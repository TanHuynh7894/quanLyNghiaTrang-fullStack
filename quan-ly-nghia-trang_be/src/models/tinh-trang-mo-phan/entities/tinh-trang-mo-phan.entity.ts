import { Entity, PrimaryColumn, Column } from 'typeorm';

@Entity({ name: 'tinh_trang_mo_phan' })
export class TinhTrangMoPhan {
  @PrimaryColumn({ type: 'uuid' })
  ma_tinh_trang: string;

  @Column({ type: 'varchar', length: 255, nullable: false })
  ten_tinh_trang: string;

  @Column({ type: 'varchar', length: 10, nullable: true })
  color?: string | null;
}
