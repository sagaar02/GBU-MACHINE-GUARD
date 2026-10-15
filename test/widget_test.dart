import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gbu/models/telemetry.dart';
import 'package:gbu/models/device_config.dart';
import 'package:gbu/services/alert_service.dart';
import 'package:gbu/services/vibration_service.dart';
import 'package:gbu/services/sound_monitor_service.dart';
import 'package:gbu/controllers/machine_controller.dart';
import 'package:gbu/screens/dashboard_screen.dart';

void main() {
  group('DeviceConfiguration & Rule Validation', () {
    test('Constructs initial default configuration with valid defaults', () {
      final config = DeviceConfiguration.initial();
      expect(config.version, equals(1));
      expect(config.tempRules.tempWarning, equals(35.0));
      expect(config.tempRules.tempCritical, equals(45.0));
      expect(config.vibRules.vibActiveState, equals(1));
      expect(config.waterRules.waterWarning, equals(100));
      expect(config.waterRules.waterCritical, equals(1000));
      expect(config.soundRules.soundWarning, equals(0.50));
      expect(config.soundRules.soundCritical, equals(0.80));
      expect(config.riskRules.riskWarning, equals(35));
      expect(config.riskRules.riskCritical, equals(70));
      expect(config.isValid, isTrue);
    });

    test('Serializes to JSON and deserializes correctly', () {
      final original = DeviceConfiguration.initial().copyWith(
        version: 3,
        tempRules: const TemperatureRules(tempWarning: 40.0, tempCritical: 55.0),
        waterRules: const WaterRules(waterWarning: 200, waterCritical: 1500),
      );

      final jsonMap = original.toJson();
      final deserialized = DeviceConfiguration.fromJson(jsonMap);

      expect(deserialized.version, equals(3));
      expect(deserialized.tempRules.tempWarning, equals(40.0));
      expect(deserialized.tempRules.tempCritical, equals(55.0));
      expect(deserialized.waterRules.waterWarning, equals(200));
      expect(deserialized.waterRules.waterCritical, equals(1500));
      expect(deserialized.isValid, isTrue);
    });

    test('Validates threshold ordering rules and flags invalid configurations', () {
      final invalidTemp = DeviceConfiguration.initial().copyWith(
        tempRules: const TemperatureRules(tempWarning: 50.0, tempCritical: 40.0), // Invalid ordering
      );
      final tempErrors = invalidTemp.validate();
      expect(tempErrors.isNotEmpty, isTrue);
      expect(tempErrors.first, contains('must be greater than warning threshold'));

      final invalidWater = DeviceConfiguration.initial().copyWith(
        waterRules: const WaterRules(waterWarning: 1200, waterCritical: 500),
      );
      expect(invalidWater.validate().isNotEmpty, isTrue);

      final invalidRisk = DeviceConfiguration.initial().copyWith(
        riskRules: const RiskRules(riskWarning: 80, riskCritical: 60),
      );
      expect(invalidRisk.validate().isNotEmpty, isTrue);

      final overBuzzerDur = const RiskRules(buzzerDurationMs: 8000);
      expect(overBuzzerDur.buzzerDurationMs, equals(5000));

      final invalidBuzzerDur = DeviceConfiguration.initial().copyWith(
        riskRules: const RiskRules(buzzerDurationMs: 200),
      );
      expect(invalidBuzzerDur.validate().isNotEmpty, isTrue);
      expect(invalidBuzzerDur.validate().first, contains('Buzzer duration must be between 500ms and 5000ms'));
    });
  });

  group('Telemetry Parsing & Validation', () {
    test('Parses valid ESP32 JSON payload with soundLevel and emergency state', () {
      final jsonMap = {
        "temp": 38.5,
        "hum": 62.0,
        "vibration": 1,
        "water": 1200,
        "soundLevel": 0.85,
        "risk": 85,
        "status": "CRITICAL",
        "cause": "ABNORMAL SOUND",
        "emergency": true
      };

      final data = TelemetryData.fromJson(jsonMap);

      expect(data.temp, equals(38.5));
      expect(data.hum, equals(62.0));
      expect(data.vibration, equals(1));
      expect(data.water, equals(1200));
      expect(data.soundLevel, equals(0.85));
      expect(data.risk, equals(85));
      expect(data.status, equals('CRITICAL'));
      expect(data.cause, equals('ABNORMAL SOUND'));
      expect(data.emergency, isTrue);
      expect(data.isVibrationDetected, isTrue);
      expect(data.isWaterLeak, isTrue);
      expect(data.isAbnormalSound, isTrue);
    });

    test('Clamps risk value within 0 to 100 range', () {
      final jsonOver = {"risk": 150, "temp": 20.0};
      final dataOver = TelemetryData.fromJson(jsonOver);
      expect(dataOver.risk, equals(100));

      final jsonUnder = {"risk": -20, "temp": 20.0};
      final dataUnder = TelemetryData.fromJson(jsonUnder);
      expect(dataUnder.risk, equals(0));
    });

    test('Handles malformed types gracefully without throwing exceptions', () {
      final jsonBadTypes = {
        "risk": "75",
        "temp": "42.1",
        "hum": "55.4",
        "vibration": "1",
        "water": "1200",
        "soundLevel": "0.75",
        "emergency": "true"
      };

      final data = TelemetryData.fromJson(jsonBadTypes);
      expect(data.risk, equals(75));
      expect(data.temp, equals(42.1));
      expect(data.hum, equals(55.4));
      expect(data.vibration, equals(1));
      expect(data.water, equals(1200));
      expect(data.soundLevel, equals(0.75));
      expect(data.emergency, isTrue);
    });
  });

  group('Emergency State Machine & Latched Alerts', () {
    test('Transitions from SAFE to CRITICAL and latches emergency state', () {
      final alertService = AlertService();

      final nominalData = TelemetryData.fromJson({"risk": 20, "status": "SAFE"});
      alertService.processTelemetry(nominalData);
      expect(alertService.emergencyState, equals(EmergencyState.normal));
      expect(alertService.alerts.length, equals(0));

      final criticalData = TelemetryData.fromJson({
        "risk": 85,
        "status": "CRITICAL",
        "cause": "EXCESSIVE VIBRATION",
        "emergency": true,
      });
      final isNewCritical = alertService.processTelemetry(criticalData);
      expect(isNewCritical, isTrue);
      expect(alertService.emergencyState, equals(EmergencyState.emergencyLatched));
      expect(alertService.alerts.length, equals(1));
    });

    test('Recovery of physical sensors does NOT silently clear latched emergency', () {
      final alertService = AlertService();

      // Enter critical state
      final criticalData = TelemetryData.fromJson({
        "risk": 90,
        "status": "CRITICAL",
        "cause": "WATER LEAK",
        "emergency": true,
      });
      alertService.processTelemetry(criticalData);
      expect(alertService.isEmergencyActive, isTrue);

      // Sensors return to safe levels, but hardware stays emergency=true
      final recoveredData = TelemetryData.fromJson({
        "risk": 15,
        "status": "SAFE",
        "cause": "Normal Operation",
        "emergency": true,
      });
      final isNewCrit = alertService.processTelemetry(recoveredData);

      // Deduplication check: repeated packets do not trigger new critical vibration
      expect(isNewCrit, isFalse);
      // Emergency state MUST remain latched until explicitly reset!
      expect(alertService.isEmergencyActive, isTrue);
    });

    test('Reset validation prevents reset while critical conditions persist', () {
      final alertService = AlertService();

      final criticalData = TelemetryData.fromJson({
        "risk": 85,
        "status": "CRITICAL",
        "cause": "HIGH TEMPERATURE",
        "emergency": true,
      });
      alertService.processTelemetry(criticalData);

      // Attempt reset while still in critical state
      final resetAllowed = alertService.canResetEmergency();
      expect(resetAllowed, isFalse);
    });
  });

  group('Sound Monitor Service & State Machine', () {
    test('Initializes in IDLE state with clear sound level, display --, and OFF status', () {
      final soundService = SoundMonitorService();
      expect(soundService.state, equals(SoundMonitorState.idle));
      expect(soundService.isMonitoring, isFalse);
      expect(soundService.currentLevel, equals(0.0));
      expect(soundService.currentPeak, equals(0.0));
      expect(soundService.displayLevel, equals('--'));
      expect(soundService.displayPeak, equals('--'));
      expect(soundService.statusBadgeText, equals('OFF'));
      expect(soundService.statusMessage, equals('Sound Monitoring Disabled'));
      soundService.dispose();
    });

    test('Injecting simulated sound while microphone is OFF is blocked and does not update sound level', () async {
      final soundService = SoundMonitorService();
      Map<String, dynamic>? receivedPacket;

      soundService.soundFeatureStream.listen((packet) {
        receivedPacket = packet;
      });

      // Sound monitoring is OFF (idle)
      expect(soundService.isMonitoring, isFalse);
      soundService.injectSimulatedSoundLevel(0.95);
      await Future.microtask(() {});

      // Sound level MUST stay 0.0 and display --
      expect(soundService.currentLevel, equals(0.0));
      expect(soundService.currentPeak, equals(0.0));
      expect(soundService.displayLevel, equals('--'));
      expect(receivedPacket, isNull);

      soundService.dispose();
    });

    test('Stop monitoring is idempotent, releases resources, and displays Sound Monitoring Disabled', () async {
      final soundService = SoundMonitorService();

      await soundService.stopMonitoring();
      expect(soundService.state, equals(SoundMonitorState.idle));
      expect(soundService.isMonitoring, isFalse);
      expect(soundService.currentLevel, equals(0.0));
      expect(soundService.currentPeak, equals(0.0));
      expect(soundService.displayLevel, equals('--'));
      expect(soundService.statusBadgeText, equals('OFF'));
      expect(soundService.statusMessage, equals('Sound Monitoring Disabled'));

      // Calling stop a second time should not throw or change state
      await soundService.stopMonitoring();
      expect(soundService.state, equals(SoundMonitorState.idle));
      soundService.dispose();
    });
  });

  group('Microphone OFF Alert Suppression & Independent Sensor Isolation', () {
    test('No sound alerts occur while sound monitoring is OFF, even with high sound telemetry', () {
      final alertService = AlertService();

      final highSoundTelemetry = TelemetryData.fromJson({
        "risk": 20,
        "status": "SAFE",
        "cause": "Normal Operation",
        "soundLevel": 0.95,
        "temp": 25.0,
        "hum": 50.0,
        "vibration": 0,
        "water": 50,
      });

      // Process telemetry with sound monitoring OFF
      final isNewCritical = alertService.processTelemetry(
        highSoundTelemetry,
        isSoundMonitoringActive: false,
      );

      expect(isNewCritical, isFalse);
      // Ensure NO sound alerts were created
      final soundAlerts = alertService.alerts.where((a) => a.id.startsWith('SOUND_')).toList();
      expect(soundAlerts.isEmpty, isTrue);
      expect(alertService.alerts.length, equals(0));
    });

    test('Sound alert triggers when microphone is ON, but stops triggering after microphone is turned OFF', () {
      final alertService = AlertService();

      final highSoundTelemetry = TelemetryData.fromJson({
        "risk": 80,
        "status": "CRITICAL",
        "cause": "ABNORMAL SOUND",
        "soundLevel": 0.90,
        "temp": 25.0,
        "vibration": 0,
        "water": 50,
      });

      // 1. When microphone is ON: Sound alert should trigger
      final isCritWithMicOn = alertService.processTelemetry(
        highSoundTelemetry,
        isSoundMonitoringActive: true,
      );
      expect(isCritWithMicOn, isTrue);
      final soundAlerts = alertService.alerts.where((a) => a.id.startsWith('SOUND_')).toList();
      expect(soundAlerts.length, equals(1));
      expect(alertService.isEmergencyActive, isTrue);

      // 2. Microphone turned OFF: Subsequent telemetry must not trigger any new sound alerts
      final subsequentTelemetry = TelemetryData.fromJson({
        "risk": 25,
        "status": "SAFE",
        "cause": "Normal Operation",
        "soundLevel": 0.95,
        "temp": 25.0,
        "vibration": 0,
        "water": 50,
      });

      final isCritWithMicOff = alertService.processTelemetry(
        subsequentTelemetry,
        isSoundMonitoringActive: false,
      );
      expect(isCritWithMicOff, isFalse);
      final soundAlertsAfter = alertService.alerts.where((a) => a.id.startsWith('SOUND_')).toList();
      expect(soundAlertsAfter.length, equals(1)); // Still only 1, no new sound alerts!

      // Latched machine emergency must remain latched independently!
      expect(alertService.isEmergencyActive, isTrue);
    });

    test('Turning microphone OFF does not disable other sensors (temp, vibration, water)', () {
      final alertService = AlertService();

      // High temperature event with microphone OFF
      final highTempTelemetry = TelemetryData.fromJson({
        "risk": 85,
        "status": "CRITICAL",
        "cause": "HIGH TEMPERATURE",
        "temp": 48.0,
        "soundLevel": 0.0,
        "vibration": 0,
        "water": 50,
      });

      final isCritTemp = alertService.processTelemetry(
        highTempTelemetry,
        isSoundMonitoringActive: false,
      );

      expect(isCritTemp, isTrue);
      final tempAlerts = alertService.alerts.where((a) => a.id.startsWith('TEMP_')).toList();
      expect(tempAlerts.length, equals(1));
      expect(alertService.isEmergencyActive, isTrue);

      // Vibration event with microphone OFF
      final vibTelemetry = TelemetryData.fromJson({
        "risk": 60,
        "status": "MODERATE",
        "cause": "EXCESSIVE VIBRATION",
        "temp": 25.0,
        "vibration": 1,
        "water": 50,
      });

      alertService.processTelemetry(
        vibTelemetry,
        isSoundMonitoringActive: false,
      );

      final vibAlerts = alertService.alerts.where((a) => a.id.startsWith('VIB_')).toList();
      expect(vibAlerts.length, equals(1));
    });
  });

  group('Vibration Service Deduplication Logic', () {
    test('Deduplicates repeated critical states', () async {
      final vibrationService = VibrationService();

      expect(vibrationService.isCriticalActive, isFalse);

      // Transition to critical
      await vibrationService.handleCriticalStateChange(true);
      expect(vibrationService.isCriticalActive, isTrue);

      // Second identical critical call - stays active without re-triggering state transition
      await vibrationService.handleCriticalStateChange(true);
      expect(vibrationService.isCriticalActive, isTrue);

      // Recovery to safe
      await vibrationService.handleCriticalStateChange(false);
      expect(vibrationService.isCriticalActive, isFalse);

      // Subsequent critical call after recovery
      await vibrationService.handleCriticalStateChange(true);
      expect(vibrationService.isCriticalActive, isTrue);
    });
  });

  testWidgets('Renders GbuApp with header title', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final controller = MachineController();
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: DashboardScreen(controller: controller),
      ),
    ));
    await tester.pump();
    expect(find.text('GBU'), findsOneWidget);
    expect(find.text('PREDICTIVE MAINTENANCE'), findsOneWidget);
    controller.dispose();
  });
}



