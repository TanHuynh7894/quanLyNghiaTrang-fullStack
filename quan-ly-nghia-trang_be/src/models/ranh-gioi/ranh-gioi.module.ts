import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { RanhGioiService } from './ranh-gioi.service';
import { RanhGioiController } from './ranh-gioi.controller';
import { RanhGioi } from './entities/ranh-gioi.entity';

@Module({
  imports: [TypeOrmModule.forFeature([RanhGioi])],
  controllers: [RanhGioiController],
  providers: [RanhGioiService],
  exports: [RanhGioiService],
})
export class RanhGioiModule {}
