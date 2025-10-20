import { Injectable, NotFoundException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { TrangThai } from './entities/trang-thai.entity';
import { CreateTrangThaiDto } from './dto/create-trang-thai.dto';
import { UpdateTrangThaiDto } from './dto/update-trang-thai.dto';

@Injectable()
export class TrangThaiService {
  constructor(
    @InjectRepository(TrangThai)
    private readonly repo: Repository<TrangThai>,
  ) {}

  create(dto: CreateTrangThaiDto) {
    const entity = this.repo.create(dto);
    return this.repo.save(entity);
  }

  findAll() {
    return this.repo.find();
  }

  async findOne(id: string) {
    const entity = await this.repo.findOne({ where: { maTrangThai: id } });
    if (!entity) throw new NotFoundException('Không tìm thấy trạng thái');
    return entity;
  }

  async update(id: string, dto: UpdateTrangThaiDto) {
    const entity = await this.findOne(id);
    Object.assign(entity, dto);
    return this.repo.save(entity);
  }

  async remove(id: string) {
    const entity = await this.findOne(id);
    await this.repo.remove(entity);
    return { success: true };
  }
}
