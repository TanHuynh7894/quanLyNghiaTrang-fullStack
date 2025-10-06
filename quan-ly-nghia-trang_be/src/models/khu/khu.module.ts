import { Module } from '@nestjs/common';
import { KhuService } from './khu.service';
import { KhuController } from './khu.controller';
import { TypeOrmModule } from '@nestjs/typeorm';
import { Khu } from '../khu/entities/khu.entity';

@Module({
  imports: [TypeOrmModule.forFeature([Khu])],
  controllers: [KhuController],
  providers: [KhuService],
  exports: [KhuModule],
})
export class KhuModule {}
