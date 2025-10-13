import { Component } from '@angular/core';
import { HeaderComponent } from '../header/header';
import { MapComponent } from '../map/map';
import { MenuComponent } from '../menu/menu';

@Component({
  selector: 'app-map-page',
  standalone: true,
  imports: [HeaderComponent, MapComponent, MenuComponent],
  templateUrl: './map-page.html',
  styleUrls: ['./map-page.css']
})
export class MapPageComponent {
  isMenuVisible = false;
  mapMode: any = null;
  selectedKhu: any = null;
  selectedHang: any = null;
  selectedO: any = null;
}
