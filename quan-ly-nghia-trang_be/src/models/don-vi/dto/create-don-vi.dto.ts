import {
  IsIn,
  IsNotEmpty,
  IsOptional,
  IsString,
  MaxLength,
  IsUUID,
} from 'class-validator';

export class CreateDonViDto {
  @IsString()
  @IsNotEmpty()
  @MaxLength(255)
  tenDonVi!: string;

  @IsOptional()
  @IsUUID()
  maDonViCha?: string;

  @IsOptional()
  @IsString()
  @MaxLength(255)
  diaChi?: string;

  @IsOptional()
  @IsString()
  @MaxLength(10)
  soDienThoai?: string;

  @IsOptional()
  @IsString()
  @MaxLength(15)
  maSoThue?: string;

  @IsOptional()
  @IsString()
  @MaxLength(35)
  soTaiKhoan?: string;

  @IsOptional()
  @IsString()
  @MaxLength(10)
  kyHieuHoaDon?: string;

  @IsOptional()
  @IsIn(['0', '1'])
  tinhTrangHoatDong?: '0' | '1';
}
