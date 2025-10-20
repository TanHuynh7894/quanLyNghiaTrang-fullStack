import {
  IsEmail,
  IsIn,
  IsNotEmpty,
  IsOptional,
  IsString,
  IsUUID,
  Length,
  MaxLength,
} from 'class-validator';

export class CreateNhanVienDto {
  @IsString()
  @IsNotEmpty()
  @MaxLength(255)
  tenNhanVien!: string;

  @IsUUID()
  maDonVi!: string;

  @IsOptional()
  @IsIn(['nam', 'nu', 'khac'])
  gioiTinh?: 'nam' | 'nu' | 'khac';

  @IsOptional()
  @IsString()
  @Length(10, 10)
  soDienThoai?: string;

  @IsOptional()
  @IsEmail()
  @MaxLength(255)
  email?: string;

  @IsOptional()
  @IsString()
  tinhTrangLamViec?: string;

  @IsOptional()
  @IsString()
  @MaxLength(100)
  hinhAnh?: string;
}
