import 'dart:convert';
import 'dart:io';

import 'package:pocket_party/games/chess_game.dart';

// A real HTTP smoke test: two seats, checkmate, synchronized boards, rematch.
Future<void> main(List<String> args) async {
  final base = args.isEmpty ? 'http://127.0.0.1:8787' : args.single;
  final client = HttpClient();
  Future<Map<String, dynamic>> post(
    String path,
    Map<String, dynamic> body, [
    String? token,
  ]) async {
    final request = await client.postUrl(Uri.parse('$base$path'));
    request.headers.contentType = ContentType.json;
    if (token != null) request.headers.set('Authorization', 'Bearer $token');
    request.write(jsonEncode(body));
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
    final host = await post('/rooms', {'players': 2, 'gameType': 'chess'});
    if (host['gameType'] != 'chess') {
      throw StateError('Server has not deployed chess yet');
    }
    final code = host['code'];
    final guest = await post('/rooms/$code/join', {});
    final tokens = [host['token'] as String, guest['token'] as String];
    var snapshot = guest;
    var index = 0;
    for (final move in ['f2f3', 'e7e5', 'g2g4', 'd8h4']) {
      snapshot = await post('/rooms/$code/moves', {
        'move': move,
        'revision': snapshot['revision'],
      }, tokens[index++ % 2]);
    }
    final game = ChessGame.fromJson(snapshot['game'] as Map<String, dynamic>);
    if (!game.finished || game.result != 'Black wins by checkmate!') {
      throw StateError('Checkmate was not recorded');
    }
    for (final token in tokens) {
      final request = await client.getUrl(Uri.parse('$base/rooms/$code'));
      request.headers.set('Authorization', 'Bearer $token');
      final response = await request.close();
      final data = jsonDecode(
        await utf8.decoder.bind(response).join(),
      ) as Map<String, dynamic>;
      if (jsonEncode(data['game']) != jsonEncode(snapshot['game'])) {
        throw StateError('Boards differ');
      }
    }
    final rematch = await post('/rooms/$code/restart', {
      'revision': snapshot['revision'],
    }, tokens[0]);
    if ((rematch['game']['moves'] as List).isNotEmpty) {
      throw StateError('Rematch did not reset');
    }
    stdout.writeln(
      'Chess verified: two seats, four legal moves, checkmate, synchronized boards and rematch.',
    );
  } finally {
    client.close(force: true);
  }
}
