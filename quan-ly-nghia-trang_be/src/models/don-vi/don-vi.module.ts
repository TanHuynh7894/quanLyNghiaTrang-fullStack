// src/models/don-vi/don-vi.module.ts
import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { DonVi } from './entities/don-vi.entity';
import { DonViService } from './don-vi.service';
import { DonViController } from './don-vi.controller';

@Module({
  imports: [TypeOrmModule.forFeature([DonVi])], // << QUAN TRỌNG
  controllers: [DonViController],
  providers: [DonViService],
  exports: [DonViService],
})
export class DonViModule {}
