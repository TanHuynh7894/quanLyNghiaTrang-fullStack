import { Controller, Get } from '@nestjs/common';
// import { AppService } from './app.service';
import { DataSource } from 'typeorm';

@Controller()
export class AppController {
  constructor(private readonly ds: DataSource) {}

  @Get('db')
  async db() {
    const result: Array<{ now: string }> = await this.ds.query('SELECT NOW()');
    return { ok: true, now: result[0].now };
  }
}
