import 'package:server/service/cloak_service.dart';

/// Example usage of CloakService
/// Cloak is a censorship circumvention tool that evades deep packet inspection
Future<void> main() async {
  final service = CloakService();

  try {
    // Initialize the service
    await service.initialize();
    print('Cloak service initialized\n');

    // ==================== KEY AND UID GENERATION ====================

    // Example 1: Get library version
    print('--- Example 1: Get library version ---');
    final version = await service.getVersion();
    print('Cloak version: $version\n');

    // Example 2: Generate key pair for server
    print('--- Example 2: Generate ECDH key pair ---');
    final keyPair = await service.generateKeyPair();
    print('Public Key: ${keyPair['publicKey']}');
    print('Private Key: ${keyPair['privateKey']}\n');

    // Example 3: Generate UID for admin user
    print('--- Example 3: Generate admin UID ---');
    final adminUID = await service.generateUID();
    print('Admin UID: $adminUID\n');

    // Example 4: Generate UID for regular user
    print('--- Example 4: Generate user UID ---');
    final userUID = await service.generateUID();
    print('User UID: $userUID\n');

    // ==================== SERVER CONFIGURATION ====================

    // Example 5: Create basic server configuration
    print('--- Example 5: Create server configuration ---');
    final config = service.createConfig(
      bindAddr: [':443', ':8443'],
      proxyBook: {'shadowsocks': '127.0.0.1:8388', 'vmess': '127.0.0.1:10086'},
      privateKey: keyPair['privateKey'],
      adminUID: adminUID,
      databasePath: 'userinfo.db',
      streamTimeout: 300,
      keepAlive: 0,
    );
    print('Configuration created:');
    print('  Bind addresses: ${config['BindAddr']}');
    print('  Proxy book: ${config['ProxyBook']}');
    print('  Database: ${config['DatabasePath']}\n');

    // Example 6: Start Cloak server
    print('--- Example 6: Start Cloak server ---');
    final taskID = await service.startCloakServer(config);
    print('Cloak server started with task ID: $taskID');
    print('Server is listening on ports 443 and 8443');
    print(
      'Proxying to shadowsocks (127.0.0.1:8388) and vmess (127.0.0.1:10086)\n',
    );

    // Keep the server running
    print('Server is running. Press Ctrl+C to stop...\n');
    await Future.delayed(Duration(minutes: 5));

    // Stop the server
    print('--- Stopping Cloak server ---');
    await service.stopTask(taskID);
    print('Server stopped\n');
  } catch (e) {
    print('Error: $e');
  } finally {
    // Cleanup
    service.dispose();
    print('Service disposed');
  }
}

/// Simple example - Start a Cloak server with auto-generated keys
Future<void> simpleServerExample() async {
  final service = CloakService();
  await service.initialize();

  // Create complete configuration with auto-generated keys
  final config = await service.createCompleteConfig(
    bindAddr: [':443'],
    proxyBook: {'shadowsocks': '127.0.0.1:8388'},
  );

  // Start the server
  final taskID = await service.startCloakServer(config);
  print('Cloak server running on port 443');
  print('Task ID: $taskID');

  // Keep running...
  await Future.delayed(Duration(hours: 1));

  // Stop when done
  await service.stopTask(taskID);
  service.dispose();
}

/// Advanced example - Multiple proxy backends
Future<void> multiProxyExample() async {
  final service = CloakService();
  await service.initialize();

  // Generate credentials
  final keyPair = await service.generateKeyPair();
  final adminUID = await service.generateUID();

  print('=== Cloak Server Setup ===');
  print('Public Key: ${keyPair['publicKey']}');
  print('Admin UID: $adminUID');
  print('\nShare these with your clients for connection.\n');

  // Create configuration with multiple proxy backends
  final config = service.createConfig(
    bindAddr: [':443', ':8443'],
    proxyBook: {
      'shadowsocks': '127.0.0.1:8388',
      'vmess': '127.0.0.1:10086',
      'trojan': '127.0.0.1:8080',
      'direct': '127.0.0.1:1080',
    },
    privateKey: keyPair['privateKey'],
    adminUID: adminUID,
    databasePath: 'userinfo.db',
    streamTimeout: 300,
    keepAlive: 30,
  );

  // Start the server
  final taskID = await service.startCloakServer(config);
  print('Cloak server started with multiple backends:');
  print('  - shadowsocks: 127.0.0.1:8388');
  print('  - vmess: 127.0.0.1:10086');
  print('  - trojan: 127.0.0.1:8080');
  print('  - direct: 127.0.0.1:1080');
  print('\nListening on ports: 443, 8443');
  print('Task ID: $taskID\n');

  // Keep running...
  await Future.delayed(Duration(hours: 24));

  // Stop when done
  await service.stopTask(taskID);
  service.dispose();
}

/// Example - Generate credentials for client configuration
Future<void> generateClientCredentials() async {
  final service = CloakService();
  await service.initialize();

  print('=== Generating Cloak Client Credentials ===\n');

  // Generate server key pair
  print('1. Generating server key pair...');
  final serverKeyPair = await service.generateKeyPair();
  print('   Server Public Key: ${serverKeyPair['publicKey']}');
  print('   Server Private Key: ${serverKeyPair['privateKey']}\n');

  // Generate admin UID
  print('2. Generating admin UID...');
  final adminUID = await service.generateUID();
  print('   Admin UID: $adminUID\n');

  // Generate user UIDs
  print('3. Generating user UIDs...');
  for (int i = 1; i <= 3; i++) {
    final uid = await service.generateUID();
    print('   User $i UID: $uid');
  }

  print('\n=== Server Configuration ===');
  print('Use the Server Private Key and Admin UID for server setup.');
  print('\n=== Client Configuration ===');
  print('Clients need:');
  print('  - Server Public Key: ${serverKeyPair['publicKey']}');
  print('  - Their respective UID (User 1, 2, or 3)');
  print('  - Server address and port\n');

  service.dispose();
}

/// Example - Custom configuration with security settings
Future<void> secureServerExample() async {
  final service = CloakService();
  await service.initialize();

  final keyPair = await service.generateKeyPair();
  final adminUID = await service.generateUID();

  // Create a more secure configuration
  final config = service.createConfig(
    bindAddr: [':8443'], // Use non-standard port
    proxyBook: {'secure-proxy': '127.0.0.1:8388'},
    privateKey: keyPair['privateKey'],
    adminUID: adminUID,
    databasePath: 'secure_users.db',
    streamTimeout: 180, // Shorter timeout for security
    keepAlive: 15, // Regular keep-alive checks
  );

  final taskID = await service.startCloakServer(config);
  print('Secure Cloak server running on port 8443');
  print('Stream timeout: 180s');
  print('Keep-alive: 15s');
  print('Task ID: $taskID');

  // Monitor the server
  print('\nServer monitoring active...');

  await Future.delayed(Duration(hours: 1));

  await service.stopTask(taskID);
  service.dispose();
}
