import { IsNotEmpty, IsString, MaxLength } from 'class-validator';

export class CreateTrangThaiDto {
  @IsString()
  @IsNotEmpty()
  @MaxLength(255)
  tenTrangThai!: string;
}
