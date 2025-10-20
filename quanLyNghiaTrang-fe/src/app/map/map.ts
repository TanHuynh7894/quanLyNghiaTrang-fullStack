import {
  Component, AfterViewInit, OnDestroy, ElementRef, ViewChild,
  inject, NgZone, Input, OnChanges, SimpleChanges, Output, EventEmitter,
  ChangeDetectorRef, HostBinding
} from '@angular/core';
import { CommonModule } from '@angular/common';

import {
  Map, LngLatBounds, Popup,
  type GeoJSONSource
} from 'maplibre-gl';
import type { Feature, FeatureCollection, GeoJsonProperties, Geometry } from 'geojson';

import { Router } from '@angular/router';
import { MapDataService } from '../map-data';
import { environment } from '../../environments/environment';
import { TinhTrangMoPhan } from '../../models/tinh-trang-mo-phan';

// ==============================
// View levels
// ==============================
export enum MapViewLevel { Khu, Hang, O }
type TinhTrangMoPhanVM = Omit<TinhTrangMoPhan, 'checked'> & { checked: boolean };

@Component({
  selector: 'app-map',
  standalone: true,
  imports: [CommonModule],
  templateUrl: './map.html',
  styleUrls: ['./map.css'],
})
export class MapComponent implements AfterViewInit, OnDestroy, OnChanges {
  @ViewChild('map') private mapContainer!: ElementRef<HTMLElement>;

  @Input() mapMode: 'khu' | 'hang' | 'o' = 'khu';
  @Input() selectedKhu?: string;
  @Input() selectedHang?: string;
  @Input() selectedO?: string;

  @Output() khuPicked = new EventEmitter<string>();
  @Output() hangPicked = new EventEmitter<string>();
  @Output() oPicked = new EventEmitter<string>();

  // DI
  private router = inject(Router);
  private api = inject(MapDataService);
  private zone = inject(NgZone);
  private cdr = inject(ChangeDetectorRef);

  // Map
  private map?: Map;
  private mapReady = false;

  // State
  public currentView = MapViewLevel.Khu;
  public MapViewLevel = MapViewLevel;

  // Media / gallery
  public mediaBaseUrl = environment.apiMedia + '/';
  public galleryIndex = 0;
  private galleryTimer?: any;
  private galleryPaused = false;

  // Popup hover (reuse)
  private popup = new Popup({ closeButton: false, closeOnClick: false });
  private hoveredFeature: { source: string; id: string | number } | null = null;

  // Legend
  public tinhTrangList: TinhTrangMoPhanVM[] = [];
  public tinhTrangLoading = false;
  public tinhTrangError?: string;
  public showLegendTtmp = false;
  private selectedTinhTrang = new Set<string>();

  // Detail overlay data
  public detailHtml: any | null = null;

  // Caches (để tìm feature theo thuộc tính)
  private khuData: FeatureCollection | null = null;
  private hangData: FeatureCollection | null = null;
  private oData: FeatureCollection | null = null;

  @HostBinding('class.overlay-visible') get isOverlayVisible() { return !!this.detailHtml; }

  // ==============================
  // Lifecycle
  // ==============================
  ngAfterViewInit() {
    const apiKey = '3suk2GO5O2JgkhGmruDP'; // -> đưa vào env nếu cần
    const initial = { lng: 106.64731872829728, lat: 11.180320653754398, zoom: 17.5 };

    console.log('[Map] init with center:', initial);

    this.map = new Map({
      container: this.mapContainer.nativeElement,
      style: `https://api.maptiler.com/maps/streets-v2/style.json?key=${apiKey}`,
      center: [initial.lng, initial.lat],
      zoom: initial.zoom,
      maxZoom: 22,
    });

    this.map.on('load', () => {
      console.log('[Map] style loaded');
      this.initializeLayers();
      this.loadInitialKhuData();
      this.setupInteractivity();
      this.mapReady = true;
      this.applySelectionsFromInputs();
    });
  }

