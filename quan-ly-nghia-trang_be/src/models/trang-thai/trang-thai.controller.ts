import {
  Controller,
  Get,
  Post,
  Body,
  Patch,
  Param,
  Delete,
} from '@nestjs/common';
import { TrangThaiService } from './trang-thai.service';
import { CreateTrangThaiDto } from './dto/create-trang-thai.dto';
import { UpdateTrangThaiDto } from './dto/update-trang-thai.dto';

@Controller('trang-thai')
export class TrangThaiController {
  constructor(private readonly service: TrangThaiService) {}

  @Post()
  create(@Body() dto: CreateTrangThaiDto) {
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
  update(@Param('id') id: string, @Body() dto: UpdateTrangThaiDto) {
    return this.service.update(id, dto);
  }

  @Delete(':id')
  remove(@Param('id') id: string) {
    return this.service.remove(id);
  }
}
