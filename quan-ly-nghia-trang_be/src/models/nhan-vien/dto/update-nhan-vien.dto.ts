import { PartialType } from '@nestjs/mapped-types';
import { CreateNhanVienDto } from './create-nhan-vien.dto';
import {
  IsEmail,
  IsIn,
  IsOptional,
  IsString,
  IsUUID,
  Length,
  MaxLength,
} from 'class-validator';

export class UpdateNhanVienDto extends PartialType(CreateNhanVienDto) {
  @IsOptional() @IsString() @MaxLength(255) tenNhanVien?: string;
  @IsOptional() @IsUUID() maDonVi?: string;
  @IsOptional() @IsIn(['nam', 'nu', 'khac']) gioiTinh?: 'nam' | 'nu' | 'khac';
  @IsOptional() @IsString() @Length(10, 10) soDienThoai?: string;
  @IsOptional() @IsEmail() @MaxLength(255) email?: string;
  @IsOptional() @IsString() tinhTrangLamViec?: string;
  @IsOptional() @IsString() @MaxLength(100) hinhAnh?: string;
}
