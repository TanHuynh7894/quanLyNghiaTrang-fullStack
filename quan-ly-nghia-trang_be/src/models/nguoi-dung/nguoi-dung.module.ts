import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { NguoiDung } from './entities/nguoi-dung.entity';
import { NguoiDungService } from './nguoi-dung.service';
import { NguoiDungController } from './nguoi-dung.controller';
import { TrangThai } from '../trang-thai/entities/trang-thai.entity';

@Module({
  imports: [TypeOrmModule.forFeature([NguoiDung, TrangThai])],
  controllers: [NguoiDungController],
  providers: [NguoiDungService],
  exports: [TypeOrmModule],
})
export class NguoiDungModule {}
