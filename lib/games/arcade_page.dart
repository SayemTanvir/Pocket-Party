import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../online/online_session.dart';
import 'arcade_rules.dart';
import 'darts_board.dart';
import 'game_catalog.dart';
import 'game_factory.dart';
import 'match_series.dart';
import 'match_widgets.dart';
import 'party_game.dart';
import 'word_dictionary.dart';

const arcadeColors = [
  Color(0xFF68E0C2),
  Color(0xFFFFBC73),
  Color(0xFFB7A0FF),
  Color(0xFFFF83A5),
];

class ArcadePage extends StatefulWidget {
  const ArcadePage({
    super.key,
    required this.type,
    this.players = 2,
    this.bot = false,
    this.online,
  });
  final String type;
  final int players;
  final bool bot;
  final OnlineSession? online;
  @override
  State<ArcadePage> createState() => _ArcadePageState();
}

class _ArcadePageState extends State<ArcadePage> {
  late PartyGame game;
  late MatchSeries localSeries;
  MatchSeries get series => widget.online?.series ?? localSeries;
  bool busy = false, resultShown = false;
  int generation = 0;
  int? selected;
  String letter = 'A';
  DialogRoute<void>? resultDialog;
  bool get canPlay =>
      !game.finished &&
      !busy &&
      (widget.online?.canMove ?? (!widget.bot || game.turn == 0));
  @override
  void initState() {
    super.initState();
    game =
        widget.online?.state ?? newGame(widget.type, players: widget.players);
    localSeries = MatchSeries(game.players);
    widget.online?.addListener(sync);
    checkResult();
  }

  void sync() {
    if (!mounted) return;
    setState(() {
      game = widget.online!.state;
      if (game is WordGame &&
          selected != null &&
          (game as WordGame).cells[selected!].isNotEmpty) {
        selected = null;
      }
    });
    checkResult();
  }

  @override
  void dispose() {
    generation++;
    widget.online?.removeListener(sync);
    widget.online?.dispose();
    super.dispose();
  }

  void restart() {
    if (widget.online != null) {
      unawaited(widget.online!.restart());
      return;
    }
    setState(() {
      generation++;
      game = newGame(widget.type, players: widget.players);
      selected = null;
      busy = false;
      resultShown = false;
    });
  }

  String playerName(int player) => widget.bot && player == 1
      ? 'Bot'
      : widget.bot
      ? 'You'
      : 'Player ${player + 1}';
  String get result {
    final winner = matchWinner(game);
    return winner == null
        ? 'A draw. Well played!'
        : '${playerName(winner)} wins!';
  }

