import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { KhachHang } from './entities/khach-hang.entity';
import { KhachHangService } from './khach-hang.service';
import { KhachHangController } from './khach-hang.controller';
import { NguoiDung } from '../nguoi-dung/entities/nguoi-dung.entity';

@Module({
  imports: [TypeOrmModule.forFeature([KhachHang, NguoiDung])],
  controllers: [KhachHangController],
  providers: [KhachHangService],
})
export class KhachHangModule {}
