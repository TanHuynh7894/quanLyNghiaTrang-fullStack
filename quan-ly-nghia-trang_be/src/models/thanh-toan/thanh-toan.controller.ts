import {
  Controller,
  Get,
  Post,
  Body,
  Patch,
  Param,
  Delete,
  ParseUUIDPipe,
} from '@nestjs/common';
import { ThanhToanService } from './thanh-toan.service';
import { CreateThanhToanDto } from './dto/create-thanh-toan.dto';
import { UpdateThanhToanDto } from './dto/update-thanh-toan.dto';

@Controller('thanh-toan')
export class ThanhToanController {
  constructor(private readonly service: ThanhToanService) {}

  @Post()
  create(@Body() dto: CreateThanhToanDto) {
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
    @Body() dto: UpdateThanhToanDto,
  ) {
    return this.service.update(id, dto);
  }

  @Delete(':id')
  remove(@Param('id', new ParseUUIDPipe()) id: string) {
    return this.service.remove(id);
  }
}
