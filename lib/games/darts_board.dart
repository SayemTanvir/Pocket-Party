import 'dart:math';

import 'package:flutter/material.dart';

import 'arcade_rules.dart';

class DartsBoard extends StatefulWidget {
  const DartsBoard({
    super.key,
    required this.enabled,
    required this.onThrow,
    this.lastThrow,
  });
  final bool enabled;
  final ValueChanged<String> onThrow;
  final String? lastThrow;
  @override
  State<DartsBoard> createState() => _DartsBoardState();
}

class _DartsBoardState extends State<DartsBoard>
    with SingleTickerProviderStateMixin {
  late final AnimationController motion = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 18),
    value: Random().nextDouble(),
  )..repeat();
  @override
  void initState() {
    super.initState();
    if (!widget.enabled) motion.stop();
  }

  @override
  void didUpdateWidget(DartsBoard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.enabled && !oldWidget.enabled) {
      motion.repeat();
    }
    if (!widget.enabled && oldWidget.enabled) {
      motion.stop();
    }
  }

  Offset get sight {
    final phase = motion.value * 2 * pi;
    // Sweeping through the centre while rotating reaches every part of the
    // circular scoring area, with a continuous path at the animation loop.
    final radius = .99 * sin(phase * 7);
    final angle = phase * 3 + .35 * sin(phase * 2);
    return Offset(cos(angle) * radius, sin(angle) * radius);
  }

  void throwDart() {
    if (!widget.enabled) return;
    widget.onThrow(
      '${(sight.dx * 1000).round().clamp(-1250, 1250)}:${(sight.dy * 1000).round().clamp(-1250, 1250)}',
    );
  }

  @override
  void dispose() {
    motion.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Column(
    children: [
      AspectRatio(
        aspectRatio: 1,
        child: LayoutBuilder(
          builder: (context, size) => Stack(
            fit: StackFit.expand,
            children: [
              RepaintBoundary(
                child: CustomPaint(
                  painter: _DartPainter(lastThrow: widget.lastThrow),
                ),
              ),
              AnimatedBuilder(
                animation: motion,
                builder: (_, child) => Semantics(
                  label: 'Dartboard. Tap to throw at the moving aim marker.',
                  child: GestureDetector(
                    onPanEnd: widget.enabled ? (_) => throwDart() : null,
                    onTapUp: widget.enabled ? (_) => throwDart() : null,
                    child: CustomPaint(
                      painter: _AimPainter(widget.enabled ? sight : null),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      const SizedBox(height: 12),
      SizedBox(
        width: double.infinity,
        child: FilledButton.icon(
          onPressed: widget.enabled ? throwDart : null,
          icon: const Icon(Icons.near_me_rounded),
          label: const Text('Throw dart'),
        ),
      ),
      const SizedBox(height: 8),
      const Text(
        'Time your throw · tap the board or Throw dart',
        style: TextStyle(color: Colors.white60),
      ),
    ],
  );
}

class _DartPainter extends CustomPainter {
  const _DartPainter({this.lastThrow});
  final String? lastThrow;
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width * .41;
    canvas.drawCircle(
      center,
      radius * 1.19,
      Paint()..color = const Color(0xFF202B3B),
    );
    for (var i = 0; i < 20; i++) {
      final start = -pi / 2 - pi / 20 + i * pi / 10;
      for (final ring in [
        (1.0, .92, true),
        (.92, .64, false),
        (.64, .56, true),
        (.56, .12, false),
      ]) {
        final color = ring.$3
            ? (i.isEven ? const Color(0xFFFF718F) : const Color(0xFF4FD5B0))
            : (i.isEven ? const Color(0xFF172131) : const Color(0xFFE4DDCC));
        final path = Path()
          ..moveTo(
            center.dx + cos(start) * radius * ring.$1,
            center.dy + sin(start) * radius * ring.$1,
          )
          ..arcTo(
            Rect.fromCircle(center: center, radius: radius * ring.$1),
            start,
            pi / 10,
            false,
          )
          ..arcTo(
            Rect.fromCircle(center: center, radius: radius * ring.$2),
            start + pi / 10,
            -pi / 10,
            false,
          )
          ..close();
        canvas.drawPath(path, Paint()..color = color);
        canvas.drawPath(
          path,
          Paint()
            ..color = const Color(0x6638495D)
            ..style = PaintingStyle.stroke
            ..strokeWidth = .5,
        );
      }
      final angle = -pi / 2 + i * pi / 10;
      final label = TextPainter(
        text: TextSpan(
          text: '${DartsGame.sectors[i]}',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: size.width * .035,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      label.paint(
        canvas,
        center +
            Offset(cos(angle), sin(angle)) * radius * 1.09 -
            Offset(label.width / 2, label.height / 2),
      );
    }
    canvas.drawCircle(
      center,
      radius * .12,
      Paint()..color = const Color(0xFF4FD5B0),
    );
    canvas.drawCircle(
      center,
      radius * .05,
      Paint()..color = const Color(0xFFFF718F),
    );
    if (lastThrow != null) {
      final point = lastThrow!.split(':').map(int.parse).toList();
      final hit = center + Offset(point[0] / 1000, point[1] / 1000) * radius;
      canvas.drawCircle(hit, 6, Paint()..color = Colors.amber);
      canvas.drawLine(
        hit,
        hit + const Offset(12, -20),
        Paint()
          ..color = Colors.white
          ..strokeWidth = 3,
      );
    }
  }

  @override
  bool shouldRepaint(_DartPainter oldDelegate) =>
      oldDelegate.lastThrow != lastThrow;
}

class _AimPainter extends CustomPainter {
  const _AimPainter(this.sight);
  final Offset? sight;
  @override
  void paint(Canvas canvas, Size size) {
    if (sight == null) return;
    final point =
        Offset(size.width / 2, size.height / 2) + sight! * size.width * .41;
    final paint = Paint()
      ..color = Colors.white
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    canvas.drawCircle(point, 10, paint);
    canvas.drawLine(
      point - const Offset(16, 0),
      point + const Offset(16, 0),
      paint,
    );
    canvas.drawLine(
      point - const Offset(0, 16),
      point + const Offset(0, 16),
      paint,
    );
  }

  @override
  bool shouldRepaint(_AimPainter oldDelegate) => oldDelegate.sight != sight;
}
