// src/models/dich-vu/entities/dich-vu.entity.ts
import { Entity, Column, PrimaryGeneratedColumn } from 'typeorm';

@Entity({ name: 'dich_vu' })
export class DichVu {
  @PrimaryGeneratedColumn('uuid', { name: 'ma_dich_vu' })
  maDichVu!: string;

  @Column({ name: 'loai_dich_vu', type: 'text' })
  loaiDichVu!: string;

  @Column({ name: 'chi_phi', type: 'numeric', precision: 18, scale: 2 })
  chiPhiDichVu!: number;

  @Column({
    name: 'tinh_trang',
    type: 'enum',
    enum: ['0', '1'],
    default: '1',
  })
  tinhTrangHoatDong!: '0' | '1';

  @Column({ name: 'ghi_chu', type: 'text', nullable: true })
  ghiChu?: string;
}
