import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:pocket_party/online/online_session.dart';

import '../server/room_server.dart';

// ignore: avoid_relative_lib_imports
import '../lib/games/chess_clock.dart';

void main() {
  late RoomServer server;
  late String base;
  late http.Client client;
  setUp(() async {
    server = RoomServer();
    final running = await server.start(port: 0);
    base = 'http://127.0.0.1:${running.port}';
    client = http.Client();
  });
  tearDown(() async {
    client.close();
    await server.close();
  });

  Future<http.Response> post(
    String path,
    Map<String, dynamic> body, [
    String? token,
  ]) => client.post(
    Uri.parse('$base$path'),
    headers: {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    },
    body: jsonEncode(body),
  );
  Map<String, dynamic> decode(http.Response response) =>
      jsonDecode(response.body) as Map<String, dynamic>;

  test('Rooms authenticate players and enforce turns and revisions', () async {
    final host = decode(await post('/rooms', {'players': 2}));
    final code = host['code'];
    final hostToken = host['token'] as String;
    expect(
      (await post('/rooms/$code/moves', {
        'move': 'h:0:0',
        'revision': 0,
      }, hostToken)).statusCode,
      409,
    );
    final guest = decode(await post('/rooms/$code/join', {}));
    final guestToken = guest['token'] as String;
    expect(guest['ready'], isTrue);
    expect((await post('/rooms/$code/join', {})).statusCode, 409);
    expect((await client.get(Uri.parse('$base/rooms/$code'))).statusCode, 401);
    expect(
      (await post('/rooms/$code/moves', {
        'move': 'h:0:0',
        'revision': 1,
      }, guestToken)).statusCode,
      409,
    );
    expect(
      (await post('/rooms/$code/moves', {
        'move': 'h:99:0',
        'revision': 1,
      }, hostToken)).statusCode,
      400,
    );
    final move = await post('/rooms/$code/moves', {
      'move': 'h:0:0',
      'revision': 1,
    }, hostToken);
    expect(move.statusCode, 200);
    expect(decode(move)['game']['turn'], 1);
    expect(
      (await post('/rooms/$code/moves', {
        'move': 'h:0:1',
        'revision': 1,
      }, guestToken)).statusCode,
      409,
    );
    expect(
      (await post('/rooms/$code/restart', {
        'revision': 2,
      }, guestToken)).statusCode,
      403,
    );
    expect(
      (await post('/rooms/$code/restart', {
        'revision': 2,
      }, hostToken)).statusCode,
      409,
    );
  });

  test(
    'Four players finish a synchronized match and host starts a rematch',
    () async {
      final sessions = <OnlineSession>[];
      try {
        final host = await OnlineSession.open(base, players: 4);
        sessions.add(host);
        for (var i = 1; i < 4; i++) {
          sessions.add(await OnlineSession.open(base, code: host.code));
        }
        for (final session in sessions) {
          await session.refresh();
        }
        expect(sessions.every((s) => s.ready), isTrue);
        final room = server.rooms[host.code]!;
        while (!room.game.finished) {
          final session = sessions[room.game.turn];
          await session.refresh();
          await session.move(room.game.legalMoves.first);
        }
        for (final session in sessions) {
          await session.refresh();
        }
        expect(sessions.every((s) => s.game.finished), isTrue);
        expect(host.game.size, 7);
        expect(host.game.scores.reduce((a, b) => a + b), 36);
        expect(sessions.last.game.toJson(), host.game.toJson());
        await host.restart();
        await sessions.last.refresh();
        expect(sessions.last.game.edges, isEmpty);
        expect(sessions.last.game.turn, 0);
      } finally {
        for (final session in sessions) {
          session.dispose();
        }
      }
    },
  );

  test('Chess rooms synchronize checkmate and host rematch', () async {
    final host = await OnlineSession.open(base, players: 2, gameType: 'chess');
    final guest = await OnlineSession.open(base, code: host.code);
    try {
      expect(guest.gameType, 'chess');
      for (final move in ['f2f3', 'e7e5', 'g2g4', 'd8h4']) {
        await host.refresh();
        await guest.refresh();
        final player = host.chessGame.turn == 0 ? host : guest;
        await player.move(move);
        expect(player.error, isNull);
      }
      await host.refresh();
      await guest.refresh();
      expect(host.chessGame.finished, isTrue);
      expect(host.chessGame.toJson(), guest.chessGame.toJson());
      await host.restart();
      await guest.refresh();
      expect(guest.chessGame.history, isEmpty);
      expect(guest.chessGame.turn, 0);
      expect(
        (await post('/rooms', {'players': 3, 'gameType': 'chess'})).statusCode,
        400,
      );
    } finally {
      host.dispose();
      guest.dispose();
    }
  });

  test(
    'Server owns online timeouts, counts once and preserves records on rematch',
    () async {
      final host = await OnlineSession.open(
        base,
        players: 2,
        gameType: 'chess',
        clockSeconds: 60,
      );
      OnlineSession? guest;
      try {
        final room = server.rooms[host.code]!;
        var now = 0;
        room.clock = ChessClock(60, now: () => now);
        now = 120000;
        await host.refresh();
        expect(host.chessGame.finished, isFalse);
        expect(host.remainingMs, [60000, 60000]);
        guest = await OnlineSession.open(base, code: host.code);
        now += 61000;
        await host.refresh();
        await guest.refresh();
        expect(host.chessGame.winner, 1);
        expect(guest.chessGame.finished, isTrue);
        expect(host.series.losses, [1, 0]);
        expect(host.series.wins, [0, 1]);
        await host.refresh();
        expect(host.series.wins, [0, 1]);
        await host.restart();
        await guest.refresh();
        expect(guest.chessGame.finished, isFalse);
        expect(guest.round, 2);
        expect(guest.series.wins, [0, 1]);
        expect(guest.clock!['seconds'], 60);
        expect(
          (await post('/rooms', {
            'players': 2,
            'gameType': 'chess',
            'clockSeconds': -1,
          })).statusCode,
          400,
        );
      } finally {
        host.dispose();
        guest?.dispose();
      }
    },
  );

  test('Malformed and unknown room requests have useful errors', () async {
    expect((await post('/rooms', {'players': 8})).statusCode, 400);
    expect((await post('/rooms/ZZZZZZ/join', {})).statusCode, 404);
    final response = await client.post(
      Uri.parse('$base/rooms'),
      body: 'not json',
    );
    expect(response.statusCode, 400);
  });

  test(
    'Creation limits protect rooms without breaking health checks',
    () async {
      await server.close();
      server = RoomServer(creationLimit: 1, requestLimit: 3);
      final running = await server.start(port: 0);
      base = 'http://127.0.0.1:${running.port}';
      expect((await post('/rooms', {'players': 2})).statusCode, 200);
      final limited = await post('/rooms', {'players': 2});
      expect(limited.statusCode, 429);
      expect(limited.headers['retry-after'], '60');
      expect(server.rooms.length, 1);
      expect((await client.get(Uri.parse('$base/health'))).statusCode, 200);
      await client.get(Uri.parse('$base/missing'));
      expect((await client.get(Uri.parse('$base/missing'))).statusCode, 429);
      expect((await client.get(Uri.parse('$base/health'))).statusCode, 200);
    },
  );

  test('Oversized room requests cannot allocate rooms', () async {
    final response = await client.post(
      Uri.parse('$base/rooms'),
      body: jsonEncode({'players': 2, 'padding': 'x' * 5000}),
    );
    expect(response.statusCode, 413);
    expect(server.rooms, isEmpty);
  });
}
