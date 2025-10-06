import { Component, AfterViewInit, OnDestroy, ElementRef, ViewChild, inject, NgZone, OnInit, Input, OnChanges, SimpleChanges, Output, EventEmitter } from '@angular/core';
import { CommonModule } from '@angular/common';
// Cập nhật: Import thêm Popup và các type cần thiết
import { Map, LngLatBounds, MapGeoJSONFeature, Popup } from 'maplibre-gl';
import { MapDataService } from '../map-data';
import { Feature, GeoJsonProperties } from 'geojson';

// Enum để quản lý trạng thái hiển thị của bản đồ
export enum MapViewLevel {
  Khu,
  Hang,
  O
}

@Component({
  selector: 'app-map',
  standalone: true,
  imports: [CommonModule],
  templateUrl: './map.html',
  styleUrls: ['./map.css'],
})
export class MapComponent implements AfterViewInit, OnDestroy {

  @ViewChild('map') private mapContainer!: ElementRef<HTMLElement>;
  @Input() mapMode: 'khu' | 'hang' | 'o' = 'khu';
  @Input() selectedKhu?: string;
  @Input() selectedHang?: string;
  @Input() selectedO?: string;
  @Output() khuPicked  = new EventEmitter<string>();
  @Output() hangPicked = new EventEmitter<string>();
  @Output() oPicked    = new EventEmitter<string>();

  private map?: Map;
  private mapDataService = inject(MapDataService);
  private zone = inject(NgZone);
  private mapReady = false;
  // @Input() mapMode: string = 'khu';

  // Mới: Thêm một instance Popup để tái sử dụng cho hiệu ứng hover
  private popup = new Popup({
    closeButton: false,
    closeOnClick: false
  });

  public currentView = MapViewLevel.Khu;
  public MapViewLevel = MapViewLevel;
  // Xóa: 'detailHtml' không còn cần thiết cho hiệu ứng hover
  // public detailHtml: string | null = null;

  // private selectedKhu: string | null = null;
  // private selectedHang: string | null = null;
  private hoveredFeature: { id: string | number; source: string } | null = null;
  public detailHtml: string | null = null;

  ngAfterViewInit() {
    const apiKey = '3suk2GO5O2JgkhGmruDP'; // Lưu ý: Nên đưa key này vào environment files
    const initialState = { lng: 106.64731872829728, lat: 11.180320653754398, zoom: 17.5 };

    this.map = new Map({
      container: this.mapContainer.nativeElement,
      style: `https://api.maptiler.com/maps/streets-v2/style.json?key=${apiKey}`,
      center: [initialState.lng, initialState.lat],
      zoom: initialState.zoom
    });

    this.map.on('load', () => {
      this.initializeLayers();
      this.loadInitialKhuData();
      this.setupInteractivity();
      this.mapReady = true;
      this.applySelectionsFromInputs();
    });
  }

  ngOnChanges(changes: SimpleChanges): void {
  if (!this.mapReady) return;

  // Bật/tắt layer theo mode
  if (changes['mapMode'] && !changes['mapMode'].firstChange) {
    this.updateLayersBasedOnMode(this.mapMode);
  }

  // ---- KHI CHỌN KHU ----
  if (changes['selectedKhu'] && this.selectedKhu) {
    this.updateLayersBasedOnMode('hang');
    this.loadHangByKhu(this.selectedKhu);

    // zoom vào Khu đã chọn bằng cách tìm trong 'khu-source'
    const khuFeat = (this.map?.querySourceFeatures('khu-source') as any[] || [])
      .find(f => String(f.properties?.['ten_khu']) === String(this.selectedKhu));
    if (khuFeat) this.zoomToFeature(khuFeat as unknown as Feature);
  }

  // ---- KHI CHỌN HÀNG ----
  if (changes['selectedHang'] && this.selectedKhu && this.selectedHang) {
    this.updateLayersBasedOnMode('o');
    this.loadOByHang(this.selectedKhu, this.selectedHang);

    // zoom vào Hàng đã chọn trong 'hang-source'
    const hangFeat = (this.map?.querySourceFeatures('hang-source') as any[] || [])
      .find(f => String(f.properties?.['ten_hang']) === String(this.selectedHang));
    if (hangFeat) this.zoomToFeature(hangFeat as unknown as Feature);
  }

  // ---- KHI CHỌN Ô ----
  if (changes['selectedO'] && this.selectedO) {
    // Bạn bảo tên trường của Ô là 'ten_o'
    const oFeat = (this.map?.querySourceFeatures('o-source') as any[] || [])
      .find(f => String(f.properties?.['ten_o']) === String(this.selectedO));
    if (oFeat) this.zoomToFeature(oFeat as unknown as Feature);
  }
}

