import { Controller, Get, Query, BadRequestException } from '@nestjs/common';
import { OService } from './o.service';
import type { Feature, FeatureCollection } from 'geojson';

@Controller('o')
export class OController {
  constructor(private readonly oService: OService) {}

  @Get()
  async getO(
    @Query('dia_chi') dia_chi?: string,
    @Query('ten_khu') ten_khu?: string,
    @Query('ten_hang') ten_hang?: string,
    @Query('ten_o') ten_o?: string,
  ): Promise<Feature | FeatureCollection> {
    if (dia_chi?.trim()) {
      return this.oService.findOneByDiaChi(dia_chi.trim());
    }

    if (ten_khu?.trim() && ten_hang?.trim() && ten_o?.trim()) {
      return this.oService.findOneByTen(
        ten_khu.trim(),
        ten_hang.trim(),
        ten_o.trim(),
      );
    }

    if (ten_khu?.trim() && ten_hang?.trim()) {
      return this.oService.findByTenKhuAndTenHang(
        ten_khu.trim(),
        ten_hang.trim(),
      );
    }

    throw new BadRequestException('Thiếu tham số');
  }
}
