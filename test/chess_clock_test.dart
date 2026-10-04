import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_party/games/chess_game.dart';
import 'package:pocket_party/games/chess_clock.dart';
import 'package:pocket_party/games/match_series.dart';

void main() {
  test('Clock waits for start and charges only the active player', () {
    var now = 0;
    final game = ChessGame();
    final clock = ChessClock(60, now: () => now);
    now = 10000;
    clock.settle(game);
    expect(clock.remainingMs, [60000, 60000]);
    clock.start();
    now += 1250;
    clock.settle(game);
    expect(clock.remainingMs, [58750, 60000]);
    game.play('e2e4');
    now += 2250;
    clock.settle(game);
    expect(clock.remainingMs, [58750, 57750]);
    now += 60000;
    clock.settle(game);
    expect(game.finished, isTrue);
    expect(game.winner, 0);
    expect(game.result, 'White wins on time!');
    expect(game.play('e7e5'), isFalse);
    expect(ChessGame.fromJson(game.toJson()).winner, 0);
  });
  test('A clock cannot change an already completed game', () {
    var now = 0;
    final game = ChessGame();
    final clock = ChessClock(60, now: () => now)..start();
    for (final move in ['f2f3', 'e7e5', 'g2g4', 'd8h4']) {
      game.play(move);
    }
    now = 100000;
    clock.settle(game);
    expect(game.result, 'Black wins by checkmate!');
    expect(game.timeoutLoser, isNull);
  });
  test('Timeout against a bare king is a draw', () {
    final game = ChessGame(fen: '7k/8/8/8/8/8/6Q1/7K w - - 0 1');
    game.loseOnTime(0);
    expect(game.finished, isTrue);
    expect(game.winner, isNull);
    expect(game.timeoutDraw, isTrue);
  });
  test(
    'Series records completed results and retains them for the next game',
    () {
      final series = MatchSeries(2);
      series.record(ChessGame());
      expect(series.wins, [0, 0]);
      final game = ChessGame()..loseOnTime(0);
      series.record(game);
      expect(series.wins, [0, 1]);
      expect(series.losses, [1, 0]);
      final draw = ChessGame(fen: '7k/8/8/8/8/8/8/7K w - - 0 1');
      series.record(draw);
      final restored = MatchSeries.fromJson(series.toJson());
      expect(restored.wins, [0, 1]);
      expect(restored.draws, [1, 1]);
    },
  );
}
