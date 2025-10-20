import { Injectable, NotFoundException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { DonVi } from './entities/don-vi.entity';
import { CreateDonViDto } from './dto/create-don-vi.dto';
import { UpdateDonViDto } from './dto/update-don-vi.dto';

function toDonViResponse(
  dv: DonVi,
  parent: { maDonVi: string | null; tenDonVi: string } | null,
) {
  return {
    // ----- root level -----
    maDonVi: dv.maDonVi,
    tenDonVi: dv.tenDonVi,
    diaChi: dv.diaChi,
    soDienThoai: dv.soDienThoai,
    maSoThue: dv.maSoThue,
    soTaiKhoan: dv.soTaiKhoan,
    kyHieuHoaDon: dv.kyHieuHoaDon,
    tinhTrangHoatDong: dv.tinhTrangHoatDong, // '0' | '1'
    // 👇 luôn ở root, cùng level với maDonVi
    tinhTrangHoatDongText:
      dv.tinhTrangHoatDong === '1' ? 'Đang hoạt động' : 'Ngừng hoạt động',

    // ----- nested object -----
    maDonViCha:
      parent ??
      ({
        maDonVi: 'Không có',
        tenDonVi: 'Không có',
      } as const),
  };
}

@Injectable()
export class DonViService {
  constructor(
    @InjectRepository(DonVi)
    private readonly repo: Repository<DonVi>,
  ) {}

  async create(dto: CreateDonViDto) {
    const donVi = this.repo.create(dto);
    return this.repo.save(donVi);
  }

  async findAll() {
    const list = await this.repo.find();
    // preload map id -> tên để tránh N query
    const byId = new Map(list.map((x) => [x.maDonVi, x]));

    return list.map((dv) => {
      const p = dv.maDonViCha ? byId.get(dv.maDonViCha) : null;
      const parent = p ? { maDonVi: p.maDonVi, tenDonVi: p.tenDonVi } : null;
      return toDonViResponse(dv, parent);
    });
  }

  async findOne(id: string) {
    const dv = await this.repo.findOne({ where: { maDonVi: id } });
    if (!dv) throw new NotFoundException('Không tìm thấy đơn vị');

    let parent: { maDonVi: string | null; tenDonVi: string } | null = null;
    if (dv.maDonViCha) {
      const p = await this.repo.findOne({ where: { maDonVi: dv.maDonViCha } });
      if (p) parent = { maDonVi: p.maDonVi, tenDonVi: p.tenDonVi };
    }

    return toDonViResponse(dv, parent);
  }

  async update(id: string, dto: UpdateDonViDto) {
    const dv = await this.repo.findOne({ where: { maDonVi: id } });
    if (!dv) throw new NotFoundException('Không tìm thấy đơn vị');
    Object.assign(dv, dto);
    return this.repo.save(dv);
  }

  async remove(id: string) {
    const res = await this.repo.delete(id);
    if (!res.affected) throw new NotFoundException('Không tìm thấy đơn vị');
    return { success: true };
  }
}
