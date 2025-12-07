import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data' as typed_data;
import 'package:flutter_blue_plus_windows/flutter_blue_plus_windows.dart';
import '../protocol/command_protocol.dart';
import 'transport.dart';

/// Bluetooth Low Energy transport
class BluetoothTransport with TransportMixin implements TransportInterface {
  @override
  String get name => 'Bluetooth';
  
  TransportState _state = TransportState.disconnected;
  @override
  TransportState get state => _state;
  
  final _eventsController = StreamController<TransportEvent>. broadcast();
  @override
  Stream<TransportEvent> get events => _eventsController.stream;
  
  final _commandsController = StreamController<RemoteCommand>.broadcast();
  @override
  Stream<RemoteCommand> get incomingCommands => _commandsController.stream;
  
  final _responsesController = StreamController<CommandResponse>.broadcast();
  @override
  Stream<CommandResponse> get incomingResponses => _responsesController.stream;
  
  // BLE UUIDs for our custom service
  static const String serviceUuid = "12345678-1234-1234-1234-123456789abc";
  static const String commandCharUuid = "12345678-1234-1234-1234-123456789abd";
  static const String responseCharUuid = "12345678-1234-1234-1234-123456789abe";
  
  BluetoothDevice? _connectedDevice;
  BluetoothCharacteristic? _commandCharacteristic;
  
  StreamSubscription?  _scanSubscription;
  StreamSubscription? _connectionSubscription;
  StreamSubscription? _characteristicSubscription;
  
  @override
  bool get isAvailable => Platform.isAndroid || Platform.isIOS;
  
  @override
  Future<void> initialize() async {
    if (!await FlutterBluePlus.isSupported) {
      throw UnsupportedError('Bluetooth not supported on this device');
    }
    
    // Listen for adapter state changes
    FlutterBluePlus.adapterState.listen((state) {
      if (state != BluetoothAdapterState.on) {
        _eventsController.add(TransportErrorEvent(name, 'Bluetooth is off'));
      }
    });
    
    _state = TransportState. disconnected;
  }
  
  /// Scan for devices with our service
  Stream<ScanResult> scan({Duration timeout = const Duration(seconds: 10)}) async* {
    await FlutterBluePlus.startScan(
      timeout: timeout,
      withServices: [Guid(serviceUuid)],
    );
    
    await for (final results in FlutterBluePlus.scanResults) {
      for (final result in results) {
        yield result;
      }
    }
  }
  
  /// Get list of scanned devices
  Future<List<ScanResult>> scanDevices({Duration timeout = const Duration(seconds: 5)}) async {
    final devices = <ScanResult>[];
    
    _scanSubscription = FlutterBluePlus.scanResults.expand((e) => e).listen((result) {
      if (! devices.any((d) => d.device.remoteId == result.device. remoteId)) {
        devices.add(result);
      }
    });
    
    await FlutterBluePlus.startScan(timeout: timeout);
    await Future.delayed(timeout);
    
    await _scanSubscription?.cancel();
    
    return devices;
  }
  
  @override
  Future<void> startServer({Map<String, dynamic>? config}) async {
    // BLE Peripheral mode is complex and platform-specific
    // For desktop, we typically use a different approach
    throw UnsupportedError(
      'BLE Peripheral mode not directly supported.  '
      'Consider using BlueZ D-Bus API on Linux or native plugins.'
    );
  }
  
