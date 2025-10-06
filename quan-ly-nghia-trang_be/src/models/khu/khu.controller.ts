import { Controller, Get, Query } from '@nestjs/common';
import { KhuService } from './khu.service';

@Controller('khu')
export class KhuController {
  constructor(private readonly khuService: KhuService) {}

  @Get()
  find(@Query('ten_khu') ten_khu?: string) {
    return ten_khu
      ? this.khuService.findOneKhu(ten_khu)
      : this.khuService.findAllKhu();
  }
}
