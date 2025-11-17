// lib/main.dart
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:geolocator/geolocator.dart'; // NEW: dùng để lấy GPS

import 'status_colors.dart';
import 'map_effects.dart';
import 'o_detail_sheet.dart';
// dùng service flutter_sound + AI intent
import 'audio_note_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load biến môi trường từ .env
  await dotenv.load(fileName: ".env");

  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
  ));

  runApp(const MapApp());
}

class MapApp extends StatelessWidget {
  const MapApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      // Khóa textScaleFactor = 1.0 để UI không vỡ trên máy font to
      builder: (context, child) {
        final data = MediaQuery.of(context);
        return MediaQuery(
          data: data.copyWith(textScaleFactor: 1.0),
          child: child!,
        );
      },
      home: const FullScreenMap(),
    );
  }
}

class FullScreenMap extends StatefulWidget {
  const FullScreenMap({super.key});

  @override
  State<FullScreenMap> createState() => _FullScreenMapState();
}

class _FullScreenMapState extends State<FullScreenMap> {
  // ===== MÀU & OPACITY =====
  static const _NEN_FILL = '#cfcfcf';
  static const _NEN_OUTLINE = '#9a9a9a';
  static const _NEN_OPACITY = 0.75;

  static const _KHU_FILL = '#9bf6ff';
  static const _KHU_OUTLINE = '#0e7a66';
  static const _KHU_OPACITY = 0.35;

  static const _HANG_FILL = '#caffbf';
  static const _HANG_OUTLINE = '#b58d00';
  static const _HANG_OPACITY = 0.38;

  static const _O_OUTLINE = '#8e1b12';
  static const _O_OPACITY = 1.0;

  // ==== CONFIG từ .env ====
  // Nếu thiếu trong .env thì fallback về giá trị cũ
  final String _mapTilerKey =
      dotenv.env['MAPTILER_KEY'] ?? '3suk2GO5O2JgkhGmruDP';
  final String _baseUrl = dotenv.env['BASE_URL'] ?? 'http://10.0.2.2:5000';

  final _searchCtl = TextEditingController();

  MaplibreMapController? _map;
  late final MapEffects fx;
  bool _styleLoaded = false;

  // ===== AUDIO (flutter_sound + AI) =====
  late final AudioNoteServiceFS _audio;
  bool get _isRec => _audio.isRecording;

  // ===== LOCATION BUTTON STATE =====
  bool _locating = false;

  // Layer theo Z-order: nền -> khu -> hàng -> ô
  final List<Fill> _nenFills = [];
  final List<Fill> _khuFills = [];
  final List<Fill> _hangFills = [];
  final List<Fill> _oFills = [];

  // Tra ngược Fill → Feature (để xử lý onFillTapped)
  final Map<Fill, Map<String, dynamic>> _khuMeta = {};
  final Map<Fill, Map<String, dynamic>> _hangMeta = {};
  final Map<Fill, Map<String, dynamic>> _oMeta = {};

  // Dropdown states
  List<String> _khuList = [];
  List<String> _hangList = [];
  List<String> _oList = [];
  String? _khu, _hang, _o;

  // Preset tình trạng
  static const List<Map<String, String>> _STATUS_PRESET = [
    {
      "ma_tinh_trang": "11111111-2222-3333-4444-000000000004",
      "ten_tinh_trang": "Đã bán",
      "color": "#ff9800"
    },
    {
      "ma_tinh_trang": "11111111-2222-3333-4444-000000000005",
      "ten_tinh_trang": "Đã chôn 1 người",
      "color": "#673ab7"
    },
    {
      "ma_tinh_trang": "11111111-2222-3333-4444-000000000006",
      "ten_tinh_trang": "Đã chôn đủ",
      "color": "#f44336"
    },
    {
      "ma_tinh_trang": "11111111-2222-3333-4444-000000000003",
      "ten_tinh_trang": "Hoàn thiện",
      "color": "#00d26a"
    },
    {
      "ma_tinh_trang": "11111111-2222-3333-4444-000000000001",
      "ten_tinh_trang": "Kim Tĩnh",
      "color": "#5b5b5bff"
    },
    {
      "ma_tinh_trang": "11111111-2222-3333-4444-000000000007",
      "ten_tinh_trang": "Trống",
      "color": "#FFFFFF"
    },
    {
      "ma_tinh_trang": "11111111-2222-3333-4444-000000000002",
      "ten_tinh_trang": "Xây thô",
      "color": "#ffe800"
    },
  ];
  List<Map<String, String>> _statusList = [];
  String? _selectedStatusId;

