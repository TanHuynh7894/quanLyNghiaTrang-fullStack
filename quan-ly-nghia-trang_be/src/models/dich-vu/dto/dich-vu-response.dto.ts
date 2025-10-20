export class DichVuResponseDto {
  maDichVu!: string;
  loaiDichVu!: string;
  chiPhiDichVu!: number;
  tinhTrangHoatDong!: '0' | '1';
  ghiChu?: string;
  // field hiển thị
  tinhTrangHoatDongText!: string;
}
