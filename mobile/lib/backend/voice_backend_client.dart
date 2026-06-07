import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:web_socket_channel/web_socket_channel.dart';

enum BackendState { initializing, unavailable, unlinked, linking, connecting, connected, disconnected, expired, error }

class BackendSnapshot {
  const BackendSnapshot({required this.state, this.player, this.server, this.online = false, this.muted = false, this.deafened = false, this.message});
  final BackendState state;
  final String? player;
  final String? server;
  final bool online;
  final bool muted;
  final bool deafened;
  final String? message;
}

class VoiceBackendClient {
  VoiceBackendClient();

  static const baseUrl = String.fromEnvironment('API_BASE_URL', defaultValue: '');
  static const timeout = Duration(seconds: 5);
  static const reconnectDelay = Duration(seconds: 3);

  final _storage = const FlutterSecureStorage();
  final _http = http.Client();
  final _stream = StreamController<BackendSnapshot>.broadcast();
  Stream<BackendSnapshot> get snapshots => _stream.stream;

  WebSocketChannel? _socket;
  StreamSubscription<dynamic>? _socketSub;
  Timer? _reconnect;
  String? _token;
  String? _player;
  String? _server;
  bool _online = false;
  bool _muted = false;
  bool _deafened = false;
  bool _closed = false;

  Future<void> initialize() async {
    _emit(const BackendSnapshot(state: BackendState.initializing));
    if (baseUrl.isEmpty || !await healthCheck()) {
      _emit(const BackendSnapshot(state: BackendState.unavailable, message: 'Backend unavailable'));
      return;
    }
    _token = await _storage.read(key: 'voice_session_token');
    if (_token == null || _token!.isEmpty) {
      _emit(const BackendSnapshot(state: BackendState.unlinked));
      return;
    }
    await refresh();
  }

  Future<bool> healthCheck() async {
    try {
      final response = await _http.get(Uri.parse('$baseUrl/health')).timeout(timeout);
      return response.statusCode >= 200 && response.statusCode < 300;
    } catch (_) {
      return false;
    }
  }

  Future<void> claim(String rawCode) async {
    final code = rawCode.trim().toUpperCase();
    if (!RegExp(r'^STR-\d{6}$').hasMatch(code)) throw const BackendException('Invalid link code');
    _emit(const BackendSnapshot(state: BackendState.linking));

    final deviceId = await _getOrCreate('voice_device_id', 16);
    final publicKey = await _getOrCreate('voice_device_public_key', 64);
    final response = await _http.post(
      Uri.parse('$baseUrl/api/v1/link-codes/claim'),
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode({'code': code, 'deviceId': deviceId, 'publicKey': publicKey, 'deviceName': 'Android Device'}),
    ).timeout(timeout);

    final json = _json(response.body);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      _emit(const BackendSnapshot(state: BackendState.unlinked));
      throw BackendException(_error(json) ?? 'Unable to claim link code');
    }

