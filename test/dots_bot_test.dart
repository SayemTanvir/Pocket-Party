import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_party/games/dots_game.dart';
import 'package:pocket_party/games/dots_bot.dart';

void main() {
  test('Bot claims an available box without mutating the board', () {
    final game = DotsGame(size: 2);
    for (final move in ['h:0:0', 'h:1:0', 'v:0:0']) {
      game.play(move);
    }
    expect(chooseBotMove(game, random: Random(1)), 'v:0:1');
    expect(game.edges.length, 3);
    expect(game.boxes, isEmpty);
  });
  test('Bot avoids giving away a box when safe moves exist', () {
    final game = DotsGame(size: 3);
    game.play('h:0:0');
    game.play('v:0:0');
    final move = chooseBotMove(game, random: Random(3));
    expect(move, isNot(anyOf('h:1:0', 'v:0:1')));
    expect(game.legalMoves, contains(move));
  });
}
