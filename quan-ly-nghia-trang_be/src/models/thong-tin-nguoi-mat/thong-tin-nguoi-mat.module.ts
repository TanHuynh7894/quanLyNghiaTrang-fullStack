import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { ThongTinNguoiMat } from './entities/thong-tin-nguoi-mat.entity';
import { ThongTinNguoiMatService } from './thong-tin-nguoi-mat.service';
import { ThongTinNguoiMatController } from './thong-tin-nguoi-mat.controller';

@Module({
  imports: [TypeOrmModule.forFeature([ThongTinNguoiMat])],
  controllers: [ThongTinNguoiMatController],
  providers: [ThongTinNguoiMatService],
  exports: [ThongTinNguoiMatService],
})
export class ThongTinNguoiMatModule {}