  ngOnChanges(changes: SimpleChanges): void {
    if (!this.mapReady) return;

    console.log('[ngOnChanges]', {
      mapMode: this.mapMode,
      selectedKhu: this.selectedKhu,
      selectedHang: this.selectedHang,
      selectedO: this.selectedO
    });

    if (changes['mapMode'] && !changes['mapMode'].firstChange) {
      this.updateLayersBasedOnMode(this.mapMode);
    }

    if (changes['selectedKhu'] && this.selectedKhu) {
      this.updateLayersBasedOnMode('hang');
      this.loadHangByKhuP(this.selectedKhu).then(() => {
        const f = this.findFeatureInCache(this.khuData, 'ten_khu', this.selectedKhu!);
        console.log('[ngOnChanges] found khu feature =', !!f);
        if (f) this.zoomToFeature(f);
      });
    }

    if (changes['selectedHang'] && this.selectedKhu && this.selectedHang) {
      this.updateLayersBasedOnMode('o');
      this.loadOByHangP(this.selectedKhu, this.selectedHang).then(() => {
        const f = this.findFeatureInCache(this.hangData, 'ten_hang', this.selectedHang!);
        console.log('[ngOnChanges] found hang feature =', !!f);
        if (f) this.zoomToFeature(f);
      });
    }

    if (changes['selectedO'] && this.selectedO) {
      const f = this.findFeatureInCache(this.oData, 'ten_o', this.selectedO);
      console.log('[ngOnChanges] found o feature =', !!f);
      if (f) {
        this.zoomToFeature(f);
        setTimeout(() => this.flashOByTenO(this.selectedO!), 600);
      }
    }
  }

  ngOnDestroy() {
    console.log('[Map] destroy');
    this.map?.remove();
  }

  // ==============================
  // Init layers & sources
  // ==============================
  private initializeLayers(): void {
    if (!this.map) return;
    console.log('[Layers] initialize');

    // KHU
    this.map.addSource('khu-source', { type: 'geojson', data: this.emptyFC(), promoteId: 'id' });
    this.map.addLayer({
      id: 'khu-fill-layer', type: 'fill', source: 'khu-source',
      paint: { 'fill-color': ['case', ['boolean', ['feature-state', 'hover'], false], '#EF5350', '#D32F2F'], 'fill-opacity': 0.35 }
    });
    this.map.addLayer({ id: 'khu-outline-layer', type: 'line', source: 'khu-source', paint: { 'line-color': '#B71C1C', 'line-width': 2.5 } });
    this.map.addLayer({
      id: 'khu-label', type: 'symbol', source: 'khu-source',
      layout: { 'text-field': ['get', 'ten_khu'], 'text-size': 14 },
      paint: { 'text-color': '#D32F2F', 'text-halo-color': 'white', 'text-halo-width': 1 }
    });

    // HÀNG
    this.map.addSource('hang-source', { type: 'geojson', data: this.emptyFC(), promoteId: 'id' });
    this.map.addLayer({
      id: 'hang-fill-layer', type: 'fill', source: 'hang-source', layout: { 'visibility': 'none' },
      paint: { 'fill-color': ['case', ['boolean', ['feature-state', 'hover'], false], '#64B5F6', '#1976D2'], 'fill-opacity': 0.35 }
    });
    this.map.addLayer({ id: 'hang-outline-layer', type: 'line', source: 'hang-source', layout: { 'visibility': 'none' }, paint: { 'line-color': '#0D47A1', 'line-width': 2 } });
    this.map.addLayer({
      id: 'hang-label', type: 'symbol', source: 'hang-source',
      layout: { 'visibility': 'none', 'text-field': ['get', 'ten_hang'], 'text-size': 12 },
      paint: { 'text-color': '#1976D2', 'text-halo-color': 'white', 'text-halo-width': 1 }
    });

    // Ô
    this.map.addSource('o-source', { type: 'geojson', data: this.emptyFC(), promoteId: 'id' });
    this.map.addLayer({
      id: 'o-fill', type: 'fill', source: 'o-source', layout: { 'visibility': 'none' },
      paint: {
        'fill-color': ['case', ['boolean', ['feature-state', 'hover'], false], '#627BC1', '#007cbf'],
        'fill-opacity': 0.5
      }
    });
    this.map.addLayer({
      id: 'o-outline', type: 'line', source: 'o-source', layout: { 'visibility': 'none' },
      paint: {
        'line-color': ['case', ['boolean', ['feature-state', 'flash'], false], '#ffffff', '#000000'],
        'line-width': ['case', ['boolean', ['feature-state', 'flash'], false], 4, 1]
      }
    });
  }