    final session = json['session'];
    if (session is! Map<String, dynamic> || session['token'] is! String) throw const BackendException('Invalid backend session');
    _token = session['token'] as String;
    final player = json['player'];
    _player = player is Map<String, dynamic> ? player['username'] as String? : null;
    await _storage.write(key: 'voice_session_token', value: _token);
    await refresh();
  }

  Future<void> refresh() async {
    final token = _token;
    if (token == null) return;
    _emit(BackendSnapshot(state: BackendState.connecting, player: _player, server: _server));
    try {
      final response = await _http.get(
        Uri.parse('$baseUrl/api/v1/sessions/me'),
        headers: {'Authorization': 'Bearer $token'},
      ).timeout(timeout);
      if (response.statusCode == 401) {
        await unlink();
        _emit(const BackendSnapshot(state: BackendState.expired));
        return;
      }
      final json = _json(response.body);
      if (response.statusCode < 200 || response.statusCode >= 300) throw BackendException(_error(json) ?? 'Session unavailable');
      final player = json['player'];
      final server = json['server'];
      _player = player is Map<String, dynamic> ? player['username'] as String? : _player;
      _server = server is Map<String, dynamic> ? server['name'] as String? : null;
      _online = json['online'] as bool? ?? (_server != null);
      _muted = json['muted'] as bool? ?? false;
      _deafened = json['deafened'] as bool? ?? false;
      await _connectSocket();
    } catch (error) {
      _emit(BackendSnapshot(state: BackendState.disconnected, player: _player, server: _server, message: '$error'));
      _scheduleReconnect();
    }
  }

  Future<void> _connectSocket() async {
    final token = _token;
    if (token == null || _closed) return;
    await _closeSocket();
    final wsBase = baseUrl.replaceFirst('https://', 'wss://').replaceFirst('http://', 'ws://');
    try {
      _socket = WebSocketChannel.connect(Uri.parse('$wsBase/ws'));
      await _socket!.ready.timeout(timeout);
      _socket!.sink.add(jsonEncode({'type': 'AUTH', 'payload': {'token': token}}));
      _socketSub = _socket!.stream.listen(_onSocket, onDone: _onDisconnected, onError: (_) => _onDisconnected());
    } catch (_) {
      _onDisconnected();
    }
  }

  void _onSocket(dynamic raw) {
    if (raw is! String) return;
    final json = _json(raw);
    final type = json['type'];
    final payload = json['payload'];
    if (type == 'AUTH' && payload is Map<String, dynamic> && payload['status'] == 'ok') {
      _emitCurrent(BackendState.connected);
    } else if (type == 'PING') {
      _socket?.sink.add(jsonEncode({'type': 'PONG'}));
    } else if (type == 'PLAYER_STATE' && payload is Map<String, dynamic>) {
      _online = payload['online'] as bool? ?? _online;
      _muted = payload['muted'] as bool? ?? _muted;
      _deafened = payload['deafened'] as bool? ?? _deafened;
      _server = payload['serverName'] as String? ?? _server;
      _emitCurrent(BackendState.connected);
    } else if (type == 'SESSION_REVOKED') {
      unawaited(unlink());
      _emit(const BackendSnapshot(state: BackendState.expired));
    }
  }

  void setMuted(bool value) {
    _muted = value;
    _socket?.sink.add(jsonEncode({'type': value ? 'MUTE' : 'UNMUTE', 'payload': {}}));
    _emitCurrent(BackendState.connected);
  }

  void setDeafened(bool value) {
    _deafened = value;
    _socket?.sink.add(jsonEncode({'type': value ? 'DEAFEN' : 'UNDEAFEN', 'payload': {}}));
    _emitCurrent(BackendState.connected);
  }

  Future<void> unlink() async {
    _token = null;
    _player = null;
    _server = null;
    _online = false;
    await _storage.delete(key: 'voice_session_token');
    await _closeSocket();
    _emit(const BackendSnapshot(state: BackendState.unlinked));
  }

  void _onDisconnected() {
    if (_token == null || _closed) return;
    _emitCurrent(BackendState.disconnected);
    _scheduleReconnect();
  }

  void _scheduleReconnect() {
    if (_closed || _token == null || _reconnect?.isActive == true) return;
    _reconnect = Timer(reconnectDelay, refresh);
  }

  void _emitCurrent(BackendState state) => _emit(BackendSnapshot(state: state, player: _player, server: _server, online: _online, muted: _muted, deafened: _deafened));
  void _emit(BackendSnapshot value) { if (!_closed) _stream.add(value); }

  Future<String> _getOrCreate(String key, int bytes) async {
    final existing = await _storage.read(key: key);
    if (existing != null && existing.isNotEmpty) return existing;
    final random = Random.secure();
    final value = List<int>.generate(bytes, (_) => random.nextInt(256)).map((e) => e.toRadixString(16).padLeft(2, '0')).join();
    await _storage.write(key: key, value: value);
    return value;
  }

  Map<String, dynamic> _json(String source) {
    try {
      final value = jsonDecode(source);
      return value is Map<String, dynamic> ? value : {};
    } catch (_) {
      return {};
    }
  }

  String? _error(Map<String, dynamic> json) {
    final error = json['error'];
    return error is Map<String, dynamic> ? error['message'] as String? : null;
  }

  Future<void> _closeSocket() async {
    await _socketSub?.cancel();
    _socketSub = null;
    await _socket?.sink.close();
    _socket = null;
  }

  Future<void> dispose() async {
    _closed = true;
    _reconnect?.cancel();
    await _closeSocket();
    _http.close();
    await _stream.close();
  }
}

class BackendException implements Exception {
  const BackendException(this.message);
  final String message;
  @override
  String toString() => message;
}
