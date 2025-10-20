import { IsString, MaxLength, MinLength } from 'class-validator';

export class CreateNguoiDungDto {
  @IsString()
  @MaxLength(255)
  tenTaiKhoan!: string;

  @IsString()
  @MinLength(6)
  @MaxLength(100)
  matKhau!: string;
}