  // ==============================
  // Data loading (Promise-based)
  // ==============================
  private loadInitialKhuData(): void {
    console.log('[Data] loadInitialKhuData');
    this.api.getKhuBoundaries().subscribe(data => {
      console.log('[Data] khu setData:', data?.features?.length);
      this.khuData = data;
      const src = this.map?.getSource('khu-source') as GeoJSONSource | undefined;
      src?.setData(data);
    });
  }

  private loadHangByKhuP(ten_khu: string): Promise<void> {
    console.log('[Data] loadHangByKhu:', ten_khu);
    return new Promise<void>((resolve) => {
      this.api.getHangByKhu(ten_khu).subscribe(async data => {
        console.log('[Data] hang setData:', data?.features?.length, 'for khu:', ten_khu);

        this.hangData = data;
        this.toggleLayersVisibility(['o-fill', 'o-outline'], 'none');

        const src = this.map?.getSource('hang-source') as GeoJSONSource | undefined;
        src?.setData(data);

        this.toggleLayersVisibility(['hang-fill-layer', 'hang-outline-layer', 'hang-label'], 'visible');

        this.zone.run(() => {
          this.selectedKhu = ten_khu;
          this.currentView = MapViewLevel.Hang;
          this.showLegendTtmp = false;
        });

        await this.waitForSourceData('hang-source');
        resolve();
      });
    });
  }

  private loadOByHangP(ten_khu: string, ten_hang: string): Promise<void> {
    console.log('[Data] loadOByHang:', { ten_khu, ten_hang });
    return new Promise<void>((resolve) => {
      this.api.getOByHang(ten_khu, ten_hang).subscribe(async (data) => {
        // Chuẩn hoá props
        data.features?.forEach((f: any, i: number) => {
          const props = (f.properties ??= {}) as Record<string, any>;
          let mp = props['mo_phan'];
          if (typeof mp === 'string') { try { mp = JSON.parse(mp); } catch { mp = {}; } }
          if (typeof mp !== 'object' || mp === null) mp = {};
          props['mo_phan'] = mp;
          props['ma_tinh_trang_flat'] = String(mp['ma_tinh_trang'] ?? '');
          if (props['id'] == null) props['id'] = f.id ?? `o_${i}`;
        });

        console.log('[Data] o setData:', data?.features?.length, 'for hang:', ten_hang);
        this.oData = data;

        const src = this.map?.getSource('o-source') as GeoJSONSource | undefined;
        src?.setData(data);

        this.toggleLayersVisibility(['o-fill', 'o-outline'], 'visible');

        this.zone.run(() => {
          this.selectedHang = ten_hang;
          this.currentView = MapViewLevel.O;
          this.showLegendTtmp = true;
        });
        this.showTinhTrangMoPhan();

        await this.waitForSourceData('o-source');
        resolve();
      });
    });
  }

