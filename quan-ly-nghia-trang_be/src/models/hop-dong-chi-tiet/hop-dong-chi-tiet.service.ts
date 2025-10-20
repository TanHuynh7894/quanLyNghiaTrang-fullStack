import { Injectable, NotFoundException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { HopDongChiTiet } from './entities/hop-dong-chi-tiet.entity';
import { CreateHopDongChiTietDto } from './dto/create-hop-dong-chi-tiet.dto';
import { UpdateHopDongChiTietDto } from './dto/update-hop-dong-chi-tiet.dto';

@Injectable()
export class HopDongChiTietService {
  constructor(
    @InjectRepository(HopDongChiTiet)
    private readonly repo: Repository<HopDongChiTiet>,
  ) {}

  create(dto: CreateHopDongChiTietDto) {
    const entity = this.repo.create(dto);
    return this.repo.save(entity);
  }

  findAll() {
    return this.repo.find({
      relations: ['dichVu', 'hopDong', 'nguoiMat'],
    });
  }

  async findOne(id: string) {
    const item = await this.repo.findOne({
      where: { maHopDongChiTiet: id },
      relations: ['dichVu', 'hopDong', 'nguoiMat'],
    });
    if (!item) throw new NotFoundException('Không tìm thấy hợp đồng chi tiết');
    return item;
  }

  async update(id: string, dto: UpdateHopDongChiTietDto) {
    const existing = await this.repo.findOneBy({ maHopDongChiTiet: id });
    if (!existing) {
      throw new NotFoundException('Không tìm thấy hợp đồng chi tiết');
    }
    Object.assign(existing, dto);
    return this.repo.save(existing);
  }

  async remove(id: string) {
    const existing = await this.repo.findOneBy({ maHopDongChiTiet: id });
    if (!existing) {
      throw new NotFoundException('Không tìm thấy hợp đồng chi tiết');
    }
    return this.repo.remove(existing);
  }
}
