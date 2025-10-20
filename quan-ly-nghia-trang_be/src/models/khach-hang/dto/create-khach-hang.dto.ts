import {
  IsString,
  IsOptional,
  MaxLength,
  IsUUID,
  IsDateString,
} from 'class-validator';

export class CreateKhachHangDto {
  @IsString()
  @MaxLength(255)
  tenKhachHang!: string;

  @IsOptional()
  @IsString()
  @MaxLength(255)
  diaChi?: string;

  @IsOptional()
  @IsString()
  @MaxLength(10)
  soLienHe?: string;

  @IsOptional()
  @IsString()
  @MaxLength(20)
  quocTich?: string;

  @IsOptional()
  @IsString()
  @MaxLength(20)
  soCCCDHoChieu?: string;

  @IsOptional()
  @IsDateString()
  ngayCap?: Date;

  @IsOptional()
  @IsString()
  noiCap?: string;

  @IsOptional()
  @IsString()
  ghiChu?: string;

  @IsUUID()
  maNguoiDung!: string; // bắt buộc có người tạo
}
