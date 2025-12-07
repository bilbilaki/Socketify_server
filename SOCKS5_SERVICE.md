# Socks5 Service

A Dart service for interacting with the Socks5 Go native library, providing SOCKS5 proxy server capabilities with various configurations.

## Overview

The `Socks5Service` allows you to create and manage SOCKS5 proxy servers with different configurations including authentication, TCP/UDP support, and proxy chaining.

## Features

- **Multiple Server Types**:
  - Simple servers (with/without authentication)
  - Direct TCP SOCKS5 servers
  - Direct UDP SOCKS5 servers
  - UDP proxy servers with upstream SOCKS5 chaining
  
- **Authentication Support**:
  - No authentication
  - Username/password authentication
  - Custom authentication handlers

- **Task Management**: Start/stop servers with task IDs
- **Cross-platform**: Windows, Linux, macOS support

## Installation

The service requires the native libraries to be present:
- **Windows**: `native/windows/socks5lib.dll` or `socks5lib.dll`
- **Linux**: `native/linux/socks5lib.so` or `socks5lib.so`
- **macOS**: `native/macos/socks5lib.dylib` or `socks5lib.dylib`

## Usage

### Quick Start

```dart
import 'package:server/service/socks5_service.dart';

Future<void> main() async {
  final service = Socks5Service();
  
  // Initialize the service
  await service.initialize();
  
  // Create a simple SOCKS5 server without authentication
  final serverID = await service.createWithoutAuthServer(
    listenPort: 1080,
  );
  
  // Start the server
  final taskID = await service.startSocks5Server(serverID);
  print('SOCKS5 server running on localhost:1080');
  
  // Keep running...
  await Future.delayed(Duration(hours: 1));
  
  // Stop the server
  service.stopTask(taskID);
  await service.stopSocks5Server(serverID);
  service.dispose();
}
```

## API Reference

### Initialization

#### `initialize()`
Initialize the service and set up communication bridge with the native library.

```dart
await service.initialize();
```

### Server Creation Methods

#### `createWithoutAuthServer({required int listenPort})`
Create a SOCKS5 server without authentication.

**Parameters:**
- `listenPort`: Port to listen on

**Returns:** Server ID

```dart
final serverID = await service.createWithoutAuthServer(listenPort: 1080);
```

#### `createWithAuthServer({required int listenPort})`
Create a SOCKS5 server with authentication (uses default auth handler).

**Parameters:**
- `listenPort`: Port to listen on

**Returns:** Server ID

```dart
final serverID = await service.createWithAuthServer(listenPort: 1080);
```

#### `createDirectServerTCP({required int listenPort, String? username, String? password})`
Create a direct TCP SOCKS5 server with optional custom authentication.

**Parameters:**
- `listenPort`: Port to listen on
- `username`: Authentication username (optional)
- `password`: Authentication password (optional)

**Returns:** Server ID

```dart
final serverID = await service.createDirectServerTCP(
  listenPort: 1080,
  username: 'myuser',
  password: 'mypassword',
);
```

#### `createDirectServerUDP({required int listenPort, String? username, String? password})`
Create a direct UDP SOCKS5 server with optional custom authentication.

**Parameters:**
- `listenPort`: Port to listen on
- `username`: Authentication username (optional)
- `password`: Authentication password (optional)

**Returns:** Server ID

```dart
final serverID = await service.createDirectServerUDP(
  listenPort: 1080,
  username: 'myuser',
  password: 'mypassword',
);
```

#### `createProxyToSocks5ServerUDP({...})`
Create a UDP SOCKS5 server that proxies to another upstream SOCKS5 server.

**Parameters:**
- `listenPort`: Port to listen on
- `username`: Authentication username for clients (optional)
- `password`: Authentication password for clients (optional)
- `proxyAddr`: Address of the upstream SOCKS5 proxy (required)
- `proxyUser`: Username for upstream proxy (optional)
- `proxyPass`: Password for upstream proxy (optional)

**Returns:** Server ID

```dart
final serverID = await service.createProxyToSocks5ServerUDP(
  listenPort: 1080,
  username: 'localuser',
  password: 'localpass',
  proxyAddr: '192.168.1.100:1080',
  proxyUser: 'upstreamuser',
  proxyPass: 'upstreampass',
);
```

### Server Management

#### `startSocks5Server(int srvID)`
Start a SOCKS5 server.

**Parameters:**
- `srvID`: Server ID returned from a create method

**Returns:** Task ID for the server operation

```dart
final taskID = await service.startSocks5Server(serverID);
```

#### `stopSocks5Server(int srvID)`
Stop a SOCKS5 server.

**Parameters:**
- `srvID`: Server ID

