// src/duong-xa/duong-xa.entity.ts
import {
  Entity,
  PrimaryGeneratedColumn,
  Column,
  Index,
  BaseEntity,
} from 'typeorm';

@Entity({ name: 'duong_routing' })
export class DuongXa extends BaseEntity {
  @PrimaryGeneratedColumn({ name: 'id', type: 'int' })
  id: number;

  // fid gốc từ QGIS (nếu cần dùng để debug / join ngược)
  @Column({ name: 'fid', type: 'bigint' })
  fid: number;

  @Column({
    name: 'name',
    type: 'varchar',
    length: 255,
    nullable: true,
  })
  name?: string;

  // geometry LINESTRING 4326
  @Column({
    name: 'geom',
    type: 'geometry',
    spatialFeatureType: 'LineString',
    srid: 4326,
  })
  geom: string; // có thể để any nếu bạn muốn

  @Index()
  @Column({
    name: 'from_id',
    type: 'int',
    nullable: false,
  })
  fromId: number;

  @Index()
  @Column({
    name: 'to_id',
    type: 'int',
    nullable: false,
  })
  toId: number;

  @Column({
    name: 'cost',
    type: 'double precision',
    nullable: true,
  })
  cost?: number;
}