  // ==============================
  // Interactivity
  // ==============================
  private setupInteractivity(): void {
    if (!this.map) return;
    console.log('[UX] setup interactivity');

    const interactive = ['khu-fill-layer', 'hang-fill-layer', 'o-fill'];

    // Click KHU
    this.map.on('click', 'khu-fill-layer', (e) => {
      const f = e.features?.[0];
      const ten_khu = f?.properties?.['ten_khu'];
      console.log('[UX] click khu', ten_khu);

      if (ten_khu) {
        this.zoomToFeature(f as any);
        this.loadHangByKhuP(String(ten_khu));
        this.khuPicked.emit(String(ten_khu));
      }
    });

    // Click HÀNG
    this.map.on('click', 'hang-fill-layer', (e) => {
      const f = e.features?.[0];
      const ten_hang = f?.properties?.['ten_hang'];
      console.log('[UX] click hang', ten_hang);

      if (ten_hang && this.selectedKhu) {
        this.zoomToFeature(f as any);
        this.loadOByHangP(this.selectedKhu, String(ten_hang));
        this.hangPicked.emit(String(ten_hang));
      }
    });

    // Click Ô
    this.map.on('click', 'o-fill', (e) => {
      const f = e.features?.[0];
      if (!f) return;
      const ten_o = f.properties?.['ten_o'];
      console.log('[UX] click ô', ten_o, f.properties);

      this.zoomToFeature(f as any);
      if (ten_o) this.oPicked.emit(String(ten_o));

      const parse = (v: unknown) => (typeof v === 'string' ? (JSON.parse(v as any) ?? v) : v);
      const props = (f.properties ?? {}) as Record<string, unknown>;
      const parsed = {
        id: props['id'],
        ten_o: props['ten_o'],
        ten_hang: props['ten_hang'],
        ten_khu: props['ten_khu'],
        dia_chi: props['dia_chi'],
        mo_phan: parse(props['mo_phan']),
        lich_su_mo_phan: (parse(props['lich_su_mo_phan']) as any[]) ?? [],
        hinh_anh_mo_phan: (parse(props['hinh_anh_mo_phan']) as any[]) ?? [],
      };
      console.log('[UX] detail parsed:', parsed);
      this.zone.run(() => this.showDetail(parsed));
    });

    // Hover chung
    this.map.on('mousemove', interactive, (e) => this.handleMouseMove(e));
    this.map.on('mouseleave', interactive, () => this.handleMouseLeave());
  }

  private handleMouseMove(e: maplibregl.MapMouseEvent & { features?: maplibregl.MapGeoJSONFeature[] }) {
    if (!this.map || !e.features?.length) { if (this.hoveredFeature) this.handleMouseLeave(); return; }
    const f = e.features[0];

    this.map.getCanvas().style.cursor = 'pointer';
    if (this.hoveredFeature?.id !== f.id) {
      this.handleMouseLeave();
      this.hoveredFeature = { source: String(f.source), id: f.id! };
      this.map.setFeatureState(this.hoveredFeature, { hover: true });
    }

    const description = f.properties?.['description'];
    if (description) this.popup.setLngLat(e.lngLat).setHTML(description).addTo(this.map);
  }

  private handleMouseLeave() {
    if (!this.map) return;
    this.map.getCanvas().style.cursor = '';
    this.popup.remove();
    if (this.hoveredFeature) this.map.setFeatureState(this.hoveredFeature, { hover: false });
    this.hoveredFeature = null;
  }

  // ==============================
  // Zoom (robust & logged)
  // ==============================
  private zoomToFeature(feature: Feature): void {
    if (!this.map || !feature?.geometry) return;

    const doZoom = () => {
      try { this.map!.resize(); } catch { }
      const b = this.computeBounds(feature.geometry);
      if (!b) {
        console.warn('[Zoom] Empty bounds. Feature=', feature);
        return;
      }

      const size = {
        w: Math.abs(b.getEast() - b.getWest()),
        h: Math.abs(b.getNorth() - b.getSouth()),
      };
      console.log('[Zoom] bounds=', b.toArray(), 'size=', size);

      // bbox rất nhỏ → bay thẳng vào tâm với zoom cao
      const tiny = size.w * size.h < 1e-9;
      if (tiny) {
        const c = b.getCenter();
        console.log('[Zoom] tiny bbox -> easeTo center=', c, 'z=19');
        this.map!.easeTo({ center: c, zoom: 19, duration: 700 });
        return;
      }

      // fitBounds trước, sau đó ép đảm bảo zoom tối thiểu 18
      this.map!.fitBounds(b, {
        padding: { top: 36, bottom: 36, left: 40, right: 40 },
        maxZoom: 22,
        duration: 700
      });

      this.map!.once('moveend', () => {
        const z = this.map!.getZoom();
        if (z < 18) {
          const c = b.getCenter();
          console.log('[Zoom] post-fit: z=', z, '→ enforce z=18 at', c);
          this.map!.easeTo({ center: c, zoom: 18, duration: 500 });
        }
      });
    };

    if (this.map.isStyleLoaded()) doZoom();
    else this.map.once('idle', doZoom);
  }

