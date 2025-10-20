import { IsDateString, IsOptional, IsUUID } from 'class-validator';

export class CreateNhanVienChucVuDto {
  @IsUUID()
  maNhanVien!: string;

  @IsUUID()
  maChucVu!: string;

  @IsOptional()
  @IsDateString()
  ngayBoNhiem?: string;
}
