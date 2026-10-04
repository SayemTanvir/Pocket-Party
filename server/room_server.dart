import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

// The server compiles independently of Flutter and shares these pure Dart rules.
// ignore: avoid_relative_lib_imports
import '../lib/games/dots_game.dart';
// ignore: avoid_relative_lib_imports
import '../lib/games/chess_game.dart';
// ignore: avoid_relative_lib_imports
import '../lib/games/party_game.dart';
// ignore: avoid_relative_lib_imports
import '../lib/games/chess_clock.dart';
// ignore: avoid_relative_lib_imports
import '../lib/games/match_series.dart';

class ApiError implements Exception {
  ApiError(this.status, this.message);
  final int status;
  final String message;
}

class Room {
  Room(this.code, int players, {this.gameType = 'dots', this.clockSeconds = 0})
    : state = gameType == 'chess' ? ChessGame() : DotsGame(players: players),
      series = MatchSeries(players),
      clock = clockSeconds == 0 ? null : ChessClock(clockSeconds);
  final String code, gameType;
  final int clockSeconds;
  PartyGame state;
  final MatchSeries series;
  ChessClock? clock;
  bool recorded = false;
  int round = 1;
  DotsGame get game => state as DotsGame;
  final List<String> tokens = [];
  int revision = 0;
  DateTime touched = DateTime.now();
  bool get ready => tokens.length == state.players;
  void update() {
    final wasFinished = state.finished;
    if (state is ChessGame) clock?.settle(state as ChessGame);
    if (!wasFinished && state.finished) revision++;
    if (state.finished && !recorded) {
      series.record(state);
      recorded = true;
    }
  }

  void restart() {
    state = gameType == 'chess'
        ? ChessGame()
        : DotsGame(players: state.players);
    clock = clockSeconds == 0 ? null : (ChessClock(clockSeconds)..start());
    round++;
    recorded = false;
  }

  Map<String, dynamic> snapshot(int player) {
    update();
    return {
      'code': code,
      'player': player,
      'joined': tokens.length,
      'ready': ready,
      'revision': revision,
      'gameType': gameType,
      'game': state.toJson(),
      'clock': clock?.toJson(),
      'series': series.toJson(),
      'round': round,
    };
  }
}

class RoomServer {
  RoomServer({
    this.requestLimit = 1200,
    this.creationLimit = 40,
    this.rateWindow = const Duration(minutes: 1),
  });
  final int requestLimit;
  final int creationLimit;
  final Duration rateWindow;
  final Map<String, _RateBucket> _rates = {};
  final Map<String, Room> rooms = {};
  final Random random = Random.secure();
  Timer? cleanup;
  HttpServer? http;

  void _checkRate(String key, int limit) {
    final now = DateTime.now();
    _rates.removeWhere(
      (_, value) => now.difference(value.started) >= rateWindow,
    );
    if (!_rates.containsKey(key) && _rates.length >= 2000) {
      throw ApiError(429, 'Server is busy. Try again shortly.');
    }
    final bucket = _rates.putIfAbsent(key, () => _RateBucket(now));
    if (++bucket.count > limit) {
      throw ApiError(429, 'Too many requests. Try again shortly.');
    }
  }

