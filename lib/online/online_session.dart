import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../games/dots_game.dart';

class OnlineSession extends ChangeNotifier {
  OnlineSession._(this.baseUrl, this.token, Map<String, dynamic> data) {
    _apply(data);
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => refresh());
  }
  final String baseUrl;
  final String token;
  final http.Client _client = http.Client();
  late String code;
  late int player;
  late DotsGame game;
  int joined = 1;
  int revision = -1;
  bool ready = false;
  bool connected = true;
  bool busy = false;
  bool expired = false;
  bool _polling = false;
  bool _disposed = false;
  String? error;
  Timer? _timer;

  bool get canMove =>
      ready &&
      connected &&
      !busy &&
      !expired &&
      !game.finished &&
      game.turn == player;

  static String normalizeUrl(String value) {
    final uri = Uri.tryParse(value.trim());
    if (uri == null ||
        !['http', 'https'].contains(uri.scheme) ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        uri.hasQuery ||
        uri.hasFragment ||
        (uri.path.isNotEmpty && uri.path != '/')) {
      throw const FormatException(
        'Enter a server address such as http://127.0.0.1:8787',
      );
    }
    return uri.replace(path: '').toString();
  }

  static Future<OnlineSession> open(
    String address, {
    int? players,
    String? code,
  }) async {
    final base = normalizeUrl(address);
    final joinCode = code?.trim().toUpperCase();
    if (players == null &&
        (joinCode == null || !RegExp(r'^[A-Z2-9]{6}$').hasMatch(joinCode))) {
      throw const FormatException('Enter the six-character room code');
    }
    final client = http.Client();
    try {
      // Wake a sleeping demo service with a read-only request first. Never
      // retry room creation automatically: that could reserve duplicate seats.
      final health = await client
          .get(Uri.parse('$base/health'))
          .timeout(const Duration(seconds: 75));
      if (health.statusCode != 200) {
        throw RoomException(
          'The game server is starting or unavailable. Try again shortly.',
          health.statusCode,
        );
      }
      final response = await client
          .post(
            Uri.parse('$base/rooms${players == null ? '/$joinCode/join' : ''}'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(players == null ? {} : {'players': players}),
          )
          .timeout(const Duration(seconds: 8));
      final data = _decode(response);
      return OnlineSession._(base, data['token'] as String, data);
    } finally {
      client.close();
    }
  }

  static Map<String, dynamic> _decode(http.Response response) {
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode >= 400) {
      throw RoomException(
        data['error'] as String? ?? 'Request failed',
        response.statusCode,
      );
    }
    return data;
  }

  void _apply(Map<String, dynamic> data) {
    final next = data['revision'] as int;
    if (next < revision) return;
    code = data['code'] as String;
    player = data['player'] as int;
    joined = data['joined'] as int;
    ready = data['ready'] as bool;
    revision = next;
    game = DotsGame.fromJson(data['game'] as Map<String, dynamic>);
  }

  Future<void> refresh() async {
    if (_disposed || _polling || busy || expired) return;
    _polling = true;
    try {
      final response = await _client
          .get(
            Uri.parse('$baseUrl/rooms/$code'),
            headers: {'Authorization': 'Bearer $token'},
          )
          .timeout(const Duration(seconds: 5));
      final data = _decode(response);
      if (_disposed) return;
      _apply(data);
      connected = true;
    } catch (failure) {
      if (_disposed) return;
      connected = false;
      if (failure is RoomException && [401, 404].contains(failure.status)) {
        expired = true;
        error = failure.message;
      }
    } finally {
      _polling = false;
      if (!_disposed) notifyListeners();
    }
  }

  Future<void> move(String move) => _send('moves', {'move': move});
  Future<void> restart() => _send('restart', {});

  Future<void> _send(String action, Map<String, dynamic> body) async {
    if (_disposed || busy || expired) return;
    busy = true;
    error = null;
    notifyListeners();
    try {
      final response = await _client
          .post(
            Uri.parse('$baseUrl/rooms/$code/$action'),
            headers: {
              'Authorization': 'Bearer $token',
              'Content-Type': 'application/json',
            },
            body: jsonEncode({...body, 'revision': revision}),
          )
          .timeout(const Duration(seconds: 5));
      final data = _decode(response);
      if (_disposed) return;
      _apply(data);
      connected = true;
    } catch (failure) {
      if (_disposed) return;
      if (failure is RoomException) {
        error = failure.message;
      } else {
        connected = false;
        error = 'Connection interrupted. Checking whether your move arrived…';
      }
    } finally {
      busy = false;
      if (!_disposed) {
        notifyListeners();
        unawaited(refresh());
      }
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    _client.close();
    super.dispose();
  }
}

class RoomException implements Exception {
  RoomException(this.message, this.status);
  final String message;
  final int status;
  @override
  String toString() => message;
}
