import 'dart:convert';
import 'dart:typed_data';

/// Command categories for organizing operations
enum CommandCategory {
  mouse(0x01),
  keyboard(0x02),
  screen(0x03),
  clipboard(0x04),
  system(0x05),
  hook(0x06),
  config(0x07),
  connection(0x08);

  final int code;
  const CommandCategory(this. code);
  
  static CommandCategory fromCode(int code) {
    return CommandCategory. values.firstWhere(
      (e) => e.code == code,
      orElse: () => CommandCategory.connection,
    );
  }
}

/// Mouse operation types
enum MouseOp {
  move(0x01),
  moveRelative(0x02),
  click(0x03),
  doubleClick(0x04),
  rightClick(0x05),
  middleClick(0x06),
  scroll(0x07),
  getLocation(0x08),
  moveSmooth(0x09),
  dragSmooth(0x0A),
  mouseDown(0x0B),
  mouseUp(0x0C);

  final int code;
  const MouseOp(this.code);
  
  static MouseOp fromCode(int code) {
    return MouseOp.values.firstWhere((e) => e. code == code);
  }
}

/// Keyboard operation types
enum KeyboardOp {
  typeStr(0x01),
  keyTap(0x02),
  keyDown(0x03),
  keyUp(0x04),
  hotkey(0x05);

  final int code;
  const KeyboardOp(this.code);
  
  static KeyboardOp fromCode(int code) {
    return KeyboardOp.values.firstWhere((e) => e.code == code);
  }
}

/// Screen operation types
enum ScreenOp {
  getSize(0x01),
  getPixelColor(0x02),
  captureRegion(0x03),
  captureBase64(0x04),
  getDisplaysNum(0x05),
  getDisplayBounds(0x06);

  final int code;
  const ScreenOp(this.code);
  
  static ScreenOp fromCode(int code) {
    return ScreenOp.values.firstWhere((e) => e.code == code);
  }
}

/// Clipboard operation types
enum ClipboardOp {
  read(0x01),
  write(0x02);

  final int code;
  const ClipboardOp(this.code);
  
  static ClipboardOp fromCode(int code) {
    return ClipboardOp. values.firstWhere((e) => e.code == code);
  }
}

/// System operation types
enum SystemOp {
  startMonitor(0x01),
  stopMonitor(0x02),
  controlService(0x03),
  getSystemInfo(0x04);

  final int code;
  const SystemOp(this. code);
  
  static SystemOp fromCode(int code) {
    return SystemOp.values.firstWhere((e) => e. code == code);
  }
}

/// Unified command structure for all transports
class RemoteCommand {
  final String id;           // Unique command ID for response matching
  final CommandCategory category;
  final int operation;       // Operation code within category
  final Map<String, dynamic> params;
  final DateTime timestamp;

