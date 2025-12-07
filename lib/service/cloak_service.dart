import 'dart:async';
import 'dart:io';
import 'dart:ffi' as ffi;
import 'dart:isolate';
import 'dart:convert';
import 'package:ffi/ffi.dart';
import '../bindings/generated_bindings_for_cloak.dart';

/// Service for loading and interacting with the Cloak Server native library
/// Cloak is a censorship circumvention tool that evades deep packet inspection
class CloakService {
  late final CloakLibrary _bindings;
  late final ffi.DynamicLibrary _dylib;
  ReceivePort? _receivePort;
  int _nativePort = 0;
  final Map<String, Function(Map<String, dynamic>)> _responseHandlers = {};

  /// Singleton instance
  static CloakService? _instance;

  factory CloakService() {
    _instance ??= CloakService._internal();
    return _instance!;
  }

  CloakService._internal();

  /// Initialize the library and setup communication bridge
  Future<void> initialize() async {
    _dylib = _loadLibrary();
    _bindings = CloakLibrary(_dylib);

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

    print('CloakService initialized successfully');
  }

  /// Load the appropriate dynamic library based on platform
  ffi.DynamicLibrary _loadLibrary() {
    if (Platform.isWindows) {
      // Try multiple paths for Windows
      try {
        return ffi.DynamicLibrary.open('native/windows/cloaklib.dll');
      } catch (e) {
        try {
          return ffi.DynamicLibrary.open('cloaklib.dll');
        } catch (e2) {
          return ffi.DynamicLibrary.open(
            '../cloak/cmd/ck-server-wrapper/cloaklib.dll',
          );
        }
      }
    } else if (Platform.isLinux) {
      try {
        return ffi.DynamicLibrary.open('native/linux/cloaklib.so');
      } catch (e) {
        try {
          return ffi.DynamicLibrary.open('./cloaklib.so');
        } catch (e2) {
          return ffi.DynamicLibrary.open(
            '../cloak/cmd/ck-server-wrapper/cloaklib.so',
          );
        }
      }
    } else if (Platform.isMacOS) {
      try {
        return ffi.DynamicLibrary.open('native/macos/cloaklib.dylib');
      } catch (e) {
        try {
          return ffi.DynamicLibrary.open('./cloaklib.dylib');
        } catch (e2) {
          return ffi.DynamicLibrary.open(
            '../cloak/cmd/ck-server-wrapper/cloaklib.dylib',
          );
        }
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
        print('Cloak Native: $message');
      }
    }
  }

  /// Dispose resources
  void dispose() {
    _bindings.UnregisterPort();
    _receivePort?.close();
    _receivePort = null;
  }

  // ==================== CLOAK SERVER OPERATIONS ====================

  /// Start a Cloak server with the given configuration
  ///
  /// [config] - Server configuration as a Map that will be converted to JSON
  ///
  /// Configuration should include:
  /// - BindAddr: List of addresses to bind to (e.g., [":443"])
  /// - ProxyBook: Map of proxy names to redirection addresses
  /// - PrivateKey: Base64-encoded private key (use generateKeyPair to create)
  /// - AdminUID: Base64-encoded admin UID (use generateUID to create)
  /// - DatabasePath: Path to user database file
  /// - StreamTimeout: Timeout for streams in seconds
  /// - KeepAlive: Keep-alive interval in seconds
  ///
  /// Returns the task ID for the server operation
  Future<int> startCloakServer(Map<String, dynamic> config) {
    final completer = Completer<int>();
    _responseHandlers['start_cloak_server'] = (data) {
      if (data['success'] == true) {
        completer.complete(data['data'] as int? ?? -1);
      } else {
        completer.completeError(data['error'] ?? 'Unknown error');
      }
    };

    final configJSON = jsonEncode(config);
    final configPtr = configJSON.toNativeUtf8().cast<ffi.Char>();

    final taskID = _bindings.StartCloakServer(configPtr, _nativePort);

    malloc.free(configPtr);

    // If response is synchronous (taskID > 0), complete immediately
    if (taskID > 0) {
      completer.complete(taskID);
    }

    return completer.future;
  }

