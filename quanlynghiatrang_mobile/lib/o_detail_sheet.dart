// lib/o_detail_sheet.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'status_colors.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:url_launcher/url_launcher.dart';

class ODetailSheet {
  static final String _mediaBase =
      '${dotenv.env['BASE_URL'] ?? 'http://10.0.2.2:5000'}/media';

  /// Tỉ lệ chiều cao sheet so với màn hình (0.5 = 50%)
  static const double kSheetHeightFactor = 0.90; // chỉnh cao/thấp ở đây

  static void show(
    BuildContext context,
    dynamic detail,
    String tenKhu,
    String tenHang,
    String tenO,
  ) {
    final props = _extractProperties(detail);
    final mo    = (props['mo_phan'] as Map?)?.cast<String, dynamic>() ?? {};

    // ===== Mapping theo yêu cầu =====
    final maDisplay = (props['dia_chi'] ?? '').toString().trim().isNotEmpty
        ? props['dia_chi'].toString().trim()
        : '$tenKhu-$tenHang-$tenO';
    final loaiMo    = (mo['ten_kieu_mo'] ?? '').toString().trim();
    final trangThai = (mo['ten_tinh_trang'] ?? mo['tinh_trang'])?.toString() ?? '';
    final giaTri    = _formatVnd(mo['gia_tri']);

    // URL ảnh (đọc từ properties.hinh_anh_mo_phan, hỗ trợ nhiều format)
    final imgUrls = _imageFiles(props, tenKhu, tenHang, tenO);

    final statusColor = _statusColorFromMo(mo);

    // ===== Toạ độ mộ (nếu có) =====
    double? lat = _pickDouble(props, ['lat', 'latitude', 'vi_do']);
    double? lng = _pickDouble(props, ['lng', 'lon', 'long', 'longitude', 'kinh_do']);

    // Nếu chưa có trong props thì lấy từ geometry (GeoJSON Polygon / MultiPolygon)
    if ((lat == null || lng == null) && detail is Map && detail['geometry'] is Map) {
      final geom = detail['geometry'] as Map;
      final coords = geom['coordinates'];

      if (coords is List && coords.isNotEmpty) {
        // MultiPolygon: [[[ [lng, lat], ... ]]]
        // Polygon: [[ [lng, lat], ... ]]
        dynamic level1 = coords[0];
        dynamic level2;
        dynamic point;

        if (level1 is List && level1.isNotEmpty) {
          level2 = level1[0];
          if (level2 is List && level2.isNotEmpty) {
            point = level2[0];
          }
        }

        if (point is List && point.length >= 2) {
          final lngFromGeom = _toDouble(point[0]);
          final latFromGeom = _toDouble(point[1]);
          lng ??= lngFromGeom;
          lat ??= latFromGeom;
        }
      }
    }

    final bool hasLocation = lat != null && lng != null;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return SafeArea(
          top: false,
          child: FractionallySizedBox( // khống chế chiều cao
            heightFactor: kSheetHeightFactor,
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFFdfe9f3), Color(0xFF9ec1cf)],
                ),
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 8)],
              ),
              child: Column(
                children: [
                  // ===== Header cố định (luôn dính trên) =====
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 18, 12, 12),
                    child: Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'Chi tiết dự án',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              shadows: [Shadow(color: Colors.black26, blurRadius: 4)],
                            ),
                          ),
                        ),
                        InkWell(
                          onTap: () => Navigator.pop(context),
                          borderRadius: BorderRadius.circular(999),
                          child: Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: Colors.transparent,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.close, size: 18, color: Colors.black87),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // ===== Nội dung cuộn =====
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.only(bottom: 12),
                      children: [
                        // Mã + Loại
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Row(
                            children: [
                              Expanded(child: _InfoPill(label: 'Mã', value: maDisplay)),
                              const SizedBox(width: 12),
                              Expanded(child: _InfoPill(label: 'Loại', value: loaiMo.isEmpty ? '—' : loaiMo)),
                            ],
                          ),
                        ),
                        const SizedBox(height: 10),

                        // Trạng thái
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: _InfoPill(
                            label: 'Trạng thái',
                            value: trangThai.isEmpty ? '—' : trangThai,
                            badgeColor: statusColor.withOpacity(0.2),
                            borderColor: statusColor.withOpacity(0.5),
                            textColor: statusColor.darken(0.2),
                          ),
                        ),
                        const SizedBox(height: 10),

                        // Giá trị
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: _InfoPill(label: 'Giá', value: giaTri ?? '—'),
                        ),
                        const SizedBox(height: 14),

                        // Carousel 16:9 với 2 nút mũi tên
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(14),
                            child: AspectRatio(
                              aspectRatio: 16 / 9,
                              child: _ImageCarousel(imgUrls: imgUrls),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // CTA (giữ nguyên)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                          child: SizedBox(
                            width: double.infinity,
                            height: 48,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.white.withOpacity(0.9),
                                foregroundColor: Colors.black87,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  side: const BorderSide(color: Color(0xFFd0d7de)),
                                ),
                              ),
                              onPressed: () => Navigator.pop(context),
                              child: const Text(
                                'ĐẶT MUA NGAY',
                                style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: 1.2),
                              ),
                            ),
                          ),
                        ),

                        // NÚT MỚI: CHỈ ĐƯỜNG TỚI MỘ
                        Padding(
                          padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
                          child: SizedBox(
                            width: double.infinity,
                            height: 44,
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: hasLocation
                                    ? Colors.teal
                                    : Colors.grey.shade400,
                                foregroundColor: Colors.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              onPressed: hasLocation
                                  ? () => _openDirection(context, lat!, lng!)
                                  : null,
                              icon: const Icon(Icons.directions),
                              label: Text(
                                hasLocation
                                    ? 'CHỈ ĐƯỜNG TỚI MỘ'
                                    : 'KHÔNG CÓ TOẠ ĐỘ ĐỂ CHỈ ĐƯỜNG',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 1.0,
                                ),
                              ),
                            ),
                          ),
                        ),

                        // Debug JSON (mở rộng khi cần)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: ExpansionTile(
                            tilePadding: EdgeInsets.zero,
                            title: const Text('Xem JSON gốc', style: TextStyle(fontWeight: FontWeight.w600)),
                            children: [
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade50,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: Colors.black12),
                                ),
                                child: SingleChildScrollView(
                                  scrollDirection: Axis.horizontal,
                                  child: SelectableText(
                                    const JsonEncoder.withIndent('  ').convert(detail),
                                    style: const TextStyle(fontFamily: 'monospace', fontSize: 12.5),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // ================= Helpers (data) =================
  static Map<String, dynamic> _extractProperties(dynamic detail) {
    if (detail is Map) {
      if (detail['type'] == 'Feature') {
        return (detail['properties'] as Map?)?.cast<String, dynamic>() ?? {};
      }
      if (detail['type'] == 'FeatureCollection') {
        final feats = (detail['features'] as List?) ?? const [];
        if (feats.isNotEmpty && feats.first is Map) {
          return ((feats.first as Map)['properties'] as Map?)?.cast<String, dynamic>() ?? {};
        }
      }
      if (detail['properties'] is Map) {
        return (detail['properties'] as Map).cast<String, dynamic>();
      }
    }
    return {};
  }

  /// Trả về **danh sách URL ảnh** từ `properties.hinh_anh_mo_phan`.
  /// Hỗ trợ:
  /// - String: "a.jpg,b.jpg"
  /// - List<String>
  /// - List<Map> với key ưu tiên: hinh_anh, file, url, name
  static List<String> _imageFiles(
    Map<String, dynamic> props, String khu, String hang, String o,
  ) {
    final raw = props['hinh_anh_mo_phan'];
    final List<String> out = [];

    void addOne(String s) {
      final v = s.trim();
      if (v.isEmpty) return;
      if (v.startsWith('http://') || v.startsWith('https://')) {
        out.add(v);
      } else {
        out.add('$_mediaBase/${Uri.encodeComponent(v)}');
      }
    }

    if (raw is String && raw.trim().isNotEmpty) {
      // Ví dụ: "6.3-6-15_1.jpg, 6.3-6-15_2.jpg;6.3-6-15_3.jpg"
      raw.split(RegExp(r'[,\s;]+')).forEach(addOne);
    } else if (raw is List) {
      for (final it in raw) {
        if (it is String) addOne(it);
        if (it is Map) {
          // Dạng bạn cung cấp: [{"hinh_anh":"6.3-6-15_1.jpg"}, ...]
          final f = (it['hinh_anh'] ?? it['file'] ?? it['url'] ?? it['name'])?.toString();
          if (f != null) addOne(f);
        }
      }
    }

    // Fallback nếu API không có ảnh -> theo địa chỉ mộ
    if (out.isEmpty) addOne('${khu}-${hang}-${o}_1.jpg');

    return out;
  }

  static String? _formatVnd(dynamic v) {
    if (v == null) return null;
    try {
      final n = (v is num) ? v.toInt() : int.parse(v.toString());
      final s = n.toString();
      final buf = StringBuffer();
      final len = s.length;
      for (int i = 0; i < len; i++) {
        buf.write(s[i]);
        final left = len - i - 1;
        if (left > 0 && left % 3 == 0) buf.write('.');
      }
      return '${buf.toString()} ₫';
    } catch (_) {
      return v.toString();
    }
  }

  static Color _statusColorFromMo(Map<String, dynamic> mo) {
    try {
      final hex = StatusColorService.resolveFromFeature({'properties': {'mo_phan': mo}});
      return _hexToColor(hex);
    } catch (_) {
      return Colors.grey.shade500;
    }
  }

  static Color _hexToColor(String hex) {
    var s = hex.trim();
    if (!s.startsWith('#')) s = '#$s';
    if (s.length == 7) {
      return Color(int.parse('FF${s.substring(1)}', radix: 16));
    } else if (s.length == 9) {
      final rrggbb = s.substring(1, 7);
      final aa = s.substring(7, 9);
      return Color(int.parse('$aa$rrggbb', radix: 16));
    }
    return const Color(0xFFCCCCCC);
  }

  // ===== Helpers chỉ đường =====
  static double? _toDouble(dynamic v) {
    if (v == null) return null;
    if (v is double) return v;
    if (v is int) return v.toDouble();
    return double.tryParse(v.toString());
  }

  static double? _pickDouble(Map<String, dynamic> props, List<String> keys) {
    for (final k in keys) {
      if (props.containsKey(k)) {
        final d = _toDouble(props[k]);
        if (d != null) return d;
      }
    }
    return null;
  }

  static Future<void> _openDirection(
      BuildContext context, double lat, double lng) async {
    final uri = Uri.parse(
      'https://www.google.com/maps/dir/?api=1&destination=$lat,$lng',
    );
    final ok = await launchUrl(
      uri,
      mode: LaunchMode.externalApplication,
    );
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Không mở được ứng dụng bản đồ')),
      );
    }
  }
}

