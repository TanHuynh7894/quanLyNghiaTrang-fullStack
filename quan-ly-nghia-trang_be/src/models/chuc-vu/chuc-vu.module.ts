import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { ChucVu } from './entities/chuc-vu.entity';
import { ChucVuService } from './chuc-vu.service';
import { ChucVuController } from './chuc-vu.controller';

@Module({
  imports: [TypeOrmModule.forFeature([ChucVu])],
  controllers: [ChucVuController],
  providers: [ChucVuService],
  exports: [ChucVuService],
})
export class ChucVuModule {}
