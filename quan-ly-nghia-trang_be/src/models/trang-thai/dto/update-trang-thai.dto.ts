import { PartialType } from '@nestjs/mapped-types';
import { CreateTrangThaiDto } from './create-trang-thai.dto';

export class UpdateTrangThaiDto extends PartialType(CreateTrangThaiDto) {}
