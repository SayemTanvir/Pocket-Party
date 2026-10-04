import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_party/games/arcade_rules.dart';
import 'package:pocket_party/games/match_series.dart';

void main() {
  test('Darts scores rings, bulls, misses and rejects invalid coordinates', () {
    expect(DartsGame.scoreAt(0, 0), 50);
    expect(DartsGame.scoreAt(0, 100), 25);
    expect(DartsGame.scoreAt(0, -600), 60);
    expect(DartsGame.scoreAt(0, -950), 40);
    expect(DartsGame.scoreAt(0, -800), 20);
    expect(DartsGame.scoreAt(1200, 0), 0);
    final game = DartsGame();
    expect(game.play('9999:0'), isFalse);
    expect(game.play('NaN:0'), isFalse);
    expect(game.throws, isEmpty);
  });
  test(
    'Darts gives everyone fifteen throws and preserves scores in snapshots',
    () {
      final game = DartsGame(players: 4);
      for (var i = 0; i < 60; i++) {
        expect(game.turn, (i ~/ 3) % 4);
        expect(game.play('0:0'), isTrue);
      }
      expect(game.finished, isTrue);
      expect(game.scores, [750, 750, 750, 750]);
      expect(game.play('0:0'), isFalse);
      expect(DartsGame.fromJson(game.toJson()).scores, game.scores);
    },
  );
  test(
    'A word scores its length once and occupied tiles cannot be replaced',
    () {
      final game = WordGame();
      for (final move in ['0:C', '1:A', '2:T']) {
        expect(game.play(move), isTrue);
      }
      expect(game.lastWords, ['CAT']);
      expect(game.scores, [3, 0]);
      expect(game.play('2:S'), isFalse);
      expect(game.play('25:A'), isFalse);
      for (final move in ['5:C', '6:A', '7:T']) {
        game.play(move);
      }
      expect(game.scores, [3, 0]);
      expect(game.lastWords, isEmpty);
      expect(WordGame.fromJson(game.toJson()).scores, game.scores);
    },
  );
  test('One letter can score two crossing words', () {
    final game = WordGame();
    for (final move in ['5:C', '7:T', '1:B', '11:T', '6:A']) {
      game.play(move);
    }
    expect(game.lastWords, unorderedEquals(['CAT', 'BAT']));
    expect(game.scores, [6, 0]);
  });
  test('Connect Four detects horizontal, vertical and diagonal wins', () {
    for (final moves in [
      [0, 0, 1, 1, 2, 2, 3],
      [0, 1, 0, 1, 0, 1, 0],
      [0, 1, 1, 2, 4, 2, 2, 3, 4, 3, 5, 3, 3],
    ]) {
      final game = ConnectGame();
      for (final col in moves) {
        expect(game.play('$col'), isTrue);
      }
      expect(game.winner, 0);
      expect(game.winningCells.length, 4);
      expect(game.play('5'), isFalse);
      expect(ConnectGame.fromJson(game.toJson()).winner, 0);
      final series = MatchSeries(2)..record(game);
      expect(series.wins, [1, 0]);
    }
  });
  test(
    'Connect Four rejects full columns and its bot blocks a winning threat',
    () {
      final full = ConnectGame();
      for (var i = 0; i < 6; i++) {
        full.play('0');
      }
      expect(full.play('0'), isFalse);
      final game = ConnectGame();
      for (final col in [0, 6, 1, 6, 2]) {
        game.play('$col');
      }
      expect(chooseArcadeMove({'type': 'connect', 'game': game.toJson()}), '3');
    },
  );
  test('Word bot completes a word without modifying its input', () {
    final game = WordGame()
      ..play('0:C')
      ..play('1:A');
    final move = chooseArcadeMove({'type': 'words', 'game': game.toJson()});
    expect(game.history.length, 2);
    expect(game.play(move), isTrue);
    expect(game.scores[0], greaterThanOrEqualTo(3));
  });
}
