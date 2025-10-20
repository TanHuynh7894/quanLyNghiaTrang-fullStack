import {
  Entity,
  PrimaryGeneratedColumn,
  Column,
  ManyToOne,
  JoinColumn,
} from 'typeorm';
import { KhachHang } from '../../khach-hang/entities/khach-hang.entity';
import { NhanVien } from '../../nhan-vien/entities/nhan-vien.entity';

@Entity('hop_dong')
export class HopDong {
  @PrimaryGeneratedColumn('uuid', { name: 'ma_hop_dong' })
  maHopDong: string;

  @Column({ name: 'so_hop_dong', type: 'text' })
  soHopDong: string;

  @Column({ name: 'ngay_ky_ket', type: 'date' })
  ngayKyKet: string;

  @Column({ name: 'ngay_hieu_luc', type: 'date' })
  ngayHieuLuc: string;

  @Column({
    name: 'gia_tri',
    type: 'numeric',
    precision: 18,
    scale: 2,
  })
  giaTriHopDong: number;

  @Column({
    name: 'phi_chuyen_nhuong',
    type: 'numeric',
    precision: 18,
    scale: 2,
    nullable: true,
  })
  phiChuyenNhuong: number;

  @Column({ name: 'vi_tri_luu_ho_so', type: 'text', nullable: true })
  viTriLuuHoSo: string;

  @Column({ name: 'trang_thai', type: 'text', nullable: true })
  trangThaiHopDong: string;

  @Column({ name: 'ghi_chu', type: 'text', nullable: true })
  ghiChu: string;

  // ===== FK =====
  @ManyToOne(() => KhachHang, { onDelete: 'SET NULL', onUpdate: 'CASCADE' })
  @JoinColumn({ name: 'ma_khach_hang' })
  khachHang: KhachHang;

  @ManyToOne(() => KhachHang, { onDelete: 'SET NULL', onUpdate: 'CASCADE' })
  @JoinColumn({ name: 'ma_khach_ben_c' })
  khachHangBenC: KhachHang;

  @ManyToOne(() => NhanVien, { onDelete: 'SET NULL', onUpdate: 'CASCADE' })
  @JoinColumn({ name: 'ma_nhan_vien' })
  nhanVien: NhanVien;
}
