import 'dart:io';
import 'dart:convert';
import 'dart:math';
import 'package:args/args.dart';
import 'package:commander_ui/commander_ui.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_web_socket/shelf_web_socket.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:path/path.dart' as p;
import '../server.dart';
// Import your new Docker Manager

// --- CONFIGURATION ---
const String serviceName = 'dart-manager';
const int port = 8080;

String get appDir => Platform.isWindows
    ? '${Platform.environment['USERPROFILE']}\\dart-manager'
    : '/etc/dart-manager';
String get configPath => p.join(appDir, 'config.json');
String get execPath => Platform.isWindows
    ? p.join(appDir, 'bin', 'server.dart')
    : '/usr/local/bin/dart-manager';

// Initialize Docker Manager globally or pass it down

void main(List<String> arguments) async {

    final commander = Commander(level: Level.verbose);

  final value = await commander.select('what you want to do ?',
      onDisplay: (value) => value,
      placeholder: 'Type to search',
      defaultValue: 'run',
      options: ['run', 'install', 'uninstall']);



  final results = value;

  if (results == 'install') {
    await installService();
  } else if (results == 'uninstall') {
    await uninstallService();
  } else if (results == 'run') {
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
    print(
      'Error: Configuration not found. Please run "sudo ... install" first.',
    );
    exit(1);
  }

  final String validToken = config['token'];
  print('Starting server on port $port...');

  var handler = webSocketHandler((WebSocketChannel webSocket, protocol) {
    print('Client connected.');
    bool isAuthenticated = true;

    webSocket.stream.listen((message) {
      if (!isAuthenticated) {
        try {
          final data = jsonDecode(message);
          if (data['type'] == 'auth' && data['token'] == validToken) {
            isAuthenticated = true;
            webSocket.sink.add(
              jsonEncode({'status': 'authenticated', 'msg': 'Welcome Root.'}),
            );
          } else {
            webSocket.sink.add(
              jsonEncode({'status': 'error', 'msg': 'Invalid Token'}),
            );
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
        ws.sink.add(
          jsonEncode({
            'type': 'response',
            'output': result.stdout.toString().trim(),
          }),
        );
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
  if (Platform.isWindows) {
    print('Installing $serviceName service on Windows...');
    final directory = Directory(appDir);
    if (!directory.existsSync()) {
      directory.createSync(recursive: true);
    }
    // Copy bin/server.dart
    final binDir = Directory(p.join(appDir, 'bin'));
    binDir.createSync(recursive: true);
    File(
      p.join(binDir.path, 'server.dart'),
    ).writeAsStringSync(File('bin/server.dart').readAsStringSync());

    final token = _generateRandomString(32);
    File(configPath).writeAsStringSync(jsonEncode({'token': token}));

    // Find dart path
    final dartResult = Process.runSync('where', ['dart']);
    if (dartResult.exitCode != 0) {
      print('Error: dart not found in PATH');
      exit(1);
    }
    final dartPath = dartResult.stdout.toString().trim().split('\n')[0];
    final binaryPath = '"$dartPath" "$execPath" run';
    final psCommand =
        'New-Service -Name "$serviceName" -BinaryPathName "$binaryPath" -DisplayName "Dart Server Manager" -StartupType Automatic';
    final result = Process.runSync('powershell.exe', ['-Command', psCommand]);
    if (result.exitCode != 0) {
      print('Error creating service: ${result.stderr}');
      exit(1);
    }
    print('---------------------------------------------');
    print('Service Installed and Started!');
    print('Token: $token');
    print('---------------------------------------------');
  } else {
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

    final execPathLocal = '/usr/local/bin/dart-manager';
    final serviceFileContent =
        '''
[Unit]
Description=Dart Server Manager
After=docker.service network.target
Requires=docker.service

[Service]
User=root
ExecStart=$execPathLocal run
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
}

Future<void> uninstallService() async {
  if (Platform.isWindows) {
    final psCommand =
        'Stop-Service -Name "$serviceName" -ErrorAction SilentlyContinue; Remove-Service -Name "$serviceName" -ErrorAction SilentlyContinue';
    final result = Process.runSync('powershell.exe', ['-Command', psCommand]);
    if (result.exitCode != 0) {
      print('Error removing service: ${result.stderr}');
    } else {
      print('Service removed.');
    }
  } else {
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
  const chars =
      'AaBbCcDdEeFfGgHhIiJjKkLlMmNnOoPpQqRrSsTtUuVvWwXxYyZz1234567890';
  Random rnd = Random.secure();
  return String.fromCharCodes(
    Iterable.generate(
      length,
      (_) => chars.codeUnitAt(rnd.nextInt(chars.length)),
    ),
  );
}
