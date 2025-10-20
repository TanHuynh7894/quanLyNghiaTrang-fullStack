import { Column, Entity, PrimaryGeneratedColumn } from 'typeorm';

@Entity({ name: 'chuc_vu' })
export class ChucVu {
  @PrimaryGeneratedColumn('uuid', { name: 'ma_chuc_vu' })
  maChucVu!: string;

  @Column({ name: 'ten_chuc_vu', type: 'varchar', length: 255 })
  tenChucVu!: string;

  @Column({
    name: 'tinh_trang_hoat_dong',
    type: 'enum',
    enum: ['0', '1'],
    default: '1',
  })
  tinhTrangHoatDong!: '0' | '1';
}
