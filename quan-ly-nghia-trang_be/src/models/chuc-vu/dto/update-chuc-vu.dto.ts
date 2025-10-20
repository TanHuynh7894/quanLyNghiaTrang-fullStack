import { PartialType } from '@nestjs/mapped-types';
import { CreateChucVuDto } from './create-chuc-vu.dto';
import { IsIn, IsOptional, IsString, MaxLength } from 'class-validator';

export class UpdateChucVuDto extends PartialType(CreateChucVuDto) {
  @IsOptional()
  @IsString()
  @MaxLength(255)
  tenChucVu?: string;

  @IsOptional()
  @IsIn(['0', '1'])
  tinhTrangHoatDong?: '0' | '1';
}