// ================= Widgets =================

class _InfoPill extends StatelessWidget {
  const _InfoPill({
    required this.label,
    required this.value,
    this.badgeColor,
    this.borderColor,
    this.textColor,
  });

  final String label;
  final String value;
  final Color? badgeColor;
  final Color? borderColor;
  final Color? textColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: (badgeColor ?? Colors.black.withOpacity(0.15)),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor ?? Colors.white30),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(label, style: TextStyle(fontSize: 12, color: (textColor ?? Colors.white).withOpacity(0.9))),
          const SizedBox(height: 2),
          Text(
            value.isEmpty ? '—' : value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: textColor ?? Colors.white,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}

class _ImageCarousel extends StatefulWidget {
  const _ImageCarousel({required this.imgUrls});
  final List<String> imgUrls;

  @override
  State<_ImageCarousel> createState() => _ImageCarouselState();
}

class _ImageCarouselState extends State<_ImageCarousel> {
  late final PageController _ctl;
  int _index = 0;

  @override
  void initState() {
    super.initState();
    _ctl = PageController(keepPage: true, initialPage: 0);
  }

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  void _go(int newIndex) {
    if (!_ctl.hasClients) return;
    final len = widget.imgUrls.isEmpty ? 1 : widget.imgUrls.length;
    final target = (newIndex % len + len) % len; // wrap vòng
    _ctl.animateToPage(
      target,
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeOut,
    );
  }

