import { Injectable } from '@angular/core';
import { BehaviorSubject } from 'rxjs';

export enum MapViewLevel {
  Khu,
  Hang,
  O
}

@Injectable({
  providedIn: 'root'
})
export class MapStateService {
  public readonly currentView$ = new BehaviorSubject<MapViewLevel>(MapViewLevel.Khu);
  
  private selectedKhu: string | null = null;
  private selectedHang: string | null = null;

  public selectKhu(ten_khu: string): void {
    this.selectedKhu = ten_khu;
    this.currentView$.next(MapViewLevel.Hang);
  }

  public selectHang(ten_hang: string): void {
    this.selectedHang = ten_hang;
    this.currentView$.next(MapViewLevel.O);
  }
  
  public goBack(): void {
    const currentView = this.currentView$.getValue();
    if (currentView === MapViewLevel.O) {
      this.selectedHang = null;
      this.currentView$.next(MapViewLevel.Hang);
    } else if (currentView === MapViewLevel.Hang) {
      this.selectedKhu = null;
      this.currentView$.next(MapViewLevel.Khu);
    }
  }

  public getSelectedKhu(): string | null {
    return this.selectedKhu;
  }
  
  public getSelectedHang(): string | null {
    return this.selectedHang;
  }
}

