import { Injectable, NotFoundException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { HopDong } from './entities/hop-dong.entity';
import { CreateHopDongDto } from './dto/create-hop-dong.dto';
import { UpdateHopDongDto } from './dto/update-hop-dong.dto';

@Injectable()
export class HopDongService {
  constructor(
    @InjectRepository(HopDong)
    private readonly repo: Repository<HopDong>,
  ) {}

  create(dto: CreateHopDongDto) {
    const hopDong = this.repo.create(dto);
    return this.repo.save(hopDong);
  }

  findAll() {
    return this.repo.find({
      relations: ['khachHang', 'khachHangBenC', 'nhanVien'],
    });
  }

  async findOne(id: string) {
    const hd = await this.repo.findOne({
      where: { maHopDong: id },
      relations: ['khachHang', 'khachHangBenC', 'nhanVien'],
    });
    if (!hd) throw new NotFoundException('Không tìm thấy hợp đồng');
    return hd;
  }

  async update(id: string, dto: UpdateHopDongDto) {
    const existing = await this.repo.findOneBy({ maHopDong: id });
    if (!existing) throw new NotFoundException('Không tìm thấy hợp đồng');
    Object.assign(existing, dto);
    return this.repo.save(existing);
  }

  async remove(id: string) {
    const existing = await this.repo.findOneBy({ maHopDong: id });
    if (!existing) throw new NotFoundException('Không tìm thấy hợp đồng');
    return this.repo.remove(existing);
  }
}
