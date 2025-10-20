import { Injectable, NotFoundException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { ThanhToan } from './entities/thanh-toan.entity';
import { CreateThanhToanDto } from './dto/create-thanh-toan.dto';
import { UpdateThanhToanDto } from './dto/update-thanh-toan.dto';

@Injectable()
export class ThanhToanService {
  constructor(
    @InjectRepository(ThanhToan)
    private readonly repo: Repository<ThanhToan>,
  ) {}

  async create(dto: CreateThanhToanDto) {
    const entity = this.repo.create({
      ...dto,
      ngayThanhToan: new Date(dto.ngayThanhToan),
    });
    return this.repo.save(entity);
  }

  async findAll() {
    return this.repo.find();
  }

  async findOne(id: string) {
    const item = await this.repo.findOne({ where: { maDotThanhToan: id } });
    if (!item) throw new NotFoundException('Không tìm thấy đợt thanh toán');
    return item;
  }

  async update(id: string, dto: UpdateThanhToanDto) {
    const item = await this.repo.findOne({ where: { maDotThanhToan: id } });
    if (!item) throw new NotFoundException('Không tìm thấy đợt thanh toán');

    Object.assign(item, {
      ...dto,
      ...(dto.ngayThanhToan
        ? { ngayThanhToan: new Date(dto.ngayThanhToan) }
        : null),
    });

    return this.repo.save(item);
  }

  async remove(id: string) {
    const res = await this.repo.delete(id);
    if (!res.affected) {
      throw new NotFoundException('Không tìm thấy đợt thanh toán');
    }
    return { success: true };
  }
}
