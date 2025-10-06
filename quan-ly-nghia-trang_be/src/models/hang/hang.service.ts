import { Hang } from './entities/hang.entity';
import {
  Injectable,
  NotFoundException,
  BadRequestException,
} from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import type { Geometry, FeatureCollection, Feature } from 'geojson';
import { LookupService } from '../../helpper/lookup/lookup.service';

type HangRaw = {
  ma_hang: string;
  ten_hang: string;
  ma_khu: string;
  ten_khu: string;
  geojson: string;
};

@Injectable()
export class HangService {
  constructor(
    @InjectRepository(Hang) private readonly hangRepo: Repository<Hang>,
    private readonly lookup: LookupService,
  ) {}

  private mapHangRawToFeature(row: HangRaw): Feature {
    const geometry = JSON.parse(row.geojson) as Geometry;
    return {
      type: 'Feature',
      geometry,
      properties: {
        ma_hang: row.ma_hang,
        ten_hang: row.ten_hang,
        ma_khu: row.ma_khu,
        ten_khu: row.ten_khu,
      },
    };
  }

  private toFeatureCollection(rows: HangRaw[]): FeatureCollection {
    return {
      type: 'FeatureCollection',
      features: rows.map((r) => this.mapHangRawToFeature(r)),
    };
  }

  async findByTenKhu(ten_khu: string): Promise<FeatureCollection> {
    if (!ten_khu?.trim()) {
      throw new BadRequestException('ten_khu is required');
    }
    const _tenKhu = ten_khu.trim();

    const ma_khu = await this.lookup.getMaKhuByTen(_tenKhu);

    const rows = await this.hangRepo
      .createQueryBuilder('h')
      .leftJoin('khu', 'k', 'k.ma_khu = h.ma_khu')
      .select([
        'h.ma_hang AS ma_hang',
        'h.ten_hang AS ten_hang',
        'h.ma_khu  AS ma_khu',
      ])
      .addSelect('k.ten_khu', 'ten_khu')
      .addSelect('ST_AsGeoJSON(h.toa_do, 6)', 'geojson')
      .where('h.ma_khu = :ma_khu', { ma_khu })
      .orderBy('h.ten_hang', 'ASC')
      .getRawMany<HangRaw>();

    return this.toFeatureCollection(rows);
  }

  async findOneByTenKhuAndTenHang(
    ten_khu: string,
    ten_hang: string,
  ): Promise<Feature> {
    if (!ten_khu?.trim() || !ten_hang?.trim()) {
      throw new BadRequestException('ten_khu và ten_hang là bắt buộc');
    }
    const _tenKhu = ten_khu.trim();
    const _tenHang = ten_hang.trim();

    const ma_khu = await this.lookup.getMaKhuByTen(_tenKhu);

    const row = await this.hangRepo
      .createQueryBuilder('h')
      .leftJoin('khu', 'k', 'k.ma_khu = h.ma_khu')
      .select([
        'h.ma_hang AS ma_hang',
        'h.ten_hang AS ten_hang',
        'h.ma_khu  AS ma_khu',
      ])
      .addSelect('k.ten_khu', 'ten_khu')
      .addSelect('ST_AsGeoJSON(h.toa_do, 6)', 'geojson')
      .where('h.ma_khu = :ma_khu', { ma_khu })
      .andWhere('h.ten_hang ILIKE :ten_hang', { ten_hang: _tenHang })
      .getRawOne<HangRaw>();

    if (!row) {
      throw new NotFoundException(
        `Không tìm thấy hàng có ten_hang="${_tenHang}" trong khu "${_tenKhu}"`,
      );
    }

    return this.mapHangRawToFeature(row);
  }
}