  /// Generate a new ECDH key pair for Cloak server
  ///
  /// Returns a map containing:
  /// - publicKey: Base64-encoded public key
  /// - privateKey: Base64-encoded private key
  Future<Map<String, String>> generateKeyPair() {
    final completer = Completer<Map<String, String>>();
    _responseHandlers['generate_keypair'] = (data) {
      if (data['success'] == true) {
        final result = data['data'] as Map<String, dynamic>;
        completer.complete({
          'publicKey': result['publicKey'] as String,
          'privateKey': result['privateKey'] as String,
        });
      } else {
        completer.completeError(data['error'] ?? 'Unknown error');
      }
    };

    _bindings.GenerateKeyPair(_nativePort);

    return completer.future;
  }

  /// Generate a new UID (User ID) for Cloak
  ///
  /// Returns a Base64-encoded UID string
  Future<String> generateUID() {
    final completer = Completer<String>();
    _responseHandlers['generate_uid'] = (data) {
      if (data['success'] == true) {
        completer.complete(data['data'] as String? ?? '');
      } else {
        completer.completeError(data['error'] ?? 'Unknown error');
      }
    };

    _bindings.GenerateUID(_nativePort);

    return completer.future;
  }

  /// Get the version of the Cloak library
  ///
  /// Returns a version string
  Future<String> getVersion() {
    final completer = Completer<String>();
    _responseHandlers['get_version'] = (data) {
      if (data['success'] == true) {
        completer.complete(data['data'] as String? ?? '');
      } else {
        completer.completeError(data['error'] ?? 'Unknown error');
      }
    };

    _bindings.GetVersion(_nativePort);

    return completer.future;
  }

  /// Stop a running task by its task ID
  ///
  /// [taskID] - Task ID returned from startCloakServer
  Future<void> stopTask(int taskID) {
    final completer = Completer<void>();
    _responseHandlers['stop_task'] = (data) {
      if (data['success'] == true) {
        completer.complete();
      } else {
        completer.completeError(data['error'] ?? 'Unknown error');
      }
    };

    _bindings.StopTask(taskID, _nativePort);

    return completer.future;
  }

  // ==================== HELPER METHODS ====================

  /// Create a basic Cloak server configuration
  ///
  /// [bindAddr] - List of addresses to bind to (default: [":443"])
  /// [proxyBook] - Map of proxy names to redirection addresses
  /// [privateKey] - Base64-encoded private key (if null, will need to be set)
  /// [adminUID] - Base64-encoded admin UID (if null, will need to be set)
  /// [databasePath] - Path to user database file (default: "userinfo.db")
  /// [streamTimeout] - Timeout for streams in seconds (default: 300)
  /// [keepAlive] - Keep-alive interval in seconds (default: 0)
  ///
  /// Returns a configuration map ready to be used with startCloakServer
  Map<String, dynamic> createConfig({
    List<String>? bindAddr,
    required Map<String, String> proxyBook,
    String? privateKey,
    String? adminUID,
    String databasePath = 'userinfo.db',
    int streamTimeout = 300,
    int keepAlive = 0,
  }) {
    return {
      'BindAddr': bindAddr ?? [':443'],
      'ProxyBook': proxyBook,
      if (privateKey != null) 'PrivateKey': privateKey,
      if (adminUID != null) 'AdminUID': adminUID,
      'DatabasePath': databasePath,
      'StreamTimeout': streamTimeout,
      'KeepAlive': keepAlive,
    };
  }

  /// Create a complete configuration with generated keys
  ///
  /// This is a convenience method that generates keys and UID automatically
  Future<Map<String, dynamic>> createCompleteConfig({
    List<String>? bindAddr,
    required Map<String, String> proxyBook,
    String databasePath = 'userinfo.db',
    int streamTimeout = 300,
    int keepAlive = 0,
  }) async {
    final keyPair = await generateKeyPair();
    final uid = await generateUID();

    return createConfig(
      bindAddr: bindAddr,
      proxyBook: proxyBook,
      privateKey: keyPair['privateKey'],
      adminUID: uid,
      databasePath: databasePath,
      streamTimeout: streamTimeout,
      keepAlive: keepAlive,
    );
  }
}
