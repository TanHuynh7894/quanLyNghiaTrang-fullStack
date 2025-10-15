-- EXTENSIONS
CREATE EXTENSION IF NOT EXISTS postgis;
CREATE EXTENSION IF NOT EXISTS pgcrypto;
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
-- TYPES / ENUMS
DO $$ BEGIN
  CREATE TYPE trang_thai_enum AS ENUM ('0','1');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE TYPE trang_thai_hoat_dong AS ENUM ('0','1');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE TYPE the_loai_lich_su AS ENUM ('An táng','Cải táng');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

-- ===== DANH MỤC NỀN =====
CREATE TABLE trang_thai (
  ma_trang_thai  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  ten_trang_thai VARCHAR(255) NOT NULL
);

CREATE TABLE kieu_mo (
  ma_kieu_mo UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  ten_kieu_mo VARCHAR(255) NOT NULL,
  tinh_trang_hoat_dong BOOLEAN NOT NULL DEFAULT TRUE
);

CREATE TABLE tinh_trang_mo_phan (
  ma_tinh_trang UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  ten_tinh_trang VARCHAR(255) NOT NULL
);

CREATE TABLE dich_vu (
  ma_dich_vu   UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  loai_dich_vu VARCHAR(255) NOT NULL,
  chi_phi      NUMERIC(18,2),
  tinh_trang   trang_thai_enum NOT NULL,
  ghi_chu      TEXT
);

CREATE TABLE don_vi (
  ma_don_vi       UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  ten_don_vi      VARCHAR(255) NOT NULL,
  ma_don_vi_cha   UUID,
  dia_chi         VARCHAR(255),
  so_dien_thoai   VARCHAR(10),
  ma_so_thue      VARCHAR(15),
  so_tai_khoan    VARCHAR(35),
  ky_hieu_hoa_don VARCHAR(10),
  tinh_trang_hoat_dong trang_thai_hoat_dong NOT NULL,
  CONSTRAINT fk_don_vi_cha FOREIGN KEY (ma_don_vi_cha)
    REFERENCES don_vi(ma_don_vi) ON DELETE SET NULL
);

CREATE TABLE chuc_vu (
  ma_chuc_vu UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  ten_chuc_vu VARCHAR(255) NOT NULL,
  tinh_trang_hoat_dong trang_thai_hoat_dong NOT NULL
);

CREATE TABLE dao_tao (
  ma_dao_tao   UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tieu_de      TEXT NOT NULL,
  mo_ta        TEXT,
  thoi_gian_bd TIMESTAMP NOT NULL,
  thoi_gian_kt TIMESTAMP NOT NULL
);

-- ===== NGƯỜI DÙNG / QUYỀN =====
CREATE TABLE nguoi_dung (
  ma_nguoi_dung UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  ten_tai_khoan VARCHAR(255),
  mat_khau      VARCHAR(255),
  ma_trang_thai UUID,
  CONSTRAINT fk_trangthai FOREIGN KEY (ma_trang_thai)
    REFERENCES trang_thai(ma_trang_thai)
);

CREATE TABLE quyen_nguoi_dung (
  ma_nhom_quyen   UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  ten_nhom_quyen  VARCHAR(255) NOT NULL,
  mo_ta_nhom_quyen TEXT,
  ma_trang_thai   UUID,
  CONSTRAINT fk_quyen_trangthai FOREIGN KEY (ma_trang_thai)
    REFERENCES trang_thai(ma_trang_thai) ON DELETE SET NULL
);

CREATE TABLE phan_quyen_nguoi_dung (
  ma_nhom_quyen UUID NOT NULL,
  ma_nguoi_dung UUID NOT NULL,
  PRIMARY KEY (ma_nhom_quyen, ma_nguoi_dung),
  CONSTRAINT fk_pqnd_quyen FOREIGN KEY (ma_nhom_quyen)
    REFERENCES quyen_nguoi_dung(ma_nhom_quyen) ON DELETE CASCADE,
  CONSTRAINT fk_pqnd_user FOREIGN KEY (ma_nguoi_dung)
    REFERENCES nguoi_dung(ma_nguoi_dung) ON DELETE CASCADE
);

-- ===== NHÂN SỰ =====
CREATE TABLE nhan_vien (
  ma_nhan_vien   UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  ten_nhan_vien  VARCHAR(255) NOT NULL,
  ma_don_vi      UUID NOT NULL,
  ma_chuc_vu     UUID,
  gioi_tinh      VARCHAR(5),
  so_dien_thoai  VARCHAR(10),
  email          VARCHAR(255),
  tinh_trang_lam_viec TEXT,
  hinh_anh       VARCHAR(100),
  CONSTRAINT fk_nv_donvi FOREIGN KEY (ma_don_vi)
    REFERENCES don_vi(ma_don_vi) ON DELETE CASCADE,
  CONSTRAINT fk_nv_chucvu FOREIGN KEY (ma_chuc_vu)
    REFERENCES chuc_vu(ma_chuc_vu) ON DELETE SET NULL
);

CREATE TABLE chuc_vu_nhan_vien (
  ma_chuc_vu  UUID NOT NULL,
  ma_nhan_vien UUID NOT NULL,
  PRIMARY KEY (ma_chuc_vu, ma_nhan_vien),
  CONSTRAINT fk_cvnv_chucvu FOREIGN KEY (ma_chuc_vu)
    REFERENCES chuc_vu(ma_chuc_vu) ON DELETE CASCADE,
  CONSTRAINT fk_cvnv_nhanvien FOREIGN KEY (ma_nhan_vien)
    REFERENCES nhan_vien(ma_nhan_vien) ON DELETE CASCADE
);

CREATE TABLE cong_viec (
  ma_cong_viec       UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  ma_nv_giao_viec    UUID NOT NULL,
  ma_nv_nhan_viec    UUID NOT NULL,
  nhom_cong_viec     VARCHAR(100),
  noi_dung_cong_viec TEXT,
  ngay_giao_viec     TIMESTAMP,
  ngay_thuc_hien     DATE,
  thoi_gian          TIME,
  ngay_hoan_thanh    TIMESTAMP,
  CONSTRAINT fk_cv_nv_giao FOREIGN KEY (ma_nv_giao_viec)
    REFERENCES nhan_vien(ma_nhan_vien) ON DELETE CASCADE,
  CONSTRAINT fk_cv_nv_nhan FOREIGN KEY (ma_nv_nhan_viec)
    REFERENCES nhan_vien(ma_nhan_vien) ON DELETE CASCADE
);

CREATE TABLE hinh_anh_cong_viec (
  ma_cong_viec UUID NOT NULL,
  hinh_anh     VARCHAR(100) NOT NULL,
  PRIMARY KEY (ma_cong_viec, hinh_anh)
);

CREATE TABLE diem_danh (
  ma_diem_danh  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  ma_nhan_vien  UUID NOT NULL,
  ngay          DATE NOT NULL,
  thoi_gian_vao TIME,
  thoi_gian_ra  TIME,
  CONSTRAINT fk_dd_nv FOREIGN KEY (ma_nhan_vien)
    REFERENCES nhan_vien(ma_nhan_vien) ON DELETE CASCADE
);

CREATE TABLE danh_gia_nhan_vien (
  ma_danh_gia    UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  ma_nhan_vien   UUID NOT NULL,
  ngay_danh_gia  TIMESTAMP,
  diem           INT,
  ghi_chu        TEXT,
  ma_nv_danh_gia UUID,
  CONSTRAINT fk_dgnv_nv FOREIGN KEY (ma_nhan_vien)
    REFERENCES nhan_vien(ma_nhan_vien) ON DELETE CASCADE,
  CONSTRAINT fk_dgnv_nguoigd FOREIGN KEY (ma_nv_danh_gia)
    REFERENCES nhan_vien(ma_nhan_vien) ON DELETE SET NULL
);

CREATE TABLE tien_luong (
  ma_luong       UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  ma_nhan_vien   UUID NOT NULL,
  thang          INT NOT NULL,
  nam            INT NOT NULL,
  luong_co_ban   VARCHAR(25),
  thuong         VARCHAR(25),
  phat           VARCHAR(25),
  ngay           TIMESTAMP,
  ma_nv_ky_duyet UUID,
  CONSTRAINT fk_tl_nv FOREIGN KEY (ma_nhan_vien)
    REFERENCES nhan_vien(ma_nhan_vien) ON DELETE CASCADE,
  CONSTRAINT fk_tl_nv_kyduyet FOREIGN KEY (ma_nv_ky_duyet)
    REFERENCES nhan_vien(ma_nhan_vien) ON DELETE SET NULL
);

-- ===== NGHĨA TRANG (KHÔNG GIAN) =====
CREATE TABLE khu (
  ma_khu UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  ten_khu VARCHAR(100) NOT NULL,
  toa_do geometry(MultiPolygon, 4326)
);

CREATE TABLE hang (
  ma_hang UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  ten_hang VARCHAR(100) NOT NULL,
  ma_khu UUID NOT NULL,
  toa_do geometry(MultiPolygon, 4326),
  CONSTRAINT fk_hang_khu FOREIGN KEY (ma_khu)
    REFERENCES khu(ma_khu) ON DELETE CASCADE
);

CREATE TABLE o (
  id       UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  dia_chi  VARCHAR(100),
  ten_o    VARCHAR(100),
  ma_hang  UUID NOT NULL,
  ma_khu   UUID NOT NULL,
  toa_do   geometry(MultiPolygon, 4326),
  CONSTRAINT fk_o_hang FOREIGN KEY (ma_hang) REFERENCES hang(ma_hang) ON DELETE CASCADE,
  CONSTRAINT fk_o_khu  FOREIGN KEY (ma_khu)  REFERENCES khu(ma_khu)  ON DELETE CASCADE
);

CREATE TABLE mo_phan (
  dia_chi_o     VARCHAR(10) PRIMARY KEY NOT NULL,
  ten_o         VARCHAR(100) NOT NULL,
  chieu_dai     VARCHAR(100),
  chieu_rong    VARCHAR(100),
  dien_tich     VARCHAR(100),
  ma_tinh_trang UUID,
  ngay_khao_sat TIMESTAMP,
  ma_kieu_mo    UUID,
  gia_tri       NUMERIC(18,2),
  CONSTRAINT fk_mo_phan_tinh_trang
    FOREIGN KEY (ma_tinh_trang) REFERENCES tinh_trang_mo_phan(ma_tinh_trang),
  CONSTRAINT fk_mo_phan_kieu_mo
    FOREIGN KEY (ma_kieu_mo) REFERENCES kieu_mo(ma_kieu_mo)
);

CREATE TABLE lich_su_phan_mo (
  dia_chi_o VARCHAR(10) PRIMARY KEY NOT NULL,
  ngay      TIMESTAMP NOT NULL,
  the_loai  the_loai_lich_su NOT NULL,
  ghi_chu   TEXT,
  CONSTRAINT fk_lichsu_o FOREIGN KEY (dia_chi_o)
    REFERENCES mo_phan(dia_chi_o) ON DELETE CASCADE
);

CREATE TABLE hinh_anh_mo_phan (
  dia_chi_o VARCHAR(10) NOT NULL,
  hinh_anh  VARCHAR(100) NOT NULL,
  PRIMARY KEY (dia_chi_o, hinh_anh),
  CONSTRAINT fk_hinhanh_o FOREIGN KEY (dia_chi_o)
    REFERENCES mo_phan(dia_chi_o) ON DELETE CASCADE
);

-- ===== KHÁCH HÀNG / HỢP ĐỒNG =====
CREATE TABLE khach_hang (
  ma_khach_hang   UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  ten_khach_hang  VARCHAR(255) NOT NULL,
  dia_chi         VARCHAR(255),
  so_lien_he      VARCHAR(10),
  quoc_tich       VARCHAR(20),
  so_cccd         VARCHAR(20),
  ngay_cap        DATE,
  noi_cap         TEXT,
  ghi_chu         TEXT
);

CREATE TABLE thong_tin_nguoi_mat (
  ma_nguoi_mat   UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  ten_nguoi_mat  VARCHAR(255) NOT NULL,
  dia_chi        VARCHAR(255),
  quoc_tich      VARCHAR(20),
  so_cccd        VARCHAR(20),
  ngay_cap       DATE,
  noi_cap        TEXT,
  ngay_sinh      DATE,
  ngay_mat_duong DATE,
  ngay_mat_am    DATE,
  ma_khach_hang  UUID,
  CONSTRAINT fk_nguoi_mat_khach FOREIGN KEY (ma_khach_hang)
    REFERENCES khach_hang(ma_khach_hang) ON DELETE SET NULL
);

CREATE TABLE hop_dong (
  ma_hop_dong      UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  so_hop_dong      VARCHAR(100),
  ngay_ky_ket      DATE,
  ngay_hieu_luc    DATE,
  gia_tri          NUMERIC(18,2),
  phi_chuyen_nhuong NUMERIC(18,2),
  vi_tri_luu_ho_so TEXT,
  trang_thai       TEXT,
  ghi_chu          TEXT,
  ma_khach_hang    UUID,
  ma_khach_ben_c   UUID,
  ma_nhan_vien     UUID,
  CONSTRAINT fk_hd_khach    FOREIGN KEY (ma_khach_hang)  REFERENCES khach_hang(ma_khach_hang) ON DELETE SET NULL,
  CONSTRAINT fk_hd_khach_c  FOREIGN KEY (ma_khach_ben_c) REFERENCES khach_hang(ma_khach_hang) ON DELETE SET NULL,
  CONSTRAINT fk_hd_nv       FOREIGN KEY (ma_nhan_vien)   REFERENCES nhan_vien(ma_nhan_vien)   ON DELETE SET NULL
);

CREATE TABLE thanh_toan (
  ma_dot_thanh_toan UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  ma_hop_dong       UUID NOT NULL,
  so_tien           NUMERIC(18,2) NOT NULL,
  ngay_thanh_toan   TIMESTAMP,
  hinh_thuc_thanh_toan VARCHAR(255),
  noi_dung          TEXT,
  ghi_chu           TEXT,
  CONSTRAINT fk_tt_hopdong FOREIGN KEY (ma_hop_dong)
    REFERENCES hop_dong(ma_hop_dong) ON DELETE CASCADE
);

CREATE TABLE hop_dong_chi_tiet (
  ma_hd_chi_tiet  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  ma_dich_vu      UUID,
  dia_chi_o       VARCHAR(10),
  ma_hop_dong     UUID,
  ma_nguoi_mat    UUID,
  tinh_trang_thuc TEXT,
  ngay_thuc_hien  TIMESTAMP,
  ngay_ban_giao   TIMESTAMP,
  to_chuc_le      trang_thai_enum,
  CONSTRAINT fk_hdct_dv FOREIGN KEY (ma_dich_vu)
    REFERENCES dich_vu(ma_dich_vu) ON DELETE SET NULL,
  CONSTRAINT fk_hdct_o  FOREIGN KEY (dia_chi_o)
    REFERENCES mo_phan(dia_chi_o) ON DELETE SET NULL,
  CONSTRAINT fk_hdct_hd FOREIGN KEY (ma_hop_dong)
    REFERENCES hop_dong(ma_hop_dong) ON DELETE CASCADE,
  CONSTRAINT fk_hdct_nm FOREIGN KEY (ma_nguoi_mat)
    REFERENCES thong_tin_nguoi_mat(ma_nguoi_mat) ON DELETE SET NULL
);

CREATE TABLE dao_tao_nhan_vien (
  ma_dao_tao   UUID NOT NULL,
  ma_nhan_vien UUID NOT NULL,
  PRIMARY KEY (ma_dao_tao, ma_nhan_vien),
  CONSTRAINT fk_dtnv_dao_tao   FOREIGN KEY (ma_dao_tao)   REFERENCES dao_tao(ma_dao_tao) ON DELETE CASCADE,
  CONSTRAINT fk_dtnv_nhan_vien FOREIGN KEY (ma_nhan_vien) REFERENCES nhan_vien(ma_nhan_vien) ON DELETE CASCADE
);

