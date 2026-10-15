import 'dart:async';
import 'package:flutter/material.dart';
import '../models/telemetry.dart';
import '../models/machine_alert.dart';
import '../models/device_config.dart';
import '../services/bluetooth_service.dart';
import '../services/alert_service.dart';
import '../services/vibration_service.dart';
import '../services/sound_monitor_service.dart';

class MachineController extends ChangeNotifier {
  final BluetoothService _bluetoothService = BluetoothService();
  final AlertService _alertService = AlertService();
  final VibrationService _vibrationService = VibrationService();
  final SoundMonitorService _soundMonitorService = SoundMonitorService();

  StreamSubscription<TelemetryData>? _telemetrySub;
  StreamSubscription<DeviceBtState>? _stateSub;
  StreamSubscription<Map<String, dynamic>>? _soundSub;
  StreamSubscription<Map<String, dynamic>>? _configSub;
  Timer? _stalenessTimer;

  // Latest telemetry data
  TelemetryData _telemetry = TelemetryData.initial();
  TelemetryData get telemetry => _telemetry;

  // Rolling history of last 60 telemetry readings
  final List<TelemetryData> _history = [];
  List<TelemetryData> get history => List.unmodifiable(_history);

  // Bluetooth Connection state
  DeviceBtState _connectionState = DeviceBtState.disconnected;
  DeviceBtState get connectionState => _connectionState;

  // Configuration State & Sync
  DeviceConfiguration _activeConfig = DeviceConfiguration.initial();
  DeviceConfiguration get activeConfig => _activeConfig;

  DeviceConfiguration _draftConfig = DeviceConfiguration.initial();
  DeviceConfiguration get draftConfig => _draftConfig;

  bool _isConfigApplying = false;
  bool get isConfigApplying => _isConfigApplying;

  bool _isConfigSyncing = false;
  bool get isConfigSyncing => _isConfigSyncing;

  String _configSyncStatus = 'DISCONNECTED';
  String get configSyncStatus => _configSyncStatus;

  String _configErrorMsg = '';
  String get configErrorMsg => _configErrorMsg;

  bool get hasUnsavedConfigEdits => _draftConfig != _activeConfig;

  // Emergency Overlay Dismissal state
  bool _isEmergencyOverlayAcknowledged = false;
  bool get isEmergencyOverlayAcknowledged => _isEmergencyOverlayAcknowledged;

  bool get isEmergencyActive {
    return (_alertService.currentState == EmergencyState.emergencyLatched ||
            _alertService.currentState == EmergencyState.resetPending ||
            _telemetry.emergency ||
            _telemetry.risk >= 70 ||
            _telemetry.status == 'CRITICAL');
  }

  String get connectionStatusText {
    switch (_connectionState) {
      case DeviceBtState.connected:
        return 'BT CONNECTED';
      case DeviceBtState.connecting:
        return 'CONNECTING...';
      case DeviceBtState.disconnected:
      case DeviceBtState.error:
        return 'BT DISCONNECTED';
    }
  }

  Color get connectionStatusColor {
    switch (_connectionState) {
      case DeviceBtState.connected:
        return const Color(0xFF00E676); // Green
      case DeviceBtState.connecting:
        return const Color(0xFFF5D400); // Yellow
      case DeviceBtState.disconnected:
      case DeviceBtState.error:
        return const Color(0xFFFF3D00); // Red
    }
  }

  // Alerts
  List<MachineAlert> get alerts => _alertService.alerts;
  EmergencyState get emergencyState => _alertService.currentState;

  // Command feedback & status tracking
  bool _isCommandPending = false;
  bool get isCommandPending => _isCommandPending;

  String _commandFeedback = '';
  String get commandFeedback => _commandFeedback;

  bool? _commandSuccess;
  bool? get commandSuccess => _commandSuccess;

  // Last reading timestamp for staleness tracking
  DateTime? _lastReadingTime;
  DateTime? get lastReadingTime => _lastReadingTime;

  bool get isDataStale {
    if (_lastReadingTime == null) return true;
    return DateTime.now().difference(_lastReadingTime!).inSeconds >= 5;
  }

  int get dataAgeSeconds {
    if (_lastReadingTime == null) return 0;
    return DateTime.now().difference(_lastReadingTime!).inSeconds;
  }

  BluetoothService get bluetoothService => _bluetoothService;
  VibrationService get vibrationService => _vibrationService;
  SoundMonitorService get soundMonitorService => _soundMonitorService;
  SoundMonitorService get soundMonitor => _soundMonitorService;

  Future<void> startSoundMonitoring() async {
    await _soundMonitorService.startMonitoring();
    notifyListeners();
  }

  Future<void> stopSoundMonitoring() async {
    await _soundMonitorService.stopMonitoring();
    if (_connectionState == DeviceBtState.connected) {
      _bluetoothService.sendSoundFeatures(0.0, 0.0);
    }
    notifyListeners();
  }

  MachineController() {
    _initListeners();
  }

