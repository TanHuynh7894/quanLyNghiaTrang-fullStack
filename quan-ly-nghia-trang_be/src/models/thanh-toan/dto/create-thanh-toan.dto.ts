import {
  IsUUID,
  IsNumber,
  Min,
  IsOptional,
  IsString,
  MaxLength,
  IsDateString,
} from 'class-validator';
import { Type } from 'class-transformer';

export class CreateThanhToanDto {
  @IsUUID()
  maHopDong!: string;

  @Type(() => Number)
  @IsNumber({ maxDecimalPlaces: 2 })
  @Min(0)
  soTienThanhToan!: number;

  // ISO string, ví dụ "2025-10-20T09:30:00+07:00"
  @IsDateString()
  ngayThanhToan!: string; // nhận string; service sẽ convert sang Date

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
