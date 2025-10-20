import { Controller, Get, Param } from '@nestjs/common';
import { NhanVienChucVuService } from './nhan-vien-chuc-vu.service';

@Controller('nhan-vien-chuc-vu')
export class NhanVienChucVuController {
  constructor(private readonly service: NhanVienChucVuService) {}

  // Lấy toàn bộ danh sách (ma_chuc_vu, ma_nhan_vien)
  @Get()
  async findAll() {
    return this.service.findAll();
  }

  // Lấy tất cả chức vụ của một nhân viên
  @Get('nhan-vien/:maNhanVien')
  async findByNhanVien(@Param('maNhanVien') maNhanVien: string) {
    return this.service.findByNhanVien(maNhanVien);
  }

  // Lấy tất cả nhân viên của một chức vụ
  @Get('chuc-vu/:maChucVu')
  async findByChucVu(@Param('maChucVu') maChucVu: string) {
    return this.service.findByChucVu(maChucVu);
  }
}
