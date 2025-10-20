import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { NhanVienChucVu } from './entities/nhan-vien-chuc-vu.entity';
import { NhanVienChucVuService } from './nhan-vien-chuc-vu.service';
import { NhanVienChucVuController } from './nhan-vien-chuc-vu.controller';

@Module({
  imports: [TypeOrmModule.forFeature([NhanVienChucVu])],
  controllers: [NhanVienChucVuController],
  providers: [NhanVienChucVuService],
  exports: [NhanVienChucVuService],
})
export class NhanVienChucVuModule {}