  private initializeLayers(): void {
    if (!this.map) return;

    // Source và Layer cho KHU
    this.map.addSource('khu-source', { type: 'geojson', data: { type: 'FeatureCollection', features: [] }, generateId: true });
    this.map.addLayer({ id: 'khu-fill-layer', type: 'fill', source: 'khu-source', paint: { 'fill-color': ['case', ['boolean', ['feature-state', 'hover'], false], '#EF5350', '#D32F2F'], 'fill-opacity': 0.35 } });
    this.map.addLayer({ id: 'khu-outline-layer', type: 'line', source: 'khu-source', paint: { 'line-color': '#B71C1C', 'line-width': 2.5 } });
    this.map.addLayer({ id: 'khu-label', type: 'symbol', source: 'khu-source', layout: { 'text-field': ['get', 'ten_khu'], 'text-size': 14 }, paint: { 'text-color': '#D32F2F', 'text-halo-color': 'white', 'text-halo-width': 1 } });

    // Source và Layer cho HÀNG
    this.map.addSource('hang-source', { type: 'geojson', data: { type: 'FeatureCollection', features: [] }, generateId: true });
    this.map.addLayer({ id: 'hang-fill-layer', type: 'fill', source: 'hang-source', layout: { 'visibility': 'none' }, paint: { 'fill-color': ['case', ['boolean', ['feature-state', 'hover'], false], '#64B5F6', '#1976D2'], 'fill-opacity': 0.35 } });
    this.map.addLayer({ id: 'hang-outline-layer', type: 'line', source: 'hang-source', layout: { 'visibility': 'none' }, paint: { 'line-color': '#0D47A1', 'line-width': 2 } });
    this.map.addLayer({ id: 'hang-label', type: 'symbol', source: 'hang-source', layout: { 'visibility': 'none', 'text-field': ['get', 'ten_hang'], 'text-size': 12 }, paint: { 'text-color': '#1976D2', 'text-halo-color': 'white', 'text-halo-width': 1 } });

    // Source và Layer cho Ô
    this.map.addSource('o-source', { type: 'geojson', data: { type: 'FeatureCollection', features: [] }, generateId: true });
    this.map.addLayer({ id: 'o-fill', type: 'fill', source: 'o-source', layout: { 'visibility': 'none' }, paint: { 'fill-color': ['case', ['boolean', ['feature-state', 'hover'], false], '#627BC1', '#007cbf'], 'fill-opacity': 0.5 } });
    this.map.addLayer({ id: 'o-outline', type: 'line', source: 'o-source', layout: { 'visibility': 'none' }, paint: { 'line-color': '#000', 'line-width': 1 } });
  }

  private loadInitialKhuData(): void {
    this.mapDataService.getKhuBoundaries().subscribe(data => {
      const source = this.map?.getSource('khu-source') as maplibregl.GeoJSONSource;
      if (source) source.setData(data);
    });
  }

