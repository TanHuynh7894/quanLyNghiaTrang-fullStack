import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { TrangThai } from './entities/trang-thai.entity';
import { TrangThaiService } from './trang-thai.service';
import { TrangThaiController } from './trang-thai.controller';

@Module({
  imports: [TypeOrmModule.forFeature([TrangThai])],
  controllers: [TrangThaiController],
  providers: [TrangThaiService],
  exports: [TrangThaiService],
})
export class TrangThaiModule {}
