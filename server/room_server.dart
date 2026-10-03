import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:pocket_party/games/dots_game.dart';

class ApiError implements Exception {
  ApiError(this.status, this.message);
  final int status;
  final String message;
}

class Room {
  Room(this.code, int players) : game = DotsGame(players: players);
  final String code;
  DotsGame game;
  final List<String> tokens = [];
  int revision = 0;
  DateTime touched = DateTime.now();
  bool get ready => tokens.length == game.players;
  Map<String, dynamic> snapshot(int player) => {
    'code': code,
    'player': player,
    'joined': tokens.length,
    'ready': ready,
    'revision': revision,
    'game': game.toJson(),
  };
}

class RoomServer {
  final Map<String, Room> rooms = {};
  final Random random = Random.secure();
  Timer? cleanup;
  HttpServer? http;

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
        response.write(jsonEncode({'status': 'ok'}));
        return;
      }
      Map<String, dynamic> body = {};
      if (request.method == 'POST') {
        final bytes = <int>[];
        await for (final chunk in request) {
          bytes.addAll(chunk);
          if (bytes.length > 4096) throw ApiError(413, 'Request too large');
        }
        body = Map<String, dynamic>.from(jsonDecode(utf8.decode(bytes)) as Map);
      }
      Object result;
      if (request.method == 'POST' && request.uri.path == '/rooms') {
        final players = body['players'];
        if (players is! int || players < 2 || players > 4) {
          throw ApiError(400, 'Choose 2 to 4 players');
        }
        if (rooms.length >= 500) {
          throw ApiError(503, 'Server is full. Try later.');
        }
        var roomCode = code();
        while (rooms.containsKey(roomCode)) {
          roomCode = code();
        }
        final room = Room(roomCode, players);
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
        if (request.method == 'POST' &&
            parts.length == 3 &&
            parts[2] == 'join') {
          if (room.ready) throw ApiError(409, 'This room is full');
          final key = token();
          room.tokens.add(key);
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
            if (room.game.turn != player) {
              throw ApiError(409, 'It is another player’s turn');
            }
            final move = body['move'];
            if (move is! String || !room.game.play(move)) {
              throw ApiError(400, 'That move is not legal');
            }
            room.revision++;
            result = room.snapshot(player);
          } else if (request.method == 'POST' &&
              parts.length == 3 &&
              parts[2] == 'restart') {
            if (player != 0) throw ApiError(403, 'Only the host can restart');
            if (!room.game.finished) {
              throw ApiError(409, 'Finish this match before restarting');
            }
            if (body['revision'] != room.revision) {
              throw ApiError(409, 'The board changed');
            }
            room.game = DotsGame(players: room.game.players);
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
      response.write(jsonEncode({'error': error.message}));
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
    }
  }
}
