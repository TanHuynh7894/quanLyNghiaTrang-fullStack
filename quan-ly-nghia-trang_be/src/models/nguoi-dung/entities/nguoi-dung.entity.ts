import {
  Entity,
  PrimaryGeneratedColumn,
  Column,
  ManyToOne,
  JoinColumn,
  BeforeInsert,
  BeforeUpdate,
} from 'typeorm';
import bcrypt from 'bcrypt';
import { TrangThai } from '../../trang-thai/entities/trang-thai.entity';

@Entity({ name: 'nguoi_dung' })
export class NguoiDung {
  @PrimaryGeneratedColumn('uuid', { name: 'ma_nguoi_dung' })
  id!: string;

  @Column({ name: 'ten_tai_khoan', type: 'text', unique: true })
  tenTaiKhoan!: string;

  // Không trả về mặc định (bảo mật)
  @Column({ name: 'mat_khau', type: 'text', select: false })
  matKhau!: string;

  // FK -> trang_thai(ma_trang_thai)
  @Column({ name: 'ma_trang_thai', type: 'uuid' })
  maTrangThai!: string;

  @ManyToOne(() => TrangThai, { eager: true, nullable: false })
  @JoinColumn({ name: 'ma_trang_thai', referencedColumnName: 'maTrangThai' })
  trangThai!: TrangThai;

  @BeforeInsert()
  @BeforeUpdate()
  async hashPassword() {
    if (this.matKhau && !this.matKhau.startsWith('$2b$')) {
      this.matKhau = await bcrypt.hash(this.matKhau, 10);
    }
  }
}
