import { Injectable, NotFoundException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { ChucVu } from './entities/chuc-vu.entity';
import { CreateChucVuDto } from './dto/create-chuc-vu.dto';
import { UpdateChucVuDto } from './dto/update-chuc-vu.dto';

type ChucVuResponse = ChucVu & { tinhTrangHoatDongText: string };

@Injectable()
export class ChucVuService {
  constructor(
    @InjectRepository(ChucVu)
    private readonly repo: Repository<ChucVu>,
  ) {}

  async create(dto: CreateChucVuDto): Promise<ChucVu> {
    return this.repo.save(this.repo.create(dto));
  }

  async findAll(): Promise<ChucVuResponse[]> {
    const list = await this.repo.find();
    return list.map((cv) => ({
      ...cv,
      tinhTrangHoatDongText:
        cv.tinhTrangHoatDong === '1' ? 'Đang hoạt động' : 'Ngừng hoạt động',
    }));
  }

  async findOne(id: string): Promise<ChucVuResponse> {
    const cv = await this.repo.findOne({ where: { maChucVu: id } });
    if (!cv) throw new NotFoundException('Không tìm thấy chức vụ');
    return {
      ...cv,
      tinhTrangHoatDongText:
        cv.tinhTrangHoatDong === '1' ? 'Đang hoạt động' : 'Ngừng hoạt động',
    };
  }

  async update(id: string, dto: UpdateChucVuDto): Promise<ChucVu> {
    const cv = await this.repo.findOne({ where: { maChucVu: id } });
    if (!cv) throw new NotFoundException('Không tìm thấy chức vụ');
    Object.assign(cv, dto);
    return this.repo.save(cv);
  }

  async remove(id: string) {
    const res = await this.repo.delete(id);
    if (!res.affected) throw new NotFoundException('Không tìm thấy chức vụ');
    return { success: true };
  }
}
