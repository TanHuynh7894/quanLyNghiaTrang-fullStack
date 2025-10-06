import { Controller, Get } from '@nestjs/common';
import { AppService } from './app.service';
import { DataSource } from 'typeorm';

@Controller()
export class AppController {
  constructor(
    private readonly ds: DataSource,
    private readonly appService: AppService,
  ) {}

  @Get('db')
  async db() {
    const result: Array<{ now: string }> = await this.ds.query('SELECT NOW()');
    return { ok: true, now: result[0].now };
  }

  @Get('getHello')
  getHello(): string {
    return this.appService.getHello();
  }
}
