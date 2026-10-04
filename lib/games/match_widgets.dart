import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'match_series.dart';

class TimeControlPicker extends StatelessWidget {
  const TimeControlPicker({
    super.key,
    required this.seconds,
    required this.onChanged,
  });
  final int seconds;
  final ValueChanged<int>? onChanged;
  @override
  Widget build(BuildContext context) => DropdownButtonFormField<int>(
    initialValue: seconds,
    decoration: const InputDecoration(
      labelText: 'Chess timer',
      border: OutlineInputBorder(),
      helperText: 'Time per player · no increment',
    ),
    items: [
      for (final n in [0, 60, 180, 300, 600])
        DropdownMenuItem(
          value: n,
          child: Text(
            n == 0
                ? 'No timer'
                : '${n ~/ 60} ${n == 60 ? 'minute' : 'minutes'} per player',
          ),
        ),
    ],
    onChanged: onChanged == null ? null : (value) => onChanged!(value!),
  );
}

class SeriesScore extends StatelessWidget {
  const SeriesScore({
    super.key,
    required this.series,
    required this.labels,
    this.player,
  });
  final MatchSeries series;
  final List<String> labels;
  final int? player;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 12),
    child: Column(
      children: [
        Text(
          player == null
              ? 'This series · Wins / Losses / Draws'
              : 'Your record · Wins / Losses / Draws',
          style: Theme.of(context).textTheme.labelLarge,
        ),
        const SizedBox(height: 6),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 12,
          runSpacing: 6,
          children: [
            for (var p = 0; p < labels.length; p++)
              if (player == null || p == player)
                Text(
                  '${labels[p]}: ${series.wins[p]} / ${series.losses[p]} / ${series.draws[p]}',
                ),
          ],
        ),
      ],
    ),
  );
}

class ChessClocks extends StatelessWidget {
  const ChessClocks({
    super.key,
    required this.remainingMs,
    required this.turn,
    required this.finished,
  });
  final List<int> remainingMs;
  final int turn;
  final bool finished;
  String format(int ms) {
    final seconds = (ms + 999) ~/ 1000;
    return '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: Row(
      children: [
        for (var p = 0; p < 2; p++)
          Expanded(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 4),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: !finished && p == turn
                    ? const Color(0xFF284B42)
                    : const Color(0xFF202B38),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  Text(p == 0 ? 'White' : 'Black'),
                  Text(
                    format(remainingMs[p]),
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      color: remainingMs[p] < 10000
                          ? const Color(0xFFFF83A5)
                          : Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    ),
  );
}

Future<void> celebrateMatch(
  BuildContext context, {
  required String title,
  required bool draw,
  VoidCallback? playAgain,
  ValueChanged<DialogRoute<void>>? onRoute,
}) {
  final route = DialogRoute<void>(
    context: context,
    builder: (_) =>
        _Celebration(title: title, draw: draw, playAgain: playAgain),
  );
  onRoute?.call(route);
  return Navigator.of(context).push(route);
}

class _Celebration extends StatefulWidget {
  const _Celebration({required this.title, required this.draw, this.playAgain});
  final String title;
  final bool draw;
  final VoidCallback? playAgain;
  @override
  State<_Celebration> createState() => _CelebrationState();
}

class _CelebrationState extends State<_Celebration>
    with SingleTickerProviderStateMixin {
  late final AnimationController animation = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2200),
  );
  bool reduced = false;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    reduced = MediaQuery.disableAnimationsOf(context);
    if (!animation.isAnimating && animation.value == 0 && !reduced) {
      animation.forward();
      if (!widget.draw) HapticFeedback.heavyImpact();
    }
  }

  @override
  void dispose() {
    animation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: animation,
    builder: (_, child) => Stack(
      children: [
        if (!reduced && !widget.draw)
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(painter: _Confetti(animation.value)),
            ),
          ),
        Center(
          child: Transform.translate(
            offset: Offset(
              reduced
                  ? 0
                  : sin(animation.value * pi * 24) *
                        7 *
                        max(0, 1 - animation.value * 4),
              0,
            ),
            child: AlertDialog(
              icon: Icon(
                widget.draw ? Icons.handshake : Icons.emoji_events,
                size: 64,
                color: const Color(0xFFFFC76B),
              ),
              title: Text(widget.title, textAlign: TextAlign.center),
              content: Text(
                widget.draw
                    ? 'A close contest. Ready for another round?'
                    : 'Well played! Your series record has been updated.',
                textAlign: TextAlign.center,
              ),
              actionsAlignment: MainAxisAlignment.center,
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('View board'),
                ),
                if (widget.playAgain != null)
                  FilledButton(
                    onPressed: () {
                      Navigator.pop(context);
                      widget.playAgain!();
                    },
                    child: const Text('Play again'),
                  ),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}

class _Confetti extends CustomPainter {
  const _Confetti(this.progress);
  final double progress;
  @override
  void paint(Canvas canvas, Size size) {
    if (progress >= 1) return;
    final random = Random(19);
    const colors = [
      Color(0xFF68E0C2),
      Color(0xFFFFBC73),
      Color(0xFFB7A0FF),
      Color(0xFFFF83A5),
    ];
    for (var i = 0; i < 75; i++) {
      final x = random.nextDouble() * size.width;
      final y =
          -random.nextDouble() * size.height * .6 +
          progress * size.height * 1.8;
      canvas.save();
      canvas.translate(x + sin(progress * 8 + i) * 24, y);
      canvas.rotate(progress * 8 + i);
      canvas.drawRect(
        const Rect.fromLTWH(-3, -5, 6, 10),
        Paint()..color = colors[i % 4].withValues(alpha: 1 - progress),
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_Confetti oldDelegate) => progress != oldDelegate.progress;
}
