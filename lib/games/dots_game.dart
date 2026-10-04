import 'party_game.dart';

class DotsGame implements PartyGame {
  DotsGame({this.size = 7, this.players = 2})
    : scores = List.filled(players, 0);

  final int size;
  @override
  final int players;
  final List<int> scores;
  final Set<String> edges = {};
  final Map<String, int> edgeOwners = {};
  final Map<String, int> boxes = {};
  @override
  int turn = 0;

  String edge(bool horizontal, int row, int col) =>
      '${horizontal ? 'h' : 'v'}:$row:$col';
  @override
  bool get finished => boxes.length == (size - 1) * (size - 1);

  @override
  List<String> get legalMoves => [
    for (var r = 0; r < size; r++)
      for (var c = 0; c < size - 1; c++)
        if (!edges.contains(edge(true, r, c))) edge(true, r, c),
    for (var r = 0; r < size - 1; r++)
      for (var c = 0; c < size; c++)
        if (!edges.contains(edge(false, r, c))) edge(false, r, c),
  ];

  @override
  bool play(String move) {
    if (finished || !legalMoves.contains(move)) return false;
    edges.add(move);
    edgeOwners[move] = turn;
    var gained = 0;
    for (var r = 0; r < size - 1; r++) {
      for (var c = 0; c < size - 1; c++) {
        final key = '$r:$c';
        if (!boxes.containsKey(key) &&
            edges.contains(edge(true, r, c)) &&
            edges.contains(edge(true, r + 1, c)) &&
            edges.contains(edge(false, r, c)) &&
            edges.contains(edge(false, r, c + 1))) {
          boxes[key] = turn;
          gained++;
        }
      }
    }
    scores[turn] += gained;
    if (gained == 0) turn = (turn + 1) % players;
    return true;
  }

  DotsGame copy() {
    final result = DotsGame(size: size, players: players);
    result.edges.addAll(edges);
    result.edgeOwners.addAll(edgeOwners);
    result.boxes.addAll(boxes);
    result.scores.setAll(0, scores);
    result.turn = turn;
    return result;
  }

  @override
  Map<String, dynamic> toJson() => {
    'size': size,
    'players': players,
    'scores': scores,
    'edges': edges.toList(),
    'edgeOwners': edgeOwners,
    'boxes': boxes,
    'turn': turn,
  };

  factory DotsGame.fromJson(Map<String, dynamic> json) {
    final game = DotsGame(
      size: json['size'] as int,
      players: json['players'] as int,
    );
    game.edges.addAll((json['edges'] as List).cast<String>());
    game.edgeOwners.addAll(Map<String, int>.from(json['edgeOwners'] as Map));
    game.boxes.addAll(Map<String, int>.from(json['boxes'] as Map));
    game.scores.setAll(0, (json['scores'] as List).cast<int>());
    game.turn = json['turn'] as int;
    return game;
  }
}
