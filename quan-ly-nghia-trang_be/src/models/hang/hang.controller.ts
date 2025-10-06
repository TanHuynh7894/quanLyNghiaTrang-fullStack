import { Controller, Get, Query, BadRequestException } from '@nestjs/common';
import { HangService } from './hang.service';
import type { FeatureCollection, Feature } from 'geojson';

@Controller('hang')
export class HangController {
  constructor(private readonly hangService: HangService) {}
  @Get()
  async unified(
    @Query('dia_chi') dia_chi?: string,
    @Query('ten_khu') ten_khu?: string,
    @Query('ten_hang') ten_hang?: string,
  ): Promise<Feature | FeatureCollection> {
    const dc = dia_chi?.trim();
    if (dc) {
      const [ma_khuRaw, ma_hangRaw] = dc.split('-', 2);
      const ma_khu = ma_khuRaw?.trim();
      const ma_hang = ma_hangRaw?.trim();

      if (!ma_khu) {
        throw new BadRequestException(
          'Định dạng dia_chi không hợp lệ. Ví dụ đúng: 6.1-A hoặc 6.1',
        );
      }
      if (ma_hang) {
        return this.hangService.findOneByTenKhuAndTenHang(ma_khu, ma_hang);
      }
      return this.hangService.findByTenKhu(ma_khu);
    }

    // 2) Không có dia_chi -> dùng ten_khu [/ ten_hang]
    const _tenKhu = ten_khu?.trim();
    const _tenHang = ten_hang?.trim();

    if (!_tenKhu) {
      throw new BadRequestException(
        'Thiếu tham số. Cung cấp "dia_chi=ma_khu[-ma_hang]" hoặc "ten_khu" (và tuỳ chọn "ten_hang").',
      );
    }

    if (_tenHang) {
      return this.hangService.findOneByTenKhuAndTenHang(_tenKhu, _tenHang);
    }
    return this.hangService.findByTenKhu(_tenKhu);
  }
}
