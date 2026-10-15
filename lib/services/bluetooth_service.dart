import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/telemetry.dart';

enum DeviceBtState {
  disconnected,
  connecting,
  connected,
  error,
}

class BluetoothService {
  static const String targetDeviceName = 'EdgeAI_Predictive_Node';

  DeviceBtState _connectionState = DeviceBtState.disconnected;
  DeviceBtState get connectionState => _connectionState;

  BluetoothConnection? _connection;
  StreamSubscription<Uint8List>? _inputSubscription;

  // Stream controller for parsed TelemetryData
  final StreamController<TelemetryData> _telemetryController =
      StreamController<TelemetryData>.broadcast();
  Stream<TelemetryData> get telemetryStream => _telemetryController.stream;

  // Stream controller for incoming configuration responses (config_data & config_ack)
  final StreamController<Map<String, dynamic>> _configController =
      StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get configStream => _configController.stream;

  // Stream controller for connection state updates
  final StreamController<DeviceBtState> _stateController =
      StreamController<DeviceBtState>.broadcast();
  Stream<DeviceBtState> get stateStream => _stateController.stream;

  // Stream controller for raw line logs (useful for debugging & protocol auditing)
  final StreamController<String> _rawLogController =
      StreamController<String>.broadcast();
  Stream<String> get rawLogStream => _rawLogController.stream;

  String _buffer = '';
  BluetoothDevice? _connectedDevice;
  BluetoothDevice? get connectedDevice => _connectedDevice;

  String _lastErrorMsg = '';
  String get lastErrorMsg => _lastErrorMsg;

  /// Request required Android runtime permissions for Bluetooth Classic & Location.
  Future<bool> requestPermissions() async {
    try {
      Map<Permission, PermissionStatus> statuses = await [
        Permission.bluetoothConnect,
        Permission.bluetoothScan,
        Permission.location,
      ].request();

      // Check if critical permissions are granted or limited
      bool granted = (statuses[Permission.bluetoothConnect]?.isGranted ?? true) &&
          (statuses[Permission.bluetoothScan]?.isGranted ?? true);
      return granted;
    } catch (e) {
      debugPrint('Permission request error: $e');
      return false;
    }
  }

  /// Check whether Bluetooth is enabled on the device.
  Future<bool> isBluetoothEnabled() async {
    try {
      bool? isEnabled = await FlutterBluetoothSerial.instance.isEnabled;
      return isEnabled ?? false;
    } catch (e) {
      debugPrint('Error checking Bluetooth state: $e');
      return false;
    }
  }

  /// Request enabling Bluetooth via system prompt if disabled.
  Future<bool> requestEnableBluetooth() async {
    try {
      bool? requested = await FlutterBluetoothSerial.instance.requestEnable();
      return requested ?? false;
    } catch (e) {
      debugPrint('Error requesting Bluetooth enable: $e');
      return false;
    }
  }

  /// Get list of paired (bonded) Bluetooth devices.
  Future<List<BluetoothDevice>> getPairedDevices() async {
    try {
      return await FlutterBluetoothSerial.instance.getBondedDevices();
    } catch (e) {
      debugPrint('Error getting bonded devices: $e');
      return [];
    }
  }

  /// Find the ESP32 node by target advertised device name.
  Future<BluetoothDevice?> findTargetDevice() async {
    List<BluetoothDevice> bonded = await getPairedDevices();
    for (var device in bonded) {
      if (device.name == targetDeviceName ||
          (device.name != null && device.name!.contains('EdgeAI'))) {
        return device;
      }
    }
    return null;
  }

  /// Connect to ESP32 by address or by looking up `EdgeAI_Predictive_Node`.
  Future<bool> connect([String? deviceAddress]) async {
    if (_connectionState == DeviceBtState.connecting) return false;

    _setConnectionState(DeviceBtState.connecting);
    _buffer = '';

    try {
      await requestPermissions();

      bool btOn = await isBluetoothEnabled();
      if (!btOn) {
        btOn = await requestEnableBluetooth();
        if (!btOn) {
          _lastErrorMsg = 'Bluetooth is disabled on this phone.';
          _setConnectionState(DeviceBtState.error);
          return false;
        }
      }

      BluetoothDevice? target;
      if (deviceAddress != null && deviceAddress.isNotEmpty) {
        List<BluetoothDevice> paired = await getPairedDevices();
        target = paired.firstWhere(
          (d) => d.address == deviceAddress,
          orElse: () => BluetoothDevice(address: deviceAddress, name: targetDeviceName),
        );
      } else {
        target = await findTargetDevice();
      }

      if (target == null) {
        _lastErrorMsg = 'Target device "$targetDeviceName" not found in paired Bluetooth devices. Please pair the ESP32 in Android Settings first.';
        _setConnectionState(DeviceBtState.error);
        return false;
      }

      _connectedDevice = target;

      // Establish SPP connection
      _connection = await BluetoothConnection.toAddress(target.address);
      _setConnectionState(DeviceBtState.connected);
      _lastErrorMsg = '';

      // Listen to incoming byte stream
      _inputSubscription = _connection!.input!.listen(
        _onDataReceived,
        onDone: _onDisconnected,
        onError: _onError,
      );

      return true;
    } catch (e) {
      _lastErrorMsg = 'Connection failed: ${e.toString()}';
      debugPrint(_lastErrorMsg);
      _setConnectionState(DeviceBtState.error);
      return false;
    }
  }

