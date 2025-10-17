import {
  Component, Input, Output, EventEmitter, HostBinding, SimpleChanges,
  ViewChild, ElementRef
} from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { HttpClient } from '@angular/common/http';
import type { FeatureCollection } from 'geojson';
import { MapDataService } from '../map-data';

type UIState = 'idle' | 'recording';

@Component({
  selector: 'app-header',
  standalone: true,
  imports: [CommonModule, FormsModule],
  templateUrl: './header.html',
  styleUrls: ['./header.css'],
})
export class HeaderComponent {
  projectName = 'My Project';
  isMenuOpen = false;

  query = '';
  khus: string[] = [];
  hangs: string[] = [];
  os: string[] = [];

  @Input() selectedKhu?: string;
  @Input() selectedHang?: string;
  @Input() selectedO?: string;

  @Output() modeChange = new EventEmitter<'khu' | 'hang' | 'o'>();
  @Output() khuChange = new EventEmitter<string>();
  @Output() hangChange = new EventEmitter<string>();
  @Output() oChange = new EventEmitter<string>();
  @Output() menuToggled = new EventEmitter<boolean>();
  @HostBinding('class.header-menu-open') get menuOpenClass() { return this.isMenuOpen; }

  // ==== Recording UI ====
  isRecordingMode = false;
  isUploading = false;
  recordError?: string;
  elapsedMs = 0;
  readonly MIN_SEND_MS = 300;

  // Waveform SVG params
  @ViewChild('waveSvg') waveSvg?: ElementRef<SVGSVGElement>;
  stemsCount = 48;          // số cọc
  stemGap = 8;              // khoảng cách giữa cọc (px trong viewBox)
  svgH = 60;                // chiều cao viewBox
  get svgW() { return (this.stemsCount - 1) * this.stemGap + 1; }
  get centerY() { return this.svgH / 2; }
  stemsArr = Array.from({ length: this.stemsCount });
  hasLevels = false;

  // Audio nodes
  private state: UIState = 'idle';
  private audioCtx?: AudioContext;
  private source?: MediaStreamAudioSourceNode;
  private analyser?: AnalyserNode;
  private processor?: ScriptProcessorNode;
  private rafId?: number;
  private timerId?: any;

  // PCM capture
  private chunks: Float32Array[] = [];
  private startAt = 0;
  private readonly SAMPLE_RATE = 16000;

  // API
  private readonly UPLOAD_URL = 'http://localhost:5000/voice-notes/upload'; // dùng proxy dev; nếu không dùng: 'http://localhost:3000/voice-notes/upload'

  constructor(private api: MapDataService, private http: HttpClient) { }

  // ===== lifecycle =====
  ngOnInit() {
    this.api.getKhuBoundaries().subscribe((fc: FeatureCollection) => {
      this.khus = Array.from(new Set(
        fc.features.map(f => String(f.properties?.['ten_khu'])).filter(Boolean)
      ));
    });
  }
  ngOnChanges(changes: SimpleChanges): void {
    if (changes['selectedKhu'] && this.selectedKhu) this.loadHangsByKhu(this.selectedKhu);
    if (changes['selectedHang'] && this.selectedKhu && this.selectedHang) this.loadOsByHang(this.selectedKhu, this.selectedHang);
  }

  // ===== menu =====
  toggleMenu(): void {
    this.isMenuOpen = !this.isMenuOpen;
    this.menuToggled.emit(this.isMenuOpen);
  }

  // ===== search cascade =====
  onKhuChange() {
    if (!this.selectedKhu) return;
    this.selectedHang = undefined; this.selectedO = undefined;
    this.hangs = []; this.os = [];
    this.modeChange.emit('hang');
    this.khuChange.emit(this.selectedKhu);
    this.loadHangsByKhu(this.selectedKhu);
  }
  onHangChange() {
    if (!this.selectedKhu || !this.selectedHang) return;
    this.selectedO = undefined; this.os = [];
    this.modeChange.emit('o');
    this.hangChange.emit(this.selectedHang);
    this.loadOsByHang(this.selectedKhu, this.selectedHang);
  }
  onOChange() { if (this.selectedO) this.oChange.emit(this.selectedO); }

