// lib/chi_duong.dart
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:url_launcher/url_launcher.dart';

class ChiDuongService {
  final String baseUrl; // VD: http://10.0.2.2:5000
  final MapLibreMapController mapController;

  ChiDuongService({
    required this.baseUrl,
    required this.mapController,
  });

  // ========== 1. Check có nằm trong ranh giới không ==========
  Future<bool> isInsideBoundary(LatLng point) async {
    try {
      final uri = Uri.parse(
        '$baseUrl/ranh-gioi/check'
        '?lat=${point.latitude}&lng=${point.longitude}',
      );

      final res = await http.get(uri);
      if (res.statusCode != 200) return false;

      final data = jsonDecode(res.body) as Map<String, dynamic>;
      return data['inside'] == true;
    } catch (e) {
      // Có lỗi thì coi như ngoài ranh
      // print('isInsideBoundary error: $e');
      return false;
    }
  }

  // ========== 2. Mở Google Maps khi ngoài ranh ==========
  Future<void> openGoogleMapDirection(LatLng start, LatLng end) async {
    final url =
        'https://www.google.com/maps/dir/?api=1'
        '&origin=${start.latitude},${start.longitude}'
        '&destination=${end.latitude},${end.longitude}'
        '&travelmode=walking';

    final uri = Uri.parse(url);

    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      // print('Không mở được Google Maps');
    }
  }

  // ========== 3. Lấy route nội bộ và vẽ lên MapLibre ==========
  Future<void> drawInternalRoute(LatLng start, LatLng end) async {
    try {
      final uri = Uri.parse(
        '$baseUrl/route'
        '?startLat=${start.latitude}&startLng=${start.longitude}'
        '&endLat=${end.latitude}&endLng=${end.longitude}',
      );

      final res = await http.get(uri);
      if (res.statusCode != 200) return;

      final data = jsonDecode(res.body) as Map<String, dynamic>;
      final geom = data['geometry'] as Map<String, dynamic>;

      final coordsRaw = geom['coordinates'] as List;

      final coords = coordsRaw
          .map((c) {
            final list = c as List;
            final lng = (list[0] as num).toDouble();
            final lat = (list[1] as num).toDouble();
            return LatLng(lat, lng);
          })
          .toList();

      // Có thể xoá line cũ nếu muốn, hoặc đặt 1 id riêng
      await mapController.addLine(
        LineOptions(
          geometry: coords,
          lineWidth: 4.0,
          lineColor: '#FF0000',
          lineOpacity: 1.0,
        ),
      );

      // TODO: nếu cần, tính bbox rồi zoom cho đẹp (tuỳ ông)
    } catch (e) {
      // print('drawInternalRoute error: $e');
    }
  }

  // ========== 4. Hàm chính: Chỉ đường ==========
  Future<void> navigateTo({
    required LatLng start,
    required LatLng destination,
  }) async {
    final startInside = await isInsideBoundary(start);
    final endInside = await isInsideBoundary(destination);

    if (!startInside || !endInside) {
      // 1 trong 2 điểm ngoài ranh -> dùng Google Maps
      await openGoogleMapDirection(start, destination);
    } else {
      // Cả 2 đều trong ranh -> chỉ đường nội bộ trên map
      await drawInternalRoute(start, destination);
    }
  }
}
