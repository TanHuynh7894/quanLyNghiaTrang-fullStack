import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { VoiceNote } from './voice-note.entity/voice-note.entity';
import { VoiceNotesController } from './voice-notes.controller';
import { VoiceNotesService } from './voice-notes.service';

@Module({
  imports: [TypeOrmModule.forFeature([VoiceNote])],
  controllers: [VoiceNotesController],
  providers: [VoiceNotesService],
})
export class VoiceNotesModule {}
