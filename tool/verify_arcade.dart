import 'dart:convert';
import 'dart:io';

import 'package:pocket_party/games/game_factory.dart';

Future<void> main(List<String> args) async {
  final base = args.isEmpty ? 'http://127.0.0.1:8787' : args.single;
  final client = HttpClient();
  Future<Map<String, dynamic>> request(
    String path, [
    Map<String, dynamic>? body,
    String? token,
  ]) async {
    final request = body == null
        ? await client.getUrl(Uri.parse('$base$path'))
        : await client.postUrl(Uri.parse('$base$path'));
    if (token != null) request.headers.set('Authorization', 'Bearer $token');
    if (body != null) {
      request.headers.contentType = ContentType.json;
      request.write(jsonEncode(body));
    }
    final response = await request.close();
    final data = jsonDecode(
      await utf8.decoder.bind(response).join(),
    ) as Map<String, dynamic>;
    if (response.statusCode != 200) {
      throw StateError('$path: ${response.statusCode} ${data['error']}');
    }
    return data;
  }

  try {
    final health = await request('/health');
    if (!(health['games'] as List).contains('words')) {
      stdout.writeln('New games are still deploying.');
      return;
    }
    for (final type in ['darts', 'words', 'connect']) {
      final host = await request('/rooms', {'players': 2, 'gameType': type});
      final code = host['code'];
      final guest = await request('/rooms/$code/join', {});
      final tokens = [host['token'] as String, guest['token'] as String];
      var snapshot = guest;
      var game = restoreGame(type, snapshot['game'] as Map<String, dynamic>);
      var count = 0;
      while (!game.finished) {
        final move = type == 'connect'
            ? ['0', '1', '0', '1', '0', '1', '0'][count]
            : type == 'words' && count < 3
            ? ['0:C', '1:A', '2:T'][count]
            : game.legalMoves.first;
        snapshot = await request('/rooms/$code/moves', {
          'move': move,
          'revision': snapshot['revision'],
        }, tokens[game.turn]);
        game = restoreGame(type, snapshot['game'] as Map<String, dynamic>);
        count++;
      }
      final other = await request('/rooms/$code', null, tokens[1]);
      if (jsonEncode(other['game']) != jsonEncode(snapshot['game'])) {
        throw StateError('$type boards differ');
      }
      final rematch = await request('/rooms/$code/restart', {
        'revision': snapshot['revision'],
      }, tokens[0]);
      if (restoreGame(type, rematch['game'] as Map<String, dynamic>).finished ||
          rematch['round'] != 2 ||
          jsonEncode(rematch['series']) != jsonEncode(snapshot['series'])) {
        throw StateError('$type rematch failed');
      }
      stdout.writeln(
        '$type verified: $count moves, synchronized result and rematch record.',
      );
    }
  } finally {
    client.close(force: true);
  }
}
