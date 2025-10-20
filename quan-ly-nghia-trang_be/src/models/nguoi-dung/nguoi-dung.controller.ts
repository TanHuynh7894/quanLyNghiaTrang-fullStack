// src/models/nguoi-dung/nguoi-dung.controller.ts
import {
  Controller,
  Get,
  Post,
  Body,
  Patch,
  Param,
  Delete,
  Query,
  ParseIntPipe,
  ParseUUIDPipe,
} from '@nestjs/common';
import { NguoiDungService } from './nguoi-dung.service';
import { CreateNguoiDungDto } from './dtos/create-nguoi-dung.dto';
import { UpdateNguoiDungDto } from './dtos/update-nguoi-dung.dto';

@Controller('nguoi-dung')
export class NguoiDungController {
  constructor(private readonly service: NguoiDungService) {}

  @Post()
  create(@Body() dto: CreateNguoiDungDto) {
    return this.service.create(dto);
  }

  @Get()
  findAll(
    @Query('page', new ParseIntPipe({ optional: true })) page = 1,
    @Query('limit', new ParseIntPipe({ optional: true })) limit = 20,
    @Query('q') q?: string,
  ) {
    return this.service.findAll(page, limit, q);
  }

  @Get(':id')
  findOne(@Param('id', new ParseUUIDPipe()) id: string) {
    return this.service.findOne(id);
  }

  @Patch(':id')
  update(
    @Param('id', new ParseUUIDPipe()) id: string,
    @Body() dto: UpdateNguoiDungDto,
  ) {
    return this.service.update(id, dto);
  }

  @Delete(':id')
  remove(@Param('id', new ParseUUIDPipe()) id: string) {
    return this.service.remove(id);
  }
}
