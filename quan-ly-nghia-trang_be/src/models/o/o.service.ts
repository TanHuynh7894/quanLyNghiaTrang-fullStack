import { Injectable, NotFoundException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import type { Feature, FeatureCollection, Geometry } from 'geojson';
import { OEntity } from './entities/o.entity';
import { Hang } from '../hang/entities/hang.entity';
import { Khu } from '../khu/entities/khu.entity';
import {
  LookupService,
  MoPhanBase,
  MoPhanBundle,
} from '../../helpper/lookup/lookup.service';

import { HopDongChiTiet } from '../hop-dong-chi-tiet/entities/hop-dong-chi-tiet.entity';
import { ThongTinNguoiMat } from '../thong-tin-nguoi-mat/entities/thong-tin-nguoi-mat.entity';
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
    @InjectRepository(HopDongChiTiet)
    private readonly hdctRepo: Repository<HopDongChiTiet>,
    private readonly lookup: LookupService,
  ) {}

  private async mapORawToFeature(row: ORaw): Promise<Feature> {
    const geometry = JSON.parse(row.geojson) as Geometry;

    let extras: MoPhanBundle | null = null;
    if (row.dia_chi) {
      const base: MoPhanBase | null = await this.lookup.getMoPhanBaseByDiaChi(
        row.dia_chi,
      );
      if (base) {
        const [lich_su, hinh_anh] = await Promise.all([
          this.lookup.getLichSuByDiaChi(row.dia_chi.trim()),
          this.lookup.getHinhAnhByDiaChi(row.dia_chi.trim()),
        ]);
        extras = { mo_phan: base, lich_su, hinh_anh };
        console.log('FE = ', JSON.stringify(extras));
      }
    }

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
        mo_phan: extras?.mo_phan ?? null,
        lich_su_mo_phan: extras?.lich_su ?? [],
        hinh_anh_mo_phan: extras?.hinh_anh ?? [],
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
      .orderBy('(o.ten_o)::integer', 'ASC')
      .getRawMany<ORaw>();

    const features = await Promise.all(
      rows.map((r) => this.mapORawToFeature(r)),
    );
    return { type: 'FeatureCollection', features };
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
    console.log('findOneByDiaChi');
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
      .orderBy("regexp_replace(o.ten_o, '[^0-9]+', '', 'g')::int", 'ASC')
      .addOrderBy('o.ten_o', 'ASC')
      .getRawOne<ORaw>();
    if (!row) {
      throw new NotFoundException(`Không tìm thấy ô với địa chỉ: "${dia_chi}"`);
    }
    console.log('FE row.dia_chi =', JSON.stringify(row.dia_chi));
    return this.mapORawToFeature(row);
  }

  async findOneByTenNguoiMat(tenNguoiMat: string): Promise<Feature> {
    // normalize input (bỏ nháy, dư space)
    const ten = (tenNguoiMat ?? '')
      .replace(/^['"]+|['"]+$/g, '')
      .replace(/\s+/g, ' ')
      .trim();

    if (!ten) {
      throw new NotFoundException('Thiếu tên người mất');
    }

    // JOIN trực tiếp NguoiMat theo khóa ngoại ma_nguoi_mat
    const hdct = await this.hdctRepo
      .createQueryBuilder('hdct')
      .innerJoin(ThongTinNguoiMat, 'nm', 'nm.ma_nguoi_mat = hdct.ma_nguoi_mat')
      .where('nm.ten_nguoi_mat ILIKE :ten', { ten: `%${ten}%` })
      .orderBy('hdct.ngay_thuc_hien', 'DESC') // đổi đúng tên cột DB của bạn
      .addOrderBy('hdct.ngay_ban_giao', 'DESC') // đổi đúng tên cột DB của bạn
      .getOne();

    if (!hdct || !hdct.diaChiO /* hoặc 'hdct.dia_chi_o' nếu snake_case */) {
      throw new NotFoundException(
        `Không tìm thấy hợp đồng/địa chỉ ô cho người mất: "${ten}"`,
      );
    }

    // Trả về Feature đầy đủ (kèm mo_phan/lich_su/hinh_anh)
    return this.findOneByDiaChi(hdct.diaChiO /* hoặc hdct.dia_chi_o */);
  }
}
