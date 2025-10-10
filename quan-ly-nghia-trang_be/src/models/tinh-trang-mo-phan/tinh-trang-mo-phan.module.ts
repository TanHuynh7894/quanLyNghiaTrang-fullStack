import { Module } from '@nestjs/common';
import { TinhTrangMoPhanService } from './tinh-trang-mo-phan.service';
import { TinhTrangMoPhanController } from './tinh-trang-mo-phan.controller';
import { TinhTrangMoPhan } from './entities/tinh-trang-mo-phan.entity';
import { TypeOrmModule } from '@nestjs/typeorm';

@Module({
  imports: [TypeOrmModule.forFeature([TinhTrangMoPhan])],
  providers: [TinhTrangMoPhanService],
  controllers: [TinhTrangMoPhanController],
  exports: [TypeOrmModule, TinhTrangMoPhanService],
})
export class TinhTrangMoPhanModule {}
