// src/models/dich-vu/dto/create-dich-vu.dto.ts
import {
  IsIn,
  IsNotEmpty,
  IsOptional,
  IsString,
  MaxLength,
  Min,
  IsNumber,
} from 'class-validator';
import { Type } from 'class-transformer';

export class CreateDichVuDto {
  @IsString()
  @IsNotEmpty()
  @MaxLength(255)
  loaiDichVu!: string;

  // ép về number an toàn
  @Type(() => Number)
  @IsNumber({ maxDecimalPlaces: 2 })
  @Min(0)
  chiPhiDichVu!: number;

  // '1' = hoạt động, '0' = ngừng
  @IsOptional()
  @IsIn(['0', '1'])
  tinhTrangHoatDong?: '0' | '1';

  @IsOptional()
  @IsString()
  ghiChu?: string;
}
