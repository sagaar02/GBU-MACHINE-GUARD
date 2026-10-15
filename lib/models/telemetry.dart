class TelemetryData {
  final int risk; // 0 - 100
  final String status; // SAFE, MODERATE, CRITICAL
  final String cause;
  final double temp;
  final double hum;
  final int vibration; // 0 = Clear, 1 = Detected (SW-420 Sensor)
  final int vibrationCount; // Pulse rate / count (pulses/sec)
  final int water; // ADC reading (0 - 4095)
  final double soundLevel; // Relative normalized sound level 0.0 .. 1.0 from microphone
  final bool emergency; // Latched emergency state on ESP32
  final DateTime timestamp;
  final bool isValid;

  const TelemetryData({
    required this.risk,
    required this.status,
    required this.cause,
    required this.temp,
    required this.hum,
    required this.vibration,
    this.vibrationCount = 0,
    required this.water,
    required this.soundLevel,
    required this.emergency,
    required this.timestamp,
    this.isValid = true,
  });

  /// Factory constructor for initial unavailable state before ESP32 telemetry arrives.
  factory TelemetryData.initial() {
    return TelemetryData(
      risk: 0,
      status: 'SAFE',
      cause: 'Awaiting ESP32 connection...',
      temp: 0.0,
      hum: 0.0,
      vibration: 0,
      vibrationCount: 0,
      water: 0,
      soundLevel: 0.0,
      emergency: false,
      timestamp: DateTime.now(),
      isValid: false,
    );
  }

  /// Safely parses newline-delimited JSON transmitted by ESP32:
  /// `{"temp":38.5,"hum":62.0,"vibration":1,"vibrationCount":12,"water":1200,"soundLevel":0.72,"risk":85,"status":"CRITICAL","cause":"ABNORMAL SOUND","emergency":true}`
  factory TelemetryData.fromJson(Map<String, dynamic> json) {
    final rawRisk = json['risk'];
    int parsedRisk = 0;
    if (rawRisk is num) {
      parsedRisk = rawRisk.toInt();
    } else if (rawRisk is String) {
      parsedRisk = int.tryParse(rawRisk) ?? 0;
    }
    // Clamp risk score to 0..100
    parsedRisk = parsedRisk.clamp(0, 100);

    final rawStatus = json['status']?.toString() ?? 'SAFE';
    final parsedStatus = rawStatus.trim().toUpperCase();
    final parsedCause = json['cause']?.toString() ?? 'Normal Operation';

    final rawTemp = json['temp'];
    double parsedTemp = 0.0;
    if (rawTemp is num) {
      parsedTemp = rawTemp.toDouble();
    } else if (rawTemp is String) {
      parsedTemp = double.tryParse(rawTemp) ?? 0.0;
    }

    final rawHum = json['hum'] ?? json['humidity'];
    double parsedHum = 0.0;
    if (rawHum is num) {
      parsedHum = rawHum.toDouble();
    } else if (rawHum is String) {
      parsedHum = double.tryParse(rawHum) ?? 0.0;
    }

    final rawVibration = json['vibration'];
    int parsedVibration = 0;
    if (rawVibration is num) {
      parsedVibration = rawVibration.toInt();
    } else if (rawVibration is String) {
      parsedVibration = int.tryParse(rawVibration) ?? 0;
    }

    final rawVibCount = json['vibrationCount'] ?? json['vibration_count'] ?? json['vibCount'];
    int parsedVibCount = 0;
    if (rawVibCount is num) {
      parsedVibCount = rawVibCount.toInt();
    } else if (rawVibCount is String) {
      parsedVibCount = int.tryParse(rawVibCount) ?? 0;
    }

    final rawWater = json['water'];
    int parsedWater = 0;
    if (rawWater is num) {
      parsedWater = rawWater.toInt();
    } else if (rawWater is String) {
      parsedWater = int.tryParse(rawWater) ?? 0;
    }

    final rawSound = json['soundLevel'] ?? json['sound_level'] ?? json['sound'];
    double parsedSound = 0.0;
    if (rawSound is num) {
      parsedSound = rawSound.toDouble();
    } else if (rawSound is String) {
      parsedSound = double.tryParse(rawSound) ?? 0.0;
    }
    parsedSound = parsedSound.clamp(0.0, 1.0);

    final rawEmergency = json['emergency'];
    bool parsedEmergency = false;
    if (rawEmergency is bool) {
      parsedEmergency = rawEmergency;
    } else if (rawEmergency is num) {
      parsedEmergency = rawEmergency.toInt() == 1;
    } else if (rawEmergency is String) {
      parsedEmergency = rawEmergency.toLowerCase() == 'true' || rawEmergency == '1';
    }

    return TelemetryData(
      risk: parsedRisk,
      status: parsedStatus,
      cause: parsedCause,
      temp: parsedTemp,
      hum: parsedHum,
      vibration: parsedVibration,
      vibrationCount: parsedVibCount,
      water: parsedWater,
      soundLevel: parsedSound,
      emergency: parsedEmergency,
      timestamp: DateTime.now(),
      isValid: true,
    );
  }

  /// Check vibration status. `vibration == 1` means SW-420 sensor module triggered.
  bool get isVibrationDetected => vibration == 1;

  /// Check water seepage status.
  bool get isWaterLeak => water >= 1000;

  /// Check sound anomaly status.
  bool get isAbnormalSound => soundLevel >= 0.80;

  Map<String, dynamic> toJson() {
    return {
      'type': 'telemetry',
      'temp': temp,
      'hum': hum,
      'vibration': vibration,
      'vibrationCount': vibrationCount,
      'water': water,
      'soundLevel': soundLevel,
      'risk': risk,
      'status': status,
      'cause': cause,
      'emergency': emergency,
      'timestamp': timestamp.toIso8601String(),
    };
  }
}

