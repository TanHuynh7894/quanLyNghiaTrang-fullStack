import {
  Entity,
  PrimaryGeneratedColumn,
  Column,
  ManyToOne,
  JoinColumn,
} from 'typeorm';
import { KhachHang } from '../../khach-hang/entities/khach-hang.entity';

@Entity('thong_tin_nguoi_mat')
export class ThongTinNguoiMat {
  @PrimaryGeneratedColumn('uuid', { name: 'ma_nguoi_mat' })
  maNguoiMat: string;

  @Column({ name: 'ten_nguoi_mat', type: 'text' })
  tenNguoiMat: string;

  @Column({ name: 'dia_chi', type: 'text', nullable: true })
  diaChi?: string;

  @Column({ name: 'quoc_tich', type: 'text', nullable: true })
  quocTich?: string;

  @Column({ name: 'so_cccd', type: 'text', nullable: true })
  soCCCDHoChieu?: string;

  @Column({ name: 'ngay_cap', type: 'date', nullable: true })
  ngayCap?: string;

  @Column({ name: 'noi_cap', type: 'text', nullable: true })
  noiCap?: string;

  @Column({ name: 'ngay_sinh', type: 'date', nullable: true })
  ngaySinh?: string;

  @Column({ name: 'ngay_mat_duong', type: 'date', nullable: true })
  ngayMatDuongLich?: string;

  @Column({ name: 'ngay_mat_am', type: 'date', nullable: true })
  ngayMatAmLich?: string;

  // ===== FK =====
  @ManyToOne(() => KhachHang, { onDelete: 'SET NULL', onUpdate: 'CASCADE' })
  @JoinColumn({ name: 'ma_khach_hang' })
  khachHang: KhachHang;
}
