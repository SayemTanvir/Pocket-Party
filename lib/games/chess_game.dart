import 'dart:math';

import 'package:chess/chess.dart' as rules;

import 'party_game.dart';

class ChessGame implements PartyGame {
  ChessGame({String? fen})
    : initialFen = fen,
      engine = fen == null ? rules.Chess() : rules.Chess.fromFEN(fen);
  final String? initialFen;
  final rules.Chess engine;
  final List<String> history = [];
  int? timeoutLoser;
  bool timeoutDraw = false;
  int? get winner => timeoutLoser != null
      ? (timeoutDraw ? null : 1 - timeoutLoser!)
      : engine.in_checkmate
      ? 1 - turn
      : null;
  void loseOnTime(int player) {
    if (finished) return;
    timeoutLoser = player;
    final opponent = player == 0 ? rules.Color.BLACK : rules.Color.WHITE;
    final pieces = engine.board
        .whereType<rules.Piece>()
        .where((p) => p.color == opponent)
        .toList();
    final loserPieces = engine.board
        .whereType<rules.Piece>()
        .where((p) => p.color != opponent)
        .length;
    timeoutDraw =
        pieces.length == 1 ||
        (loserPieces == 1 &&
            pieces.length == 2 &&
            [
              'b',
              'n',
            ].contains(pieces.firstWhere((p) => p.type.name != 'k').type.name));
  }

  @override
  int get players => 2;
  @override
  int get turn => engine.turn == rules.Color.WHITE ? 0 : 1;
  @override
  bool get finished => timeoutLoser != null || engine.game_over;
  bool get check => engine.in_check;
  String get result => timeoutLoser != null
      ? timeoutDraw
            ? 'Draw on time: no mating material'
            : '${winner == 0 ? 'White' : 'Black'} wins on time!'
      : engine.in_checkmate
      ? '${turn == 0 ? 'Black' : 'White'} wins by checkmate!'
      : engine.in_stalemate
      ? 'Draw by stalemate'
      : 'Draw';
  List<String> get notation => engine.getHistory().cast<String>();
  @override
  List<String> get legalMoves => finished
      ? []
      : engine
            .generate_moves()
            .map(
              (m) =>
                  '${m.fromAlgebraic}${m.toAlgebraic}${m.promotion?.name ?? ''}',
            )
            .toList();
  String? pieceAt(String square) {
    final piece = engine.get(square);
    if (piece == null) return null;
    return piece.color == rules.Color.WHITE
        ? piece.type.name.toUpperCase()
        : piece.type.name;
  }

  @override
  bool play(String move) {
    if (!legalMoves.contains(move)) return false;
    engine.move({
      'from': move.substring(0, 2),
      'to': move.substring(2, 4),
      if (move.length == 5) 'promotion': move[4],
    });
    history.add(move);
    return true;
  }

  @override
  Map<String, dynamic> toJson() => {
    'initialFen': initialFen,
    'moves': history,
    'timeoutLoser': timeoutLoser,
    'timeoutDraw': timeoutDraw,
  };
  factory ChessGame.fromJson(Map<String, dynamic> data) {
    final game = ChessGame(fen: data['initialFen'] as String?);
    for (final move in (data['moves'] as List).cast<String>()) {
      if (!game.play(move)) {
        throw const FormatException('Invalid chess history');
      }
    }
    game.timeoutLoser = data['timeoutLoser'] as int?;
    game.timeoutDraw = data['timeoutDraw'] as bool? ?? false;
    return game;
  }
}

// Runs in an isolate on mobile so searching does not block board interactions.
String chooseChessBotMove(Map<String, dynamic> snapshot) {
  final game = ChessGame.fromJson(snapshot);
  final engine = game.engine;
  final side = engine.turn;
  const values = {'p': 100, 'n': 320, 'b': 330, 'r': 500, 'q': 900, 'k': 0};
  int evaluate() {
    if (engine.in_checkmate) return engine.turn == side ? -100000 : 100000;
    if (engine.in_draw) return 0;
    var score = 0;
    for (final piece in engine.board) {
      if (piece != null) {
        score += (piece.color == side ? 1 : -1) * values[piece.type.name]!;
      }
    }
    return score;
  }

  final candidates = engine.generate_moves()..shuffle(Random());
  var best = -1000000;
  String chosen = '';
  for (final move in candidates) {
    engine.move(move);
    var score = evaluate();
    if (!engine.game_over) {
      score = 1000000;
      for (final reply in engine.generate_moves()) {
        engine.move(reply);
        score = min(score, evaluate());
        engine.undo();
      }
    }
    engine.undo();
    if (score > best) {
      best = score;
      chosen =
          '${move.fromAlgebraic}${move.toAlgebraic}${move.promotion?.name ?? ''}';
    }
  }
  return chosen;
}
