import {
  Component, Input, Output, EventEmitter, HostBinding, SimpleChanges,
  ViewChild, ElementRef
} from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { HttpClient, HttpParams } from '@angular/common/http';
import type { FeatureCollection } from 'geojson';
import { MapDataService } from '../map-data';

type UIState = 'idle' | 'recording';

type AiJson = {
  text: string;
  intent?: string;
  be_url?: string;
  params?: Record<string, any>;
};

@Component({
  selector: 'app-header',
  standalone: true,
  imports: [CommonModule, FormsModule],
  templateUrl: './header.html',
  styleUrls: ['./header.css'],
})
export class HeaderComponent {
  // =========================
  // Basic UI
  // =========================
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

  // =========================
  // Recording UI
  // =========================
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

  // =========================
  // API endpoints
  // =========================
  // Lưu ý: Đảm bảo BE route trùng khớp với code NestJS đã cấu hình.
  private readonly UPLOAD_URL = 'http://localhost:5000/voice/upload';
  private readonly TRANSCRIBE_URL = 'http://localhost:5000/voice/transcribe';
  private readonly PROXY_URL = 'http://localhost:5000/voice/proxy';

  constructor(private api: MapDataService, private http: HttpClient) { }

  // =========================
  // Lifecycle
  // =========================
  ngOnInit() {
    console.log('[header] ngOnInit');
    console.time('[header] loadKhuBoundaries');
    this.api.getKhuBoundaries().subscribe({
      next: (fc: FeatureCollection) => {
        this.khus = Array.from(new Set(
          fc.features.map(f => String(f.properties?.['ten_khu'])).filter(Boolean)
        ));
        console.timeEnd('[header] loadKhuBoundaries');
        console.log('[header] khus loaded:', this.khus.length);
      },
      error: (err) => {
        console.timeEnd('[header] loadKhuBoundaries');
        console.error('[header] loadKhuBoundaries error:', err);
      }
    });
  }

  ngOnChanges(changes: SimpleChanges): void {
    if (changes['selectedKhu'] && this.selectedKhu) {
      console.log('[header] ngOnChanges selectedKhu =', this.selectedKhu);
      this.loadHangsByKhu(this.selectedKhu);
    }
    if (changes['selectedHang'] && this.selectedKhu && this.selectedHang) {
      console.log('[header] ngOnChanges selectedHang =', this.selectedHang);
      this.loadOsByHang(this.selectedKhu, this.selectedHang);
    }
  }

  // =========================
  // Menu toggle
  // =========================
  toggleMenu(): void {
    this.isMenuOpen = !this.isMenuOpen;
    this.menuToggled.emit(this.isMenuOpen);
    console.log('[header] toggleMenu ->', this.isMenuOpen);
  }

  // =========================
  // Search cascade
  // =========================
  onKhuChange() {
    if (!this.selectedKhu) return;
    console.log('[header] onKhuChange ->', this.selectedKhu);
    this.selectedHang = undefined; this.selectedO = undefined;
    this.hangs = []; this.os = [];
    this.modeChange.emit('hang');
    this.khuChange.emit(this.selectedKhu);
    this.loadHangsByKhu(this.selectedKhu);
  }

  onHangChange() {
    if (!this.selectedKhu || !this.selectedHang) return;
    console.log('[header] onHangChange ->', this.selectedHang);
    this.selectedO = undefined; this.os = [];
    this.modeChange.emit('o');
    this.hangChange.emit(this.selectedHang);
    this.loadOsByHang(this.selectedKhu, this.selectedHang);
  }

  onOChange() {
    if (this.selectedO) {
      console.log('[header] onOChange ->', this.selectedO);
      this.oChange.emit(this.selectedO);
    }
  }

  private loadHangsByKhu(ten_khu: string) {
    console.time('[header] loadHangsByKhu');
    this.api.getHangByKhu(ten_khu).subscribe({
      next: (fc: FeatureCollection) => {
        this.hangs = Array.from(new Set(
          fc.features.map(f => String(f.properties?.['ten_hang'])).filter(Boolean)
        )).sort((a, b) => parseFloat(a) - parseFloat(b));
        console.timeEnd('[header] loadHangsByKhu');
        console.log('[header] hangs loaded:', this.hangs.length);
      },
      error: (err) => {
        console.timeEnd('[header] loadHangsByKhu');
        console.error('[header] loadHangsByKhu error:', err);
      }
    });
  }

