import 'dart:async';
import '../protocol/command_protocol.dart';

/// Connection states for transports
enum TransportState {
  disconnected,
  connecting,
  connected,
  reconnecting,
  error,
}

/// Events emitted by transports
abstract class TransportEvent {}

class TransportConnectedEvent extends TransportEvent {
  final String transportName;
  final Map<String, dynamic>? deviceInfo;
  TransportConnectedEvent(this.transportName, [this.deviceInfo]);
}

class TransportDisconnectedEvent extends TransportEvent {
  final String transportName;
  final String?  reason;
  TransportDisconnectedEvent(this.transportName, [this.reason]);
}

class TransportErrorEvent extends TransportEvent {
  final String transportName;
  final String error;
  TransportErrorEvent(this. transportName, this.error);
}

class TransportDataEvent extends TransportEvent {
  final String transportName;
  final dynamic data;
  TransportDataEvent(this.transportName, this.data);
}

/// Abstract interface for all transport types
abstract class TransportInterface {
  /// Unique name for this transport type
  String get name;
  
  /// Current connection state
  TransportState get state;
  
  /// Stream of transport events
  Stream<TransportEvent> get events;
  
  /// Stream of incoming commands (for server/desktop side)
  Stream<RemoteCommand> get incomingCommands;
  
  /// Stream of incoming responses (for client/mobile side)
  Stream<CommandResponse> get incomingResponses;
  
  /// Initialize the transport
  Future<void> initialize();
  
  /// Start listening/advertising (server mode)
  Future<void> startServer({Map<String, dynamic>? config});
  
  /// Connect to a remote device/server (client mode)
  Future<void> connect(String target, {Map<String, dynamic>? config});
  
  /// Disconnect from current connection
  Future<void> disconnect();
  
  /// Send a command (client side)
  Future<CommandResponse> sendCommand(RemoteCommand command, {Duration? timeout});
  
  /// Send a response (server side)
  Future<void> sendResponse(CommandResponse response);
  
  /// Check if transport is available on this platform
  bool get isAvailable;
  
  /// Dispose resources
  void dispose();
}

/// Mixin providing common functionality for transports
mixin TransportMixin {
  final Map<String, Completer<CommandResponse>> _pendingCommands = {};
  final Duration defaultTimeout = const Duration(seconds: 30);
  
  /// Register a pending command and return completer
  Completer<CommandResponse> registerPendingCommand(String commandId) {
    final completer = Completer<CommandResponse>();
    _pendingCommands[commandId] = completer;
    return completer;
  }
  
  /// Complete a pending command with response
  void completePendingCommand(CommandResponse response) {
    final completer = _pendingCommands. remove(response.commandId);
    if (completer != null && ! completer.isCompleted) {
      completer.complete(response);
    }
  }
  
  /// Fail a pending command with error
  void failPendingCommand(String commandId, String error) {
    final completer = _pendingCommands.remove(commandId);
    if (completer != null && !completer.isCompleted) {
      completer.completeError(error);
    }
  }
  
  /// Fail all pending commands
  void failAllPendingCommands(String error) {
    for (final entry in _pendingCommands.entries) {
      if (! entry.value.isCompleted) {
        entry.value. completeError(error);
      }
    }
    _pendingCommands. clear();
  }
}