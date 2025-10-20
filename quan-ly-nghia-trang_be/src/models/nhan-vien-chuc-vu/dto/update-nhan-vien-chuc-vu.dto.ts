import { PartialType } from '@nestjs/mapped-types';
import { CreateNhanVienChucVuDto } from './create-nhan-vien-chuc-vu.dto';
export class UpdateNhanVienChucVuDto extends PartialType(
  CreateNhanVienChucVuDto,
) {}