  private loadOsByHang(ten_khu: string, ten_hang: string) {
    console.time('[header] loadOsByHang');
    this.api.getOByHang(ten_khu, ten_hang).subscribe({
      next: (fc) => {
        this.os = fc.features.map(f => String(f.properties?.['ten_o']))
          .filter(Boolean).sort((a, b) => parseFloat(a) - parseFloat(b));
        console.timeEnd('[header] loadOsByHang');
        console.log('[header] os loaded:', this.os.length);
      },
      error: (err) => {
        console.timeEnd('[header] loadOsByHang');
        console.error('[header] loadOsByHang error:', err);
      }
    });
  }

  onSearch() {
    const query = this.query.trim();
    console.log('[header] onSearch query =', query);
    if (!query) return;

    const isAddress = /^\d+(\.\d+)?(-\d+){0,2}$/.test(query);

    if (isAddress) {
      console.log('[header] search as address');
      this.modeChange.emit('o');
      const parts = query.split('-');
      this.khuChange.emit(parts[0]);
      if (parts[1]) this.hangChange.emit(parts[1]);
      if (parts[2]) this.oChange.emit(parts[2]);
    } else {
      console.time('[header] search tenNguoiMat');
      this.api.getOByTenNguoiMat(query).subscribe({
        next: (f) => {
          console.timeEnd('[header] search tenNguoiMat');
          if (!f?.properties) {
            console.warn('[header] tenNguoiMat not found for:', query);
            return;
          }
          const { ten_khu, ten_hang, ten_o } = f.properties;
          console.log('[header] tenNguoiMat found →', { ten_khu, ten_hang, ten_o });
          this.khuChange.emit(ten_khu);
          this.hangChange.emit(ten_hang);
          this.oChange.emit(ten_o);
          this.modeChange.emit('o');
        },
        error: (e) => {
          console.timeEnd('[header] search tenNguoiMat');
          console.error('[header] onSearch tenNguoiMat error:', e);
        }
      });
    }
  }

  // =========================
  // Recording flow
  // =========================
  async onMicClickStart() {
    this.recordError = undefined;
    console.log('[rec] onMicClickStart');
    try {
      // render recordingTpl
      this.isRecordingMode = true;
      await new Promise<void>(r => setTimeout(r, 0));

      // bắt đầu thu
      await this.startRecording();

      // timer & waveform
      this.startTimer();
      this.startWaveLoop();
      console.log('[rec] start ok');
    } catch (e: any) {
      this.recordError = e?.message || String(e);
      console.error('[rec] start error:', e);
      await this.cleanupRecording();
      this.isRecordingMode = false;
    }
  }

  async onCancelRecording() {
    console.log('[rec] onCancelRecording');
    await this.cleanupRecording();
    this.isRecordingMode = false;
    this.elapsedMs = 0;
  }

