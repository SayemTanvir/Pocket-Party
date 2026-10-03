import 'dart:io';

import 'room_server.dart';

Future<void> main() async {
  final host = Platform.environment['HOST'] ?? '127.0.0.1';
  final port = int.parse(Platform.environment['PORT'] ?? '8787');
  final server = RoomServer();
  await server.start(host: host, port: port);
  stdout.writeln('Pocket Party rooms listening on http://$host:$port');
  stdout.writeln(
    'Rooms live in memory and expire after two hours of inactivity.',
  );
  ProcessSignal.sigint.watch().listen((_) async {
    await server.close();
    exit(0);
  });
}
