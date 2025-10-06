import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { Hang } from './entities/hang.entity';
import { HangService } from './hang.service';
import { HangController } from './hang.controller';
import { HelperModule } from '../../helpper/helpper.module';

@Module({
  imports: [TypeOrmModule.forFeature([Hang]), HelperModule],
  controllers: [HangController],
  providers: [HangService],
  exports: [HangModule],
})
export class HangModule {}
