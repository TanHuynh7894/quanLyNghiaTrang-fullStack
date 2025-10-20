import {
  Controller,
  Get,
  Post,
  Body,
  Param,
  Patch,
  Delete,
} from '@nestjs/common';
import { HopDongService } from './hop-dong.service';
import { CreateHopDongDto } from './dto/create-hop-dong.dto';
import { UpdateHopDongDto } from './dto/update-hop-dong.dto';

@Controller('hop-dong')
export class HopDongController {
  constructor(private readonly service: HopDongService) {}

  @Post()
  create(@Body() dto: CreateHopDongDto) {
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
  update(@Param('id') id: string, @Body() dto: UpdateHopDongDto) {
    return this.service.update(id, dto);
  }

  @Delete(':id')
  remove(@Param('id') id: string) {
    return this.service.remove(id);
  }
}
