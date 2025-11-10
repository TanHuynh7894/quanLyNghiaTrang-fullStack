// lib/audio_note_service.dart
import 'dart:io';

import 'package:flutter_sound/flutter_sound.dart'
    show FlutterSoundRecorder, Codec;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:http/http.dart' as http;

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

  // Dừng ghi + upload
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

    // Debug: kiểm tra file có thật & có dung lượng không
    final f = File(path);
    final exists = await f.exists();
    final len = exists ? await f.length() : 0;
    // print('🎧 File thu âm: $path, exists=$exists, length=$len bytes');

    if (!exists || len < 1000) {
      return 'File audio quá nhỏ (len=$len bytes), kiểm tra lại ghi âm';
    }

    // POST /voice-notes/upload field 'file'
    final url = Uri.parse('$_baseUrl/voice-notes/upload');
    final req = http.MultipartRequest('POST', url)
      ..files.add(
        await http.MultipartFile.fromPath(
          'file',
          path,
          filename: name, // vd: mb_1762507443177.m4a
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