CREATE TABLE voice_notes (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  file_url TEXT NOT NULL,
  status SMALLINT NOT NULL DEFAULT 0 CHECK (status IN (0, 1)),  -- 0: uploaded, 1: transcribed
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- ===== SEED DATA (UUID CỐ ĐỊNH ĐỂ THAM CHIẾU) =====
-- Trang thái
INSERT INTO trang_thai(ma_trang_thai, ten_trang_thai) VALUES
 ('11111111-1111-1111-1111-111111111111','Đang hoạt động'),
 ('11111111-1111-1111-1111-222222222222','Ngưng hoạt động');

-- Khu vực / Danh mục
INSERT INTO kieu_mo(ma_kieu_mo, ten_kieu_mo, tinh_trang_hoat_dong) VALUES
 ('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1','Mộ đơn', TRUE),
 ('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa2','Mộ đôi', TRUE); 

INSERT INTO tinh_trang_mo_phan (ma_tinh_trang, ten_tinh_trang) VALUES
 ('11111111-2222-3333-4444-000000000001','Kim Tĩnh'),
 ('11111111-2222-3333-4444-000000000002','Xây thô'),
 ('11111111-2222-3333-4444-000000000003','Hoàn thiện'),
 ('11111111-2222-3333-4444-000000000004','Đã bán'),
 ('11111111-2222-3333-4444-000000000005','Đã chôn 1 người'),
 ('11111111-2222-3333-4444-000000000006','Đã chôn đủ'),
 ('11111111-2222-3333-4444-000000000007','Trống');

INSERT INTO dich_vu (loai_dich_vu, chi_phi, tinh_trang, ghi_chu) VALUES
('An táng (chôn mới)',                      15000000.00, '1', 'Gói cơ bản: đào huyệt, vận chuyển, hạ huyệt; chưa gồm bia & xây mộ'),
('Cải táng/di dời – bốc mộ',                12000000.00, '1', 'Gói cơ bản cải táng/di dời; chưa gồm lưu giữ/xe đường dài'),
('Hỏa táng (nếu có) / an táng tro cốt',      5000000.00, '1', 'Nhận tro cốt và an vị; không gồm phí lò hỏa táng'),
('Xây mộ mới',                               40000000.00, '1', 'Mộ 1 chỗ, vật liệu granite phổ thông; theo mẫu chuẩn'),
('Nâng cấp/ốp lát/sơn sửa mộ',                8000000.00, '1', 'Đơn giá gói cơ bản; tùy khối lượng thực tế'),
('Dựng/khắc bia, làm mái che',               10000000.00, '1', 'Bia đá khắc chữ tiêu chuẩn; mái che khung thép/tôn'),
('Chống lún – sửa nứt',                       6000000.00, '1', 'Gia cố nền, trám nứt; chưa gồm tái lát toàn phần'),
('Vệ sinh mộ/tảo mộ (Tết/Thanh minh)',        1000000.00, '1', 'Đơn giá/lần: lau dọn, thay hoa quả/nhang'),
('Cắt cỏ, quét dọn khu vực',                   300000.00, '1', 'Đơn giá/lần, khu vực < 50 m²'),
('Dâng hoa/nhang định kỳ',                     200000.00, '1', 'Đơn giá/lần, gói tiêu chuẩn');

  INSERT INTO don_vi(ma_don_vi, ten_don_vi, ma_don_vi_cha, dia_chi, so_dien_thoai, ma_so_thue, so_tai_khoan, ky_hieu_hoa_don, tinh_trang_hoat_dong) VALUES
   ('dddddddd-dddd-4ddd-8ddd-ddddddddddd1','FPT', NULL, 'Số 1 ABC','0900000001','010000001','0123456789','AA','1'),
   ('dddddddd-dddd-4ddd-8ddd-ddddddddddd2','FPTU','dddddddd-dddd-4ddd-8ddd-ddddddddddd1','Số 1 ABC','0900000002','010000002','0123456790','AB','1');

  INSERT INTO chuc_vu (ten_chuc_vu, tinh_trang_hoat_dong) VALUES
   ('Phó Giám đốc','1'),
   ('Kế toán trưởng','1'),
   ('Kế toán viên','1'),
   ('Trưởng phòng Xây dựng','1'),
   ('Phó phòng Xây dựng','1'),
   ('Kỹ sư xây dựng','1'),
   ('Giám sát hiện trường','1'),
   ('Nhân viên dự toán','1'),
   ('Nhân viên vật tư','1'),
   ('Thợ xây','1'),
   ('Thợ đá ốp lát','1'),
   ('Nhân viên bảo trì','1'),
   ('Nhân viên QC','1'),
   ('Nhân viên an toàn','1');

INSERT INTO dao_tao(ma_dao_tao, tieu_de, mo_ta, thoi_gian_bd, thoi_gian_kt) VALUES
 ('ffffffff-ffff-4fff-8fff-fffffffffff1','An toàn lao động','Đào tạo cơ bản','2025-10-01 09:00','2025-10-01 12:00');

-- Người dùng / Quyền
INSERT INTO nguoi_dung(ma_nguoi_dung, ten_tai_khoan, mat_khau, ma_trang_thai) VALUES
-- ===== 15 NHÂN VIÊN =====
('aaaabbbb-cccc-4ddd-8eee-ffff00000003','annv1023',    'hash_annv1023',    '11111111-1111-1111-1111-111111111111'), -- Nguyen Van An
('aaaabbbb-cccc-4ddd-8eee-ffff00000004','binhtt2145',  'hash_binhtt2145',  '11111111-1111-1111-1111-111111111111'), -- Tran Thi Binh
('aaaabbbb-cccc-4ddd-8eee-ffff00000005','tamlt3267',   'hash_tamlt3267',   '11111111-1111-1111-1111-111111111111'), -- Le Thanh Tam
('aaaabbbb-cccc-4ddd-8eee-ffff00000006','dungpv4389',  'hash_dungpv4389',  '11111111-1111-1111-1111-111111111111'), -- Pham Van Dung
('aaaabbbb-cccc-4ddd-8eee-ffff00000007','ducvm5401',   'hash_ducvm5401',   '11111111-1111-1111-1111-111111111111'), -- Vu Minh Duc
('aaaabbbb-cccc-4ddd-8eee-ffff00000008','huybq6523',   'hash_huybq6523',   '11111111-1111-1111-1111-111111111111'), -- Bui Quang Huy
('aaaabbbb-cccc-4ddd-8eee-ffff00000009','khoaha7645',  'hash_khoaha7645',  '11111111-1111-1111-1111-111111111111'), -- Hoang Anh Khoa
('aaaabbbb-cccc-4ddd-8eee-ffff0000000a','lampt8767',   'hash_lampt8767',   '11111111-1111-1111-1111-111111111111'), -- Phan Thanh Lam
('aaaabbbb-cccc-4ddd-8eee-ffff0000000b','maidt9889',   'hash_maidt9889',   '11111111-1111-1111-1111-111111111111'), -- Dang Thi Mai
('aaaabbbb-cccc-4ddd-8eee-ffff0000000c','namdv0901',   'hash_namdv0901',   '11111111-1111-1111-1111-111111111111'), -- Doan Van Nam
('aaaabbbb-cccc-4ddd-8eee-ffff0000000d','phongdt1123', 'hash_phongdt1123', '11111111-1111-1111-1111-111111111111'), -- Dinh Tuan Phong
('aaaabbbb-cccc-4ddd-8eee-ffff0000000e','quynhnt2244', 'hash_quynhnt2244', '11111111-1111-1111-1111-111111111111'), -- Ngo Thi Quynh
('aaaabbbb-cccc-4ddd-8eee-ffff0000000f','sonth3366',   'hash_sonth3366',   '11111111-1111-1111-1111-111111111111'), -- Truong Hoai Son
('aaaabbbb-cccc-4ddd-8eee-ffff00000010','thinhlg4488', 'hash_thinhlg4488', '11111111-1111-1111-1111-111111111111'), -- Ly Gia Thinh
('aaaabbbb-cccc-4ddd-8eee-ffff00000011','tungct5599',  'hash_tungct5599',  '11111111-1111-1111-1111-111111111111'), -- Chau Thanh Tung

-- ===== 15 KHÁCH HÀNG / VIEWER =====
('aaaabbbb-cccc-4ddd-8eee-ffff00000012','nguyenthithuha', 'hash_nguyenthithuha', '11111111-1111-1111-1111-111111111111'),
('aaaabbbb-cccc-4ddd-8eee-ffff00000013','phamhoangson',   'hash_phamhoangson',   '11111111-1111-1111-1111-111111111111'),
('aaaabbbb-cccc-4ddd-8eee-ffff00000014','leminhtri',      'hash_leminhtri',      '11111111-1111-1111-1111-111111111111'),
('aaaabbbb-cccc-4ddd-8eee-ffff00000015','tranthikimoanh', 'hash_tranthikimoanh', '11111111-1111-1111-1111-111111111111'),
('aaaabbbb-cccc-4ddd-8eee-ffff00000016','buithanhtung',   'hash_buithanhtung',   '11111111-1111-1111-1111-111111111111'),
('aaaabbbb-cccc-4ddd-8eee-ffff00000017','dangquynhnhu',   'hash_dangquynhnhu',   '11111111-1111-1111-1111-111111111111'),
('aaaabbbb-cccc-4ddd-8eee-ffff00000018','dongoclan',      'hash_dongoclan',      '11111111-1111-1111-1111-111111111111'),
('aaaabbbb-cccc-4ddd-8eee-ffff00000019','vuanhtuan',      'hash_vuanhtuan',      '11111111-1111-1111-1111-111111111111'),
('aaaabbbb-cccc-4ddd-8eee-ffff0000001a','hothimyduyen',   'hash_hothimyduyen',   '11111111-1111-1111-1111-111111111111'),
('aaaabbbb-cccc-4ddd-8eee-ffff0000001b','voquockhanh',    'hash_voquockhanh',    '11111111-1111-1111-1111-111111111111'),
('aaaabbbb-cccc-4ddd-8eee-ffff0000001c','ngothanhha',     'hash_ngothanhha',     '11111111-1111-1111-1111-111111111111'),
('aaaabbbb-cccc-4ddd-8eee-ffff0000001d','hoangminhthu',   'hash_hoangminhthu',   '11111111-1111-1111-1111-111111111111'),
('aaaabbbb-cccc-4ddd-8eee-ffff0000001e','lequochuy',      'hash_lequochuy',      '11111111-1111-1111-1111-111111111111'),
('aaaabbbb-cccc-4ddd-8eee-ffff0000001f','phamngocanh',    'hash_phamngocanh',    '11111111-1111-1111-1111-111111111111'),
('aaaabbbb-cccc-4ddd-8eee-ffff00000020','truongthanhtrung','hash_truongthanhtrung','11111111-1111-1111-1111-111111111111');
  
INSERT INTO quyen_nguoi_dung
(ma_nhom_quyen, ten_nhom_quyen, mo_ta_nhom_quyen, ma_trang_thai)
VALUES
-- 1) Ban Giám đốc
(
  gen_random_uuid(),
  'Ban Giám đốc',
  $${
    "khu": ["read"],
    "hang": ["read"],
    "o": ["read"],
    "mo_phan": ["read"],
    "dich_vu": ["read","approve","update"],
    "hop_dong": ["read","approve","update"],
    "thanh_toan": ["read","approve"],
    "khach_hang": ["read"],
    "nhan_vien": ["read"],
    "tien_luong": ["read"],
    "diem_danh": ["read"],
    "dao_tao": ["read"],
    "bao_cao": ["read","export"]
  }$$,
  (SELECT ma_trang_thai FROM trang_thai WHERE ten_trang_thai='Đang hoạt động' LIMIT 1)
),

-- 2) Phòng Kế toán
(
  gen_random_uuid(),
  'Phòng Kế toán',
  $${
    "hop_dong": ["read","update"],
    "thanh_toan": ["read","create","update","export","approve_l1"],
    "dich_vu": ["read"],
    "khach_hang": ["read"],
    "bao_cao": ["read","export"]
  }$$,
  (SELECT ma_trang_thai FROM trang_thai WHERE ten_trang_thai='Đang hoạt động' LIMIT 1)
),

-- 3) Phòng Hành chính – Nhân sự
(
  gen_random_uuid(),
  'Phòng Hành chính – Nhân sự',
  $${
    "nhan_vien": ["read","create","update"],
    "chuc_vu": ["read","create","update"],
    "don_vi": ["read","create","update"],
    "diem_danh": ["read","create","update"],
    "tien_luong": ["read","create","update"],
    "dao_tao": ["read","create","update"],
    "nguoi_dung": ["read","create","reset_password"],
    "hop_dong": ["read"],
    "thanh_toan": ["read"]
  }$$,
  (SELECT ma_trang_thai FROM trang_thai WHERE ten_trang_thai='Đang hoạt động' LIMIT 1)
),

-- 4) Khách hàng (đề nghị áp RLS cho *_own)
(
  gen_random_uuid(),
  'Khách hàng',
  $${
    "dich_vu":   ["read"],
    "hop_dong":  ["read_own"],
    "thanh_toan":["read_own"],
    "khach_hang":["read_own","update_own"],
    "mo_phan":   ["read_own"]
  }$$,
  (SELECT ma_trang_thai FROM trang_thai WHERE ten_trang_thai='Đang hoạt động' LIMIT 1)
);

-- GÁN 2 NHÂN VIÊN VÀO BAN GIÁM ĐỐC
INSERT INTO phan_quyen_nguoi_dung (ma_nhom_quyen, ma_nguoi_dung)
SELECT q.ma_nhom_quyen, u.ma_nguoi_dung
FROM quyen_nguoi_dung q
JOIN nguoi_dung u ON u.ten_tai_khoan IN ('annv1023','sonth3366')
WHERE q.ten_nhom_quyen = 'Ban Giám đốc'
ON CONFLICT DO NOTHING;

-- GÁN 3 NHÂN VIÊN VÀO PHÒNG KẾ TOÁN
INSERT INTO phan_quyen_nguoi_dung (ma_nhom_quyen, ma_nguoi_dung)
SELECT q.ma_nhom_quyen, u.ma_nguoi_dung
FROM quyen_nguoi_dung q
JOIN nguoi_dung u ON u.ten_tai_khoan IN ('binhtt2145','tamlt3267','namdv0901')
WHERE q.ten_nhom_quyen = 'Phòng Kế toán'
ON CONFLICT DO NOTHING;

-- GÁN 10 NHÂN VIÊN CÒN LẠI VÀO PHÒNG HÀNH CHÍNH – NHÂN SỰ
INSERT INTO phan_quyen_nguoi_dung (ma_nhom_quyen, ma_nguoi_dung)
SELECT q.ma_nhom_quyen, u.ma_nguoi_dung
FROM quyen_nguoi_dung q
JOIN nguoi_dung u ON u.ten_tai_khoan IN (
  'dungpv4389','ducvm5401','huybq6523','khoaha7645','lampt8767',
  'maidt9889','phongdt1123','quynhnt2244','thinhlg4488','tungct5599'
)
WHERE q.ten_nhom_quyen = 'Phòng Hành chính – Nhân sự'
ON CONFLICT DO NOTHING;

-- GÁN 15 TÀI KHOẢN CÒN LẠI VÀO NHÓM "KHÁCH HÀNG"
INSERT INTO phan_quyen_nguoi_dung (ma_nhom_quyen, ma_nguoi_dung)
SELECT q.ma_nhom_quyen, u.ma_nguoi_dung
FROM quyen_nguoi_dung q
JOIN nguoi_dung u ON u.ten_tai_khoan IN (
  'nguyenthithuha','phamhoangson','leminhtri','tranthikimoanh','buithanhtung',
  'dangquynhnhu','dongoclan','vuanhtuan','hothimyduyen','voquockhanh',
  'ngothanhha','hoangminhthu','lequochuy','phamngocanh','truongthanhtrung'
)
WHERE q.ten_nhom_quyen = 'Khách hàng'
ON CONFLICT DO NOTHING;

-- Nhân sự
INSERT INTO nhan_vien
(ma_nhan_vien, ten_nhan_vien, ma_don_vi, ma_chuc_vu, gioi_tinh, so_dien_thoai, email, tinh_trang_lam_viec, hinh_anh)
VALUES
('aaaabbbb-cccc-4ddd-8eee-ffff00000003','Nguyễn Văn An',
 'dddddddd-dddd-4ddd-8ddd-ddddddddddd1',
 (SELECT ma_chuc_vu FROM chuc_vu WHERE ten_chuc_vu='Phó Giám đốc' LIMIT 1),
 'M','0901111101','annv1023@cty.vn','Đang làm','nv01.jpg'),

('aaaabbbb-cccc-4ddd-8eee-ffff00000004','Trần Thị Bình',
 'dddddddd-dddd-4ddd-8ddd-ddddddddddd2',
 (SELECT ma_chuc_vu FROM chuc_vu WHERE ten_chuc_vu='Kế toán trưởng' LIMIT 1),
 'F','0901111102','binhtt2145@cty.vn','Đang làm','nv02.jpg'),

('aaaabbbb-cccc-4ddd-8eee-ffff00000005','Lê Thanh Tâm',
 'dddddddd-dddd-4ddd-8ddd-ddddddddddd1',
 (SELECT ma_chuc_vu FROM chuc_vu WHERE ten_chuc_vu='Kế toán viên' LIMIT 1),
 'F','0901111103','tamlt3267@cty.vn','Đang làm','nv03.jpg'),

('aaaabbbb-cccc-4ddd-8eee-ffff00000006','Phạm Văn Dũng',
 'dddddddd-dddd-4ddd-8ddd-ddddddddddd2',
 (SELECT ma_chuc_vu FROM chuc_vu WHERE ten_chuc_vu='Kỹ sư xây dựng' LIMIT 1),
 'M','0901111104','dungpv4389@cty.vn','Đang làm','nv04.jpg'),

('aaaabbbb-cccc-4ddd-8eee-ffff00000007','Vũ Minh Đức',
 'dddddddd-dddd-4ddd-8ddd-ddddddddddd2',
 (SELECT ma_chuc_vu FROM chuc_vu WHERE ten_chuc_vu='Giám sát hiện trường' LIMIT 1),
 'M','0901111105','ducvm5401@cty.vn','Đang làm','nv05.jpg'),

('aaaabbbb-cccc-4ddd-8eee-ffff00000008','Bùi Quang Huy',
 'dddddddd-dddd-4ddd-8ddd-ddddddddddd1',
 (SELECT ma_chuc_vu FROM chuc_vu WHERE ten_chuc_vu='Nhân viên dự toán' LIMIT 1),
 'M','0901111106','huybq6523@cty.vn','Đang làm','nv06.jpg'),

('aaaabbbb-cccc-4ddd-8eee-ffff00000009','Hoàng Anh Khoa',
 'dddddddd-dddd-4ddd-8ddd-ddddddddddd1',
 (SELECT ma_chuc_vu FROM chuc_vu WHERE ten_chuc_vu='Nhân viên vật tư' LIMIT 1),
 'M','0901111107','khoaha7645@cty.vn','Đang làm','nv07.jpg'),

('aaaabbbb-cccc-4ddd-8eee-ffff0000000a','Phan Thanh Lâm',
 'dddddddd-dddd-4ddd-8ddd-ddddddddddd2',
 (SELECT ma_chuc_vu FROM chuc_vu WHERE ten_chuc_vu='Trưởng phòng Xây dựng' LIMIT 1),
 'M','0901111108','lampt8767@cty.vn','Đang làm','nv08.jpg'),

('aaaabbbb-cccc-4ddd-8eee-ffff0000000b','Đặng Thị Mai',
 'dddddddd-dddd-4ddd-8ddd-ddddddddddd2',
 (SELECT ma_chuc_vu FROM chuc_vu WHERE ten_chuc_vu='Phó phòng Xây dựng' LIMIT 1),
 'F','0901111109','maidt9889@cty.vn','Đang làm','nv09.jpg'),

('aaaabbbb-cccc-4ddd-8eee-ffff0000000c','Đoàn Văn Nam',
 'dddddddd-dddd-4ddd-8ddd-ddddddddddd1',
 (SELECT ma_chuc_vu FROM chuc_vu WHERE ten_chuc_vu='Kế toán viên' LIMIT 1),
 'M','0901111110','namdv0901@cty.vn','Đang làm','nv10.jpg'),

('aaaabbbb-cccc-4ddd-8eee-ffff0000000d','Đinh Tuấn Phong',
 'dddddddd-dddd-4ddd-8ddd-ddddddddddd1',
 (SELECT ma_chuc_vu FROM chuc_vu WHERE ten_chuc_vu='Thợ đá ốp lát' LIMIT 1),
 'M','0901111111','phongdt1123@cty.vn','Đang làm','nv11.jpg'),

('aaaabbbb-cccc-4ddd-8eee-ffff0000000e','Ngô Thị Quỳnh',
 'dddddddd-dddd-4ddd-8ddd-ddddddddddd2',
 (SELECT ma_chuc_vu FROM chuc_vu WHERE ten_chuc_vu='Nhân viên bảo trì' LIMIT 1),
 'F','0901111112','quynhnt2244@cty.vn','Đang làm','nv12.jpg'),

('aaaabbbb-cccc-4ddd-8eee-ffff0000000f','Trương Hoài Sơn',
 'dddddddd-dddd-4ddd-8ddd-ddddddddddd1',
 (SELECT ma_chuc_vu FROM chuc_vu WHERE ten_chuc_vu='Phó Giám đốc' LIMIT 1),
 'M','0901111113','sonth3366@cty.vn','Đang làm','nv13.jpg'),

('aaaabbbb-cccc-4ddd-8eee-ffff00000010','Lý Gia Thịnh',
 'dddddddd-dddd-4ddd-8ddd-ddddddddddd2',
 (SELECT ma_chuc_vu FROM chuc_vu WHERE ten_chuc_vu='Nhân viên an toàn' LIMIT 1),
 'M','0901111114','thinhlg4488@cty.vn','Đang làm','nv14.jpg'),

('aaaabbbb-cccc-4ddd-8eee-ffff00000011','Châu Thanh Tùng',
 'dddddddd-dddd-4ddd-8ddd-ddddddddddd2',
 (SELECT ma_chuc_vu FROM chuc_vu WHERE ten_chuc_vu='Kế toán viên' LIMIT 1),
 'M','0901111115','tungct5599@cty.vn','Đang làm','nv15.jpg')
ON CONFLICT (ma_nhan_vien) DO NOTHING;


INSERT INTO chuc_vu_nhan_vien (ma_chuc_vu, ma_nhan_vien)
SELECT n.ma_chuc_vu, n.ma_nhan_vien
FROM nhan_vien n
WHERE n.ma_nhan_vien IN (
  'aaaabbbb-cccc-4ddd-8eee-ffff00000003',
  'aaaabbbb-cccc-4ddd-8eee-ffff00000004',
  'aaaabbbb-cccc-4ddd-8eee-ffff00000005',
  'aaaabbbb-cccc-4ddd-8eee-ffff00000006',
  'aaaabbbb-cccc-4ddd-8eee-ffff00000007',
  'aaaabbbb-cccc-4ddd-8eee-ffff00000008',
  'aaaabbbb-cccc-4ddd-8eee-ffff00000009',
  'aaaabbbb-cccc-4ddd-8eee-ffff0000000a',
  'aaaabbbb-cccc-4ddd-8eee-ffff0000000b',
  'aaaabbbb-cccc-4ddd-8eee-ffff0000000c',
  'aaaabbbb-cccc-4ddd-8eee-ffff0000000d',
  'aaaabbbb-cccc-4ddd-8eee-ffff0000000e',
  'aaaabbbb-cccc-4ddd-8eee-ffff0000000f',
  'aaaabbbb-cccc-4ddd-8eee-ffff00000010',
  'aaaabbbb-cccc-4ddd-8eee-ffff00000011'
)
ON CONFLICT DO NOTHING;

INSERT INTO cong_viec
(ma_cong_viec, ma_nv_giao_viec, ma_nv_nhan_viec, nhom_cong_viec, noi_dung_cong_viec, ngay_giao_viec, ngay_thuc_hien, thoi_gian, ngay_hoan_thanh)
VALUES
('88888888-8888-4888-8888-888888888881','aaaabbbb-cccc-4ddd-8eee-ffff00000003','aaaabbbb-cccc-4ddd-8eee-ffff00000008','Bảo dưỡng','Vệ sinh khu A','2025-10-02 08:00','2025-10-03','08:00','2025-10-03 17:00'),
('88888888-8888-4888-8888-888888888882','aaaabbbb-cccc-4ddd-8eee-ffff0000000a','aaaabbbb-cccc-4ddd-8eee-ffff00000008','Xây dựng','Kiểm tra vật tư khu B (H001)','2025-10-04 09:00','2025-10-05','09:00','2025-10-05 16:00'),
('88888888-8888-4888-8888-888888888883','aaaabbbb-cccc-4ddd-8eee-ffff0000000a','aaaabbbb-cccc-4ddd-8eee-ffff00000006','Bảo trì','Sửa mộ nứt hàng H002','2025-10-06 08:30','2025-10-06','08:30','2025-10-06 15:30'),
('88888888-8888-4888-8888-888888888884','aaaabbbb-cccc-4ddd-8eee-ffff00000003','aaaabbbb-cccc-4ddd-8eee-ffff0000000d','Xây dựng','Dựng/khắc bia mộ MP001','2025-10-07 08:00','2025-10-07','08:00','2025-10-07 17:30'),
('88888888-8888-4888-8888-888888888885','aaaabbbb-cccc-4ddd-8eee-ffff0000000f','aaaabbbb-cccc-4ddd-8eee-ffff00000007','Bảo trì','Chống lún lối đi khu K001','2025-10-08 07:45','2025-10-08','07:45','2025-10-08 16:45'),
('88888888-8888-4888-8888-888888888886','aaaabbbb-cccc-4ddd-8eee-ffff0000000f','aaaabbbb-cccc-4ddd-8eee-ffff0000000e','Chuẩn bị lễ','Dâng hoa/nhang định kỳ khu A','2025-10-10 09:00','2025-10-10','09:00','2025-10-10 11:00'),
('88888888-8888-4888-8888-888888888887','aaaabbbb-cccc-4ddd-8eee-ffff00000003','aaaabbbb-cccc-4ddd-8eee-ffff00000006','Khảo sát','Khảo sát nâng cấp mái che khu B','2025-10-09 14:00','2025-10-10','14:00','2025-10-10 17:00'),
('88888888-8888-4888-8888-888888888888','aaaabbbb-cccc-4ddd-8eee-ffff0000000a','aaaabbbb-cccc-4ddd-8eee-ffff00000009','Bảo dưỡng','Cắt cỏ toàn khu K002','2025-10-11 07:30','2025-10-11','07:30','2025-10-11 15:00');

