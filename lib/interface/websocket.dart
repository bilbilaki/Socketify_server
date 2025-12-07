import 'dart:async';
import 'dart:convert';
import 'dart:io';
import '../protocol/command_protocol.dart';
import 'transport.dart';

/// WebSocket transport for network-based communication
class WebSocketTransport with TransportMixin implements TransportInterface {
  @override
  String get name => 'WebSocket';
  
  TransportState _state = TransportState.disconnected;
  @override
  TransportState get state => _state;
  
  final _eventsController = StreamController<TransportEvent>.broadcast();
  @override
  Stream<TransportEvent> get events => _eventsController.stream;
  
  final _commandsController = StreamController<RemoteCommand>.broadcast();
  @override
  Stream<RemoteCommand> get incomingCommands => _commandsController. stream;
  
  final _responsesController = StreamController<CommandResponse>.broadcast();
  @override
  Stream<CommandResponse> get incomingResponses => _responsesController.stream;
  
  HttpServer? _server;
  WebSocket? _clientSocket;
  final List<WebSocket> _serverConnections = [];
  
  int _serverPort = 8765;
  String?  _serverHost;
  
  @override
  bool get isAvailable => true; // WebSocket available on all platforms
  
  @override
  Future<void> initialize() async {
    _state = TransportState. disconnected;
  }
  
  /// Start WebSocket server (desktop side)
  @override
  Future<void> startServer({Map<String, dynamic>? config}) async {
    _serverPort = config? ['port'] ?? 8765;
    _serverHost = config?['host'] ??  '0.0.0. 0';
    
    try {
      _state = TransportState. connecting;
      
      _server = await HttpServer.bind(_serverHost!, _serverPort);
      print('WebSocket server listening on $_serverHost:$_serverPort');
      
      _state = TransportState. connected;
      _eventsController.add(TransportConnectedEvent(name, {
        'host': _serverHost,
        'port': _serverPort,
      }));
      
      _server! .transform(WebSocketTransformer()).listen(
        _handleServerConnection,
        onError: (error) {
          _eventsController.add(TransportErrorEvent(name, error. toString()));
        },
      );
    } catch (e) {
      _state = TransportState. error;
      _eventsController.add(TransportErrorEvent(name, e.toString()));
      rethrow;
    }
  }
  
  void _handleServerConnection(WebSocket socket) {
    _serverConnections.add(socket);
    print('Client connected.  Total connections: ${_serverConnections.length}');
    
    socket.listen(
      (data) => _handleServerMessage(socket, data),
      onDone: () {
        _serverConnections.remove(socket);
        print('Client disconnected. Total connections: ${_serverConnections. length}');
      },
      onError: (error) {
        _serverConnections.remove(socket);
        _eventsController.add(TransportErrorEvent(name, error.toString()));
      },
    );
  }
  
  void _handleServerMessage(WebSocket socket, dynamic data) {
    try {
      final json = jsonDecode(data as String);
      
      // Check if it's a command or response
      if (json. containsKey('cat') && json. containsKey('op')) {
        final command = RemoteCommand. fromJson(json);
        // Attach socket reference for response routing
        command.params['_socket'] = socket;
        _commandsController.add(command);
      } else if (json.containsKey('success')) {
        final response = CommandResponse.fromJson(json);
        completePendingCommand(response);
        _responsesController. add(response);
      }
    } catch (e) {
      print('Error parsing message: $e');
    }
  }
  
  /// Connect to WebSocket server (mobile side)
  @override
  Future<void> connect(String target, {Map<String, dynamic>?  config}) async {
    // target format: "ws://host:port" or just "host:port"
    String wsUrl = target;
    if (!target.startsWith('ws://') && !target.startsWith('wss://')) {
      wsUrl = 'ws://$target';
    }
    
    try {
      _state = TransportState. connecting;
      
      _clientSocket = await WebSocket.connect(wsUrl);
      
      _state = TransportState.connected;
      _eventsController.add(TransportConnectedEvent(name, {'url': wsUrl}));
      
      _clientSocket!.listen(
        _handleClientMessage,
        onDone: () {
          _state = TransportState.disconnected;
          _eventsController.add(TransportDisconnectedEvent(name));
          failAllPendingCommands('Connection closed');
        },
        onError: (error) {
          _state = TransportState.error;
          _eventsController. add(TransportErrorEvent(name, error.toString()));
          failAllPendingCommands(error.toString());
        },
      );
    } catch (e) {
      _state = TransportState.error;
      _eventsController.add(TransportErrorEvent(name, e.toString()));
      rethrow;
    }
  }
  
  void _handleClientMessage(dynamic data) {
    try {
      final json = jsonDecode(data as String);
      
      if (json.containsKey('success')) {
        final response = CommandResponse. fromJson(json);
        completePendingCommand(response);
        _responsesController.add(response);
      } else if (json.containsKey('cat')) {
        // Server pushing command (e.g., monitor updates)
        final command = RemoteCommand. fromJson(json);
        _commandsController.add(command);
      }
    } catch (e) {
      print('Error parsing message: $e');
    }
  }
  
  @override
  Future<void> disconnect() async {
    await _clientSocket?.close();
    _clientSocket = null;
    
    for (final socket in _serverConnections) {
      await socket.close();
    }
    _serverConnections.clear();
    
    await _server?.close();
    _server = null;
    
    _state = TransportState.disconnected;
    failAllPendingCommands('Disconnected');
  }
  
  @override
  Future<CommandResponse> sendCommand(RemoteCommand command, {Duration? timeout}) async {
    if (_clientSocket == null || _state != TransportState. connected) {
      throw StateError('Not connected');
    }
    
    final completer = registerPendingCommand(command. id);
    
    _clientSocket!.add(jsonEncode(command. toJson()));
    
    return completer.future. timeout(
      timeout ?? defaultTimeout,
      onTimeout: () {
        failPendingCommand(command.id, 'Command timeout');
        throw TimeoutException('Command ${command.id} timed out');
      },
    );
  }
  
  @override
  Future<void> sendResponse(CommandResponse response) async {
    final json = jsonEncode(response. toJson());
    
    // Send to specific socket if available, otherwise broadcast
    if (_serverConnections.isNotEmpty) {
      // For now, send to all connected clients
      for (final socket in _serverConnections) {
        socket.add(json);
      }
    } else if (_clientSocket != null) {
      _clientSocket!.add(json);
    }
  }
  
  /// Send response to specific client
  Future<void> sendResponseToClient(WebSocket socket, CommandResponse response) async {
    socket.add(jsonEncode(response.toJson()));
  }
  
  /// Broadcast to all connected clients
  void broadcast(String message) {
    for (final socket in _serverConnections) {
      socket. add(message);
    }
  }
  
  @override
  void dispose() {
    disconnect();
    _eventsController.close();
    _commandsController.close();
    _responsesController.close();
  }
}