import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../online/online_session.dart';
import 'chess_game.dart';

class ChessPage extends StatefulWidget {
  const ChessPage({super.key, this.bot = false, this.online});
  final bool bot;
  final OnlineSession? online;
  @override
  State<ChessPage> createState() => _ChessPageState();
}

class _ChessPageState extends State<ChessPage> {
  late ChessGame game;
  String? selected;
  bool flipped = false;
  bool thinking = false;
  int generation = 0;
  @override
  void initState() {
    super.initState();
    game = widget.online?.chessGame ?? ChessGame();
    flipped = widget.online?.player == 1;
    widget.online?.addListener(sync);
  }

  void sync() {
    if (!mounted) return;
    setState(() {
      final next = widget.online!.chessGame;
      if (next.engine.fen != game.engine.fen) selected = null;
      game = next;
    });
  }

  @override
  void dispose() {
    generation++;
    widget.online?.removeListener(sync);
    widget.online?.dispose();
    super.dispose();
  }

  bool get canMove =>
      !game.finished &&
      !thinking &&
      (widget.online?.canMove ?? (!widget.bot || game.turn == 0));
  Future<void> tap(String square) async {
    if (!canMove) return;
    final moves = game.legalMoves
        .where((m) => m.startsWith('${selected ?? '-'}$square'))
        .toList();
    if (moves.isEmpty) {
      setState(
        () => selected = game.legalMoves.any((m) => m.startsWith(square))
            ? square
            : null,
      );
      return;
    }
    var move = moves.first;
    if (moves.length > 1) {
      final revision = game.history.length;
      final promotion = await showDialog<String>(
        context: context,
        builder: (context) => SimpleDialog(
          title: const Text('Promote pawn'),
          children: [
            for (final entry in {
              'q': 'Queen',
              'r': 'Rook',
              'b': 'Bishop',
              'n': 'Knight',
            }.entries)
              SimpleDialogOption(
                onPressed: () => Navigator.pop(context, entry.key),
                child: Text(entry.value),
              ),
          ],
        ),
      );
      if (!mounted ||
          promotion == null ||
          revision != game.history.length ||
          !canMove) {
        return;
      }
      move = '${move.substring(0, 4)}$promotion';
    }
    setState(() => selected = null);
    if (widget.online != null) {
      await widget.online!.move(move);
    } else {
      setState(() => game.play(move));
      if (widget.bot && !game.finished) {
        setState(() => thinking = true);
        final current = generation;
        final reply = await compute(chooseChessBotMove, game.toJson());
        if (!mounted || current != generation) return;
        setState(() {
          game.play(reply);
          thinking = false;
        });
      }
    }
  }

  String get status {
    final online = widget.online;
    if (online != null) {
      if (online.expired) return 'Room unavailable';
      if (!online.connected) return 'Reconnecting…';
      if (!online.ready) return 'Waiting for your friend';
      if (online.busy) return 'Sending move…';
    }
    if (game.finished) return game.result;
    if (thinking) return 'Bot is thinking…';
    return '${game.turn == 0 ? 'White' : 'Black'} to move${game.check ? ' · Check!' : ''}';
  }