  RemoteCommand({
    required this. id,
    required this.category,
    required this.operation,
    this.params = const {},
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  /// Convert to JSON for WebSocket transport
  Map<String, dynamic> toJson() => {
    'id': id,
    'cat': category.code,
    'op': operation,
    'params': params,
    'ts': timestamp.millisecondsSinceEpoch,
  };

  /// Parse from JSON
  factory RemoteCommand.fromJson(Map<String, dynamic> json) {
    return RemoteCommand(
      id: json['id'] as String,
      category: CommandCategory. fromCode(json['cat'] as int),
      operation: json['op'] as int,
      params: Map<String, dynamic>. from(json['params'] ?? {}),
      timestamp: DateTime.fromMillisecondsSinceEpoch(json['ts'] as int),
    );
  }

  /// Convert to binary for BLE transport (compact format)
  /// Format: [ID_LEN(1)][ID(n)][CAT(1)][OP(1)][PARAMS_LEN(2)][PARAMS(n)]
  Uint8List toBinary() {
    final idBytes = utf8.encode(id);
    final paramsJson = utf8.encode(jsonEncode(params));
    
    final buffer = BytesBuilder();
    buffer. addByte(idBytes. length);
    buffer.add(idBytes);
    buffer. addByte(category.code);
    buffer.addByte(operation);
    buffer.addByte((paramsJson.length >> 8) & 0xFF);
    buffer.addByte(paramsJson. length & 0xFF);
    buffer. add(paramsJson);
    
    return buffer.toBytes();
  }

  /// Parse from binary
  factory RemoteCommand.fromBinary(Uint8List data) {
    int offset = 0;
    
    final idLen = data[offset++];
    final id = utf8.decode(data.sublist(offset, offset + idLen));
    offset += idLen;
    
    final category = CommandCategory.fromCode(data[offset++]);
    final operation = data[offset++];
    
    final paramsLen = (data[offset] << 8) | data[offset + 1];
    offset += 2;
    
    final paramsJson = utf8.decode(data.sublist(offset, offset + paramsLen));
    final params = paramsLen > 0 ?  jsonDecode(paramsJson) : {};
    
    return RemoteCommand(
      id: id,
      category: category,
      operation: operation,
      params: Map<String, dynamic>. from(params),
    );
  }

  // ==================== Factory Methods for Mouse Commands ====================

  static RemoteCommand mouseMove(int x, int y, {String? id}) => RemoteCommand(
    id: id ??  _generateId(),
    category: CommandCategory. mouse,
    operation: MouseOp. move.code,
    params: {'x': x, 'y': y},
  );

  static RemoteCommand mouseMoveRelative(int dx, int dy, {String? id}) => RemoteCommand(
    id: id ??  _generateId(),
    category: CommandCategory.mouse,
    operation: MouseOp.moveRelative. code,
    params: {'dx': dx, 'dy': dy},
  );

  static RemoteCommand mouseClick({String button = 'left', String? id}) => RemoteCommand(
    id: id ??  _generateId(),
    category: CommandCategory.mouse,
    operation: MouseOp.click.code,
    params: {'button': button},
  );

  static RemoteCommand mouseDoubleClick({String button = 'left', String? id}) => RemoteCommand(
    id: id ??  _generateId(),
    category: CommandCategory.mouse,
    operation: MouseOp.doubleClick. code,
    params: {'button': button},
  );

  static RemoteCommand mouseScroll(int x, int y, {String? id}) => RemoteCommand(
    id: id ??  _generateId(),
    category: CommandCategory.mouse,
    operation: MouseOp.scroll.code,
    params: {'x': x, 'y': y},
  );

  static RemoteCommand getMouseLocation({String? id}) => RemoteCommand(
    id: id ?? _generateId(),
    category: CommandCategory.mouse,
    operation: MouseOp.getLocation.code,
  );

  static RemoteCommand mouseMoveSmooth(int x, int y, {String? id}) => RemoteCommand(
    id: id ?? _generateId(),
    category: CommandCategory.mouse,
    operation: MouseOp.moveSmooth.code,
    params: {'x': x, 'y': y},
  );

  // ==================== Factory Methods for Keyboard Commands ====================

  static RemoteCommand typeString(String text, {String? id}) => RemoteCommand(
    id: id ?? _generateId(),
    category: CommandCategory. keyboard,
    operation: KeyboardOp.typeStr.code,
    params: {'text': text},
  );

  static RemoteCommand keyTap(String key, {List<String>? modifiers, String? id}) => RemoteCommand(
    id: id ??  _generateId(),
    category: CommandCategory.keyboard,
    operation: KeyboardOp.keyTap.code,
    params: {'key': key, 'modifiers': modifiers ??  []},
  );

  static RemoteCommand hotkey(List<String> keys, {String? id}) => RemoteCommand(
    id: id ?? _generateId(),
    category: CommandCategory.keyboard,
    operation: KeyboardOp.hotkey.code,
    params: {'keys': keys},
  );

  // ==================== Factory Methods for Screen Commands ====================

  static RemoteCommand getScreenSize({String? id}) => RemoteCommand(
    id: id ?? _generateId(),
    category: CommandCategory.screen,
    operation: ScreenOp.getSize.code,
  );

  static RemoteCommand captureScreen(int x, int y, int w, int h, {String? id}) => RemoteCommand(
    id: id ??  _generateId(),
    category: CommandCategory.screen,
    operation: ScreenOp.captureBase64.code,
    params: {'x': x, 'y': y, 'w': w, 'h': h},
  );

  // ==================== Factory Methods for Clipboard Commands ====================

  static RemoteCommand readClipboard({String? id}) => RemoteCommand(
    id: id ?? _generateId(),
    category: CommandCategory.clipboard,
    operation: ClipboardOp. read.code,
  );

  static RemoteCommand writeClipboard(String text, {String? id}) => RemoteCommand(
    id: id ?? _generateId(),
    category: CommandCategory.clipboard,
    operation: ClipboardOp.write.code,
    params: {'text': text},
  );

  // ==================== Factory Methods for System Commands ====================

  static RemoteCommand startMonitor({String?  id}) => RemoteCommand(
    id: id ?? _generateId(),
    category: CommandCategory.system,
    operation: SystemOp.startMonitor.code,
  );

  static RemoteCommand stopMonitor(int taskId, {String?  id}) => RemoteCommand(
    id: id ?? _generateId(),
    category: CommandCategory.system,
    operation: SystemOp.stopMonitor.code,
    params: {'taskId': taskId},
  );

  static int _idCounter = 0;
  static String _generateId() => 'cmd_${++_idCounter}_${DateTime.now(). millisecondsSinceEpoch}';
}

/// Response from desktop
class CommandResponse {
  final String commandId;
  final bool success;
  final dynamic data;
  final String? error;
  final DateTime timestamp;

  CommandResponse({
    required this.commandId,
    required this. success,
    this.data,
    this.error,
    DateTime? timestamp,
  }) : timestamp = timestamp ??  DateTime.now();

  Map<String, dynamic> toJson() => {
    'id': commandId,
    'success': success,
    'data': data,
    'error': error,
    'ts': timestamp. millisecondsSinceEpoch,
  };

  factory CommandResponse.fromJson(Map<String, dynamic> json) {
    return CommandResponse(
      commandId: json['id'] as String,
      success: json['success'] as bool,
      data: json['data'],
      error: json['error'] as String?,
      timestamp: DateTime.fromMillisecondsSinceEpoch(json['ts'] as int),
    );
  }

  Uint8List toBinary() {
    final json = jsonEncode(toJson());
    return utf8.encode(json);
  }

  factory CommandResponse. fromBinary(Uint8List data) {
    final json = jsonDecode(utf8.decode(data));
    return CommandResponse. fromJson(json);
  }
}