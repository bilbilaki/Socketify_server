import 'dart:async';
import '../../interface/transport.dart';
import '../../protocol/command_protocol.dart';
import '../../service/sentinel_service.dart';


/// Routes incoming commands to the appropriate handler
class CommandRouter {
  final SentinelService _sentinel;
  final List<TransportInterface> _transports = [];
  final List<StreamSubscription> _subscriptions = [];
  
  /// Map of custom command handlers
  final Map<String, Future<dynamic> Function(RemoteCommand)> _customHandlers = {};
  
  CommandRouter(this._sentinel);
  
  /// Register a transport for incoming commands
  void registerTransport(TransportInterface transport) {
    _transports. add(transport);
    
    final sub = transport.incomingCommands.listen((command) {
      _handleCommand(transport, command);
    });
    
    _subscriptions.add(sub);
  }
  
  /// Register a custom command handler
  void registerHandler(
    CommandCategory category,
    int operation,
    Future<dynamic> Function(RemoteCommand) handler,
  ) {
    final key = '${category.code}_$operation';
    _customHandlers[key] = handler;
  }
  
  /// Handle incoming command and route to appropriate handler
  Future<void> _handleCommand(TransportInterface transport, RemoteCommand command) async {
    CommandResponse response;
    
    try {
      final result = await _processCommand(command);
      response = CommandResponse(
        commandId: command.id,
        success: true,
        data: result,
      );
    } catch (e) {
      response = CommandResponse(
        commandId: command.id,
        success: false,
        error: e.toString(),
      );
    }
    
    // Send response back
    await transport.sendResponse(response);
  }
  
  /// Process command based on category and operation
  Future<dynamic> _processCommand(RemoteCommand command) async {
    // Check for custom handler first
    final handlerKey = '${command.category.code}_${command.operation}';
    if (_customHandlers. containsKey(handlerKey)) {
      return _customHandlers[handlerKey]!(command);
    }
    
    // Route to built-in handlers
    switch (command.category) {
      case CommandCategory.mouse:
        return _handleMouseCommand(command);
      case CommandCategory.keyboard:
        return _handleKeyboardCommand(command);
      case CommandCategory.screen:
        return _handleScreenCommand(command);
      case CommandCategory.clipboard:
        return _handleClipboardCommand(command);
      case CommandCategory.system:
        return _handleSystemCommand(command);
      case CommandCategory.hook:
        return _handleHookCommand(command);
      case CommandCategory.config:
        return _handleConfigCommand(command);
      case CommandCategory.connection:
        return _handleConnectionCommand(command);
    }
  }
  
  // ==================== Mouse Command Handler ====================
  
  Future<dynamic> _handleMouseCommand(RemoteCommand command) async {
    final op = MouseOp. fromCode(command.operation);
    final params = command.params;
    
    switch (op) {
      case MouseOp.move:
        return await _sentinel.move(params['x'] as int, params['y'] as int);
        
      case MouseOp.moveRelative:
        return await _sentinel. moveRelative(params['dx'] as int, params['dy'] as int);
        
      case MouseOp.click:
        await _sentinel.click(button: params['button'] as String?  ?? 'left');
        return null;
        
      case MouseOp. doubleClick:
        await _sentinel.click(
          button: params['button'] as String?  ?? 'left',
          doubleClick: true,
        );
        return null;
        
      case MouseOp. rightClick:
        await _sentinel.click(button: 'right');
        return null;
        
      case MouseOp.middleClick:
        await _sentinel.click(button: 'center');
        return null;
        
      case MouseOp. scroll:
        await _sentinel.scroll(params['x'] as int, params['y'] as int);
        return null;
        
      case MouseOp.getLocation:
        return await _sentinel.getLocation();
        
      case MouseOp.moveSmooth:
        final taskId = _sentinel.moveSmoothStart(
          params['x'] as int,
          params['y'] as int,
        );
        return {'taskId': taskId};
        
      case MouseOp. dragSmooth:
        final taskId = _sentinel.dragSmoothStart(
          params['x'] as int,
          params['y'] as int,
        );
        return {'taskId': taskId};
        
      case MouseOp.mouseDown:
      case MouseOp. mouseUp:
        // Implement if SentinelService supports these
        throw UnimplementedError('mouseDown/mouseUp not implemented');
    }
  }
  
  // ==================== Keyboard Command Handler ====================
  
