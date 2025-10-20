import { Entity, ManyToOne, JoinColumn, PrimaryColumn, Unique } from 'typeorm';
import { NhanVien } from '../../nhan-vien/entities/nhan-vien.entity';
import { ChucVu } from '../../chuc-vu/entities/chuc-vu.entity';

@Entity({ name: 'chuc_vu_nhan_vien' })
@Unique(['maNhanVien', 'maChucVu'])
export class NhanVienChucVu {
  @PrimaryColumn({ name: 'ma_nhan_vien', type: 'uuid' })
  maNhanVien!: string;

  @PrimaryColumn({ name: 'ma_chuc_vu', type: 'uuid' })
  maChucVu!: string;

  // eslint-disable-next-line @typescript-eslint/no-unsafe-return
  @ManyToOne(() => NhanVien, { onDelete: 'CASCADE', onUpdate: 'CASCADE' })
  @JoinColumn({ name: 'ma_nhan_vien', referencedColumnName: 'maNhanVien' })
  nhanVien?: NhanVien;
  @ManyToOne(() => ChucVu, { onDelete: 'CASCADE', onUpdate: 'CASCADE' })
  @JoinColumn({ name: 'ma_chuc_vu', referencedColumnName: 'maChucVu' })
  chucVu?: ChucVu;
}
