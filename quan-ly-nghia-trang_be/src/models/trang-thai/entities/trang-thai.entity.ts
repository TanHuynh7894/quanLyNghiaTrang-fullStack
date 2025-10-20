import { Entity, PrimaryGeneratedColumn, Column } from 'typeorm';

@Entity({ name: 'trang_thai' })
export class TrangThai {
  @PrimaryGeneratedColumn('uuid', { name: 'ma_trang_thai' })
  maTrangThai!: string; // Tự động sinh UUID

  @Column({ name: 'ten_trang_thai', type: 'text', unique: true })
  tenTrangThai!: string;
}
