import {
  Body,
  Controller,
  Delete,
  Get,
  Param,
  Post,
  Put,
} from '@nestjs/common';
import { TinhTrangMoPhanService } from './tinh-trang-mo-phan.service';

@Controller('tinh-trang-mo-phan')
export class TinhTrangMoPhanController {
  constructor(private readonly service: TinhTrangMoPhanService) {}

  @Get()
  findAll() {
    return this.service.findAll();
  }

  @Get(':ma_tinh_trang')
  findOne(@Param('ma_tinh_trang') ma_tinh_trang: string) {
    return this.service.findOne(ma_tinh_trang);
  }

  @Post()
  create(
    @Body()
    body: {
      ma_tinh_trang: string;
      ten_tinh_trang: string;
      color?: string | null;
    },
  ) {
    return this.service.create(body);
  }

  @Put(':ma_tinh_trang')
  update(
    @Param('ma_tinh_trang') ma_tinh_trang: string,
    @Body() body: { ten_tinh_trang?: string; color?: string | null },
  ) {
    return this.service.update(ma_tinh_trang, body);
  }

  @Delete(':ma_tinh_trang')
  remove(@Param('ma_tinh_trang') ma_tinh_trang: string) {
    return this.service.remove(ma_tinh_trang);
  }
}
