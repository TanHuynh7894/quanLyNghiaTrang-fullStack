import { Entity, PrimaryGeneratedColumn, Column, OneToMany } from 'typeorm';
import { Hang } from '../../hang/entities/hang.entity';
import { OEntity } from '../../o/entities/o.entity';

@Entity('khu')
export class Khu {
  @PrimaryGeneratedColumn() ma_khu: string;
  @Column({ length: 255 }) ten_khu: string;
  @Column({
    type: 'geometry',
    spatialFeatureType: 'MultiPolygon',
    srid: 4326,
    select: false,
  })
  toa_do: unknown;

  @OneToMany(() => Hang, (h) => h.khu)
  hangs: Hang[];

  @OneToMany(() => OEntity, (o) => o.khu)
  os: OEntity[];
}