  void _initListeners() {
    // Listen to incoming telemetry from Bluetooth stream
    _telemetrySub = _bluetoothService.telemetryStream.listen((data) {
      _telemetry = data;
      _lastReadingTime = DateTime.now();

      // Maintain rolling 60-item history
      if (_history.length >= 60) {
        _history.removeAt(0);
      }
      _history.add(data);

      // Process alert rules & emergency state machine
      // Sound anomaly alerts are evaluated ONLY if phone microphone sound monitoring is ON
      final isNewCritical = _alertService.processTelemetry(
        data,
        isSoundMonitoringActive: _soundMonitorService.isMonitoring,
      );
      final isCriticalState = data.risk >= 70 || data.status == 'CRITICAL' || data.emergency;

      if (isNewCritical) {
        // Reset local overlay dismissal so overlay pops up for new critical event
        _isEmergencyOverlayAcknowledged = false;
        _vibrationService.handleCriticalStateChange(true);
      } else {
        _vibrationService.handleCriticalStateChange(isCriticalState);
      }

      notifyListeners();
    });

    // Listen to incoming config packets (config_data & config_ack)
    _configSub = _bluetoothService.configStream.listen((configJson) {
      final type = configJson['type']?.toString();
      if (type == 'config_data') {
        _activeConfig = DeviceConfiguration.fromJson(configJson);
        _draftConfig = _activeConfig;
        _isConfigSyncing = false;
        _configSyncStatus = 'SYNCHRONIZED';
        _configErrorMsg = '';
        notifyListeners();
      }
    });

    // Listen to connection state updates
    _stateSub = _bluetoothService.stateStream.listen((state) {
      _connectionState = state;
      _alertService.processBluetoothState(state);
      if (state == DeviceBtState.connected) {
        fetchDeviceConfig();
      } else {
        _vibrationService.reset();
        _configSyncStatus = 'DISCONNECTED';
      }
      notifyListeners();
    });

    // Listen to sound feature packets from SoundMonitorService and transmit over Bluetooth SPP
    _soundSub = _soundMonitorService.soundFeatureStream.listen((featurePacket) {
      if (_connectionState == DeviceBtState.connected) {
        _bluetoothService.sendSoundFeatures(
          featurePacket['level'] as double,
          featurePacket['peak'] as double,
        );
      }
    });

    // Timer to periodically check data staleness (every 1 second)
    _stalenessTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_connectionState == DeviceBtState.connected) {
        _alertService.checkStaleData(_lastReadingTime);
        notifyListeners();
      }
    });
  }

  /// Update draft configuration locally in Settings screen
  void updateDraftConfig(DeviceConfiguration updated) {
    _draftConfig = updated;
    _configSyncStatus = hasUnsavedConfigEdits ? 'MODIFIED' : 'SYNCHRONIZED';
    _configErrorMsg = '';
    notifyListeners();
  }

  /// Discard draft configuration changes and revert to last confirmed device settings
  void discardDraftConfig() {
    _draftConfig = _activeConfig;
    _configSyncStatus = 'SYNCHRONIZED';
    _configErrorMsg = '';
    notifyListeners();
  }

  /// Request active configuration from ESP32 over SPP
  Future<bool> fetchDeviceConfig() async {
    if (_connectionState != DeviceBtState.connected) {
      _configSyncStatus = 'DISCONNECTED';
      notifyListeners();
      return false;
    }

    _isConfigSyncing = true;
    _configSyncStatus = 'SYNCING';
    notifyListeners();

    final requestId = DateTime.now().millisecondsSinceEpoch.toString();
    bool sent = await _bluetoothService.sendConfigGet(requestId);
    if (!sent) {
      _isConfigSyncing = false;
      _configSyncStatus = 'SYNC FAILED';
      _configErrorMsg = 'Failed to transmit config_get request over Bluetooth.';
      notifyListeners();
    }
    return sent;
  }

  /// Transactional apply of draft configuration to ESP32 over SPP
  Future<bool> applyConfiguration() async {
    if (_connectionState != DeviceBtState.connected) {
      _configErrorMsg = 'Cannot apply rules: ESP32 is disconnected.';
      _configSyncStatus = 'DISCONNECTED';
      notifyListeners();
      return false;
    }

    final validationErrors = _draftConfig.validate();
    if (validationErrors.isNotEmpty) {
      _configErrorMsg = validationErrors.first;
      notifyListeners();
      return false;
    }

    _isConfigApplying = true;
    _configSyncStatus = 'APPLYING';
    _configErrorMsg = '';
    notifyListeners();

    final requestId = DateTime.now().millisecondsSinceEpoch.toString();
    final completer = Completer<bool>();

    late StreamSubscription sub;
    sub = _bluetoothService.configStream.listen((packet) {
      if (packet['type'] == 'config_ack' && packet['requestId'] == requestId) {
        sub.cancel();
        if (packet['status'] == 'applied') {
          _activeConfig = _draftConfig.copyWith(
            version: (packet['version'] as num?)?.toInt() ?? (_draftConfig.version + 1),
            lastSyncTime: DateTime.now(),
          );
          _draftConfig = _activeConfig;
          _isConfigApplying = false;
          _configSyncStatus = 'SYNCHRONIZED';
          _configErrorMsg = '';
          _commandFeedback = 'Configuration successfully applied to ESP32 firmware!';
          _commandSuccess = true;
          completer.complete(true);
        } else {
          _isConfigApplying = false;
          _configSyncStatus = 'REJECTED';
          _configErrorMsg = packet['reason']?.toString() ?? 'ESP32 firmware rejected configuration update.';
          _commandFeedback = 'Configuration rejected by ESP32: $_configErrorMsg';
          _commandSuccess = false;
          completer.complete(false);
        }
        notifyListeners();
      }
    });

    // Send payload
    bool sent = await _bluetoothService.sendConfigSet(_draftConfig.toJson(), requestId);
    if (!sent) {
      sub.cancel();
      _isConfigApplying = false;
      _configSyncStatus = 'FAILED';
      _configErrorMsg = 'Failed to send config_set payload over Bluetooth.';
      notifyListeners();
      return false;
    }

    // 4-second timeout guard
    Timer(const Duration(seconds: 4), () {
      if (!completer.isCompleted) {
        sub.cancel();
        _isConfigApplying = false;
        _configSyncStatus = 'TIMEOUT';
        _configErrorMsg = 'Configuration acknowledgement timed out after 4 seconds.';
        notifyListeners();
        completer.complete(false);
      }
    });

    return completer.future;
  }

  /// Connect to ESP32 Bluetooth Classic device
  Future<bool> connect([String? deviceAddress]) async {
    _commandFeedback = 'Attempting connection to ${BluetoothService.targetDeviceName}...';
    _commandSuccess = null;
    notifyListeners();

    bool success = await _bluetoothService.connect(deviceAddress);
    if (success) {
      _commandFeedback = 'Connected successfully to ${BluetoothService.targetDeviceName}';
      _commandSuccess = true;
    } else {
      _commandFeedback = _bluetoothService.lastErrorMsg;
      _commandSuccess = false;
    }
    notifyListeners();
    return success;
  }

  /// Disconnect from ESP32
  Future<void> disconnect() async {
    await _bluetoothService.disconnect();
    _commandFeedback = 'Disconnected from Bluetooth device.';
    _commandSuccess = null;
    _vibrationService.reset();
    _configSyncStatus = 'DISCONNECTED';
    notifyListeners();
  }

  /// Send a single-byte command (`T`, `D`, `L`, `S`, `C`, `O`, `R`) over SPP
  Future<bool> sendCommand(String charCode, String commandLabel) async {
    if (_connectionState != DeviceBtState.connected) {
      _commandFeedback = 'Cannot send command: Bluetooth disconnected.';
      _commandSuccess = false;
      notifyListeners();
      return false;
    }

    _isCommandPending = true;
    _commandFeedback = 'Transmitting command "$charCode" ($commandLabel)...';
    _commandSuccess = null;
    notifyListeners();

    bool sent = await _bluetoothService.sendCommand(charCode);
    _isCommandPending = false;

    if (sent) {
      _commandFeedback = 'Command "$commandLabel" ($charCode) sent to ESP32. Awaiting telemetry update for state confirmation.';
      _commandSuccess = true;
      if (charCode.toUpperCase() == 'R') {
        _alertService.clearEmergencyLatched();
        _isEmergencyOverlayAcknowledged = true;
      }
    } else {
      _commandFeedback = 'Failed to transmit command "$commandLabel": ${_bluetoothService.lastErrorMsg}';
      _commandSuccess = false;
    }

    notifyListeners();
    return sent;
  }

  /// Send Acoustic Sound Fault Injection command (`S`)
  Future<bool> triggerSoundFault() async {
    _soundMonitorService.injectSimulatedSoundLevel(0.92);
    return await sendCommand('S', 'ABNORMAL SOUND FAULT');
  }

  /// Send Safety Override command (`O`)
  Future<bool> requestSafetyOverride() async {
    return await sendCommand('O', 'SAFETY OVERRIDE REQUEST');
  }

  /// Send System Reset command (`R`)
  Future<bool> requestSystemReset() async {
    return await sendCommand('R', 'SYSTEM RESET REQUEST');
  }

  /// Visually acknowledge the emergency stop overlay view without clearing hardware interlocks
  void acknowledgeEmergencyOverlay() {
    _isEmergencyOverlayAcknowledged = true;
    notifyListeners();
  }

  /// Acknowledge an alert item
  void acknowledgeAlert(String alertId) {
    _alertService.acknowledgeAlert(alertId);
    notifyListeners();
  }

  /// Clear command status message bar
  void clearCommandFeedback() {
    _commandFeedback = '';
    _commandSuccess = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _telemetrySub?.cancel();
    _stateSub?.cancel();
    _soundSub?.cancel();
    _configSub?.cancel();
    _stalenessTimer?.cancel();
    _bluetoothService.dispose();
    _soundMonitorService.dispose();
    super.dispose();
  }
}