  @override
  Future<void> connect(String target, {Map<String, dynamic>? config}) async {
    // target can be device ID or we can connect to provided BluetoothDevice
    final device = config? ['device'] as BluetoothDevice?;
    
    if (device == null) {
      throw ArgumentError('BluetoothDevice must be provided in config');
    }
    
    try {
      _state = TransportState. connecting;
      
      // Connect to device
      await device.connect(timeout: const Duration(seconds: 15), license: License.free);
      _connectedDevice = device;
      
      // Listen for disconnection
      _connectionSubscription = device.connectionState.listen((state) {
        if (state == BluetoothConnectionState.disconnected) {
          _state = TransportState.disconnected;
          _eventsController.add(TransportDisconnectedEvent(name));
          failAllPendingCommands('Bluetooth disconnected');
        }
      });
      
      // Discover services
      final services = await device. discoverServices();
      
      // Find our service
      for (final service in services) {
        if (service.uuid. toString(). toLowerCase() == serviceUuid.toLowerCase()) {
          for (final char in service.characteristics) {
            final charUuid = char. uuid.toString().toLowerCase();
            
            if (charUuid == commandCharUuid. toLowerCase()) {
              _commandCharacteristic = char;
            } else if (charUuid == responseCharUuid.toLowerCase()) {
              
              // Subscribe to responses
              await char.setNotifyValue(true);
              _characteristicSubscription = char.onValueReceived.listen(_handleBleResponse);
              device.cancelWhenDisconnected(_characteristicSubscription! );
            }
          }
        }
      }
      
      if (_commandCharacteristic == null) {
        throw StateError('Command characteristic not found');
      }
      
      _state = TransportState.connected;
      _eventsController. add(TransportConnectedEvent(name, {
        'deviceName': device.platformName,
        'deviceId': device.remoteId. toString(),
      }));
      
    } catch (e) {
      _state = TransportState. error;
      _eventsController.add(TransportErrorEvent(name, e. toString()));
      await disconnect();
      rethrow;
    }
  }
  
 void _handleBleResponse(List<int> value) {
  try {
    // Try to parse as JSON first (for complete messages)
    final json = jsonDecode(utf8.decode(value));
    
    if (json.containsKey('success')) {
      final response = CommandResponse.fromJson(json);
      completePendingCommand(response);
      _responsesController.add(response);
    } else if (json.containsKey('cat')) {
      final command = RemoteCommand.fromJson(json);
      _commandsController.add(command);
    }
  } catch (e) {
    // Try binary protocol
    try {
      final response = CommandResponse.fromBinary(typed_data.Uint8List.fromList(value));
      completePendingCommand(response);
      _responsesController.add(response);
    } catch (e2) {
      print('Failed to parse BLE message: $e2');
    }
  }
}
  
  @override
  Future<void> disconnect() async {
    await _scanSubscription?.cancel();
    await _connectionSubscription?.cancel();
    await _characteristicSubscription?. cancel();
    
    await _connectedDevice?. disconnect();
    
    _connectedDevice = null;
    _commandCharacteristic = null;
    
    _state = TransportState.disconnected;
    failAllPendingCommands('Disconnected');
  }
  
  @override
  Future<CommandResponse> sendCommand(RemoteCommand command, {Duration? timeout}) async {
    if (_commandCharacteristic == null || _state != TransportState.connected) {
      throw StateError('Not connected');
    }
    
    final completer = registerPendingCommand(command.id);
    
    // Use binary format for BLE (more efficient)
    final data = command.toBinary();
    
    // Split if necessary (BLE has MTU limits)
    await _writeWithMtu(data);
    
    return completer.future. timeout(
      timeout ?? defaultTimeout,
      onTimeout: () {
        failPendingCommand(command.id, 'Command timeout');
        throw TimeoutException('Command ${command.id} timed out');
      },
    );
  }
  
  /// Write data respecting MTU limits
  Future<void> _writeWithMtu(List<int> data) async {
    final mtu = _connectedDevice?. mtuNow ?? 23;
    final chunkSize = mtu - 3; // BLE overhead
    
    for (int i = 0; i < data.length; i += chunkSize) {
      final end = (i + chunkSize < data.length) ?  i + chunkSize : data.length;
      final chunk = data.sublist(i, end);
      
      await _commandCharacteristic!.write(chunk, withoutResponse: false);
    }
  }
  
  @override
  Future<void> sendResponse(CommandResponse response) async {
    // Server-side response (if we implement peripheral mode)
    throw UnsupportedError('Response sending not supported in BLE Central mode');
  }
  
  @override
  void dispose() {
    disconnect();
    _eventsController.close();
    _commandsController.close();
    _responsesController.close();
  }
}

// Helper for Uint8List
class Uint8List {
  static List<int> fromList(List<int> list) => list;
}