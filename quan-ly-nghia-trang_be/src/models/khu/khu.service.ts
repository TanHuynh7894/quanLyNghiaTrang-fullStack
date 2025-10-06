import { Injectable, NotFoundException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { Khu } from '../khu/entities/khu.entity';
import type { Geometry, Feature } from 'geojson';

type KhuRaw = {
  ma_khu: string;
  ten_khu: string;
  geojson: string;
};

@Injectable()
export class KhuService {
  constructor(
    @InjectRepository(Khu)
    private readonly repo: Repository<Khu>,
  ) {}

  async findAllKhu() {
    const rows = await this.repo
      .createQueryBuilder('k')
      .select(['k.ma_khu', 'ma_khu'])
      .addSelect('k.ten_khu', 'ten_khu')
      .addSelect('ST_AsGeoJSON(k.toa_do, 6)', 'geojson')
      .orderBy('k.ten_khu', 'ASC')
      .getRawMany<KhuRaw>();

    return {
      type: 'FeatureCollection',
      features: rows.map((r) => ({
        type: 'Feature',
        geometry: JSON.parse(r.geojson) as Geometry,
        properties: {
          ma_khu: r.ma_khu,
          ten_khu: r.ten_khu,
        },
      })),
    };
  }

  async findOneKhu(ten_khu: string): Promise<Feature> {
    const row = await this.repo
      .createQueryBuilder('k')
      .select('k.ma_khu', 'ma_khu')
      .addSelect('k.ten_khu', 'ten_khu')
      .addSelect('ST_AsGeoJSON(k.toa_do, 6)', 'geojson')
      .where('k.ten_khu = :ten_khu', { ten_khu })
      .getRawOne<KhuRaw>();

    if (!row) {
      throw new NotFoundException(` 
        Không tìm thấy khu có ten_khu = "${ten_khu}"
      `);
    }

    return {
      type: 'Feature',
      geometry: JSON.parse(row.geojson) as Geometry,
      properties: {
        ma_khu: row.ma_khu,
        ten_khu: row.ten_khu,
      },
    };
  }
}
