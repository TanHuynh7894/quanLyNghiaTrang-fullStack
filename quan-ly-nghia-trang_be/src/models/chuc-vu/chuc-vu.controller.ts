import {
  Controller,
  Get,
  Post,
  Body,
  Param,
  Patch,
  Delete,
  ParseUUIDPipe,
} from '@nestjs/common';
import { ChucVuService } from './chuc-vu.service';
import { CreateChucVuDto } from './dto/create-chuc-vu.dto';
import { UpdateChucVuDto } from './dto/update-chuc-vu.dto';

@Controller('chuc-vu')
export class ChucVuController {
  constructor(private readonly service: ChucVuService) {}

  @Post()
  create(@Body() dto: CreateChucVuDto) {
    return this.service.create(dto);
  }

  @Get()
  findAll() {
    return this.service.findAll();
  }

  @Get(':id')
  findOne(@Param('id', new ParseUUIDPipe()) id: string) {
    return this.service.findOne(id);
  }

  @Patch(':id')
  update(
    @Param('id', new ParseUUIDPipe()) id: string,
    @Body() dto: UpdateChucVuDto,
  ) {
    return this.service.update(id, dto);
  }

  @Delete(':id')
  remove(@Param('id', new ParseUUIDPipe()) id: string) {
    return this.service.remove(id);
  }
}