  async onSendRecording() {
    console.log('[rec] onSendRecording elapsedMs=', this.elapsedMs);
    if (this.elapsedMs < this.MIN_SEND_MS) {
      console.warn('[rec] too short, ignore');
      return;
    }

    try {
      this.isUploading = true;

      // 1) Đóng ghi & lấy file WAV
      console.time('[rec] finalizeToFile');
      const file = await this.finalizeToFile();
      console.timeEnd('[rec] finalizeToFile');
      console.log('[rec] file ready:', file.name, file.size, file.type);

      // 2) UPLOAD
      console.time('[api] upload');
      const form = new FormData();
      form.append('file', file);
      const upResp = await this.http.post<{ ok: boolean; filename: string; path?: string }>(
        this.UPLOAD_URL, form
      ).toPromise();
      console.timeEnd('[api] upload');
      console.log('[api] upload resp:', upResp);

      if (!upResp?.ok || !upResp.filename) {
        throw new Error('Upload thất bại');
      }

      // 3) TRANSCRIBE (Docker AI)
      console.time('[api] transcribe');
      const trResp = await this.http.post<{ ok: boolean; data: AiJson }>(
        this.TRANSCRIBE_URL, { filename: upResp.filename }
      ).toPromise();
      console.timeEnd('[api] transcribe');
      console.log('[api] transcribe resp:', trResp);

      if (!trResp?.ok || !trResp.data) {
        throw new Error('Transcribe thất bại');
      }

      const ai = trResp.data; // { text, intent, be_url, params }
      console.log('[AI] text:', ai.text, 'intent:', ai.intent, 'be_url:', ai.be_url, 'params:', ai.params);

      // 4) FOLLOW be_url qua proxy để tránh CORS
      let beData: any = null;
      if (ai.be_url) {
        console.time('[api] proxy be_url');
        beData = await this.http.get<{ ok: boolean; data: any }>(
          this.PROXY_URL, { params: new HttpParams().set('url', ai.be_url) }
        ).toPromise().then(r => r?.data ?? null);
        console.timeEnd('[api] proxy be_url');
        console.log('[api] proxy resp:', beData);
      } else {
        console.warn('[AI] be_url empty → skip proxy');
      }

      // 5) Tương tác FE theo intent
      if (ai.intent === 'o_ten_nguoi_mat' && beData) {
        // tuỳ backend trả gì; giả định trả 1 Feature với .properties
        const f = beData?.properties ? beData : null;
        if (f) {
          const { ten_khu, ten_hang, ten_o } = f.properties;
          console.log('[intent] o_ten_nguoi_mat → emit:', { ten_khu, ten_hang, ten_o });
          if (ten_khu) this.khuChange.emit(ten_khu);
          if (ten_hang) this.hangChange.emit(ten_hang);
          if (ten_o) this.oChange.emit(ten_o);
          this.modeChange.emit('o');
        } else {
          console.warn('[intent] o_ten_nguoi_mat but beData not Feature-like');
        }
      } else if (ai.intent) {
        console.log('[intent] other:', ai.intent, 'params:', ai.params);
        // TODO: handle các intent khác nếu có
      }

      // 6) Reset UI
      this.isRecordingMode = false;
      this.elapsedMs = 0;
      console.log('[rec] done');

    } catch (e: any) {
      this.recordError = e?.message || String(e);
      console.error('[rec] onSendRecording error:', e);
    } finally {
      this.isUploading = false;
    }
  }

  // =========================
  // Low-level audio
  // =========================
  private async startRecording() {
    if (this.state === 'recording') return;
    console.time('[rec] getUserMedia');

    const stream = await navigator.mediaDevices.getUserMedia({ audio: true });
    console.timeEnd('[rec] getUserMedia');

    this.audioCtx = new AudioContext({ sampleRate: this.SAMPLE_RATE });

    if (this.audioCtx.state === 'suspended') {
      console.time('[rec] audioCtx.resume');
      await this.audioCtx.resume();
      console.timeEnd('[rec] audioCtx.resume');
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
      // copy channel 0
      this.chunks.push(new Float32Array(ev.inputBuffer.getChannelData(0)));
    };
    this.source.connect(this.processor);
    // kết nối đến destination để đảm bảo onaudioprocess được gọi
    this.processor.connect(this.audioCtx.destination);

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

  // =========================
  // Waveform loop (SVG stems)
  // =========================
  private startWaveLoop() {
    const svg = this.waveSvg?.nativeElement;
    if (!svg || !this.analyser) {
      console.warn('[wave] svg/analyser not ready');
      return;
    }

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

        const norm = Math.min(1, (avg / 255) * 1.25);  // 0..1
        const amp = Math.max(2, norm * maxHalf);       // px mỗi phía
        const yTop = (this.centerY - amp).toFixed(1);
        const yBot = (this.centerY + amp).toFixed(1);

        const line = stems[i];
        line.setAttribute('y1', yTop);
        line.setAttribute('y2', yBot);
      }

      this.hasLevels = true;
      this.rafId = requestAnimationFrame(tick);
    };

    this.stopWaveLoop(); // dừng loop cũ nếu còn
    this.rafId = requestAnimationFrame(tick);
    console.log('[wave] start');
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

    // không log quá nhiều mỗi lần stop, chỉ 1 dòng
    console.log('[wave] stop');
  }

  // =========================
  // WAV encode
  // =========================
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
    // Dừng ghi trước khi gộp samples
    await this.cleanupRecording();
    const samples = this.merge(this.chunks);
    const wav = this.encodeWav(samples, this.SAMPLE_RATE);
    const blob = new Blob([wav], { type: 'audio/wav' });
    const file = new File([blob], `rec_${Date.now()}.wav`, { type: 'audio/wav' });
    return file;
  }
}
