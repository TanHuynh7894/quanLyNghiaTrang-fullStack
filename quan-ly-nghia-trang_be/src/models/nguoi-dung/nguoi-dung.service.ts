import {
  Injectable,
  NotFoundException,
  ConflictException,
} from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository, ILike } from 'typeorm';
import { NguoiDung } from './entities/nguoi-dung.entity';
import { CreateNguoiDungDto } from './dtos/create-nguoi-dung.dto';
import { UpdateNguoiDungDto } from './dtos/update-nguoi-dung.dto';
import { TrangThai } from '../trang-thai/entities/trang-thai.entity';

const DEFAULT_STATUS_NAME = 'Đang hoạt động';

@Injectable()
export class NguoiDungService {
  constructor(
    @InjectRepository(NguoiDung) private readonly repo: Repository<NguoiDung>,
    @InjectRepository(TrangThai) private readonly ttRepo: Repository<TrangThai>,
  ) {}

  /** Lấy hoặc tạo trạng thái mặc định */
  private async getDefaultTrangThaiId(): Promise<string> {
    let tt = await this.ttRepo.findOne({
      where: { tenTrangThai: ILike(DEFAULT_STATUS_NAME) },
    });
    if (!tt) {
      tt = await this.ttRepo.save(
        this.ttRepo.create({ tenTrangThai: DEFAULT_STATUS_NAME }),
      );
    }
    return tt.maTrangThai;
  }

  /** CREATE - luôn tự gán "Đang hoạt động" */
  async create(dto: CreateNguoiDungDto) {
    const maTrangThai = await this.getDefaultTrangThaiId();
    const entity = this.repo.create({ ...dto, maTrangThai });

    try {
      return await this.repo.save(entity);
    } catch (err: unknown) {
      const code = (err as { code?: string })?.code;
      if (code === '23505') {
        throw new ConflictException('Tên tài khoản đã tồn tại');
      }
      throw err;
    }
  }

  /** GET ALL */
  async findAll(page = 1, limit = 20, q?: string) {
    const qb = this.repo
      .createQueryBuilder('u')
      .leftJoin('u.trangThai', 'tt')
      .select(['u.id', 'u.tenTaiKhoan', 'u.maTrangThai', 'tt.tenTrangThai'])
      .orderBy('u.tenTaiKhoan', 'ASC')
      .skip((page - 1) * limit)
      .take(limit);

    if (q) {
      qb.where('LOWER(u.tenTaiKhoan) LIKE :q', { q: `%${q.toLowerCase()}%` });
    }
    const [items, total] = await qb.getManyAndCount();
    return { items, total, page, limit };
  }

  /** GET ONE */
  async findOne(id: string) {
    const user = await this.repo
      .createQueryBuilder('u')
      .leftJoin('u.trangThai', 'tt')
      .select(['u.id', 'u.tenTaiKhoan', 'u.maTrangThai', 'tt.tenTrangThai'])
      .where('u.id = :id', { id })
      .getOne();

    if (!user) throw new NotFoundException('Không tìm thấy người dùng');
    return user;
  }

  /** UPDATE */
  async update(id: string, dto: UpdateNguoiDungDto) {
    const user = await this.repo.findOne({
      where: { id },
      select: ['id', 'tenTaiKhoan', 'matKhau', 'maTrangThai'],
    });
    if (!user) throw new NotFoundException('Không tìm thấy người dùng');

    Object.assign(user, dto);
    try {
      return await this.repo.save(user);
    } catch (err: unknown) {
      const code = (err as { code?: string })?.code;
      if (code === '23505') {
        throw new ConflictException('Tên tài khoản đã tồn tại');
      }
      throw err;
    }
  }

  /** DELETE */
  async remove(id: string) {
    const res = await this.repo.delete(id);
    if (!res.affected) throw new NotFoundException('Không tìm thấy người dùng');
    return { success: true };
  }
}
