// src/app/shared-state.ts (Phiên bản nâng cao)

import { Injectable } from '@angular/core';
import { BehaviorSubject, Observable } from 'rxjs';

// Thêm enum MapViewLevel từ map.ts để đảm bảo đồng bộ
import { MapViewLevel } from './map/map';

@Injectable({
  providedIn: 'root'
})
export class SharedStateService {
  // BehaviorSubjects để lưu trữ trạng thái của từng cấp độ
  public readonly currentKhu = new BehaviorSubject<string | null>(null);
  public readonly currentHang = new BehaviorSubject<string | null>(null);
  public readonly currentO = new BehaviorSubject<string | null>(null);
  public readonly currentViewLevel = new BehaviorSubject<MapViewLevel>(MapViewLevel.Khu);

  constructor() { }

  /**
   * Cập nhật trạng thái lựa chọn và cấp độ hiển thị.
   * @param khu Mã khu vực được chọn.
   * @param hang Mã hàng được chọn.
   * @param o Mã ô được chọn.
   * @param viewLevel Cấp độ hiển thị trên bản đồ (Khu, Hàng, Ô).
   */
  changeSelection(khu: string | null, hang: string | null, o: string | null, viewLevel: MapViewLevel): void {
    // Cập nhật từng BehaviorSubject, kích hoạt các subscriber tương ứng
    this.currentKhu.next(khu);
    this.currentHang.next(hang);
    this.currentO.next(o);
    this.currentViewLevel.next(viewLevel);
  }

  goBack(): void {
    const currentLevel = this.currentViewLevel.getValue();
    switch (currentLevel) {
      case MapViewLevel.O:
        this.changeSelection(this.currentKhu.getValue(), this.currentHang.getValue(), null, MapViewLevel.Hang);
        break;
      case MapViewLevel.Hang:
        this.changeSelection(this.currentKhu.getValue(), null, null, MapViewLevel.Khu);
        break;
      case MapViewLevel.Khu:
        // Đã ở cấp độ cao nhất, không làm gì cả
        break;
      default:
        break;
    }
  }
}