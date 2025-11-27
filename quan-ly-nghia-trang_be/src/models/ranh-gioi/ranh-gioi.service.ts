// src/models/ranh-gioi/ranh-gioi.service.ts
import { Injectable } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import type { Feature, FeatureCollection, Geometry } from 'geojson';
import { RanhGioi } from './entities/ranh-gioi.entity';

type RanhGioiRaw = {
  id: number;
  fid: number | null;
  geojson: string;
};

@Injectable()
export class RanhGioiService {
  constructor(
    @InjectRepository(RanhGioi)
    private readonly ranhGioiRepo: Repository<RanhGioi>,
  ) {}

  private mapRawToFeature(row: RanhGioiRaw): Feature {
    const geometry = JSON.parse(row.geojson) as Geometry;

    return {
      type: 'Feature',
      geometry,
      properties: {
        id: row.id,
        fid: row.fid,
      },
    };
  }

  // ONLY ONE FUNCTION
  async getAll(): Promise<FeatureCollection> {
    const rows = await this.ranhGioiRepo
      .createQueryBuilder('rg')
      .select(['rg.id AS id', 'rg.fid AS fid'])
      .addSelect('ST_AsGeoJSON(rg.geom, 6)', 'geojson')
      .orderBy('rg.id', 'ASC')
      .getRawMany<RanhGioiRaw>();

    const features = rows.map((r) => this.mapRawToFeature(r));
    return { type: 'FeatureCollection', features };
  }
}