INSERT INTO hinh_anh_cong_viec (ma_cong_viec, hinh_anh) VALUES
('88888888-8888-4888-8888-888888888881','cv01_1.jpg'),
('88888888-8888-4888-8888-888888888881','cv01_2.jpg'),
('88888888-8888-4888-8888-888888888882','cv02_1.jpg'),
('88888888-8888-4888-8888-888888888882','cv02_2.jpg'),
('88888888-8888-4888-8888-888888888883','cv03_1.jpg'),
('88888888-8888-4888-8888-888888888883','cv03_2.jpg'),
('88888888-8888-4888-8888-888888888884','cv04_1.jpg'),
('88888888-8888-4888-8888-888888888884','cv04_2.jpg'),
('88888888-8888-4888-8888-888888888885','cv05_1.jpg'),
('88888888-8888-4888-8888-888888888885','cv05_2.jpg'),
('88888888-8888-4888-8888-888888888886','cv06_1.jpg'),
('88888888-8888-4888-8888-888888888886','cv06_2.jpg'),
('88888888-8888-4888-8888-888888888887','cv07_1.jpg'),
('88888888-8888-4888-8888-888888888887','cv07_2.jpg'),
('88888888-8888-4888-8888-888888888888','cv08_1.jpg'),
('88888888-8888-4888-8888-888888888888','cv08_2.jpg')
ON CONFLICT DO NOTHING;

INSERT INTO diem_danh (ma_diem_danh, ma_nhan_vien, ngay, thoi_gian_vao, thoi_gian_ra) VALUES
('77777777-7777-4777-8777-777777777771','aaaabbbb-cccc-4ddd-8eee-ffff00000004','2025-10-03','08:00','17:00'), -- Tran Thi Binh
('77777777-7777-4777-8777-777777777772','aaaabbbb-cccc-4ddd-8eee-ffff00000005','2025-10-03','08:10','17:05'), -- Le Thanh Tam
('77777777-7777-4777-8777-777777777773','aaaabbbb-cccc-4ddd-8eee-ffff00000006','2025-10-03','07:55','16:50'), -- Pham Van Dung
('77777777-7777-4777-8777-777777777774','aaaabbbb-cccc-4ddd-8eee-ffff00000007','2025-10-03','08:05','17:15'), -- Vu Minh Duc
('77777777-7777-4777-8777-777777777775','aaaabbbb-cccc-4ddd-8eee-ffff00000008','2025-10-03','08:00','17:10'), -- Bui Quang Huy
('77777777-7777-4777-8777-777777777776','aaaabbbb-cccc-4ddd-8eee-ffff00000009','2025-10-03','08:12','17:20'), -- Hoang Anh Khoa
('77777777-7777-4777-8777-777777777777','aaaabbbb-cccc-4ddd-8eee-ffff0000000a','2025-10-03','07:50','16:45'), -- Phan Thanh Lam
('77777777-7777-4777-8777-777777777778','aaaabbbb-cccc-4ddd-8eee-ffff0000000b','2025-10-03','08:20','17:25'), -- Dang Thi Mai
('77777777-7777-4777-8777-777777777779','aaaabbbb-cccc-4ddd-8eee-ffff0000000c','2025-10-03','08:00','17:00'), -- Doan Van Nam
('77777777-7777-4777-8777-77777777777a','aaaabbbb-cccc-4ddd-8eee-ffff0000000d','2025-10-03','08:03','17:08'), -- Dinh Tuan Phong
('77777777-7777-4777-8777-77777777777b','aaaabbbb-cccc-4ddd-8eee-ffff0000000e','2025-10-03','08:07','17:02'), -- Ngo Thi Quynh
('77777777-7777-4777-8777-77777777777c','aaaabbbb-cccc-4ddd-8eee-ffff0000000f','2025-10-03','07:58','17:12'), -- Truong Hoai Son
('77777777-7777-4777-8777-77777777777d','aaaabbbb-cccc-4ddd-8eee-ffff00000010','2025-10-04','08:01','17:04'), -- Ly Gia Thinh
('77777777-7777-4777-8777-77777777777e','aaaabbbb-cccc-4ddd-8eee-ffff00000011','2025-10-04','08:15','17:18'), -- Chau Thanh Tung
('77777777-7777-4777-8777-77777777777f','aaaabbbb-cccc-4ddd-8eee-ffff00000003','2025-10-04','08:05','17:00'); -- Nguyen Van An

INSERT INTO danh_gia_nhan_vien
(ma_danh_gia, ma_nhan_vien, ngay_danh_gia, diem, ghi_chu, ma_nv_danh_gia) VALUES
('66666666-6666-4666-8666-666666666661','aaaabbbb-cccc-4ddd-8eee-ffff00000004','2025-10-03 18:00',85,'Hoàn thành tốt','aaaabbbb-cccc-4ddd-8eee-ffff00000003');

INSERT INTO tien_luong
(ma_luong, ma_nhan_vien, thang, nam, luong_co_ban, thuong, phat, ngay, ma_nv_ky_duyet) VALUES
('55555555-5555-4555-8555-555555555561','aaaabbbb-cccc-4ddd-8eee-ffff00000003',9,2025,'15000000','3000000','0','2025-09-30 17:00','aaaabbbb-cccc-4ddd-8eee-ffff0000000f'),
('55555555-5555-4555-8555-555555555562','aaaabbbb-cccc-4ddd-8eee-ffff00000004',9,2025,'12000000','2000000','0','2025-09-30 17:00','aaaabbbb-cccc-4ddd-8eee-ffff00000003'),
('55555555-5555-4555-8555-555555555563','aaaabbbb-cccc-4ddd-8eee-ffff00000005',9,2025,'11000000','1500000','0','2025-09-30 17:00','aaaabbbb-cccc-4ddd-8eee-ffff00000004'),
('55555555-5555-4555-8555-555555555564','aaaabbbb-cccc-4ddd-8eee-ffff00000006',9,2025,'13000000','2500000','0','2025-09-30 17:00','aaaabbbb-cccc-4ddd-8eee-ffff00000003'),
('55555555-5555-4555-8555-555555555565','aaaabbbb-cccc-4ddd-8eee-ffff00000007',9,2025,'11500000','1800000','0','2025-09-30 17:00','aaaabbbb-cccc-4ddd-8eee-ffff00000003'),
('55555555-5555-4555-8555-555555555566','aaaabbbb-cccc-4ddd-8eee-ffff00000008',9,2025,'10500000','1200000','0','2025-09-30 17:00','aaaabbbb-cccc-4ddd-8eee-ffff00000004'),
('55555555-5555-4555-8555-555555555567','aaaabbbb-cccc-4ddd-8eee-ffff00000009',9,2025,'10800000','1300000','0','2025-09-30 17:00','aaaabbbb-cccc-4ddd-8eee-ffff00000003'),
('55555555-5555-4555-8555-555555555568','aaaabbbb-cccc-4ddd-8eee-ffff0000000a',9,2025,'12500000','2200000','0','2025-09-30 17:00','aaaabbbb-cccc-4ddd-8eee-ffff0000000f'),
('55555555-5555-4555-8555-555555555569','aaaabbbb-cccc-4ddd-8eee-ffff0000000b',9,2025,'11200000','1400000','0','2025-09-30 17:00','aaaabbbb-cccc-4ddd-8eee-ffff00000004'),
('55555555-5555-4555-8555-55555555556a','aaaabbbb-cccc-4ddd-8eee-ffff0000000c',9,2025,'10000000','1000000','0','2025-09-30 17:00','aaaabbbb-cccc-4ddd-8eee-ffff00000003'),
('55555555-5555-4555-8555-55555555556b','aaaabbbb-cccc-4ddd-8eee-ffff0000000d',9,2025,'10400000','1200000','0','2025-09-30 17:00','aaaabbbb-cccc-4ddd-8eee-ffff00000003'),
('55555555-5555-4555-8555-55555555556c','aaaabbbb-cccc-4ddd-8eee-ffff0000000e',9,2025,'10200000','1100000','0','2025-09-30 17:00','aaaabbbb-cccc-4ddd-8eee-ffff00000004'),
('55555555-5555-4555-8555-55555555556d','aaaabbbb-cccc-4ddd-8eee-ffff0000000f',9,2025,'14500000','2800000','0','2025-09-30 17:00','aaaabbbb-cccc-4ddd-8eee-ffff00000003'),
('55555555-5555-4555-8555-55555555556e','aaaabbbb-cccc-4ddd-8eee-ffff00000010',9,2025,'10100000','1000000','200000','2025-09-30 17:00','aaaabbbb-cccc-4ddd-8eee-ffff00000004'),
('55555555-5555-4555-8555-55555555556f','aaaabbbb-cccc-4ddd-8eee-ffff00000011',9,2025,'11800000','1600000','0','2025-09-30 17:00','aaaabbbb-cccc-4ddd-8eee-ffff00000003');

