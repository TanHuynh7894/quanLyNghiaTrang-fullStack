// src/models/voice-notes/voice-notes.controller.ts
import {
  BadRequestException,
  Body,
  Controller,
  Get,
  Logger,
  Post,
  Query,
  UploadedFile,
  UseInterceptors,
} from '@nestjs/common';
import { FileInterceptor } from '@nestjs/platform-express';
import { diskStorage } from 'multer';
import { join } from 'path';
import { VoiceNotesService } from './voice-notes.service';

@Controller('voice-notes')
export class VoiceNotesController {
  private readonly logger = new Logger(VoiceNotesController.name);

  constructor(private readonly service: VoiceNotesService) {}

  @Post('upload')
  @UseInterceptors(
    FileInterceptor('file', {
      storage: diskStorage({
        destination: join('E:', 'D', 'vnpt', 'quanLyNghiaTrang_1', 'temp'),
        filename: (_req, file, cb) =>
          cb(null, `${Date.now()}_${file.originalname}`),
      }),
      limits: { fileSize: 30 * 1024 * 1024 }, // 30MB
    }),
  )
  async upload(@UploadedFile() file: Express.Multer.File) {
    if (!file) throw new BadRequestException('Missing file');
    this.logger.log(
      `[upload] received: ${file.originalname} (${file.size} bytes)`,
    );
    const result = await this.service.saveRaw(file.path, file.originalname);
    this.logger.log(`[upload] saved -> ${result.path}`);
    return result;
  }

  @Post('transcribe')
  async transcribe(@Body('filename') filename: string) {
    if (!filename) throw new BadRequestException('filename is required');
    this.logger.log(`[transcribe] start -> ${filename}`);

    const { ai, result } = await this.service.transcribeLocalFile(filename);

    this.logger.log(
      `[transcribe] ok -> text="${ai.text}", intent=${ai.intent ?? 'null'}, be_url=${ai.be_url ?? 'none'}`,
    );

    return { ok: true, data: ai, ...(result !== undefined && { result }) };
  }

  @Get('proxy')
  async proxy(@Query('url') url: string) {
    if (!url) throw new BadRequestException('url is required');
    this.logger.log(`[proxy] GET ${url}`);
    const data = await this.service.proxyGET(url);
    return { ok: true, data };
  }
}
