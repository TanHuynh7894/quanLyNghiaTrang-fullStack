import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { LookupService } from './lookup/lookup.service';
import { Khu } from '../models/khu/entities/khu.entity';
import { Hang } from '../models/hang/entities/hang.entity';

@Module({
  imports: [TypeOrmModule.forFeature([Khu, Hang])],
  providers: [LookupService],
  exports: [LookupService, HelperModule],
})
export class HelperModule {}
