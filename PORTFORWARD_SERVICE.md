# PortForward Service

A Dart service for interacting with the PortForward Go native library, providing Kubernetes port forwarding capabilities.

## Overview

The `PortForwardService` allows you to create and manage port forwarding sessions to Kubernetes services, similar to `kubectl port-forward` but from within your Dart application.

## Features

- Create port forwarder instances
- Start/stop port forwarding
- Get forwarded ports information
- Task management for forwarding operations
- Cross-platform support (Windows, Linux, macOS)

## Installation

The service requires the native libraries to be present:
- **Windows**: `native/windows/portforward.dll`
- **Linux**: `native/linux/portforward.so`
- **macOS**: `native/macos/portforward.dylib`

## Usage

### Basic Example

```dart
import 'package:server/portforward_service.dart';

Future<void> main() async {
  final service = PortForwardService();
  
  // Initialize the service
  await service.initialize();
  
  // Create a port forwarder
  final pfID = await service.createPortForwarder(
    url: 'https://kubernetes.default.svc',
    ports: '8080:80,9090:90',  // Local:Remote port mappings
    address: 'localhost',
  );
  
  // Start forwarding
  final taskID = await service.startForwardPorts(pfID);
  
  // Get forwarded ports information
  final portsInfo = await service.getForwardedPorts(pfID);
  print('Forwarded ports: $portsInfo');
  
  // Stop forwarding
  service.stopTask(taskID);
  await service.stopForwardPorts(pfID);
  
  // Cleanup
  service.dispose();
}
```

## API Reference

### `initialize()`
Initialize the service and set up communication bridge with the native library.

```dart
await service.initialize();
```

### `createPortForwarder({required String url, required String ports, String address = 'localhost'})`
Create a port forwarder instance.

**Parameters:**
- `url`: Kubernetes API server URL (e.g., "https://kubernetes.default.svc")
- `ports`: Comma-separated port mappings (e.g., "8080:80,9090:90")
- `address`: Local bind address (default: "localhost")

**Returns:** Port forwarder ID

```dart
final pfID = await service.createPortForwarder(
  url: 'https://kubernetes.default.svc',
  ports: '8080:80',
  address: 'localhost',
);
```

### `startForwardPorts(int pfID)`
Start forwarding ports for a given port forwarder.

**Parameters:**
- `pfID`: Port forwarder ID returned from `createPortForwarder`

**Returns:** Task ID for the forwarding operation

```dart
final taskID = await service.startForwardPorts(pfID);
```

### `stopForwardPorts(int pfID)`
Stop forwarding ports for a given port forwarder.

**Parameters:**
- `pfID`: Port forwarder ID

```dart
await service.stopForwardPorts(pfID);
```

### `getForwardedPorts(int pfID)`
Get information about forwarded ports.

**Parameters:**
- `pfID`: Port forwarder ID

**Returns:** Map containing forwarded port information

```dart
final portsInfo = await service.getForwardedPorts(pfID);
```

### `stopTask(int taskID)`
Stop a running task by its task ID.

**Parameters:**
- `taskID`: Task ID returned from `startForwardPorts`

```dart
service.stopTask(taskID);
```

### `dispose()`
Dispose resources and clean up the service.

```dart
service.dispose();
```

## Architecture

The service follows the same pattern as `SentinelService`:

1. **Singleton Pattern**: Only one instance per application
2. **FFI Bindings**: Generated using `ffigen` from C headers
3. **Async Communication**: Uses Dart Isolate ports for callbacks from Go
4. **Response Handlers**: Maps operations to Dart Futures for async/await support

## Regenerating Bindings

If the Go native library changes, regenerate the FFI bindings:

```bash
dart run ffigen --config ffigen_portforward.yaml
```

## Notes

- The service uses the singleton pattern - calling `PortForwardService()` multiple times returns the same instance
- Always call `initialize()` before using any other methods
- Call `dispose()` when done to clean up resources
- The native library must be built and placed in the appropriate directory before use

## See Also

- `SentinelService` - Similar service for system automation
- [Example](example/portforward_example.dart) - Complete working example