INSERT INTO mo_phan(dia_chi_o, ten_o, chieu_dai, chieu_rong, dien_tich, ma_tinh_trang, ngay_khao_sat, ma_kieu_mo, gia_tri) VALUES
('6.1-1-1','Ô 1','2m','1m','2m2','11111111-2222-3333-4444-000000000005','2025-10-01 10:00','aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa2',20000000)
ON CONFLICT (dia_chi_o) DO UPDATE SET ma_tinh_trang=EXCLUDED.ma_tinh_trang, ma_kieu_mo=EXCLUDED.ma_kieu_mo;
INSERT INTO mo_phan(dia_chi_o, ten_o, chieu_dai, chieu_rong, dien_tich, ma_tinh_trang, ngay_khao_sat, ma_kieu_mo, gia_tri) VALUES
('6.1-1-2','Ô 2','2m','1m','2m2','11111111-2222-3333-4444-000000000006','2025-10-01 10:00','aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1',20000000)
ON CONFLICT (dia_chi_o) DO UPDATE SET ma_tinh_trang=EXCLUDED.ma_tinh_trang, ma_kieu_mo=EXCLUDED.ma_kieu_mo;
INSERT INTO mo_phan(dia_chi_o, ten_o, chieu_dai, chieu_rong, dien_tich, ma_tinh_trang, ngay_khao_sat, ma_kieu_mo, gia_tri) VALUES
('6.1-1-3','Ô 3','2m','1m','2m2','11111111-2222-3333-4444-000000000005','2025-10-01 10:00','aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1',20000000)
ON CONFLICT (dia_chi_o) DO UPDATE SET ma_tinh_trang=EXCLUDED.ma_tinh_trang, ma_kieu_mo=EXCLUDED.ma_kieu_mo;
INSERT INTO mo_phan(dia_chi_o, ten_o, chieu_dai, chieu_rong, dien_tich, ma_tinh_trang, ngay_khao_sat, ma_kieu_mo, gia_tri) VALUES
('6.1-1-4','Ô 4','2m','1m','2m2','11111111-2222-3333-4444-000000000002','2025-10-01 10:00','aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa2',20000000)
ON CONFLICT (dia_chi_o) DO UPDATE SET ma_tinh_trang=EXCLUDED.ma_tinh_trang, ma_kieu_mo=EXCLUDED.ma_kieu_mo;
INSERT INTO mo_phan(dia_chi_o, ten_o, chieu_dai, chieu_rong, dien_tich, ma_tinh_trang, ngay_khao_sat, ma_kieu_mo, gia_tri) VALUES
('6.1-1-5','Ô 5','2m','1m','2m2','11111111-2222-3333-4444-000000000005','2025-10-01 10:00','aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa2',20000000)
ON CONFLICT (dia_chi_o) DO UPDATE SET ma_tinh_trang=EXCLUDED.ma_tinh_trang, ma_kieu_mo=EXCLUDED.ma_kieu_mo;
INSERT INTO mo_phan(dia_chi_o, ten_o, chieu_dai, chieu_rong, dien_tich, ma_tinh_trang, ngay_khao_sat, ma_kieu_mo, gia_tri) VALUES
('6.1-1-6','Ô 6','2m','1m','2m2','11111111-2222-3333-4444-000000000002','2025-10-01 10:00','aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1',20000000)
ON CONFLICT (dia_chi_o) DO UPDATE SET ma_tinh_trang=EXCLUDED.ma_tinh_trang, ma_kieu_mo=EXCLUDED.ma_kieu_mo;
INSERT INTO mo_phan(dia_chi_o, ten_o, chieu_dai, chieu_rong, dien_tich, ma_tinh_trang, ngay_khao_sat, ma_kieu_mo, gia_tri) VALUES
('6.1-1-7','Ô 7','2m','1m','2m2','11111111-2222-3333-4444-000000000005','2025-10-01 10:00','aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa2',20000000)
ON CONFLICT (dia_chi_o) DO UPDATE SET ma_tinh_trang=EXCLUDED.ma_tinh_trang, ma_kieu_mo=EXCLUDED.ma_kieu_mo;
INSERT INTO mo_phan(dia_chi_o, ten_o, chieu_dai, chieu_rong, dien_tich, ma_tinh_trang, ngay_khao_sat, ma_kieu_mo, gia_tri) VALUES
('6.1-1-8','Ô 8','2m','1m','2m2','11111111-2222-3333-4444-000000000005','2025-10-01 10:00','aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1',20000000)
ON CONFLICT (dia_chi_o) DO UPDATE SET ma_tinh_trang=EXCLUDED.ma_tinh_trang, ma_kieu_mo=EXCLUDED.ma_kieu_mo;
INSERT INTO mo_phan(dia_chi_o, ten_o, chieu_dai, chieu_rong, dien_tich, ma_tinh_trang, ngay_khao_sat, ma_kieu_mo, gia_tri) VALUES
('6.1-1-9','Ô 9','2m','1m','2m2','11111111-2222-3333-4444-000000000006','2025-10-01 10:00','aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa2',20000000)
ON CONFLICT (dia_chi_o) DO UPDATE SET ma_tinh_trang=EXCLUDED.ma_tinh_trang, ma_kieu_mo=EXCLUDED.ma_kieu_mo;
INSERT INTO mo_phan(dia_chi_o, ten_o, chieu_dai, chieu_rong, dien_tich, ma_tinh_trang, ngay_khao_sat, ma_kieu_mo, gia_tri) VALUES
('6.1-2-1','Ô 1','2m','1m','2m2','11111111-2222-3333-4444-000000000005','2025-10-01 10:00','aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1',20000000)
ON CONFLICT (dia_chi_o) DO UPDATE SET ma_tinh_trang=EXCLUDED.ma_tinh_trang, ma_kieu_mo=EXCLUDED.ma_kieu_mo;
INSERT INTO mo_phan(dia_chi_o, ten_o, chieu_dai, chieu_rong, dien_tich, ma_tinh_trang, ngay_khao_sat, ma_kieu_mo, gia_tri) VALUES
('6.1-2-2','Ô 2','2m','1m','2m2','11111111-2222-3333-4444-000000000003','2025-10-01 10:00','aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa2',20000000)
ON CONFLICT (dia_chi_o) DO UPDATE SET ma_tinh_trang=EXCLUDED.ma_tinh_trang, ma_kieu_mo=EXCLUDED.ma_kieu_mo;
INSERT INTO mo_phan(dia_chi_o, ten_o, chieu_dai, chieu_rong, dien_tich, ma_tinh_trang, ngay_khao_sat, ma_kieu_mo, gia_tri) VALUES
('6.1-2-3','Ô 3','2m','1m','2m2','11111111-2222-3333-4444-000000000005','2025-10-01 10:00','aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa2',20000000)
ON CONFLICT (dia_chi_o) DO UPDATE SET ma_tinh_trang=EXCLUDED.ma_tinh_trang, ma_kieu_mo=EXCLUDED.ma_kieu_mo;
INSERT INTO mo_phan(dia_chi_o, ten_o, chieu_dai, chieu_rong, dien_tich, ma_tinh_trang, ngay_khao_sat, ma_kieu_mo, gia_tri) VALUES
('6.1-2-4','Ô 4','2m','1m','2m2','11111111-2222-3333-4444-000000000006','2025-10-01 10:00','aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa2',20000000)
ON CONFLICT (dia_chi_o) DO UPDATE SET ma_tinh_trang=EXCLUDED.ma_tinh_trang, ma_kieu_mo=EXCLUDED.ma_kieu_mo;
INSERT INTO mo_phan(dia_chi_o, ten_o, chieu_dai, chieu_rong, dien_tich, ma_tinh_trang, ngay_khao_sat, ma_kieu_mo, gia_tri) VALUES
('6.1-2-5','Ô 5','2m','1m','2m2','11111111-2222-3333-4444-000000000006','2025-10-01 10:00','aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa2',20000000)
ON CONFLICT (dia_chi_o) DO UPDATE SET ma_tinh_trang=EXCLUDED.ma_tinh_trang, ma_kieu_mo=EXCLUDED.ma_kieu_mo;
INSERT INTO mo_phan(dia_chi_o, ten_o, chieu_dai, chieu_rong, dien_tich, ma_tinh_trang, ngay_khao_sat, ma_kieu_mo, gia_tri) VALUES
('6.1-2-6','Ô 6','2m','1m','2m2','11111111-2222-3333-4444-000000000005','2025-10-01 10:00','aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa2',20000000)
ON CONFLICT (dia_chi_o) DO UPDATE SET ma_tinh_trang=EXCLUDED.ma_tinh_trang, ma_kieu_mo=EXCLUDED.ma_kieu_mo;
INSERT INTO mo_phan(dia_chi_o, ten_o, chieu_dai, chieu_rong, dien_tich, ma_tinh_trang, ngay_khao_sat, ma_kieu_mo, gia_tri) VALUES
('6.1-2-7','Ô 7','2m','1m','2m2','11111111-2222-3333-4444-000000000007','2025-10-01 10:00','aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa2',20000000)
ON CONFLICT (dia_chi_o) DO UPDATE SET ma_tinh_trang=EXCLUDED.ma_tinh_trang, ma_kieu_mo=EXCLUDED.ma_kieu_mo;
INSERT INTO mo_phan(dia_chi_o, ten_o, chieu_dai, chieu_rong, dien_tich, ma_tinh_trang, ngay_khao_sat, ma_kieu_mo, gia_tri) VALUES
('6.1-2-8','Ô 8','2m','1m','2m2','11111111-2222-3333-4444-000000000002','2025-10-01 10:00','aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1',20000000)
ON CONFLICT (dia_chi_o) DO UPDATE SET ma_tinh_trang=EXCLUDED.ma_tinh_trang, ma_kieu_mo=EXCLUDED.ma_kieu_mo;
INSERT INTO mo_phan(dia_chi_o, ten_o, chieu_dai, chieu_rong, dien_tich, ma_tinh_trang, ngay_khao_sat, ma_kieu_mo, gia_tri) VALUES
('6.1-2-9','Ô 9','2m','1m','2m2','11111111-2222-3333-4444-000000000007','2025-10-01 10:00','aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa2',20000000)
ON CONFLICT (dia_chi_o) DO UPDATE SET ma_tinh_trang=EXCLUDED.ma_tinh_trang, ma_kieu_mo=EXCLUDED.ma_kieu_mo;
INSERT INTO mo_phan(dia_chi_o, ten_o, chieu_dai, chieu_rong, dien_tich, ma_tinh_trang, ngay_khao_sat, ma_kieu_mo, gia_tri) VALUES
('6.1-3-1','Ô 1','2m','1m','2m2','11111111-2222-3333-4444-000000000001','2025-10-01 10:00','aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa2',20000000)
ON CONFLICT (dia_chi_o) DO UPDATE SET ma_tinh_trang=EXCLUDED.ma_tinh_trang, ma_kieu_mo=EXCLUDED.ma_kieu_mo;
INSERT INTO mo_phan(dia_chi_o, ten_o, chieu_dai, chieu_rong, dien_tich, ma_tinh_trang, ngay_khao_sat, ma_kieu_mo, gia_tri) VALUES
('6.1-3-2','Ô 2','2m','1m','2m2','11111111-2222-3333-4444-000000000002','2025-10-01 10:00','aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1',20000000)
ON CONFLICT (dia_chi_o) DO UPDATE SET ma_tinh_trang=EXCLUDED.ma_tinh_trang, ma_kieu_mo=EXCLUDED.ma_kieu_mo;
INSERT INTO mo_phan(dia_chi_o, ten_o, chieu_dai, chieu_rong, dien_tich, ma_tinh_trang, ngay_khao_sat, ma_kieu_mo, gia_tri) VALUES
('6.1-3-3','Ô 3','2m','1m','2m2','11111111-2222-3333-4444-000000000005','2025-10-01 10:00','aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1',20000000)
ON CONFLICT (dia_chi_o) DO UPDATE SET ma_tinh_trang=EXCLUDED.ma_tinh_trang, ma_kieu_mo=EXCLUDED.ma_kieu_mo;
INSERT INTO mo_phan(dia_chi_o, ten_o, chieu_dai, chieu_rong, dien_tich, ma_tinh_trang, ngay_khao_sat, ma_kieu_mo, gia_tri) VALUES
('6.1-3-4','Ô 4','2m','1m','2m2','11111111-2222-3333-4444-000000000001','2025-10-01 10:00','aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1',20000000)
ON CONFLICT (dia_chi_o) DO UPDATE SET ma_tinh_trang=EXCLUDED.ma_tinh_trang, ma_kieu_mo=EXCLUDED.ma_kieu_mo;
INSERT INTO mo_phan(dia_chi_o, ten_o, chieu_dai, chieu_rong, dien_tich, ma_tinh_trang, ngay_khao_sat, ma_kieu_mo, gia_tri) VALUES
('6.1-3-5','Ô 5','2m','1m','2m2','11111111-2222-3333-4444-000000000004','2025-10-01 10:00','aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa2',20000000)
ON CONFLICT (dia_chi_o) DO UPDATE SET ma_tinh_trang=EXCLUDED.ma_tinh_trang, ma_kieu_mo=EXCLUDED.ma_kieu_mo;
INSERT INTO mo_phan(dia_chi_o, ten_o, chieu_dai, chieu_rong, dien_tich, ma_tinh_trang, ngay_khao_sat, ma_kieu_mo, gia_tri) VALUES
('6.1-3-6','Ô 6','2m','1m','2m2','11111111-2222-3333-4444-000000000001','2025-10-01 10:00','aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1',20000000)
ON CONFLICT (dia_chi_o) DO UPDATE SET ma_tinh_trang=EXCLUDED.ma_tinh_trang, ma_kieu_mo=EXCLUDED.ma_kieu_mo;
INSERT INTO mo_phan(dia_chi_o, ten_o, chieu_dai, chieu_rong, dien_tich, ma_tinh_trang, ngay_khao_sat, ma_kieu_mo, gia_tri) VALUES
('6.1-3-7','Ô 7','2m','1m','2m2','11111111-2222-3333-4444-000000000002','2025-10-01 10:00','aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa2',20000000)
ON CONFLICT (dia_chi_o) DO UPDATE SET ma_tinh_trang=EXCLUDED.ma_tinh_trang, ma_kieu_mo=EXCLUDED.ma_kieu_mo;
INSERT INTO mo_phan(dia_chi_o, ten_o, chieu_dai, chieu_rong, dien_tich, ma_tinh_trang, ngay_khao_sat, ma_kieu_mo, gia_tri) VALUES
('6.1-3-8','Ô 8','2m','1m','2m2','11111111-2222-3333-4444-000000000005','2025-10-01 10:00','aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa2',20000000)
ON CONFLICT (dia_chi_o) DO UPDATE SET ma_tinh_trang=EXCLUDED.ma_tinh_trang, ma_kieu_mo=EXCLUDED.ma_kieu_mo;
INSERT INTO mo_phan(dia_chi_o, ten_o, chieu_dai, chieu_rong, dien_tich, ma_tinh_trang, ngay_khao_sat, ma_kieu_mo, gia_tri) VALUES
('6.1-3-9','Ô 9','2m','1m','2m2','11111111-2222-3333-4444-000000000002','2025-10-01 10:00','aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1',20000000)
ON CONFLICT (dia_chi_o) DO UPDATE SET ma_tinh_trang=EXCLUDED.ma_tinh_trang, ma_kieu_mo=EXCLUDED.ma_kieu_mo;
INSERT INTO mo_phan(dia_chi_o, ten_o, chieu_dai, chieu_rong, dien_tich, ma_tinh_trang, ngay_khao_sat, ma_kieu_mo, gia_tri) VALUES
('6.1-3-10','Ô 10','2m','1m','2m2','11111111-2222-3333-4444-000000000005','2025-10-01 10:00','aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa2',20000000)
ON CONFLICT (dia_chi_o) DO UPDATE SET ma_tinh_trang=EXCLUDED.ma_tinh_trang, ma_kieu_mo=EXCLUDED.ma_kieu_mo;
INSERT INTO mo_phan(dia_chi_o, ten_o, chieu_dai, chieu_rong, dien_tich, ma_tinh_trang, ngay_khao_sat, ma_kieu_mo, gia_tri) VALUES
('6.1-4-1','Ô 1','2m','1m','2m2','11111111-2222-3333-4444-000000000002','2025-10-01 10:00','aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa2',20000000)
ON CONFLICT (dia_chi_o) DO UPDATE SET ma_tinh_trang=EXCLUDED.ma_tinh_trang, ma_kieu_mo=EXCLUDED.ma_kieu_mo;
INSERT INTO mo_phan(dia_chi_o, ten_o, chieu_dai, chieu_rong, dien_tich, ma_tinh_trang, ngay_khao_sat, ma_kieu_mo, gia_tri) VALUES
('6.1-4-2','Ô 2','2m','1m','2m2','11111111-2222-3333-4444-000000000004','2025-10-01 10:00','aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1',20000000)
ON CONFLICT (dia_chi_o) DO UPDATE SET ma_tinh_trang=EXCLUDED.ma_tinh_trang, ma_kieu_mo=EXCLUDED.ma_kieu_mo;
INSERT INTO mo_phan(dia_chi_o, ten_o, chieu_dai, chieu_rong, dien_tich, ma_tinh_trang, ngay_khao_sat, ma_kieu_mo, gia_tri) VALUES
('6.1-4-3','Ô 3','2m','1m','2m2','11111111-2222-3333-4444-000000000005','2025-10-01 10:00','aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa2',20000000)
ON CONFLICT (dia_chi_o) DO UPDATE SET ma_tinh_trang=EXCLUDED.ma_tinh_trang, ma_kieu_mo=EXCLUDED.ma_kieu_mo;
INSERT INTO mo_phan(dia_chi_o, ten_o, chieu_dai, chieu_rong, dien_tich, ma_tinh_trang, ngay_khao_sat, ma_kieu_mo, gia_tri) VALUES
('6.1-4-4','Ô 4','2m','1m','2m2','11111111-2222-3333-4444-000000000005','2025-10-01 10:00','aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa2',20000000)
ON CONFLICT (dia_chi_o) DO UPDATE SET ma_tinh_trang=EXCLUDED.ma_tinh_trang, ma_kieu_mo=EXCLUDED.ma_kieu_mo;
INSERT INTO mo_phan(dia_chi_o, ten_o, chieu_dai, chieu_rong, dien_tich, ma_tinh_trang, ngay_khao_sat, ma_kieu_mo, gia_tri) VALUES
('6.1-4-5','Ô 5','2m','1m','2m2','11111111-2222-3333-4444-000000000003','2025-10-01 10:00','aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1',20000000)
ON CONFLICT (dia_chi_o) DO UPDATE SET ma_tinh_trang=EXCLUDED.ma_tinh_trang, ma_kieu_mo=EXCLUDED.ma_kieu_mo;
INSERT INTO mo_phan(dia_chi_o, ten_o, chieu_dai, chieu_rong, dien_tich, ma_tinh_trang, ngay_khao_sat, ma_kieu_mo, gia_tri) VALUES
('6.1-4-6','Ô 6','2m','1m','2m2','11111111-2222-3333-4444-000000000006','2025-10-01 10:00','aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1',20000000)
ON CONFLICT (dia_chi_o) DO UPDATE SET ma_tinh_trang=EXCLUDED.ma_tinh_trang, ma_kieu_mo=EXCLUDED.ma_kieu_mo;
INSERT INTO mo_phan(dia_chi_o, ten_o, chieu_dai, chieu_rong, dien_tich, ma_tinh_trang, ngay_khao_sat, ma_kieu_mo, gia_tri) VALUES
('6.1-4-7','Ô 7','2m','1m','2m2','11111111-2222-3333-4444-000000000003','2025-10-01 10:00','aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1',20000000)
ON CONFLICT (dia_chi_o) DO UPDATE SET ma_tinh_trang=EXCLUDED.ma_tinh_trang, ma_kieu_mo=EXCLUDED.ma_kieu_mo;
INSERT INTO mo_phan(dia_chi_o, ten_o, chieu_dai, chieu_rong, dien_tich, ma_tinh_trang, ngay_khao_sat, ma_kieu_mo, gia_tri) VALUES
('6.1-4-8','Ô 8','2m','1m','2m2','11111111-2222-3333-4444-000000000004','2025-10-01 10:00','aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa2',20000000)
ON CONFLICT (dia_chi_o) DO UPDATE SET ma_tinh_trang=EXCLUDED.ma_tinh_trang, ma_kieu_mo=EXCLUDED.ma_kieu_mo;
INSERT INTO mo_phan(dia_chi_o, ten_o, chieu_dai, chieu_rong, dien_tich, ma_tinh_trang, ngay_khao_sat, ma_kieu_mo, gia_tri) VALUES
('6.1-4-9','Ô 9','2m','1m','2m2','11111111-2222-3333-4444-000000000006','2025-10-01 10:00','aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1',20000000)
ON CONFLICT (dia_chi_o) DO UPDATE SET ma_tinh_trang=EXCLUDED.ma_tinh_trang, ma_kieu_mo=EXCLUDED.ma_kieu_mo;
INSERT INTO mo_phan(dia_chi_o, ten_o, chieu_dai, chieu_rong, dien_tich, ma_tinh_trang, ngay_khao_sat, ma_kieu_mo, gia_tri) VALUES
('6.1-4-10','Ô 10','2m','1m','2m2','11111111-2222-3333-4444-000000000005','2025-10-01 10:00','aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1',20000000)
ON CONFLICT (dia_chi_o) DO UPDATE SET ma_tinh_trang=EXCLUDED.ma_tinh_trang, ma_kieu_mo=EXCLUDED.ma_kieu_mo;
INSERT INTO mo_phan(dia_chi_o, ten_o, chieu_dai, chieu_rong, dien_tich, ma_tinh_trang, ngay_khao_sat, ma_kieu_mo, gia_tri) VALUES
('6.1-5-1','Ô 1','2m','1m','2m2','11111111-2222-3333-4444-000000000005','2025-10-01 10:00','aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa2',20000000)
ON CONFLICT (dia_chi_o) DO UPDATE SET ma_tinh_trang=EXCLUDED.ma_tinh_trang, ma_kieu_mo=EXCLUDED.ma_kieu_mo;
INSERT INTO mo_phan(dia_chi_o, ten_o, chieu_dai, chieu_rong, dien_tich, ma_tinh_trang, ngay_khao_sat, ma_kieu_mo, gia_tri) VALUES
('6.1-5-2','Ô 2','2m','1m','2m2','11111111-2222-3333-4444-000000000004','2025-10-01 10:00','aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa2',20000000)
ON CONFLICT (dia_chi_o) DO UPDATE SET ma_tinh_trang=EXCLUDED.ma_tinh_trang, ma_kieu_mo=EXCLUDED.ma_kieu_mo;
INSERT INTO mo_phan(dia_chi_o, ten_o, chieu_dai, chieu_rong, dien_tich, ma_tinh_trang, ngay_khao_sat, ma_kieu_mo, gia_tri) VALUES
('6.1-5-3','Ô 3','2m','1m','2m2','11111111-2222-3333-4444-000000000007','2025-10-01 10:00','aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa2',20000000)
ON CONFLICT (dia_chi_o) DO UPDATE SET ma_tinh_trang=EXCLUDED.ma_tinh_trang, ma_kieu_mo=EXCLUDED.ma_kieu_mo;
INSERT INTO mo_phan(dia_chi_o, ten_o, chieu_dai, chieu_rong, dien_tich, ma_tinh_trang, ngay_khao_sat, ma_kieu_mo, gia_tri) VALUES
('6.1-5-4','Ô 4','2m','1m','2m2','11111111-2222-3333-4444-000000000007','2025-10-01 10:00','aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa2',20000000)
ON CONFLICT (dia_chi_o) DO UPDATE SET ma_tinh_trang=EXCLUDED.ma_tinh_trang, ma_kieu_mo=EXCLUDED.ma_kieu_mo;
INSERT INTO mo_phan(dia_chi_o, ten_o, chieu_dai, chieu_rong, dien_tich, ma_tinh_trang, ngay_khao_sat, ma_kieu_mo, gia_tri) VALUES
('6.1-5-5','Ô 5','2m','1m','2m2','11111111-2222-3333-4444-000000000002','2025-10-01 10:00','aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1',20000000)
ON CONFLICT (dia_chi_o) DO UPDATE SET ma_tinh_trang=EXCLUDED.ma_tinh_trang, ma_kieu_mo=EXCLUDED.ma_kieu_mo;
INSERT INTO mo_phan(dia_chi_o, ten_o, chieu_dai, chieu_rong, dien_tich, ma_tinh_trang, ngay_khao_sat, ma_kieu_mo, gia_tri) VALUES
('6.1-5-6','Ô 6','2m','1m','2m2','11111111-2222-3333-4444-000000000002','2025-10-01 10:00','aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa2',20000000)
ON CONFLICT (dia_chi_o) DO UPDATE SET ma_tinh_trang=EXCLUDED.ma_tinh_trang, ma_kieu_mo=EXCLUDED.ma_kieu_mo;
INSERT INTO mo_phan(dia_chi_o, ten_o, chieu_dai, chieu_rong, dien_tich, ma_tinh_trang, ngay_khao_sat, ma_kieu_mo, gia_tri) VALUES
('6.1-5-7','Ô 7','2m','1m','2m2','11111111-2222-3333-4444-000000000007','2025-10-01 10:00','aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1',20000000)
ON CONFLICT (dia_chi_o) DO UPDATE SET ma_tinh_trang=EXCLUDED.ma_tinh_trang, ma_kieu_mo=EXCLUDED.ma_kieu_mo;
INSERT INTO mo_phan(dia_chi_o, ten_o, chieu_dai, chieu_rong, dien_tich, ma_tinh_trang, ngay_khao_sat, ma_kieu_mo, gia_tri) VALUES
('6.1-5-8','Ô 8','2m','1m','2m2','11111111-2222-3333-4444-000000000001','2025-10-01 10:00','aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa2',20000000)
ON CONFLICT (dia_chi_o) DO UPDATE SET ma_tinh_trang=EXCLUDED.ma_tinh_trang, ma_kieu_mo=EXCLUDED.ma_kieu_mo;
INSERT INTO mo_phan(dia_chi_o, ten_o, chieu_dai, chieu_rong, dien_tich, ma_tinh_trang, ngay_khao_sat, ma_kieu_mo, gia_tri) VALUES
('6.1-5-9','Ô 9','2m','1m','2m2','11111111-2222-3333-4444-000000000002','2025-10-01 10:00','aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1',20000000)
ON CONFLICT (dia_chi_o) DO UPDATE SET ma_tinh_trang=EXCLUDED.ma_tinh_trang, ma_kieu_mo=EXCLUDED.ma_kieu_mo;
INSERT INTO mo_phan(dia_chi_o, ten_o, chieu_dai, chieu_rong, dien_tich, ma_tinh_trang, ngay_khao_sat, ma_kieu_mo, gia_tri) VALUES
('6.1-5-10','Ô 10','2m','1m','2m2','11111111-2222-3333-4444-000000000007','2025-10-01 10:00','aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1',20000000)
ON CONFLICT (dia_chi_o) DO UPDATE SET ma_tinh_trang=EXCLUDED.ma_tinh_trang, ma_kieu_mo=EXCLUDED.ma_kieu_mo;
INSERT INTO mo_phan(dia_chi_o, ten_o, chieu_dai, chieu_rong, dien_tich, ma_tinh_trang, ngay_khao_sat, ma_kieu_mo, gia_tri) VALUES
('6.2-1-1','Ô 1','2m','1m','2m2','11111111-2222-3333-4444-000000000005','2025-10-01 10:00','aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1',20000000)
ON CONFLICT (dia_chi_o) DO UPDATE SET ma_tinh_trang=EXCLUDED.ma_tinh_trang, ma_kieu_mo=EXCLUDED.ma_kieu_mo;
INSERT INTO mo_phan(dia_chi_o, ten_o, chieu_dai, chieu_rong, dien_tich, ma_tinh_trang, ngay_khao_sat, ma_kieu_mo, gia_tri) VALUES
('6.2-1-2','Ô 2','2m','1m','2m2','11111111-2222-3333-4444-000000000005','2025-10-01 10:00','aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1',20000000)
ON CONFLICT (dia_chi_o) DO UPDATE SET ma_tinh_trang=EXCLUDED.ma_tinh_trang, ma_kieu_mo=EXCLUDED.ma_kieu_mo;
INSERT INTO mo_phan(dia_chi_o, ten_o, chieu_dai, chieu_rong, dien_tich, ma_tinh_trang, ngay_khao_sat, ma_kieu_mo, gia_tri) VALUES
('6.2-1-3','Ô 3','2m','1m','2m2','11111111-2222-3333-4444-000000000002','2025-10-01 10:00','aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa2',20000000)
ON CONFLICT (dia_chi_o) DO UPDATE SET ma_tinh_trang=EXCLUDED.ma_tinh_trang, ma_kieu_mo=EXCLUDED.ma_kieu_mo;
INSERT INTO mo_phan(dia_chi_o, ten_o, chieu_dai, chieu_rong, dien_tich, ma_tinh_trang, ngay_khao_sat, ma_kieu_mo, gia_tri) VALUES
('6.2-1-4','Ô 4','2m','1m','2m2','11111111-2222-3333-4444-000000000004','2025-10-01 10:00','aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1',20000000)
ON CONFLICT (dia_chi_o) DO UPDATE SET ma_tinh_trang=EXCLUDED.ma_tinh_trang, ma_kieu_mo=EXCLUDED.ma_kieu_mo;
INSERT INTO mo_phan(dia_chi_o, ten_o, chieu_dai, chieu_rong, dien_tich, ma_tinh_trang, ngay_khao_sat, ma_kieu_mo, gia_tri) VALUES
('6.2-1-5','Ô 5','2m','1m','2m2','11111111-2222-3333-4444-000000000005','2025-10-01 10:00','aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1',20000000)
ON CONFLICT (dia_chi_o) DO UPDATE SET ma_tinh_trang=EXCLUDED.ma_tinh_trang, ma_kieu_mo=EXCLUDED.ma_kieu_mo;
INSERT INTO mo_phan(dia_chi_o, ten_o, chieu_dai, chieu_rong, dien_tich, ma_tinh_trang, ngay_khao_sat, ma_kieu_mo, gia_tri) VALUES
('6.2-1-6','Ô 6','2m','1m','2m2','11111111-2222-3333-4444-000000000006','2025-10-01 10:00','aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1',20000000)
ON CONFLICT (dia_chi_o) DO UPDATE SET ma_tinh_trang=EXCLUDED.ma_tinh_trang, ma_kieu_mo=EXCLUDED.ma_kieu_mo;
INSERT INTO mo_phan(dia_chi_o, ten_o, chieu_dai, chieu_rong, dien_tich, ma_tinh_trang, ngay_khao_sat, ma_kieu_mo, gia_tri) VALUES
('6.2-1-7','Ô 7','2m','1m','2m2','11111111-2222-3333-4444-000000000004','2025-10-01 10:00','aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa2',20000000)
ON CONFLICT (dia_chi_o) DO UPDATE SET ma_tinh_trang=EXCLUDED.ma_tinh_trang, ma_kieu_mo=EXCLUDED.ma_kieu_mo;
INSERT INTO mo_phan(dia_chi_o, ten_o, chieu_dai, chieu_rong, dien_tich, ma_tinh_trang, ngay_khao_sat, ma_kieu_mo, gia_tri) VALUES
('6.2-1-8','Ô 8','2m','1m','2m2','11111111-2222-3333-4444-000000000005','2025-10-01 10:00','aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1',20000000)
ON CONFLICT (dia_chi_o) DO UPDATE SET ma_tinh_trang=EXCLUDED.ma_tinh_trang, ma_kieu_mo=EXCLUDED.ma_kieu_mo;
INSERT INTO mo_phan(dia_chi_o, ten_o, chieu_dai, chieu_rong, dien_tich, ma_tinh_trang, ngay_khao_sat, ma_kieu_mo, gia_tri) VALUES
('6.2-1-9','Ô 9','2m','1m','2m2','11111111-2222-3333-4444-000000000001','2025-10-01 10:00','aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa2',20000000)
ON CONFLICT (dia_chi_o) DO UPDATE SET ma_tinh_trang=EXCLUDED.ma_tinh_trang, ma_kieu_mo=EXCLUDED.ma_kieu_mo;
INSERT INTO mo_phan(dia_chi_o, ten_o, chieu_dai, chieu_rong, dien_tich, ma_tinh_trang, ngay_khao_sat, ma_kieu_mo, gia_tri) VALUES
('6.2-1-10','Ô 10','2m','1m','2m2','11111111-2222-3333-4444-000000000001','2025-10-01 10:00','aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa2',20000000)
ON CONFLICT (dia_chi_o) DO UPDATE SET ma_tinh_trang=EXCLUDED.ma_tinh_trang, ma_kieu_mo=EXCLUDED.ma_kieu_mo;
INSERT INTO mo_phan(dia_chi_o, ten_o, chieu_dai, chieu_rong, dien_tich, ma_tinh_trang, ngay_khao_sat, ma_kieu_mo, gia_tri) VALUES
('6.2-2-1','Ô 1','2m','1m','2m2','11111111-2222-3333-4444-000000000005','2025-10-01 10:00','aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa2',20000000)
ON CONFLICT (dia_chi_o) DO UPDATE SET ma_tinh_trang=EXCLUDED.ma_tinh_trang, ma_kieu_mo=EXCLUDED.ma_kieu_mo;
INSERT INTO mo_phan(dia_chi_o, ten_o, chieu_dai, chieu_rong, dien_tich, ma_tinh_trang, ngay_khao_sat, ma_kieu_mo, gia_tri) VALUES
('6.2-2-2','Ô 2','2m','1m','2m2','11111111-2222-3333-4444-000000000003','2025-10-01 10:00','aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa2',20000000)
ON CONFLICT (dia_chi_o) DO UPDATE SET ma_tinh_trang=EXCLUDED.ma_tinh_trang, ma_kieu_mo=EXCLUDED.ma_kieu_mo;
INSERT INTO mo_phan(dia_chi_o, ten_o, chieu_dai, chieu_rong, dien_tich, ma_tinh_trang, ngay_khao_sat, ma_kieu_mo, gia_tri) VALUES
('6.2-2-3','Ô 3','2m','1m','2m2','11111111-2222-3333-4444-000000000001','2025-10-01 10:00','aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa2',20000000)
ON CONFLICT (dia_chi_o) DO UPDATE SET ma_tinh_trang=EXCLUDED.ma_tinh_trang, ma_kieu_mo=EXCLUDED.ma_kieu_mo;
INSERT INTO mo_phan(dia_chi_o, ten_o, chieu_dai, chieu_rong, dien_tich, ma_tinh_trang, ngay_khao_sat, ma_kieu_mo, gia_tri) VALUES
('6.2-2-4','Ô 4','2m','1m','2m2','11111111-2222-3333-4444-000000000007','2025-10-01 10:00','aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa2',20000000)
ON CONFLICT (dia_chi_o) DO UPDATE SET ma_tinh_trang=EXCLUDED.ma_tinh_trang, ma_kieu_mo=EXCLUDED.ma_kieu_mo;
INSERT INTO mo_phan(dia_chi_o, ten_o, chieu_dai, chieu_rong, dien_tich, ma_tinh_trang, ngay_khao_sat, ma_kieu_mo, gia_tri) VALUES
('6.2-2-5','Ô 5','2m','1m','2m2','11111111-2222-3333-4444-000000000002','2025-10-01 10:00','aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1',20000000)
ON CONFLICT (dia_chi_o) DO UPDATE SET ma_tinh_trang=EXCLUDED.ma_tinh_trang, ma_kieu_mo=EXCLUDED.ma_kieu_mo;
INSERT INTO mo_phan(dia_chi_o, ten_o, chieu_dai, chieu_rong, dien_tich, ma_tinh_trang, ngay_khao_sat, ma_kieu_mo, gia_tri) VALUES
('6.2-2-6','Ô 6','2m','1m','2m2','11111111-2222-3333-4444-000000000004','2025-10-01 10:00','aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa2',20000000)
ON CONFLICT (dia_chi_o) DO UPDATE SET ma_tinh_trang=EXCLUDED.ma_tinh_trang, ma_kieu_mo=EXCLUDED.ma_kieu_mo;
INSERT INTO mo_phan(dia_chi_o, ten_o, chieu_dai, chieu_rong, dien_tich, ma_tinh_trang, ngay_khao_sat, ma_kieu_mo, gia_tri) VALUES
('6.2-2-7','Ô 7','2m','1m','2m2','11111111-2222-3333-4444-000000000006','2025-10-01 10:00','aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1',20000000)
ON CONFLICT (dia_chi_o) DO UPDATE SET ma_tinh_trang=EXCLUDED.ma_tinh_trang, ma_kieu_mo=EXCLUDED.ma_kieu_mo;
INSERT INTO mo_phan(dia_chi_o, ten_o, chieu_dai, chieu_rong, dien_tich, ma_tinh_trang, ngay_khao_sat, ma_kieu_mo, gia_tri) VALUES
('6.2-2-8','Ô 8','2m','1m','2m2','11111111-2222-3333-4444-000000000005','2025-10-01 10:00','aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1',20000000)
ON CONFLICT (dia_chi_o) DO UPDATE SET ma_tinh_trang=EXCLUDED.ma_tinh_trang, ma_kieu_mo=EXCLUDED.ma_kieu_mo;
INSERT INTO mo_phan(dia_chi_o, ten_o, chieu_dai, chieu_rong, dien_tich, ma_tinh_trang, ngay_khao_sat, ma_kieu_mo, gia_tri) VALUES
('6.2-2-9','Ô 9','2m','1m','2m2','11111111-2222-3333-4444-000000000003','2025-10-01 10:00','aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa2',20000000)
ON CONFLICT (dia_chi_o) DO UPDATE SET ma_tinh_trang=EXCLUDED.ma_tinh_trang, ma_kieu_mo=EXCLUDED.ma_kieu_mo;
INSERT INTO mo_phan(dia_chi_o, ten_o, chieu_dai, chieu_rong, dien_tich, ma_tinh_trang, ngay_khao_sat, ma_kieu_mo, gia_tri) VALUES
('6.2-2-10','Ô 10','2m','1m','2m2','11111111-2222-3333-4444-000000000006','2025-10-01 10:00','aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa2',20000000)
ON CONFLICT (dia_chi_o) DO UPDATE SET ma_tinh_trang=EXCLUDED.ma_tinh_trang, ma_kieu_mo=EXCLUDED.ma_kieu_mo;
INSERT INTO mo_phan(dia_chi_o, ten_o, chieu_dai, chieu_rong, dien_tich, ma_tinh_trang, ngay_khao_sat, ma_kieu_mo, gia_tri) VALUES
('6.2-3-1','Ô 1','2m','1m','2m2','11111111-2222-3333-4444-000000000005','2025-10-01 10:00','aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa2',20000000)
ON CONFLICT (dia_chi_o) DO UPDATE SET ma_tinh_trang=EXCLUDED.ma_tinh_trang, ma_kieu_mo=EXCLUDED.ma_kieu_mo;
INSERT INTO mo_phan(dia_chi_o, ten_o, chieu_dai, chieu_rong, dien_tich, ma_tinh_trang, ngay_khao_sat, ma_kieu_mo, gia_tri) VALUES
('6.2-3-2','Ô 2','2m','1m','2m2','11111111-2222-3333-4444-000000000007','2025-10-01 10:00','aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1',20000000)
ON CONFLICT (dia_chi_o) DO UPDATE SET ma_tinh_trang=EXCLUDED.ma_tinh_trang, ma_kieu_mo=EXCLUDED.ma_kieu_mo;
INSERT INTO mo_phan(dia_chi_o, ten_o, chieu_dai, chieu_rong, dien_tich, ma_tinh_trang, ngay_khao_sat, ma_kieu_mo, gia_tri) VALUES
('6.2-3-3','Ô 3','2m','1m','2m2','11111111-2222-3333-4444-000000000002','2025-10-01 10:00','aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1',20000000)
ON CONFLICT (dia_chi_o) DO UPDATE SET ma_tinh_trang=EXCLUDED.ma_tinh_trang, ma_kieu_mo=EXCLUDED.ma_kieu_mo;
INSERT INTO mo_phan(dia_chi_o, ten_o, chieu_dai, chieu_rong, dien_tich, ma_tinh_trang, ngay_khao_sat, ma_kieu_mo, gia_tri) VALUES
('6.2-3-4','Ô 4','2m','1m','2m2','11111111-2222-3333-4444-000000000003','2025-10-01 10:00','aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1',20000000)
ON CONFLICT (dia_chi_o) DO UPDATE SET ma_tinh_trang=EXCLUDED.ma_tinh_trang, ma_kieu_mo=EXCLUDED.ma_kieu_mo;
INSERT INTO mo_phan(dia_chi_o, ten_o, chieu_dai, chieu_rong, dien_tich, ma_tinh_trang, ngay_khao_sat, ma_kieu_mo, gia_tri) VALUES
('6.2-3-5','Ô 5','2m','1m','2m2','11111111-2222-3333-4444-000000000001','2025-10-01 10:00','aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa2',20000000)
ON CONFLICT (dia_chi_o) DO UPDATE SET ma_tinh_trang=EXCLUDED.ma_tinh_trang, ma_kieu_mo=EXCLUDED.ma_kieu_mo;
INSERT INTO mo_phan(dia_chi_o, ten_o, chieu_dai, chieu_rong, dien_tich, ma_tinh_trang, ngay_khao_sat, ma_kieu_mo, gia_tri) VALUES
('6.2-3-6','Ô 6','2m','1m','2m2','11111111-2222-3333-4444-000000000003','2025-10-01 10:00','aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa2',20000000)
ON CONFLICT (dia_chi_o) DO UPDATE SET ma_tinh_trang=EXCLUDED.ma_tinh_trang, ma_kieu_mo=EXCLUDED.ma_kieu_mo;
INSERT INTO mo_phan(dia_chi_o, ten_o, chieu_dai, chieu_rong, dien_tich, ma_tinh_trang, ngay_khao_sat, ma_kieu_mo, gia_tri) VALUES
('6.2-3-7','Ô 7','2m','1m','2m2','11111111-2222-3333-4444-000000000004','2025-10-01 10:00','aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa2',20000000)
ON CONFLICT (dia_chi_o) DO UPDATE SET ma_tinh_trang=EXCLUDED.ma_tinh_trang, ma_kieu_mo=EXCLUDED.ma_kieu_mo;
INSERT INTO mo_phan(dia_chi_o, ten_o, chieu_dai, chieu_rong, dien_tich, ma_tinh_trang, ngay_khao_sat, ma_kieu_mo, gia_tri) VALUES
('6.2-3-8','Ô 8','2m','1m','2m2','11111111-2222-3333-4444-000000000006','2025-10-01 10:00','aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1',20000000)
ON CONFLICT (dia_chi_o) DO UPDATE SET ma_tinh_trang=EXCLUDED.ma_tinh_trang, ma_kieu_mo=EXCLUDED.ma_kieu_mo;
INSERT INTO mo_phan(dia_chi_o, ten_o, chieu_dai, chieu_rong, dien_tich, ma_tinh_trang, ngay_khao_sat, ma_kieu_mo, gia_tri) VALUES
('6.2-4-1','Ô 1','2m','1m','2m2','11111111-2222-3333-4444-000000000002','2025-10-01 10:00','aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa2',20000000)
ON CONFLICT (dia_chi_o) DO UPDATE SET ma_tinh_trang=EXCLUDED.ma_tinh_trang, ma_kieu_mo=EXCLUDED.ma_kieu_mo;
INSERT INTO mo_phan(dia_chi_o, ten_o, chieu_dai, chieu_rong, dien_tich, ma_tinh_trang, ngay_khao_sat, ma_kieu_mo, gia_tri) VALUES
('6.3-1-1','Ô 1','2m','1m','2m2','11111111-2222-3333-4444-000000000002','2025-10-01 10:00','aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa2',20000000)
ON CONFLICT (dia_chi_o) DO UPDATE SET ma_tinh_trang=EXCLUDED.ma_tinh_trang, ma_kieu_mo=EXCLUDED.ma_kieu_mo;
INSERT INTO mo_phan(dia_chi_o, ten_o, chieu_dai, chieu_rong, dien_tich, ma_tinh_trang, ngay_khao_sat, ma_kieu_mo, gia_tri) VALUES
('6.3-1-2','Ô 2','2m','1m','2m2','11111111-2222-3333-4444-000000000005','2025-10-01 10:00','aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1',20000000)
ON CONFLICT (dia_chi_o) DO UPDATE SET ma_tinh_trang=EXCLUDED.ma_tinh_trang, ma_kieu_mo=EXCLUDED.ma_kieu_mo;
INSERT INTO mo_phan(dia_chi_o, ten_o, chieu_dai, chieu_rong, dien_tich, ma_tinh_trang, ngay_khao_sat, ma_kieu_mo, gia_tri) VALUES
('6.3-1-3','Ô 3','2m','1m','2m2','11111111-2222-3333-4444-000000000006','2025-10-01 10:00','aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa2',20000000)
ON CONFLICT (dia_chi_o) DO UPDATE SET ma_tinh_trang=EXCLUDED.ma_tinh_trang, ma_kieu_mo=EXCLUDED.ma_kieu_mo;
INSERT INTO mo_phan(dia_chi_o, ten_o, chieu_dai, chieu_rong, dien_tich, ma_tinh_trang, ngay_khao_sat, ma_kieu_mo, gia_tri) VALUES
('6.3-1-4','Ô 4','2m','1m','2m2','11111111-2222-3333-4444-000000000007','2025-10-01 10:00','aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1',20000000)
ON CONFLICT (dia_chi_o) DO UPDATE SET ma_tinh_trang=EXCLUDED.ma_tinh_trang, ma_kieu_mo=EXCLUDED.ma_kieu_mo;
INSERT INTO mo_phan(dia_chi_o, ten_o, chieu_dai, chieu_rong, dien_tich, ma_tinh_trang, ngay_khao_sat, ma_kieu_mo, gia_tri) VALUES
('6.3-2-1','Ô 1','2m','1m','2m2','11111111-2222-3333-4444-000000000006','2025-10-01 10:00','aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1',20000000)
ON CONFLICT (dia_chi_o) DO UPDATE SET ma_tinh_trang=EXCLUDED.ma_tinh_trang, ma_kieu_mo=EXCLUDED.ma_kieu_mo;
INSERT INTO mo_phan(dia_chi_o, ten_o, chieu_dai, chieu_rong, dien_tich, ma_tinh_trang, ngay_khao_sat, ma_kieu_mo, gia_tri) VALUES
('6.3-2-2','Ô 2','2m','1m','2m2','11111111-2222-3333-4444-000000000002','2025-10-01 10:00','aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1',20000000)
ON CONFLICT (dia_chi_o) DO UPDATE SET ma_tinh_trang=EXCLUDED.ma_tinh_trang, ma_kieu_mo=EXCLUDED.ma_kieu_mo;
INSERT INTO mo_phan(dia_chi_o, ten_o, chieu_dai, chieu_rong, dien_tich, ma_tinh_trang, ngay_khao_sat, ma_kieu_mo, gia_tri) VALUES
('6.3-2-3','Ô 3','2m','1m','2m2','11111111-2222-3333-4444-000000000004','2025-10-01 10:00','aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1',20000000)
ON CONFLICT (dia_chi_o) DO UPDATE SET ma_tinh_trang=EXCLUDED.ma_tinh_trang, ma_kieu_mo=EXCLUDED.ma_kieu_mo;
INSERT INTO mo_phan(dia_chi_o, ten_o, chieu_dai, chieu_rong, dien_tich, ma_tinh_trang, ngay_khao_sat, ma_kieu_mo, gia_tri) VALUES
('6.3-2-4','Ô 4','2m','1m','2m2','11111111-2222-3333-4444-000000000005','2025-10-01 10:00','aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa2',20000000)
ON CONFLICT (dia_chi_o) DO UPDATE SET ma_tinh_trang=EXCLUDED.ma_tinh_trang, ma_kieu_mo=EXCLUDED.ma_kieu_mo;
INSERT INTO mo_phan(dia_chi_o, ten_o, chieu_dai, chieu_rong, dien_tich, ma_tinh_trang, ngay_khao_sat, ma_kieu_mo, gia_tri) VALUES
('6.3-2-5','Ô 5','2m','1m','2m2','11111111-2222-3333-4444-000000000002','2025-10-01 10:00','aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa2',20000000)
ON CONFLICT (dia_chi_o) DO UPDATE SET ma_tinh_trang=EXCLUDED.ma_tinh_trang, ma_kieu_mo=EXCLUDED.ma_kieu_mo;
INSERT INTO mo_phan(dia_chi_o, ten_o, chieu_dai, chieu_rong, dien_tich, ma_tinh_trang, ngay_khao_sat, ma_kieu_mo, gia_tri) VALUES
('6.3-2-6','Ô 6','2m','1m','2m2','11111111-2222-3333-4444-000000000007','2025-10-01 10:00','aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1',20000000)
ON CONFLICT (dia_chi_o) DO UPDATE SET ma_tinh_trang=EXCLUDED.ma_tinh_trang, ma_kieu_mo=EXCLUDED.ma_kieu_mo;
INSERT INTO mo_phan(dia_chi_o, ten_o, chieu_dai, chieu_rong, dien_tich, ma_tinh_trang, ngay_khao_sat, ma_kieu_mo, gia_tri) VALUES
('6.3-2-7','Ô 7','2m','1m','2m2','11111111-2222-3333-4444-000000000003','2025-10-01 10:00','aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa2',20000000)
ON CONFLICT (dia_chi_o) DO UPDATE SET ma_tinh_trang=EXCLUDED.ma_tinh_trang, ma_kieu_mo=EXCLUDED.ma_kieu_mo;
INSERT INTO mo_phan(dia_chi_o, ten_o, chieu_dai, chieu_rong, dien_tich, ma_tinh_trang, ngay_khao_sat, ma_kieu_mo, gia_tri) VALUES
('6.3-2-8','Ô 8','2m','1m','2m2','11111111-2222-3333-4444-000000000001','2025-10-01 10:00','aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1',20000000)
ON CONFLICT (dia_chi_o) DO UPDATE SET ma_tinh_trang=EXCLUDED.ma_tinh_trang, ma_kieu_mo=EXCLUDED.ma_kieu_mo;
INSERT INTO mo_phan(dia_chi_o, ten_o, chieu_dai, chieu_rong, dien_tich, ma_tinh_trang, ngay_khao_sat, ma_kieu_mo, gia_tri) VALUES
('6.3-2-9','Ô 9','2m','1m','2m2','11111111-2222-3333-4444-000000000004','2025-10-01 10:00','aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa2',20000000)
ON CONFLICT (dia_chi_o) DO UPDATE SET ma_tinh_trang=EXCLUDED.ma_tinh_trang, ma_kieu_mo=EXCLUDED.ma_kieu_mo;
INSERT INTO mo_phan(dia_chi_o, ten_o, chieu_dai, chieu_rong, dien_tich, ma_tinh_trang, ngay_khao_sat, ma_kieu_mo, gia_tri) VALUES
('6.3-2-10','Ô 10','2m','1m','2m2','11111111-2222-3333-4444-000000000004','2025-10-01 10:00','aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa2',20000000)
ON CONFLICT (dia_chi_o) DO UPDATE SET ma_tinh_trang=EXCLUDED.ma_tinh_trang, ma_kieu_mo=EXCLUDED.ma_kieu_mo;
INSERT INTO mo_phan(dia_chi_o, ten_o, chieu_dai, chieu_rong, dien_tich, ma_tinh_trang, ngay_khao_sat, ma_kieu_mo, gia_tri) VALUES
('6.3-2-11','Ô 11','2m','1m','2m2','11111111-2222-3333-4444-000000000003','2025-10-01 10:00','aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa2',20000000)
ON CONFLICT (dia_chi_o) DO UPDATE SET ma_tinh_trang=EXCLUDED.ma_tinh_trang, ma_kieu_mo=EXCLUDED.ma_kieu_mo;
INSERT INTO mo_phan(dia_chi_o, ten_o, chieu_dai, chieu_rong, dien_tich, ma_tinh_trang, ngay_khao_sat, ma_kieu_mo, gia_tri) VALUES
('6.3-2-12','Ô 12','2m','1m','2m2','11111111-2222-3333-4444-000000000007','2025-10-01 10:00','aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa2',20000000)
ON CONFLICT (dia_chi_o) DO UPDATE SET ma_tinh_trang=EXCLUDED.ma_tinh_trang, ma_kieu_mo=EXCLUDED.ma_kieu_mo;
INSERT INTO mo_phan(dia_chi_o, ten_o, chieu_dai, chieu_rong, dien_tich, ma_tinh_trang, ngay_khao_sat, ma_kieu_mo, gia_tri) VALUES
('6.3-3-1','Ô 1','2m','1m','2m2','11111111-2222-3333-4444-000000000007','2025-10-01 10:00','aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1',20000000)
ON CONFLICT (dia_chi_o) DO UPDATE SET ma_tinh_trang=EXCLUDED.ma_tinh_trang, ma_kieu_mo=EXCLUDED.ma_kieu_mo;
INSERT INTO mo_phan(dia_chi_o, ten_o, chieu_dai, chieu_rong, dien_tich, ma_tinh_trang, ngay_khao_sat, ma_kieu_mo, gia_tri) VALUES
('6.3-3-2','Ô 2','2m','1m','2m2','11111111-2222-3333-4444-000000000001','2025-10-01 10:00','aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1',20000000)
ON CONFLICT (dia_chi_o) DO UPDATE SET ma_tinh_trang=EXCLUDED.ma_tinh_trang, ma_kieu_mo=EXCLUDED.ma_kieu_mo;
INSERT INTO mo_phan(dia_chi_o, ten_o, chieu_dai, chieu_rong, dien_tich, ma_tinh_trang, ngay_khao_sat, ma_kieu_mo, gia_tri) VALUES
('6.3-3-3','Ô 3','2m','1m','2m2','11111111-2222-3333-4444-000000000005','2025-10-01 10:00','aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1',20000000)
ON CONFLICT (dia_chi_o) DO UPDATE SET ma_tinh_trang=EXCLUDED.ma_tinh_trang, ma_kieu_mo=EXCLUDED.ma_kieu_mo;
INSERT INTO mo_phan(dia_chi_o, ten_o, chieu_dai, chieu_rong, dien_tich, ma_tinh_trang, ngay_khao_sat, ma_kieu_mo, gia_tri) VALUES
('6.3-3-4','Ô 4','2m','1m','2m2','11111111-2222-3333-4444-000000000002','2025-10-01 10:00','aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1',20000000)
ON CONFLICT (dia_chi_o) DO UPDATE SET ma_tinh_trang=EXCLUDED.ma_tinh_trang, ma_kieu_mo=EXCLUDED.ma_kieu_mo;
INSERT INTO mo_phan(dia_chi_o, ten_o, chieu_dai, chieu_rong, dien_tich, ma_tinh_trang, ngay_khao_sat, ma_kieu_mo, gia_tri) VALUES
('6.3-3-5','Ô 5','2m','1m','2m2','11111111-2222-3333-4444-000000000006','2025-10-01 10:00','aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1',20000000)
ON CONFLICT (dia_chi_o) DO UPDATE SET ma_tinh_trang=EXCLUDED.ma_tinh_trang, ma_kieu_mo=EXCLUDED.ma_kieu_mo;
INSERT INTO mo_phan(dia_chi_o, ten_o, chieu_dai, chieu_rong, dien_tich, ma_tinh_trang, ngay_khao_sat, ma_kieu_mo, gia_tri) VALUES
('6.3-3-6','Ô 6','2m','1m','2m2','11111111-2222-3333-4444-000000000004','2025-10-01 10:00','aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1',20000000)
ON CONFLICT (dia_chi_o) DO UPDATE SET ma_tinh_trang=EXCLUDED.ma_tinh_trang, ma_kieu_mo=EXCLUDED.ma_kieu_mo;
INSERT INTO mo_phan(dia_chi_o, ten_o, chieu_dai, chieu_rong, dien_tich, ma_tinh_trang, ngay_khao_sat, ma_kieu_mo, gia_tri) VALUES
('6.3-3-7','Ô 7','2m','1m','2m2','11111111-2222-3333-4444-000000000005','2025-10-01 10:00','aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa2',20000000)
ON CONFLICT (dia_chi_o) DO UPDATE SET ma_tinh_trang=EXCLUDED.ma_tinh_trang, ma_kieu_mo=EXCLUDED.ma_kieu_mo;
INSERT INTO mo_phan(dia_chi_o, ten_o, chieu_dai, chieu_rong, dien_tich, ma_tinh_trang, ngay_khao_sat, ma_kieu_mo, gia_tri) VALUES
('6.3-3-8','Ô 8','2m','1m','2m2','11111111-2222-3333-4444-000000000007','2025-10-01 10:00','aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa2',20000000)
ON CONFLICT (dia_chi_o) DO UPDATE SET ma_tinh_trang=EXCLUDED.ma_tinh_trang, ma_kieu_mo=EXCLUDED.ma_kieu_mo;
INSERT INTO mo_phan(dia_chi_o, ten_o, chieu_dai, chieu_rong, dien_tich, ma_tinh_trang, ngay_khao_sat, ma_kieu_mo, gia_tri) VALUES
('6.3-3-9','Ô 9','2m','1m','2m2','11111111-2222-3333-4444-000000000007','2025-10-01 10:00','aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1',20000000)
ON CONFLICT (dia_chi_o) DO UPDATE SET ma_tinh_trang=EXCLUDED.ma_tinh_trang, ma_kieu_mo=EXCLUDED.ma_kieu_mo;
INSERT INTO mo_phan(dia_chi_o, ten_o, chieu_dai, chieu_rong, dien_tich, ma_tinh_trang, ngay_khao_sat, ma_kieu_mo, gia_tri) VALUES
('6.3-3-10','Ô 10','2m','1m','2m2','11111111-2222-3333-4444-000000000003','2025-10-01 10:00','aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1',20000000)
ON CONFLICT (dia_chi_o) DO UPDATE SET ma_tinh_trang=EXCLUDED.ma_tinh_trang, ma_kieu_mo=EXCLUDED.ma_kieu_mo;
INSERT INTO mo_phan(dia_chi_o, ten_o, chieu_dai, chieu_rong, dien_tich, ma_tinh_trang, ngay_khao_sat, ma_kieu_mo, gia_tri) VALUES
('6.3-3-11','Ô 11','2m','1m','2m2','11111111-2222-3333-4444-000000000003','2025-10-01 10:00','aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa2',20000000)
ON CONFLICT (dia_chi_o) DO UPDATE SET ma_tinh_trang=EXCLUDED.ma_tinh_trang, ma_kieu_mo=EXCLUDED.ma_kieu_mo;
INSERT INTO mo_phan(dia_chi_o, ten_o, chieu_dai, chieu_rong, dien_tich, ma_tinh_trang, ngay_khao_sat, ma_kieu_mo, gia_tri) VALUES
('6.3-3-12','Ô 12','2m','1m','2m2','11111111-2222-3333-4444-000000000002','2025-10-01 10:00','aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa2',20000000)
ON CONFLICT (dia_chi_o) DO UPDATE SET ma_tinh_trang=EXCLUDED.ma_tinh_trang, ma_kieu_mo=EXCLUDED.ma_kieu_mo;
INSERT INTO mo_phan(dia_chi_o, ten_o, chieu_dai, chieu_rong, dien_tich, ma_tinh_trang, ngay_khao_sat, ma_kieu_mo, gia_tri) VALUES
('6.3-4-1','Ô 1','2m','1m','2m2','11111111-2222-3333-4444-000000000005','2025-10-01 10:00','aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1',20000000)
ON CONFLICT (dia_chi_o) DO UPDATE SET ma_tinh_trang=EXCLUDED.ma_tinh_trang, ma_kieu_mo=EXCLUDED.ma_kieu_mo;
INSERT INTO mo_phan(dia_chi_o, ten_o, chieu_dai, chieu_rong, dien_tich, ma_tinh_trang, ngay_khao_sat, ma_kieu_mo, gia_tri) VALUES
('6.3-4-2','Ô 2','2m','1m','2m2','11111111-2222-3333-4444-000000000002','2025-10-01 10:00','aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1',20000000)
ON CONFLICT (dia_chi_o) DO UPDATE SET ma_tinh_trang=EXCLUDED.ma_tinh_trang, ma_kieu_mo=EXCLUDED.ma_kieu_mo;
INSERT INTO mo_phan(dia_chi_o, ten_o, chieu_dai, chieu_rong, dien_tich, ma_tinh_trang, ngay_khao_sat, ma_kieu_mo, gia_tri) VALUES
('6.3-4-3','Ô 3','2m','1m','2m2','11111111-2222-3333-4444-000000000005','2025-10-01 10:00','aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa2',20000000)
ON CONFLICT (dia_chi_o) DO UPDATE SET ma_tinh_trang=EXCLUDED.ma_tinh_trang, ma_kieu_mo=EXCLUDED.ma_kieu_mo;
INSERT INTO mo_phan(dia_chi_o, ten_o, chieu_dai, chieu_rong, dien_tich, ma_tinh_trang, ngay_khao_sat, ma_kieu_mo, gia_tri) VALUES
('6.3-4-4','Ô 4','2m','1m','2m2','11111111-2222-3333-4444-000000000006','2025-10-01 10:00','aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa2',20000000)
ON CONFLICT (dia_chi_o) DO UPDATE SET ma_tinh_trang=EXCLUDED.ma_tinh_trang, ma_kieu_mo=EXCLUDED.ma_kieu_mo;
INSERT INTO mo_phan(dia_chi_o, ten_o, chieu_dai, chieu_rong, dien_tich, ma_tinh_trang, ngay_khao_sat, ma_kieu_mo, gia_tri) VALUES
('6.3-4-5','Ô 5','2m','1m','2m2','11111111-2222-3333-4444-000000000002','2025-10-01 10:00','aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1',20000000)
ON CONFLICT (dia_chi_o) DO UPDATE SET ma_tinh_trang=EXCLUDED.ma_tinh_trang, ma_kieu_mo=EXCLUDED.ma_kieu_mo;
INSERT INTO mo_phan(dia_chi_o, ten_o, chieu_dai, chieu_rong, dien_tich, ma_tinh_trang, ngay_khao_sat, ma_kieu_mo, gia_tri) VALUES
('6.3-4-6','Ô 6','2m','1m','2m2','11111111-2222-3333-4444-000000000003','2025-10-01 10:00','aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1',20000000)
ON CONFLICT (dia_chi_o) DO UPDATE SET ma_tinh_trang=EXCLUDED.ma_tinh_trang, ma_kieu_mo=EXCLUDED.ma_kieu_mo;
INSERT INTO mo_phan(dia_chi_o, ten_o, chieu_dai, chieu_rong, dien_tich, ma_tinh_trang, ngay_khao_sat, ma_kieu_mo, gia_tri) VALUES
('6.3-4-7','Ô 7','2m','1m','2m2','11111111-2222-3333-4444-000000000003','2025-10-01 10:00','aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa2',20000000)
ON CONFLICT (dia_chi_o) DO UPDATE SET ma_tinh_trang=EXCLUDED.ma_tinh_trang, ma_kieu_mo=EXCLUDED.ma_kieu_mo;
INSERT INTO mo_phan(dia_chi_o, ten_o, chieu_dai, chieu_rong, dien_tich, ma_tinh_trang, ngay_khao_sat, ma_kieu_mo, gia_tri) VALUES
('6.3-4-8','Ô 8','2m','1m','2m2','11111111-2222-3333-4444-000000000002','2025-10-01 10:00','aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa2',20000000)
ON CONFLICT (dia_chi_o) DO UPDATE SET ma_tinh_trang=EXCLUDED.ma_tinh_trang, ma_kieu_mo=EXCLUDED.ma_kieu_mo;
INSERT INTO mo_phan(dia_chi_o, ten_o, chieu_dai, chieu_rong, dien_tich, ma_tinh_trang, ngay_khao_sat, ma_kieu_mo, gia_tri) VALUES
('6.3-4-9','Ô 9','2m','1m','2m2','11111111-2222-3333-4444-000000000002','2025-10-01 10:00','aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1',20000000)
ON CONFLICT (dia_chi_o) DO UPDATE SET ma_tinh_trang=EXCLUDED.ma_tinh_trang, ma_kieu_mo=EXCLUDED.ma_kieu_mo;
INSERT INTO mo_phan(dia_chi_o, ten_o, chieu_dai, chieu_rong, dien_tich, ma_tinh_trang, ngay_khao_sat, ma_kieu_mo, gia_tri) VALUES
('6.3-4-10','Ô 10','2m','1m','2m2','11111111-2222-3333-4444-000000000005','2025-10-01 10:00','aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1',20000000)
ON CONFLICT (dia_chi_o) DO UPDATE SET ma_tinh_trang=EXCLUDED.ma_tinh_trang, ma_kieu_mo=EXCLUDED.ma_kieu_mo;
INSERT INTO mo_phan(dia_chi_o, ten_o, chieu_dai, chieu_rong, dien_tich, ma_tinh_trang, ngay_khao_sat, ma_kieu_mo, gia_tri) VALUES
('6.3-4-11','Ô 11','2m','1m','2m2','11111111-2222-3333-4444-000000000001','2025-10-01 10:00','aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa2',20000000)
ON CONFLICT (dia_chi_o) DO UPDATE SET ma_tinh_trang=EXCLUDED.ma_tinh_trang, ma_kieu_mo=EXCLUDED.ma_kieu_mo;
INSERT INTO mo_phan(dia_chi_o, ten_o, chieu_dai, chieu_rong, dien_tich, ma_tinh_trang, ngay_khao_sat, ma_kieu_mo, gia_tri) VALUES
('6.3-4-12','Ô 12','2m','1m','2m2','11111111-2222-3333-4444-000000000005','2025-10-01 10:00','aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa2',20000000)
ON CONFLICT (dia_chi_o) DO UPDATE SET ma_tinh_trang=EXCLUDED.ma_tinh_trang, ma_kieu_mo=EXCLUDED.ma_kieu_mo;
INSERT INTO mo_phan(dia_chi_o, ten_o, chieu_dai, chieu_rong, dien_tich, ma_tinh_trang, ngay_khao_sat, ma_kieu_mo, gia_tri) VALUES
('6.3-4-13','Ô 13','2m','1m','2m2','11111111-2222-3333-4444-000000000006','2025-10-01 10:00','aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa2',20000000)
ON CONFLICT (dia_chi_o) DO UPDATE SET ma_tinh_trang=EXCLUDED.ma_tinh_trang, ma_kieu_mo=EXCLUDED.ma_kieu_mo;
INSERT INTO mo_phan(dia_chi_o, ten_o, chieu_dai, chieu_rong, dien_tich, ma_tinh_trang, ngay_khao_sat, ma_kieu_mo, gia_tri) VALUES
('6.3-5-1','Ô 1','2m','1m','2m2','11111111-2222-3333-4444-000000000007','2025-10-01 10:00','aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa2',20000000)
ON CONFLICT (dia_chi_o) DO UPDATE SET ma_tinh_trang=EXCLUDED.ma_tinh_trang, ma_kieu_mo=EXCLUDED.ma_kieu_mo;
INSERT INTO mo_phan(dia_chi_o, ten_o, chieu_dai, chieu_rong, dien_tich, ma_tinh_trang, ngay_khao_sat, ma_kieu_mo, gia_tri) VALUES
('6.3-5-2','Ô 2','2m','1m','2m2','11111111-2222-3333-4444-000000000002','2025-10-01 10:00','aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa2',20000000)
ON CONFLICT (dia_chi_o) DO UPDATE SET ma_tinh_trang=EXCLUDED.ma_tinh_trang, ma_kieu_mo=EXCLUDED.ma_kieu_mo;
INSERT INTO mo_phan(dia_chi_o, ten_o, chieu_dai, chieu_rong, dien_tich, ma_tinh_trang, ngay_khao_sat, ma_kieu_mo, gia_tri) VALUES
('6.3-5-3','Ô 3','2m','1m','2m2','11111111-2222-3333-4444-000000000002','2025-10-01 10:00','aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa2',20000000)
ON CONFLICT (dia_chi_o) DO UPDATE SET ma_tinh_trang=EXCLUDED.ma_tinh_trang, ma_kieu_mo=EXCLUDED.ma_kieu_mo;
INSERT INTO mo_phan(dia_chi_o, ten_o, chieu_dai, chieu_rong, dien_tich, ma_tinh_trang, ngay_khao_sat, ma_kieu_mo, gia_tri) VALUES
('6.3-5-4','Ô 4','2m','1m','2m2','11111111-2222-3333-4444-000000000007','2025-10-01 10:00','aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1',20000000)
ON CONFLICT (dia_chi_o) DO UPDATE SET ma_tinh_trang=EXCLUDED.ma_tinh_trang, ma_kieu_mo=EXCLUDED.ma_kieu_mo;
INSERT INTO mo_phan(dia_chi_o, ten_o, chieu_dai, chieu_rong, dien_tich, ma_tinh_trang, ngay_khao_sat, ma_kieu_mo, gia_tri) VALUES
('6.3-5-5','Ô 5','2m','1m','2m2','11111111-2222-3333-4444-000000000006','2025-10-01 10:00','aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa2',20000000)
ON CONFLICT (dia_chi_o) DO UPDATE SET ma_tinh_trang=EXCLUDED.ma_tinh_trang, ma_kieu_mo=EXCLUDED.ma_kieu_mo;
INSERT INTO mo_phan(dia_chi_o, ten_o, chieu_dai, chieu_rong, dien_tich, ma_tinh_trang, ngay_khao_sat, ma_kieu_mo, gia_tri) VALUES
('6.3-5-6','Ô 6','2m','1m','2m2','11111111-2222-3333-4444-000000000003','2025-10-01 10:00','aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1',20000000)
ON CONFLICT (dia_chi_o) DO UPDATE SET ma_tinh_trang=EXCLUDED.ma_tinh_trang, ma_kieu_mo=EXCLUDED.ma_kieu_mo;
INSERT INTO mo_phan(dia_chi_o, ten_o, chieu_dai, chieu_rong, dien_tich, ma_tinh_trang, ngay_khao_sat, ma_kieu_mo, gia_tri) VALUES
('6.3-5-7','Ô 7','2m','1m','2m2','11111111-2222-3333-4444-000000000007','2025-10-01 10:00','aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa2',20000000)
ON CONFLICT (dia_chi_o) DO UPDATE SET ma_tinh_trang=EXCLUDED.ma_tinh_trang, ma_kieu_mo=EXCLUDED.ma_kieu_mo;
INSERT INTO mo_phan(dia_chi_o, ten_o, chieu_dai, chieu_rong, dien_tich, ma_tinh_trang, ngay_khao_sat, ma_kieu_mo, gia_tri) VALUES
('6.3-5-8','Ô 8','2m','1m','2m2','11111111-2222-3333-4444-000000000004','2025-10-01 10:00','aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa2',20000000)
ON CONFLICT (dia_chi_o) DO UPDATE SET ma_tinh_trang=EXCLUDED.ma_tinh_trang, ma_kieu_mo=EXCLUDED.ma_kieu_mo;
INSERT INTO mo_phan(dia_chi_o, ten_o, chieu_dai, chieu_rong, dien_tich, ma_tinh_trang, ngay_khao_sat, ma_kieu_mo, gia_tri) VALUES
('6.3-5-9','Ô 9','2m','1m','2m2','11111111-2222-3333-4444-000000000005','2025-10-01 10:00','aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa2',20000000)
ON CONFLICT (dia_chi_o) DO UPDATE SET ma_tinh_trang=EXCLUDED.ma_tinh_trang, ma_kieu_mo=EXCLUDED.ma_kieu_mo;
INSERT INTO mo_phan(dia_chi_o, ten_o, chieu_dai, chieu_rong, dien_tich, ma_tinh_trang, ngay_khao_sat, ma_kieu_mo, gia_tri) VALUES
('6.3-5-10','Ô 10','2m','1m','2m2','11111111-2222-3333-4444-000000000003','2025-10-01 10:00','aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1',20000000)
ON CONFLICT (dia_chi_o) DO UPDATE SET ma_tinh_trang=EXCLUDED.ma_tinh_trang, ma_kieu_mo=EXCLUDED.ma_kieu_mo;
INSERT INTO mo_phan(dia_chi_o, ten_o, chieu_dai, chieu_rong, dien_tich, ma_tinh_trang, ngay_khao_sat, ma_kieu_mo, gia_tri) VALUES
('6.3-5-11','Ô 11','2m','1m','2m2','11111111-2222-3333-4444-000000000001','2025-10-01 10:00','aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1',20000000)
ON CONFLICT (dia_chi_o) DO UPDATE SET ma_tinh_trang=EXCLUDED.ma_tinh_trang, ma_kieu_mo=EXCLUDED.ma_kieu_mo;
INSERT INTO mo_phan(dia_chi_o, ten_o, chieu_dai, chieu_rong, dien_tich, ma_tinh_trang, ngay_khao_sat, ma_kieu_mo, gia_tri) VALUES
('6.3-5-12','Ô 12','2m','1m','2m2','11111111-2222-3333-4444-000000000007','2025-10-01 10:00','aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1',20000000)
ON CONFLICT (dia_chi_o) DO UPDATE SET ma_tinh_trang=EXCLUDED.ma_tinh_trang, ma_kieu_mo=EXCLUDED.ma_kieu_mo;
INSERT INTO mo_phan(dia_chi_o, ten_o, chieu_dai, chieu_rong, dien_tich, ma_tinh_trang, ngay_khao_sat, ma_kieu_mo, gia_tri) VALUES
('6.3-5-13','Ô 13','2m','1m','2m2','11111111-2222-3333-4444-000000000004','2025-10-01 10:00','aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa2',20000000)
ON CONFLICT (dia_chi_o) DO UPDATE SET ma_tinh_trang=EXCLUDED.ma_tinh_trang, ma_kieu_mo=EXCLUDED.ma_kieu_mo;
INSERT INTO mo_phan(dia_chi_o, ten_o, chieu_dai, chieu_rong, dien_tich, ma_tinh_trang, ngay_khao_sat, ma_kieu_mo, gia_tri) VALUES
('6.3-5-14','Ô 14','2m','1m','2m2','11111111-2222-3333-4444-000000000004','2025-10-01 10:00','aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa2',20000000)
ON CONFLICT (dia_chi_o) DO UPDATE SET ma_tinh_trang=EXCLUDED.ma_tinh_trang, ma_kieu_mo=EXCLUDED.ma_kieu_mo;
INSERT INTO mo_phan(dia_chi_o, ten_o, chieu_dai, chieu_rong, dien_tich, ma_tinh_trang, ngay_khao_sat, ma_kieu_mo, gia_tri) VALUES
('6.3-6-1','Ô 1','2m','1m','2m2','11111111-2222-3333-4444-000000000006','2025-10-01 10:00','aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa2',20000000)
ON CONFLICT (dia_chi_o) DO UPDATE SET ma_tinh_trang=EXCLUDED.ma_tinh_trang, ma_kieu_mo=EXCLUDED.ma_kieu_mo;
INSERT INTO mo_phan(dia_chi_o, ten_o, chieu_dai, chieu_rong, dien_tich, ma_tinh_trang, ngay_khao_sat, ma_kieu_mo, gia_tri) VALUES
('6.3-6-2','Ô 2','2m','1m','2m2','11111111-2222-3333-4444-000000000007','2025-10-01 10:00','aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa2',20000000)
ON CONFLICT (dia_chi_o) DO UPDATE SET ma_tinh_trang=EXCLUDED.ma_tinh_trang, ma_kieu_mo=EXCLUDED.ma_kieu_mo;
INSERT INTO mo_phan(dia_chi_o, ten_o, chieu_dai, chieu_rong, dien_tich, ma_tinh_trang, ngay_khao_sat, ma_kieu_mo, gia_tri) VALUES
('6.3-6-3','Ô 3','2m','1m','2m2','11111111-2222-3333-4444-000000000003','2025-10-01 10:00','aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa2',20000000)
ON CONFLICT (dia_chi_o) DO UPDATE SET ma_tinh_trang=EXCLUDED.ma_tinh_trang, ma_kieu_mo=EXCLUDED.ma_kieu_mo;
INSERT INTO mo_phan(dia_chi_o, ten_o, chieu_dai, chieu_rong, dien_tich, ma_tinh_trang, ngay_khao_sat, ma_kieu_mo, gia_tri) VALUES
('6.3-6-4','Ô 4','2m','1m','2m2','11111111-2222-3333-4444-000000000004','2025-10-01 10:00','aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1',20000000)
ON CONFLICT (dia_chi_o) DO UPDATE SET ma_tinh_trang=EXCLUDED.ma_tinh_trang, ma_kieu_mo=EXCLUDED.ma_kieu_mo;
INSERT INTO mo_phan(dia_chi_o, ten_o, chieu_dai, chieu_rong, dien_tich, ma_tinh_trang, ngay_khao_sat, ma_kieu_mo, gia_tri) VALUES
('6.3-6-5','Ô 5','2m','1m','2m2','11111111-2222-3333-4444-000000000006','2025-10-01 10:00','aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa2',20000000)
ON CONFLICT (dia_chi_o) DO UPDATE SET ma_tinh_trang=EXCLUDED.ma_tinh_trang, ma_kieu_mo=EXCLUDED.ma_kieu_mo;
INSERT INTO mo_phan(dia_chi_o, ten_o, chieu_dai, chieu_rong, dien_tich, ma_tinh_trang, ngay_khao_sat, ma_kieu_mo, gia_tri) VALUES
('6.3-6-6','Ô 6','2m','1m','2m2','11111111-2222-3333-4444-000000000004','2025-10-01 10:00','aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa2',20000000)
ON CONFLICT (dia_chi_o) DO UPDATE SET ma_tinh_trang=EXCLUDED.ma_tinh_trang, ma_kieu_mo=EXCLUDED.ma_kieu_mo;
INSERT INTO mo_phan(dia_chi_o, ten_o, chieu_dai, chieu_rong, dien_tich, ma_tinh_trang, ngay_khao_sat, ma_kieu_mo, gia_tri) VALUES
('6.3-6-7','Ô 7','2m','1m','2m2','11111111-2222-3333-4444-000000000006','2025-10-01 10:00','aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1',20000000)
ON CONFLICT (dia_chi_o) DO UPDATE SET ma_tinh_trang=EXCLUDED.ma_tinh_trang, ma_kieu_mo=EXCLUDED.ma_kieu_mo;
INSERT INTO mo_phan(dia_chi_o, ten_o, chieu_dai, chieu_rong, dien_tich, ma_tinh_trang, ngay_khao_sat, ma_kieu_mo, gia_tri) VALUES
('6.3-6-8','Ô 8','2m','1m','2m2','11111111-2222-3333-4444-000000000003','2025-10-01 10:00','aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa2',20000000)
ON CONFLICT (dia_chi_o) DO UPDATE SET ma_tinh_trang=EXCLUDED.ma_tinh_trang, ma_kieu_mo=EXCLUDED.ma_kieu_mo;
INSERT INTO mo_phan(dia_chi_o, ten_o, chieu_dai, chieu_rong, dien_tich, ma_tinh_trang, ngay_khao_sat, ma_kieu_mo, gia_tri) VALUES
('6.3-6-9','Ô 9','2m','1m','2m2','11111111-2222-3333-4444-000000000006','2025-10-01 10:00','aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1',20000000)
ON CONFLICT (dia_chi_o) DO UPDATE SET ma_tinh_trang=EXCLUDED.ma_tinh_trang, ma_kieu_mo=EXCLUDED.ma_kieu_mo;
INSERT INTO mo_phan(dia_chi_o, ten_o, chieu_dai, chieu_rong, dien_tich, ma_tinh_trang, ngay_khao_sat, ma_kieu_mo, gia_tri) VALUES
('6.3-6-10','Ô 10','2m','1m','2m2','11111111-2222-3333-4444-000000000005','2025-10-01 10:00','aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1',20000000)
ON CONFLICT (dia_chi_o) DO UPDATE SET ma_tinh_trang=EXCLUDED.ma_tinh_trang, ma_kieu_mo=EXCLUDED.ma_kieu_mo;
INSERT INTO mo_phan(dia_chi_o, ten_o, chieu_dai, chieu_rong, dien_tich, ma_tinh_trang, ngay_khao_sat, ma_kieu_mo, gia_tri) VALUES
('6.3-6-11','Ô 11','2m','1m','2m2','11111111-2222-3333-4444-000000000002','2025-10-01 10:00','aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1',20000000)
ON CONFLICT (dia_chi_o) DO UPDATE SET ma_tinh_trang=EXCLUDED.ma_tinh_trang, ma_kieu_mo=EXCLUDED.ma_kieu_mo;
INSERT INTO mo_phan(dia_chi_o, ten_o, chieu_dai, chieu_rong, dien_tich, ma_tinh_trang, ngay_khao_sat, ma_kieu_mo, gia_tri) VALUES
('6.3-6-12','Ô 12','2m','1m','2m2','11111111-2222-3333-4444-000000000005','2025-10-01 10:00','aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1',20000000)
ON CONFLICT (dia_chi_o) DO UPDATE SET ma_tinh_trang=EXCLUDED.ma_tinh_trang, ma_kieu_mo=EXCLUDED.ma_kieu_mo;
INSERT INTO mo_phan(dia_chi_o, ten_o, chieu_dai, chieu_rong, dien_tich, ma_tinh_trang, ngay_khao_sat, ma_kieu_mo, gia_tri) VALUES
('6.3-6-13','Ô 13','2m','1m','2m2','11111111-2222-3333-4444-000000000001','2025-10-01 10:00','aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1',20000000)
ON CONFLICT (dia_chi_o) DO UPDATE SET ma_tinh_trang=EXCLUDED.ma_tinh_trang, ma_kieu_mo=EXCLUDED.ma_kieu_mo;
INSERT INTO mo_phan(dia_chi_o, ten_o, chieu_dai, chieu_rong, dien_tich, ma_tinh_trang, ngay_khao_sat, ma_kieu_mo, gia_tri) VALUES
('6.3-6-14','Ô 14','2m','1m','2m2','11111111-2222-3333-4444-000000000005','2025-10-01 10:00','aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1',20000000)
ON CONFLICT (dia_chi_o) DO UPDATE SET ma_tinh_trang=EXCLUDED.ma_tinh_trang, ma_kieu_mo=EXCLUDED.ma_kieu_mo;
INSERT INTO mo_phan(dia_chi_o, ten_o, chieu_dai, chieu_rong, dien_tich, ma_tinh_trang, ngay_khao_sat, ma_kieu_mo, gia_tri) VALUES
('6.3-6-15','Ô 15','2m','1m','2m2','11111111-2222-3333-4444-000000000003','2025-10-01 10:00','aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1',20000000)
ON CONFLICT (dia_chi_o) DO UPDATE SET ma_tinh_trang=EXCLUDED.ma_tinh_trang, ma_kieu_mo=EXCLUDED.ma_kieu_mo;
INSERT INTO mo_phan(dia_chi_o, ten_o, chieu_dai, chieu_rong, dien_tich, ma_tinh_trang, ngay_khao_sat, ma_kieu_mo, gia_tri) VALUES
('6.3-6-16','Ô 16','2m','1m','2m2','11111111-2222-3333-4444-000000000006','2025-10-01 10:00','aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1',20000000)
ON CONFLICT (dia_chi_o) DO UPDATE SET ma_tinh_trang=EXCLUDED.ma_tinh_trang, ma_kieu_mo=EXCLUDED.ma_kieu_mo;

