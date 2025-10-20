import { Column, Entity, PrimaryGeneratedColumn } from 'typeorm';

@Entity({ name: 'don_vi' })
export class DonVi {
  @PrimaryGeneratedColumn('uuid', { name: 'ma_don_vi' })
  maDonVi!: string;

  @Column({ name: 'ten_don_vi', type: 'text' })
  tenDonVi!: string;

  @Column({ name: 'ma_don_vi_cha', type: 'uuid', nullable: true })
  maDonViCha?: string;

  @Column({ name: 'dia_chi', type: 'text', nullable: true })
  diaChi?: string;

  @Column({
    name: 'so_dien_thoai',
    type: 'text',
    nullable: true,
  })
  soDienThoai?: string;

  @Column({ name: 'ma_so_thue', type: 'text', nullable: true })
  maSoThue?: string;

  @Column({ name: 'so_tai_khoan', type: 'text', nullable: true })
  soTaiKhoan?: string;

  @Column({ name: 'ky_hieu_hoa_don', type: 'text', nullable: true })
  kyHieuHoaDon?: string;

  @Column({
    name: 'tinh_trang_hoat_dong',
    type: 'enum',
    enum: ['0', '1'],
    default: '1',
  })
  tinhTrangHoatDong!: '0' | '1';
}
