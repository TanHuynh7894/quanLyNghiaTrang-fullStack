// lib/status_colors.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Quản lý màu theo tình trạng mộ phần.
/// - Endpoint cố định: http://10.0.2.2:5000/tinh-trang-mo-phan
/// - Hỗ trợ dữ liệu dạng List hoặc FeatureCollection.
/// - Ưu tiên dùng field: ma_tinh_trang, color, (tùy API có) ten_tinh_trang.
class StatusColorService {
  static String get _endpoint =>
      '${dotenv.env['BASE_URL'] ?? 'http://10.0.2.2:5000'}/tinh-trang-mo-phan';

  /// id -> #hex
  static Map<String, String> _colorById = {
    // Fallback tối thiểu
    'default': '#e74c3c',
  };

  /// id -> tên hiển thị (nếu API có)
  static Map<String, String> _nameById = {};

  /// Gọi API và nạp vào bộ nhớ
  static Future<void> load() async {
    try {
      final res = await http
          .get(Uri.parse(_endpoint))
          .timeout(const Duration(seconds: 10));

      if (res.statusCode == 200 && res.body.isNotEmpty) {
        final data = jsonDecode(res.body);
        _ingest(data);
      } else {
        // Giữ nguyên fallback
      }
    } catch (_) {
      // Giữ nguyên fallback
    }
  }

  /// Lấy màu từ Feature (đọc properties.mo_phan.ma_tinh_trang)
  static String resolveFromFeature(
    Map<String, dynamic> feature, {
    String fallback = '#e74c3c',
  }) {
    try {
      final props = feature['properties'];
      if (props is Map) {
        final moPhan = props['mo_phan'];
        if (moPhan is Map) {
          final id = moPhan['ma_tinh_trang']?.toString();
          if (id != null && id.isNotEmpty) {
            return resolveById(id, fallback: fallback);
          }
        }
      }
    } catch (_) {}
    return _normalizeHex(fallback);
  }

  /// Lấy màu trực tiếp theo id (ma_tinh_trang)
  static String resolveById(String? id, {String fallback = '#e74c3c'}) {
    if (id != null && _colorById.containsKey(id)) {
      return _normalizeHex(_colorById[id]!);
    }
    // nếu không có id thì trả fallback
    return _normalizeHex(fallback);
  }

  /// Trả legend (id -> {name,color}) nếu API có tên; nếu không, name=null.
  static Map<String, Map<String, String?>> legend() {
    final out = <String, Map<String, String?>>{};
    _colorById.forEach((id, hex) {
      if (id == 'default') return;
      out[id] = {
        'name': _nameById[id],
        'color': _normalizeHex(hex),
      };
    });
    return out;
  }

  // ---------------------- internal helpers ----------------------

  static void _ingest(dynamic data) {
    final nextColor = <String, String>{};
    final nextName = <String, String>{};

    if (data is List) {
      for (final it in data) {
        if (it is Map) {
          final id = it['ma_tinh_trang']?.toString();
          final color = it['color']?.toString();
          if (id != null && color != null) {
            nextColor[id] = _normalizeHex(color);
          }
          final name = it['ten_tinh_trang']?.toString();
          if (id != null && name != null) nextName[id] = name;
        }
      }
    } else if (data is Map && data['type'] == 'FeatureCollection') {
      for (final f in (data['features'] as List? ?? const [])) {
        if (f is Map) {
          final p = f['properties'];
          if (p is Map) {
            final id = p['ma_tinh_trang']?.toString();
            final color = p['color']?.toString();
            if (id != null && color != null) {
              nextColor[id] = _normalizeHex(color);
            }
            final name = p['ten_tinh_trang']?.toString();
            if (id != null && name != null) nextName[id] = name;
          }
        }
      }
    }

    if (nextColor.isNotEmpty) {
      _colorById = nextColor;
      _nameById = nextName;
    }
  }

  static String _normalizeHex(String hex) {
    var s = hex.trim();
    if (!s.startsWith('#')) s = '#$s';
    // chấp nhận #RRGGBB hoặc #RRGGBBAA
    if (s.length == 7 || s.length == 9) return s;
    if (s.length > 9) return s.substring(0, 9);
    if (s.length < 7) return '#e74c3c';
    return s;
  }
}
