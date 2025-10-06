import { Module } from '@nestjs/common';
import { TypeOrmModule, type TypeOrmModuleOptions } from '@nestjs/typeorm';
import { ConfigModule, ConfigService } from '@nestjs/config';
import { AppController } from './app.controller';
import { AppService } from './app.service';
import { KhuModule } from './models/khu/khu.module';
import { HangModule } from './models/hang/hang.module';
import { OModule } from './models/o/o.module';
import { HelperModule } from './helpper/helpper.module';

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
          synchronize: cfg.get('DB_SYNC') === 'false',
          migrationsRun: cfg.get('DB_SYNC') === 'true',
          logging: cfg.get('DB_LOGGING') === 'true',
          ssl: ssl ? { rejectUnauthorized: false } : false,
        };
      },
    }),
    KhuModule,
    HangModule,
    OModule,
    HelperModule,
  ],
  controllers: [AppController],
  providers: [AppService],
  exports: [AppService],
})
export class AppModule {}
