import { Injectable, NotFoundException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { NhanVien } from './entities/nhan-vien.entity';
import { CreateNhanVienDto } from './dto/create-nhan-vien.dto';
import { UpdateNhanVienDto } from './dto/update-nhan-vien.dto';
import { NhanVienChucVu } from '../nhan-vien-chuc-vu/entities/nhan-vien-chuc-vu.entity';

@Injectable()
export class NhanVienService {
  constructor(
    @InjectRepository(NhanVien)
    private readonly repo: Repository<NhanVien>,
    @InjectRepository(NhanVienChucVu)
    private readonly nvcvRepo: Repository<NhanVienChucVu>,
  ) {}

  async create(dto: CreateNhanVienDto) {
    const row = this.repo.create(dto);
    return this.repo.save(row);
  }

  // Trả về donVi dưới dạng object { maDonVi, tenDonVi }
  async findAll() {
    const list = await this.repo.find({ relations: { donVi: true } });
    return list.map((nv) => ({
      maNhanVien: nv.maNhanVien,
      tenNhanVien: nv.tenNhanVien,
      gioiTinh: nv.gioiTinh,
      soDienThoai: nv.soDienThoai,
      email: nv.email,
      tinhTrangLamViec: nv.tinhTrangLamViec,
      hinhAnh: nv.hinhAnh,
      maDonVi: {
        maDonVi: nv.maDonVi,
        tenDonVi: nv.donVi?.tenDonVi ?? null,
      },
    }));
  }

  async findOne(id: string) {
    const nv = await this.repo.findOne({
      where: { maNhanVien: id },
      relations: { donVi: true },
    });
    if (!nv) throw new NotFoundException('Không tìm thấy nhân viên');

    // lấy danh sách chức vụ của nhân viên
    const roles = await this.nvcvRepo.find({
      where: { maNhanVien: id },
      relations: { chucVu: true },
    });

    const chucVus = roles.map((r) => ({
      maChucVu: r.maChucVu,
      tenChucVu: r.chucVu?.tenChucVu ?? null,
    }));

    return {
      maNhanVien: nv.maNhanVien,
      tenNhanVien: nv.tenNhanVien,
      gioiTinh: nv.gioiTinh,
      soDienThoai: nv.soDienThoai,
      email: nv.email,
      tinhTrangLamViec: nv.tinhTrangLamViec,
      hinhAnh: nv.hinhAnh,
      maDonVi: {
        maDonVi: nv.maDonVi,
        tenDonVi: nv.donVi?.tenDonVi ?? null,
      },
      chucVus,
    };
  }

  async update(id: string, dto: UpdateNhanVienDto) {
    const nv = await this.repo.findOne({ where: { maNhanVien: id } });
    if (!nv) throw new NotFoundException('Không tìm thấy nhân viên');
    Object.assign(nv, dto);
    return this.repo.save(nv);
  }

  async remove(id: string) {
    const res = await this.repo.delete(id);
    if (!res.affected) throw new NotFoundException('Không tìm thấy nhân viên');
    return { success: true };
  }
}
