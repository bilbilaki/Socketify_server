import 'package:server/service/socks5v2_service.dart';

/// Example usage of Socks5V2Service
/// This version includes both server and client capabilities
Future<void> main() async {
  final service = Socks5V2Service();

  try {
    // Initialize the service
    await service.initialize();
    print('Socks5V2 service initialized\n');

    // ==================== SERVER EXAMPLES ====================

    // Example 1: Create a simple SOCKS5 server without authentication
    print('--- Example 1: SOCKS5 server without authentication ---');
    final simpleServerID = await service.createWithoutAuthServer(
      listenPort: 1080,
    );
    print('Simple server created with ID: $simpleServerID');

    final simpleTaskID = await service.startSocks5Server(simpleServerID);
    print('Simple server started with task ID: $simpleTaskID\n');

    // Example 2: Create a SOCKS5 server with authentication
    print('--- Example 2: SOCKS5 server with authentication ---');
    final authServerID = await service.createWithAuthServer(listenPort: 1081);
    print('Auth server created with ID: $authServerID');

    final authTaskID = await service.startSocks5Server(authServerID);
    print('Auth server started with task ID: $authTaskID\n');

    // Example 3: Create a direct TCP SOCKS5 server with custom auth
    print('--- Example 3: Direct TCP server with custom credentials ---');
    final tcpServerID = await service.createDirectServerTCP(
      listenPort: 1082,
      username: 'myuser',
      password: 'mypassword',
    );
    print('TCP server created with ID: $tcpServerID');

    final tcpTaskID = await service.startSocks5Server(tcpServerID);
    print('TCP server started with task ID: $tcpTaskID\n');

    // Example 4: Create a direct UDP SOCKS5 server
    print('--- Example 4: Direct UDP server ---');
    final udpServerID = await service.createDirectServerUDP(
      listenPort: 1083,
      username: 'udpuser',
      password: 'udppass',
    );
    print('UDP server created with ID: $udpServerID');

    final udpTaskID = await service.startSocks5Server(udpServerID);
    print('UDP server started with task ID: $udpTaskID\n');

    // Example 5: Create a TCP proxy to another SOCKS5 server
    print('--- Example 5: TCP proxy to upstream SOCKS5 ---');
    final tcpProxyID = await service.createProxyToSocks5ServerTCP(
      listenPort: 1084,
      username: 'localuser',
      password: 'localpass',
      proxyAddr: '192.168.1.100:1080',
      proxyUser: 'upstreamuser',
      proxyPass: 'upstreampass',
    );
    print('TCP proxy server created with ID: $tcpProxyID');

    final tcpProxyTaskID = await service.startSocks5Server(tcpProxyID);
    print('TCP proxy server started with task ID: $tcpProxyTaskID\n');

    // Example 6: Create a UDP proxy to another SOCKS5 server
    print('--- Example 6: UDP proxy to upstream SOCKS5 ---');
    final udpProxyID = await service.createProxyToSocks5ServerUDP(
      listenPort: 1085,
      username: 'localuser2',
      password: 'localpass2',
      proxyAddr: '192.168.1.100:1080',
      proxyUser: 'upstreamuser2',
      proxyPass: 'upstreampass2',
    );
    print('UDP proxy server created with ID: $udpProxyID');

    final udpProxyTaskID = await service.startSocks5Server(udpProxyID);
    print('UDP proxy server started with task ID: $udpProxyTaskID\n');

    // ==================== CLIENT EXAMPLES ====================

    // Example 7: Connect to a target via SOCKS5 proxy (TCP)
    print('--- Example 7: Client TCP connection via SOCKS5 ---');
    final tcpConnID = await service.connectDirectTCP(
      socksAddr: '127.0.0.1:1080',
      targetAddr: 'example.com:80',
    );
    print('TCP connection established with ID: $tcpConnID\n');

    // Example 8: Connect to SOCKS5 proxy with authentication (TCP)
    print('--- Example 8: Client TCP connection with auth ---');
    final authTcpConnID = await service.connectDirectTCP(
      socksAddr: '127.0.0.1:1082',
      username: 'myuser',
      password: 'mypassword',
      targetAddr: 'example.com:443',
    );
    print('Authenticated TCP connection established with ID: $authTcpConnID\n');

    // Example 9: UDP association via SOCKS5 proxy
    print('--- Example 9: Client UDP association ---');
    final udpConnID = await service.connectDirectUDP(
      socksAddr: '127.0.0.1:1083',
      username: 'udpuser',
      password: 'udppass',
    );
    print('UDP association established with ID: $udpConnID\n');

    // ==================== STATUS ====================

    print('--- All servers are running ---');
    print('Simple server (no auth): localhost:1080');
    print('Auth server: localhost:1081');
    print('TCP server: localhost:1082 (user: myuser, pass: mypassword)');
    print('UDP server: localhost:1083 (user: udpuser, pass: udppass)');
    print(
      'TCP Proxy server: localhost:1084 (user: localuser, pass: localpass)',
    );
    print(
      'UDP Proxy server: localhost:1085 (user: localuser2, pass: localpass2)',
    );
    print('\nClient connections:');
    print('TCP connection to example.com:80 via localhost:1080');
    print('TCP connection to example.com:443 via localhost:1082');
    print('UDP association via localhost:1083');
    print('\nPress Ctrl+C to stop all servers...\n');

    // Keep running for demonstration
    await Future.delayed(Duration(minutes: 5));

    // Clean shutdown
    print('--- Stopping all servers and connections ---');

    // Stop client connections
    service.stopTask(tcpConnID);
    print('TCP connection stopped');

    service.stopTask(authTcpConnID);
    print('Authenticated TCP connection stopped');

    service.stopTask(udpConnID);
    print('UDP association stopped');

    // Stop servers
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

    service.stopTask(tcpProxyTaskID);
    await service.stopSocks5Server(tcpProxyID);
    print('TCP proxy server stopped');

    service.stopTask(udpProxyTaskID);
    await service.stopSocks5Server(udpProxyID);
    print('UDP proxy server stopped');
  } catch (e) {
    print('Error: $e');
  } finally {
    // Cleanup
    service.dispose();
    print('\nService disposed');
  }
}

