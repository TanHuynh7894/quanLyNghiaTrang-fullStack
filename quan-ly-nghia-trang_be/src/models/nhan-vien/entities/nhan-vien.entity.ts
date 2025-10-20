import {
  Column,
  Entity,
  Index,
  JoinColumn,
  ManyToOne,
  PrimaryGeneratedColumn,
} from 'typeorm';
import { DonVi } from '../../don-vi/entities/don-vi.entity';

@Entity({ name: 'nhan_vien' })
export class NhanVien {
  @PrimaryGeneratedColumn('uuid', { name: 'ma_nhan_vien' })
  maNhanVien!: string;

  @Column({ name: 'ten_nhan_vien', type: 'varchar', length: 255 })
  tenNhanVien!: string;

  // FK -> don_vi
  @Index()
  @Column({ name: 'ma_don_vi', type: 'uuid' })
  maDonVi!: string;

  @ManyToOne(() => DonVi, {
    onUpdate: 'CASCADE',
    onDelete: 'RESTRICT',
    eager: false,
    nullable: false,
  })
  @JoinColumn({ name: 'ma_don_vi', referencedColumnName: 'maDonVi' })
  donVi?: DonVi;

  // 'nam' | 'nu' | 'khac' (để varchar(5) đúng sơ đồ)
  @Column({ name: 'gioi_tinh', type: 'varchar', nullable: true })
  gioiTinh?: string;

  @Column({
    name: 'so_dien_thoai',
    type: 'text',
    nullable: true,
  })
  soDienThoai?: string;

  @Column({ name: 'email', type: 'varchar', nullable: true })
  email?: string;

  @Column({ name: 'tinh_trang_lam_viec', type: 'text', nullable: true })
  tinhTrangLamViec?: string;

  @Column({ name: 'hinh_anh', type: 'varchar', nullable: true })
  hinhAnh?: string;
}
