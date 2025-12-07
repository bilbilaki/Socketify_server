import 'dart:async';
import 'dart:io';
import 'dart:ffi' as ffi;
import 'dart:isolate';
import 'dart:convert';
import 'package:ffi/ffi.dart';
import '../bindings/generated_bindings_for_portforward.dart';

/// Service for loading and interacting with the PortForward native library
class PortForwardService {
  late final PortForwardLibrary _bindings;
  late final ffi.DynamicLibrary _dylib;
  ReceivePort? _receivePort;
  int _nativePort = 0;
  final Map<String, Function(Map<String, dynamic>)> _responseHandlers = {};

  /// Singleton instance
  static PortForwardService? _instance;

  factory PortForwardService() {
    _instance ??= PortForwardService._internal();
    return _instance!;
  }

  PortForwardService._internal();

  /// Initialize the library and setup communication bridge
  Future<void> initialize() async {
    _dylib = _loadLibrary();
    _bindings = PortForwardLibrary(_dylib);

    // Setup receive port for callbacks from Go
    _receivePort = ReceivePort();
    _nativePort = _receivePort!.sendPort.nativePort;

    // Initialize the Dart API in Go
    final dartApiDL = ffi.NativeApi.initializeApiDLData;
    _bindings.BridgeInit(dartApiDL);

    // Register the port
    _bindings.RegisterPort(_nativePort);

    // Listen for messages from Go
    _receivePort!.listen(_handleNativeMessage);

    print('PortForwardService initialized successfully');
  }

  /// Load the appropriate dynamic library based on platform
  ffi.DynamicLibrary _loadLibrary() {
    if (Platform.isWindows) {
      // Try multiple paths for Windows
      try {
        return ffi.DynamicLibrary.open('native/windows/portforward.dll');
      } catch (e) {
        return ffi.DynamicLibrary.open('portforward.dll');
      }
    } else if (Platform.isLinux) {
      try {
        return ffi.DynamicLibrary.open('native/linux/portforward.so');
      } catch (e) {
        return ffi.DynamicLibrary.open('./portforward.so');
      }
    } else if (Platform.isMacOS) {
      try {
        return ffi.DynamicLibrary.open('native/macos/portforward.dylib');
      } catch (e) {
        return ffi.DynamicLibrary.open('./portforward.dylib');
      }
    }
    throw UnsupportedError('Unsupported platform: ${Platform.operatingSystem}');
  }

  /// Handle messages from native library
  void _handleNativeMessage(dynamic message) {
    if (message is String) {
      try {
        final data = jsonDecode(message);
        final op = data['op'] as String?;

        if (op != null && _responseHandlers.containsKey(op)) {
          _responseHandlers[op]!(data);
          _responseHandlers.remove(op);
        } else {
          print('Received: $message');
        }
      } catch (e) {
        // Not JSON, just a simple message
        print('PortForward Native: $message');
      }
    }
  }

  /// Dispose resources
  void dispose() {
    _bindings.UnregisterPort();
    _receivePort?.close();
    _receivePort = null;
  }

  // ==================== PORT FORWARD OPERATIONS ====================

  /// Create a port forwarder instance
  ///
  /// [url] - Kubernetes API server URL (e.g., "https://kubernetes.default.svc")
  /// [ports] - Comma-separated port mappings (e.g., "8080:80,9090:90")
  /// [address] - Local bind address (e.g., "localhost" or "0.0.0.0")
  ///
  /// Returns the port forwarder ID
  Future<int> createPortForwarder({
    required String url,
    required String ports,
    String address = 'localhost',
  }) {
    final completer = Completer<int>();
    _responseHandlers['create_port_forwarder'] = (data) {
      if (data['success'] == true) {
        completer.complete(data['data']['pfID'] as int? ?? -1);
      } else {
        completer.completeError(data['error'] ?? 'Unknown error');
      }
    };

    final urlPtr = url.toNativeUtf8().cast<ffi.Char>();
    final portsPtr = ports.toNativeUtf8().cast<ffi.Char>();
    final addressPtr = address.toNativeUtf8().cast<ffi.Char>();

    final pfID = _bindings.CreatePortForwarder(
      urlPtr,
      portsPtr,
      addressPtr,
      _nativePort,
    );

    malloc.free(urlPtr);
    malloc.free(portsPtr);
    malloc.free(addressPtr);

    // If response is synchronous (pfID > 0), complete immediately
    if (pfID > 0) {
      completer.complete(pfID);
    }

    return completer.future;
  }

  /// Start forwarding ports for a given port forwarder
  ///
  /// [pfID] - Port forwarder ID returned from createPortForwarder
  ///
  /// Returns the task ID for the forwarding operation
  Future<int> startForwardPorts(int pfID) {
    final completer = Completer<int>();
    _responseHandlers['start_forward_ports'] = (data) {
      if (data['success'] == true) {
        completer.complete(data['data']['taskID'] as int? ?? -1);
      } else {
        completer.completeError(data['error'] ?? 'Unknown error');
      }
    };

    final taskID = _bindings.StartForwardPorts(pfID, _nativePort);

    // If response is synchronous (taskID > 0), complete immediately
    if (taskID > 0) {
      completer.complete(taskID);
    }

    return completer.future;
  }

  /// Stop forwarding ports for a given port forwarder
  ///
  /// [pfID] - Port forwarder ID
  Future<void> stopForwardPorts(int pfID) {
    final completer = Completer<void>();
    _responseHandlers['stop_forward_ports'] = (data) {
      if (data['success'] == true) {
        completer.complete();
      } else {
        completer.completeError(data['error'] ?? 'Unknown error');
      }
    };

    _bindings.StopForwardPorts(pfID, _nativePort);

    return completer.future;
  }

  /// Get information about forwarded ports
  ///
  /// [pfID] - Port forwarder ID
  ///
  /// Returns a map containing forwarded port information
  Future<Map<String, dynamic>> getForwardedPorts(int pfID) {
    final completer = Completer<Map<String, dynamic>>();
    _responseHandlers['get_forwarded_ports'] = (data) {
      if (data['success'] == true) {
        completer.complete(Map<String, dynamic>.from(data['data']));
      } else {
        completer.completeError(data['error'] ?? 'Unknown error');
      }
    };

    _bindings.GetForwardedPorts(pfID, _nativePort);

    return completer.future;
  }

  /// Stop a running task by its task ID
  ///
  /// [taskID] - Task ID returned from startForwardPorts
  void stopTask(int taskID) {
    _bindings.StopTask(taskID, _nativePort);
  }
}
