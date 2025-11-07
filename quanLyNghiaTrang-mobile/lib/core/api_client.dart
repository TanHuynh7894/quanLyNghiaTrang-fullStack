import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiClient {
  final String baseUrl;
  final http.Client _client;

  ApiClient({String? baseUrl, http.Client? client})
      : baseUrl = baseUrl ?? 'http://10.0.2.2:5000',
        _client = client ?? http.Client();

  Future<Map<String, dynamic>> getJson(String path, Map<String, String> q) async {
    final uri = Uri.parse('$baseUrl$path').replace(queryParameters: q);
    final res = await _client.get(uri).timeout(const Duration(seconds: 12));
    if (res.statusCode >= 200 && res.statusCode < 300) {
      return jsonDecode(res.body) as Map<String, dynamic>;
    }
    throw Exception('GET $path -> ${res.statusCode}: ${res.body}');
  }

  void dispose() => _client.close();
}
