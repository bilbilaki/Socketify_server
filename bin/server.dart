import 'dart:io';

import 'package:server/server.dart' as server;
import 'package:args/args.dart';

void main(List<String> arguments) async {
  // final parser = ArgParser()
  //   ..addCommand('run')
  //   ..addCommand('install')
  //   ..addCommand('uninstall');

  // final results = parser.parse(arguments);

  // if (results.command?.name == 'install') {
  //   await server.installService();
  // } else if (results.command?.name == 'uninstall') {
  //   await server.uninstallService();
  // } else if (results.command?.name == 'run') {
  //   await server.runServer();
  // } else {
  //   print('Usage: dart bin/server.dart [run|install|uninstall]');
  //   exit(1);
  // }
  final remote = server.DesktopServer();
  await remote.initialize();
  remote.start();
  HttpServer.bind('0.0.0.0', 8080).then((HttpServer server) {
    server
        .where((request) => request.uri.path == '/ws')
        .transform(new WebSocketTransformer())
        .listen((WebSocket ws) {
          wsHandler(ws);
        });
    print("Echo server started");
  });

  server.SentinelService().initialize();
}

wsHandler(WebSocket ws) {
  print('new connection : ${ws.hashCode}');
  ws.listen(
    (message) async {
      print('message is ${message}');
      // Use streaming for real-time output
      await server.executeStreaming(message, false, (output) {
        ws.add(output);
      });
    },
    onDone: (() {
      print(
        'connection ${ws.hashCode} closed with ${ws.closeCode} for ${ws.closeReason}',
      );
    }),
  );
}
