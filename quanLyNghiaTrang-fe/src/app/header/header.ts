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
  intent?: 'o_ten_nguoi_mat' | 'o_dia_chi' | 'o_ten' | 'hang_dia_chi' | 'hang_ten' | 'khu';
  be_url?: string;
  params?: Record<string, any>;
};

type UploadRespOld = { ok: boolean; filename: string; path?: string };
type UploadRespNew = { id: string; file_url: string; status: number; created_at: string };
type TranscribeResp = { ok: boolean; data: AiJson; result?: any };

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
  stemsCount = 48;
  stemGap = 8;
  svgH = 60;
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
  // API endpoints (BE theo module voice-notes)
  // =========================
  private readonly UPLOAD_URL = 'http://localhost:5000/voice-notes/upload';
  private readonly TRANSCRIBE_URL = 'http://localhost:5000/voice-notes/transcribe';
  private readonly PROXY_URL = 'http://localhost:5000/voice-notes/proxy'; // fallback khi cần

  constructor(private api: MapDataService, private http: HttpClient) {}

  // =========================
  // Lifecycle
  // =========================
  ngOnInit() {
    this.api.getKhuBoundaries().subscribe({
      next: (fc: FeatureCollection) => {
        this.khus = Array.from(new Set(
          fc.features.map(f => String(f.properties?.['ten_khu'])).filter(Boolean)
        ));
      },
      error: (err) => console.error('[header] loadKhuBoundaries error:', err)
    });
  }

  ngOnChanges(changes: SimpleChanges): void {
    if (changes['selectedKhu'] && this.selectedKhu) this.loadHangsByKhu(this.selectedKhu);
    if (changes['selectedHang'] && this.selectedKhu && this.selectedHang) this.loadOsByHang(this.selectedKhu, this.selectedHang);
  }

  // =========================
  // Menu
  // =========================
  toggleMenu(): void {
    this.isMenuOpen = !this.isMenuOpen;
    this.menuToggled.emit(this.isMenuOpen);
  }

  // =========================
  // Search cascade
  // =========================
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
    this.api.getHangByKhu(ten_khu).subscribe({
      next: (fc: FeatureCollection) => {
        this.hangs = Array.from(new Set(
          fc.features.map(f => String(f.properties?.['ten_hang'])).filter(Boolean)
        )).sort((a, b) => parseFloat(a) - parseFloat(b));
      },
      error: (err) => console.error('[header] loadHangsByKhu error:', err)
    });
  }

  private loadOsByHang(ten_khu: string, ten_hang: string) {
    this.api.getOByHang(ten_khu, ten_hang).subscribe({
      next: (fc) => {
        this.os = fc.features.map(f => String(f.properties?.['ten_o']))
          .filter(Boolean).sort((a, b) => parseFloat(a) - parseFloat(b));
      },
      error: (err) => console.error('[header] loadOsByHang error:', err)
    });
  }

  onSearch() {
    const query = this.query.trim();
    if (!query) return;

    const isAddress = /^\d+(\.\d+)?(-\d+){0,2}$/.test(query);
    if (isAddress) {
      this.modeChange.emit('o');
      const parts = query.split('-');
      this.khuChange.emit(parts[0]);
      if (parts[1]) this.hangChange.emit(parts[1]);
      if (parts[2]) this.oChange.emit(parts[2]);
    } else {
      this.api.getOByTenNguoiMat(query).subscribe({
        next: (f) => {
          if (!f?.properties) return;
          const { ten_khu, ten_hang, ten_o } = f.properties;
          this.khuChange.emit(ten_khu);
          this.hangChange.emit(ten_hang);
          this.oChange.emit(ten_o);
          this.modeChange.emit('o');
        },
        error: (e) => console.error('[onSearch tenNguoiMat]', e)
      });
    }
  }

  // =========================
  // Recording flow
  // =========================
  async onMicClickStart() {
    this.recordError = undefined;
    try {
      this.isRecordingMode = true;
      await new Promise<void>(r => setTimeout(r, 0));
      await this.startRecording();
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

      // 1) finalize WAV
      const file = await this.finalizeToFile();

      // 2) upload
      const form = new FormData();
      form.append('file', file);
      const upResp = await this.http.post<UploadRespOld | UploadRespNew>(this.UPLOAD_URL, form).toPromise();
      const filename = this.extractFilenameFromUpload(upResp);
      if (!filename) throw new Error('Upload thất bại: không có filename');

      // 3) transcribe (BE sẽ gọi Docker AI và follow be_url nếu có)
      const trResp = await this.http.post<TranscribeResp>(this.TRANSCRIBE_URL, { filename }).toPromise();
      if (!trResp?.ok || !trResp.data) throw new Error('Transcribe thất bại');

      const ai = trResp.data;
      let beData: any = trResp.result ?? null;

      // fallback: nếu BE chưa follow (hiếm), proxy theo be_url
      if (!beData && ai.be_url) {
        beData = await this.http.get<{ ok: boolean; data: any }>(
          this.PROXY_URL, { params: new HttpParams().set('url', ai.be_url) }
        ).toPromise().then(r => r?.data ?? null);
      }

      // 4) xử lý intent đúng theo app.py
      this.handleIntent(ai, beData);

      // 5) reset UI
      this.isRecordingMode = false;
      this.elapsedMs = 0;

    } catch (e: any) {
      this.recordError = e?.message || String(e);
      console.error('[rec] onSendRecording error:', e);
    } finally {
      this.isUploading = false;
    }
  }

  // =========================
  // Intent handler (đúng danh sách của app.py)
  // =========================
  private handleIntent(ai: AiJson, beData: any) {
    const f = this.asFeature(beData);

    switch (ai.intent) {
      // ------ O (đầy đủ khu + hàng + ô) ------
      case 'o_ten_nguoi_mat':
      case 'o_dia_chi':
      case 'o_ten': {
        const info = this.extractKhuHangO(f ?? beData);
        if (!info) {
          console.warn(`[intent ${ai.intent}] dữ liệu trả về không phải Feature/không có ten_khu/ten_hang/ten_o`, beData);
          return;
        }
        const { ten_khu, ten_hang, ten_o } = info;
        if (ten_khu) this.khuChange.emit(ten_khu);
        if (ten_hang) this.hangChange.emit(ten_hang);
        if (ten_o) this.oChange.emit(ten_o);
        this.modeChange.emit('o');
        break;
      }

      // ------ HÀNG (khu + hàng) ------
      case 'hang_dia_chi':
      case 'hang_ten': {
        const info = this.extractKhuHang(f ?? beData);
        if (!info) {
          console.warn(`[intent ${ai.intent}] dữ liệu không có ten_khu/ten_hang`, beData);
          return;
        }
        const { ten_khu, ten_hang } = info;
        if (ten_khu) this.khuChange.emit(ten_khu);
        if (ten_hang) this.hangChange.emit(ten_hang);
        this.modeChange.emit('o');       // chuyển xuống chọn ô
        break;
      }

      // ------ KHU ------
      case 'khu': {
        const khu = this.extractKhu(f ?? beData);
        if (!khu) {
          console.warn('[intent khu] dữ liệu không có khu/ten_khu', beData);
          return;
        }
        this.khuChange.emit(khu);
        this.modeChange.emit('hang');    // chuyển tới chọn hàng
        break;
      }

      default: {
        // Không có intent (None) hoặc intent lạ
        const t = ai.text?.trim();
        if (t) alert(`🤖 Tôi nghe: "${t}". Chưa nhận ra yêu cầu.`);
        else alert('🤖 Không nhận ra yêu cầu.');
      }
    }
  }

  // =========================
  // Helpers cho intent
  // =========================
  private asFeature(x: any): any | null {
    return x && typeof x === 'object' && 'properties' in x ? x : null;
  }

  private extractKhuHangO(x: any): { ten_khu: string; ten_hang: string; ten_o: string } | null {
    // Hỗ trợ 2 dạng: Feature GeoJSON ({properties:{...}}) hoặc object phẳng
    const p = x?.properties ?? x;
    const ten_khu = p?.ten_khu ?? p?.khu ?? p?.['tenKhu'];
    const ten_hang = p?.ten_hang ?? p?.hang ?? p?.['tenHang'];
    const ten_o = p?.ten_o ?? p?.o ?? p?.['tenO'];
    if (!ten_khu || !ten_hang || !ten_o) return null;
    return { ten_khu: String(ten_khu), ten_hang: String(ten_hang), ten_o: String(ten_o) };
    }

  private extractKhuHang(x: any): { ten_khu: string; ten_hang: string } | null {
    const p = x?.properties ?? x;
    const ten_khu = p?.ten_khu ?? p?.khu ?? p?.['tenKhu'];
    const ten_hang = p?.ten_hang ?? p?.hang ?? p?.['tenHang'];
    if (!ten_khu || !ten_hang) return null;
    return { ten_khu: String(ten_khu), ten_hang: String(ten_hang) };
  }

  private extractKhu(x: any): string | null {
    const p = x?.properties ?? x;
    const khu = p?.khu ?? p?.ten_khu ?? p?.['tenKhu'];
    return khu ? String(khu) : null;
  }

  // =========================
  // Low-level audio
  // =========================
  private async startRecording() {
    if (this.state === 'recording') return;
    const stream = await navigator.mediaDevices.getUserMedia({ audio: true });
    this.audioCtx = new AudioContext({ sampleRate: this.SAMPLE_RATE });
    if (this.audioCtx.state === 'suspended') await this.audioCtx.resume();
    this.source = this.audioCtx.createMediaStreamSource(stream);
    this.analyser = this.audioCtx.createAnalyser();
    this.analyser.fftSize = 2048;
    this.source.connect(this.analyser);

    this.processor = this.audioCtx.createScriptProcessor(4096, 1, 1);
    this.chunks = [];
    this.processor.onaudioprocess = (ev) => {
      this.chunks.push(new Float32Array(ev.inputBuffer.getChannelData(0)));
    };
    this.source.connect(this.processor);
    this.processor.connect(this.audioCtx.destination);

    this.state = 'recording';
    this.startAt = Date.now();
  }

  private async cleanupRecording() {
    this.stopWaveLoop();
    try { this.processor?.disconnect(); } catch {}
    try { this.source?.disconnect(); } catch {}
    try { this.analyser?.disconnect(); } catch {}
    try { await this.audioCtx?.close(); } catch {}
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
        const norm = Math.min(1, (avg / 255) * 1.25);
        const amp = Math.max(2, norm * maxHalf);
        const yTop = (this.centerY - amp).toFixed(1);
        const yBot = (this.centerY + amp).toFixed(1);

        const line = stems[i];
        line.setAttribute('y1', yTop);
        line.setAttribute('y2', yBot);
      }

      this.hasLevels = true;
      this.rafId = requestAnimationFrame(tick);
    };

    this.stopWaveLoop();
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
    await this.cleanupRecording();
    const samples = this.merge(this.chunks);
    const wav = this.encodeWav(samples, this.SAMPLE_RATE);
    const blob = new Blob([wav], { type: 'audio/wav' });
    return new File([blob], `rec_${Date.now()}.wav`, { type: 'audio/wav' });
  }

  // =========================
  // Helpers
  // =========================
  private extractFilenameFromUpload(resp: UploadRespOld | UploadRespNew | any): string | null {
    if (resp && typeof resp === 'object' && 'ok' in resp && 'filename' in resp && resp.ok && resp.filename) {
      return String(resp.filename);
    }
    if (resp && typeof resp === 'object' && typeof resp.file_url === 'string') {
      const seg = resp.file_url.split('/').filter(Boolean);
      return seg.length ? seg[seg.length - 1] : null;
    }
    return null;
  }
}
