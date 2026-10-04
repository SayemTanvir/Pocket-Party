import 'dart:math';

import 'party_game.dart';
import 'word_dictionary.dart';

abstract class ScoredGame implements PartyGame {
  List<int> get scores;
}

class DartsGame implements ScoredGame {
  DartsGame({this.players = 2}) : scores = List.filled(players, 0);
  @override
  final int players;
  @override
  final List<int> scores;
  final List<String> throws = [];
  static const sectors = [
    20,
    1,
    18,
    4,
    13,
    6,
    10,
    15,
    2,
    17,
    3,
    19,
    7,
    16,
    8,
    11,
    14,
    9,
    12,
    5,
  ];
  @override
  int get turn => (throws.length ~/ 3) % players;
  int get round => min(5, throws.length ~/ (players * 3) + 1);
  int get dartsLeft => finished ? 0 : 3 - throws.length % 3;
  @override
  bool get finished => throws.length >= players * 15;
  static int scoreAt(int x, int y) {
    final radius = sqrt(x * x + y * y) / 1000;
    if (radius > 1) return 0;
    if (radius <= .05) return 50;
    if (radius <= .12) return 25;
    final angle = (atan2(y, x) + pi / 2 + pi / 20 + 2 * pi) % (2 * pi);
    final base = sectors[(angle / (pi / 10)).floor() % 20];
    return base *
        (radius >= .92
            ? 2
            : radius >= .56 && radius <= .64
            ? 3
            : 1);
  }

  @override
  List<String> get legalMoves => finished ? [] : ['0:0'];
  @override
  bool play(String move) {
    if (finished || !RegExp(r'^-?\d{1,4}:-?\d{1,4}$').hasMatch(move)) {
      return false;
    }
    final point = move.split(':').map(int.parse).toList();
    if (point.any((n) => n.abs() > 1250)) return false;
    scores[turn] += scoreAt(point[0], point[1]);
    throws.add(move);
    return true;
  }

  int get lastScore {
    if (throws.isEmpty) return 0;
    final point = throws.last.split(':').map(int.parse).toList();
    return scoreAt(point[0], point[1]);
  }

  @override
  Map<String, dynamic> toJson() => {'players': players, 'throws': throws};
  factory DartsGame.fromJson(Map<String, dynamic> data) {
    final game = DartsGame(players: data['players'] as int);
    for (final move in (data['throws'] as List).cast<String>()) {
      if (!game.play(move)) throw const FormatException('Invalid dart');
    }
    return game;
  }
}

class WordGame implements ScoredGame {
  WordGame({this.players = 2}) : scores = List.filled(players, 0);
  @override
  final int players;
  @override
  final List<int> scores;
  final List<String> cells = List.filled(25, '');
  final List<String> history = [];
  final Set<String> claimed = {};
  List<String> lastWords = [];
  @override
  int get turn => history.length % players;
  @override
  bool get finished => history.length == 25;
  @override
  List<String> get legalMoves => finished
      ? []
      : [
          for (var i = 0; i < 25; i++)
            if (cells[i].isEmpty)
              for (var c = 65; c <= 90; c++) '$i:${String.fromCharCode(c)}',
        ];
  @override
  bool play(String move) {
    if (finished || !RegExp(r'^\d{1,2}:[A-Z]$').hasMatch(move)) return false;
    final parts = move.split(':');
    final index = int.parse(parts[0]);
    if (index >= 25 || cells[index].isNotEmpty) return false;
    cells[index] = parts[1];
    lastWords = [];
    for (final vertical in [false, true]) {
      final position = vertical ? index ~/ 5 : index % 5;
      final line = [
        for (var i = 0; i < 5; i++)
          cells[vertical ? i * 5 + index % 5 : index ~/ 5 * 5 + i],
      ];
      for (var start = 0; start <= position; start++) {
        for (var end = max(start + 3, position + 1); end <= 5; end++) {
          final letters = line.sublist(start, end);
          if (letters.contains('')) continue;
          final word = letters.join();
          if (wordDictionary.contains(word) && claimed.add(word)) {
            scores[turn] += word.length;
            lastWords.add(word);
          }
        }
      }
    }
    history.add(move);
    return true;
  }

