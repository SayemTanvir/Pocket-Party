import 'chess_game.dart';
import 'dots_game.dart';
import 'party_game.dart';

int? matchWinner(PartyGame game) {
  if (!game.finished) return null;
  if (game is ChessGame) return game.winner;
  final scores = (game as DotsGame).scores;
  var best = scores.first;
  for (final score in scores) {
    if (score > best) best = score;
  }
  final winners = [
    for (var i = 0; i < scores.length; i++)
      if (scores[i] == best) i,
  ];
  return winners.length == 1 ? winners.single : null;
}

class MatchSeries {
  MatchSeries(int players)
    : wins = List.filled(players, 0),
      losses = List.filled(players, 0),
      draws = List.filled(players, 0);
  final List<int> wins, losses, draws;
  void record(PartyGame game) {
    if (!game.finished) return;
    final winner = matchWinner(game);
    final best = game is DotsGame
        ? game.scores.reduce((a, b) => a > b ? a : b)
        : null;
    for (var p = 0; p < wins.length; p++) {
      if (winner == null) {
        if (game is DotsGame && game.scores[p] != best) {
          losses[p]++;
        } else {
          draws[p]++;
        }
      } else if (p == winner) {
        wins[p]++;
      } else {
        losses[p]++;
      }
    }
  }

  Map<String, dynamic> toJson() => {
    'wins': wins,
    'losses': losses,
    'draws': draws,
  };
  factory MatchSeries.fromJson(Map<String, dynamic> data) {
    final series = MatchSeries((data['wins'] as List).length);
    series.wins.setAll(0, (data['wins'] as List).cast<int>());
    series.losses.setAll(0, (data['losses'] as List).cast<int>());
    series.draws.setAll(0, (data['draws'] as List).cast<int>());
    return series;
  }
}
