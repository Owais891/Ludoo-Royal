import 'dart:convert';
import 'package:http/http.dart' as http;
import '../storage/app_config.dart';

/// Generic HTTP client for talking to the Ludo Royale PHP backend.
class ApiClient {
  final String baseUrl;
  final http.Client _client;

  ApiClient({String? baseUrl, http.Client? client})
      : baseUrl = baseUrl ?? AppConfig.apiBaseUrl,
        _client = client ?? http.Client();

  Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
    if (AppConfig.authToken != null) 'Authorization': 'Bearer ${AppConfig.authToken}',
  };

  Uri _uri(String path) {
    final clean = path.startsWith('/') ? path.substring(1) : path;
    final base = baseUrl.endsWith('/') ? baseUrl.substring(0, baseUrl.length - 1) : baseUrl;
    return Uri.parse('$base/$clean');
  }

  Future<Map<String, dynamic>> get(String path, {Map<String, dynamic>? query}) async {
    final uri = _uri(path).replace(queryParameters: query?.map((k, v) => MapEntry(k, v.toString())));
    final res = await _client.get(uri, headers: _headers);
    return _decode(res.body, res.statusCode);
  }

  Future<Map<String, dynamic>> post(String path, {Map<String, dynamic>? body}) async {
    final res = await _client.post(
      _uri(path),
      headers: _headers,
      body: body != null ? jsonEncode(body) : null,
    );
    return _decode(res.body, res.statusCode);
  }

  Future<Map<String, dynamic>> put(String path, {Map<String, dynamic>? body}) async {
    final res = await _client.put(
      _uri(path),
      headers: _headers,
      body: body != null ? jsonEncode(body) : null,
    );
    return _decode(res.body, res.statusCode);
  }

  Map<String, dynamic> _decode(String body, int status) {
    Map<String, dynamic> j;
    try {
      j = jsonDecode(body) as Map<String, dynamic>;
    } catch (_) {
      throw ApiException(status, 'Invalid JSON response', body);
    }
    if (status >= 400 || j['success'] == false) {
      throw ApiException(status, (j['message'] as String?) ?? 'Request failed', j);
    }
    return j;
  }
}

class ApiException implements Exception {
  final int statusCode;
  final String message;
  final dynamic body;
  ApiException(this.statusCode, this.message, [this.body]);

  @override
  String toString() => 'ApiException($statusCode): $message';
}