  static const glyphs = {
    'K': '♚',
    'Q': '♛',
    'R': '♜',
    'B': '♝',
    'N': '♞',
    'P': '♟',
    'k': '♚',
    'q': '♛',
    'r': '♜',
    'b': '♝',
    'n': '♞',
    'p': '♟',
  };
  static const names = {
    'k': 'king',
    'q': 'queen',
    'r': 'rook',
    'b': 'bishop',
    'n': 'knight',
    'p': 'pawn',
  };
  @override
  Widget build(BuildContext context) {
    final legal = game.legalMoves;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Chess'),
        actions: [
          IconButton(
            tooltip: 'Flip board',
            onPressed: () => setState(() => flipped = !flipped),
            icon: const Icon(Icons.swap_vert),
          ),
          if (widget.online == null)
            IconButton(
              tooltip: 'Restart game',
              onPressed: () => setState(() {
                generation++;
                game = ChessGame();
                selected = null;
                thinking = false;
              }),
              icon: const Icon(Icons.refresh),
            ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Column(
                children: [
                  if (widget.online != null) ...[
                    Text(
                      'You play ${widget.online!.player == 0 ? 'White' : 'Black'}',
                    ),
                    TextButton.icon(
                      icon: const Icon(Icons.copy),
                      label: Text('Room ${widget.online!.code} · copy code'),
                      onPressed: () async {
                        await Clipboard.setData(
                          ClipboardData(text: widget.online!.code),
                        );
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Room code copied')),
                          );
                        }
                      },
                    ),
                    if (widget.online!.error != null)
                      Text(
                        widget.online!.error!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                  ],
                  Text(
                    status,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 20),
                  AspectRatio(
                    aspectRatio: 1,
                    child: LayoutBuilder(
                      builder: (context, size) => GridView.builder(
                        physics: const NeverScrollableScrollPhysics(),
                        padding: EdgeInsets.zero,
                        itemCount: 64,
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 8,
                            ),
                        itemBuilder: (context, index) {
                          final row = flipped ? 7 - index ~/ 8 : index ~/ 8;
                          final col = flipped ? 7 - index % 8 : index % 8;
                          final square =
                              '${String.fromCharCode(97 + col)}${8 - row}';
                          final piece = game.pieceAt(square);
                          final target =
                              selected != null &&
                              legal.any(
                                (m) => m.startsWith('$selected$square'),
                              );
                          final last = game.history.isEmpty
                              ? ''
                              : game.history.last;
                          final recent =
                              last.startsWith(square) ||
                              (last.length >= 4 &&
                                  last.substring(2, 4) == square);
                          final white =
                              piece != null && piece == piece.toUpperCase();
                          return Semantics(
                            key: ValueKey(square),
                            excludeSemantics: true,
                            button: true,
                            label:
                                '$square${piece == null ? ' empty' : ' ${white ? 'white' : 'black'} ${names[piece.toLowerCase()]}'}',
                            child: GestureDetector(
                              onTap: canMove
                                  ? () => unawaited(tap(square))
                                  : null,
                              child: Container(
                                decoration: BoxDecoration(
                                  color: selected == square
                                      ? const Color(0xFFE2C462)
                                      : recent
                                      ? const Color(0xFF88AE83)
                                      : (row + col).isEven
                                      ? const Color(0xFFDFE5D7)
                                      : const Color(0xFF648A7A),
                                  border: target
                                      ? Border.all(
                                          color: const Color(0xFFDDAB35),
                                          width: 3,
                                        )
                                      : null,
                                ),
                                child: Stack(
                                  children: [
                                    if (piece != null)
                                      Center(
                                        child: piece.toLowerCase() == 'p'
                                            ? CustomPaint(
                                                size: Size(
                                                  size.maxWidth / 8 * .65,
                                                  size.maxWidth / 8 * .78,
                                                ),
                                                painter: _PawnPainter(white),
                                              )
                                            : Text(
                                                '${glyphs[piece]!}\uFE0E',
                                                style: TextStyle(
                                                  fontSize:
                                                      size.maxWidth / 8 * .8,
                                                  height: 1,
                                                  color: white
                                                      ? Colors.white
                                                      : const Color(0xFF17212B),
                                                  shadows: const [
                                                    Shadow(
                                                      color: Colors.black54,
                                                      blurRadius: 2,
                                                    ),
                                                  ],
                                                ),
                                              ),
                                      ),
                                    if (target && piece == null)
                                      Center(
                                        child: Container(
                                          width: 12,
                                          height: 12,
                                          decoration: const BoxDecoration(
                                            color: Color(0x990B3825),
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                      ),
                                    Positioned(
                                      left: 2,
                                      bottom: 1,
                                      child: Text(
                                        square,
                                        style: const TextStyle(
                                          fontSize: 9,
                                          color: Color(0xFF243E34),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    widget.bot ? 'You play White · beginner bot plays Black' : 'White starts · tap a piece, then a highlighted square',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    game.notation.isEmpty
                        ? 'Your moves will appear here'
                        : [
                            for (var i = 0; i < game.notation.length; i += 2)
                              '${i ~/ 2 + 1}. ${game.notation[i]}${i + 1 < game.notation.length ? ' ${game.notation[i + 1]}' : ''}',
                          ].join('   '),
                    textAlign: TextAlign.center,
                  ),
                  if (game.finished && widget.online?.player == 0)
                    FilledButton(
                      onPressed: widget.online!.busy
                          ? null
                          : () => widget.online!.restart(),
                      child: const Text('Play again'),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PawnPainter extends CustomPainter {
  const _PawnPainter(this.white);
  final bool white;
  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 40, size.height / 48);
    final body = Path()
      ..moveTo(14, 19)
      ..lineTo(26, 19)
      ..cubicTo(24, 27, 25, 33, 32, 38)
      ..lineTo(34, 44)
      ..lineTo(6, 44)
      ..lineTo(8, 38)
      ..cubicTo(15, 33, 16, 27, 14, 19)
      ..close();
    final fill = Paint()
      ..color = white ? Colors.white : const Color(0xFF17212B);
    final outline = Paint()
      ..color = const Color(0xFF17212B)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawPath(body, fill);
    canvas.drawPath(body, outline);
    canvas.drawCircle(const Offset(20, 10), 7.5, fill);
    canvas.drawCircle(const Offset(20, 10), 7.5, outline);
    final collar = RRect.fromRectAndRadius(
      const Rect.fromLTWH(11, 18, 18, 4),
      const Radius.circular(2),
    );
    canvas.drawRRect(collar, fill);
    canvas.drawRRect(collar, outline);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_PawnPainter oldDelegate) => oldDelegate.white != white;
}