  private computeBounds(geom: Geometry): LngLatBounds | null {
    const pts: [number, number][] = [];

    const push = (xy: any) => {
      let x = Number(Array.isArray(xy) ? xy[0] : undefined);
      let y = Number(Array.isArray(xy) ? xy[1] : undefined);
      // guard: nếu [lat,lng] bị đảo → sửa lại [lng,lat]
      if (Number.isFinite(x) && Number.isFinite(y) && Math.abs(y) > 90 && Math.abs(x) <= 90) [x, y] = [y, x];
      if (Number.isFinite(x) && Number.isFinite(y)) pts.push([x, y]);
    };
    const walk = (node: any) => {
      if (!node) return;
      if (Array.isArray(node) && typeof node[0] === 'number' && typeof node[1] === 'number') { push(node); return; }
      if (Array.isArray(node)) node.forEach(walk);
    };

    if (geom.type === 'Point') push((geom as any).coordinates);
    else if (geom.type === 'GeometryCollection') (geom as any).geometries.forEach((g: any) => walk(g.coordinates));
    else walk((geom as any).coordinates);

    console.log('[Bounds] points collected:', pts.length, 'first=', pts[0]);
    if (pts.length === 0) return null;

    const b = new LngLatBounds();
    for (const p of pts) b.extend(p);
    return b;
  }

  // ==============================
  // Back navigation
  // ==============================
  public goBack(): void {
    if (!this.map) return;
    if (this.currentView === MapViewLevel.O) {
      this.toggleLayersVisibility(['o-fill', 'o-outline'], 'none');
      this.toggleLayersVisibility(['hang-fill-layer', 'hang-outline-layer', 'hang-label'], 'visible');
      this.zone.run(() => { this.selectedHang = 'null'; this.currentView = MapViewLevel.Hang; });
    } else if (this.currentView === MapViewLevel.Hang) {
      this.toggleLayersVisibility(['hang-fill-layer', 'hang-outline-layer', 'hang-label'], 'none');
      this.toggleLayersVisibility(['khu-fill-layer', 'khu-outline-layer', 'khu-label'], 'visible');
      this.zone.run(() => { this.selectedKhu = 'null'; this.currentView = MapViewLevel.Khu; });
    }
  }

  // ==============================
  // Detail panel / gallery
  // ==============================
  public closeDetailOverlay(): void { this.detailHtml = null; this.clearAuto(); }
  private showDetail(d: any) { this.detailHtml = d; this.galleryIndex = 0; this.startAuto(); this.cdr.detectChanges(); }
  public nextImg() { const n = this.detailHtml?.hinh_anh_mo_phan?.length || 0; if (!n) return; this.galleryIndex = (this.galleryIndex + 1) % n; }
  public prevImg() { const n = this.detailHtml?.hinh_anh_mo_phan?.length || 0; if (!n) return; this.galleryIndex = (this.galleryIndex - 1 + n) % n; }
  public goImg(i: number) { this.galleryIndex = i; }
  private startAuto() { this.clearAuto(); this.galleryTimer = setInterval(() => { if (!this.galleryPaused) this.nextImg(); }, 2000); }
  private clearAuto() { if (this.galleryTimer) { clearInterval(this.galleryTimer); this.galleryTimer = undefined; } }
  public pauseAuto() { this.galleryPaused = true; }
  public resumeAuto() { this.galleryPaused = false; }

  // ==============================
  // Flash selected Ô
  // ==============================
  private flashOByTenO(tenO: string, cycles = 8, interval = 250) {
    if (!this.map) return;
    const f = this.findFeatureInCache(this.oData, 'ten_o', tenO) as any;
    console.log('[Flash] find o by ten_o=', tenO, 'found=', !!f);
    if (!f) return;

    const id = f.id ?? f.properties?.['id'];
    if (id == null) return;

    const key = { source: 'o-source', id };
    let on = false, count = 0;
    const timer = setInterval(() => {
      on = !on; this.map!.setFeatureState(key, { flash: on }); count++;
      if (count >= cycles) { clearInterval(timer); this.map!.setFeatureState(key, { flash: false }); }
    }, interval);
  }

