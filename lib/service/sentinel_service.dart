import 'dart:async';
import 'dart:io';
import 'dart:ffi' as ffi;
import 'dart:isolate';
import 'dart:convert';
import 'package:ffi/ffi.dart';
import '../bindings/generated_bindings.dart';

/// Service for loading and interacting with the Sentinel native library
class SentinelService {
  late final SentinelLibrary _bindings;
  late final ffi.DynamicLibrary _dylib;
  ReceivePort? _receivePort;
  int _nativePort = 0;
  final Map<String, Function(Map<String, dynamic>)> _responseHandlers = {};

  /// Singleton instance
  static SentinelService? _instance;
  
  factory SentinelService() {
    _instance ??= SentinelService._internal();
    return _instance!;
  }

  SentinelService._internal();

  /// Initialize the library and setup communication bridge
  Future<void> initialize() async {
    _dylib = _loadLibrary();
    _bindings = SentinelLibrary(_dylib);
    
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
    
    print('SentinelService initialized successfully');
  }

  /// Load the appropriate dynamic library based on platform
  ffi.DynamicLibrary _loadLibrary() {
    if (Platform.isWindows) {
      // Try multiple paths for Windows
      try {
        return ffi.DynamicLibrary.open('native/windows/sentinel.dll');
      } catch (e) {
        return ffi.DynamicLibrary.open('sentinel.dll');
      }
    } else if (Platform.isLinux) {
      try {
        return ffi.DynamicLibrary.open('native/linux/sentinel.so');
      } catch (e) {
        return ffi.DynamicLibrary.open('./sentinel.so');
      }
    } else if (Platform.isMacOS) {
      try {
        return ffi.DynamicLibrary.open('native/macos/sentinel.dylib');
      } catch (e) {
        return ffi.DynamicLibrary.open('./sentinel.dylib');
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
        print('Native: $message');
      }
    }
  }

  /// Dispose resources
  void dispose() {
    _bindings.UnregisterPort();
    _receivePort?.close();
    _receivePort = null;
  }

  // ==================== MOUSE OPERATIONS ====================

  /// Move mouse to absolute coordinates
  Future<Map<String, int>> move(int x, int y) {
    final completer = Completer<Map<String, int>>();
    _responseHandlers['move'] = (data) {
      if (data['success'] == true) {
        completer.complete(Map<String, int>.from(data['data']));
      } else {
        completer.completeError(data['error'] ?? 'Unknown error');
      }
    };
    _bindings.Move(x, y, _nativePort);
    return completer.future;
  }

  /// Move mouse relative to current position
  Future<Map<String, int>> moveRelative(int x, int y) {
    final completer = Completer<Map<String, int>>();
    _responseHandlers['move_relative'] = (data) {
      if (data['success'] == true) {
        completer.complete(Map<String, int>.from(data['data']));
      } else {
        completer.completeError(data['error'] ?? 'Unknown error');
      }
    };
    _bindings.MoveRelative(x, y, _nativePort);
    return completer.future;
  }

  /// Click mouse button
  Future<void> click({String button = 'left', bool doubleClick = false}) {
    final completer = Completer<void>();
    _responseHandlers['click'] = (data) {
      if (data['success'] == true) {
        completer.complete();
      } else {
        completer.completeError(data['error'] ?? 'Unknown error');
      }
    };
    final btnPtr = button.toNativeUtf8().cast<ffi.Char>();
    _bindings.Click(btnPtr, doubleClick ? 1 : 0, _nativePort);
    malloc.free(btnPtr);
    return completer.future;
  }

  /// Get current mouse location
  Future<Map<String, int>> getLocation() {
    final completer = Completer<Map<String, int>>();
    _responseHandlers['location'] = (data) {
      if (data['success'] == true) {
        completer.complete(Map<String, int>.from(data['data']));
      } else {
        completer.completeError(data['error'] ?? 'Unknown error');
      }
    };
    _bindings.GetLocation(_nativePort);
    return completer.future;
  }

  /// Scroll mouse wheel
  Future<void> scroll(int x, int y) {
    final completer = Completer<void>();
    _responseHandlers['scroll'] = (data) {
      if (data['success'] == true) {
        completer.complete();
      } else {
        completer.completeError(data['error'] ?? 'Unknown error');
      }
    };
    _bindings.Scroll(x, y, _nativePort);
    return completer.future;
  }

  /// Start smooth mouse movement (returns task ID)
  int moveSmoothStart(int x, int y) {
    return _bindings.MoveSmoothStart(x, y, _nativePort);
  }

  /// Start smooth drag operation (returns task ID)
  int dragSmoothStart(int x, int y) {
    return _bindings.DragSmoothStart(x, y, _nativePort);
  }