  private setupInteractivity(): void {
    if (!this.map) return;

    const interactiveLayers = ['khu-fill-layer', 'hang-fill-layer', 'o-fill'];

    // Lắng nghe sự kiện CLICK trên các layer
    this.map.on('click', 'khu-fill-layer', (e) => {
      if (e.features?.length) {
        const feature = e.features[0];
        const ten_khu = feature.properties?.['ten_khu'];
        if (ten_khu) { 
          this.zoomToFeature(feature); 
          this.loadHangByKhu(ten_khu); 
          this.khuPicked.emit(String(ten_khu));
        }
      }
    });

    this.map.on('click', 'hang-fill-layer', (e) => {
      if (e.features?.length) {
        const feature = e.features[0];
        const ten_hang = feature.properties?.['ten_hang'];
        if (ten_hang && this.selectedKhu) { 
          this.zoomToFeature(feature); 
          this.loadOByHang(this.selectedKhu, ten_hang); 
          this.hangPicked.emit(String(ten_hang));
        }
      }
    });

    // Click vào Ô chỉ để zoom
    this.map.on('click', 'o-fill', (e) => {
      if (e.features?.length) {
        const feature = e.features[0];
        const ten_o = feature.properties?.['ten_o'];
        this.zoomToFeature(feature);
        if (ten_o) this.oPicked.emit(String(ten_o)); 
        const description = feature.properties?.['description'];
        this.zone.run(() => {
          this.detailHtml = description || '<p>Không có thông tin chi tiết.</p>';
        });
      }
    });

    // Tối ưu: Lắng nghe sự kiện MOUSEMOVE và MOUSELEAVE trên tất cả các layer tương tác
    this.map.on('mousemove', interactiveLayers, (e) => this.handleMouseMove(e));
    this.map.on('mouseleave', interactiveLayers, () => this.handleMouseLeave());
  }

  // Xóa: Hàm này không còn cần thiết
  // private buildDetailHtmlFromProperties(...) {}
  // public closeDetailOverlay(): void {}

  private zoomToFeature(feature: Feature): void {
    if (!this.map || !feature.geometry) return;

    const bounds = new LngLatBounds();
    const geometry = feature.geometry;

    // SỬA LỖI: Kiểm tra loại geometry trước khi truy cập 'coordinates'
    if (geometry.type === 'Polygon') {
      (geometry.coordinates as [number, number][][]).forEach(ring => ring.forEach(coord => bounds.extend(coord as [number, number])));
    } else if (geometry.type === 'MultiPolygon') {
      (geometry.coordinates as [number, number][][][]).forEach(polygon => polygon.forEach(ring => ring.forEach(coord => bounds.extend(coord as [number, number]))));
    }

    if (!bounds.isEmpty()) {
      this.map.fitBounds(bounds, { padding: 100, maxZoom: 19, duration: 1200 });
    }
  }

  // Cập nhật: Hàm xử lý hover thống nhất
  private handleMouseMove(e: maplibregl.MapMouseEvent & { features?: maplibregl.MapGeoJSONFeature[] }) {
    if (!this.map || !e.features?.length) {
      // Nếu không có feature nào dưới con trỏ, đảm bảo xóa popup và highlight
      if (this.hoveredFeature) this.handleMouseLeave();
      return;
    };

    this.map.getCanvas().style.cursor = 'pointer';
    const currentFeature = e.features[0];

    // Cập nhật trạng thái hover để highlight
    if (this.hoveredFeature?.id !== currentFeature.id) {
      this.handleMouseLeave(); // Xóa trạng thái và popup cũ
      this.hoveredFeature = { id: currentFeature.id!, source: currentFeature.source };
      this.map?.setFeatureState(this.hoveredFeature, { hover: true });
    }

    // Hiển thị popup với thông tin 'description'
    const description = currentFeature.properties?.['description'];
    if (description) {
      this.popup.setLngLat(e.lngLat).setHTML(description).addTo(this.map);
    }
  }

