import {
  Entity,
  PrimaryGeneratedColumn,
  Column,
  CreateDateColumn,
} from 'typeorm';

@Entity('voice_notes')
export class VoiceNote {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column({ type: 'text' })
  file_url: string;

  @Column({ type: 'smallint', default: 0 })
  status: number; // 0 = uploaded_wav, 1 = mp3_ready, 2 = stt_done

  @CreateDateColumn({ type: 'timestamptz' })
  created_at: Date;
}
