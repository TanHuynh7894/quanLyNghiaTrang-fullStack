import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { NhanVien } from './entities/nhan-vien.entity';
import { NhanVienService } from './nhan-vien.service';
import { NhanVienController } from './nhan-vien.controller';
import { DonVi } from '../don-vi/entities/don-vi.entity';
import { ChucVu } from '../chuc-vu/entities/chuc-vu.entity';
import { NhanVienChucVu } from '../nhan-vien-chuc-vu/entities/nhan-vien-chuc-vu.entity';

@Module({
  imports: [
    TypeOrmModule.forFeature([NhanVien, DonVi, ChucVu, NhanVienChucVu]),
  ],
  controllers: [NhanVienController],
  providers: [NhanVienService],
})
export class NhanVienModule {}
