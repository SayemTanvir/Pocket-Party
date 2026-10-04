import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:pocket_party/main.dart';
import 'package:pocket_party/games/chess_page.dart';
import 'package:pocket_party/online/online_session.dart';

import '../server/room_server.dart';

void main() {
  testWidgets('A player can launch a local match', (tester) async {
    await tester.pumpWidget(const PartyApp());
    expect(find.text('Pocket Party'), findsOneWidget);
    await tester.ensureVisible(find.text('Start game'));
    await tester.tap(find.text('Start game'));
    await tester.pumpAndSettle();
    expect(find.text('Player 1’s turn'), findsOneWidget);
    final semantics = tester.ensureSemantics();
    await tester.tap(find.bySemanticsLabel('Horizontal line 1, 1'));
    await tester.pump();
    expect(find.text('Player 2’s turn'), findsOneWidget);
    semantics.dispose();
    expect(tester.takeException(), isNull);
  });

  testWidgets('Chess board selects a pawn and makes a legal move', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: ChessPage()));
    final semantics = tester.ensureSemantics();
    await tester.tap(find.bySemanticsLabel('e2 white pawn'));
    await tester.pump();
    await tester.tap(find.bySemanticsLabel('e4 empty'));
    await tester.pump();
    expect(find.text('Black to move'), findsOneWidget);
    expect(find.text('1. e4'), findsOneWidget);
    expect(tester.takeException(), isNull);
    semantics.dispose();
  });

  testWidgets('Chess selection survives an unchanged online refresh', (
    tester,
  ) async {
    HttpOverrides.global = null;
    final server = RoomServer();
    late OnlineSession host;
    late OnlineSession guest;
    await tester.runAsync(() async {
      final http = await server.start(port: 0);
      final base = 'http://127.0.0.1:${http.port}';
      host = await OnlineSession.open(base, players: 2, gameType: 'chess');
      guest = await OnlineSession.open(base, code: host.code);
      await host.refresh();
    });
    await tester.pumpWidget(MaterialApp(home: ChessPage(online: host)));
    final semantics = tester.ensureSemantics();
    await tester.ensureVisible(find.byKey(const ValueKey('e2')));
    await tester.pumpAndSettle();
    await tester.tap(find.bySemanticsLabel('e2 white pawn'));
    await tester.pump();
    await tester.runAsync(host.refresh);
    await tester.pump();
    await tester.runAsync(() async {
      await tester.tap(find.bySemanticsLabel('e4 empty'));
      await Future<void>.delayed(const Duration(milliseconds: 300));
      await guest.refresh();
    });
    expect(guest.chessGame.history, ['e2e4']);
    expect(host.error, isNull);
    semantics.dispose();
    await tester.pumpWidget(const SizedBox());
    guest.dispose();
    await tester.runAsync(server.close);
  });

  testWidgets('Waiting board accepts a move after another player joins', (
    tester,
  ) async {
    HttpOverrides.global = null;
    final server = RoomServer();
    late OnlineSession host;
    late OnlineSession guest;
    await tester.runAsync(() async {
      final http = await server.start(port: 0);
      final base = 'http://127.0.0.1:${http.port}';
      host = await OnlineSession.open(base, players: 2);
    });
    await tester.pumpWidget(
      MaterialApp(home: MatchPage(players: 2, bot: false, online: host)),
    );
    expect(find.text('Waiting for players (1/2)'), findsOneWidget);
    await tester.runAsync(() async {
      guest = await OnlineSession.open(host.baseUrl, code: host.code);
      await host.refresh();
    });
    await tester.pump();
    expect(find.text('Your turn'), findsOneWidget);
    expect(host.canMove, isTrue);
    final semantics = tester.ensureSemantics();
    await tester.runAsync(() async {
      await tester.tap(find.bySemanticsLabel('Horizontal line 1, 1'));
      expect(host.busy, isTrue, reason: 'Touch must submit the move');
      await Future<void>.delayed(const Duration(milliseconds: 500));
      await guest.refresh();
    });
    expect(host.error, isNull);
    expect(server.rooms[host.code]!.game.edges, contains('h:0:0'));
    expect(guest.game.edges, contains('h:0:0'));
    semantics.dispose();
    await tester.pumpWidget(const SizedBox());
    guest.dispose();
    await tester.runAsync(server.close);
  });
}
