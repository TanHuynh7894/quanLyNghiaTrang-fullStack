import {
  IsIn,
  IsNotEmpty,
  IsOptional,
  IsString,
  MaxLength,
} from 'class-validator';

export class CreateChucVuDto {
  @IsString()
  @IsNotEmpty()
  @MaxLength(255)
  tenChucVu!: string;

  @IsOptional()
  @IsIn(['0', '1'])
  tinhTrangHoatDong?: '0' | '1';
}
