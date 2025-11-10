import 'dart:io';

class ApiConfig {
  static String get baseUrl {
    // Android emulator dùng 10.0.2.2, iOS simulator/mac có thể localhost
    if (Platform.isAndroid) return 'http://10.0.2.2:5000';
    return 'http://localhost:5000';
  }
}