INSERT INTO lich_su_phan_mo (dia_chi_o, ngay, the_loai, ghi_chu) VALUES
('6.1-1-1','2025-10-03 10:00','An táng','An táng lần đầu'),
('6.1-1-2','2025-10-04 09:30','An táng','An táng lần đầu'),
('6.1-2-3','2025-10-10 08:15','Cải táng','Cải táng về ô mới'),
('6.1-3-7','2025-10-12 14:00','An táng','Lễ đơn giản'),
('6.1-4-10','2025-10-15 07:45','Cải táng','Di dời theo yêu cầu gia đình'),
('6.1-5-4','2025-10-18 09:00','An táng','An táng và đặt hoa'),
('6.2-1-8','2025-10-20 10:30','An táng','An táng lần đầu'),
('6.2-2-1','2025-10-22 15:20','Cải táng','Bốc mộ và di dời'),
('6.3-1-2','2025-10-24 08:00','An táng','Lễ an táng buổi sáng'),
('6.3-2-9','2025-10-26 16:10','Cải táng','Cải táng sang mộ đôi'),
('6.3-3-12','2025-10-27 09:40','An táng','An táng và dâng hương'),
('6.3-6-15','2025-10-28 13:30','Cải táng','Cải táng, chỉnh trang sau lễ');

