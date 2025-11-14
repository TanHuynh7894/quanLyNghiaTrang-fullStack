// lib/audio_note_service.dart
import 'dart:io';
import 'dart:convert';

import 'package:flutter_sound/flutter_sound.dart'
    show FlutterSoundRecorder, Codec;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:http/http.dart' as http;

// ====== Kiểu dữ liệu giống bên Angular ======

class AiJson {
  final String text;
  final String? intent; // 'o_ten_nguoi_mat' | 'o_dia_chi' | 'o_ten' | ...
  final String? beUrl;
  final Map<String, dynamic>? params;

  AiJson({
    required this.text,
    this.intent,
    this.beUrl,
    this.params,
  });

  factory AiJson.fromMap(Map<String, dynamic> m) {
    return AiJson(
      text: (m['text'] ?? '').toString(),
      intent: m['intent']?.toString(),
      beUrl: m['be_url']?.toString(),
      params: (m['params'] is Map)
          ? Map<String, dynamic>.from(m['params'] as Map)
          : null,
    );
  }
}

class AiCallResult {
  final AiJson ai;
  final dynamic beData; // Feature hoặc object phẳng

  AiCallResult({
    required this.ai,
    this.beData,
  });
}

// ====== Service chính ======

class AudioNoteServiceFS {
  AudioNoteServiceFS({String? baseUrl})
      : _baseUrl = baseUrl ?? 'http://10.0.2.2:5000';

  final String _baseUrl;
  final FlutterSoundRecorder _recorder = FlutterSoundRecorder();

  bool _inited = false;
  bool _isRecording = false;
  String? _currentPath;
  String? _currentName;

  bool get isRecording => _isRecording;
  String? get currentName => _currentName;

  // Đặt tên file .m4a
  static String _genName() =>
      'mb_${DateTime.now().millisecondsSinceEpoch}.m4a';

  // Khởi tạo recorder + xin quyền
  Future<void> init() async {
    if (_inited) return;

    final mic = await Permission.microphone.request();
    if (!mic.isGranted) {
      throw Exception('Thiếu quyền micro');
    }

    await _recorder.openRecorder();
    await _recorder.setSubscriptionDuration(
      const Duration(milliseconds: 50),
    );

    _inited = true;
  }

  // Bắt đầu ghi
  Future<void> start() async {
    if (!_inited) await init();
    if (_isRecording) return;

    final dir = await getTemporaryDirectory();
    _currentName = _genName();
    _currentPath = '${dir.path}${Platform.pathSeparator}${_currentName!}';

    await _recorder.startRecorder(
      toFile: _currentPath!,
      codec: Codec.aacMP4,   // -> file .m4a chuẩn
      sampleRate: 16000,
      numChannels: 1,
    );

    _isRecording = true;
  }

  // ============ HÀM CŨ: Dừng ghi + chỉ upload (giữ lại nếu cần debug) ============
  Future<String> stopAndUpload() async {
    if (!_isRecording) {
      throw Exception('Chưa bắt đầu ghi');
    }

    final stoppedPath = await _recorder.stopRecorder();
    _isRecording = false;

    final path = stoppedPath ?? _currentPath;
    final name = _currentName;
    _currentPath = null;
    _currentName = null;

    if (path == null || name == null) {
      throw Exception('Không có file để upload');
    }

    final f = File(path);
    final exists = await f.exists();
    final len = exists ? await f.length() : 0;

    if (!exists || len < 1000) {
      return 'File audio quá nhỏ (len=$len bytes), kiểm tra lại ghi âm';
    }

    final url = Uri.parse('$_baseUrl/voice-notes/upload');
    final req = http.MultipartRequest('POST', url)
      ..files.add(
        await http.MultipartFile.fromPath(
          'file',
          path,
          filename: name,
        ),
      );

    final resp = await req.send();
    final body = await resp.stream.bytesToString();

    if (resp.statusCode >= 200 && resp.statusCode < 300) {
      return 'Upload OK: $name';
    } else {
      return 'Upload lỗi (${resp.statusCode}): $body';
    }
  }

