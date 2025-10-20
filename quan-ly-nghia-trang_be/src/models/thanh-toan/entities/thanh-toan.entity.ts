import {
  Column,
  Entity,
  PrimaryGeneratedColumn,
  //   ManyToOne,
  //   JoinColumn,
} from 'typeorm';
// Nếu bạn đã có entity Hợp đồng, mở comment 2 dòng dưới
// import { HopDong } from '../../hop-dong/entities/hop-dong.entity';

@Entity({ name: 'thanh_toan' })
export class ThanhToan {
  @PrimaryGeneratedColumn('uuid', { name: 'ma_dot_thanh_toan' })
  maDotThanhToan!: string;

  // FK tới hop_dong (nếu có)
  @Column({ name: 'ma_hop_dong', type: 'uuid' })
  maHopDong!: string;

  // Nếu đã có HopDong entity, bật relation này
  // @ManyToOne(() => HopDong, { nullable: false, onDelete: 'RESTRICT' })
  // @JoinColumn({ name: 'ma_hop_dong', referencedColumnName: 'maHopDong' })
  // hopDong!: HopDong;

  @Column({
    name: 'so_tien',
    type: 'numeric',
    precision: 18,
    scale: 2,
  })
  soTienThanhToan!: number;

  // thời gian thanh toán
  @Column({ name: 'ngay_thanh_toan', type: 'timestamptz' })
  ngayThanhToan!: Date;

  @Column({
    name: 'hinh_thuc_thanh_toan',
    type: 'varchar',
    length: 255,
    nullable: true,
  })
  hinhThucThanhToan?: string;

  @Column({ name: 'noi_dung', type: 'text', nullable: true })
  noiDung?: string;

  @Column({ name: 'ghi_chu', type: 'text', nullable: true })
  ghiChu?: string;
}