  private loadHangsByKhu(ten_khu: string) {
    this.api.getHangByKhu(ten_khu).subscribe((fc: FeatureCollection) => {
      this.hangs = Array.from(new Set(
        fc.features.map(f => String(f.properties?.['ten_hang'])).filter(Boolean)
      )).sort((a, b) => parseFloat(a) - parseFloat(b));
    });
  }
  private loadOsByHang(ten_khu: string, ten_hang: string) {
    this.api.getOByHang(ten_khu, ten_hang).subscribe(fc => {
      this.os = fc.features.map(f => String(f.properties?.['ten_o']))
        .filter(Boolean).sort((a, b) => parseFloat(a) - parseFloat(b));
    });
  }

  onSearch() {
    if (this.isRecordingMode) return;
    const raw = this.query.trim();
    if (!raw) return;
    const parts = raw.split(/[-]/).map(s => s.trim()).filter(Boolean);
    if (parts.length === 1) {
      const khu = parts[0];
      this.selectedKhu = khu; this.selectedHang = undefined; this.selectedO = undefined;
      this.modeChange.emit('hang'); this.khuChange.emit(khu); this.loadHangsByKhu(khu);
      return;
    }
    if (parts.length === 2) {
      const [khu, hang] = parts;
      this.selectedKhu = khu; this.selectedHang = hang; this.selectedO = undefined;
      this.modeChange.emit('o'); this.khuChange.emit(khu); this.hangChange.emit(hang);
      this.loadOsByHang(khu, hang);
      return;
    }
    const [khu, hang, o] = parts;
    this.selectedKhu = khu; this.selectedHang = hang; this.selectedO = o;
    this.khuChange.emit(khu); this.hangChange.emit(hang); this.oChange.emit(o);
  }

  // ===== recording flow =====
  async onMicClickStart() {
    this.recordError = undefined;
    try {
      // 1) render recordingTpl (để #waveSvg tồn tại)
      this.isRecordingMode = true;

      // 2) chờ 1 tick cho Angular render xong
      await new Promise<void>(r => setTimeout(r, 0));

      // 3) bắt đầu thu
      await this.startRecording();

      // 4) timer & vẽ waveform (giờ đã có this.waveSvg)
      this.startTimer();
      this.startWaveLoop();
    } catch (e: any) {
      this.recordError = e?.message || String(e);
      await this.cleanupRecording();
      this.isRecordingMode = false;
    }
  }

  async onCancelRecording() {
    await this.cleanupRecording();
    this.isRecordingMode = false;
    this.elapsedMs = 0;
  }
  async onSendRecording() {
    if (this.elapsedMs < this.MIN_SEND_MS) return;
    try {
      this.isUploading = true;
      const file = await this.finalizeToFile();
      const form = new FormData();
      form.append('file', file);
      await this.http.post(this.UPLOAD_URL, form).toPromise();
      await this.cleanupRecording();
      this.isRecordingMode = false;
      this.elapsedMs = 0;
    } catch (e: any) {
      this.recordError = e?.message || String(e);
    } finally {
      this.isUploading = false;
    }
  }

  // ===== low-level audio =====
  private async startRecording() {
    if (this.state === 'recording') return;

    const stream = await navigator.mediaDevices.getUserMedia({ audio: true });

    this.audioCtx = new AudioContext({ sampleRate: this.SAMPLE_RATE });
    if (this.audioCtx.state === 'suspended') {
      await this.audioCtx.resume();          // quan trọng trên Chrome/Safari
    }

    this.source = this.audioCtx.createMediaStreamSource(stream);

    // analyser cho waveform
    this.analyser = this.audioCtx.createAnalyser();
    this.analyser.fftSize = 2048;
    this.source.connect(this.analyser);

    // thu PCM để encode WAV
    this.processor = this.audioCtx.createScriptProcessor(4096, 1, 1);
    this.chunks = [];
    this.processor.onaudioprocess = (ev) => {
      this.chunks.push(new Float32Array(ev.inputBuffer.getChannelData(0)));
    };
    this.source.connect(this.processor);
    this.processor.connect(this.audioCtx.destination); // để onaudioprocess chạy

    this.state = 'recording';
    this.startAt = Date.now();
  }


