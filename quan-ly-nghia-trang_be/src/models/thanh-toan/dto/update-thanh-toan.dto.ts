import { PartialType } from '@nestjs/mapped-types';
import { CreateThanhToanDto } from './create-thanh-toan.dto';
import {
  IsDateString,
  IsNumber,
  IsOptional,
  IsString,
  MaxLength,
  Min,
  IsUUID,
} from 'class-validator';
import { Type } from 'class-transformer';

export class UpdateThanhToanDto extends PartialType(CreateThanhToanDto) {
  @IsOptional()
  @IsUUID()
  maHopDong?: string;

  @IsOptional()
  @Type(() => Number)
  @IsNumber({ maxDecimalPlaces: 2 })
  @Min(0)
  soTienThanhToan?: number;

  @IsOptional()
  @IsDateString()
  ngayThanhToan?: string;

  @IsOptional()
  @IsString()
  @MaxLength(255)
  hinhThucThanhToan?: string;

  @IsOptional()
  @IsString()
  noiDung?: string;

  @IsOptional()
  @IsString()
  ghiChu?: string;
}
