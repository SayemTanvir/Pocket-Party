import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_party/games/dots_game.dart';

void main() {
  test('Completing a box scores a point and retains the turn', () {
    final game = DotsGame(size: 2);
    game.play('h:0:0');
    game.play('v:0:0');
    game.play('h:1:0');
    expect(game.turn, 1);
    expect(game.play('v:0:1'), isTrue);
    expect(game.scores, [0, 1]);
    expect(game.turn, 1);
    expect(game.finished, isTrue);
    expect(game.play('v:0:1'), isFalse);
  });
  test('Duplicate and invalid moves leave the turn unchanged', () {
    final game = DotsGame(players: 4);
    game.play('h:0:0');
    expect(game.play('h:0:0'), isFalse);
    expect(game.play('h:99:99'), isFalse);
    expect(game.turn, 1);
    expect(game.edges.length, 1);
  });
}
