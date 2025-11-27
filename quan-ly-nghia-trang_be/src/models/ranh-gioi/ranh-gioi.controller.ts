// src/models/ranh-gioi/ranh-gioi.controller.ts
import { Controller, Get } from '@nestjs/common';
import type { FeatureCollection } from 'geojson';
import { RanhGioiService } from './ranh-gioi.service';

@Controller('ranh-gioi')
export class RanhGioiController {
  constructor(private readonly ranhGioiService: RanhGioiService) {}

  @Get()
  async getAll(): Promise<FeatureCollection> {
    return this.ranhGioiService.getAll();
  }
}
