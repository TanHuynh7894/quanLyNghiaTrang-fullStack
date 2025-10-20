// src/models/dich-vu/dich-vu.service.ts
import { Injectable } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { DichVu } from './entities/dich-vu.entity';
import { DichVuResponseDto } from './dto/dich-vu-response.dto';

@Injectable()
export class DichVuService {
  constructor(
    @InjectRepository(DichVu)
    private readonly repo: Repository<DichVu>,
  ) {}

  async findAll(): Promise<DichVuResponseDto[]> {
    const items = await this.repo.find();
    return items.map(
      (dv): DichVuResponseDto => ({
        maDichVu: dv.maDichVu,
        loaiDichVu: dv.loaiDichVu,
        chiPhiDichVu: dv.chiPhiDichVu,
        tinhTrangHoatDong: dv.tinhTrangHoatDong, // giữ '0' | '1'
        ghiChu: dv.ghiChu,
        tinhTrangHoatDongText:
          dv.tinhTrangHoatDong === '1' ? 'Đang hoạt động' : 'Đã dừng dịch vụ',
      }),
    );
  }

  async findOne(id: string): Promise<DichVuResponseDto | null> {
    const dv = await this.repo.findOne({ where: { maDichVu: id } });
    if (!dv) return null;
    return {
      maDichVu: dv.maDichVu,
      loaiDichVu: dv.loaiDichVu,
      chiPhiDichVu: dv.chiPhiDichVu,
      tinhTrangHoatDong: dv.tinhTrangHoatDong,
      ghiChu: dv.ghiChu,
      tinhTrangHoatDongText:
        dv.tinhTrangHoatDong === '1' ? 'Đang hoạt động' : 'Đã dừng dịch vụ',
    };
  }

  async create(dto: Partial<DichVu>) {
    const entity = this.repo.create(dto);
    return this.repo.save(entity);
  }

  async update(id: string, dto: Partial<DichVu>) {
    await this.repo.update(id, dto);
    return this.findOne(id);
  }

  async remove(id: string) {
    return this.repo.delete(id);
  }
}
