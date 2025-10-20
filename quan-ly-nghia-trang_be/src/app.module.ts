import { Module } from '@nestjs/common';
import { TypeOrmModule, type TypeOrmModuleOptions } from '@nestjs/typeorm';
import { ConfigModule, ConfigService } from '@nestjs/config';
import { AppController } from './app.controller';
import { AppService } from './app.service';
import { KhuModule } from './models/khu/khu.module';
import { HangModule } from './models/hang/hang.module';
import { OModule } from './models/o/o.module';
import { HelperModule } from './helpper/helpper.module';
import { TinhTrangMoPhanModule } from './models/tinh-trang-mo-phan/tinh-trang-mo-phan.module';
import { VoiceNotesModule } from './models/voice-notes/voice-notes.module';
import { NguoiDungModule } from './models/nguoi-dung/nguoi-dung.module';
import { TrangThaiModule } from './models/trang-thai/trang-thai.module';
import { KhachHangModule } from './models/khach-hang/khach-hang.module';
import { DichVuModule } from './models/dich-vu/dich-vu.module';
import { ThanhToanModule } from './models/thanh-toan/thanh-toan.module';
import { DonViModule } from './models/don-vi/don-vi.module';
import { ChucVuModule } from './models/chuc-vu/chuc-vu.module';
import { NhanVienChucVuModule } from './models/nhan-vien-chuc-vu/nhan-vien-chuc-vu.module';
import { NhanVienModule } from './models/nhan-vien/nhan-vien.module';
import { HopDongModule } from './models/hop-dong/hop-dong.module';
import { ThongTinNguoiMatModule } from './models/thong-tin-nguoi-mat/thong-tin-nguoi-mat.module';
import { HopDongChiTietModule } from './models/hop-dong-chi-tiet/hop-dong-chi-tiet.module';

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
    TinhTrangMoPhanModule,
    VoiceNotesModule,
    NguoiDungModule,
    TrangThaiModule,
    KhachHangModule,
    DichVuModule,
    ThanhToanModule,
    DonViModule,
    ChucVuModule,
    NhanVienChucVuModule,
    NhanVienModule,
    HopDongModule,
    ThongTinNguoiMatModule,
    HopDongChiTietModule,
  ],
  controllers: [AppController],
  providers: [AppService],
  exports: [AppService],
})
export class AppModule {}