  String token() =>
      base64Url.encode(List.generate(24, (_) => random.nextInt(256)));
  String code() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    return List.generate(6, (_) => chars[random.nextInt(chars.length)]).join();
  }

  Future<HttpServer> start({String host = '127.0.0.1', int port = 8787}) async {
    http = await HttpServer.bind(host, port);
    http!.listen(handle);
    cleanup = Timer.periodic(const Duration(minutes: 5), (_) {
      rooms.removeWhere(
        (_, room) =>
            DateTime.now().difference(room.touched) > const Duration(hours: 2),
      );
    });
    return http!;
  }

  Future<void> close() async {
    cleanup?.cancel();
    await http?.close(force: true);
  }

  Future<void> handle(HttpRequest request) async {
    final response = request.response;
    StreamSubscription<List<int>>? bodySubscription;
    response.headers.set('Access-Control-Allow-Origin', '*');
    response.headers.set(
      'Access-Control-Allow-Headers',
      'Content-Type, Authorization',
    );
    response.headers.set('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
    response.headers.set('Cache-Control', 'no-store');
    response.headers.contentType = ContentType.json;
    try {
      if (request.method == 'OPTIONS') {
        response.statusCode = 204;
        return;
      }
      if (request.method == 'GET' && request.uri.path == '/health') {
        response.write(
          jsonEncode({
            'status': 'ok',
            'games': ['dots', 'chess'],
            'dotsBoardSize': 7,
            'features': ['chessClocks', 'matchSeries'],
          }),
        );
        return;
      }
      final source = request.connectionInfo?.remoteAddress.address ?? 'unknown';
      _checkRate('requests:$source', requestLimit);
      if (request.method == 'POST' && request.uri.path == '/rooms') {
        _checkRate('create:$source', creationLimit);
      }
      Map<String, dynamic> body = {};
      if (request.method == 'POST') {
        final bytes = <int>[];
        final complete = Completer<void>();
        bodySubscription = request.listen(
          (chunk) {
            if (complete.isCompleted) return;
            if (bytes.length + chunk.length > 4096) {
              complete.completeError(ApiError(413, 'Request too large'));
            } else {
              bytes.addAll(chunk);
            }
          },
          onDone: () {
            if (!complete.isCompleted) complete.complete();
          },
          onError: (Object error) {
            if (!complete.isCompleted) complete.completeError(error);
          },
        );
        await complete.future.timeout(const Duration(seconds: 10));
        body = Map<String, dynamic>.from(jsonDecode(utf8.decode(bytes)) as Map);
      }
      Object result;
      if (request.method == 'POST' && request.uri.path == '/rooms') {
        final players = body['players'];
        if (players is! int || players < 2 || players > 4) {
          throw ApiError(400, 'Choose 2 to 4 players');
        }
        final gameType = body['gameType'] ?? 'dots';
        if (!['dots', 'chess'].contains(gameType) ||
            (gameType == 'chess' && players != 2)) {
          throw ApiError(
            400,
            'Choose a supported game. Chess needs two players.',
          );
        }
        final seconds = body['clockSeconds'] ?? 0;
        if (seconds is! int ||
            ![0, 60, 180, 300, 600].contains(seconds) ||
            (gameType != 'chess' && seconds != 0)) {
          throw ApiError(400, 'Choose a supported chess timer');
        }
        if (rooms.length >= 500) {
          throw ApiError(503, 'Server is full. Try later.');
        }
        var roomCode = code();
        while (rooms.containsKey(roomCode)) {
          roomCode = code();
        }
        final room = Room(
          roomCode,
          players,
          gameType: gameType as String,
          clockSeconds: seconds,
        );
        final key = token();
        room.tokens.add(key);
        rooms[roomCode] = room;
        result = {...room.snapshot(0), 'token': key};
      } else {
        final parts = request.uri.pathSegments;
        if (parts.length < 2 || parts.first != 'rooms') {
          throw ApiError(404, 'Not found');
        }
        final room = rooms[parts[1].toUpperCase()];
        if (room == null) throw ApiError(404, 'Room not found or expired');
        room.update();
        if (request.method == 'POST' &&
            parts.length == 3 &&
            parts[2] == 'join') {
          if (room.ready) throw ApiError(409, 'This room is full');
          final key = token();
          room.tokens.add(key);
          if (room.ready) room.clock?.start();
          room.revision++;
          room.touched = DateTime.now();
          result = {...room.snapshot(room.tokens.length - 1), 'token': key};
        } else {
          final auth = request.headers.value('Authorization') ?? '';
          final player = room.tokens.indexOf(
            auth.startsWith('Bearer ') ? auth.substring(7) : '',
          );
          if (player < 0) throw ApiError(401, 'Invalid player session');
          if (request.method == 'GET' && parts.length == 2) {
            result = room.snapshot(player);
          } else if (request.method == 'POST' &&
              parts.length == 3 &&
              parts[2] == 'moves') {
            if (!room.ready) throw ApiError(409, 'Waiting for all players');
            if (body['revision'] != room.revision) {
              throw ApiError(409, 'The board changed. Refresh and try again.');
            }
            if (room.state.turn != player) {
              throw ApiError(409, 'It is another player’s turn');
            }
            final move = body['move'];
            if (move is! String || !room.state.play(move)) {
              throw ApiError(400, 'That move is not legal');
            }
            room.revision++;
            result = room.snapshot(player);
          } else if (request.method == 'POST' &&
              parts.length == 3 &&
              parts[2] == 'restart') {
            if (player != 0) throw ApiError(403, 'Only the host can restart');
            if (!room.state.finished) {
              throw ApiError(409, 'Finish this match before restarting');
            }
            if (body['revision'] != room.revision) {
              throw ApiError(409, 'The board changed');
            }
            room.restart();
            room.revision++;
            result = room.snapshot(player);
          } else {
            throw ApiError(404, 'Not found');
          }
          room.touched = DateTime.now();
        }
      }
      response.write(jsonEncode(result));
    } on ApiError catch (error) {
      response.statusCode = error.status;
      if (error.status == 429) response.headers.set('Retry-After', '60');
      response.write(jsonEncode({'error': error.message}));
    } on TimeoutException {
      response.statusCode = 408;
      response.write(jsonEncode({'error': 'Request timed out'}));
    } on FormatException {
      response.statusCode = 400;
      response.write(jsonEncode({'error': 'Invalid request'}));
    } on TypeError {
      response.statusCode = 400;
      response.write(jsonEncode({'error': 'Invalid request'}));
    } catch (_) {
      response.statusCode = 500;
      response.write(jsonEncode({'error': 'Server error'}));
    } finally {
      await response.close();
      await bodySubscription?.cancel();
    }
  }
}

class _RateBucket {
  _RateBucket(this.started);
  final DateTime started;
  int count = 0;
}
