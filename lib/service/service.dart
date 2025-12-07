import 'dart:io';
import 'dart:convert';
import 'dart:math';
import 'package:args/args.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_web_socket/shelf_web_socket.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:path/path.dart' as p;
// Import your new Docker Manager

// --- CONFIGURATION ---
const String serviceName = 'dart-manager';
const int port = 8080;
const String configPath = '/etc/dart-manager/config.json';

// Initialize Docker Manager globally or pass it down

void main(List<String> arguments) async {
  final parser = ArgParser()
    ..addCommand('run')
    ..addCommand('install')
    ..addCommand('uninstall');

  final results = parser.parse(arguments);

  if (results.command?.name == 'install') {
    await installService();
  } else if (results.command?.name == 'uninstall') {
    await uninstallService();
  } else if (results.command?.name == 'run') {
    await runServer();
  } else {
    print('Usage: dart bin/server.dart [run|install|uninstall]');
    exit(1);
  }
}

// ---------------------------------------------------------
// 1. WEBSOCKET SERVER & AUTHENTICATION
// ---------------------------------------------------------

Future<void> runServer() async {
  final config = _loadConfig();
  if (config == null) {
    print('Error: Configuration not found. Please run "sudo ... install" first.');
    exit(1);
  }

  final String validToken = config['token'];
  print('Starting server on port $port...');

  var handler = webSocketHandler((WebSocketChannel webSocket, protocol) {
    print('Client connected.');
    bool isAuthenticated = false;

    webSocket.stream.listen((message) {
      if (!isAuthenticated) {
        try {
          final data = jsonDecode(message);
          if (data['type'] == 'auth' && data['token'] == validToken) {
            isAuthenticated = true;
            webSocket.sink.add(jsonEncode({'status': 'authenticated', 'msg': 'Welcome Root.'}));
          } else {
            webSocket.sink.add(jsonEncode({'status': 'error', 'msg': 'Invalid Token'}));
            webSocket.sink.close(); 
          }
        } catch (e) {
          webSocket.sink.close();
        }
        return;
      }

      _handleCommand(message, webSocket);
    }, onDone: () => print('Client disconnected'));
  });

  await shelf_io.serve(handler, InternetAddress.anyIPv4, port);
  print('Serving at ws://0.0.0.0:$port');
}

void _handleCommand(dynamic message, WebSocketChannel ws) async {
  try {
    final data = jsonDecode(message);
    
    // --- COMMAND SWITCH ---
    switch (data['command']) {
      case 'uptime':
        final result = await Process.run('uptime', []);
        ws.sink.add(jsonEncode({'type': 'response', 'output': result.stdout.toString().trim()}));
        break;
      


      default:
        ws.sink.add(jsonEncode({'type': 'error', 'msg': 'Unknown command'}));
    }
  } catch (e) {
    ws.sink.add(jsonEncode({'type': 'error', 'msg': e.toString()}));
  }
}

// ---------------------------------------------------------
// 2. SERVICE MANAGEMENT (REMAINS SAME)
// ---------------------------------------------------------

Future<void> installService() async {
  if (!_isRoot()) {
    print('Error: Install must be run as root (sudo).');
    exit(1);
  }

  print('Installing $serviceName service...');
  final directory = Directory(p.dirname(configPath));
  if (!directory.existsSync()) {
    directory.createSync(recursive: true);
  }

  final token = _generateRandomString(32);
  File(configPath).writeAsStringSync(jsonEncode({'token': token}));
  await Process.run('chmod', ['600', configPath]);

  final execPath = '/usr/local/bin/dart-manager'; 
  final serviceFileContent = '''
[Unit]
Description=Dart Server Manager
After=docker.service network.target
Requires=docker.service

[Service]
User=root
ExecStart=$execPath run
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
''';

  final servicePath = '/etc/systemd/system/$serviceName.service';
  File(servicePath).writeAsStringSync(serviceFileContent);

  await Process.run('systemctl', ['daemon-reload']);
  await Process.run('systemctl', ['enable', serviceName]);
  await Process.run('systemctl', ['start', serviceName]);

  print('---------------------------------------------');
  print('Service Installed and Started!');
  print('Token: $token');
  print('---------------------------------------------');
}

Future<void> uninstallService() async {
  if (!_isRoot()) {
    print('Error: Uninstall must be run as root.');
    exit(1);
  }
  await Process.run('systemctl', ['stop', serviceName]);
  await Process.run('systemctl', ['disable', serviceName]);
  final serviceFile = File('/etc/systemd/system/$serviceName.service');
  if (serviceFile.existsSync()) serviceFile.deleteSync();
  await Process.run('systemctl', ['daemon-reload']);
  print('Service removed.');
}

bool _isRoot() {
  final result = Process.runSync('id', ['-u']);
  return result.stdout.toString().trim() == '0';
}

Map<String, dynamic>? _loadConfig() {
  try {
    final file = File(configPath);
    if (!file.existsSync()) return null;
    return jsonDecode(file.readAsStringSync());
  } catch (e) {
    return null;
  }
}

String _generateRandomString(int length) {
  const chars = 'AaBbCcDdEeFfGgHhIiJjKkLlMmNnOoPpQqRrSsTtUuVvWwXxYyZz1234567890';
  Random rnd = Random.secure();
  return String.fromCharCodes(Iterable.generate(
      length, (_) => chars.codeUnitAt(rnd.nextInt(chars.length))));
}