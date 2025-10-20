import { Module } from '@nestjs/common';
import { OService } from './o.service';
import { OController } from './o.controller';
import { TypeOrmModule } from '@nestjs/typeorm';
import { HelperModule } from '../../helpper/helpper.module';
import { OEntity } from './entities/o.entity';
import { Hang } from '../hang/entities/hang.entity';
import { Khu } from '../khu/entities/khu.entity';
import { HopDongChiTiet } from '../hop-dong-chi-tiet/entities/hop-dong-chi-tiet.entity';

@Module({
  imports: [
    TypeOrmModule.forFeature([OEntity, Hang, Khu, HopDongChiTiet]),
    HelperModule,
  ],
  controllers: [OController],
  providers: [OService],
  exports: [OModule, OService],
})
export class OModule {}