  /// Stop a running task
  void stopTask(int taskId) {
    _bindings.StopTask(taskId, _nativePort);
  }

  // ==================== KEYBOARD OPERATIONS ====================

  /// Type a string
  Future<void> typeStr(String text) {
    final completer = Completer<void>();
    _responseHandlers['type_str'] = (data) {
      if (data['success'] == true) {
        completer.complete();
      } else {
        completer.completeError(data['error'] ?? 'Unknown error');
      }
    };
    final textPtr = text.toNativeUtf8().cast<ffi.Char>();
    _bindings.TypeStr(textPtr, _nativePort);
    malloc.free(textPtr);
    return completer.future;
  }

  /// Tap a key with optional modifiers
  Future<void> keyTap(String key, {List<String>? modifiers}) {
    final completer = Completer<void>();
    _responseHandlers['key_tap'] = (data) {
      if (data['success'] == true) {
        completer.complete();
      } else {
        completer.completeError(data['error'] ?? 'Unknown error');
      }
    };
    
    final keyPtr = key.toNativeUtf8().cast<ffi.Char>();
    ffi.Pointer<ffi.Char> modsPtr;
    
    if (modifiers != null && modifiers.isNotEmpty) {
      final modsStr = modifiers.join(',');
      modsPtr = modsStr.toNativeUtf8().cast<ffi.Char>();
    } else {
      modsPtr = ffi.nullptr;
    }
    
    _bindings.KeyTap(keyPtr, modsPtr, _nativePort);
    
    malloc.free(keyPtr);
    if (modsPtr != ffi.nullptr) malloc.free(modsPtr);
    
    return completer.future;
  }

  /// Read clipboard content
  Future<String> readClipboard() {
    final completer = Completer<String>();
    _responseHandlers['read_all'] = (data) {
      if (data['success'] == true) {
        completer.complete(data['data']?.toString() ?? '');
      } else {
        completer.completeError(data['error'] ?? 'Unknown error');
      }
    };
    _bindings.ReadAll(_nativePort);
    return completer.future;
  }

  /// Write to clipboard
  Future<void> writeClipboard(String text) {
    final completer = Completer<void>();
    _responseHandlers['write_all'] = (data) {
      if (data['success'] == true) {
        completer.complete();
      } else {
        completer.completeError(data['error'] ?? 'Unknown error');
      }
    };
    final textPtr = text.toNativeUtf8().cast<ffi.Char>();
    _bindings.WriteAll(textPtr, _nativePort);
    malloc.free(textPtr);
    return completer.future;
  }

  // ==================== SCREEN OPERATIONS ====================

  /// Get screen size
  Future<Map<String, int>> getScreenSize() {
    final completer = Completer<Map<String, int>>();
    _responseHandlers['get_screen_size'] = (data) {
      if (data['success'] == true) {
        completer.complete(Map<String, int>.from(data['data']));
      } else {
        completer.completeError(data['error'] ?? 'Unknown error');
      }
    };
    _bindings.GetScreenSize(_nativePort);
    return completer.future;
  }

  /// Get pixel color at coordinates
  Future<String> getPixelColor(int x, int y) {
    final completer = Completer<String>();
    _responseHandlers['get_pixel_color'] = (data) {
      if (data['success'] == true) {
        completer.complete(data['data']['color']?.toString() ?? '');
      } else {
        completer.completeError(data['error'] ?? 'Unknown error');
      }
    };
    _bindings.GetPixelColor(x, y, _nativePort);
    return completer.future;
  }

  /// Capture screen region and save to file
  Future<String> captureScreenSave(int x, int y, int w, int h, {String? path}) {
    final completer = Completer<String>();
    _responseHandlers['capture_screen_save'] = (data) {
      if (data['success'] == true) {
        completer.complete(data['data']['path']?.toString() ?? '');
      } else {
        completer.completeError(data['error'] ?? 'Unknown error');
      }
    };
    
    ffi.Pointer<ffi.Char> pathPtr;
    if (path != null) {
      pathPtr = path.toNativeUtf8().cast<ffi.Char>();
    } else {
      pathPtr = ffi.nullptr;
    }
    
    _bindings.CaptureScreenSave(x, y, w, h, pathPtr, _nativePort);
    
    if (pathPtr != ffi.nullptr) malloc.free(pathPtr);
    
    return completer.future;
  }

