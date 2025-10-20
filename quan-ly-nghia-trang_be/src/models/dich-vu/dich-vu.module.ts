// src/models/dich-vu/dich-vu.module.ts
import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { DichVuService } from './dich-vu.service';
import { DichVuController } from './dich-vu.controller';
import { DichVu } from './entities/dich-vu.entity';

@Module({
  imports: [TypeOrmModule.forFeature([DichVu])],
  controllers: [DichVuController],
  providers: [DichVuService],
  exports: [DichVuService],
})
export class DichVuModule {}
