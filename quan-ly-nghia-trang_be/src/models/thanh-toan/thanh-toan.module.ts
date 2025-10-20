import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { ThanhToan } from './entities/thanh-toan.entity';
import { ThanhToanService } from './thanh-toan.service';
import { ThanhToanController } from './thanh-toan.controller';

@Module({
  imports: [TypeOrmModule.forFeature([ThanhToan])],
  controllers: [ThanhToanController],
  providers: [ThanhToanService],
})
export class ThanhToanModule {}
