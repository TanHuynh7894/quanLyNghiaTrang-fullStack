// src/models/dich-vu/dto/update-dich-vu.dto.ts
import { PartialType } from '@nestjs/mapped-types';
import { CreateDichVuDto } from './create-dich-vu.dto';
import {
  IsIn,
  IsNumber,
  IsOptional,
  IsString,
  MaxLength,
  Min,
} from 'class-validator';
import { Type } from 'class-transformer';

export class UpdateDichVuDto extends PartialType(CreateDichVuDto) {
  @IsOptional()
  @IsString()
  @MaxLength(255)
  loaiDichVu?: string;

  @IsOptional()
  @Type(() => Number)
  @IsNumber({ maxDecimalPlaces: 2 })
  @Min(0)
  chiPhiDichVu?: number;

  @IsOptional()
  @IsIn(['0', '1'])
  tinhTrangHoatDong?: '0' | '1';

  @IsOptional()
  @IsString()
  ghiChu?: string;
}