  // ==============================
  // Legend (tình trạng mộ phần)
  // ==============================
  public showTinhTrangMoPhan(): void {
    console.log('[Legend] load');
    this.tinhTrangLoading = true; this.tinhTrangError = undefined;
    this.api.getTinhTrangMoPhan().subscribe({
      next: (list: TinhTrangMoPhan[]) => {
        this.tinhTrangList = list.map((tt): TinhTrangMoPhanVM => ({ ...tt, checked: this.selectedTinhTrang.has(tt.ma_tinh_trang) }));
        this.tinhTrangLoading = false;
        console.log('[Legend] loaded items:', this.tinhTrangList.length);
      },
      error: (err) => { this.tinhTrangLoading = false; this.tinhTrangError = 'Lỗi tải tình trạng mộ phần'; console.error('[Legend] error:', err); }
    });
  }

  public onTinhTrangToggle(tt: TinhTrangMoPhanVM) {
    tt.checked = !tt.checked;
    if (tt.checked) this.selectedTinhTrang.add(tt.ma_tinh_trang);
    else this.selectedTinhTrang.delete(tt.ma_tinh_trang);
    console.log('[Legend] toggle:', tt.ma_tinh_trang, 'checked=', tt.checked);
    this.applyTinhTrangColors();
  }

  private applyTinhTrangColors() {
    if (!this.map) return;
    const layerId = 'o-fill'; if (!this.map.getLayer(layerId)) return;

    const STATUS_PROP: any[] = ['get', 'ma_tinh_trang_flat'];
    const active = this.tinhTrangList.filter(x => x.checked && x.color);
    const fallbackColor = 'rgba(120,120,120,0.18)';

    if (active.length === 0) {
      const hoverFlag: any[] = ['boolean', ['feature-state', 'hover'], false];
      this.map.setPaintProperty(layerId, 'fill-color', ['case', hoverFlag, '#627BC1', '#007cbf'] as any);
      this.map.setPaintProperty(layerId, 'fill-opacity', ['case', hoverFlag, 0.9, 0.5] as any);
      console.log('[Legend] reset colors (no filters)');
      return;
    }

    const colorExpr: any[] = ['match', STATUS_PROP];
    for (const s of active) colorExpr.push(s.ma_tinh_trang, s.color!);
    colorExpr.push(fallbackColor);
    this.map.setPaintProperty(layerId, 'fill-color', colorExpr as any);

    const isActiveExpr: any[] = ['match', STATUS_PROP, ...active.flatMap(s => [s.ma_tinh_trang, true]), false];
    const opacityExpr: any[] = ['case', isActiveExpr, 0.75, 0.25];
    this.map.setPaintProperty(layerId, 'fill-opacity', opacityExpr as any);

    console.log('[Legend] apply colors for active:', active.map(a => a.ten_tinh_trang));
  }

