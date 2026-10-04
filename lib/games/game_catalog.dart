import 'package:flutter/material.dart';

class GameInfo {
  const GameInfo(
    this.id,
    this.title,
    this.tagline,
    this.rules,
    this.icon,
    this.color,
    this.category,
    this.maxPlayers,
    this.duration,
  );
  final String id, title, tagline, rules, category, duration;
  final IconData icon;
  final Color color;
  final int maxPlayers;
}

const gameCatalog = [
  GameInfo(
    'dots',
    'Dots & Boxes',
    'One line can change everything.',
    'Tap between dots to draw a line. Complete a box to score and keep your turn. Most boxes wins.',
    Icons.grid_on_rounded,
    Color(0xFF68E0C2),
    'Strategy',
    4,
    '5–10 min',
  ),
  GameInfo(
    'chess',
    'Chess',
    'Your next brilliant move.',
    'Tap a piece, then a highlighted square. Checkmate the king. Optional clocks give each player their own time limit.',
    Icons.castle_rounded,
    Color(0xFFFFBC73),
    'Strategy',
    2,
    'Your pace',
  ),
  GameInfo(
    'darts',
    'Darts',
    'Steady aim. Perfect timing.',
    'Drag on the board to aim, then release to throw. The sight moves, so time your release. Three darts per turn, five rounds. Highest total wins. Outer ring doubles, middle ring triples, bull scores 25 or 50.',
    Icons.my_location_rounded,
    Color(0xFFFF83A5),
    'Action',
    4,
    '3–5 min',
  ),
  GameInfo(
    'words',
    'Word Grid',
    'A single letter. A clever steal.',
    'Select an empty tile and place a letter. New 3–5 letter English words reading left to right or top to bottom score their length. Each distinct word scores once per match. Multiple new words score together. Fill all 25 tiles; highest score wins.',
    Icons.abc_rounded,
    Color(0xFFB7A0FF),
    'Words',
    4,
    '5–10 min',
  ),
  GameInfo(
    'connect',
    'Connect Four',
    'Build a line. Break their plan.',
    'Tap a column to drop a disc. Connect four horizontally, vertically or diagonally before your opponent. A full board with no winner is a draw.',
    Icons.blur_circular_rounded,
    Color(0xFF70BFFF),
    'Strategy',
    2,
    '2–5 min',
  ),
];
GameInfo gameInfo(String id) => gameCatalog.firstWhere((game) => game.id == id);

Future<void> showGameRules(BuildContext context, String type) =>
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 4, 24, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(gameInfo(type).icon, color: gameInfo(type).color, size: 40),
              const SizedBox(height: 16),
              Text(
                'How to play ${gameInfo(type).title}',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              Text(gameInfo(type).rules, style: const TextStyle(height: 1.6)),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Got it'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
