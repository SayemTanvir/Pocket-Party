import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'games/dots_game.dart';
import 'games/chess_page.dart';
import 'games/dots_bot.dart';
import 'games/arcade_page.dart';
import 'games/game_catalog.dart';
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
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFF101622),
        scrolledUnderElevation: 0,
        centerTitle: false,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: const Color(0xFF182333),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: const BorderSide(color: Colors.white10),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(48, 52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(48, 52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          side: const BorderSide(color: Colors.white24),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFF182333),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: FadeUpwardsPageTransitionsBuilder(),
          TargetPlatform.iOS: FadeUpwardsPageTransitionsBuilder(),
        },
      ),
    ),
    home: const Lobby(),
  );
}

Widget onlineMatch(OnlineSession session) => switch (session.gameType) {
  'chess' => ChessPage(online: session),
  'dots' => MatchPage(
    players: session.game.players,
    bot: false,
    online: session,
  ),
  _ => ArcadePage(
    type: session.gameType,
    players: session.state.players,
    online: session,
  ),
};

class Lobby extends StatefulWidget {
  const Lobby({super.key});
  @override
  State<Lobby> createState() => _LobbyState();
}

class _LobbyState extends State<Lobby> {
  String category = 'All';
  @override
  Widget build(BuildContext context) {
    final games = gameCatalog
        .where((g) => category == 'All' || g.category == category)
        .toList();
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 900),
            child: CustomScrollView(
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
                  sliver: SliverToBoxAdapter(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(0xFF68E0C2)
                                    .withValues(alpha: .12),
                                borderRadius: BorderRadius.circular(18),
                              ),
                              child: const Icon(
                                Icons.sports_esports_rounded,
                                color: Color(0xFF68E0C2),
                                size: 30,
                              ),
                            ),
                            const SizedBox(width: 14),
                            const Text(
                              'Pocket Party',
                              style: TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                                letterSpacing: -.8,
                              ),
                            ),
                            const Spacer(),
                            IconButton(
                              tooltip: 'About Pocket Party',
                              icon: const Icon(Icons.info_outline),
                              onPressed: () => showAboutDialog(
                                context: context,
                                applicationName: 'Pocket Party',
                                applicationVersion: 'Five games. Good company.',
                                children: [
                                  const Text(
                                    'Built for local play, friendly bots and private online rooms. Word Grid uses the CC0 Letterpress dictionary.',
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 28),
                        Text(
                          'Good times,\none game away.',
                          style: Theme.of(context).textTheme.headlineLarge
                              ?.copyWith(
                                fontWeight: FontWeight.bold,
                                height: 1.12,
                                letterSpacing: -.6,
                              ),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Pick a challenge. Bring your friends.',
                          style: TextStyle(color: Colors.white60, fontSize: 16),
                        ),
                        const SizedBox(height: 24),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (final label in [
                              'All',
                              'Strategy',
                              'Words',
                              'Action',
                            ])
                              ChoiceChip(
                                label: Text(label),
                                selected: category == label,
                                onSelected: (_) =>
                                    setState(() => category = label),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  sliver: SliverLayoutBuilder(
                    builder: (context, constraints) => SliverGrid(
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: constraints.crossAxisExtent > 650
                            ? 3
                            : 2,
                        mainAxisExtent: 220,
                        mainAxisSpacing: 12,
                        crossAxisSpacing: 12,
                      ),
                      delegate: SliverChildBuilderDelegate((context, index) {
                        final info = games[index];
                        return Semantics(
                          button: true,
                          label: 'Open ${info.title}',
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(24),
                              onTap: () => Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                  builder: (_) =>
                                      GameSetupPage(gameType: info.id),
                                ),
                              ),
                              child: Ink(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(24),
                                  border: Border.all(
                                    color: info.color.withValues(alpha: .2),
                                  ),
                                  gradient: LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: [
                                      info.color.withValues(alpha: .14),
                                      const Color(0xFF182333),
                                    ],
                                  ),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Icon(
                                            info.icon,
                                            size: 34,
                                            color: info.color,
                                          ),
                                          const Spacer(),
                                          const Icon(
                                            Icons.north_east_rounded,
                                            size: 18,
                                            color: Colors.white38,
                                          ),
                                        ],
                                      ),
                                      const Spacer(),
                                      Text(
                                        info.title,
                                        maxLines: 2,
                                        style: const TextStyle(
                                          fontSize: 20,
                                          height: 1.15,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        info.tagline,
                                        maxLines: 2,
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: Colors.white60,
                                          height: 1.4,
                                        ),
                                      ),
                                      const SizedBox(height: 12),
                                      Text(
                                        '${info.maxPlayers == 2 ? '2' : '2?4'} players  ?  ${info.duration}',
                                        style: TextStyle(
                                          fontSize: 10,
                                          color: info.color,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      }, childCount: games.length),
                    ),
                  ),
                ),
                const SliverPadding(
                  padding: EdgeInsets.fromLTRB(24, 24, 24, 28),
                  sliver: SliverToBoxAdapter(
                    child: Text(
                      'PLAY YOUR WAY  ?  LOCAL / BOT / ONLINE',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 10,
                        letterSpacing: 1.3,
                        color: Colors.white38,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class GameSetupPage extends StatefulWidget {
  const GameSetupPage({super.key, required this.gameType});
  final String gameType;
  @override
  State<GameSetupPage> createState() => _GameSetupPageState();
}

class _GameSetupPageState extends State<GameSetupPage> {
  int players = 2, seconds = 0;
  bool bot = false;
  @override
  Widget build(BuildContext context) {
    final info = gameInfo(widget.gameType);
    final chess = widget.gameType == 'chess';
    return Scaffold(
      appBar: AppBar(
        title: Text(info.title),
        actions: [
          IconButton(
            tooltip: 'How to play',
            onPressed: () => showGameRules(context, info.id),
            icon: const Icon(Icons.help_outline_rounded),
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    padding: const EdgeInsets.all(28),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(28),
                      gradient: LinearGradient(
                        colors: [
                          info.color.withValues(alpha: .2),
                          const Color(0xFF182333),
                        ],
                      ),
                    ),
                    child: Column(
                      children: [
                        Icon(info.icon, size: 72, color: info.color),
                        const SizedBox(height: 20),
                        Text(
                          info.tagline,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          '${info.maxPlayers == 2 ? '2' : '2?4'} players ? ${info.duration}',
                          style: const TextStyle(color: Colors.white60),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 28),
                  const Text(
                    'Choose your opponent',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  SegmentedButton<bool>(
                    segments: const [
                      ButtonSegment(
                        value: false,
                        icon: Icon(Icons.people_outline),
                        label: Text('On this device'),
                      ),
                      ButtonSegment(
                        value: true,
                        icon: Icon(Icons.smart_toy_outlined),
                        label: Text('Bot'),
                      ),
                    ],
                    selected: {bot},
                    onSelectionChanged: (value) => setState(() {
                      bot = value.first;
                      if (bot) players = 2;
                    }),
                  ),
                  const SizedBox(height: 20),
                  if (info.maxPlayers > 2 && !bot) ...[
                    SegmentedButton<int>(
                      showSelectedIcon: false,
                      segments: [
                        for (final n in [2, 3, 4])
                          ButtonSegment(value: n, label: Text('$n players')),
                      ],
                      selected: {players},
                      onSelectionChanged: (value) =>
                          setState(() => players = value.first),
                    ),
                    const SizedBox(height: 20),
                  ],
                  if (chess) ...[
                    TimeControlPicker(
                      seconds: seconds,
                      onChanged: (value) => setState(() => seconds = value),
                    ),
                    const SizedBox(height: 20),
                  ],
                  FilledButton.icon(
                    icon: const Icon(Icons.play_arrow_rounded),
                    label: Text(chess ? 'Start chess' : 'Start game'),
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => switch (info.id) {
                          'chess' => ChessPage(bot: bot, seconds: seconds),
                          'dots' => MatchPage(players: players, bot: bot),
                          _ => ArcadePage(
                            type: info.id,
                            players: players,
                            bot: bot,
                          ),
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.public_rounded),
                    label: const Text('Play with friends online'),
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => RoomSetupPage(
                          gameType: info.id,
                          seconds: seconds,
                          matchBuilder: onlineMatch,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextButton.icon(
                    icon: const Icon(Icons.auto_stories_outlined, size: 18),
                    label: const Text('How to play'),
                    onPressed: () => showGameRules(context, info.id),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Play again after a match to keep your series record.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white38, fontSize: 12),
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
    HapticFeedback.selectionClick();
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
        IconButton(
          tooltip: 'How to play',
          onPressed: () => showGameRules(context, 'dots'),
          icon: const Icon(Icons.help_outline_rounded),
        ),
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
                                        child: AnimatedContainer(
                                          duration: const Duration(
                                            milliseconds: 180,
                                          ),
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
