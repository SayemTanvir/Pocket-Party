import 'package:flutter/material.dart';

import 'online_session.dart';
import '../games/match_widgets.dart';
import '../games/game_catalog.dart';

class RoomSetupPage extends StatefulWidget {
  const RoomSetupPage({
    super.key,
    required this.matchBuilder,
    this.gameType = 'dots',
    this.seconds = 0,
  });
  final String gameType;
  final int seconds;
  final Widget Function(OnlineSession) matchBuilder;
  @override
  State<RoomSetupPage> createState() => _RoomSetupPageState();
}

class _RoomSetupPageState extends State<RoomSetupPage> {
  final address = TextEditingController(
    text: const String.fromEnvironment(
      'ROOM_SERVER',
      defaultValue: 'https://pocket-party-rooms.onrender.com',
    ),
  );
  final code = TextEditingController();
  int players = 2;
  late int seconds;
  @override
  void initState() {
    super.initState();
    seconds = widget.seconds;
  }

  bool busy = false;
  String? error;
  @override
  void dispose() {
    address.dispose();
    code.dispose();
    super.dispose();
  }

  Future<void> open(bool create) async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final session = await OnlineSession.open(
        address.text,
        players: create ? players : null,
        gameType: widget.gameType,
        clockSeconds: seconds,
        code: create ? null : code.text,
      );
      if (!mounted) {
        session.dispose();
        return;
      }
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(builder: (_) => widget.matchBuilder(session)),
      );
    } catch (failure) {
      if (!mounted) return;
      setState(() {
        busy = false;
        error = failure is RoomException
            ? failure.message
            : failure is FormatException
            ? failure.message
            : 'Could not reach the server. Check the address and connection.';
      });
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Play with friends')),
    body: SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  '${gameInfo(widget.gameType).title} room',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 12),
                const Text(
                  'Create a room and share its code. Everyone must connect to the same game server.',
                ),
                const SizedBox(height: 24),
                ExpansionTile(
                  tilePadding: EdgeInsets.zero,
                  title: const Text('Connection settings'),
                  subtitle: const Text('Pocket Party online server'),
                  children: [
                    TextField(
                      controller: address,
                      enabled: !busy,
                      keyboardType: TextInputType.url,
                      autocorrect: false,
                      decoration: const InputDecoration(
                        labelText: 'Server address',
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                ),
                const SizedBox(height: 20),
                if (gameInfo(widget.gameType).maxPlayers > 2)
                  SegmentedButton<int>(
                    showSelectedIcon: false,
                    segments: [
                      for (final n in [2, 3, 4])
                        ButtonSegment(value: n, label: Text('$n players')),
                    ],
                    selected: {players},
                    onSelectionChanged: busy
                        ? null
                        : (values) => setState(() => players = values.first),
                  ),
                if (widget.gameType == 'chess')
                  TimeControlPicker(
                    seconds: seconds,
                    onChanged: busy
                        ? null
                        : (value) => setState(() => seconds = value),
                  ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: busy ? null : () => open(true),
                  icon: const Icon(Icons.add),
                  label: const Text('Create room'),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 20),
                  child: Divider(),
                ),
                TextField(
                  controller: code,
                  enabled: !busy,
                  maxLength: 6,
                  textCapitalization: TextCapitalization.characters,
                  autocorrect: false,
                  decoration: const InputDecoration(
                    labelText: 'Room code',
                    border: OutlineInputBorder(),
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: busy ? null : () => open(false),
                  icon: const Icon(Icons.login),
                  label: const Text('Join room'),
                ),
                if (busy)
                  const Padding(
                    padding: EdgeInsets.all(16),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                if (busy)
                  const Text(
                    'Connecting… A sleeping demo server may take about a minute to start.',
                    textAlign: TextAlign.center,
                  ),
                if (error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: Text(
                      error!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
                const SizedBox(height: 20),
                const Text(
                  'Keep the match open to reconnect after a network interruption. Leaving the screen ends your session on this device.',
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
