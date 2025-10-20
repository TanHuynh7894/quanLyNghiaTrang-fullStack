import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { HopDong } from './entities/hop-dong.entity';
import { HopDongService } from './hop-dong.service';
import { HopDongController } from './hop-dong.controller';

@Module({
  imports: [TypeOrmModule.forFeature([HopDong])],
  controllers: [HopDongController],
  providers: [HopDongService],
  exports: [HopDongService],
})
export class HopDongModule {}
