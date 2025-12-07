import 'package:server/service/socks5_service.dart';

/// Example usage of Socks5Service
Future<void> main() async {
  final service = Socks5Service();

  try {
    // Initialize the service
    await service.initialize();
    print('Socks5 service initialized');

    // Example 1: Create a simple SOCKS5 server without authentication
    print('\n--- Example 1: SOCKS5 server without authentication ---');
    final simpleServerID = await service.createWithoutAuthServer(
      listenPort: 1080,
    );
    print('Simple server created with ID: $simpleServerID');

    final simpleTaskID = await service.startSocks5Server(simpleServerID);
    print('Simple server started with task ID: $simpleTaskID');

    // Example 2: Create a SOCKS5 server with authentication
    print('\n--- Example 2: SOCKS5 server with authentication ---');
    final authServerID = await service.createWithAuthServer(listenPort: 1081);
    print('Auth server created with ID: $authServerID');

    final authTaskID = await service.startSocks5Server(authServerID);
    print('Auth server started with task ID: $authTaskID');

    // Example 3: Create a direct TCP SOCKS5 server with custom auth
    print('\n--- Example 3: Direct TCP server with custom credentials ---');
    final tcpServerID = await service.createDirectServerTCP(
      listenPort: 1082,
      username: 'myuser',
      password: 'mypassword',
    );
    print('TCP server created with ID: $tcpServerID');

    final tcpTaskID = await service.startSocks5Server(tcpServerID);
    print('TCP server started with task ID: $tcpTaskID');

    // Example 4: Create a direct UDP SOCKS5 server
    print('\n--- Example 4: Direct UDP server ---');
    final udpServerID = await service.createDirectServerUDP(
      listenPort: 1083,
      username: 'udpuser',
      password: 'udppass',
    );
    print('UDP server created with ID: $udpServerID');

    final udpTaskID = await service.startSocks5Server(udpServerID);
    print('UDP server started with task ID: $udpTaskID');

    // Example 5: Create a UDP proxy to another SOCKS5 server
    print('\n--- Example 5: UDP proxy to upstream SOCKS5 ---');
    final proxyServerID = await service.createProxyToSocks5ServerUDP(
      listenPort: 1084,
      username: 'localuser',
      password: 'localpass',
      proxyAddr: '192.168.1.100:1080',
      proxyUser: 'upstreamuser',
      proxyPass: 'upstreampass',
    );
    print('Proxy server created with ID: $proxyServerID');

    final proxyTaskID = await service.startSocks5Server(proxyServerID);
    print('Proxy server started with task ID: $proxyTaskID');

    // Keep the servers running
    print('\n--- All servers are running ---');
    print('Simple server (no auth): localhost:1080');
    print('Auth server: localhost:1081');
    print('TCP server: localhost:1082 (user: myuser, pass: mypassword)');
    print('UDP server: localhost:1083 (user: udpuser, pass: udppass)');
    print('Proxy server: localhost:1084 (user: localuser, pass: localpass)');
    print('\nPress Ctrl+C to stop all servers...');

    // Keep running for demonstration (in real use, handle shutdown signals)
    await Future.delayed(Duration(minutes: 5));

    // Clean shutdown
    print('\n--- Stopping all servers ---');
    service.stopTask(simpleTaskID);
    await service.stopSocks5Server(simpleServerID);
    print('Simple server stopped');

    service.stopTask(authTaskID);
    await service.stopSocks5Server(authServerID);
    print('Auth server stopped');

    service.stopTask(tcpTaskID);
    await service.stopSocks5Server(tcpServerID);
    print('TCP server stopped');

    service.stopTask(udpTaskID);
    await service.stopSocks5Server(udpServerID);
    print('UDP server stopped');

    service.stopTask(proxyTaskID);
    await service.stopSocks5Server(proxyServerID);
    print('Proxy server stopped');
  } catch (e) {
    print('Error: $e');
  } finally {
    // Cleanup
    service.dispose();
    print('\nService disposed');
  }
}

/// Simple example - just start one server
Future<void> simpleExample() async {
  final service = Socks5Service();

  await service.initialize();

  // Create and start a simple SOCKS5 server on port 1080
  final serverID = await service.createWithoutAuthServer(listenPort: 1080);
  final taskID = await service.startSocks5Server(serverID);

  print('SOCKS5 server running on localhost:1080');
  print('Task ID: $taskID');

  // Keep running...
  await Future.delayed(Duration(hours: 1));

  // Stop when done
  service.stopTask(taskID);
  await service.stopSocks5Server(serverID);
  service.dispose();
}
