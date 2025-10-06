import { Injectable, NotFoundException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import type { Feature, FeatureCollection, Geometry } from 'geojson';
import { OEntity } from './entities/o.entity';
import { Hang } from '../hang/entities/hang.entity';
import { Khu } from '../khu/entities/khu.entity';
import { LookupService } from '../../helpper/lookup/lookup.service';

type ORaw = {
  id: string;
  ten_o: string;
  ma_hang: string;
  ten_hang: string;
  ma_khu: string;
  ten_khu: string;
  dia_chi: string | null;
  geojson: string;
};

@Injectable()
export class OService {
  constructor(
    @InjectRepository(OEntity) private readonly oRepo: Repository<OEntity>,
    private readonly lookup: LookupService,
  ) {}

  private mapORawToFeature(row: ORaw): Feature {
    const geometry = JSON.parse(row.geojson) as Geometry;
    return {
      type: 'Feature',
      geometry,
      properties: {
        id: row.id,
        ten_o: row.ten_o,
        ma_hang: row.ma_hang,
        ten_hang: row.ten_hang,
        ma_khu: row.ma_khu,
        ten_khu: row.ten_khu,
        dia_chi: row.dia_chi,
      },
    };
  }

  async findByTenKhuAndTenHang(
    ten_khu: string,
    ten_hang: string,
  ): Promise<FeatureCollection> {
    const ma_khu = await this.lookup.getMaKhuByTen(ten_khu.trim());
    const ma_hang = await this.lookup.getMaHangByTen(ten_hang.trim(), ma_khu);

    const rows = await this.oRepo
      .createQueryBuilder('o')
      .leftJoin(Hang, 'h', 'h.ma_hang = o.ma_hang AND h.ma_khu = o.ma_khu')
      .leftJoin(Khu, 'k', 'k.ma_khu = o.ma_khu')
      .select([
        'o.id AS id',
        'o.ten_o AS ten_o',
        'o.ma_hang AS ma_hang',
        'o.ma_khu AS ma_khu',
        'o.dia_chi AS dia_chi',
      ])
      .addSelect('h.ten_hang', 'ten_hang')
      .addSelect('k.ten_khu', 'ten_khu')
      .addSelect('ST_AsGeoJSON(o.toa_do, 6)', 'geojson')
      .where('o.ma_khu = :ma_khu', { ma_khu })
      .andWhere('o.ma_hang = :ma_hang', { ma_hang })
      .orderBy('o.ten_o', 'ASC')
      .getRawMany<ORaw>();

    return {
      type: 'FeatureCollection',
      features: rows.map((r) => this.mapORawToFeature(r)),
    };
  }

  async findOneByTen(
    ten_khu: string,
    ten_hang: string,
    ten_o: string,
  ): Promise<Feature> {
    const ma_khu = await this.lookup.getMaKhuByTen(ten_khu.trim());
    const ma_hang = await this.lookup.getMaHangByTen(ten_hang.trim(), ma_khu);

    const row = await this.oRepo
      .createQueryBuilder('o')
      .leftJoin(Hang, 'h', 'h.ma_hang = o.ma_hang AND h.ma_khu = o.ma_khu')
      .leftJoin(Khu, 'k', 'k.ma_khu = o.ma_khu')
      .select([
        'o.id AS id',
        'o.ten_o AS ten_o',
        'o.ma_hang AS ma_hang',
        'o.ma_khu AS ma_khu',
        'o.dia_chi AS dia_chi',
      ])
      .addSelect('h.ten_hang', 'ten_hang')
      .addSelect('k.ten_khu', 'ten_khu')
      .addSelect('ST_AsGeoJSON(o.toa_do, 6)', 'geojson')
      .where('o.ma_khu = :ma_khu', { ma_khu })
      .andWhere('o.ma_hang = :ma_hang', { ma_hang })
      .andWhere('o.ten_o ILIKE :ten_o', { ten_o: ten_o.trim() })
      .getRawOne<ORaw>();

    if (!row) {
      throw new NotFoundException(
        `Không tìm thấy ô: "${ten_o}" (hàng="${ten_hang}", khu="${ten_khu}")`,
      );
    }

    return this.mapORawToFeature(row);
  }

  async findOneByDiaChi(dia_chi: string): Promise<Feature> {
    const row = await this.oRepo
      .createQueryBuilder('o')
      .leftJoin(Hang, 'h', 'h.ma_hang = o.ma_hang AND h.ma_khu = o.ma_khu')
      .leftJoin(Khu, 'k', 'k.ma_khu = o.ma_khu')
      .select([
        'o.id AS id',
        'o.ten_o AS ten_o',
        'o.ma_hang AS ma_hang',
        'o.ma_khu AS ma_khu',
        'o.dia_chi AS dia_chi',
      ])
      .addSelect('h.ten_hang', 'ten_hang')
      .addSelect('k.ten_khu', 'ten_khu')
      .addSelect('ST_AsGeoJSON(o.toa_do, 6)', 'geojson')
      .where('o.dia_chi ILIKE :dia_chi', { dia_chi: dia_chi.trim() })
      .getRawOne<ORaw>();

    if (!row) {
      throw new NotFoundException(`Không tìm thấy ô với địa chỉ: "${dia_chi}"`);
    }

    return this.mapORawToFeature(row);
  }
}
