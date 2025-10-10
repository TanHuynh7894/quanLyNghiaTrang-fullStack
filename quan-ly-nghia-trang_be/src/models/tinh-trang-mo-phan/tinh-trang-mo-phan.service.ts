import { Injectable, NotFoundException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { TinhTrangMoPhan } from './entities/tinh-trang-mo-phan.entity';

@Injectable()
export class TinhTrangMoPhanService {
  constructor(
    @InjectRepository(TinhTrangMoPhan)
    private readonly repo: Repository<TinhTrangMoPhan>,
  ) {}

  findAll() {
    return this.repo.find({ order: { ten_tinh_trang: 'ASC' } });
  }

  async findOne(ma_tinh_trang: string) {
    const found = await this.repo.findOne({ where: { ma_tinh_trang } });
    if (!found) {
      throw new NotFoundException('Không tìm thấy tình trạng mộ phần');
    }
    return found;
  }

  // Nếu bạn muốn tự sinh UUID khi thiếu, có thể dùng 'uuid' và set ở đây.
  async create(data: Partial<TinhTrangMoPhan>) {
    // Yêu cầu phải có ma_tinh_trang vì PrimaryColumn không tự sinh
    if (!data.ma_tinh_trang) {
      throw new Error('Thiếu ma_tinh_trang (uuid)'); // hoặc tự generate nếu muốn
    }
    const entity = this.repo.create({
      ma_tinh_trang: data.ma_tinh_trang,
      ten_tinh_trang: data.ten_tinh_trang!,
      color: data.color,
    });
    return this.repo.save(entity);
  }

  async update(ma_tinh_trang: string, data: Partial<TinhTrangMoPhan>) {
    const found = await this.repo.findOne({ where: { ma_tinh_trang } });
    if (!found) {
      throw new NotFoundException('Không tìm thấy tình trạng mộ phần');
    }
    // chỉ cập nhật các field cho phép
    if (typeof data.ten_tinh_trang === 'string') {
      found.ten_tinh_trang = data.ten_tinh_trang;
    }
    if (typeof data.color === 'string' || data.color === null) {
      found.color = data.color ?? null;
    }
    return this.repo.save(found);
  }

  async remove(ma_tinh_trang: string) {
    const res = await this.repo.delete({ ma_tinh_trang });
    if (!res.affected) {
      throw new NotFoundException('Không tìm thấy tình trạng mộ phần');
    }
    return { deleted: true };
  }
}
