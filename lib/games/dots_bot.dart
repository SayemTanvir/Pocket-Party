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
    // A box with three sides gives the next player an immediate capture.
    // Scan boxes once instead of copying the board for every possible reply.
    var givesBox = false;
    for (var row = 0; row < next.size - 1 && !givesBox; row++) {
      for (var col = 0; col < next.size - 1; col++) {
        if (next.boxes.containsKey('$row:$col')) continue;
        final sides = [
          next.edge(true, row, col),
          next.edge(true, row + 1, col),
          next.edge(false, row, col),
          next.edge(false, row, col + 1),
        ].where(next.edges.contains).length;
        if (sides == 3) {
          givesBox = true;
          break;
        }
      }
    }
    if (!givesBox) safe.add(move);
  }
  return safe.isNotEmpty ? safe.first : moves.first;
}