  String get _styleUrl =>
      "https://api.maptiler.com/maps/streets-v2/style.json?key=$_mapTilerKey";

  @override
  void initState() {
    super.initState();
    debugPrint('[INIT] FullScreenMap initState');
    fx = MapEffects(context: context);

    // khởi tạo audio service với baseUrl từ .env
    _audio = AudioNoteServiceFS(baseUrl: _baseUrl);

    // init audio + xin quyền mic
    _audio.init().then((_) {
      debugPrint('[AUDIO] init OK');
    }).catchError((e) {
      debugPrint('[AUDIO] init ERROR: $e');
      _snack('Audio init lỗi: $e');
    });
  }

  // ===================== API (khu/hang/o) =====================
  Future<dynamic> _get(String path, [Map<String, String>? params]) async {
    final base = Uri.parse(_baseUrl);
    final uri = Uri(
      scheme: base.scheme,
      host: base.host,
      port: base.port,
      path: path,
      queryParameters: params,
    );

    debugPrint('[API] GET $uri');

    try {
      final res = await http.get(uri).timeout(const Duration(seconds: 15));
      debugPrint('[API] RESP $path status=${res.statusCode}');
      if (res.statusCode == 200 && res.body.isNotEmpty) {
        return jsonDecode(res.body);
      } else {
        _snack("HTTP ${res.statusCode}: ${res.body}");
      }
    } catch (e) {
      debugPrint('[API] ERROR $path: $e');
      _snack("Lỗi API $path: $e");
    }
    return null;
  }

  Future<dynamic> _getAllKhu() => _get("/khu");
  Future<dynamic> _getAllHang(String khu) => _get("/hang", {"ten_khu": khu});
  Future<dynamic> _getAllO(String khu, String hang) =>
      _get("/o", {"ten_khu": khu, "ten_hang": hang});

  Future<Map<String, dynamic>?> _fetchKhu(String tenKhu) async {
    final data = await _get("/khu", {"ten_khu": tenKhu});
    if (data is Map) return Map<String, dynamic>.from(data);
    return null;
  }

  Future<Map<String, dynamic>?> _fetchHangGeom(
      String khu, String hang) async {
    final data = await _get("/hang", {"ten_khu": khu, "ten_hang": hang});
    if (data is Map) return Map<String, dynamic>.from(data);
    return null;
  }

  Future<Map<String, dynamic>?> _fetchOGeom(
      String khu, String hang, String o) async {
    final data = await _get("/o", {
      "ten_khu": khu,
      "ten_hang": hang,
      "ten_o": o,
    });
    if (data is Map) return Map<String, dynamic>.from(data);
    return null;
  }

  // ====== NẠP PRESET TÌNH TRẠNG ======
  Future<void> _initStatusesFromPreset() async {
    debugPrint('[STATUS] init from preset');
    _statusList = _STATUS_PRESET
        .map((e) => {
              'id': e['ma_tinh_trang'] ?? '',
              'name': e['ten_tinh_trang'] ?? (e['ma_tinh_trang'] ?? ''),
              'color': e['color'] ?? '#cccccc',
            })
        .toList();
    if (mounted) setState(() {});
  }

  // Lọc danh sách Ô theo tình trạng
  dynamic _filterOByStatus(dynamic data) {
    if (_selectedStatusId == null) return data;

    List feats = [];
    if (data is Map && data['type'] == 'FeatureCollection') {
      feats = List.from(data['features'] as List? ?? const []);
    } else if (data is List) {
      feats = List.from(data);
    } else {
      return data;
    }

    final filtered = feats.where((f) {
      if (f is! Map) return false;
      final props = f['properties'];
      if (props is! Map) return false;
      final mo = props['mo_phan'];
      if (mo is! Map) return false;
      final id = mo['ma_tinh_trang']?.toString();
      return id == _selectedStatusId;
    }).toList();

    if (data is Map && data['type'] == 'FeatureCollection') {
      return {'type': 'FeatureCollection', 'features': filtered};
    }
    return filtered;
  }

