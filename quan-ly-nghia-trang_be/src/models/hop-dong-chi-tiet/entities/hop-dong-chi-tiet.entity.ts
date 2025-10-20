import {
  Entity,
  PrimaryGeneratedColumn,
  Column,
  ManyToOne,
  JoinColumn,
} from 'typeorm';
import { DichVu } from '../../dich-vu/entities/dich-vu.entity';
import { HopDong } from '../../hop-dong/entities/hop-dong.entity';
import { ThongTinNguoiMat } from '../../thong-tin-nguoi-mat/entities/thong-tin-nguoi-mat.entity';

@Entity('hop_dong_chi_tiet')
export class HopDongChiTiet {
  @PrimaryGeneratedColumn('uuid', { name: 'ma_hd_chi_tiet' })
  maHopDongChiTiet: string;

  // ===== FK giữ nguyên các quan hệ còn lại =====
  @ManyToOne(() => DichVu, { onDelete: 'SET NULL', onUpdate: 'CASCADE' })
  @JoinColumn({ name: 'ma_dich_vu' })
  dichVu: DichVu;

  @ManyToOne(() => HopDong, { onDelete: 'CASCADE', onUpdate: 'CASCADE' })
  @JoinColumn({ name: 'ma_hop_dong' })
  hopDong: HopDong;

  @ManyToOne(() => ThongTinNguoiMat, {
    onDelete: 'SET NULL',
    onUpdate: 'CASCADE',
  })
  @JoinColumn({ name: 'ma_nguoi_mat' })
  nguoiMat: ThongTinNguoiMat;

  // ===== ĐỊA CHỈ Ô: chỉ là dữ liệu text, không FK =====
  @Column({ name: 'dia_chi_o', type: 'text', nullable: true })
  diaChiO?: string;

  // ===== Thông tin chi tiết =====
  @Column({ name: 'tinh_trang_thuc', type: 'text', nullable: true })
  tinhTrangHienThuc?: string;

  @Column({ name: 'ngay_thuc_hien', type: 'timestamp', nullable: true })
  ngayThucHienDichVu?: Date;

  @Column({ name: 'ngay_ban_giao', type: 'timestamp', nullable: true })
  ngayBanGiao?: Date;

  @Column({ name: 'to_chuc_le', type: 'enum', enum: ['0', '1'], default: '0' })
  toChucLe: '0' | '1';
}
