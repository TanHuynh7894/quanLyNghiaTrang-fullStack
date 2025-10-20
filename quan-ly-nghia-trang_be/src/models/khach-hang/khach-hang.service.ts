import { Injectable, NotFoundException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { KhachHang } from './entities/khach-hang.entity';
import { CreateKhachHangDto } from './dto/create-khach-hang.dto';
import { UpdateKhachHangDto } from './dto/update-khach-hang.dto';
import { NguoiDung } from '../nguoi-dung/entities/nguoi-dung.entity';

@Injectable()
export class KhachHangService {
  constructor(
    @InjectRepository(KhachHang) private readonly repo: Repository<KhachHang>,
    @InjectRepository(NguoiDung)
    private readonly userRepo: Repository<NguoiDung>,
  ) {}

  async create(dto: CreateKhachHangDto) {
    const nguoiDung = await this.userRepo.findOne({
      where: { id: dto.maNguoiDung },
    });
    if (!nguoiDung) {
      throw new NotFoundException('Không tìm thấy người dùng liên kết');
    }

    const entity = this.repo.create({ ...dto });
    return this.repo.save(entity);
  }

  async findAll() {
    return this.repo.find({ relations: ['nguoiDung', 'nguoiDung.trangThai'] });
  }

  async findOne(id: string) {
    const kh = await this.repo.findOne({
      where: { maKhachHang: id },
      relations: ['nguoiDung', 'nguoiDung.trangThai'],
    });
    if (!kh) throw new NotFoundException('Không tìm thấy khách hàng');
    return kh;
  }

  async update(id: string, dto: UpdateKhachHangDto) {
    const kh = await this.repo.findOne({ where: { maKhachHang: id } });
    if (!kh) throw new NotFoundException('Không tìm thấy khách hàng');

    Object.assign(kh, dto);
    return this.repo.save(kh);
  }

  async remove(id: string) {
    const res = await this.repo.delete(id);
    if (!res.affected) throw new NotFoundException('Không tìm thấy khách hàng');
    return { success: true };
  }
}
