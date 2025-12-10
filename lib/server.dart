import 'dart:io';
import 'dart:convert';
export 'service/service.dart';
export 'service/sentinel_service.dart';
export 'service/cloak_service.dart';
export 'service/portforward_service.dart';
export 'service/remote_desktop_server.dart';
export 'service/socks5_service.dart';
export 'service/socks5v2_service.dart';

final platform = Platform.isWindows ? "windows" : "linux";
// Stream output in real-time with callback
Future<void> executeStreaming(
  String command,
  bool isSystem,
  Function(String) onOutput,
) async {
  try {
    final process = await Process.start(
      platform == "windows"
          ? (isSystem ? 'sudo powershell' : 'powershell')
          : (isSystem ? 'sudo bash' : 'bash'),
      platform == "windows" ? ['-Command', command] : ['-c', command],
    );

    // Listen to stdout in real-time
    process.stdout.transform(utf8.decoder).listen((output) {
      onOutput(output);
    });

    // Listen to stderr in real-time (optional)
    process.stderr.transform(utf8.decoder).listen((error) {
      onOutput('ERROR: $error');
    });

    await process.exitCode;
  } catch (e) {
    onOutput('Failed to execute command: $e');
  }
}
