import '../models/telemetry.dart';
import '../models/machine_alert.dart';
import 'bluetooth_service.dart';

enum EmergencyState {
  normal,
  warning,
  critical,
  emergencyLatched,
  resetPending,
}

class AlertService {
  final List<MachineAlert> _alerts = [];
  List<MachineAlert> get alerts => List.unmodifiable(_alerts);

  EmergencyState _currentState = EmergencyState.normal;
  EmergencyState get currentState => _currentState;
  EmergencyState get emergencyState => _currentState;

  bool get isEmergencyActive =>
      _currentState == EmergencyState.emergencyLatched ||
      _currentState == EmergencyState.resetPending;

  bool canResetEmergency() => _previousRiskCategory < 2;

  // Track previous states for event deduplication
  int _previousRiskCategory = 0; // 0: SAFE, 1: MODERATE, 2: CRITICAL
  bool _previousWaterLeak = false;
  bool _previousTempOverlimit = false;
  bool _previousVibrationAlert = false;
  bool _previousSoundAlert = false;
  bool _previousBtDisconnected = true;
  bool _previousStale = false;

  // Threshold configurations
  static const double tempSafetyLimit = 45.0; // °C
  static const int waterLeakAdcThreshold = 1000; // ADC reading
  static const double soundAbnormalThreshold = 0.80; // 80% sound level

  /// Process telemetry data.
  /// Returns `true` ONLY if a NEW critical event transition occurred.
  bool processTelemetry(TelemetryData telemetry, {bool isSoundMonitoringActive = true}) {
    if (!telemetry.isValid) return false;

    final now = DateTime.now();
    bool newCriticalEvent = false;

    // Determine current risk category
    int currentRiskCategory = 0;
    if (telemetry.risk >= 70 || telemetry.status == 'CRITICAL' || telemetry.emergency) {
      currentRiskCategory = 2; // Critical
    } else if (telemetry.risk >= 35 || telemetry.status == 'MODERATE' || telemetry.status == 'WARNING') {
      currentRiskCategory = 1; // Moderate / Warning
    }

    // State Machine Transitions
    if (currentRiskCategory == 2) {
      if (_currentState != EmergencyState.critical && _currentState != EmergencyState.emergencyLatched) {
        newCriticalEvent = true;
        _currentState = EmergencyState.emergencyLatched;
        _addAlert(MachineAlert(
          id: 'CRIT_${now.millisecondsSinceEpoch}',
          severity: AlertSeverity.critical,
          title: 'EMERGENCY TRIP THRESHOLD BREACHED',
          cause: telemetry.cause.isNotEmpty && telemetry.cause != 'Normal Operation'
              ? telemetry.cause
              : 'Overall risk score reached ${telemetry.risk}%',
          recommendation: 'Halt machine operation immediately. Inspect physical assembly and clear hazard before reset.',
          riskScore: telemetry.risk,
          timestamp: now,
        ));
      } else {
        _currentState = EmergencyState.emergencyLatched;
      }
    } else if (currentRiskCategory == 1) {
      if (_currentState == EmergencyState.emergencyLatched || _currentState == EmergencyState.resetPending) {
        _currentState = EmergencyState.resetPending;
      } else {
        _currentState = EmergencyState.warning;
        if (_previousRiskCategory != 1) {
          _addAlert(MachineAlert(
            id: 'WARN_${now.millisecondsSinceEpoch}',
            severity: AlertSeverity.warning,
            title: 'MODERATE PREDICTIVE WARNING',
            cause: telemetry.cause.isNotEmpty && telemetry.cause != 'Normal Operation'
              ? telemetry.cause
              : 'Elevated machine risk level (${telemetry.risk}%)',
            recommendation: 'Monitor machine telemetry closely. Schedule preventive maintenance.',
            riskScore: telemetry.risk,
            timestamp: now,
          ));
        }
      }
    } else { // Category 0 (SAFE)
      if (_currentState == EmergencyState.emergencyLatched || _currentState == EmergencyState.resetPending) {
        _currentState = EmergencyState.resetPending; // Emergency remains latched until reset
      } else {
        _currentState = EmergencyState.normal;
      }
    }

    _previousRiskCategory = currentRiskCategory;

    // High Temperature Alert Transition
    bool isTempHigh = telemetry.temp >= tempSafetyLimit;
    if (isTempHigh && !_previousTempOverlimit) {
      newCriticalEvent = true;
      _addAlert(MachineAlert(
        id: 'TEMP_${now.millisecondsSinceEpoch}',
        severity: AlertSeverity.critical,
        title: 'High Temperature Threshold Breached',
        cause: 'Temperature registered ${telemetry.temp.toStringAsFixed(1)}°C (Limit: $tempSafetyLimit°C)',
        recommendation: 'Inspect cooling system, bearing friction, and thermal dissipation.',
        riskScore: telemetry.risk,
        timestamp: now,
      ));
    }
    _previousTempOverlimit = isTempHigh;

    // SW-420 Vibration Event Transition
    bool isVibActive = telemetry.isVibrationDetected;
    if (isVibActive && !_previousVibrationAlert) {
      _addAlert(MachineAlert(
        id: 'VIB_${now.millisecondsSinceEpoch}',
        severity: AlertSeverity.warning,
        title: 'Excessive Vibration Detected',
        cause: 'SW-420 digital sensor triggered vibration alert (DO == 1)',
        recommendation: 'Inspect shaft alignment, bearing play, and dampening mounts.',
        riskScore: telemetry.risk,
        timestamp: now,
      ));
    }
    _previousVibrationAlert = isVibActive;

    // Water Leak Transition
    bool isWaterLeak = telemetry.water >= waterLeakAdcThreshold;
    if (isWaterLeak && !_previousWaterLeak) {
      newCriticalEvent = true;
      _addAlert(MachineAlert(
        id: 'LEAK_${now.millisecondsSinceEpoch}',
        severity: AlertSeverity.critical,
        title: 'Water Leak Seepage Detected',
        cause: 'Water sensor ADC reading at ${telemetry.water} (Threshold: $waterLeakAdcThreshold)',
        recommendation: 'Isolate fluid channels, inspect seals and hydraulic pipe joints immediately.',
        riskScore: telemetry.risk,
        timestamp: now,
      ));
    }
    _previousWaterLeak = isWaterLeak;

    // Acoustic Sound Anomaly Transition (evaluated ONLY if phone sound monitoring is active)
    bool isSoundAnomaly = isSoundMonitoringActive && (telemetry.soundLevel >= soundAbnormalThreshold);
    if (isSoundAnomaly && !_previousSoundAlert) {
      newCriticalEvent = true;
      _addAlert(MachineAlert(
        id: 'SOUND_${now.millisecondsSinceEpoch}',
        severity: AlertSeverity.critical,
        title: 'Abnormal Machinery Acoustic Pattern',
        cause: 'Microphone sound monitoring level at ${(telemetry.soundLevel * 100).toInt()}% (Limit: 80%)',
        recommendation: 'Inspect motor gear mesh, bearing squeal, and acoustic resonance.',
        riskScore: telemetry.risk,
        timestamp: now,
      ));
    }
    _previousSoundAlert = isSoundAnomaly;

    return newCriticalEvent;
  }