  Future<dynamic> _handleKeyboardCommand(RemoteCommand command) async {
    final op = KeyboardOp.fromCode(command.operation);
    final params = command.params;
    
    switch (op) {
      case KeyboardOp.typeStr:
        await _sentinel.typeStr(params['text'] as String);
        return null;
        
      case KeyboardOp.keyTap:
        final modifiers = (params['modifiers'] as List?)?.cast<String>();
        await _sentinel.keyTap(params['key'] as String, modifiers: modifiers);
        return null;
        
      case KeyboardOp.hotkey:
        final keys = (params['keys'] as List). cast<String>();
        // Execute as key combination
        if (keys.length > 1) {
          final modifiers = keys.sublist(0, keys.length - 1);
          final key = keys.last;
          await _sentinel.keyTap(key, modifiers: modifiers);
        } else if (keys.isNotEmpty) {
          await _sentinel.keyTap(keys. first);
        }
        return null;
        
      case KeyboardOp. keyDown:
      case KeyboardOp.keyUp:
        throw UnimplementedError('keyDown/keyUp not implemented');
    }
  }
  
  // ==================== Screen Command Handler ====================
  
  Future<dynamic> _handleScreenCommand(RemoteCommand command) async {
    final op = ScreenOp.fromCode(command.operation);
    final params = command.params;
    
    switch (op) {
      case ScreenOp.getSize:
        return await _sentinel.getScreenSize();
        
      case ScreenOp.getPixelColor:
        return await _sentinel.getPixelColor(
          params['x'] as int,
          params['y'] as int,
        );
        
      case ScreenOp. captureRegion:
        return await _sentinel.captureScreenSave(
          params['x'] as int,
          params['y'] as int,
          params['w'] as int,
          params['h'] as int,
          path: params['path'] as String?,
        );
        
      case ScreenOp.captureBase64:
        return await _sentinel.captureScreenBase64(
          params['x'] as int,
          params['y'] as int,
          params['w'] as int,
          params['h'] as int,
        );
        
      case ScreenOp.getDisplaysNum:
        return await _sentinel.getDisplaysNum();
        
      case ScreenOp.getDisplayBounds:
        return await _sentinel.getDisplayBounds(params['index'] as int);
    }
  }
  
  // ==================== Clipboard Command Handler ====================
  
  Future<dynamic> _handleClipboardCommand(RemoteCommand command) async {
    final op = ClipboardOp.fromCode(command.operation);
    final params = command. params;
    
    switch (op) {
      case ClipboardOp. read:
        return await _sentinel.readClipboard();
        
      case ClipboardOp.write:
        await _sentinel.writeClipboard(params['text'] as String);
        return null;
    }
  }
  
  // ==================== System Command Handler ====================
  
  final Map<int, int> _monitorTasks = {};
  
  Future<dynamic> _handleSystemCommand(RemoteCommand command) async {
    final op = SystemOp.fromCode(command.operation);
    final params = command.params;
    
    switch (op) {
      case SystemOp.startMonitor:
        final taskId = _sentinel. startMonitor(
          onStats: (stats) {
            // Broadcast stats to all transports
            _broadcastMonitorStats(stats);
          },
        );
        _monitorTasks[command.hashCode] = taskId;
        return {'taskId': taskId};
        
      case SystemOp. stopMonitor:
        final taskId = params['taskId'] as int;
        _sentinel.stopTask(taskId);
        return null;
        
      case SystemOp. controlService:
        return await _sentinel.controlService(
          params['serviceName'] as String,
          params['action'] as String,
        );
        
      case SystemOp.getSystemInfo:
        // Return combined system info
        return {
          'screenSize': await _sentinel.getScreenSize(),
          'displays': await _sentinel. getDisplaysNum(),
        };
    }
  }
  
  void _broadcastMonitorStats(Map<String, dynamic> stats) {
    for (final transport in _transports) {
      transport.sendResponse(CommandResponse(
        commandId: 'monitor_update',
        success: true,
        data: stats,
      ));
    }
  }
  
  // ==================== Hook Command Handler ====================
  
  Future<dynamic> _handleHookCommand(RemoteCommand command) async {
    // Implement hook commands if needed
    throw UnimplementedError('Hook commands not implemented');
  }
  
  // ==================== Config Command Handler ====================
  
  Future<dynamic> _handleConfigCommand(RemoteCommand command) async {
    final params = command.params;
    
    if (params. containsKey('mouseSleep')) {
      await _sentinel.setMouseSleep(params['mouseSleep'] as int);
    }
    if (params.containsKey('keySleep')) {
      await _sentinel. setKeySleep(params['keySleep'] as int);
    }
    
    return null;
  }
  
  // ==================== Connection Command Handler ====================
  
  Future<dynamic> _handleConnectionCommand(RemoteCommand command) async {
    // Handle connection-related commands (ping, info, etc.)
    return {'status': 'connected', 'timestamp': DateTime.now(). toIso8601String()};
  }
  
  /// Dispose all resources
  void dispose() {
    for (final sub in _subscriptions) {
      sub. cancel();
    }
    _subscriptions.clear();
    _transports.clear();
  }
}