INSERT INTO hinh_anh_mo_phan (dia_chi_o, hinh_anh) VALUES
('6.1-1-1','6.1-1-1_1.jpg'),
('6.1-1-1','6.1-1-1_2.jpg'),
('6.1-1-2','6.1-1-2_1.jpg'),
('6.1-2-3','6.1-2-3_1.jpg'),
('6.1-3-7','6.1-3-7_1.jpg'),
('6.1-4-10','6.1-4-10_1.jpg'),
('6.1-5-4','6.1-5-4_1.jpg'),
('6.2-1-8','6.2-1-8_1.jpg'),
('6.2-2-1','6.2-2-1_1.jpg'),
('6.3-1-2','6.3-1-2_1.jpg'),
('6.3-2-9','6.3-2-9_1.jpg'),
('6.3-6-15','6.3-6-15_1.jpg')
ON CONFLICT DO NOTHING;

-- Khách hàng / Hợp đồng
-- (Tuỳ chọn) Xoá các KH sai mã trước đó (nếu đã lỡ chèn bằng aaaa1111-...):
-- DELETE FROM khach_hang WHERE ma_khach_hang LIKE 'aaaa1111-bbbb-4111-8111-%';

INSERT INTO khach_hang
(ma_khach_hang, ten_khach_hang, dia_chi, so_lien_he, quoc_tich, so_cccd, ngay_cap, noi_cap, ghi_chu)
SELECT
  u.ma_nguoi_dung, v.ten_khach_hang, v.dia_chi, v.so_lien_he, 'Việt Nam',
  v.so_cccd, v.ngay_cap::date, v.noi_cap, v.ghi_chu
