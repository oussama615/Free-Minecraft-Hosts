import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import '../models/models.dart';

class ApiClient {
  ApiClient({String? baseUrl}) : baseUrl = baseUrl ?? defaultBaseUrl;

  static const defaultBaseUrl = String.fromEnvironment('API_BASE_URL', defaultValue: 'http://10.0.2.2:3000');
  final String baseUrl;
  final _storage = const FlutterSecureStorage();
  String? accessToken;
  EmpUser? currentUser;

  Future<void> loadToken() async { accessToken = await _storage.read(key: 'accessToken'); }

  Future<bool> healthCheck() async {
    try {
      final res = await http.get(Uri.parse('$baseUrl/health')).timeout(const Duration(seconds: 3));
      return res.statusCode >= 200 && res.statusCode < 300;
    } catch (_) {
      return false;
    }
  }

  Future<void> login(String usernameOrEmail, String password) async {
    final res = await http.post(Uri.parse('$baseUrl/auth/login'), headers: _headers(), body: jsonEncode({'usernameOrEmail': usernameOrEmail, 'password': password}));
    _check(res);
    final json = jsonDecode(res.body) as Map<String, dynamic>;
    accessToken = json['accessToken'] as String;
    currentUser = EmpUser.fromJson(json['user'] as Map<String, dynamic>);
    await _storage.write(key: 'accessToken', value: accessToken);
    await _storage.write(key: 'refreshToken', value: json['refreshToken'] as String);
  }

  Future<EmpUser?> me() async {
    final res = await _get('/auth/me');
    if (res.statusCode == 401) { await logout(); return null; }
    _check(res);
    currentUser = EmpUser.fromJson((jsonDecode(res.body) as Map<String, dynamic>)['user'] as Map<String, dynamic>);
    return currentUser;
  }

  Future<void> logout() async {
    if (accessToken != null) {
      try { await http.post(Uri.parse('$baseUrl/auth/logout'), headers: _headers()); } catch (_) {}
    }
    accessToken = null;
    currentUser = null;
    await _storage.deleteAll();
  }

  Future<List<EmpServer>> servers() async {
    final res = await _get('/servers');
    _check(res);
    return ((jsonDecode(res.body) as Map<String, dynamic>)['servers'] as List).map((item) => EmpServer.fromJson(item as Map<String, dynamic>)).toList();
  }

  Future<Map<String, dynamic>?> latest(String id) async {
    final res = await _get('/servers/$id/metrics/latest');
    _check(res);
    return ((jsonDecode(res.body) as Map<String, dynamic>)['latest'] as Map<String, dynamic>?)?['snapshot'] as Map<String, dynamic>?;
  }

  Future<List<dynamic>> alerts(String? id) async {
    final res = await _get(id == null ? '/alerts' : '/servers/$id/alerts');
    _check(res);
    return (jsonDecode(res.body) as Map<String, dynamic>)['alerts'] as List<dynamic>;
  }

  Future<List<dynamic>> logs(String id) async {
    final res = await _get('/servers/$id/logs');
    _check(res);
    return (jsonDecode(res.body) as Map<String, dynamic>)['logs'] as List<dynamic>;
  }

  Future<List<dynamic>> securityEvents(String id) async {
    final res = await _get('/servers/$id/security-events');
    _check(res);
    return (jsonDecode(res.body) as Map<String, dynamic>)['events'] as List<dynamic>;
  }

  Future<List<dynamic>> users() async {
    final res = await _get('/users');
    _check(res);
    return (jsonDecode(res.body) as Map<String, dynamic>)['users'] as List<dynamic>;
  }

  Future<Map<String, dynamic>> sendCommand(String id, String command, {bool confirmed = false}) async {
    final res = await http.post(Uri.parse('$baseUrl/servers/$id/commands'), headers: _headers(), body: jsonEncode({'command': command, 'confirmed': confirmed}));
    _check(res);
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  Future<http.Response> _get(String path) => http.get(Uri.parse('$baseUrl$path'), headers: _headers());
  Map<String, String> _headers() => {'Content-Type': 'application/json', if (accessToken != null) 'Authorization': 'Bearer $accessToken'};
  void _check(http.Response response) { if (response.statusCode >= 400) throw Exception('${response.statusCode}: ${response.body}'); }
}