  // ===================== Tiện ích =====================
  void _snack(String msg) {
    debugPrint('[SNACK] $msg');
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg)),
      );
    }
  }

  Color _hexToColor(String hex) {
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

  // ===================== Drill-down on click =====================
  Future<void> _handleFillTap(Fill f) async {
    debugPrint('[TAP] onFillTapped: $f');

    // Ô -> show info
    if (_oMeta.containsKey(f)) {
      final feat = _oMeta[f]!;
      final props = (feat['properties'] as Map?) ?? {};
      final tenKhu = (props['ten_khu'] ?? _khu)?.toString() ?? '';
      final tenHang = (props['ten_hang'] ?? _hang)?.toString() ?? '';
      final tenO = (props['ten_o'] ?? _o)?.toString() ?? '';

      debugPrint('[TAP] Ô $tenKhu - $tenHang - $tenO');

      final detail = await _get("/o", {
        "ten_khu": tenKhu,
        "ten_hang": tenHang,
        "ten_o": tenO,
      });

      if (!mounted) return;
      if (detail == null) {
        _snack("Không lấy được chi tiết ô.");
        return;
      }
      ODetailSheet.show(context, detail, tenKhu, tenHang, tenO);
      return;
    }

    // Hàng -> load Ô
    if (_hangMeta.containsKey(f)) {
      final feat = _hangMeta[f]!;
      final props = (feat['properties'] as Map?) ?? {};
      final tenHang = props['ten_hang']?.toString();
      final tenKhuFromFeature = props['ten_khu']?.toString();

      final khuToUse = tenKhuFromFeature ?? _khu;
      debugPrint('[TAP] Hàng tenHang=$tenHang khu=$khuToUse');

      if (khuToUse == null || tenHang == null) return;

      await _onSelectKhu(khuToUse);
      await _onSelectHang(tenHang);
      return;
    }

    // Khu -> load Hàng
    if (_khuMeta.containsKey(f)) {
      final feat = _khuMeta[f]!;
      final props = (feat['properties'] as Map?) ?? {};
      final tenKhu = props['ten_khu']?.toString();
      debugPrint('[TAP] Khu tenKhu=$tenKhu');
      if (tenKhu == null) return;
      await _onSelectKhu(tenKhu);
      return;
    }
  }

  // ===================== Logic chọn (dropdown & nội bộ) =====================
  Future<void> _onSelectKhu(String val) async {
    debugPrint('[SELECT] Khu = $val');

    _khu = val;
    _hang = _o = null;
    _hangList = [];
    _oList = [];
    _selectedStatusId = null;
    setState(() {});

    await fx.clearFills(_hangFills);
    await fx.clearFills(_oFills);
    _hangMeta.clear();
    _oMeta.clear();

    final featKhu = await _fetchKhu(val);
    if (featKhu != null) {
      await fx.renderLayer(
        data: featKhu,
        layer: _khuFills,
        outline: _KHU_OUTLINE,
        opacity: _KHU_OPACITY,
        clearBefore: true,
        fitCamera: true,
        colorResolver: (_) => _KHU_FILL,
      );
    }

    final hangData = await _getAllHang(val);
    final metas = await fx.renderLayerWithMeta(
      data: hangData,
      targetLayer: _hangFills,
      outline: _HANG_OUTLINE,
      opacity: _HANG_OPACITY,
      clearBefore: true,
      fitCamera: true,
      colorResolver: (_) => _HANG_FILL,
    );
    _hangMeta
      ..clear()
      ..addEntries(metas.map((m) => MapEntry(m.fill, m.feature)));

    final set = <String>{};
    if (hangData is Map && hangData["features"] is List) {
      for (final f in hangData["features"]) {
        final p = (f is Map) ? f["properties"] : null;
        if (p is Map && p["ten_hang"] != null) {
          set.add(p["ten_hang"].toString());
        }
      }
    }
    _hangList = set.toList()..sort();
    setState(() {});
  }

  Future<void> _onSelectHang(String val) async {
    debugPrint('[SELECT] Hàng = $val');

    _hang = val;
    _o = null;
    _oList = [];
    setState(() {});

    await fx.clearFills(_oFills);
    _oMeta.clear();

    final featHang = await _fetchHangGeom(_khu!, val);
    if (featHang != null) {
      await fx.renderLayer(
        data: featHang,
        layer: _hangFills,
        outline: _HANG_OUTLINE,
        opacity: _HANG_OPACITY,
        clearBefore: false,
        fitCamera: true,
        colorResolver: (_) => _HANG_FILL,
      );
    }

    final oData = await _getAllO(_khu!, val);
    final set = <String>{};
    if (oData is Map && oData["features"] is List) {
      for (final f in oData["features"]) {
        final p = (f is Map) ? f["properties"] : null;
        if (p is Map && p["ten_o"] != null) {
          set.add(p["ten_o"].toString());
        }
      }
    }
    _oList = set.toList()..sort();
    setState(() {});

    if (oData != null) {
      final toDraw =
          (_selectedStatusId == null) ? oData : _filterOByStatus(oData);
      final metas = await fx.renderLayerWithMeta(
        data: toDraw,
        targetLayer: _oFills,
        outline: _O_OUTLINE,
        opacity: _O_OPACITY,
        clearBefore: true,
        fitCamera: false,
        colorResolver: (f) => StatusColorService.resolveFromFeature(f),
      );
      _oMeta
        ..clear()
        ..addEntries(metas.map((m) => MapEntry(m.fill, m.feature)));
    }
  }

  Future<void> _onSelectO(String val) async {
    debugPrint('[SELECT] Ô = $val');

    _o = val;
    setState(() {});
    final featO = await _fetchOGeom(_khu!, _hang!, val);
    if (featO != null) {
      final metas = await fx.renderLayerWithMeta(
        data: featO,
        targetLayer: _oFills,
        outline: _O_OUTLINE,
        opacity: _O_OPACITY,
        clearBefore: true,
        fitCamera: true,
        colorResolver: (f) => StatusColorService.resolveFromFeature(f),
      );
      _oMeta
        ..clear()
        ..addEntries(metas.map((m) => MapEntry(m.fill, m.feature)));

      final detail = await _get("/o", {
        "ten_khu": _khu!,
        "ten_hang": _hang!,
        "ten_o": val,
      });
      if (detail != null) {
        ODetailSheet.show(context, detail, _khu!, _hang!, val);
      }
    }
  }

  // ===================== Helpers cho intent AI =====================
  Map<String, dynamic>? _asProps(dynamic x) {
    if (x is Map && x['properties'] is Map) {
      return Map<String, dynamic>.from(x['properties'] as Map);
    }
    if (x is Map) return Map<String, dynamic>.from(x);
    return null;
  }

  Map<String, String>? _extractKhuHangO(dynamic x) {
    final p = _asProps(x);
    if (p == null) return null;
    final tenKhu = (p['ten_khu'] ?? p['khu'] ?? p['tenKhu'])?.toString();
    final tenHang = (p['ten_hang'] ?? p['hang'] ?? p['tenHang'])?.toString();
    final tenO = (p['ten_o'] ?? p['o'] ?? p['tenO'])?.toString();
    if (tenKhu == null || tenHang == null || tenO == null) return null;
    return {
      'ten_khu': tenKhu,
      'ten_hang': tenHang,
      'ten_o': tenO,
    };
  }

  Map<String, String>? _extractKhuHangOnly(dynamic x) {
    final p = _asProps(x);
    if (p == null) return null;
    final tenKhu = (p['ten_khu'] ?? p['khu'] ?? p['tenKhu'])?.toString();
    final tenHang = (p['ten_hang'] ?? p['hang'] ?? p['tenHang'])?.toString();
    if (tenKhu == null || tenHang == null) return null;
    return {
      'ten_khu': tenKhu,
      'ten_hang': tenHang,
    };
  }

  String? _extractKhuOnly(dynamic x) {
    final p = _asProps(x);
    if (p == null) return null;
    final tenKhu = (p['khu'] ?? p['ten_khu'] ?? p['tenKhu'])?.toString();
    return tenKhu;
  }

  // ===================== Handle intent từ AI =====================
  Future<void> _handleAiIntent(AiJson ai, dynamic beData) async {
    final text = ai.text.trim();
    debugPrint('[AI] intent=${ai.intent} text="$text"');

    if (ai.intent == null) {
      if (text.isNotEmpty) {
        _snack('🤖 Tôi nghe: "$text". Chưa nhận ra yêu cầu.');
      } else {
        _snack('🤖 Không nhận ra yêu cầu.');
      }
      return;
    }

    switch (ai.intent) {
      // ---- O (đầy đủ khu + hàng + ô) ----
      case 'o_ten_nguoi_mat':
      case 'o_dia_chi':
      case 'o_ten':
        {
          final info = _extractKhuHangO(beData);
          if (info == null) {
            _snack('Dữ liệu O không đầy đủ ten_khu/ten_hang/ten_o');
            return;
          }
          final tenKhu = info['ten_khu']!;
          final tenHang = info['ten_hang']!;
          final tenO = info['ten_o']!;

          await _onSelectKhu(tenKhu);
          await _onSelectHang(tenHang);
          await _onSelectO(tenO);
          break;
        }

      // ---- HÀNG (khu + hàng) ----
      case 'hang_dia_chi':
      case 'hang_ten':
        {
          final info = _extractKhuHangOnly(beData);
          if (info == null) {
            _snack('Dữ liệu Hàng không đầy đủ ten_khu/ten_hang');
            return;
          }
          final tenKhu = info['ten_khu']!;
          final tenHang = info['ten_hang']!;

          await _onSelectKhu(tenKhu);
          await _onSelectHang(tenHang);
          break;
        }

      // ---- KHU ----
      case 'khu':
        {
          final tenKhu = _extractKhuOnly(beData);
          if (tenKhu == null) {
            _snack('Dữ liệu Khu không có khu/ten_khu');
            return;
          }
          await _onSelectKhu(tenKhu);
          break;
        }

      // ---- Intent lạ ----
      default:
        {
          if (text.isNotEmpty) {
            _snack(
                '🤖 Tôi nghe: "$text". Intent "${ai.intent}" chưa hỗ trợ.');
          } else {
            _snack('🤖 Intent "${ai.intent}" chưa hỗ trợ.');
          }
        }
    }
  }

  // ===== Mic actions (ghi âm + AI + map) =====
  Future<void> _onMicTap() async {
    try {
      if (!_isRec) {
        debugPrint('[MIC] start recording');
        await _audio.start();
        _snack('Đang ghi: ${_audio.currentName ?? ''}');
        setState(() {});
      } else {
        debugPrint('[MIC] stop & transcribe');
        _snack('Đang xử lý AI...');
        final result = await _audio.stopAndTranscribe();
        _snack('AI xong: ${result.ai.text}');
        await _handleAiIntent(result.ai, result.beData);
        setState(() {});
      }
    } catch (e) {
      debugPrint('[MIC] ERROR: $e');
      _snack('Mic/AI error: $e');
      setState(() {});
    }
  }

  // ====== helper: kiểm tra dịch vụ location ======
  Future<bool> _ensureLocationServiceOn() async {
    final enabled = await Geolocator.isLocationServiceEnabled();
    debugPrint('[LOC] isLocationServiceEnabled = $enabled');
    if (!enabled) {
      _snack('Vui lòng bật GPS / Location trên thiết bị.');
      return false;
    }
    return true;
  }

  // ====== ĐỊNH VỊ VỊ TRÍ HIỆN TẠI ======
  Future<void> _goToMyLocation() async {
    debugPrint('================ [LOC] goToMyLocation START ================');

    if (_map == null) {
      debugPrint('[LOC] map controller is null');
      _snack('Bản đồ chưa sẵn sàng');
      return;
    }
    if (_locating) {
      debugPrint('[LOC] đang định vị, bỏ qua click mới');
      return;
    }

    setState(() => _locating = true);

    try {
      // 1. Xin quyền location (whenInUse)
      var status = await Permission.locationWhenInUse.status;
      debugPrint('[LOC] permission BEFORE request = $status');

      if (status.isDenied ||
          status.isRestricted ||
          status.isPermanentlyDenied) {
        status = await Permission.locationWhenInUse.request();
        debugPrint('[LOC] permission AFTER request = $status');
      }

      if (!status.isGranted) {
        _snack('Bạn cần cấp quyền vị trí để dùng chức năng này.');
        return;
      }

      // 2. Kiểm tra GPS có bật chưa
      if (!await _ensureLocationServiceOn()) {
        // _ensureLocationServiceOn đã show snack rồi
        return;
      }

      // 3. Lấy vị trí hiện tại bằng Geolocator
      debugPrint('[LOC] call Geolocator.getCurrentPosition');
      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.best,
      );
      debugPrint(
          '[LOC] current position = (${pos.latitude}, ${pos.longitude}), acc=${pos.accuracy}');

      final target = LatLng(pos.latitude, pos.longitude);

      // 4. Zoom camera về vị trí hiện tại
      debugPrint('[LOC] animateCamera to current position');
      await _map!.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(target: target, zoom: 18),
        ),
      );

      debugPrint('================ [LOC] goToMyLocation DONE ================');
    } on PermissionDeniedException catch (e) {
      debugPrint('[LOC] PermissionDeniedException: $e');
      _snack('Quyền vị trí bị từ chối.');
    } on LocationServiceDisabledException catch (e) {
      debugPrint('[LOC] LocationServiceDisabledException: $e');
      _snack('Dịch vụ vị trí đang tắt. Vui lòng bật GPS.');
    } on PlatformException catch (e) {
      debugPrint('[LOC] PlatformException: code=${e.code}, '
          'msg=${e.message}, details=${e.details}');
      _snack('Lỗi định vị (native): '
          '${e.message ?? (e.code.isNotEmpty ? e.code : 'Không rõ nguyên nhân')}');
    } catch (e) {
      debugPrint('[LOC] UNKNOWN ERROR: $e');
      _snack('Lỗi định vị: $e');
    } finally {
      if (mounted) {
        setState(() => _locating = false);
      }
    }
  }

  // ===================== UI helpers =====================
  bool get _khuEnabled => _khuList.isNotEmpty;
  bool get _hangEnabled => _khu != null && _hangList.isNotEmpty;
  bool get _oEnabled => _hang != null && _oList.isNotEmpty;
  bool get _statusEnabled => _hang != null;

  Widget _dimIfDisabled({required bool enabled, required Widget child}) {
    return Opacity(opacity: enabled ? 1.0 : 0.45, child: child);
  }

  Widget _ddWrapper(Widget child) {
    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.92),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(168),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Hàng 1: menu + search + mic
                Row(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.9),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.08),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.menu, color: Colors.black87),
                        onPressed: () => _snack("Menu pressed!"),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Container(
                        height: 44,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.92),
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.08),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            const SizedBox(width: 8),
                            Expanded(
                              child: TextField(
                                controller: _searchCtl,
                                onSubmitted: (_) async {
                                  final txt = _searchCtl.text.trim();
                                  if (txt.isEmpty) return;
                                  final data = await _fetchKhu(txt);
                                  if (data != null) {
                                    await fx.renderLayer(
                                      data: data,
                                      layer: _khuFills,
                                      outline: _KHU_OUTLINE,
                                      opacity: _KHU_OPACITY,
                                      clearBefore: true,
                                      fitCamera: true,
                                      colorResolver: (_) => _KHU_FILL,
                                    );
                                  }
                                },
                                decoration: const InputDecoration(
                                  hintText: "Nhập tên khu…",
                                  hintStyle: TextStyle(color: Colors.black54),
                                  border: InputBorder.none,
                                  contentPadding: EdgeInsets.symmetric(
                                    vertical: 12,
                                    horizontal: 20,
                                  ),
                                ),
                              ),
                            ),
                            IconButton(
                              onPressed: () async {
                                final txt = _searchCtl.text.trim();
                                if (txt.isEmpty) return;
                                final data = await _fetchKhu(txt);
                                if (data != null) {
                                  await fx.renderLayer(
                                    data: data,
                                    layer: _khuFills,
                                    outline: _KHU_OUTLINE,
                                    opacity: _KHU_OPACITY,
                                    clearBefore: true,
                                    fitCamera: true,
                                    colorResolver: (_) => _KHU_FILL,
                                  );
                                }
                              },
                              icon:
                                  const Icon(Icons.search, color: Colors.teal),
                              tooltip: 'Tìm khu',
                            ),
                            IconButton(
                              onPressed: _onMicTap,
                              icon:
                                  Icon(_isRec ? Icons.stop_circle : Icons.mic),
                              color: _isRec
                                  ? Colors.redAccent
                                  : Colors.black87,
                              tooltip: _isRec
                                  ? 'Dừng & gửi AI'
                                  : 'Ghi chú giọng nói',
                            ),
                            const SizedBox(width: 8),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // Hàng 2: 3 dropdown khu/hàng/ô
                Row(
                  children: [
                    Expanded(
                      child: _dimIfDisabled(
                        enabled: _khuEnabled,
                        child: _ddWrapper(
                          DropdownButtonHideUnderline(
                            child: DropdownButton<String?>(
                              isDense: true,
                              isExpanded: true,
                              value: _khu,
                              hint: const Text(
                                "Chọn khu",
                                style: TextStyle(fontSize: 14),
                              ),
                              items: _khuList
                                  .map(
                                    (e) => DropdownMenuItem<String?>(
                                      value: e,
                                      child: Text(
                                        e,
                                        style:
                                            const TextStyle(fontSize: 14),
                                      ),
                                    ),
                                  )
                                  .toList(),
                              onChanged:
                                  _khuEnabled ? (v) => _onSelectKhu(v!) : null,
                              icon: const Icon(Icons.arrow_drop_down),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _dimIfDisabled(
                        enabled: _hangEnabled,
                        child: _ddWrapper(
                          DropdownButtonHideUnderline(
                            child: DropdownButton<String?>(
                              isDense: true,
                              isExpanded: true,
                              value: _hang,
                              hint: const Text(
                                "Chọn hàng",
                                style: TextStyle(fontSize: 14),
                              ),
                              items: _hangList
                                  .map(
                                    (e) => DropdownMenuItem<String?>(
                                      value: e,
                                      child: Text(
                                        e,
                                        style:
                                            const TextStyle(fontSize: 14),
                                      ),
                                    ),
                                  )
                                  .toList(),
                              onChanged:
                                  _hangEnabled ? (v) => _onSelectHang(v!) : null,
                              icon: const Icon(Icons.arrow_drop_down),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _dimIfDisabled(
                        enabled: _oEnabled,
                        child: _ddWrapper(
                          DropdownButtonHideUnderline(
                            child: DropdownButton<String?>(
                              isDense: true,
                              isExpanded: true,
                              value: _o,
                              hint: const Text(
                                "Chọn ô",
                                style: TextStyle(fontSize: 14),
                              ),
                              items: _oList
                                  .map(
                                    (e) => DropdownMenuItem<String?>(
                                      value: e,
                                      child: Text(
                                        e,
                                        style:
                                            const TextStyle(fontSize: 14),
                                      ),
                                    ),
                                  )
                                  .toList(),
                              onChanged:
                                  _oEnabled ? (v) => _onSelectO(v!) : null,
                              icon: const Icon(Icons.arrow_drop_down),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 8),

                // Hàng 3: dropdown TÌNH TRẠNG
                Row(
                  children: [
                    Expanded(
                      child: _dimIfDisabled(
                        enabled: _statusEnabled,
                        child: _ddWrapper(
                          DropdownButtonHideUnderline(
                            child: DropdownButton<String?>(
                              isDense: true,
                              isExpanded: true,
                              value: _selectedStatusId,
                              hint: const Text(
                                "Lọc theo tình trạng mộ phần",
                                style: TextStyle(fontSize: 14),
                              ),
                              items: [
                                const DropdownMenuItem<String?>(
                                  value: null,
                                  child: Text(
                                    "— Tất cả tình trạng —",
                                    style: TextStyle(fontSize: 14),
                                  ),
                                ),
                                ..._statusList.map((it) {
                                  final id = it['id']!;
                                  final name = it['name'] ?? id;
                                  final color = it['color'] ?? '#cccccc';
                                  return DropdownMenuItem<String?>(
                                    value: id,
                                    child: Row(
                                      children: [
                                        Container(
                                          width: 12,
                                          height: 12,
                                          margin:
                                              const EdgeInsets.only(right: 8),
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            border: Border.all(
                                                color: Colors.black12),
                                            color: _hexToColor(color),
                                          ),
                                        ),
                                        Flexible(
                                          child: Text(
                                            name,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                                fontSize: 14),
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                }),
                              ],
                              onChanged: _statusEnabled
                                  ? (v) async {
                                      setState(
                                          () => _selectedStatusId = v);
                                      if (_khu != null && _hang != null) {
                                        final oData =
                                            await _getAllO(_khu!, _hang!);
                                        if (oData != null) {
                                          final toDraw =
                                              (_selectedStatusId == null)
                                                  ? oData
                                                  : _filterOByStatus(oData);
                                          final metas =
                                              await fx.renderLayerWithMeta(
                                            data: toDraw,
                                            targetLayer: _oFills,
                                            outline: _O_OUTLINE,
                                            opacity: _O_OPACITY,
                                            clearBefore: true,
                                            fitCamera: false,
                                            colorResolver: (f) =>
                                                StatusColorService
                                                    .resolveFromFeature(f),
                                          );
                                          _oMeta
                                            ..clear()
                                            ..addEntries(metas.map((m) =>
                                                MapEntry(m.fill, m.feature)));
                                        }
                                      }
                                    }
                                  : null,
                              icon: const Icon(Icons.arrow_drop_down),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
      body: Stack(
        children: [
          MaplibreMap(
            styleString: _styleUrl,
            initialCameraPosition: const CameraPosition(
              target: LatLng(11.18032, 106.64732),
              zoom: 17,
            ),
            compassEnabled: false,
            myLocationEnabled:
                true, // chỉ để hiện chấm xanh, không dùng để lấy vị trí
            onMapCreated: (c) {
              debugPrint('[MAP] onMapCreated');
              _map = c;
              fx.controller = c;
              _map!.onFillTapped.add(_handleFillTap);
            },
            onStyleLoadedCallback: () async {
              debugPrint('[MAP] onStyleLoaded');
              _styleLoaded = true;
              await StatusColorService.load();

              final allKhu = await _getAllKhu();
              if (allKhu != null) {
                final metas = await fx.renderLayerWithMeta(
                  data: allKhu,
                  targetLayer: _nenFills,
                  outline: _NEN_OUTLINE,
                  opacity: _NEN_OPACITY,
                  clearBefore: true,
                  fitCamera: true,
                  colorResolver: (_) => _NEN_FILL,
                );
                _khuMeta
                  ..clear()
                  ..addEntries(
                      metas.map((m) => MapEntry(m.fill, m.feature)));
              }

              await _initStatusesFromPreset();

              final set = <String>{};
              if (allKhu is Map && allKhu["features"] is List) {
                for (final f in allKhu["features"]) {
                  final p = (f is Map) ? f["properties"] : null;
                  if (p is Map && p["ten_khu"] != null) {
                    set.add(p["ten_khu"].toString());
                  }
                }
              }
              _khuList = set.toList()..sort();
              setState(() {});
            },
          ),

          // ====== NÚT ĐỊNH VỊ Ở GÓC DƯỚI PHẢI ======
          Positioned(
            right: 16,
            bottom: 24,
            child: FloatingActionButton(
              heroTag: 'locate_me',
              mini: true,
              onPressed: _locating ? null : _goToMyLocation,
              backgroundColor:
                  _locating ? Colors.grey : Colors.white,
              child: _locating
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.my_location, color: Colors.black87),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    debugPrint('[DISPOSE] FullScreenMap dispose');
    _map?.onFillTapped.remove(_handleFillTap);
    _searchCtl.dispose();
    _audio.dispose();
    super.dispose();
  }
}
