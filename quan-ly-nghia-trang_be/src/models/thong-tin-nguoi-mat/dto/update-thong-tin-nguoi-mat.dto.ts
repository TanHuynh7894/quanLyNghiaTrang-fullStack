import { PartialType } from '@nestjs/mapped-types';
import { CreateThongTinNguoiMatDto } from './create-thong-tin-nguoi-mat.dto';

export class UpdateThongTinNguoiMatDto extends PartialType(
  CreateThongTinNguoiMatDto,
) {}
