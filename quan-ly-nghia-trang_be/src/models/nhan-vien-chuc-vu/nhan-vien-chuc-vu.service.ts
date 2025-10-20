import { Injectable } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { NhanVienChucVu } from './entities/nhan-vien-chuc-vu.entity';

@Injectable()
export class NhanVienChucVuService {
  constructor(
    @InjectRepository(NhanVienChucVu)
    private readonly repo: Repository<NhanVienChucVu>,
  ) {}

  // Trả ra danh sách { maChucVu, maNhanVien }
  async findAll() {
    const list = await this.repo.find({
      select: ['maChucVu', 'maNhanVien'], // chỉ chọn 2 cột này
    });

    // map đảm bảo dữ liệu sạch, không lỗi eslint
    return list.map((r) => ({
      maChucVu: r.maChucVu,
      maNhanVien: r.maNhanVien,
    }));
  }

  async findByNhanVien(maNhanVien: string) {
    const list = await this.repo.find({
      where: { maNhanVien },
      select: ['maChucVu', 'maNhanVien'],
    });
    return list;
  }

  async findByChucVu(maChucVu: string) {
    const list = await this.repo.find({
      where: { maChucVu },
      select: ['maChucVu', 'maNhanVien'],
    });
    return list;
  }
}
