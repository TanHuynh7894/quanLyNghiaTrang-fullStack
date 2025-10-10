import { Injectable } from '@angular/core';
import { HttpClient } from '@angular/common/http';
import { Observable } from 'rxjs';
import { FeatureCollection } from 'geojson';
import { environment } from '../environments/environment';
import { TinhTrangMoPhan } from '../models/tinh-trang-mo-phan';

@Injectable({
  providedIn: 'root'
})
export class MapDataService {
  private apiUrl = `${environment.apiDomain}/searchAll`;
  constructor(private http: HttpClient) { }

  getAllFeatures(): Observable<FeatureCollection> {
    return this.http.get<FeatureCollection>(this.apiUrl);
  }

  getKhuBoundaries(): Observable<FeatureCollection> {
    const url = `${environment.apiDomain}/khu`;
    return this.http.get<FeatureCollection>(url);
  }

  // API Lấy các Hàng trong một Khu
  getHangByKhu(ten_khu: string): Observable<FeatureCollection> {
    const url = `${environment.apiDomain}/hang?ten_khu=${ten_khu}`;
    return this.http.get<FeatureCollection>(url);
  }

  // API Lấy các Ô trong một Hàng của một Khu
  getOByHang(ten_khu: string, ten_hang: string): Observable<FeatureCollection> {
    const url = `${environment.apiDomain}/o?ten_khu=${ten_khu}&ten_hang=${ten_hang}`;
    return this.http.get<FeatureCollection>(url);
  }

  getKhuByDiaChi(dia_chi: string): Observable<FeatureCollection> {
    const url = `${environment.apiDomain}/khu?ten_khu=${dia_chi}`;
    return this.http.get<FeatureCollection>(url);
  }

  getHangByDiaChi(dia_chi: string): Observable<FeatureCollection> {
    const url = `${environment.apiDomain}/hang?dia_chi=${dia_chi}`;
    return this.http.get<FeatureCollection>(url);
  }

  getOByDiaChi(dia_chi: string): Observable<FeatureCollection> {
    const url = `${environment.apiDomain}/o?dia_chi=${dia_chi}`;
    return this.http.get<FeatureCollection>(url);
  }

  getTinhTrangMoPhan(){
    const url = `${environment.apiDomain}/tinh-trang-mo-phan`;
    return this.http.get<TinhTrangMoPhan[]>(url);
  }
}