  private async cleanupRecording() {
    this.stopWaveLoop();

    try { this.processor?.disconnect(); } catch { }
    try { this.source?.disconnect(); } catch { }
    try { this.analyser?.disconnect(); } catch { }
    try { await this.audioCtx?.close(); } catch { }

    (this.processor as any) = undefined;
    (this.source as any) = undefined;
    (this.analyser as any) = undefined;
    (this.audioCtx as any) = undefined;

    this.state = 'idle';
    clearInterval(this.timerId);
  }

  private startTimer() {
    clearInterval(this.timerId);
    this.elapsedMs = 0;
    this.startAt = Date.now();
    this.timerId = setInterval(() => {
      this.elapsedMs = Date.now() - this.startAt;
    }, 50);
  }

  // ===== waveform loop (SVG stems) =====
  private startWaveLoop() {
    const svg = this.waveSvg?.nativeElement;
    if (!svg || !this.analyser) return;

    const stems = Array.from(svg.querySelectorAll<SVGLineElement>('line.stem'));
    const bins = new Uint8Array(this.analyser.frequencyBinCount);

    const groups = this.stemsCount;
    const step = Math.max(1, Math.floor(bins.length / groups));
    const maxHalf = (this.svgH / 2) - 4;

    const tick = () => {
      this.analyser!.getByteFrequencyData(bins);

      for (let i = 0; i < groups; i++) {
        const start = i * step;
        const end = Math.min(bins.length, start + step);
        let sum = 0; for (let j = start; j < end; j++) sum += bins[j];
        const avg = sum / (end - start || 1);          // 0..255

        const norm = Math.min(1, (avg / 255) * 1.25);  // 0..1 (nén nhẹ)
        const amp = Math.max(2, norm * maxHalf);      // px mỗi phía
        const yTop = (this.centerY - amp).toFixed(1);
        const yBot = (this.centerY + amp).toFixed(1);

        const line = stems[i];
        line.setAttribute('y1', yTop);
        line.setAttribute('y2', yBot);
      }

      this.hasLevels = true;
      this.rafId = requestAnimationFrame(tick);
    };

    this.stopWaveLoop();               // dừng loop cũ nếu còn
    this.rafId = requestAnimationFrame(tick);
  }


  private stopWaveLoop() {
    if (this.rafId) cancelAnimationFrame(this.rafId);
    this.rafId = undefined;
    this.hasLevels = false;

    const svg = this.waveSvg?.nativeElement;
    svg?.querySelectorAll<SVGLineElement>('line.stem').forEach(l => {
      l.setAttribute('y1', String(this.centerY));
      l.setAttribute('y2', String(this.centerY));
    });
  }


  // ===== WAV encode =====
  private merge(buffers: Float32Array[]) {
    let len = 0; buffers.forEach(b => len += b.length);
    const out = new Float32Array(len);
    let off = 0; buffers.forEach(b => { out.set(b, off); off += b.length; });
    return out;
  }

  private encodeWav(samples: Float32Array, sampleRate: number) {
    const buffer = new ArrayBuffer(44 + samples.length * 2);
    const view = new DataView(buffer);
    const writeStr = (off: number, s: string) => { for (let i = 0; i < s.length; i++) view.setUint8(off + i, s.charCodeAt(i)); };
    writeStr(0, 'RIFF'); view.setUint32(4, 36 + samples.length * 2, true);
    writeStr(8, 'WAVE'); writeStr(12, 'fmt '); view.setUint32(16, 16, true);
    view.setUint16(20, 1, true); view.setUint16(22, 1, true); // PCM mono
    view.setUint32(24, sampleRate, true); view.setUint32(28, sampleRate * 2, true);
    view.setUint16(32, 2, true); view.setUint16(34, 16, true);
    writeStr(36, 'data'); view.setUint32(40, samples.length * 2, true);
    let offset = 44;
    for (let i = 0; i < samples.length; i++, offset += 2) {
      const s = Math.max(-1, Math.min(1, samples[i]));
      view.setInt16(offset, s < 0 ? s * 0x8000 : s * 0x7fff, true);
    }
    return view;
  }

  private async finalizeToFile(): Promise<File> {
    await this.cleanupRecording();
    const samples = this.merge(this.chunks);
    const wav = this.encodeWav(samples, this.SAMPLE_RATE);
    const blob = new Blob([wav], { type: 'audio/wav' });
    return new File([blob], `rec_${Date.now()}.wav`, { type: 'audio/wav' });
  }
}