  private handleMouseLeave() {
    if (!this.map) return;
    this.map.getCanvas().style.cursor = '';

    this.popup.remove(); // Luôn xóa popup khi rời đi

    if (this.hoveredFeature) {
      this.map?.setFeatureState(this.hoveredFeature, { hover: false });
    }
    this.hoveredFeature = null;
  }

  private toggleLayersVisibility(layerIds: string[], visibility: 'visible' | 'none'): void {
    if (!this.map) return;
    layerIds.forEach(id => this.map?.setLayoutProperty(id, 'visibility', visibility));
  }

  private loadHangByKhu(ten_khu: string): void {
    this.mapDataService.getHangByKhu(ten_khu).subscribe(data => {
      this.toggleLayersVisibility(['o-fill', 'o-outline'], 'none');

      const source = this.map?.getSource('hang-source') as maplibregl.GeoJSONSource;
      if (source) source.setData(data);

      this.toggleLayersVisibility(['hang-fill-layer', 'hang-outline-layer', 'hang-label'], 'visible');

      this.zone.run(() => {
        this.selectedKhu = ten_khu;
        this.currentView = MapViewLevel.Hang;
      });
    });
  }

  private loadOByHang(maKhu: string, maHang: string): void {
    this.mapDataService.getOByHang(maKhu, maHang).subscribe(data => {
      // Sửa lỗi: Ẩn đúng layer của Hàng
      // this.toggleLayersVisibility(['hang-fill-layer', 'hang-outline-layer', 'hang-label'], 'none');

      const source = this.map?.getSource('o-source') as maplibregl.GeoJSONSource;
      if (source) source.setData(data);

      this.toggleLayersVisibility(['o-fill', 'o-outline'], 'visible');

      this.zone.run(() => {
        this.selectedHang = maHang;
        this.currentView = MapViewLevel.O;
      });
    });
  }

  private updateLayersBasedOnMode(mode: string): void {
    const showKhu = mode === 'khu';
    const showHang = mode === 'hang';
    const showO = mode === 'o';

    // this.toggleLayersVisibility(['khu-fill-layer', 'khu-outline-layer', 'khu-label'], showKhu ? 'visible' : 'none');
    // this.toggleLayersVisibility(['hang-fill-layer', 'hang-outline-layer', 'hang-label'], showHang ? 'visible' : 'none');
    // this.toggleLayersVisibility(['o-fill', 'o-outline'], showO ? 'visible' : 'none');

    // Cập nhật lại trạng thái hiện tại của view
    this.zone.run(() => {
      this.currentView =
        mode === 'khu' ? MapViewLevel.Khu :
        mode === 'hang' ? MapViewLevel.Hang : MapViewLevel.O;
    });
  }

   private applySelectionsFromInputs(): void {
    this.updateLayersBasedOnMode(this.mapMode);

    if (this.selectedKhu) {
      this.loadHangByKhu(this.selectedKhu);
    }
    if (this.selectedKhu && this.selectedHang) {
      this.loadOByHang(this.selectedKhu, this.selectedHang);
    }
  }

  public goBack(): void {
    if (this.currentView === MapViewLevel.O) {
      this.toggleLayersVisibility(['o-fill', 'o-outline'], 'none');
      this.toggleLayersVisibility(['hang-fill-layer', 'hang-outline-layer', 'hang-label'], 'visible');
      this.zone.run(() => {
        this.selectedHang = "null";
        this.currentView = MapViewLevel.Hang;
      });
    } else if (this.currentView === MapViewLevel.Hang) {
      this.toggleLayersVisibility(['hang-fill-layer', 'hang-outline-layer', 'hang-label'], 'none');
      this.toggleLayersVisibility(['khu-fill-layer', 'khu-outline-layer', 'khu-label'], 'visible');
      this.zone.run(() => {
        this.selectedKhu = "null";
        this.currentView = MapViewLevel.Khu;
      });
    }
  }

  public closeDetailOverlay(): void {
    this.detailHtml = null;
  }

  ngOnDestroy() {
    this.map?.remove();
  }
}

