import 'arcade_rules.dart';
import 'chess_game.dart';
import 'dots_game.dart';
import 'party_game.dart';

const gameTypes = ['dots', 'chess', 'darts', 'words', 'connect'];
PartyGame newGame(String type, {int players = 2}) => switch (type) {
  'dots' => DotsGame(players: players),
  'chess' => ChessGame(),
  'darts' => DartsGame(players: players),
  'words' => WordGame(players: players),
  'connect' => ConnectGame(),
  _ => throw ArgumentError('Unknown game'),
};
PartyGame restoreGame(String type, Map<String, dynamic> data) => switch (type) {
  'dots' => DotsGame.fromJson(data),
  'chess' => ChessGame.fromJson(data),
  'darts' => DartsGame.fromJson(data),
  'words' => WordGame.fromJson(data),
  'connect' => ConnectGame.fromJson(data),
  _ => throw const FormatException('Unknown game'),
};
