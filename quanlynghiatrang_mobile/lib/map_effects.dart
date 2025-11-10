// lib/map_effects.dart
import 'package:flutter/widgets.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

/// Kết quả render kèm meta để tra ngược Fill -> Feature.
class FillMeta {
  final Fill fill;
  final Map<String, dynamic> feature;     // properties/geometry đầy đủ 1 feature
  final List<LatLng> ring;                // outer ring đã vẽ
  FillMeta({required this.fill, required this.feature, required this.ring});
}

/// Gom các hiệu ứng / tiện ích thao tác map cho MapLibre Flutter.
class MapEffects {
  MapEffects({required this.context});
  final BuildContext context;

  MaplibreMapController? _ctl;
  set controller(MaplibreMapController c) => _ctl = c;
  bool get _ready => _ctl != null;

  /// Xoá tất cả Fill trong 1 layer list.
  Future<void> clearFills(List<Fill> list) async {
    if (!_ready) return;
    for (final f in list) {
      try { await _ctl!.removeFill(f); } catch (_) {}
    }
    list.clear();
  }

  /// Vẽ dữ liệu GeoJSON → layer Fill (phiên bản nhanh, không trả meta).
  Future<void> renderLayer({
    required dynamic data,
    required List<Fill> layer,
    required String outline,
    required double opacity,
    bool clearBefore = true,
    bool fitCamera = true,
    String Function(Map<String, dynamic> f)? colorResolver,
  }) async {
    await renderLayerWithMeta(
      data: data,
      targetLayer: layer,
      outline: outline,
      opacity: opacity,
      clearBefore: clearBefore,
      fitCamera: fitCamera,
      colorResolver: colorResolver,
    );
  }

  /// Vẽ dữ liệu GeoJSON → trả danh sách FillMeta để biết Fill gắn với feature nào.
  Future<List<FillMeta>> renderLayerWithMeta({
    required dynamic data,
    required List<Fill> targetLayer,
    required String outline,
    required double opacity,
    bool clearBefore = true,
    bool fitCamera = true,
    String Function(Map<String, dynamic> f)? colorResolver,
  }) async {
    final metas = <FillMeta>[];
    if (!_ready) return metas;
    if (clearBefore) await clearFills(targetLayer);

    // Chuẩn hoá về List<Feature(Map)>
    final feats = <Map<String, dynamic>>[];
    if (data is Map && data['type'] == 'FeatureCollection') {
      for (final f in (data['features'] as List? ?? const [])) {
        if (f is Map) feats.add(Map<String, dynamic>.from(f));
      }
    } else if (data is Map && data['type'] == 'Feature') {
      feats.add(Map<String, dynamic>.from(data));
    } else if (data is List) {
      for (final f in data) {
        if (f is Map) feats.add(Map<String, dynamic>.from(f));
      }
    }
    if (feats.isEmpty) return metas;

    final bb = _BoundsBuilder();

    for (final feat in feats) {
      final geom = feat['geometry'];
      if (geom is! Map) continue;
      final type = geom['type'];
      final coords = geom['coordinates'];

      final rings = <List<LatLng>>[];

      if (type == 'Polygon' && coords is List && coords.isNotEmpty) {
        rings.add(_toLatLngList(coords.first));
      } else if (type == 'MultiPolygon' && coords is List) {
        for (final poly in coords) {
          if (poly is List && poly.isNotEmpty) {
            rings.add(_toLatLngList(poly.first));
          }
        }
      } else {
        continue; // geometry khác bỏ qua
      }

      final color = colorResolver != null ? colorResolver(feat) : '#e74c3c';
      for (final ring in rings) {
        if (ring.isEmpty) continue;
        final fill = await _ctl!.addFill(FillOptions(
          geometry: [ring],
          fillOpacity: opacity,
          fillColor: color,
          fillOutlineColor: outline,
        ));
        targetLayer.add(fill);
        metas.add(FillMeta(fill: fill, feature: feat, ring: ring));
        for (final p in ring) bb.add(p);
      }
    }

    if (fitCamera && bb.isValid) {
      await _ctl!.animateCamera(
        CameraUpdate.newLatLngBounds(
          bb.toLatLngBounds(),
          left: 40, top: 160, right: 40, bottom: 40,
        ),
      );
    }
    return metas;
  }

  /// Tính centroid (đủ dùng cho popup) của 1 ring (có thể đóng/mở).
  LatLng polygonCentroid(List<LatLng> ring) {
    final pts = (ring.isNotEmpty && ring.first == ring.last)
        ? ring.sublist(0, ring.length - 1)
        : ring;
    double a = 0, cx = 0, cy = 0;
    for (int i = 0; i < pts.length; i++) {
      final j = (i + 1) % pts.length;
      final x0 = pts[i].longitude, y0 = pts[i].latitude;
      final x1 = pts[j].longitude, y1 = pts[j].latitude;
      final cross = x0 * y1 - x1 * y0;
      a += cross; cx += (x0 + x1) * cross; cy += (y0 + y1) * cross;
    }
    a *= 0.5;
    if (a.abs() < 1e-12) {
      double minLat =  90, maxLat = -90, minLon = 180, maxLon = -180;
      for (final p in pts) {
        if (p.latitude  < minLat) minLat = p.latitude;
        if (p.latitude  > maxLat) maxLat = p.latitude;
        if (p.longitude < minLon) minLon = p.longitude;
        if (p.longitude > maxLon) maxLon = p.longitude;
      }
      return LatLng((minLat + maxLat)/2, (minLon + maxLon)/2);
    }
    return LatLng(cy / (6 * a), cx / (6 * a));
  }

  /// Đổi LatLng → toạ độ màn hình (Offset) cho popup widget.
  Future<Offset?> toScreenOffset(LatLng latLng) async {
    if (!_ready) return null;
    final sc = await _ctl!.toScreenLocation(latLng);
    final off = Offset(sc.x.toDouble(), sc.y.toDouble());
    final size = MediaQuery.of(context).size;
    final isOff =
        off.dx < 0 || off.dy < 0 || off.dx > size.width || off.dy > size.height;
    return isOff ? null : off;
  }

  // ----------------- private helpers -----------------
  List<LatLng> _toLatLngList(dynamic ring) {
    final List<LatLng> result = [];
    if (ring is List) {
      for (final pt in ring) {
        if (pt is List && pt.length >= 2) {
          // GeoJSON: [lon, lat] → LatLng(lat, lon)
          result.add(LatLng((pt[1] as num).toDouble(), (pt[0] as num).toDouble()));
        }
      }
    }
    return result;
  }
}

/// Tính bounds cho camera.
class _BoundsBuilder {
  double? minLat, minLon, maxLat, maxLon;
  void add(LatLng p) {
    minLat = (minLat == null) ? p.latitude  : (p.latitude  < minLat! ? p.latitude  : minLat);
    maxLat = (maxLat == null) ? p.latitude  : (p.latitude  > maxLat! ? p.latitude  : maxLat);
    minLon = (minLon == null) ? p.longitude : (p.longitude < minLon! ? p.longitude : minLon);
    maxLon = (maxLon == null) ? p.longitude : (p.longitude > maxLon! ? p.longitude : maxLon);
  }
  bool get isValid => minLat != null && minLon != null && maxLat != null && maxLon != null;
  LatLngBounds toLatLngBounds() =>
      LatLngBounds(southwest: LatLng(minLat!, minLon!), northeast: LatLng(maxLat!, maxLon!));
}