  /// Handles incoming byte chunks from SPP stream.
  void _onDataReceived(Uint8List data) {
    try {
      String chunk = utf8.decode(data, allowMalformed: true);
      _buffer += chunk;

      // Process complete lines split by newline
      while (_buffer.contains('\n')) {
        int newlineIndex = _buffer.indexOf('\n');
        String rawLine = _buffer.substring(0, newlineIndex).trim();
        _buffer = _buffer.substring(newlineIndex + 1);

        if (rawLine.isNotEmpty) {
          _rawLogController.add(rawLine);
          _parseAndEmitJson(rawLine);
        }
      }
    } catch (e) {
      debugPrint('Error decoding byte chunk: $e');
    }
  }

  /// Parses JSON safely and emits TelemetryData or Config response.
  void _parseAndEmitJson(String rawLine) {
    try {
      String sanitized = rawLine.replaceAll('\r', '').trim();
      if (!sanitized.startsWith('{') || !sanitized.endsWith('}')) {
        return;
      }

      Map<String, dynamic> jsonMap = json.decode(sanitized);
      final type = jsonMap['type']?.toString();

      if (type == 'config_data' || type == 'config_ack') {
        _configController.add(jsonMap);
      } else {
        TelemetryData telemetry = TelemetryData.fromJson(jsonMap);
        _telemetryController.add(telemetry);
      }
    } catch (e) {
      debugPrint('Malformed JSON received ignored: "$rawLine". Error: $e');
    }
  }

  /// Transmit JSON configuration request to ESP32 over SPP (`{"type":"config_get","requestId":"123"}`)
  Future<bool> sendConfigGet(String requestId) async {
    if (_connection == null || !_connection!.isConnected) return false;
    try {
      final jsonStr = '${json.encode({
        'type': 'config_get',
        'requestId': requestId,
      })}\n';
      Uint8List bytes = Uint8List.fromList(utf8.encode(jsonStr));
      _connection!.output.add(bytes);
      await _connection!.output.allSent;
      return true;
    } catch (e) {
      debugPrint('Error sending config_get: $e');
      return false;
    }
  }

  /// Transmit JSON configuration update to ESP32 over SPP
  Future<bool> sendConfigSet(Map<String, dynamic> configJson, String requestId) async {
    if (_connection == null || !_connection!.isConnected) return false;
    try {
      final payload = {
        'type': 'config_set',
        'requestId': requestId,
        ...configJson,
      };
      final jsonStr = '${json.encode(payload)}\n';
      Uint8List bytes = Uint8List.fromList(utf8.encode(jsonStr));
      _connection!.output.add(bytes);
      await _connection!.output.allSent;
      return true;
    } catch (e) {
      debugPrint('Error sending config_set: $e');
      return false;
    }
  }

  /// Transmit a single character command (`T`, `D`, `L`, `S`, `C`, `O`, `R`) over SPP.
  Future<bool> sendCommand(String charCommand) async {
    if (_connection == null || !_connection!.isConnected) {
      _lastErrorMsg = 'Cannot send command: Bluetooth is disconnected.';
      return false;
    }

    try {
      Uint8List bytes = Uint8List.fromList(ascii.encode(charCommand));
      _connection!.output.add(bytes);
      await _connection!.output.allSent;
      debugPrint('Sent command over SPP: $charCommand');
      return true;
    } catch (e) {
      _lastErrorMsg = 'Failed to transmit command "$charCommand": $e';
      debugPrint(_lastErrorMsg);
      return false;
    }
  }

  /// Transmit compact sound-feature JSON payload over Bluetooth SPP:
  /// `{"type":"sound","level":0.72,"peak":0.91,"timestamp":123456789}`
  Future<bool> sendSoundFeatures(double level, double peak) async {
    if (_connection == null || !_connection!.isConnected) {
      return false;
    }

    try {
      final jsonString = '${json.encode({
        'type': 'sound',
        'level': level,
        'peak': peak,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      })}\n';

      Uint8List bytes = Uint8List.fromList(utf8.encode(jsonString));
      _connection!.output.add(bytes);
      await _connection!.output.allSent;
      return true;
    } catch (e) {
      debugPrint('Error sending sound feature packet: $e');
      return false;
    }
  }

  void _onDisconnected() {
    debugPrint('Bluetooth SPP stream completed/disconnected.');
    _setConnectionState(DeviceBtState.disconnected);
  }

  void _onError(dynamic error) {
    _lastErrorMsg = 'Bluetooth connection error: $error';
    debugPrint(_lastErrorMsg);
    _setConnectionState(DeviceBtState.error);
  }

  Future<void> disconnect() async {
    try {
      await _inputSubscription?.cancel();
      _inputSubscription = null;
      await _connection?.close();
      _connection = null;
    } catch (e) {
      debugPrint('Error closing connection: $e');
    } finally {
      _setConnectionState(DeviceBtState.disconnected);
    }
  }

  void _setConnectionState(DeviceBtState state) {
    _connectionState = state;
    if (!_stateController.isClosed) {
      _stateController.add(state);
    }
  }

  void dispose() {
    disconnect();
    if (!_telemetryController.isClosed) _telemetryController.close();
    if (!_configController.isClosed) _configController.close();
    if (!_stateController.isClosed) _stateController.close();
    if (!_rawLogController.isClosed) _rawLogController.close();
  }
}