  void _prev() => _go(_index - 1);
  void _next() => _go(_index + 1);

  @override
  Widget build(BuildContext context) {
    final itemCount = widget.imgUrls.isEmpty ? 1 : widget.imgUrls.length;

    return Material(
      type: MaterialType.transparency,
      child: Stack(
        fit: StackFit.expand,
        children: [
          PageView.builder(
            controller: _ctl,
            onPageChanged: (i) => setState(() => _index = i),
            itemCount: itemCount,
            itemBuilder: (_, i) {
              final url = widget.imgUrls.isEmpty ? '' : widget.imgUrls[i];
              if (url.isEmpty) {
                return Container(color: Colors.grey.shade200);
              }
              return Image.network(
                url,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  color: Colors.grey.shade200,
                  alignment: Alignment.center,
                  child: const Text('Không tải được ảnh'),
                ),
              );
            },
          ),

          // Nút trái
          Positioned(
            left: 10,
            top: 0,
            bottom: 0,
            child: Center(
              child: Material(
                color: Colors.transparent,
                shape: const CircleBorder(),
                child: IconButton(
                  onPressed: _prev,
                  icon: const Icon(Icons.chevron_left, size: 36, color: Colors.black87),
                  constraints: const BoxConstraints.tightFor(width: 60, height: 60),
                  padding: EdgeInsets.zero,
                  splashRadius: 26,
                ),
              ),
            ),
          ),

          // Nút phải
          Positioned(
            right: 10,
            top: 0,
            bottom: 0,
            child: Center(
              child: Material(
                color: Colors.transparent,
                shape: const CircleBorder(),
                child: IconButton(
                  onPressed: _next,
                  icon: const Icon(Icons.chevron_right, size: 36, color: Colors.black87),
                  constraints: const BoxConstraints.tightFor(width: 60, height: 60),
                  padding: EdgeInsets.zero,
                  splashRadius: 26,
                ),
              ),
            ),
          ),

          // Chỉ số ảnh
          if (itemCount > 1)
            Positioned(
              bottom: 8,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    "${_index + 1}/$itemCount",
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

extension _ColorX on Color {
  Color darken([double amount = .1]) {
    final hsl = HSLColor.fromColor(this);
    final h = hsl.withLightness((hsl.lightness - amount).clamp(0.0, 1.0));
    return h.toColor();
  }
}
