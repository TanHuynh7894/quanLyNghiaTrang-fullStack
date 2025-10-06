import { Injectable, NotFoundException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { Khu } from '../../models/khu/entities/khu.entity';
import { Hang } from '../../models/hang/entities/hang.entity';

@Injectable()
export class LookupService {
  constructor(
    @InjectRepository(Khu) private readonly khuRepo: Repository<Khu>,
    @InjectRepository(Hang) private readonly hangRepo: Repository<Hang>,
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
}
