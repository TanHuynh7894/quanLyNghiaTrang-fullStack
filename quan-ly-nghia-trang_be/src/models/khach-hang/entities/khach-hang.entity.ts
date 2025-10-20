import {
  Column,
  Entity,
  PrimaryGeneratedColumn,
  OneToOne,
  JoinColumn,
} from 'typeorm';
import { NguoiDung } from '../../nguoi-dung/entities/nguoi-dung.entity';

@Entity({ name: 'khach_hang' })
export class KhachHang {
  @PrimaryGeneratedColumn('uuid', { name: 'ma_khach_hang' })
  maKhachHang!: string;

  @OneToOne(() => NguoiDung, { onDelete: 'CASCADE', eager: true })
  @JoinColumn({ name: 'ma_khach_hang', referencedColumnName: 'id' })
  nguoiDung!: NguoiDung;

  @Column({ name: 'ten_khach_hang', type: 'text' })
  tenKhachHang!: string;

  @Column({ name: 'dia_chi', type: 'text', nullable: true })
  diaChi?: string;

  @Column({ name: 'so_lien_he', type: 'text', nullable: true })
  soLienHe?: string;

  @Column({ name: 'quoc_tich', type: 'text', nullable: true })
  quocTich?: string;

  @Column({ name: 'so_cccd', type: 'text', nullable: true })
  soCCCDHoChieu?: string;

  @Column({ name: 'ngay_cap', type: 'date', nullable: true })
  ngayCap?: Date;

  @Column({ name: 'noi_cap', type: 'text', nullable: true })
  noiCap?: string;

  @Column({ name: 'ghi_chu', type: 'text', nullable: true })
  ghiChu?: string;
}
