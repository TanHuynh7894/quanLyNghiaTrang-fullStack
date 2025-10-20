import { Injectable, NotFoundException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { ThongTinNguoiMat } from './entities/thong-tin-nguoi-mat.entity';
import { CreateThongTinNguoiMatDto } from './dto/create-thong-tin-nguoi-mat.dto';
import { UpdateThongTinNguoiMatDto } from './dto/update-thong-tin-nguoi-mat.dto';

@Injectable()
export class ThongTinNguoiMatService {
  constructor(
    @InjectRepository(ThongTinNguoiMat)
    private readonly repo: Repository<ThongTinNguoiMat>,
  ) {}

  create(dto: CreateThongTinNguoiMatDto) {
    const entity = this.repo.create(dto);
    return this.repo.save(entity);
  }

  findAll() {
    return this.repo.find({ relations: ['khachHang'] });
  }

  async findOne(id: string) {
    const item = await this.repo.findOne({
      where: { maNguoiMat: id },
      relations: ['khachHang'],
    });
    if (!item) throw new NotFoundException('Không tìm thấy người mất');
    return item;
  }

  async update(id: string, dto: UpdateThongTinNguoiMatDto) {
    const existing = await this.repo.findOneBy({ maNguoiMat: id });
    if (!existing) throw new NotFoundException('Không tìm thấy người mất');
    Object.assign(existing, dto);
    return this.repo.save(existing);
  }

  async remove(id: string) {
    const existing = await this.repo.findOneBy({ maNguoiMat: id });
    if (!existing) throw new NotFoundException('Không tìm thấy người mất');
    return this.repo.remove(existing);
  }
}
