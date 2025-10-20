import {
  Controller,
  Get,
  Post,
  Body,
  Param,
  Patch,
  Delete,
} from '@nestjs/common';
import { HopDongChiTietService } from './hop-dong-chi-tiet.service';
import { CreateHopDongChiTietDto } from './dto/create-hop-dong-chi-tiet.dto';
import { UpdateHopDongChiTietDto } from './dto/update-hop-dong-chi-tiet.dto';

@Controller('hop-dong-chi-tiet')
export class HopDongChiTietController {
  constructor(private readonly service: HopDongChiTietService) {}

  @Post()
  create(@Body() dto: CreateHopDongChiTietDto) {
    return this.service.create(dto);
  }

  @Get()
  findAll() {
    return this.service.findAll();
  }

  @Get(':id')
  findOne(@Param('id') id: string) {
    return this.service.findOne(id);
  }

  @Patch(':id')
  update(@Param('id') id: string, @Body() dto: UpdateHopDongChiTietDto) {
    return this.service.update(id, dto);
  }

  @Delete(':id')
  remove(@Param('id') id: string) {
    return this.service.remove(id);
  }
}
