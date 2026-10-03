import 'dart:math';

import 'dots_game.dart';

String chooseBotMove(DotsGame game, {Random? random}) {
  final rng = random ?? Random();
  final moves = game.legalMoves;
  if (moves.isEmpty) throw StateError('No legal moves');
  moves.shuffle(rng);
  final safe = <String>[];
  for (final move in moves) {
    final next = game.copy();
    final before = next.scores[next.turn];
    next.play(move);
    if (next.scores[game.turn] > before) return move;
    final givesBox = next.legalMoves.any((reply) {
      final trial = next.copy();
      final score = trial.scores[trial.turn];
      final player = trial.turn;
      trial.play(reply);
      return trial.scores[player] > score;
    });
    if (!givesBox) safe.add(move);
  }
  return safe.isNotEmpty ? safe.first : moves.first;
}