  /// Capture screen region as base64 PNG
  Future<String> captureScreenBase64(int x, int y, int w, int h) {
    final completer = Completer<String>();
    _responseHandlers['capture_screen_base64'] = (data) {
      if (data['success'] == true) {
        completer.complete(data['data']['base64_png']?.toString() ?? '');
      } else {
        completer.completeError(data['error'] ?? 'Unknown error');
      }
    };
    _bindings.CaptureScreenBase64(x, y, w, h, _nativePort);
    return completer.future;
  }

  /// Get number of displays
  Future<int> getDisplaysNum() {
    final completer = Completer<int>();
    _responseHandlers['displays_num'] = (data) {
      if (data['success'] == true) {
        completer.complete(data['data'] as int? ?? 0);
      } else {
        completer.completeError(data['error'] ?? 'Unknown error');
      }
    };
    _bindings.DisplaysNum(_nativePort);
    return completer.future;
  }

  /// Get display bounds
  Future<Map<String, int>> getDisplayBounds(int index) {
    final completer = Completer<Map<String, int>>();
    _responseHandlers['get_display_bounds'] = (data) {
      if (data['success'] == true) {
        completer.complete(Map<String, int>.from(data['data']));
      } else {
        completer.completeError(data['error'] ?? 'Unknown error');
      }
    };
    _bindings.GetDisplayBounds(index, _nativePort);
    return completer.future;
  }

  // ==================== SYSTEM MONITORING ====================

  /// Start system monitoring (CPU, Memory, Network)
  /// Returns task ID that can be stopped with stopTask()
  int startMonitor({Function(Map<String, dynamic>)? onStats}) {
    if (onStats != null) {
      _responseHandlers['monitor_stats'] = onStats;
    }
    final taskId = _bindings.StartMonitor(_nativePort);
    return taskId;
  }

  /// Control systemd service (Linux only)
  Future<Map<String, dynamic>> controlService(
      String serviceName, String action) {
    final completer = Completer<Map<String, dynamic>>();
    _responseHandlers['control_service'] = (data) {
      if (data['success'] == true) {
        completer.complete(Map<String, dynamic>.from(data['data']));
      } else {
        completer.completeError(data['error'] ?? 'Unknown error');
      }
    };
    
    final namePtr = serviceName.toNativeUtf8().cast<ffi.Char>();
    final actionPtr = action.toNativeUtf8().cast<ffi.Char>();
    
    _bindings.ControlService(namePtr, actionPtr, _nativePort);
    
    malloc.free(namePtr);
    malloc.free(actionPtr);
    
    return completer.future;
  }

  // ==================== HOOK OPERATIONS ====================

  /// Register a hotkey combo
  void hookRegisterCombo(String key, {List<String>? modifiers}) {
    final keyPtr = key.toNativeUtf8().cast<ffi.Char>();
    ffi.Pointer<ffi.Char> modsPtr;
    
    if (modifiers != null && modifiers.isNotEmpty) {
      final modsStr = modifiers.join(',');
      modsPtr = modsStr.toNativeUtf8().cast<ffi.Char>();
    } else {
      modsPtr = ffi.nullptr;
    }
    
    _bindings.HookRegisterCombo(modsPtr, keyPtr, _nativePort);
    
    malloc.free(keyPtr);
    if (modsPtr != ffi.nullptr) malloc.free(modsPtr);
  }

  /// Start hook event listening
  void hookStart() {
    _bindings.HookStart(_nativePort);
  }

  /// Stop hook event listening
  void hookStop() {
    _bindings.HookStop();
  }

  // ==================== UTILITY OPERATIONS ====================

  /// Sleep for milliseconds
  Future<void> milliSleep(int ms) {
    final completer = Completer<void>();
    _responseHandlers['milli_sleep'] = (data) {
      if (data['success'] == true) {
        completer.complete();
      } else {
        completer.completeError(data['error'] ?? 'Unknown error');
      }
    };
    _bindings.MilliSleep(ms, _nativePort);
    return completer.future;
  }

  /// Set mouse sleep time between operations
  Future<void> setMouseSleep(int ms) {
    final completer = Completer<void>();
    _responseHandlers['set_mouse_sleep'] = (data) {
      if (data['success'] == true) {
        completer.complete();
      } else {
        completer.completeError(data['error'] ?? 'Unknown error');
      }
    };
    _bindings.SetMouseSleep(ms, _nativePort);
    return completer.future;
  }

  /// Set key sleep time between key operations
  Future<void> setKeySleep(int ms) {
    final completer = Completer<void>();
    _responseHandlers['set_key_sleep'] = (data) {
      if (data['success'] == true) {
        completer.complete();
      } else {
        completer.completeError(data['error'] ?? 'Unknown error');
      }
    };
    _bindings.SetKeySleep(ms, _nativePort);
    return completer.future;
  }
}