  @override
  Map<String, dynamic> toJson() => {'players': players, 'moves': history};
  factory WordGame.fromJson(Map<String, dynamic> data) {
    final game = WordGame(players: data['players'] as int);
    for (final move in (data['moves'] as List).cast<String>()) {
      if (!game.play(move)) {
        throw const FormatException('Invalid letter placement');
      }
    }
    return game;
  }
}

class ConnectGame implements PartyGame {
  ConnectGame();
  final List<int> cells = List.filled(42, -1);
  final List<int> history = [];
  final List<int> winningCells = [];
  int? winner;
  @override
  int get players => 2;
  @override
  int get turn => history.length % 2;
  @override
  bool get finished => winner != null || history.length == 42;
  @override
  List<String> get legalMoves => finished
      ? []
      : [
          for (var c = 0; c < 7; c++)
            if (cells[c] == -1) '$c',
        ];
  @override
  bool play(String move) {
    if (!legalMoves.contains(move)) return false;
    final col = int.parse(move);
    var row = 5;
    while (cells[row * 7 + col] != -1) {
      row--;
    }
    final player = turn;
    cells[row * 7 + col] = player;
    history.add(col);
    for (final direction in [
      [1, 0],
      [0, 1],
      [1, 1],
      [1, -1],
    ]) {
      final line = [row * 7 + col];
      for (final sign in [-1, 1]) {
        var r = row + direction[0] * sign;
        var c = col + direction[1] * sign;
        while (r >= 0 &&
            r < 6 &&
            c >= 0 &&
            c < 7 &&
            cells[r * 7 + c] == player) {
          line.add(r * 7 + c);
          r += direction[0] * sign;
          c += direction[1] * sign;
        }
      }
      if (line.length >= 4) {
        winner = player;
        winningCells.addAll(line);
        break;
      }
    }
    return true;
  }

  @override
  Map<String, dynamic> toJson() => {'moves': history};
  factory ConnectGame.fromJson(Map<String, dynamic> data) {
    final game = ConnectGame();
    for (final col in (data['moves'] as List).cast<int>()) {
      if (!game.play('$col')) throw const FormatException('Invalid drop');
    }
    return game;
  }
}

String chooseArcadeMove(Map<String, dynamic> input) {
  final type = input['type'];
  final data = input['game'] as Map<String, dynamic>;
  final random = Random();
  if (type == 'darts') {
    return '${random.nextInt(281) - 140}:${-600 + random.nextInt(241) - 120}';
  }
  if (type == 'connect') {
    final game = ConnectGame.fromJson(data);
    final moves = game.legalMoves..shuffle(random);
    var best = -10000;
    var chosen = moves.first;
    for (final move in moves) {
      final next = ConnectGame.fromJson(data)..play(move);
      if (next.winner == game.turn) return move;
      var score = 3 - (int.parse(move) - 3).abs();
      for (final reply in next.legalMoves) {
        final trial = ConnectGame.fromJson(next.toJson())..play(reply);
        if (trial.winner != null) score -= 100;
      }
      if (score > best) {
        best = score;
        chosen = move;
      }
    }
    return chosen;
  }
  final game = WordGame.fromJson(data);
  final moves = game.legalMoves..shuffle(random);
  var best = -1;
  var chosen = moves.first;
  for (final move in moves) {
    final trial = WordGame.fromJson(data)..play(move);
    final gain = trial.scores[game.turn] - game.scores[game.turn];
    final letter = move.split(':')[1];
    final score = gain * 100 + ('ETAOINSHR'.contains(letter) ? 2 : 0);
    if (score > best) {
      best = score;
      chosen = move;
    }
  }
  return chosen;
}