/// Simple server example
Future<void> simpleServerExample() async {
  final service = Socks5V2Service();
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

/// Simple client example
Future<void> simpleClientExample() async {
  final service = Socks5V2Service();
  await service.initialize();

  // Connect to example.com via SOCKS5 proxy
  final connID = await service.connectDirectTCP(
    socksAddr: '127.0.0.1:1080',
    targetAddr: 'example.com:80',
  );

  print('Connected to example.com:80 via SOCKS5 proxy');
  print('Connection ID: $connID');

  // Use the connection...
  await Future.delayed(Duration(seconds: 30));

  // Stop when done
  service.stopTask(connID);
  service.dispose();
}

/// Proxy chain example
Future<void> proxyChainExample() async {
  final service = Socks5V2Service();
  await service.initialize();

  // Create a local SOCKS5 server that forwards to an upstream proxy
  final serverID = await service.createProxyToSocks5ServerTCP(
    listenPort: 1080,
    username: 'localuser',
    password: 'localpass',
    proxyAddr: 'upstream.proxy.com:1080',
    proxyUser: 'upstreamuser',
    proxyPass: 'upstreampass',
  );

  final taskID = await service.startSocks5Server(serverID);

  print('Proxy chain server running on localhost:1080');
  print('Forwarding to upstream.proxy.com:1080');
  print('Task ID: $taskID');

  // Keep running...
  await Future.delayed(Duration(hours: 1));

  // Stop when done
  service.stopTask(taskID);
  await service.stopSocks5Server(serverID);
  service.dispose();
}
