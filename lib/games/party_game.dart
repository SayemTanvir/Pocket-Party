abstract class PartyGame {
  int get players;
  int get turn;
  bool get finished;
  List<String> get legalMoves;
  bool play(String move);
  Map<String, dynamic> toJson();
}
