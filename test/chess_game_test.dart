import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_party/games/chess_game.dart';

void main() {
  test('Chess rejects illegal moves and ends at checkmate', () {
    final game = ChessGame();
    expect(game.legalMoves.length, 20);
    expect(game.play('e2e5'), isFalse);
    for (final move in ['f2f3', 'e7e5', 'g2g4', 'd8h4']) {
      expect(game.play(move), isTrue);
    }
    expect(game.finished, isTrue);
    expect(game.result, 'Black wins by checkmate!');
    expect(game.play('a2a3'), isFalse);
    expect(ChessGame.fromJson(game.toJson()).engine.fen, game.engine.fen);
  });
  test('Castling moves both king and rook', () {
    final game = ChessGame(fen: 'r3k2r/8/8/8/8/8/8/R3K2R w KQkq - 0 1');
    expect(game.play('e1g1'), isTrue);
    expect(game.pieceAt('g1'), 'K');
    expect(game.pieceAt('f1'), 'R');
    expect(game.pieceAt('h1'), isNull);
  });
  test('En passant removes the captured pawn', () {
    final game = ChessGame();
    for (final move in ['e2e4', 'a7a6', 'e4e5', 'd7d5', 'e5d6']) {
      expect(game.play(move), isTrue);
    }
    expect(game.pieceAt('d5'), isNull);
    expect(game.pieceAt('d6'), 'P');
  });
  test('Promotion supports all four pieces', () {
    for (final piece in ['q', 'r', 'b', 'n']) {
      final game = ChessGame(fen: '7k/P7/8/8/8/8/8/7K w - - 0 1');
      expect(game.play('a7a8$piece'), isTrue);
      expect(game.pieceAt('a8'), piece.toUpperCase());
    }
  });
  test('Replaying history preserves threefold repetition', () {
    final game = ChessGame();
    for (var i = 0; i < 2; i++) {
      for (final move in ['g1f3', 'g8f6', 'f3g1', 'f6g8']) {
        expect(game.play(move), isTrue);
      }
    }
    expect(ChessGame.fromJson(game.toJson()).finished, isTrue);
  });
  test('Beginner bot takes mate and leaves source board unchanged', () {
    final game = ChessGame();
    for (final move in ['f2f3', 'e7e5', 'g2g4']) {
      game.play(move);
    }
    final fen = game.engine.fen;
    expect(chooseChessBotMove(game.toJson()), 'd8h4');
    expect(game.engine.fen, fen);
  });
}
