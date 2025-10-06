import { Module } from '@nestjs/common';
import { OService } from './o.service';
import { OController } from './o.controller';
import { TypeOrmModule } from '@nestjs/typeorm';
import { HelperModule } from '../../helpper/helpper.module';
import { OEntity } from './entities/o.entity';

@Module({
  imports: [TypeOrmModule.forFeature([OEntity]), HelperModule],
  controllers: [OController],
  providers: [OService],
  exports: [OModule],
})
export class OModule {}