  // ============ HÀM MỚI: Dừng ghi + upload + AI + proxy ============

  Future<AiCallResult> stopAndTranscribe() async {
    if (!_isRecording) {
      throw Exception('Chưa bắt đầu ghi');
    }

    final stoppedPath = await _recorder.stopRecorder();
    _isRecording = false;

    final path = stoppedPath ?? _currentPath;
    final name = _currentName;
    _currentPath = null;
    _currentName = null;

    if (path == null || name == null) {
      throw Exception('Không có file để upload');
    }

    final f = File(path);
    final exists = await f.exists();
    final len = exists ? await f.length() : 0;

    if (!exists || len < 1000) {
      throw Exception('File audio quá nhỏ (len=$len bytes)');
    }

    // 1) UPLOAD
    final uploadUrl = Uri.parse('$_baseUrl/voice-notes/upload');
    final upReq = http.MultipartRequest('POST', uploadUrl)
      ..files.add(
        await http.MultipartFile.fromPath(
          'file',
          path,
          filename: name,
        ),
      );
    final upResp = await upReq.send();
    final upBody = await upResp.stream.bytesToString();

    if (upResp.statusCode < 200 || upResp.statusCode >= 300) {
      throw Exception('Upload lỗi (${upResp.statusCode}): $upBody');
    }

    final upJson = jsonDecode(upBody);
    final filename = _extractFilename(upJson);
    if (filename == null) {
      throw Exception('Upload OK nhưng không lấy được filename');
    }

    // 2) TRANSCRIBE
    final trUrl = Uri.parse('$_baseUrl/voice-notes/transcribe');
    final trResp = await http.post(
      trUrl,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'filename': filename}),
    );
    if (trResp.statusCode < 200 || trResp.statusCode >= 300) {
      throw Exception('Transcribe HTTP ${trResp.statusCode}: ${trResp.body}');
    }

    final trJson = jsonDecode(trResp.body);
    if (trJson is! Map || trJson['ok'] != true || trJson['data'] == null) {
      throw Exception('Transcribe thất bại: $trJson');
    }

    final ai = AiJson.fromMap(trJson['data'] as Map<String, dynamic>);
    dynamic beData = trJson['result'];

    // 3) FALLBACK PROXY nếu chưa có result mà có be_url
    if (beData == null && ai.beUrl != null) {
      final proxyUrl = Uri.parse('$_baseUrl/voice-notes/proxy')
          .replace(queryParameters: {'url': ai.beUrl!});
      final proxyResp = await http.get(proxyUrl);
      if (proxyResp.statusCode == 200 && proxyResp.body.isNotEmpty) {
        final proxyJson = jsonDecode(proxyResp.body);
        if (proxyJson is Map && proxyJson['ok'] == true) {
          beData = proxyJson['data'];
        }
      }
    }

    return AiCallResult(ai: ai, beData: beData);
  }

  String? _extractFilename(dynamic resp) {
    // dạng cũ: { ok: true, filename: 'xxx.wav' }
    if (resp is Map &&
        resp['ok'] == true &&
        resp['filename'] != null) {
      return resp['filename'].toString();
    }

    // dạng mới: { file_url: 'http://.../media/xxx.wav' }
    if (resp is Map && resp['file_url'] is String) {
      final seg = (resp['file_url'] as String)
          .split('/')
          .where((e) => e.isNotEmpty)
          .toList();
      return seg.isNotEmpty ? seg.last : null;
    }
    return null;
  }

  // Giải phóng recorder
  Future<void> dispose() async {
    try {
      if (_isRecording) {
        await _recorder.stopRecorder();
      }
    } finally {
      await _recorder.closeRecorder();
      _isRecording = false;
      _inited = false;
      _currentPath = null;
      _currentName = null;
    }
  }
}
