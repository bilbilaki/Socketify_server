import 'dart:async';
import 'dart:io';
import 'dart:ffi' as ffi;
import 'dart:isolate';
import 'dart:convert';
import 'package:ffi/ffi.dart';
import '../bindings/generated_bindings_for_socks5v2.dart';

/// Service for loading and interacting with the Socks5V2 native library
/// This version includes both server and client connection capabilities
class Socks5V2Service {
  late final Socks5V2Library _bindings;
  late final ffi.DynamicLibrary _dylib;
  ReceivePort? _receivePort;
  int _nativePort = 0;
  final Map<String, Function(Map<String, dynamic>)> _responseHandlers = {};

  /// Singleton instance
  static Socks5V2Service? _instance;

  factory Socks5V2Service() {
    _instance ??= Socks5V2Service._internal();
    return _instance!;
  }

  Socks5V2Service._internal();

  /// Initialize the library and setup communication bridge
  Future<void> initialize() async {
    _dylib = _loadLibrary();
    _bindings = Socks5V2Library(_dylib);

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

    print('Socks5V2Service initialized successfully');
  }

  /// Load the appropriate dynamic library based on platform
  ffi.DynamicLibrary _loadLibrary() {
    if (Platform.isWindows) {
      // Try multiple paths for Windows
      try {
        return ffi.DynamicLibrary.open('native/windows/socks5lib2.dll');
      } catch (e) {
        try {
          return ffi.DynamicLibrary.open('socks5lib2.dll');
        } catch (e2) {
          return ffi.DynamicLibrary.open('../socks5lib2/socks5lib2.dll');
        }
      }
    } else if (Platform.isLinux) {
      try {
        return ffi.DynamicLibrary.open('native/linux/socks5lib2.so');
      } catch (e) {
        try {
          return ffi.DynamicLibrary.open('./socks5lib2.so');
        } catch (e2) {
          return ffi.DynamicLibrary.open('../socks5lib2/socks5lib2.so');
        }
      }
    } else if (Platform.isMacOS) {
      try {
        return ffi.DynamicLibrary.open('native/macos/socks5lib2.dylib');
      } catch (e) {
        try {
          return ffi.DynamicLibrary.open('./socks5lib2.dylib');
        } catch (e2) {
          return ffi.DynamicLibrary.open('../socks5lib2/socks5lib2.dylib');
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
        print('Socks5V2 Native: $message');
      }
    }
  }

  /// Dispose resources
  void dispose() {
    _bindings.UnregisterPort();
    _receivePort?.close();
    _receivePort = null;
  }

  // ==================== SOCKS5 SERVER OPERATIONS ====================

  /// Create a direct TCP SOCKS5 server
  ///
  /// [listenPort] - Port to listen on
  /// [username] - Authentication username (optional)
  /// [password] - Authentication password (optional)
  ///
  /// Returns the server ID
  Future<int> createDirectServerTCP({
    required int listenPort,
    String? username,
    String? password,
  }) {
    final completer = Completer<int>();
    _responseHandlers['create_direct_server_tcp'] = (data) {
      if (data['success'] == true) {
        completer.complete(data['data']['srvID'] as int? ?? -1);
      } else {
        completer.completeError(data['error'] ?? 'Unknown error');
      }
    };

    final usernamePtr = username != null
        ? username.toNativeUtf8().cast<ffi.Char>()
        : ffi.nullptr;
    final passwordPtr = password != null
        ? password.toNativeUtf8().cast<ffi.Char>()
        : ffi.nullptr;

    final srvID = _bindings.CreateDirectServerTCP(
      listenPort,
      usernamePtr,
      passwordPtr,
      _nativePort,
    );

    if (usernamePtr != ffi.nullptr) malloc.free(usernamePtr);
    if (passwordPtr != ffi.nullptr) malloc.free(passwordPtr);

    // If response is synchronous (srvID > 0), complete immediately
    if (srvID > 0) {
      completer.complete(srvID);
    }

    return completer.future;
  }

  /// Create a direct UDP SOCKS5 server
  ///
  /// [listenPort] - Port to listen on
  /// [username] - Authentication username (optional)
  /// [password] - Authentication password (optional)
  ///
  /// Returns the server ID
  Future<int> createDirectServerUDP({
    required int listenPort,
    String? username,
    String? password,
  }) {
    final completer = Completer<int>();
    _responseHandlers['create_direct_server_udp'] = (data) {
      if (data['success'] == true) {
        completer.complete(data['data']['srvID'] as int? ?? -1);
      } else {
        completer.completeError(data['error'] ?? 'Unknown error');
      }
    };

    final usernamePtr = username != null
        ? username.toNativeUtf8().cast<ffi.Char>()
        : ffi.nullptr;
    final passwordPtr = password != null
        ? password.toNativeUtf8().cast<ffi.Char>()
        : ffi.nullptr;

    final srvID = _bindings.CreateDirectServerUDP(
      listenPort,
      usernamePtr,
      passwordPtr,
      _nativePort,
    );

    if (usernamePtr != ffi.nullptr) malloc.free(usernamePtr);
    if (passwordPtr != ffi.nullptr) malloc.free(passwordPtr);

    // If response is synchronous (srvID > 0), complete immediately
    if (srvID > 0) {
      completer.complete(srvID);
    }

    return completer.future;
  }

  /// Create a TCP SOCKS5 server that proxies to another SOCKS5 server
  ///
  /// [listenPort] - Port to listen on
  /// [username] - Authentication username for clients (optional)
  /// [password] - Authentication password for clients (optional)
  /// [proxyAddr] - Address of the upstream SOCKS5 proxy
  /// [proxyUser] - Username for upstream proxy (optional)
  /// [proxyPass] - Password for upstream proxy (optional)
  ///
  /// Returns the server ID
  Future<int> createProxyToSocks5ServerTCP({
    required int listenPort,
    String? username,
    String? password,
    required String proxyAddr,
    String? proxyUser,
    String? proxyPass,
  }) {
    final completer = Completer<int>();
    _responseHandlers['create_proxy_server_tcp'] = (data) {
      if (data['success'] == true) {
        completer.complete(data['data']['srvID'] as int? ?? -1);
      } else {
        completer.completeError(data['error'] ?? 'Unknown error');
      }
    };

    final usernamePtr = username != null
        ? username.toNativeUtf8().cast<ffi.Char>()
        : ffi.nullptr;
    final passwordPtr = password != null
        ? password.toNativeUtf8().cast<ffi.Char>()
        : ffi.nullptr;
    final proxyAddrPtr = proxyAddr.toNativeUtf8().cast<ffi.Char>();
    final proxyUserPtr = proxyUser != null
        ? proxyUser.toNativeUtf8().cast<ffi.Char>()
        : ffi.nullptr;
    final proxyPassPtr = proxyPass != null
        ? proxyPass.toNativeUtf8().cast<ffi.Char>()
        : ffi.nullptr;

    final srvID = _bindings.CreateProxyToSocks5ServerTCP(
      listenPort,
      usernamePtr,
      passwordPtr,
      proxyAddrPtr,
      proxyUserPtr,
      proxyPassPtr,
      _nativePort,
    );

    if (usernamePtr != ffi.nullptr) malloc.free(usernamePtr);
    if (passwordPtr != ffi.nullptr) malloc.free(passwordPtr);
    malloc.free(proxyAddrPtr);
    if (proxyUserPtr != ffi.nullptr) malloc.free(proxyUserPtr);
    if (proxyPassPtr != ffi.nullptr) malloc.free(proxyPassPtr);

    // If response is synchronous (srvID > 0), complete immediately
    if (srvID > 0) {
      completer.complete(srvID);
    }

    return completer.future;
  }

  /// Create a UDP SOCKS5 server that proxies to another SOCKS5 server
  ///
  /// [listenPort] - Port to listen on
  /// [username] - Authentication username for clients (optional)
  /// [password] - Authentication password for clients (optional)
  /// [proxyAddr] - Address of the upstream SOCKS5 proxy
  /// [proxyUser] - Username for upstream proxy (optional)
  /// [proxyPass] - Password for upstream proxy (optional)
  ///
  /// Returns the server ID
  Future<int> createProxyToSocks5ServerUDP({
    required int listenPort,
    String? username,
    String? password,
    required String proxyAddr,
    String? proxyUser,
    String? proxyPass,
  }) {
    final completer = Completer<int>();
    _responseHandlers['create_proxy_server_udp'] = (data) {
      if (data['success'] == true) {
        completer.complete(data['data']['srvID'] as int? ?? -1);
      } else {
        completer.completeError(data['error'] ?? 'Unknown error');
      }
    };

    final usernamePtr = username != null
        ? username.toNativeUtf8().cast<ffi.Char>()
        : ffi.nullptr;
    final passwordPtr = password != null
        ? password.toNativeUtf8().cast<ffi.Char>()
        : ffi.nullptr;
    final proxyAddrPtr = proxyAddr.toNativeUtf8().cast<ffi.Char>();
    final proxyUserPtr = proxyUser != null
        ? proxyUser.toNativeUtf8().cast<ffi.Char>()
        : ffi.nullptr;
    final proxyPassPtr = proxyPass != null
        ? proxyPass.toNativeUtf8().cast<ffi.Char>()
        : ffi.nullptr;

    final srvID = _bindings.CreateProxyToSocks5ServerUDP(
      listenPort,
      usernamePtr,
      passwordPtr,
      proxyAddrPtr,
      proxyUserPtr,
      proxyPassPtr,
      _nativePort,
    );

    if (usernamePtr != ffi.nullptr) malloc.free(usernamePtr);
    if (passwordPtr != ffi.nullptr) malloc.free(passwordPtr);
    malloc.free(proxyAddrPtr);
    if (proxyUserPtr != ffi.nullptr) malloc.free(proxyUserPtr);
    if (proxyPassPtr != ffi.nullptr) malloc.free(proxyPassPtr);

    // If response is synchronous (srvID > 0), complete immediately
    if (srvID > 0) {
      completer.complete(srvID);
    }

    return completer.future;
  }

  /// Create a SOCKS5 server with authentication
  ///
  /// [listenPort] - Port to listen on
  ///
  /// Returns the server ID
  Future<int> createWithAuthServer({required int listenPort}) {
    final completer = Completer<int>();
    _responseHandlers['create_with_auth_server'] = (data) {
      if (data['success'] == true) {
        completer.complete(data['data']['srvID'] as int? ?? -1);
      } else {
        completer.completeError(data['error'] ?? 'Unknown error');
      }
    };

    final srvID = _bindings.CreateWithAuthServer(listenPort, _nativePort);

    // If response is synchronous (srvID > 0), complete immediately
    if (srvID > 0) {
      completer.complete(srvID);
    }

    return completer.future;
  }

  /// Create a SOCKS5 server without authentication
  ///
  /// [listenPort] - Port to listen on
  ///
  /// Returns the server ID
  Future<int> createWithoutAuthServer({required int listenPort}) {
    final completer = Completer<int>();
    _responseHandlers['create_without_auth_server'] = (data) {
      if (data['success'] == true) {
        completer.complete(data['data']['srvID'] as int? ?? -1);
      } else {
        completer.completeError(data['error'] ?? 'Unknown error');
      }
    };

    final srvID = _bindings.CreateWithoutAuthServer(listenPort, _nativePort);

    // If response is synchronous (srvID > 0), complete immediately
    if (srvID > 0) {
      completer.complete(srvID);
    }

    return completer.future;
  }

  /// Start a SOCKS5 server
  ///
  /// [srvID] - Server ID returned from one of the create methods
  ///
  /// Returns the task ID for the server operation
  Future<int> startSocks5Server(int srvID) {
    final completer = Completer<int>();
    _responseHandlers['start_socks5_server'] = (data) {
      if (data['success'] == true) {
        completer.complete(data['data']['taskID'] as int? ?? -1);
      } else {
        completer.completeError(data['error'] ?? 'Unknown error');
      }
    };

    final taskID = _bindings.StartSocks5Server(srvID, _nativePort);

    // If response is synchronous (taskID > 0), complete immediately
    if (taskID > 0) {
      completer.complete(taskID);
    }

    return completer.future;
  }

  /// Stop a SOCKS5 server
  ///
  /// [srvID] - Server ID
  Future<void> stopSocks5Server(int srvID) {
    final completer = Completer<void>();
    _responseHandlers['stop_socks5_server'] = (data) {
      if (data['success'] == true) {
        completer.complete();
      } else {
        completer.completeError(data['error'] ?? 'Unknown error');
      }
    };

    _bindings.StopSocks5Server(srvID, _nativePort);

    return completer.future;
  }

  // ==================== SOCKS5 CLIENT OPERATIONS ====================

  /// Connect to a target address via SOCKS5 proxy (TCP)
  ///
  /// [socksAddr] - SOCKS5 proxy server address (e.g., "127.0.0.1:1080")
  /// [username] - Authentication username (optional)
  /// [password] - Authentication password (optional)
  /// [targetAddr] - Target address to connect to (e.g., "example.com:80")
  ///
  /// Returns the connection ID
  Future<int> connectDirectTCP({
    required String socksAddr,
    String? username,
    String? password,
    required String targetAddr,
  }) {
    final completer = Completer<int>();
    _responseHandlers['connect_direct_tcp'] = (data) {
      if (data['success'] == true) {
        completer.complete(data['data']['connID'] as int? ?? -1);
      } else {
        completer.completeError(data['error'] ?? 'Unknown error');
      }
    };

    final socksAddrPtr = socksAddr.toNativeUtf8().cast<ffi.Char>();
    final usernamePtr = username != null
        ? username.toNativeUtf8().cast<ffi.Char>()
        : ffi.nullptr;
    final passwordPtr = password != null
        ? password.toNativeUtf8().cast<ffi.Char>()
        : ffi.nullptr;
    final targetAddrPtr = targetAddr.toNativeUtf8().cast<ffi.Char>();

    final connID = _bindings.ConnectDirectTCP(
      socksAddrPtr,
      usernamePtr,
      passwordPtr,
      targetAddrPtr,
      _nativePort,
    );

    malloc.free(socksAddrPtr);
    if (usernamePtr != ffi.nullptr) malloc.free(usernamePtr);
    if (passwordPtr != ffi.nullptr) malloc.free(passwordPtr);
    malloc.free(targetAddrPtr);

    // If response is synchronous (connID > 0), complete immediately
    if (connID > 0) {
      completer.complete(connID);
    }

    return completer.future;
  }

  /// Connect to SOCKS5 proxy for UDP association
  ///
  /// [socksAddr] - SOCKS5 proxy server address (e.g., "127.0.0.1:1080")
  /// [username] - Authentication username (optional)
  /// [password] - Authentication password (optional)
  ///
  /// Returns the connection ID for UDP association
  Future<int> connectDirectUDP({
    required String socksAddr,
    String? username,
    String? password,
  }) {
    final completer = Completer<int>();
    _responseHandlers['connect_direct_udp'] = (data) {
      if (data['success'] == true) {
        completer.complete(data['data']['connID'] as int? ?? -1);
      } else {
        completer.completeError(data['error'] ?? 'Unknown error');
      }
    };

    final socksAddrPtr = socksAddr.toNativeUtf8().cast<ffi.Char>();
    final usernamePtr = username != null
        ? username.toNativeUtf8().cast<ffi.Char>()
        : ffi.nullptr;
    final passwordPtr = password != null
        ? password.toNativeUtf8().cast<ffi.Char>()
        : ffi.nullptr;

    final connID = _bindings.ConnectDirectUDP(
      socksAddrPtr,
      usernamePtr,
      passwordPtr,
      _nativePort,
    );

    malloc.free(socksAddrPtr);
    if (usernamePtr != ffi.nullptr) malloc.free(usernamePtr);
    if (passwordPtr != ffi.nullptr) malloc.free(passwordPtr);

    // If response is synchronous (connID > 0), complete immediately
    if (connID > 0) {
      completer.complete(connID);
    }

    return completer.future;
  }

  // ==================== TASK MANAGEMENT ====================

  /// Stop a running task by its task ID
  ///
  /// [taskID] - Task ID returned from startSocks5Server or connect methods
  void stopTask(int taskID) {
    _bindings.StopTask(taskID, _nativePort);
  }
}
