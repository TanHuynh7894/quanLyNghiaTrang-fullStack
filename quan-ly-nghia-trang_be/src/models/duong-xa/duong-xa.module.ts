// src/models/duong-xa/duong-xa.module.ts

import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { DuongXa } from './entities/duong-xa.entity';
import { DuongXaService } from './duong-xa.service';
import { DuongXaController } from './duong-xa.controller';

@Module({
  imports: [
    TypeOrmModule.forFeature([DuongXa]), // ĐĂNG KÝ REPO Ở ĐÂY
  ],
  controllers: [DuongXaController],
  providers: [DuongXaService],
  exports: [DuongXaService],
})
export class DuongXaModule {}