FROM (
  VALUES
  ('nguyenthithuha','Nguyễn Thị Thu Hà','12 Lê Lợi','0904000012','012345670012','2019-03-10','Hà Nội',''),
  ('phamhoangson','Phạm Hoàng Sơn','34 Trần Hưng Đạo','0904000013','012345670013','2018-06-21','TP.HCM',''),
  ('leminhtri','Lê Minh Trí','56 Pasteur','0904000014','012345670014','2020-02-15','Đà Nẵng',''),
  ('tranthikimoanh','Trần Thị Kim Oanh','78 Nguyễn Huệ','0904000015','012345670015','2017-11-05','Bình Dương',''),
  ('buithanhtung','Bùi Thanh Tùng','23 Hai Bà Trưng','0904000016','012345670016','2019-09-09','Hải Phòng',''),
  ('dangquynhnhu','Đặng Quỳnh Như','45 Điện Biên Phủ','0904000017','012345670017','2021-01-12','Cần Thơ',''),
  ('dongoclan','Đỗ Ngọc Lan','67 Võ Văn Tần','0904000018','012345670018','2020-07-22','Hà Nội',''),
  ('vuanhtuan','Vũ Anh Tuấn','89 Lý Thường Kiệt','0904000019','012345670019','2018-12-18','TP.HCM',''),
  ('hothimyduyen','Hồ Thị Mỹ Duyên','120 Nguyễn Trãi','0904000020','012345670020','2019-08-08','Đồng Nai',''),
  ('voquockhanh','Võ Quốc Khánh','88 Cách Mạng Tháng 8','0904000021','012345670021','2020-10-20','Hà Nội',''),
  ('ngothanhha','Ngô Thanh Hà','15 Lạch Tray','0904000022','012345670022','2017-05-16','Hải Phòng',''),
  ('hoangminhthu','Hoàng Minh Thư','9 Phan Đăng Lưu','0904000023','012345670023','2021-03-25','TP.HCM',''),
  ('lequochuy','Lê Quốc Huy','101 Nguyễn Văn Cừ','0904000024','012345670024','2018-01-30','Đà Nẵng',''),
  ('phamngocanh','Phạm Ngọc Anh','55 Bạch Đằng','0904000025','012345670025','2022-04-04','Cần Thơ',''),
  ('truongthanhtrung','Trương Thành Trung','222 Phạm Văn Đồng','0904000026','012345670026','2020-06-06','Bình Dương','')
) AS v(ten_tai_khoan, ten_khach_hang, dia_chi, so_lien_he, so_cccd, ngay_cap, noi_cap, ghi_chu)
JOIN nguoi_dung u ON u.ten_tai_khoan = v.ten_tai_khoan
ON CONFLICT (ma_khach_hang) DO UPDATE
SET ten_khach_hang = EXCLUDED.ten_khach_hang,
    dia_chi        = EXCLUDED.dia_chi,
    so_lien_he     = EXCLUDED.so_lien_he,
    quoc_tich      = EXCLUDED.quoc_tich,
    so_cccd        = EXCLUDED.so_cccd,
    ngay_cap       = EXCLUDED.ngay_cap,
    noi_cap        = EXCLUDED.noi_cap,
    ghi_chu        = EXCLUDED.ghi_chu;

INSERT INTO thong_tin_nguoi_mat
(ma_nguoi_mat, ten_nguoi_mat, dia_chi, quoc_tich, so_cccd, ngay_cap, noi_cap, ngay_sinh, ngay_mat_duong, ngay_mat_am, ma_khach_hang) VALUES
-- 1) nguyenthithuha -> 2 người
('aaaa2222-bbbb-4222-8222-000000000101','Nguyễn Văn Hòa','12 Lê Lợi','Việt Nam','223456780101','2010-05-15','Hà Nội','1940-02-10','2025-02-28','2025-02-01','aaaabbbb-cccc-4ddd-8eee-ffff00000012'),
('aaaa2222-bbbb-4222-8222-000000000102','Trần Thị Sen','12 Lê Lợi','Việt Nam','223456780102','2012-03-20','Hà Nội','1945-09-05','2024-11-12',NULL,'aaaabbbb-cccc-4ddd-8eee-ffff00000012'),

-- 2) phamhoangson -> 2 người
('aaaa2222-bbbb-4222-8222-000000000103','Phạm Văn Khải','34 Trần Hưng Đạo','Việt Nam','223456780103','2009-08-19','TP.HCM','1938-01-22','2025-03-14','2025-02-25','aaaabbbb-cccc-4ddd-8eee-ffff00000013'),
('aaaa2222-bbbb-4222-8222-000000000104','Ngô Thị Tươi','34 Trần Hưng Đạo','Việt Nam','223456780104','2016-04-11','TP.HCM','1952-07-30','2024-12-05',NULL,'aaaabbbb-cccc-4ddd-8eee-ffff00000013'),

-- 3) leminhtri -> 2 người
('aaaa2222-bbbb-4222-8222-000000000105','Lê Văn Quyết','56 Pasteur','Việt Nam','223456780105','2011-02-02','Đà Nẵng','1947-03-10','2025-01-17','2024-12-06','aaaabbbb-cccc-4ddd-8eee-ffff00000014'),
('aaaa2222-bbbb-4222-8222-000000000106','Đỗ Thị Lài','56 Pasteur','Việt Nam','223456780106','2015-10-25','Đà Nẵng','1955-05-06','2023-10-21',NULL,'aaaabbbb-cccc-4ddd-8eee-ffff00000014'),

-- 4) tranthikimoanh -> 2 người
('aaaa2222-bbbb-4222-8222-000000000107','Trần Văn Hiếu','78 Nguyễn Huệ','Việt Nam','223456780107','2013-05-09','Bình Dương','1949-03-14','2025-02-22',NULL,'aaaabbbb-cccc-4ddd-8eee-ffff00000015'),
('aaaa2222-bbbb-4222-8222-000000000108','Phạm Thị Nụ','78 Nguyễn Huệ','Việt Nam','223456780108','2019-12-12','Bình Dương','1957-11-18','2024-09-27','2024-09-01','aaaabbbb-cccc-4ddd-8eee-ffff00000015'),

-- 5) buithanhtung -> 2 người
('aaaa2222-bbbb-4222-8222-000000000109','Bùi Văn Thịnh','23 Hai Bà Trưng','Việt Nam','223456780109','2018-09-30','Hải Phòng','1952-11-28','2025-03-10','2025-02-01','aaaabbbb-cccc-4ddd-8eee-ffff00000016'),
('aaaa2222-bbbb-4222-8222-000000000110','Vũ Thị Sương','23 Hai Bà Trưng','Việt Nam','223456780110','2014-07-07','Hải Phòng','1960-04-18','2022-06-05',NULL,'aaaabbbb-cccc-4ddd-8eee-ffff00000016'),

