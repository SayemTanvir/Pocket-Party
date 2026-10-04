import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'games/dots_game.dart';
import 'games/chess_page.dart';
import 'games/dots_bot.dart';
import 'games/match_series.dart';
import 'games/match_widgets.dart';
import 'online/online_session.dart';
import 'online/room_setup_page.dart';

void main() => runApp(const PartyApp());

const playerColors = [
  Color(0xFF68E0C2),
  Color(0xFFFFBC73),
  Color(0xFFB7A0FF),
  Color(0xFFFF83A5),
];

class PartyApp extends StatelessWidget {
  const PartyApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Pocket Party',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: const Color(0xFF101622),
      colorScheme: ColorScheme.fromSeed(
        seedColor: playerColors.first,
        brightness: Brightness.dark,
      ),
      useMaterial3: true,
    ),
    home: const Lobby(),
  );
}

Widget onlineMatch(OnlineSession session) => session.gameType == 'chess'
    ? ChessPage(online: session)
    : MatchPage(players: session.game.players, bot: false, online: session);

class Lobby extends StatelessWidget {
  const Lobby({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 500),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.sports_esports_rounded,
                  size: 64,
                  color: Color(0xFF68E0C2),
                ),
                const SizedBox(height: 24),
                Text(
                  'Pocket Party',
                  style: Theme.of(context).textTheme.displaySmall,
                ),
                const SizedBox(height: 8),
                const Text('Pick your next challenge.'),
                const SizedBox(height: 32),
                for (final type in ['dots', 'chess'])
                  Padding(
                    padding: const EdgeInsets.only(bottom: 20),
                    child: Card(
                      clipBehavior: Clip.antiAlias,
                      child: InkWell(
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => GameSetupPage(gameType: type),
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Row(
                            children: [
                              Icon(
                                type == 'dots' ? Icons.grid_on : Icons.castle,
                                size: 48,
                                color: type == 'dots'
                                    ? const Color(0xFF68E0C2)
                                    : const Color(0xFFFFBC73),
                              ),
                              const SizedBox(width: 20),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      type == 'dots' ? 'Dots & Boxes' : 'Chess',
                                      style: Theme.of(context)
                                          .textTheme
                                          .headlineSmall,
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      type == 'dots'
                                          ? '36 boxes. Big chains. Late comebacks.'
                                          : 'Protect your king. Play with or without a clock.',
                                    ),
                                  ],
                                ),
                              ),
                              const Icon(Icons.chevron_right),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                const Text(
                  'Local play, bots and private online rooms.',
                  style: TextStyle(color: Colors.white70),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class GameSetupPage extends StatefulWidget {
  const GameSetupPage({super.key, required this.gameType});
  final String gameType;
  @override
  State<GameSetupPage> createState() => _GameSetupPageState();
}

class _GameSetupPageState extends State<GameSetupPage> {
  int players = 2;
  int seconds = 0;
  bool bot = false;
  bool get chess => widget.gameType == 'chess';
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(chess ? 'Chess' : 'Dots & Boxes')),
    body: SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Icon(
                  chess ? Icons.castle : Icons.grid_on,
                  size: 72,
                  color: const Color(0xFF68E0C2),
                ),
                const SizedBox(height: 24),
                Text(
                  'Make it your game',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 12),
                Text(
                  chess
                      ? 'A battle of strategy for two players. Choose a clock or take your time.'
                      : 'Connect dots and claim boxes. Complete a box to keep your turn and capture a chain.',
                ),
                const SizedBox(height: 24),
                if (!chess)
                  SegmentedButton<int>(
                    showSelectedIcon: false,
                    segments: [
                      for (final n in [2, 3, 4])
                        ButtonSegment(value: n, label: Text('$n players')),
                    ],
                    selected: {players},
                    onSelectionChanged: (value) => setState(() {
                      players = value.first;
                      if (players != 2) bot = false;
                    }),
                  ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Play against a bot'),
                  subtitle: Text(chess ? 'You play White' : 'Two players'),
                  value: bot,
                  onChanged: (value) => setState(() {
                    bot = value;
                    if (value) players = 2;
                  }),
                ),
                if (chess) ...[
                  TimeControlPicker(
                    seconds: seconds,
                    onChanged: (value) => setState(() => seconds = value),
                  ),
                  const SizedBox(height: 20),
                ],
                FilledButton.icon(
                  icon: const Icon(Icons.play_arrow),
                  label: Text(chess ? 'Start chess' : 'Start game'),
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => chess
                          ? ChessPage(bot: bot, seconds: seconds)
                          : MatchPage(players: players, bot: bot),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  icon: const Icon(Icons.public),
                  label: const Text('Play with friends'),
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => RoomSetupPage(
                        gameType: widget.gameType,
                        seconds: seconds,
                        matchBuilder: onlineMatch,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Completed games count toward this series. Play again to keep your wins, losses and draws.',
                  style: TextStyle(color: Colors.white70),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class MatchPage extends StatefulWidget {
  const MatchPage({
    super.key,
    required this.players,
    required this.bot,
    this.online,
  });
  final int players;
  final bool bot;
  final OnlineSession? online;
  @override
  State<MatchPage> createState() => _MatchPageState();
}

class _MatchPageState extends State<MatchPage> {
  late DotsGame game;
  Timer? botTimer;
  late final MatchSeries localSeries = MatchSeries(widget.players);
  MatchSeries get series => widget.online?.series ?? localSeries;
  bool resultShown = false;
  DialogRoute<void>? resultDialog;
  void restart() {
    if (widget.online != null) {
      unawaited(widget.online!.restart());
      return;
    }
    botTimer?.cancel();
    setState(() {
      game = DotsGame(players: widget.players);
      resultShown = false;
    });
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
          title: status,
          draw: matchWinner(game) == null,
          onRoute: (route) => resultDialog = route,
          playAgain: widget.online == null || widget.online!.player == 0
              ? restart
              : null,
        ),
      );
    });
  }

  @override
  void initState() {
    super.initState();
    game = widget.online?.game ?? DotsGame(players: widget.players);
    widget.online?.addListener(updateOnline);
    checkResult();
  }

  void updateOnline() {
    if (!mounted) return;
    setState(() => game = widget.online!.game);
    checkResult();
  }

  @override
  void dispose() {
    botTimer?.cancel();
    widget.online?.removeListener(updateOnline);
    widget.online?.dispose();
    super.dispose();
  }

  void play(String move) {
    if (widget.online != null) {
      if (widget.online!.canMove) unawaited(widget.online!.move(move));
      return;
    }
    if (!game.play(move)) return;
    setState(() {});
    checkResult();
    if (widget.bot && game.turn == 1 && !game.finished) {
      botTimer = Timer(const Duration(milliseconds: 450), () {
        if (!mounted) return;
        play(chooseBotMove(game));
      });
    }
  }

  String get status {
    final online = widget.online;
    if (online != null) {
      if (online.expired) return 'Room unavailable';
      if (!online.connected) return 'Reconnecting…';
      if (!online.ready) {
        return 'Waiting for players (${online.joined}/${game.players})';
      }
      if (online.busy) return 'Sending move…';
      if (!game.finished) {
        return game.turn == online.player
            ? 'Your turn'
            : 'Player ${game.turn + 1}’s turn';
      }
    }
    if (!game.finished) {
      return widget.bot && game.turn == 1
          ? 'Bot is thinking…'
          : 'Player ${game.turn + 1}’s turn';
    }
    final best = game.scores.reduce(max);
    final winners = [
      for (var i = 0; i < game.players; i++)
        if (game.scores[i] == best) i + 1,
    ];
    return winners.length > 1
        ? 'A tie! Well played.'
        : 'Player ${winners.first} wins!';
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Dots & Boxes'),
      actions: [
        if (widget.online == null)
          IconButton(
            tooltip: 'Restart game',
            icon: const Icon(Icons.refresh),
            onPressed: restart,
          ),
      ],
    ),
    body: SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 500),
            child: Column(
              children: [
                Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  children: [
                    for (var p = 0; p < game.players; p++)
                      Chip(
                        avatar: CircleAvatar(
                          backgroundColor: playerColors[p],
                          child: Text(
                            '${p + 1}',
                            style: const TextStyle(color: Colors.black),
                          ),
                        ),
                        label: Text(
                          '${widget.bot && p == 1 ? 'Bot' : 'Player ${p + 1}'}: ${game.scores[p]}',
                        ),
                      ),
                  ],
                ),
                SeriesScore(
                  series: series,
                  labels: [
                    for (var p = 0; p < game.players; p++)
                      widget.bot && p == 1 ? 'Bot' : 'Player ${p + 1}',
                  ],
                  player: widget.online?.player,
                ),
                if (game.finished && widget.online == null)
                  FilledButton(
                    onPressed: restart,
                    child: const Text('Play again'),
                  ),
                if (widget.online != null) ...[
                  const SizedBox(height: 16),
                  Text('You are Player ${widget.online!.player + 1}'),
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
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  if (game.finished && widget.online!.player == 0)
                    FilledButton(
                      onPressed: widget.online!.busy
                          ? null
                          : () => widget.online!.restart(),
                      child: const Text('Play again'),
                    ),
                ],
                const SizedBox(height: 24),
                Text(status, style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: 8),
                Text(
                  '${(game.size - 1) * (game.size - 1) - game.boxes.length} boxes left · ${game.size} × ${game.size} dots',
                  style: const TextStyle(color: Colors.white70),
                ),
                const SizedBox(height: 24),
                AspectRatio(
                  aspectRatio: 1,
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final step =
                          (constraints.maxWidth - 44) / (game.size - 1);
                      return Stack(
                        clipBehavior: Clip.none,
                        children: [
                          for (var r = 0; r < game.size - 1; r++)
                            for (var c = 0; c < game.size - 1; c++)
                              if (game.boxes.containsKey('$r:$c'))
                                Positioned(
                                  left: 22 + c * step + 10,
                                  top: 22 + r * step + 10,
                                  width: step - 20,
                                  height: step - 20,
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: playerColors[game.boxes['$r:$c']!]
                                          .withValues(alpha: 0.25),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Center(
                                      child: Text(
                                        '${game.boxes['$r:$c']! + 1}',
                                        style: const TextStyle(fontSize: 24),
                                      ),
                                    ),
                                  ),
                                ),
                          for (final horizontal in [true, false])
                            for (
                              var r = 0;
                              r < (horizontal ? game.size : game.size - 1);
                              r++
                            )
                              for (
                                var c = 0;
                                c < (horizontal ? game.size - 1 : game.size);
                                c++
                              )
                                Positioned(
                                  left: 22 + c * step - (horizontal ? 0 : 22),
                                  top: 22 + r * step - (horizontal ? 22 : 0),
                                  width: horizontal ? step : 44,
                                  height: horizontal ? 44 : step,
                                  child: Semantics(
                                    button: true,
                                    label:
                                        '${horizontal ? 'Horizontal' : 'Vertical'} line ${r + 1}, ${c + 1}',
                                    child: GestureDetector(
                                      behavior: HitTestBehavior.opaque,
                                      onTap:
                                          game.finished ||
                                              (widget.bot && game.turn == 1) ||
                                              (widget.online != null &&
                                                  !widget.online!.canMove)
                                          ? null
                                          : () => play(
                                              game.edge(horizontal, r, c),
                                            ),
                                      child: Center(
                                        child: Container(
                                          width: horizontal ? step - 12 : 5,
                                          height: horizontal ? 5 : step - 12,
                                          decoration: BoxDecoration(
                                            borderRadius: BorderRadius.circular(
                                              6,
                                            ),
                                            color:
                                                game.edges.contains(
                                                  game.edge(horizontal, r, c),
                                                )
                                                ? playerColors[game
                                                          .edgeOwners[game.edge(
                                                        horizontal,
                                                        r,
                                                        c,
                                                      )] ??
                                                      0]
                                                : Colors.white24,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                          for (var r = 0; r < game.size; r++)
                            for (var c = 0; c < game.size; c++)
                              Positioned(
                                left: 22 + c * step - 5,
                                top: 22 + r * step - 5,
                                child: const IgnorePointer(
                                  child: CircleAvatar(
                                    radius: 5,
                                    backgroundColor: Colors.white,
                                  ),
                                ),
                              ),
                        ],
                      );
                    },
                  ),
                ),
                const SizedBox(height: 32),
                const Text(
                  'Tap between two dots to draw a line.\nClaim the most boxes to win.',
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
