// src/models/voice-notes/voice-notes.service.ts
import { Injectable, Logger } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { VoiceNote } from './voice-note.entity/voice-note.entity';
import { promises as fs } from 'fs';
import { join, basename, extname } from 'path';

@Injectable()
export class VoiceNotesService {
  private readonly logger = new Logger(VoiceNotesService.name);
  private readonly uploadDir = join(process.cwd(), 'uploads');
  private readonly voiceDir = join(this.uploadDir, 'voice');

  constructor(
    @InjectRepository(VoiceNote) private readonly repo: Repository<VoiceNote>,
  ) {}

  // filePath: đường dẫn tạm (multer lưu)
  // originalName: tên gốc client gửi lên
  async saveRaw(filePath: string, originalName: string) {
    await fs.mkdir(this.voiceDir, { recursive: true });

    const base =
      basename(originalName, extname(originalName)).replace(
        /[^a-zA-Z0-9_-]/g,
        '',
      ) || 'rec';
    const outName = `${Date.now()}_${base}${extname(originalName) || '.wav'}`;
    const outPath = join(this.voiceDir, outName);

    // move file từ temp -> public/voice
    await fs.rename(filePath, outPath);

    const row = this.repo.create({
      file_url: `/voice/${outName}`,
      status: 1,
    });
    return this.repo.save(row);
  }
}
