import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_party/games/dots_game.dart';

void main() {
  test(
    'A large board supports a double capture and preserves its snapshot',
    () {
      final game = DotsGame();
      expect(game.legalMoves.length, 84);
      for (final move in [
        'h:5:4',
        'h:6:4',
        'v:5:4',
        'h:5:5',
        'h:6:5',
        'v:5:6',
      ]) {
        expect(game.play(move), isTrue);
      }
      final player = game.turn;
      expect(game.play('v:5:5'), isTrue);
      expect(game.scores[player], 2);
      expect(game.turn, player);
      final restored = DotsGame.fromJson(game.toJson());
      expect(restored.size, 7);
      expect(restored.toJson(), game.toJson());
    },
  );
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
