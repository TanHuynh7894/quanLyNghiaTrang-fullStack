// src/models/voice-notes/voice-notes.controller.ts
import {
  Controller,
  Post,
  UploadedFile,
  UseInterceptors,
} from '@nestjs/common';
import { FileInterceptor } from '@nestjs/platform-express';
import { diskStorage } from 'multer';
import { join } from 'path';
import { VoiceNotesService } from './voice-notes.service';

@Controller('voice-notes')
export class VoiceNotesController {
  constructor(private readonly service: VoiceNotesService) {}

  @Post('upload')
  @UseInterceptors(
    FileInterceptor('file', {
      storage: diskStorage({
        destination: join('E:', 'D', 'vnpt', 'quanLyNghiaTrang_1', 'temp'), // thư mục tạm trên ổ E
        filename: (req, file, cb) => {
          const name = `${Date.now()}_${file.originalname}`;
          cb(null, name);
        },
      }),
    }),
  )
  async upload(@UploadedFile() file: Express.Multer.File) {
    return this.service.saveRaw(file.path, file.originalname);
  }
}
