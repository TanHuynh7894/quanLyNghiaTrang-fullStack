import { PartialType } from '@nestjs/mapped-types';
import { CreateNguoiDungDto } from './create-nguoi-dung.dto';
import {
  IsOptional,
  IsString,
  MinLength,
  MaxLength,
  IsUUID,
} from 'class-validator';

export class UpdateNguoiDungDto extends PartialType(CreateNguoiDungDto) {
  // Cập nhật tên tài khoản
  @IsOptional()
  @IsString()
  @MaxLength(255)
  tenTaiKhoan?: string;

  // Cập nhật mật khẩu (hash lại tự động trong entity)
  @IsOptional()
  @IsString()
  @MinLength(6)
  @MaxLength(100)
  matKhau?: string;

  // Cập nhật trạng thái (UUID của bảng trang_thai)
  @IsOptional()
  @IsUUID()
  maTrangThai?: string;
}