  // ==============================
  // Search theo tên người mất
  // ==============================
  public async searchByTenNguoiMat(ten: string): Promise<void> {
    if (!ten || !ten.trim()) return;
    console.log('[SearchByTen] start with:', ten);

    this.api.getOByTenNguoiMat(ten).subscribe({
      next: async (feature: Feature) => {
        if (!feature || !feature.properties) {
          console.warn('[SearchByTen] Không tìm thấy mộ phần cho tên:', ten);
          return;
        }

        const props = feature.properties as any;
        const diaChi = String(props['dia_chi'] ?? '');
        console.log('[SearchByTen] feature props dia_chi=', diaChi, props);

        // Tách từ "6.3-6-15"
        const [ten_khu, ten_hang, ten_o] = diaChi.split('-');
        if (!ten_khu || !ten_hang || !ten_o) {
          console.warn('[SearchByTen] dia_chi không hợp lệ:', diaChi);
          // Zoom fallback theo geometry API vẫn chuẩn
          this.zoomToFeature(feature);
          return;
        }

        // 1) Load Hang theo Khu (đợi xong source render)
        await this.loadHangByKhuP(ten_khu);

        // 2) Load Ô theo Hàng (đợi xong source render)
        await this.loadOByHangP(ten_khu, ten_hang);

        // 3) Tìm đúng Ô trong cache sau khi source đã render
        const oFeat = this.findFeatureInCache(this.oData, 'ten_o', ten_o);
        console.log('[SearchByTen] o feature in cache:', !!oFeat);

        if (oFeat) {
          this.zoomToFeature(oFeat);
          this.flashOByTenO(ten_o);

          // Panel chi tiết từ oFeat
          const pf = (oFeat.properties ?? {}) as any;
          const parsed = {
            id: pf['id'],
            ten_o: pf['ten_o'],
            ten_hang: pf['ten_hang'],
            ten_khu: pf['ten_khu'],
            dia_chi: pf['dia_chi'],
            mo_phan: typeof pf['mo_phan'] === 'string' ? safeParse(pf['mo_phan']) : pf['mo_phan'],
            lich_su_mo_phan: (typeof pf['lich_su_mo_phan'] === 'string' ? safeParse(pf['lich_su_mo_phan']) : pf['lich_su_mo_phan']) ?? [],
            hinh_anh_mo_phan: (typeof pf['hinh_anh_mo_phan'] === 'string' ? safeParse(pf['hinh_anh_mo_phan']) : pf['hinh_anh_mo_phan']) ?? [],
          };
          console.log('[SearchByTen] detail parsed from oData:', parsed);
          this.zone.run(() => this.showDetail(parsed));
        } else {
          // Fallback: zoom theo feature API (chuẩn tọa độ), vẫn flash theo ten_o
          console.log('[SearchByTen] fallback zoom using API feature geometry');
          this.zoomToFeature(feature);
          this.flashOByTenO(ten_o);
          this.zone.run(() => this.showDetail(props));
        }

        function safeParse(v: any) { try { return JSON.parse(v); } catch { return v; } }
      },
      error: (err) => {
        console.error('[SearchByTen] error:', err);
      }
    });
  }

  // ==============================
  // Helpers
  // ==============================
  private async waitForIdle(): Promise<void> {
    if (!this.map) return;
    await new Promise<void>(res => this.map!.once('idle', () => res()));
  }

  private async waitForSourceData(sourceId: string, timeoutMs = 1500): Promise<void> {
    if (!this.map) return;
    const start = performance.now();
    await new Promise<void>((resolve) => {
      const onData = () => {
        // sourcedata có thể được bắn nhiều lần; ta chờ khi source state "loaded" (đơn giản: delay 1 tick)
        if (performance.now() - start > 50) {
          this.map!.off('sourcedata', onData);
          resolve();
        }
      };
      this.map!.on('sourcedata', onData);

      // timeout an toàn
      setTimeout(() => {
        this.map!.off('sourcedata', onData);
        console.warn('[waitForSourceData] timeout for', sourceId);
        resolve();
      }, timeoutMs);
    });
  }

  private toggleLayersVisibility(ids: string[], vis: 'visible' | 'none') {
    if (!this.map) return;
    ids.forEach(id => { if (this.map!.getLayer(id)) this.map!.setLayoutProperty(id, 'visibility', vis); });
    console.log('[Layer] toggle visibility:', ids, vis);
  }

  private updateLayersBasedOnMode(mode: 'khu' | 'hang' | 'o') {
    console.log('[Mode] update to', mode);
    this.zone.run(() => {
      this.currentView = mode === 'khu' ? MapViewLevel.Khu : mode === 'hang' ? MapViewLevel.Hang : MapViewLevel.O;
    });
  }

  private applySelectionsFromInputs(): void {
    console.log('[ApplySelections] mode=', this.mapMode, 'khu=', this.selectedKhu, 'hang=', this.selectedHang, 'o=', this.selectedO);
    this.updateLayersBasedOnMode(this.mapMode);
    if (this.selectedKhu) this.loadHangByKhuP(this.selectedKhu);
    if (this.selectedKhu && this.selectedHang) this.loadOByHangP(this.selectedKhu, this.selectedHang);
  }

  private emptyFC(): FeatureCollection { return { type: 'FeatureCollection', features: [] }; }

  private findFeatureInCache(fc: FeatureCollection | null, key: string, val: string | number | boolean): Feature | null {
    if (!fc) return null;
    const v = String(val);
    const f = fc.features.find(f => String((f.properties as GeoJsonProperties)?.[key]) === v);
    return f || null;
  }
}
