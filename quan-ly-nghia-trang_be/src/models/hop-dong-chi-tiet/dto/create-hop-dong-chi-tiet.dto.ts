export class CreateHopDongChiTietDto {
  maDichVu?: string;
  diaChiO?: string; // FK → tinh_trang_mo_phan
  maHopDong?: string;
  maNguoiMat?: string;
  tinhTrangHienThuc?: string;
  ngayThucHienDichVu?: Date;
  ngayBanGiao?: Date;
  toChucLe?: '0' | '1';
}
