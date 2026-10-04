import 'dart:io';

import 'room_server.dart';

Future<void> main() async {
  final host = Platform.environment['HOST'] ?? '127.0.0.1';
  final port = int.parse(Platform.environment['PORT'] ?? '8787');
  if (port < 1 || port > 65535) {
    throw ArgumentError('PORT must be between 1 and 65535');
  }
  final server = RoomServer();
  await server.start(host: host, port: port);
  stdout.writeln('Pocket Party rooms listening on http://$host:$port');
  stdout.writeln(
    'Rooms live in memory and expire after two hours of inactivity.',
  );
  var stopping = false;
  Future<void> shutdown(ProcessSignal _) async {
    if (stopping) return;
    stopping = true;
    await server.close();
    exit(0);
  }

  ProcessSignal.sigint.watch().listen(shutdown);
  if (!Platform.isWindows) ProcessSignal.sigterm.watch().listen(shutdown);
}
