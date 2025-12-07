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
// Future<void> addToPath(
//   String newPath, {
//   bool isSystem = false,
//   bool remove = false,
// }) async {
//   final scope = isSystem ? 'Machine' : 'User';

//   if (!remove) {
//     final psCommand =
//         '''
//     \$scope = [System.EnvironmentVariableTarget]::$scope
//     \$currentPath = [System.Environment]::GetEnvironmentVariable('Path', \$scope)

//     # Check if the new path (case-insensitive) is already in the split array
//     if (-not \$currentPath.Split(';').Contains('$newPath', [StringComparer]::InvariantCultureIgnoreCase)) {
//         # Append the new path with a leading semicolon (unless the current path is empty)
//         \$newPathList = \$currentPath.TrimEnd(';') + ';$newPath'
//         [System.Environment]::SetEnvironmentVariable('Path', \$newPathList, \$scope)
//         Write-Output "Success"
//     } else {
//         Write-Output "AlreadyExists"
//     }
//   ''';

//     await execute(psCommand, isSystem);
//   } else {
//     final psCommand =
//         '''
//     \$scope = [System.EnvironmentVariableTarget]::$scope
//     \$currentPath = [System.Environment]::GetEnvironmentVariable('Path', \$scope)

//     # Split the path into an array, filtering out the path to remove (case-insensitive)
//     \$updatedPathArray = \$currentPath.Split(';') | Where-Object {
//       \$_ -ne '' -and -not \$_ -eq '$newPath' -isnot [System.StringComparison]::InvariantCultureIgnoreCase
//     }

//     # Join the array back into a semicolon-separated string
//     \$newPath = \$updatedPathArray -join ';'

//     # Check if the path was actually removed (i.e., if the old and new path are different)
//     if (\$newPath -ne \$currentPath) {
//         [System.Environment]::SetEnvironmentVariable('Path', \$newPath, \$scope)
//         Write-Output "Success"
//     } else {
//         Write-Output "NotFound"
//     }
//   ''';

//     await execute(psCommand, isSystem);
//   }
// }

// Future<String> execute(String command, bool isSystem) async {
//   try {
//     if (platform == "windows") {
//       final result = await Process.run(
//         isSystem ? 'sudo powershell' : 'powershell',
//         ['-Command', command],
//       );
//       return result.stdout.toString();
//     } else {
//       final result = await Process.run(isSystem ? 'sudo bash' : 'bash', [
//         '-c',
//         command,
//       ]);
//       return result.stdout.toString();
//     }
//   } catch (e) {
//     return 'Failed to execute command: $e';
//   }
// }

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
