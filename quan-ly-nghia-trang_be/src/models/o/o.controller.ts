import { Controller, Get, Query, BadRequestException } from '@nestjs/common';
import { OService } from './o.service';
import type { Feature, FeatureCollection } from 'geojson';

@Controller('o')
export class OController {
  constructor(private readonly oService: OService) {}

  @Get()
  async getO(
    @Query('dia_chi') dia_chi?: string,
    @Query('ten_nguoi_mat') ten_nguoi_mat?: string,
    @Query('ten_khu') ten_khu?: string,
    @Query('ten_hang') ten_hang?: string,
    @Query('ten_o') ten_o?: string,
  ): Promise<Feature | FeatureCollection> {
    // 1) Ưu tiên tìm trực tiếp theo địa chỉ ô
    if (dia_chi?.trim()) {
      return this.oService.findOneByDiaChi(dia_chi.trim());
    }

    // 2) Tìm theo tên người mất (lookup -> diaChiO -> trả về ô)
    if (ten_nguoi_mat?.trim()) {
      return this.oService.findOneByTenNguoiMat(ten_nguoi_mat.trim());
    }

    // 3) Tìm 1 ô cụ thể theo tên khu/hàng/ô
    if (ten_khu?.trim() && ten_hang?.trim() && ten_o?.trim()) {
      return this.oService.findOneByTen(
        ten_khu.trim(),
        ten_hang.trim(),
        ten_o.trim(),
      );
    }

    // 4) Tìm danh sách ô theo tên khu + tên hàng
    if (ten_khu?.trim() && ten_hang?.trim()) {
      return this.oService.findByTenKhuAndTenHang(
        ten_khu.trim(),
        ten_hang.trim(),
      );
    }

    throw new BadRequestException(
      'Thiếu tham số. Cần một trong các bộ: dia_chi | ten_nguoi_mat | (ten_khu, ten_hang, ten_o) | (ten_khu, ten_hang)',
    );
  }
}
