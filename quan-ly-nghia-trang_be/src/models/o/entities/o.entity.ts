import { Entity, PrimaryColumn, Column, ManyToOne, JoinColumn } from 'typeorm';
import { Hang } from '../../hang/entities/hang.entity';
import { Khu } from '../../khu/entities/khu.entity';

@Entity('o')
export class OEntity {
  @PrimaryColumn('uuid') id: string;
  @Column({ type: 'varchar', length: 100 }) ten_o: string;
  @Column('uuid') ma_hang: string;
  @Column('uuid') ma_khu: string;
  @Column({ type: 'varchar', length: 100, nullable: true })
  dia_chi?: string | null;
  @Column({
    type: 'geometry',
    spatialFeatureType: 'MultiPolygon',
    srid: 4326,
    select: false,
  })
  toa_do: unknown;

  @ManyToOne(() => Hang, (h) => h.os, { nullable: false })
  @JoinColumn({ name: 'ma_hang', referencedColumnName: 'ma_hang' })
  hang: Hang;

  @ManyToOne(() => Khu, (k) => k.os, { nullable: false })
  @JoinColumn({ name: 'ma_khu', referencedColumnName: 'ma_khu' })
  khu: Khu;
}
