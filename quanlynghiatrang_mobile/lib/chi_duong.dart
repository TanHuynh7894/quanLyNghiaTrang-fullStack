// lib/chi_duong.dart
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:url_launcher/url_launcher.dart';

class ChiDuongService {
  final String baseUrl; // VD: http://10.0.2.2:5000
  final MaplibreMapController mapController;

  /// Giữ tất cả các Line hiện đang vẽ trên map cho route
  final List<Line> _routeLines = [];

  ChiDuongService({
    required this.baseUrl,
    required this.mapController,
  });

  // =========================================================
  // 1. Mở Google Maps (fallback khi không tính được đường nội bộ)
  // =========================================================
  Future<void> openGoogleMapDirection(LatLng start, LatLng end) async {
    final url = 'https://www.google.com/maps/dir/?api=1'
        '&origin=${start.latitude},${start.longitude}'
        '&destination=${end.latitude},${end.longitude}'
        '&travelmode=walking';

    final uri = Uri.parse(url);

    print('[NAV] OPEN GOOGLE MAPS: $uri');

    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      print('[NAV] Không mở được Google Maps');
    }
  }

  // =========================================================
  // 2. Parse GeoJSON string -> List<List<LatLng>> (các segment)
  // =========================================================
  /// Trả về danh sách các segment, mỗi segment là một polyline (List<LatLng>)
  List<List<LatLng>> _parseGeoJsonToSegments(String geojsonStr) {
    print('[NAV] parseGeoJsonToSegments: start');

    final geo = jsonDecode(geojsonStr) as Map<String, dynamic>;
    final type = geo['type'];
    print('[NAV] GeoJSON type=$type');

    // MultiLineString: [ [ [lng,lat], ... ], [ ... ], ... ]
    if (type == 'MultiLineString') {
      final segments = geo['coordinates'] as List;
      final List<List<LatLng>> result = [];

      for (final seg in segments) {
        final segList = seg as List;
        final List<LatLng> pts = [];

        for (final pair in segList) {
          final p = pair as List;
          final lng = (p[0] as num).toDouble();
          final lat = (p[1] as num).toDouble();

          // tránh trùng điểm liên tiếp
          if (pts.isEmpty ||
              pts.last.latitude != lat ||
              pts.last.longitude != lng) {
            pts.add(LatLng(lat, lng));
          }
        }

        if (pts.length >= 2) {
          result.add(pts);
        }
      }

      print('[NAV] MultiLineString segments=${result.length}');
      return result;
    }

    // LineString: [ [lng,lat], [lng,lat], ... ] -> 1 segment
    if (type == 'LineString') {
      final coordsRaw = geo['coordinates'] as List;
      final pts = coordsRaw.map<LatLng>((c) {
        final list = c as List;
        final lng = (list[0] as num).toDouble();
        final lat = (list[1] as num).toDouble();
        return LatLng(lat, lng);
      }).toList();

      print('[NAV] LineString points=${pts.length}');
      return pts.length >= 2 ? [pts] : <List<LatLng>>[];
    }

    print('[NAV] GeoJSON type không hỗ trợ: $type');
    return <List<LatLng>>[];
  }

  // =========================================================
  // 3. Lấy route từ BE -> List<List<LatLng>>
  // =========================================================
  List<List<LatLng>> _extractRouteSegments(Map<String, dynamic> data) {
    print('[NAV] extractRouteSegments keys=${data.keys.toList()}');

    // CASE chính: data['geojson'] là string
    if (data['geojson'] != null) {
      print('[NAV] dùng data.geojson (string)');
      final geojsonStr = data['geojson'] as String;
      return _parseGeoJsonToSegments(geojsonStr);
    }

    // Fallback: nếu sau này BE trả geometry kiểu object
    if (data['geometry'] != null) {
      print('[NAV] dùng geometry (fallback)');
      final geom = data['geometry'] as Map<String, dynamic>;
      final type = geom['type'];
      final coords = geom['coordinates'];

      if (type == 'MultiLineString' && coords is List) {
        final List<List<LatLng>> result = [];
        for (final seg in coords) {
          final segList = seg as List;
          final pts = segList.map<LatLng>((c) {
            final list = c as List;
            final lng = (list[0] as num).toDouble();
            final lat = (list[1] as num).toDouble();
            return LatLng(lat, lng);
          }).toList();
          if (pts.length >= 2) result.add(pts);
        }
        return result;
      }

      if (type == 'LineString' && coords is List) {
        final pts = coords.map<LatLng>((c) {
          final list = c as List;
          final lng = (list[0] as num).toDouble();
          final lat = (list[1] as num).toDouble();
          return LatLng(lat, lng);
        }).toList();
        return pts.length >= 2 ? [pts] : <List<LatLng>>[];
      }
    }

    print('[NAV] Không có geometry / geojson hợp lệ trong response');
    return <List<LatLng>>[];
  }

  // =========================================================
  // 4. Zoom camera fit theo toàn bộ tuyến đường
  // =========================================================
  Future<void> _fitCameraToRoute(List<List<LatLng>> segments) async {
    final allPoints = <LatLng>[];
    for (final seg in segments) {
      allPoints.addAll(seg);
    }
    if (allPoints.isEmpty) return;

    double minLat = allPoints.first.latitude;
    double maxLat = allPoints.first.latitude;
    double minLng = allPoints.first.longitude;
    double maxLng = allPoints.first.longitude;

    for (final p in allPoints) {
      if (p.latitude < minLat) minLat = p.latitude;
      if (p.latitude > maxLat) maxLat = p.latitude;
      if (p.longitude < minLng) minLng = p.longitude;
      if (p.longitude > maxLng) maxLng = p.longitude;
    }

    final bounds = LatLngBounds(
      southwest: LatLng(minLat, minLng),
      northeast: LatLng(maxLat, maxLng),
    );

    print('[NAV] fitCamera: SW=$minLat,$minLng NE=$maxLat,$maxLng');

    // chỉnh padding để zoom gần/xa hơn tuỳ ý
    await mapController.animateCamera(
      CameraUpdate.newLatLngBounds(
        bounds,
        left: 150,
        right: 150,
        top: 200,
        bottom: 200,
      ),
    );
  }

  // =========================================================
  // 5. Public: xoá toàn bộ route hiện có (cho main.dart gọi)
  // =========================================================
  Future<void> clearRoute() async {
    if (_routeLines.isEmpty) return;

    print('[NAV] clearRoute: count=${_routeLines.length}');
    for (final line in _routeLines) {
      try {
        await mapController.removeLine(line);
      } catch (e) {
        print('[NAV] removeLine error: $e');
      }
    }
    _routeLines.clear();
  }

  // =========================================================
  // 6. Gọi API route nội bộ và vẽ lên MapLibre
  // =========================================================
  Future<void> drawInternalRoute(LatLng start, LatLng end) async {
    try {
      // Đúng API:
      // /duong-xa/route?fromLat=...&fromLng=...&toLat=...&toLng=...
      final uri = Uri.parse(
        '$baseUrl/duong-xa/route'
            '?fromLat=${start.latitude}&fromLng=${start.longitude}'
            '&toLat=${end.latitude}&toLng=${end.longitude}',
      );

      print('[NAV] CALL /duong-xa/route: $uri');

      final res = await http.get(uri);
      print('[NAV] RESP /duong-xa/route status=${res.statusCode}');

      if (res.statusCode != 200) {
        throw Exception(
          'Route API error: ${res.statusCode} - ${res.body}',
        );
      }

      final data = jsonDecode(res.body) as Map<String, dynamic>;
      final segments = _extractRouteSegments(data);

      if (segments.isEmpty) {
        throw Exception('Route segments rỗng, không vẽ được');
      }

      // Xoá các line cũ trước khi vẽ line mới
      await clearRoute();

      // Vẽ từng segment
      for (final seg in segments) {
        final line = await mapController.addLine(
          LineOptions(
            geometry: seg,
            lineWidth: 5.5,
            lineOpacity: 1.0,
            lineColor: '#FF0000',
          ),
        );
        _routeLines.add(line);
      }

      await _fitCameraToRoute(segments);

      print('[NAV] INTERNAL ROUTE DRAWN, segments=${segments.length}');
    } catch (e) {
      print('[NAV] drawInternalRoute error: $e');
      // ném ra để main.dart bắt và fallback Google Maps
      rethrow;
    }
  }
}
