import 'dart:math';

import 'chess_game.dart';

class ChessClock {
  ChessClock(this.seconds, {int Function()? now})
    : remainingMs = List.filled(2, seconds * 1000),
      _providedNow = now;
  final int seconds;
  final List<int> remainingMs;
  final int Function()? _providedNow;
  final Stopwatch _watch = Stopwatch()..start();
  bool running = false;
  int _last = 0;
  int get _now => _providedNow?.call() ?? _watch.elapsedMilliseconds;
  void start() {
    running = true;
    _last = _now;
  }

  void settle(ChessGame game) {
    if (!running || game.finished) return;
    final now = _now;
    remainingMs[game.turn] = max(
      0,
      remainingMs[game.turn] - max(0, now - _last),
    );
    _last = now;
    if (remainingMs[game.turn] == 0) game.loseOnTime(game.turn);
  }

  Map<String, dynamic> toJson() => {
    'seconds': seconds,
    'remainingMs': remainingMs,
    'running': running,
  };
}
