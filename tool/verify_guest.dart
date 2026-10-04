// Manual end-to-end test: join a phone room, wait for its move, reply once.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:pocket_party/games/dots_game.dart';
import 'package:pocket_party/games/dots_bot.dart';

Future<void> main(List<String> args) async {
  if (args.length != 1) throw ArgumentError('Pass the room code');
  final client = http.Client();
  final room = Uri.parse('http://127.0.0.1:8787/rooms/${args.first}');
  try {
    final joined = await client.post(
      Uri.parse('$room/join'),
      headers: {'Content-Type': 'application/json'},
      body: '{}',
    );
    if (joined.statusCode != 200) throw StateError(joined.body);
    final session = jsonDecode(joined.body) as Map<String, dynamic>;
    final headers = {
      'Authorization': 'Bearer ${session['token']}',
      'Content-Type': 'application/json',
    };
    stdout.writeln('Second client joined. Waiting for a move on the phone.');
    final deadline = DateTime.now().add(const Duration(seconds: 45));
    while (DateTime.now().isBefore(deadline)) {
      final response = await client.get(room, headers: headers);
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final game = DotsGame.fromJson(data['game'] as Map<String, dynamic>);
      if (data['ready'] == true && game.turn == session['player']) {
        if (game.edges.isEmpty) throw StateError('Expected a phone move');
        final reply = await client.post(
          Uri.parse('$room/moves'),
          headers: headers,
          body: jsonEncode({
            'move': chooseBotMove(game),
            'revision': data['revision'],
          }),
        );
        if (reply.statusCode != 200) throw StateError(reply.body);
        stdout.writeln(
          'Verified phone move received and second-client reply accepted.',
        );
        return;
      }
      await Future<void>.delayed(const Duration(milliseconds: 250));
    }
    throw StateError('Timed out waiting for a phone move');
  } finally {
    client.close();
  }
}
