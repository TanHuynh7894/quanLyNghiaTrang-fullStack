import { BadRequestException, Injectable, Logger } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { DeepPartial, Repository } from 'typeorm';
import { VoiceNote } from './voice-note.entity/voice-note.entity';

import * as fs from 'fs';
import * as fsp from 'fs/promises';
import { basename, extname, join } from 'path';

import axios, { AxiosResponse } from 'axios';
import FormData from 'form-data';

export interface AiResp {
  text: string;
  intent?: string;
  be_url?: string;
  params?: Record<string, unknown>;
}

function getErrorMessage(e: unknown): string {
  if (axios.isAxiosError(e)) return e.message || 'Axios error';
  if (e instanceof Error) return e.message;
  try {
    return JSON.stringify(e);
  } catch {
    return String(e);
  }
}

@Injectable()
export class VoiceNotesService {
  private readonly logger = new Logger(VoiceNotesService.name);

  private readonly uploadDir = join(process.cwd(), 'uploads');
  private readonly voiceDir = join(this.uploadDir, 'voice');
  private readonly AI_BASE = process.env.AI_BASE ?? 'http://127.0.0.1:8010';

  constructor(
    @InjectRepository(VoiceNote)
    private readonly repo: Repository<VoiceNote>,
  ) {
    if (!fs.existsSync(this.voiceDir)) {
      fs.mkdirSync(this.voiceDir, { recursive: true });
    }
  }

  /**
   * Xoá file cũ nhất trong uploads/voice (trừ file vừa lưu)
   */
  private async cleanupOldestFile(skipFilename: string) {
    try {
      const files = await fsp.readdir(this.voiceDir);
      const candidates = files.filter((f) => f !== skipFilename);
      if (candidates.length === 0) return;

      const stats = await Promise.all(
        candidates.map(async (name) => {
          const fullPath = join(this.voiceDir, name);
          const s = await fsp.stat(fullPath);
          return { name, fullPath, ctimeMs: s.ctimeMs };
        }),
      );

      // sắp xếp tăng dần theo thời gian tạo → file lâu nhất đầu tiên
      stats.sort((a, b) => a.ctimeMs - b.ctimeMs);
      const oldest = stats[0];
      if (!oldest) return;

      this.logger.log(`[cleanup] removing oldest file: ${oldest.name}`);
      await fsp
        .unlink(oldest.fullPath)
        .catch((err) =>
          this.logger.warn(`[cleanup] failed: ${getErrorMessage(err)}`),
        );
    } catch (err) {
      this.logger.warn(`[cleanup] error: ${getErrorMessage(err)}`);
    }
  }

  async saveRaw(filePath: string, originalName: string) {
    if (!filePath || !originalName) {
      throw new BadRequestException('Invalid upload payload');
    }

    await fsp.mkdir(this.voiceDir, { recursive: true });

    const safeBase =
      basename(originalName, extname(originalName)).replace(
        /[^a-zA-Z0-9_-]/g,
        '',
      ) || 'rec';
    const ext = extname(originalName) || '.wav';
    const outName = `${Date.now()}_${safeBase}${ext}`;
    const outPath = join(this.voiceDir, outName);

    this.logger.log(`saveRaw: moving ${filePath} -> ${outPath}`);
    await fsp.rename(filePath, outPath);

    let saved: VoiceNote | null = null;
    try {
      const row: DeepPartial<VoiceNote> = {
        file_url: `/voice/${outName}`,
        status: 1,
      };
      saved = await this.repo.save(this.repo.create(row));
    } catch (err) {
      this.logger.warn(`saveRaw: repo.save failed: ${getErrorMessage(err)}`);
    }

    // DỌN FILE CŨ SAU KHI LƯU MỚI
    await this.cleanupOldestFile(outName);

    return {
      ok: true,
      filename: outName,
      path: `/uploads/voice/${outName}`,
      ...(saved && {
        id: saved.id,
        file_url: saved.file_url,
        status: (saved as unknown as { status?: number })?.status ?? 1,
        created_at: (
          saved as unknown as { created_at?: Date }
        )?.created_at?.toISOString?.(),
      }),
    };
  }

  private normalizeBeUrl(url?: string): string | undefined {
    if (!url) return url;
    try {
      const u = new URL(url);
      if (u.hostname === 'host.docker.internal') u.hostname = 'localhost';
      return u.toString();
    } catch {
      return url;
    }
  }

  async transcribeLocalFile(
    filename: string,
  ): Promise<{ ai: AiResp; result?: unknown }> {
    if (!filename) throw new BadRequestException('filename is required');

    const abs = join(this.voiceDir, filename);
    if (!fs.existsSync(abs)) {
      this.logger.warn(`transcribe: file not found ${abs}`);
      throw new BadRequestException('File not found');
    }

    const fd = new FormData();
    fd.append('file', fs.createReadStream(abs));
    fd.append('language', 'vi');
    fd.append('task', 'transcribe');
    fd.append('response_format', 'json');
    fd.append('model', 'kiendt/PhoWhisper-large-ct2');

    const url = `${this.AI_BASE}/v1/audio/transcriptions`;
    this.logger.log(`AI POST -> ${url} (file=${filename})`);

    let res: AxiosResponse<unknown>;
    try {
      res = await axios.post(url, fd, {
        headers: fd.getHeaders(),
        maxBodyLength: Infinity,
        timeout: 60_000,
        validateStatus: () => true,
      });
    } catch (err) {
      const msg = getErrorMessage(err);
      this.logger.error(`AI request failed: ${msg}`);
      throw new BadRequestException(`AI request failed: ${msg}`);
    }

    if (res.status >= 400) {
      const body = res.data as { error?: { message?: string } } | undefined;
      const msg = body?.error?.message || `AI error (${res.status})`;
      this.logger.error(msg);
      throw new BadRequestException(`AI: ${msg}`);
    }

    const raw = res.data as Partial<AiResp>;
    if (typeof raw.text !== 'string') {
      this.logger.error('AI response missing "text"');
      throw new BadRequestException('Invalid AI response');
    }

    const ai: AiResp = {
      text: raw.text,
      intent: raw.intent,
      be_url: this.normalizeBeUrl(raw.be_url),
      params: raw.params ?? {},
    };

    let result: unknown = undefined;
    if (ai.be_url) {
      this.logger.log(`Follow be_url -> ${ai.be_url}`);
      try {
        const r = await axios.get(ai.be_url, {
          timeout: 15_000,
          validateStatus: () => true,
        });
        if (r.status >= 400) {
          this.logger.warn(`be_url returned ${r.status}`);
        }
        result = r.data ?? undefined;
      } catch (err) {
        this.logger.warn(`Follow be_url failed: ${getErrorMessage(err)}`);
      }
    }

    return result !== undefined ? { ai, result } : { ai };
  }

  async proxyGET(url: string) {
    if (!/^https?:\/\//i.test(url)) {
      throw new BadRequestException('Invalid URL');
    }
    let r: AxiosResponse<unknown>;
    try {
      r = await axios.get(url, {
        timeout: 15_000,
        validateStatus: () => true,
      });
    } catch (err) {
      const msg = getErrorMessage(err);
      this.logger.warn(`Proxy GET failed: ${msg}`);
      throw new BadRequestException(`Proxy GET failed: ${msg}`);
    }
    if (r.data == null) throw new BadRequestException('Empty response');
    return r.data;
  }
}
