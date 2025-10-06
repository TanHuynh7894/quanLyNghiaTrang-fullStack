import { Khu } from './../../khu/entities/khu.entity';
import { OEntity } from 'src/models/o/entities/o.entity';
import {
  Entity,
  PrimaryGeneratedColumn,
  Column,
  ManyToOne,
  JoinColumn,
  OneToMany,
} from 'typeorm';

@Entity('hang')
export class Hang {
  @PrimaryGeneratedColumn('uuid')
  ma_hang: string;

  @Column()
  ten_hang: string;

  @Column('uuid')
  ma_khu: string;

  @Column({
    type: 'geometry',
    spatialFeatureType: 'MultiPolygon',
    srid: 4326,
    select: false,
  })
  toa_do: unknown;

  @ManyToOne(() => Khu, (k) => k.ma_khu, { nullable: false })
  @JoinColumn({ name: 'ma_khu', referencedColumnName: 'ma_khu' })
  khu: Khu;

  @OneToMany(() => OEntity, (o) => o.hang)
  os: OEntity[];
}
