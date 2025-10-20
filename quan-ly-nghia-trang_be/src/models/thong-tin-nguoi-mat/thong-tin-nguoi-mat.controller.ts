import {
  Controller,
  Get,
  Post,
  Body,
  Param,
  Patch,
  Delete,
} from '@nestjs/common';
import { ThongTinNguoiMatService } from './thong-tin-nguoi-mat.service';
import { CreateThongTinNguoiMatDto } from './dto/create-thong-tin-nguoi-mat.dto';
import { UpdateThongTinNguoiMatDto } from './dto/update-thong-tin-nguoi-mat.dto';

@Controller('thong-tin-nguoi-mat')
export class ThongTinNguoiMatController {
  constructor(private readonly service: ThongTinNguoiMatService) {}

  @Post()
  create(@Body() dto: CreateThongTinNguoiMatDto) {
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
  update(@Param('id') id: string, @Body() dto: UpdateThongTinNguoiMatDto) {
    return this.service.update(id, dto);
  }

  @Delete(':id')
  remove(@Param('id') id: string) {
    return this.service.remove(id);
  }
}
