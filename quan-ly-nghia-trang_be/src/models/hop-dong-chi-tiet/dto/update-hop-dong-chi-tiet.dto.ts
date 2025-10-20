import { PartialType } from '@nestjs/mapped-types';
import { CreateHopDongChiTietDto } from './create-hop-dong-chi-tiet.dto';

export class UpdateHopDongChiTietDto extends PartialType(
  CreateHopDongChiTietDto,
) {}