```dart
await service.stopSocks5Server(serverID);
```

#### `stopTask(int taskID)`
Stop a running task by its task ID.

**Parameters:**
- `taskID`: Task ID returned from `startSocks5Server`

```dart
service.stopTask(taskID);
```

#### `dispose()`
Dispose resources and clean up the service.

```dart
service.dispose();
```

## Examples

### Example 1: Simple SOCKS5 Server

```dart
final service = Socks5Service();
await service.initialize();

final serverID = await service.createWithoutAuthServer(listenPort: 1080);
final taskID = await service.startSocks5Server(serverID);

print('SOCKS5 server running on localhost:1080');
```

### Example 2: Authenticated SOCKS5 Server

```dart
final service = Socks5Service();
await service.initialize();

final serverID = await service.createDirectServerTCP(
  listenPort: 1080,
  username: 'admin',
  password: 'secret123',
);
final taskID = await service.startSocks5Server(serverID);

print('Authenticated SOCKS5 server running on localhost:1080');
print('Use credentials: admin / secret123');
```

### Example 3: Multiple Servers

```dart
final service = Socks5Service();
await service.initialize();

// TCP server on port 1080
final tcpID = await service.createDirectServerTCP(
  listenPort: 1080,
  username: 'user1',
  password: 'pass1',
);
final tcpTask = await service.startSocks5Server(tcpID);

// UDP server on port 1081
final udpID = await service.createDirectServerUDP(
  listenPort: 1081,
  username: 'user2',
  password: 'pass2',
);
final udpTask = await service.startSocks5Server(udpID);

print('TCP server: localhost:1080');
print('UDP server: localhost:1081');
```

### Example 4: Proxy Chain

```dart
final service = Socks5Service();
await service.initialize();

// Create a local SOCKS5 server that forwards to an upstream proxy
final serverID = await service.createProxyToSocks5ServerUDP(
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
```

## Architecture

The service follows the same pattern as other native services in the project:

1. **Singleton Pattern**: Only one instance per application
2. **FFI Bindings**: Generated using `ffigen` from C headers
3. **Async Communication**: Uses Dart Isolate ports for callbacks from Go
4. **Response Handlers**: Maps operations to Dart Futures for async/await support

## Building the Native Library

To rebuild the native SOCKS5 library:

```bash
cd server/socks5lib
go build -buildmode=c-shared -o socks5lib.dll .     # Windows
go build -buildmode=c-shared -o socks5lib.so .      # Linux
go build -buildmode=c-shared -o socks5lib.dylib .   # macOS
```

## Regenerating Bindings

If the Go native library changes, regenerate the FFI bindings:

```bash
cd server
dart run ffigen --config ffigen_socks5.yaml
```

## Configuration Files

- **ffigen_socks5.yaml**: FFI generation configuration
- **lib/bindings/generated_bindings_for_socks5.dart**: Generated FFI bindings
- **lib/service/socks5_service.dart**: Service implementation
- **example/socks5_example.dart**: Complete working examples

## Testing Your SOCKS5 Server

Once your server is running, you can test it with various tools:

### Using curl

```bash
# Without authentication
curl --socks5 localhost:1080 http://example.com

# With authentication
curl --socks5 localhost:1080 --proxy-user user:pass http://example.com
```

### Using Firefox

1. Open Settings → Network Settings
2. Select "Manual proxy configuration"
3. SOCKS Host: `localhost`, Port: `1080`
4. Select "SOCKS v5"
5. If authentication is required, Firefox will prompt for credentials

### Using SSH

```bash
ssh -o ProxyCommand="nc -x localhost:1080 %h %p" user@remote-host
```

## Notes

- The service uses the singleton pattern - calling `Socks5Service()` returns the same instance
- Always call `initialize()` before using any other methods
- Call `dispose()` when done to clean up resources
- The native library must be built and accessible before use
- Server IDs and Task IDs are positive integers; -1 typically indicates an error

## Troubleshooting

### Library not found

If you get "Library not found" errors:
1. Ensure the native library is built: `go build -buildmode=c-shared -o socks5lib.dll .`
2. Place the library in one of these locations:
   - `native/windows/socks5lib.dll` (Windows)
   - `native/linux/socks5lib.so` (Linux)
   - `native/macos/socks5lib.dylib` (macOS)
   - Or in the same directory as your executable

### Port already in use

If a port is already in use, choose a different port number (1080 is the standard SOCKS5 port but any available port can be used).

### Authentication not working

Ensure you're passing the correct username and password to the create methods and that your client is configured to use authentication.

## See Also

- `SentinelService` - System automation service
- `PortForwardService` - Kubernetes port forwarding service
- [Complete Examples](example/socks5_example.dart)
