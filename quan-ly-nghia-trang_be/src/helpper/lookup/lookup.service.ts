import { Injectable, NotFoundException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { Khu } from '../../models/khu/entities/khu.entity';
import { Hang } from '../../models/hang/entities/hang.entity';
import { DataSource } from 'typeorm';

export type MoPhanBase = {
  ten_o: string | null;
  dia_chi: string;
  chieu_dai: string | null;
  chieu_rong: string | null;
  dien_tich: string | null;
  ma_tinh_trang: string | null;
  ten_tinh_trang: string | null;
  ma_kieu_mo: string | null;
  ten_kieu_mo: string | null;
  ngay_khao_sat: Date | null;
  gia_tri: string | null;
};

export type LichSuItem = {
  id: string;
  ngay: Date;
  the_loai: string;
  ghi_chu: string | null;
};

export type HinhAnhItem = {
  id: string;
  hinh_anh: string;
};

export type MoPhanBundle = {
  mo_phan: MoPhanBase | null;
  lich_su: LichSuItem[];
  hinh_anh: HinhAnhItem[];
};

@Injectable()
export class LookupService {
  constructor(
    @InjectRepository(Khu) private readonly khuRepo: Repository<Khu>,
    @InjectRepository(Hang) private readonly hangRepo: Repository<Hang>,
    private readonly ds: DataSource,
  ) {}

  async getMaKhuByTen(ten_khu: string): Promise<string> {
    const row = await this.khuRepo
      .createQueryBuilder('k')
      .select('k.ma_khu', 'ma_khu')
      .where('k.ten_khu = :ten_khu', { ten_khu })
      .getRawOne<{ ma_khu: string }>();

    if (!row) throw new NotFoundException(`Không tìm thấy khu: ${ten_khu}`);
    return row.ma_khu;
  }

  async getMaHangByTen(ten_hang: string, ma_khu?: string): Promise<string> {
    const qb = this.hangRepo
      .createQueryBuilder('h')
      .select('h.ma_hang', 'ma_hang')
      .where('h.ten_hang = :ten_hang', { ten_hang });

    if (ma_khu) qb.andWhere('h.ma_khu = :ma_khu', { ma_khu });

    const row = await qb.getRawOne<{ ma_hang: string }>();
    if (!row) {
      const msg = ma_khu
        ? `Không tìm thấy hàng: ${ten_hang} trong khu ${ma_khu}`
        : `Không tìm thấy hàng: ${ten_hang}`;
      throw new NotFoundException(msg);
    }
    return row.ma_hang;
  }

  async getMoPhanBaseByDiaChi(dia_chi: string): Promise<MoPhanBase | null> {
    const row = await this.ds
      .createQueryBuilder()
      .from('mo_phan', 'm')
      .leftJoin('kieu_mo', 'km', 'km.ma_kieu_mo = m.ma_kieu_mo')
      .leftJoin(
        'tinh_trang_mo_phan',
        'tt',
        'tt.ma_tinh_trang = m.ma_tinh_trang',
      )
      .select([
        'm.ten_o AS ten_o',
        'm.dia_chi_o AS dia_chi',
        'm.chieu_dai AS chieu_dai',
        'm.chieu_rong AS chieu_rong',
        'm.dien_tich AS dien_tich',
        'm.ma_tinh_trang AS ma_tinh_trang',
        'tt.ten_tinh_trang AS ten_tinh_trang',
        'm.ma_kieu_mo AS ma_kieu_mo',
        'km.ten_kieu_mo AS ten_kieu_mo',
        'm.ngay_khao_sat AS ngay_khao_sat',
        'm.gia_tri AS gia_tri',
        'tt.color',
      ])
      .where('m.dia_chi_o = :dia_chi', { dia_chi })
      .getRawOne<MoPhanBase>();

    return row ?? null;
  }

  async getLichSuByDiaChi(dia_chi: string): Promise<LichSuItem[]> {
    return this.ds
      .createQueryBuilder()
      .from('lich_su_phan_mo', 'ls')
      .select([
        'ls.ngay AS ngay',
        'ls.the_loai AS the_loai',
        'ls.ghi_chu AS ghi_chu',
      ])
      .where('ls.dia_chi_o = :dia_chi', { dia_chi })
      .orderBy('ls.ngay', 'DESC')
      .getRawMany<LichSuItem>();
  }

  // 3) Danh sách hình ảnh – nhiều dòng
  async getHinhAnhByDiaChi(dia_chi: string): Promise<HinhAnhItem[]> {
    return this.ds
      .createQueryBuilder()
      .from('hinh_anh_mo_phan', 'ha')
      .select(['ha.hinh_anh AS hinh_anh'])
      .where('ha.dia_chi_o = :dia_chi', { dia_chi })
      .getRawMany<HinhAnhItem>();
  }

  // Hàm tổng hợp (gọi 3 cái trên)
  // async getMoPhanBundleByDiaChi(dia_chi: string): Promise<MoPhanBundle | null> {
  //   const base = await this.getMoPhanBaseByDiaChi(dia_chi);
  //   if (!base) return null;

  //   const [lich_su, hinh_anh] = await Promise.all([
  //     this.getLichSuByDiaChi(dia_chi),
  //     this.getHinhAnhByDiaChi(dia_chi),
  //   ]);

  //   return {
  //     mo_phan: base,
  //     lich_su,
  //     hinh_anh,
  //   };
  // }
}