-- 6) dangquynhnhu -> 2 người
('aaaa2222-bbbb-4222-8222-000000000111','Đặng Văn Tài','45 Điện Biên Phủ','Việt Nam','223456780111','2017-02-14','Cần Thơ','1938-01-05','2024-11-02',NULL,'aaaabbbb-cccc-4ddd-8eee-ffff00000017'),
('aaaa2222-bbbb-4222-8222-000000000112','Nguyễn Thị Lựu','45 Điện Biên Phủ','Việt Nam','223456780112','2019-03-03','Cần Thơ','1959-08-15','2025-04-19','2025-03-22','aaaabbbb-cccc-4ddd-8eee-ffff00000017'),

-- 7) dongoclan -> 2 người
('aaaa2222-bbbb-4222-8222-000000000113','Đỗ Văn Long','67 Võ Văn Tần','Việt Nam','223456780113','2020-07-22','Hà Nội','1941-12-01','2023-12-28',NULL,'aaaabbbb-cccc-4ddd-8eee-ffff00000018'),
('aaaa2222-bbbb-4222-8222-000000000114','Phạm Thị Hạnh','67 Võ Văn Tần','Việt Nam','223456780114','2018-11-11','Hà Nội','1953-02-20','2025-05-02','2025-04-15','aaaabbbb-cccc-4ddd-8eee-ffff00000018'),

-- 8) vuanhtuan -> 2 người
('aaaa2222-bbbb-4222-8222-000000000115','Vũ Văn Cường','89 Lý Thường Kiệt','Việt Nam','223456780115','2016-06-06','TP.HCM','1946-10-10','2024-08-30',NULL,'aaaabbbb-cccc-4ddd-8eee-ffff00000019'),
('aaaa2222-bbbb-4222-8222-000000000116','Ngô Thị Phượng','89 Lý Thường Kiệt','Việt Nam','223456780116','2012-04-02','TP.HCM','1951-03-25','2025-01-08','2024-12-18','aaaabbbb-cccc-4ddd-8eee-ffff00000019'),

-- 9) hothimyduyen -> 1 người
('aaaa2222-bbbb-4222-8222-000000000117','Hồ Văn Độ','120 Nguyễn Trãi','Việt Nam','223456780117','2011-09-09','Đồng Nai','1939-05-19','2025-06-14',NULL,'aaaabbbb-cccc-4ddd-8eee-ffff0000001a'),

-- 10) voquockhanh -> 1 người
('aaaa2222-bbbb-4222-8222-000000000118','Võ Thị Thu','88 Cách Mạng Tháng 8','Việt Nam','223456780118','2013-10-20','Hà Nội','1956-07-07','2023-03-03','2023-02-10','aaaabbbb-cccc-4ddd-8eee-ffff0000001b'),

-- 11) ngothanhha -> 1 người
('aaaa2222-bbbb-4222-8222-000000000119','Ngô Văn Đại','15 Lạch Tray','Việt Nam','223456780119','2017-05-16','Hải Phòng','1948-09-09','2024-05-01',NULL,'aaaabbbb-cccc-4ddd-8eee-ffff0000001c'),

-- 12) hoangminhthu -> 1 người
('aaaa2222-bbbb-4222-8222-000000000120','Hoàng Thị Loan','9 Phan Đăng Lưu','Việt Nam','223456780120','2021-03-25','TP.HCM','1954-01-22','2025-07-03','2025-06-06','aaaabbbb-cccc-4ddd-8eee-ffff0000001d'),

-- 13) lequochuy -> 1 người
('aaaa2222-bbbb-4222-8222-000000000121','Lê Văn Hậu','101 Nguyễn Văn Cừ','Việt Nam','223456780121','2018-01-30','Đà Nẵng','1943-02-02','2022-10-20',NULL,'aaaabbbb-cccc-4ddd-8eee-ffff0000001e'),

-- 14) phamngocanh -> 1 người
('aaaa2222-bbbb-4222-8222-000000000122','Phạm Văn Lực','55 Bạch Đằng','Việt Nam','223456780122','2022-04-04','Cần Thơ','1950-06-16','2025-03-28','2025-03-02','aaaabbbb-cccc-4ddd-8eee-ffff0000001f'),

-- 15) truongthanhtrung -> 1 người
('aaaa2222-bbbb-4222-8222-000000000123','Trương Thị Hường','222 Phạm Văn Đồng','Việt Nam','223456780123','2020-06-06','Bình Dương','1947-08-08','2024-02-14',NULL,'aaaabbbb-cccc-4ddd-8eee-ffff00000020');


INSERT INTO hop_dong
(ma_hop_dong, so_hop_dong, ngay_ky_ket, ngay_hieu_luc, gia_tri, phi_chuyen_nhuong,
 vi_tri_luu_ho_so, trang_thai, ghi_chu, ma_khach_hang, ma_nhan_vien)
SELECT
 v.hd_id,
 v.so_hd,
 v.ngay_ky,
 v.ngay_ky + (1 + floor(random()*7))::int,  -- hiệu lực ≥ 1 ngày sau ký
 v.gia_tri,
 0::numeric(18,2),
 v.path_pdf,
 'Hiệu lực',
 ''::text,
 v.ma_kh,
 v.ma_nv
FROM (
  VALUES
 -- 01) nguyenthithuha -> NV: binhtt2145
  ('aaaa3333-bbbb-4333-8333-000000000001'::uuid,'S001',DATE '2025-09-30',30000000::numeric(18,2),'/data/scans/contracts/S001.pdf',
   'aaaabbbb-cccc-4ddd-8eee-ffff00000012'::uuid,'aaaabbbb-cccc-4ddd-8eee-ffff00000004'::uuid),

  -- 02) phamhoangson -> NV: lampt8767
  ('aaaa3333-bbbb-4333-8333-000000000002'::uuid,'S002',DATE '2025-10-01',25000000::numeric(18,2),'/data/scans/contracts/S002.pdf',
   'aaaabbbb-cccc-4ddd-8eee-ffff00000013'::uuid,'aaaabbbb-cccc-4ddd-8eee-ffff0000000a'::uuid),

  -- 03) leminhtri -> NV: annv1023
  ('aaaa3333-bbbb-4333-8333-000000000003'::uuid,'S003',DATE '2025-10-02',28000000::numeric(18,2),'/data/scans/contracts/S003.pdf',
   'aaaabbbb-cccc-4ddd-8eee-ffff00000014'::uuid,'aaaabbbb-cccc-4ddd-8eee-ffff00000003'::uuid),

  -- 04) tranthikimoanh -> NV: tamlt3267
  ('aaaa3333-bbbb-4333-8333-000000000004'::uuid,'S004',DATE '2025-10-03',27000000::numeric(18,2),'/data/scans/contracts/S004.pdf',
   'aaaabbbb-cccc-4ddd-8eee-ffff00000015'::uuid,'aaaabbbb-cccc-4ddd-8eee-ffff00000005'::uuid),

  -- 05) buithanhtung -> NV: dungpv4389
  ('aaaa3333-bbbb-4333-8333-000000000005'::uuid,'S005',DATE '2025-10-04',32000000::numeric(18,2),'/data/scans/contracts/S005.pdf',
   'aaaabbbb-cccc-4ddd-8eee-ffff00000016'::uuid,'aaaabbbb-cccc-4ddd-8eee-ffff00000006'::uuid),

  -- 06) dangquynhnhu -> NV: ducvm5401
  ('aaaa3333-bbbb-4333-8333-000000000006'::uuid,'S006',DATE '2025-10-05',26000000::numeric(18,2),'/data/scans/contracts/S006.pdf',
   'aaaabbbb-cccc-4ddd-8eee-ffff00000017'::uuid,'aaaabbbb-cccc-4ddd-8eee-ffff00000007'::uuid),

  -- 07) dongoclan -> NV: huybq6523
  ('aaaa3333-bbbb-4333-8333-000000000007'::uuid,'S007',DATE '2025-10-06',35000000::numeric(18,2),'/data/scans/contracts/S007.pdf',
   'aaaabbbb-cccc-4ddd-8eee-ffff00000018'::uuid,'aaaabbbb-cccc-4ddd-8eee-ffff00000008'::uuid),

  -- 08) vuanhtuan -> NV: khoaha7645
  ('aaaa3333-bbbb-4333-8333-000000000008'::uuid,'S008',DATE '2025-10-07',24000000::numeric(18,2),'/data/scans/contracts/S008.pdf',
   'aaaabbbb-cccc-4ddd-8eee-ffff00000019'::uuid,'aaaabbbb-cccc-4ddd-8eee-ffff00000009'::uuid),

  -- 09) hothimyduyen -> NV: maidt9889
  ('aaaa3333-bbbb-4333-8333-000000000009'::uuid,'S009',DATE '2025-10-08',30000000::numeric(18,2),'/data/scans/contracts/S009.pdf',
   'aaaabbbb-cccc-4ddd-8eee-ffff0000001a'::uuid,'aaaabbbb-cccc-4ddd-8eee-ffff0000000b'::uuid),

  -- 10) voquockhanh -> NV: namdv0901
  ('aaaa3333-bbbb-4333-8333-00000000000a'::uuid,'S010',DATE '2025-10-09',23000000::numeric(18,2),'/data/scans/contracts/S010.pdf',
   'aaaabbbb-cccc-4ddd-8eee-ffff0000001b'::uuid,'aaaabbbb-cccc-4ddd-8eee-ffff0000000c'::uuid),

  -- 11) ngothanhha -> NV: phongdt1123
  ('aaaa3333-bbbb-4333-8333-00000000000b'::uuid,'S011',DATE '2025-10-10',29000000::numeric(18,2),'/data/scans/contracts/S011.pdf',
   'aaaabbbb-cccc-4ddd-8eee-ffff0000001c'::uuid,'aaaabbbb-cccc-4ddd-8eee-ffff0000000d'::uuid),

  -- 12) hoangminhthu -> NV: quynhnt2244
  ('aaaa3333-bbbb-4333-8333-00000000000c'::uuid,'S012',DATE '2025-10-11',31000000::numeric(18,2),'/data/scans/contracts/S012.pdf',
   'aaaabbbb-cccc-4ddd-8eee-ffff0000001d'::uuid,'aaaabbbb-cccc-4ddd-8eee-ffff0000000e'::uuid),

  -- 13) lequochuy -> NV: sonth3366
  ('aaaa3333-bbbb-4333-8333-00000000000d'::uuid,'S013',DATE '2025-10-12',26000000::numeric(18,2),'/data/scans/contracts/S013.pdf',
   'aaaabbbb-cccc-4ddd-8eee-ffff0000001e'::uuid,'aaaabbbb-cccc-4ddd-8eee-ffff0000000f'::uuid),

  -- 14) phamngocanh -> NV: thinhlg4488
  ('aaaa3333-bbbb-4333-8333-00000000000e'::uuid,'S014',DATE '2025-10-13',27500000::numeric(18,2),'/data/scans/contracts/S014.pdf',
   'aaaabbbb-cccc-4ddd-8eee-ffff0000001f'::uuid,'aaaabbbb-cccc-4ddd-8eee-ffff00000010'::uuid),

  -- 15) truongthanhtrung -> NV: tungct5599
  ('aaaa3333-bbbb-4333-8333-00000000000f'::uuid,'S015',DATE '2025-10-14',29500000::numeric(18,2),'/data/scans/contracts/S015.pdf',
   'aaaabbbb-cccc-4ddd-8eee-ffff00000020'::uuid,'aaaabbbb-cccc-4ddd-8eee-ffff00000011'::uuid)
) AS v(hd_id, so_hd, ngay_ky, gia_tri, path_pdf, ma_kh, ma_nv)
ON CONFLICT (ma_hop_dong) DO UPDATE
SET so_hop_dong      = EXCLUDED.so_hop_dong,
    ngay_ky_ket      = EXCLUDED.ngay_ky_ket,
    ngay_hieu_luc    = EXCLUDED.ngay_hieu_luc,
    gia_tri          = EXCLUDED.gia_tri,
    phi_chuyen_nhuong= EXCLUDED.phi_chuyen_nhuong,
    vi_tri_luu_ho_so = EXCLUDED.vi_tri_luu_ho_so,
    trang_thai       = EXCLUDED.trang_thai, 
    ghi_chu          = EXCLUDED.ghi_chu,
    ma_khach_hang    = EXCLUDED.ma_khach_hang,
    ma_nhan_vien     = EXCLUDED.ma_nhan_vien;

-- ĐỢT 1: 40% giá trị hợp đồng, thanh toán ngay ngày hiệu lực (09:00)
WITH hd AS (
  SELECT h.*,
         ROW_NUMBER() OVER (ORDER BY h.ma_hop_dong) AS rn
  FROM hop_dong h
  WHERE h.gia_tri IS NOT NULL
    AND h.ngay_hieu_luc IS NOT NULL
)
INSERT INTO thanh_toan
  (ma_dot_thanh_toan, ma_hop_dong, so_tien, ngay_thanh_toan,
   hinh_thuc_thanh_toan, noi_dung, ghi_chu)
SELECT
  uuid_generate_v5('6ba7b810-9dad-11d1-80b4-00c04fd430c8'::uuid, h.ma_hop_dong::text || '-TT01') AS ma_dot_thanh_toan,
  h.ma_hop_dong,
  ROUND(h.gia_tri::numeric(18,2) * 0.40, 2)::numeric(18,2),
  (h.ngay_hieu_luc::timestamp + INTERVAL '9 hour'),
  CASE WHEN (h.rn % 2)=1 THEN 'Tiền mặt' ELSE 'Chuyển khoản' END,
  'Đợt 1',
  ''
FROM hd h
ON CONFLICT (ma_dot_thanh_toan) DO UPDATE
SET so_tien = EXCLUDED.so_tien,
    ngay_thanh_toan = EXCLUDED.ngay_thanh_toan,
    hinh_thuc_thanh_toan = EXCLUDED.hinh_thuc_thanh_toan;

-- ĐỢt 2: UUID v5 từ (ma_hop_dong||'-TT02'), phần còn lại, sau Đợt 1 5 ngày
WITH hd AS (
  SELECT h.*,
         ROW_NUMBER() OVER (ORDER BY h.ma_hop_dong) AS rn
  FROM hop_dong h
  WHERE h.gia_tri IS NOT NULL
    AND h.ngay_hieu_luc IS NOT NULL
),
dot1 AS (
  SELECT ma_hop_dong,
         ROUND(gia_tri::numeric(18,2) * 0.40, 2)::numeric(18,2) AS so_tien_dot1,
         ngay_hieu_luc
  FROM hd
)
INSERT INTO thanh_toan
  (ma_dot_thanh_toan, ma_hop_dong, so_tien, ngay_thanh_toan,
   hinh_thuc_thanh_toan, noi_dung, ghi_chu)
SELECT
  uuid_generate_v5('6ba7b810-9dad-11d1-80b4-00c04fd430c8'::uuid, h.ma_hop_dong::text || '-TT02'),
  h.ma_hop_dong,
  (h.gia_tri::numeric(18,2) - d.so_tien_dot1),
  (d.ngay_hieu_luc::timestamp + INTERVAL '5 day' + INTERVAL '9 hour'),
  CASE WHEN (h.rn % 2)=1 THEN 'Chuyển khoản' ELSE 'Tiền mặt' END,
  'Đợt 2',
  ''
FROM hd h
JOIN dot1 d USING (ma_hop_dong)
ON CONFLICT (ma_dot_thanh_toan) DO UPDATE
SET so_tien = EXCLUDED.so_tien,
    ngay_thanh_toan = EXCLUDED.ngay_thanh_toan,
    hinh_thuc_thanh_toan = EXCLUDED.hinh_thuc_thanh_toan;

WITH
-- Hợp đồng được đánh số để ghép ô mộ theo thứ tự
hd AS (
  SELECT h.*, ROW_NUMBER() OVER (ORDER BY h.ma_hop_dong) AS rn
  FROM hop_dong h
  WHERE h.ngay_hieu_luc IS NOT NULL
),
-- Người mất của từng khách: rnk=1,2 (tối đa 2 người/khách)
nm AS (
  SELECT
    t.ma_khach_hang,
    t.ma_nguoi_mat,
    ROW_NUMBER() OVER (PARTITION BY t.ma_khach_hang ORDER BY t.ma_nguoi_mat) AS rnk
  FROM thong_tin_nguoi_mat t
),
nm12 AS (
  SELECT * FROM nm WHERE rnk <= 2
),
-- Danh sách ô mộ, đánh số để gán 1 ô cho mỗi hợp đồng
mp AS (
  SELECT m.dia_chi_o, ROW_NUMBER() OVER (ORDER BY m.dia_chi_o) AS rn
  FROM mo_phan m
),
mp_pick AS (
  SELECT hd.ma_hop_dong, mp.dia_chi_o
  FROM hd JOIN mp ON mp.rn = hd.rn
)
INSERT INTO hop_dong_chi_tiet
  (ma_hd_chi_tiet, ma_dich_vu, dia_chi_o, ma_hop_dong, ma_nguoi_mat,
   tinh_trang_thuc, ngay_thuc_hien, ngay_ban_giao, to_chuc_le)
SELECT
  -- Nếu ma_hd_chi_tiet là VARCHAR: đổi ::uuid thành ::text
  uuid_generate_v5('6ba7b810-9dad-11d1-80b4-00c04fd430c8'::uuid,
                   hd.ma_hop_dong::text || CASE nm.rnk WHEN 1 THEN ':01' ELSE ':02' END)::uuid AS ma_hd_chi_tiet,
  (
    SELECT dv.ma_dich_vu FROM dich_vu dv
    WHERE dv.loai_dich_vu =
      CASE nm.rnk
        WHEN 1 THEN 'An táng (chôn mới)'
        WHEN 2 THEN 'Cải táng/di dời – bốc mộ'
      END
    LIMIT 1
  ) AS ma_dich_vu,
  mp.dia_chi_o,
  hd.ma_hop_dong,
  nm.ma_nguoi_mat,
  'Đã thực hiện' AS tinh_trang_thuc,
  CASE nm.rnk
    WHEN 1 THEN (hd.ngay_hieu_luc::timestamp + INTERVAL '9 hour')
    ELSE          (hd.ngay_hieu_luc::timestamp + INTERVAL '1 day' + INTERVAL '8 hour')
  END AS ngay_thuc_hien,
  CASE nm.rnk
    WHEN 1 THEN (hd.ngay_hieu_luc::timestamp + INTERVAL '17 hour')
    ELSE          (hd.ngay_hieu_luc::timestamp + INTERVAL '1 day' + INTERVAL '11 hour' + INTERVAL '30 min')
  END AS ngay_ban_giao,
  '1'::trang_thai_enum AS to_chuc_le
FROM hd
JOIN mp_pick mp ON mp.ma_hop_dong = hd.ma_hop_dong
JOIN nm12 nm    ON nm.ma_khach_hang = hd.ma_khach_hang
-- mỗi HĐ sẽ sinh 1 hoặc 2 dòng tùy số người mất thuộc khách của HĐ
ON CONFLICT (ma_hd_chi_tiet) DO NOTHING;

-- 1) Đảm bảo khóa học tồn tại với đúng ma_dao_tao bạn muốn
INSERT INTO dao_tao (ma_dao_tao, tieu_de, mo_ta, thoi_gian_bd, thoi_gian_kt)
VALUES (
  'ffffffff-ffff-4fff-8fff-fffffffffff1',
  'An toàn lao động',
  'Khóa an toàn lao động cơ bản',
  '2025-10-01 09:00',
  '2025-10-01 12:00'
)
ON CONFLICT (ma_dao_tao) DO NOTHING;

-- 2) Gán khóa học này cho 15 nhân viên (ánh xạ ma_nhan_vien theo email)
INSERT INTO dao_tao_nhan_vien (ma_dao_tao, ma_nhan_vien)
SELECT 'ffffffff-ffff-4fff-8fff-fffffffffff1', nv.ma_nhan_vien
FROM nhan_vien nv
WHERE nv.email IN (
  'annv1023@cty.vn',
  'binhtt2145@cty.vn',
  'tamlt3267@cty.vn',
  'dungpv4389@cty.vn',
  'ducvm5401@cty.vn',
  'huybq6523@cty.vn',
  'khoaha7645@cty.vn',
  'lampt8767@cty.vn',
  'maidt9889@cty.vn',
  'namdv0901@cty.vn',
  'phongdt1123@cty.vn',
  'quynhnt2244@cty.vn',
  'sonth3366@cty.vn',
  'thinhlg4488@cty.vn',
  'tungct5599@cty.vn'
)
ON CONFLICT DO NOTHING;