  void processBluetoothState(DeviceBtState state) {
    bool isDisconnected = (state == DeviceBtState.disconnected || state == DeviceBtState.error);
    if (isDisconnected && !_previousBtDisconnected) {
      final now = DateTime.now();
      _addAlert(MachineAlert(
        id: 'BT_DISC_${now.millisecondsSinceEpoch}',
        severity: AlertSeverity.warning,
        title: 'Bluetooth Stream Disconnected',
        cause: 'Loss of Bluetooth SPP connection to EdgeAI_Predictive_Node',
        recommendation: 'Check ESP32 power, Bluetooth pairing, and proximity. Emergency latch remains active.',
        riskScore: null,
        timestamp: now,
      ));
    }
    _previousBtDisconnected = isDisconnected;
  }

  void checkStaleData(DateTime? lastReadingTime) {
    if (lastReadingTime == null) return;
    final age = DateTime.now().difference(lastReadingTime);
    bool isStale = age.inSeconds >= 5;

    if (isStale && !_previousStale) {
      final now = DateTime.now();
      _addAlert(MachineAlert(
        id: 'STALE_${now.millisecondsSinceEpoch}',
        severity: AlertSeverity.warning,
        title: 'Telemetry Stream Stale',
        cause: 'No valid JSON packet received for ${age.inSeconds} seconds',
        recommendation: 'Verify ESP32 firmware transmission frequency and Bluetooth link latency.',
        riskScore: null,
        timestamp: now,
      ));
    }
    _previousStale = isStale;
  }

  /// Manually clear emergency state after reset is verified on ESP32.
  void clearEmergencyLatched() {
    _currentState = EmergencyState.normal;
  }

  void acknowledgeAlert(String alertId) {
    int index = _alerts.indexWhere((a) => a.id == alertId);
    if (index != -1) {
      _alerts[index] = _alerts[index].copyWith(isAcknowledged: true);
    }
  }

  void acknowledgeAll() {
    for (int i = 0; i < _alerts.length; i++) {
      _alerts[i] = _alerts[i].copyWith(isAcknowledged: true);
    }
  }

  void clearAlerts() {
    _alerts.clear();
  }

  void _addAlert(MachineAlert alert) {
    if (_alerts.length >= 50) {
      _alerts.removeLast();
    }
    _alerts.insert(0, alert);
  }
}