  void checkResult() {
    if (!game.finished) {
      if (resultDialog?.isActive == true) {
        Navigator.of(context).removeRoute(resultDialog!);
      }
      resultDialog = null;
      resultShown = false;
      return;
    }
    if (resultShown) return;
    resultShown = true;
    if (widget.online == null) localSeries.record(game);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !game.finished) return;
      unawaited(
        celebrateMatch(
          context,
          title: result,
          draw: matchWinner(game) == null,
          onRoute: (route) => resultDialog = route,
          playAgain: widget.online == null || widget.online!.player == 0
              ? restart
              : null,
        ),
      );
    });
  }

  Future<void> play(String move) async {
    if (widget.online != null) {
      if (canPlay) await widget.online!.move(move);
      return;
    }
    if (busy || game.finished || !game.play(move)) return;
    final current = generation;
    HapticFeedback.selectionClick();
    setState(() {
      busy = true;
      selected = null;
    });
    checkResult();
    await Future<void>.delayed(const Duration(milliseconds: 350));
    if (!mounted || current != generation) return;
    setState(() => busy = false);
    if (widget.bot && game.turn == 1 && !game.finished) {
      setState(() => busy = true);
      final move = await compute(chooseArcadeMove, {
        'type': widget.type,
        'game': game.toJson(),
      });
      if (!mounted || current != generation) return;
      setState(() => busy = false);
      await play(move);
    }
  }

  String get status {
    final online = widget.online;
    if (online?.expired == true) return 'Room unavailable';
    if (online?.connected == false) return 'Reconnecting…';
    if (online != null && !online.ready) {
      return 'Waiting for players (${online.joined}/${game.players})';
    }
    if (game.finished) return result;
    if (online?.busy == true) return 'Sending move…';
    if (widget.bot && game.turn == 1) return 'Bot is thinking…';
    return online != null && online.player == game.turn
        ? 'Your turn'
        : '${playerName(game.turn)}’s turn';
  }

  Future<void> dictionary() => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) {
      String query = '';
      return StatefulBuilder(
        builder: (context, update) => Padding(
          padding: EdgeInsets.fromLTRB(
            24,
            8,
            24,
            MediaQuery.viewInsetsOf(context).bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Check a word',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              const Text('3–5 letters · English · no proper names'),
              const SizedBox(height: 16),
              TextField(
                autofocus: true,
                maxLength: 5,
                textCapitalization: TextCapitalization.characters,
                onChanged: (value) =>
                    update(() => query = value.trim().toUpperCase()),
                decoration: const InputDecoration(
                  hintText: 'Try a word',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                query.isEmpty
                    ? '${wordDictionary.length} words available offline'
                    : wordDictionary.contains(query)
                    ? '$query is valid · ${query.length} points'
                    : '$query is not in this game’s dictionary',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
      );
    },
  );
  @override
  Widget build(BuildContext context) {
    final info = gameInfo(widget.type);
    final scores = gameScores(game);
    return Scaffold(
      appBar: AppBar(
        title: Text(info.title),
        actions: [
          if (widget.type == 'words')
            IconButton(
              tooltip: 'Check a word',
              onPressed: dictionary,
              icon: const Icon(Icons.menu_book_rounded),
            ),
          IconButton(
            tooltip: 'How to play',
            onPressed: () => showGameRules(context, widget.type),
            icon: const Icon(Icons.help_outline_rounded),
          ),
          if (widget.online == null)
            IconButton(
              tooltip: 'Restart game',
              onPressed: restart,
              icon: const Icon(Icons.refresh_rounded),
            ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Column(
                children: [
                  if (widget.online != null)
                    TextButton.icon(
                      icon: const Icon(Icons.copy_rounded),
                      label: Text(
                        'Room ${widget.online!.code} · You are Player ${widget.online!.player + 1}',
                      ),
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
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    alignment: WrapAlignment.center,
                    children: [
                      for (var p = 0; p < game.players; p++)
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 220),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: !game.finished && game.turn == p
                                ? arcadeColors[p].withValues(alpha: .15)
                                : const Color(0xFF182333),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: !game.finished && game.turn == p
                                  ? arcadeColors[p]
                                  : Colors.white12,
                            ),
                          ),
                          child: Text(
                            '${playerName(p)}${scores == null ? '' : '  ${scores[p]}'}',
                            style: TextStyle(
                              color: arcadeColors[p],
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                    ],
                  ),
                  SeriesScore(
                    series: series,
                    labels: [
                      for (var p = 0; p < game.players; p++) playerName(p),
                    ],
                    player: widget.online?.player,
                  ),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 180),
                    child: Text(
                      status,
                      key: ValueKey(status),
                      style: Theme.of(context).textTheme.titleLarge,
                      textAlign: TextAlign.center,
                    ),
                  ),
                  if (widget.online?.error != null)
                    Padding(
                      padding: const EdgeInsets.all(8),
                      child: Text(
                        widget.online!.error!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ),
                  const SizedBox(height: 20),
                  if (game is DartsGame) ...[
                    Text(
                      'Round ${(game as DartsGame).round} of 5 · ${(game as DartsGame).dartsLeft} darts left',
                      style: const TextStyle(color: Colors.white60),
                    ),
                    const SizedBox(height: 12),
                    DartsBoard(
                      enabled: canPlay,
                      onThrow: (move) => unawaited(play(move)),
                      lastThrow: (game as DartsGame).throws.lastOrNull,
                    ),
                    if ((game as DartsGame).throws.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.all(12),
                        child: Text(
                          'Last dart: +${(game as DartsGame).lastScore}',
                          style: TextStyle(
                            color: info.color,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                  ],
                  if (game is WordGame) wordBoard(game as WordGame),
                  if (game is ConnectGame) connectBoard(game as ConnectGame),
                  if (game.finished &&
                      (widget.online == null || widget.online!.player == 0))
                    Padding(
                      padding: const EdgeInsets.only(top: 20),
                      child: FilledButton.icon(
                        onPressed: widget.online?.busy == true ? null : restart,
                        icon: const Icon(Icons.replay_rounded),
                        label: const Text('Play again'),
                      ),
                    ),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> selectLetter(int tile) async {
    if (!canPlay) return;
    final current = generation;
    setState(() => selected = tile);
    var choice = letter;
    final picked = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (_, update) => SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Choose a letter',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                Text('Row ${tile ~/ 5 + 1}, column ${tile % 5 + 1}'),
                const SizedBox(height: 20),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  alignment: WrapAlignment.center,
                  children: [
                    for (var c = 65; c <= 90; c++)
                      SizedBox(
                        width: 44,
                        height: 44,
                        child: TextButton(
                          style: TextButton.styleFrom(
                            padding: EdgeInsets.zero,
                            backgroundColor: choice == String.fromCharCode(c)
                                ? const Color(0xFF645594)
                                : const Color(0xFF1C293B),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          onPressed: () =>
                              update(() => choice = String.fromCharCode(c)),
                          child: Text(String.fromCharCode(c)),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () => Navigator.pop(sheetContext, choice),
                    child: Text('Place $choice'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (!mounted) return;
    setState(() => selected = null);
    if (picked == null || current != generation || !canPlay) return;
    if ((game as WordGame).cells[tile].isNotEmpty) return;
    letter = picked;
    await play('$tile:$picked');
  }

  Widget wordBoard(WordGame word) => Column(
    children: [
      Text(
        '${25 - word.history.length} tiles left · every new word scores',
        style: const TextStyle(color: Colors.white60),
      ),
      const SizedBox(height: 12),
      AspectRatio(
        aspectRatio: 1,
        child: GridView.builder(
          physics: const NeverScrollableScrollPhysics(),
          itemCount: 25,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 5,
            mainAxisSpacing: 6,
            crossAxisSpacing: 6,
          ),
          itemBuilder: (_, i) => Semantics(
            key: ValueKey('word-tile-$i'),
            button: true,
            label:
                'Word tile ${i + 1}${word.cells[i].isEmpty ? ' empty' : ' ${word.cells[i]}'}',
            child: InkWell(
              onTap: canPlay && word.cells[i].isEmpty
                  ? () => unawaited(selectLetter(i))
                  : null,
              borderRadius: BorderRadius.circular(12),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                decoration: BoxDecoration(
                  color: selected == i
                      ? const Color(0xFF645594)
                      : word.cells[i].isEmpty
                      ? const Color(0xFF1C293B)
                      : const Color(0xFF354760),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: selected == i
                        ? const Color(0xFFB7A0FF)
                        : Colors.white12,
                    width: 2,
                  ),
                ),
                child: Center(
                  child: Text(
                    word.cells[i].isEmpty
                        ? (selected == i ? letter : '·')
                        : word.cells[i],
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: word.cells[i].isEmpty
                          ? Colors.white38
                          : Colors.white,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
      const SizedBox(height: 12),
      AnimatedSwitcher(
        duration: const Duration(milliseconds: 200),
        child: Text(
          word.lastWords.isEmpty
              ? 'Build a word across or down.'
              : word.lastWords.map((w) => '$w +${w.length}').join('   '),
          key: ValueKey(word.history.length),
          style: const TextStyle(
            color: Color(0xFFB7A0FF),
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      if (!game.finished) ...[
        const SizedBox(height: 16),
        const Text(
          'Tap an empty tile to choose a letter.',
          style: TextStyle(color: Colors.white60),
        ),
      ],
    ],
  );
  Widget connectBoard(ConnectGame connect) => Column(
    children: [
      const Text(
        'Tap a column to drop your disc',
        style: TextStyle(color: Colors.white60),
      ),
      const SizedBox(height: 12),
      Row(
        children: [
          for (var col = 0; col < 7; col++)
            Expanded(
              child: IconButton(
                tooltip: 'Drop in column ${col + 1}',
                onPressed: canPlay && connect.legalMoves.contains('$col')
                    ? () => unawaited(play('$col'))
                    : null,
                icon: const Icon(Icons.arrow_downward_rounded),
                color: arcadeColors[game.turn],
              ),
            ),
        ],
      ),
      Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: const Color(0xFF223D68),
          borderRadius: BorderRadius.circular(20),
        ),
        child: AspectRatio(
          aspectRatio: 7 / 6,
          child: GridView.builder(
            physics: const NeverScrollableScrollPhysics(),
            itemCount: 42,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              mainAxisSpacing: 5,
              crossAxisSpacing: 5,
            ),
            itemBuilder: (_, i) => GestureDetector(
              onTap: canPlay && connect.legalMoves.contains('${i % 7}')
                  ? () => unawaited(play('${i % 7}'))
                  : null,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 260),
                curve: Curves.easeOutBack,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: connect.cells[i] < 0
                      ? const Color(0xFF0C1422)
                      : arcadeColors[connect.cells[i]],
                  border: Border.all(
                    color: connect.winningCells.contains(i)
                        ? Colors.white
                        : Colors.white12,
                    width: connect.winningCells.contains(i) ? 3 : 1,
                  ),
                ),
                child: Center(
                  child: Text(
                    connect.cells[i] < 0 ? '' : '${connect.cells[i] + 1}',
                    style: const TextStyle(
                      color: Color(0xFF172131),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    ],
  );
}
