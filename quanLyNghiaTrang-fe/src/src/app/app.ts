import { Component, inject } from '@angular/core';
import { CommonModule } from '@angular/common';
import { RouterModule } from '@angular/router';
import { SharedStateService } from './shared-state';
import { MapViewLevel } from './map/map'; 
import { MapDataService } from './map-data';

// Import các component con
import { HeaderComponent } from './header/header';
import { MapComponent } from './map/map';
import { MenuComponent } from './menu/menu';

@Component({
  selector: 'app-root',
  standalone: true,
  imports: [
    CommonModule,
    RouterModule,
    HeaderComponent,
    MapComponent,
    MenuComponent
  ],
  templateUrl: './app.html',
  styleUrls: ['./app.css']
})
export class App{
  isMenuOpen: boolean = false;

  private sharedStateService = inject(SharedStateService);
  private mapDataService = inject(MapDataService);

   mapMode: 'khu'|'hang'|'o' = 'khu';
  selectedKhu?: string;
  selectedHang?: string;
  selectedO?: string;

   isMenuVisible = false;

  onMenuToggled(isOpen: boolean): void {
    this.isMenuVisible = isOpen;
  }

  currentMapMode: string = 'khu';

  // Hàm nhận sự kiện từ header và cập nhật trạng thái
  onMapModeChanged(mode: string): void {
    this.currentMapMode = mode;
  }
  onModeChange(mode: 'khu'|'hang'|'o') { this.mapMode = mode; }
  onKhuChange(k: string) { this.selectedKhu = k; }
  onHangChange(h: string) { this.selectedHang = h; }
  onOChange(o: string) { this.selectedO = o; }
}