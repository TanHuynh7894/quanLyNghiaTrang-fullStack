import { Component, Input, Output, EventEmitter, HostBinding, SimpleChanges } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { MapDataService } from '../map-data';
import type { FeatureCollection } from 'geojson';

@Component({
  selector: 'app-header',
  standalone: true,
  imports: [CommonModule, FormsModule],
  templateUrl: './header.html',
  styleUrls: ['./header.css']
})
export class HeaderComponent {
  projectName = 'My Project';
  isMenuOpen = false;

  query = '';

  khus: string[] = [];
  hangs: string[] = [];
  os: string[] = [];

  @Input() selectedKhu?: string;
  @Input() selectedHang?: string;
  @Input() selectedO?: string;

  @Output() modeChange = new EventEmitter<'khu'|'hang'|'o'>();
  @Output() khuChange = new EventEmitter<string>();
  @Output() hangChange = new EventEmitter<string>();
  @Output() oChange   = new EventEmitter<string>();
  @Output() menuToggled = new EventEmitter<boolean>();
  @HostBinding('class.header-menu-open') get menuOpenClass() {
    return this.isMenuOpen;
  }

  constructor(private api: MapDataService) {}

  ngOnInit() {
    // load danh sách Khu
    this.api.getKhuBoundaries().subscribe((fc: FeatureCollection) => {
      this.khus = Array.from(new Set(
        fc.features.map(f => String(f.properties?.['ten_khu'])).filter(Boolean)
      ));
    });
  }

  ngOnChanges(changes: SimpleChanges): void {
    // Nếu selectedKhu thay đổi => load danh sách Hàng
    if (changes['selectedKhu'] && this.selectedKhu) {
      this.loadHangsByKhu(this.selectedKhu);
    }

    // Nếu selectedHang thay đổi => load danh sách Ô
    if (changes['selectedHang'] && this.selectedKhu && this.selectedHang) {
      this.loadOsByHang(this.selectedKhu, this.selectedHang);
    }
  }

  toggleMenu(): void {
    this.isMenuOpen = !this.isMenuOpen;
    this.menuToggled.emit(this.isMenuOpen);
  }

  onKhuChange() {
    if (!this.selectedKhu) return;
    this.selectedHang = undefined;
    this.selectedO = undefined;
    this.hangs = [];
    this.os = [];

    this.modeChange.emit('hang');
    this.khuChange.emit(this.selectedKhu);

    this.loadHangsByKhu(this.selectedKhu);
  }

  onHangChange() {
    if (!this.selectedKhu || !this.selectedHang) return;
    this.selectedO = undefined;
    this.os = [];

    this.modeChange.emit('o');
    this.hangChange.emit(this.selectedHang);

    this.loadOsByHang(this.selectedKhu, this.selectedHang);
  }

  /** Khi chọn Ô từ dropdown */
  onOChange() {
    if (this.selectedO) {
      this.oChange.emit(this.selectedO);
    }
  }

  /** API: Lấy danh sách Hàng từ Khu */
  private loadHangsByKhu(ten_khu: string) {
    this.api.getHangByKhu(ten_khu).subscribe((fc: FeatureCollection) => {
      this.hangs = Array.from(new Set(
        fc.features.map(f => String(f.properties?.['ten_hang'])).filter(Boolean)
      )).sort((a, b) => parseFloat(a) - parseFloat(b));
    });
  }

  /** API: Lấy danh sách Ô từ Hàng */
  private loadOsByHang(ten_khu: string, ten_hang: string) {
    this.api.getOByHang(ten_khu, ten_hang).subscribe(fc => {
      this.os = fc.features
        .map(f => String(f.properties?.['ten_o']))
        .filter(Boolean)
        .sort((a, b) => parseFloat(a) - parseFloat(b));
    });
  }

  onSearch() {
    const raw = this.query.trim();
    if (!raw) return;

    // Cho phép người dùng dùng -, ., / để phân cách
    const parts = raw.split(/[-]/).map(s => s.trim()).filter(Boolean);

    // Trường hợp chỉ có KHU
    if (parts.length === 1) {
      const khu = parts[0];
      this.api.getKhuByDiaChi(khu).subscribe({
        next: (_fc) => {
          // gán & emit
          this.selectedKhu = khu;
          this.selectedHang = undefined;
          this.selectedO = undefined;

          this.modeChange.emit('hang');
          this.khuChange.emit(khu);
          this.loadHangsByKhu(khu);
        },
        error: () => {
          // vẫn emit để map xử lý
          this.selectedKhu = khu;
          this.selectedHang = undefined;
          this.selectedO = undefined;

          this.modeChange.emit('hang');
          this.khuChange.emit(khu);
          this.loadHangsByKhu(khu);
        }
      });
      return;
    }

    // Trường hợp KHU-HÀNG
    if (parts.length === 2) {
      const [khu, hang] = parts;
      const dia_chi = `${khu}-${hang}`;
      this.api.getHangByDiaChi(dia_chi).subscribe({
        next: (_fc) => {
          this.selectedKhu = khu;
          this.selectedHang = hang;
          this.selectedO = undefined;

          this.modeChange.emit('o');
          this.khuChange.emit(khu);
          this.hangChange.emit(hang);
          this.loadOsByHang(khu, hang);
        },
        error: () => {
          this.selectedKhu = khu;
          this.selectedHang = hang;
          this.selectedO = undefined;

          this.modeChange.emit('o');
          this.khuChange.emit(khu);
          this.hangChange.emit(hang);
          this.loadOsByHang(khu, hang);
        }
      });
      return;
    }

    // Trường hợp KHU-HÀNG-Ô (lấy đúng 3 phần đầu)
    const [khu, hang, o] = parts;
    const dia_chi = `${khu}-${hang}-${o}`;
    this.api.getOByDiaChi(dia_chi).subscribe({
      next: (_fc) => {
        this.selectedKhu = khu;
        this.selectedHang = hang;
        this.selectedO = o;

        // MapComponent đang lắng nghe @Input và tự zoom
        this.khuChange.emit(khu);
        this.hangChange.emit(hang);
        this.oChange.emit(o);
      },
      error: () => {
        this.selectedKhu = khu;
        this.selectedHang = hang;
        this.selectedO = o;

        this.khuChange.emit(khu);
        this.hangChange.emit(hang);
        this.oChange.emit(o);
      }
    });
  }
}