import 'dart:io';
import '../core/routers/command_ruter.dart';
import '../interface/websocket.dart';
import 'sentinel_service.dart';

/// Main desktop server that handles remote control requests
class DesktopServer {
  final SentinelService _sentinel = SentinelService();
  late final CommandRouter _router;
  final List<dynamic> _transports = [];
  
  bool _isRunning = false;
  bool get isRunning => _isRunning;
  
  /// Initialize the server
  Future<void> initialize() async {
    // Initialize native library
    await _sentinel.initialize();
    
    // Create command router
    _router = CommandRouter(_sentinel);
    
    print('Desktop server initialized');
  }
  
  /// Start the server with specified transports
  Future<void> start({
    bool enableWebSocket = true,
    int webSocketPort = 8765,
    bool enableBluetooth = false,
  }) async {
    if (_isRunning) {
      throw StateError('Server already running');
    }
    
    // Start WebSocket transport
    if (enableWebSocket) {
      final wsTransport = WebSocketTransport();
      await wsTransport.initialize();
      await wsTransport.startServer(config: {'port': webSocketPort});
      
      _router.registerTransport(wsTransport);
      _transports.add(wsTransport);
      
      print('WebSocket server started on port $webSocketPort');
      
      // Print connection info
      _printConnectionInfo(webSocketPort);
    }
    
    // Bluetooth would require platform-specific implementation
    // for peripheral/server mode
    
    _isRunning = true;
    print('\nDesktop server is running.  Press Ctrl+C to stop.');
  }
  
  void _printConnectionInfo(int port) {
    print('\n=== Connection Info ===');
    
    // Get local IP addresses
    NetworkInterface.list().then((interfaces) {
      for (final interface in interfaces) {
        for (final addr in interface.addresses) {
          if (addr.type == InternetAddressType. IPv4 && ! addr.isLoopback) {
            print('Connect via: ws://${addr.address}:$port');
          }
        }
      }
    });
  }
  
  /// Stop the server
  Future<void> stop() async {
    for (final transport in _transports) {
      transport.dispose();
    }
    _transports.clear();
    
    _router.dispose();
    _sentinel.dispose();
    
    _isRunning = false;
    print('Desktop server stopped');
  }
}

/// Entry point for desktop server
Future<void> remoteInit() async {
  final server = DesktopServer();
  
  await server.initialize();
  await server.start(
    enableWebSocket: true,
    webSocketPort: 8765,
  );
  
  // Handle shutdown
  ProcessSignal.sigint.watch(). listen((_) async {
    print('\nShutting down.. .');
    await server.stop();
    exit(0);
  });
  
  // Keep running
  await Future.delayed(Duration(days: 365));
}