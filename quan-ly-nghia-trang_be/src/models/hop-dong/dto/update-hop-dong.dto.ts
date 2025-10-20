import { PartialType } from '@nestjs/mapped-types';
import { CreateHopDongDto } from './create-hop-dong.dto';

export class UpdateHopDongDto extends PartialType(CreateHopDongDto) {}
