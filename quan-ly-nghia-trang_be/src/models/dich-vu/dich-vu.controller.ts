// src/models/dich-vu/dich-vu.controller.ts
import {
  Controller,
  Get,
  Post,
  Put,
  Delete,
  Param,
  Body,
} from '@nestjs/common';
import { DichVuService } from './dich-vu.service';
import { DichVu } from './entities/dich-vu.entity';
import { DichVuResponseDto } from './dto/dich-vu-response.dto';

@Controller('dich-vu')
export class DichVuController {
  constructor(private readonly service: DichVuService) {}

  @Get()
  findAll(): Promise<DichVuResponseDto[]> {
    return this.service.findAll();
  }

  @Get(':id')
  findOne(@Param('id') id: string): Promise<DichVuResponseDto | null> {
    return this.service.findOne(id);
  }

  @Post()
  create(@Body() dto: Partial<DichVu>): Promise<DichVu> {
    return this.service.create(dto);
  }

  @Put(':id')
  update(@Param('id') id: string, @Body() dto: Partial<DichVu>) {
    return this.service.update(id, dto);
  }

  @Delete(':id')
  remove(@Param('id') id: string) {
    return this.service.remove(id);
  }
}
