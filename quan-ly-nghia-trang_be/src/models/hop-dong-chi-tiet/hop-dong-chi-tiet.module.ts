import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { HopDongChiTiet } from './entities/hop-dong-chi-tiet.entity';
import { HopDongChiTietService } from './hop-dong-chi-tiet.service';
import { HopDongChiTietController } from './hop-dong-chi-tiet.controller';

@Module({
  imports: [TypeOrmModule.forFeature([HopDongChiTiet])],
  controllers: [HopDongChiTietController],
  providers: [HopDongChiTietService],
  exports: [HopDongChiTietService, TypeOrmModule],
})
export class HopDongChiTietModule {}
