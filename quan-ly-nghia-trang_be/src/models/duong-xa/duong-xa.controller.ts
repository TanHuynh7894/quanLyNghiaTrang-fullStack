// src/duong-xa/duong-xa.controller.ts
import { Controller, Get, Query, ParseFloatPipe } from '@nestjs/common';
import { DuongXaService } from './duong-xa.service';

@Controller('duong-xa')
export class DuongXaController {
  constructor(private readonly duongXaService: DuongXaService) {}

  // GET /duong-xa/route?fromLat=...&fromLng=...&toLat=...&toLng=...
  @Get('route')
  async getRoute(
    @Query('fromLat', ParseFloatPipe) fromLat: number,
    @Query('fromLng', ParseFloatPipe) fromLng: number,
    @Query('toLat', ParseFloatPipe) toLat: number,
    @Query('toLng', ParseFloatPipe) toLng: number,
  ) {
    return this.duongXaService.getRoute(fromLat, fromLng, toLat, toLng);
  }

  // (Optional) debug: GET /duong-xa/edges
  @Get('edges')
  async getEdges() {
    return this.duongXaService.getAllEdges();
  }
}
