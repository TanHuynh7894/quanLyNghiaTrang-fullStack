import { NestFactory } from '@nestjs/core';
import { AppModule } from './app.module';
import { ConfigService } from '@nestjs/config';
import * as path from 'path';
import * as express from 'express';

async function bootstrap() {
  const app = await NestFactory.create(AppModule);
  const config = app.get(ConfigService);

  const origin = config.get<string>('Domain_fe') || 'http://localhost:4200';
  const credentials = config.get<string>('CORS_CREDENTIALS') === 'true';
  app.use('/media', express.static(path.join(__dirname, '..', 'uploads')));

  app.enableCors({
    origin,
    credentials,
    methods: 'GET,HEAD,PUT,PATCH,POST,DELETE',
    allowedHeaders: 'Content-Type, Authorization',
  });
  await app.listen(process.env.PORT ?? 3000);
}
bootstrap();
