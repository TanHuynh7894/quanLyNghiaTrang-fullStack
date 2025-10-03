import { Module } from '@nestjs/common';
import { TypeOrmModule, type TypeOrmModuleOptions } from '@nestjs/typeorm';
import { ConfigModule, ConfigService } from '@nestjs/config';
import { AppController } from './app.controller';

@Module({
  imports: [
    ConfigModule.forRoot({ isGlobal: true }),
    TypeOrmModule.forRootAsync({
      inject: [ConfigService],
      useFactory: (cfg: ConfigService): TypeOrmModuleOptions => {
        const ssl = cfg.get('DB_SSL') === 'true';

        return {
          type: 'postgres',
          host: cfg.get<string>('DB_HOST'),
          port: parseInt(cfg.get<string>('DB_PORT') ?? '5432', 10),
          username: cfg.get<string>('DB_USER'),
          password: cfg.get<string>('DB_PASS'),
          database: cfg.get<string>('DB_NAME'),
          autoLoadEntities: true,
          synchronize: cfg.get('DB_SYNC') === 'true',
          logging: cfg.get('DB_LOGGING') === 'true',
          ssl: ssl ? { rejectUnauthorized: false } : false,
        };
      },
    }),
  ],
  controllers: [AppController],
})
export class AppModule {}
