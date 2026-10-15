class TemperatureRules {
  final double tempWarning; // °C
  final double tempCritical; // °C

  const TemperatureRules({
    this.tempWarning = 35.0,
    this.tempCritical = 45.0,
  });

  factory TemperatureRules.fromJson(Map<String, dynamic> json) {
    return TemperatureRules(
      tempWarning: (json['tempWarning'] as num?)?.toDouble() ?? 35.0,
      tempCritical: (json['tempCritical'] as num?)?.toDouble() ?? 45.0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'tempWarning': tempWarning,
      'tempCritical': tempCritical,
    };
  }

  List<String> validate() {
    final errors = <String>[];
    if (tempWarning < 0 || tempWarning > 100) {
      errors.add('Temperature warning threshold must be between 0°C and 100°C.');
    }
    if (tempCritical < 0 || tempCritical > 120) {
      errors.add('Temperature critical threshold must be between 0°C and 120°C.');
    }
    if (tempCritical <= tempWarning) {
      errors.add('Critical temperature (${tempCritical.toStringAsFixed(1)}°C) must be greater than warning threshold (${tempWarning.toStringAsFixed(1)}°C).');
    }
    return errors;
  }

  TemperatureRules copyWith({
    double? tempWarning,
    double? tempCritical,
  }) {
    return TemperatureRules(
      tempWarning: tempWarning ?? this.tempWarning,
      tempCritical: tempCritical ?? this.tempCritical,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TemperatureRules &&
          runtimeType == other.runtimeType &&
          tempWarning == other.tempWarning &&
          tempCritical == other.tempCritical;

  @override
  int get hashCode => tempWarning.hashCode ^ tempCritical.hashCode;
}

class VibrationRules {
  final int vibActiveState; // 1 = Active HIGH, 0 = Active LOW
  final int vibDebounceMs; // milliseconds
  final int vibWarningCount; // count threshold
  final int vibCriticalCount; // count threshold

  const VibrationRules({
    this.vibActiveState = 1,
    this.vibDebounceMs = 20,
    this.vibWarningCount = 3,
    this.vibCriticalCount = 10,
  });

  factory VibrationRules.fromJson(Map<String, dynamic> json) {
    return VibrationRules(
      vibActiveState: (json['vibActiveState'] as num?)?.toInt() ?? 1,
      vibDebounceMs: (json['vibDebounceMs'] ?? json['vibDebounce'] as num?)?.toInt() ?? 20,
      vibWarningCount: (json['vibWarningCount'] as num?)?.toInt() ?? 3,
      vibCriticalCount: (json['vibCriticalCount'] as num?)?.toInt() ?? 10,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'vibActiveState': vibActiveState,
      'vibDebounceMs': vibDebounceMs,
      'vibWarningCount': vibWarningCount,
      'vibCriticalCount': vibCriticalCount,
    };
  }

  List<String> validate() {
    final errors = <String>[];
    if (vibActiveState != 0 && vibActiveState != 1) {
      errors.add('Vibration polarity must be 1 (Active HIGH) or 0 (Active LOW).');
    }
    if (vibDebounceMs < 0 || vibDebounceMs > 500) {
      errors.add('Vibration debounce interval must be between 0ms and 500ms.');
    }
    if (vibWarningCount < 1 || vibWarningCount > 100) {
      errors.add('Vibration warning count must be between 1 and 100.');
    }
    if (vibCriticalCount < 2 || vibCriticalCount > 200) {
      errors.add('Vibration critical count must be between 2 and 200.');
    }
    if (vibCriticalCount <= vibWarningCount) {
      errors.add('Vibration critical count ($vibCriticalCount) must be greater than warning count ($vibWarningCount).');
    }
    return errors;
  }

  VibrationRules copyWith({
    int? vibActiveState,
    int? vibDebounceMs,
    int? vibWarningCount,
    int? vibCriticalCount,
  }) {
    return VibrationRules(
      vibActiveState: vibActiveState ?? this.vibActiveState,
      vibDebounceMs: vibDebounceMs ?? this.vibDebounceMs,
      vibWarningCount: vibWarningCount ?? this.vibWarningCount,
      vibCriticalCount: vibCriticalCount ?? this.vibCriticalCount,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is VibrationRules &&
          runtimeType == other.runtimeType &&
          vibActiveState == other.vibActiveState &&
          vibDebounceMs == other.vibDebounceMs &&
          vibWarningCount == other.vibWarningCount &&
          vibCriticalCount == other.vibCriticalCount;

  @override
  int get hashCode =>
      vibActiveState.hashCode ^
      vibDebounceMs.hashCode ^
      vibWarningCount.hashCode ^
      vibCriticalCount.hashCode;
}

class WaterRules {
  final int waterWarning; // ADC raw value
  final int waterCritical; // ADC raw value

  const WaterRules({
    this.waterWarning = 100,
    this.waterCritical = 1000,
  });

  factory WaterRules.fromJson(Map<String, dynamic> json) {
    return WaterRules(
      waterWarning: (json['waterWarning'] as num?)?.toInt() ?? 100,
      waterCritical: (json['waterCritical'] as num?)?.toInt() ?? 1000,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'waterWarning': waterWarning,
      'waterCritical': waterCritical,
    };
  }

  List<String> validate() {
    final errors = <String>[];
    if (waterWarning < 0 || waterWarning > 4000) {
      errors.add('Water warning ADC threshold must be between 0 and 4000.');
    }
    if (waterCritical < 10 || waterCritical > 4095) {
      errors.add('Water critical ADC threshold must be between 10 and 4095.');
    }
    if (waterCritical <= waterWarning) {
      errors.add('Water critical threshold ($waterCritical ADC) must be greater than warning threshold ($waterWarning ADC).');
    }
    return errors;
  }

  WaterRules copyWith({
    int? waterWarning,
    int? waterCritical,
  }) {
    return WaterRules(
      waterWarning: waterWarning ?? this.waterWarning,
      waterCritical: waterCritical ?? this.waterCritical,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WaterRules &&
          runtimeType == other.runtimeType &&
          waterWarning == other.waterWarning &&
          waterCritical == other.waterCritical;

  @override
  int get hashCode => waterWarning.hashCode ^ waterCritical.hashCode;
}

class SoundRules {
  final bool soundEnabled;
  final double soundWarning; // 0.0 .. 1.0 normalized
  final double soundCritical; // 0.0 .. 1.0 normalized
  final int soundStaleTimeoutMs; // milliseconds

  const SoundRules({
    this.soundEnabled = true,
    this.soundWarning = 0.50,
    this.soundCritical = 0.80,
    this.soundStaleTimeoutMs = 3000,
  });

  factory SoundRules.fromJson(Map<String, dynamic> json) {
    return SoundRules(
      soundEnabled: (json['soundEnabled'] as bool?) ?? true,
      soundWarning: (json['soundWarning'] as num?)?.toDouble() ?? 0.50,
      soundCritical: (json['soundCritical'] as num?)?.toDouble() ?? 0.80,
      soundStaleTimeoutMs: (json['soundStaleTimeoutMs'] as num?)?.toInt() ?? 3000,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'soundEnabled': soundEnabled,
      'soundWarning': soundWarning,
      'soundCritical': soundCritical,
      'soundStaleTimeoutMs': soundStaleTimeoutMs,
    };
  }

  List<String> validate() {
    final errors = <String>[];
    if (soundWarning < 0.0 || soundWarning > 1.0) {
      errors.add('Sound warning threshold must be between 0.0 and 1.0.');
    }
    if (soundCritical < 0.0 || soundCritical > 1.0) {
      errors.add('Sound critical threshold must be between 0.0 and 1.0.');
    }
    if (soundCritical <= soundWarning) {
      errors.add('Sound critical threshold (${(soundCritical * 100).toInt()}%) must be greater than warning threshold (${(soundWarning * 100).toInt()}%).');
    }
    if (soundStaleTimeoutMs < 1000 || soundStaleTimeoutMs > 15000) {
      errors.add('Sound stale timeout must be between 1000ms and 15000ms.');
    }
    return errors;
  }

  SoundRules copyWith({
    bool? soundEnabled,
    double? soundWarning,
    double? soundCritical,
    int? soundStaleTimeoutMs,
  }) {
    return SoundRules(
      soundEnabled: soundEnabled ?? this.soundEnabled,
      soundWarning: soundWarning ?? this.soundWarning,
      soundCritical: soundCritical ?? this.soundCritical,
      soundStaleTimeoutMs: soundStaleTimeoutMs ?? this.soundStaleTimeoutMs,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SoundRules &&
          runtimeType == other.runtimeType &&
          soundEnabled == other.soundEnabled &&
          soundWarning == other.soundWarning &&
          soundCritical == other.soundCritical &&
          soundStaleTimeoutMs == other.soundStaleTimeoutMs;

  @override
  int get hashCode =>
      soundEnabled.hashCode ^
      soundWarning.hashCode ^
      soundCritical.hashCode ^
      soundStaleTimeoutMs.hashCode;
}

class RiskRules {
  final int riskWarning; // 0 .. 100
  final int riskCritical; // 0 .. 100
  final bool buzzerEnabled;
  final int buzzerDurationMs; // Max 5000ms
  final bool vibrationAlertEnabled;

  const RiskRules({
    this.riskWarning = 35,
    this.riskCritical = 70,
    this.buzzerEnabled = true,
    int buzzerDurationMs = 5000,
    this.vibrationAlertEnabled = true,
  }) : buzzerDurationMs = buzzerDurationMs > 5000 ? 5000 : buzzerDurationMs;

  factory RiskRules.fromJson(Map<String, dynamic> json) {
    int parsedDur = (json['buzzerDurationMs'] ?? json['buzzerDuration'] as num?)?.toInt() ?? 5000;
    if (parsedDur > 5000) parsedDur = 5000;
    return RiskRules(
      riskWarning: (json['riskWarning'] as num?)?.toInt() ?? 35,
      riskCritical: (json['riskCritical'] as num?)?.toInt() ?? 70,
      buzzerEnabled: (json['buzzerEnabled'] as bool?) ?? true,
      buzzerDurationMs: parsedDur,
      vibrationAlertEnabled: (json['vibrationAlertEnabled'] as bool?) ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'riskWarning': riskWarning,
      'riskCritical': riskCritical,
      'buzzerEnabled': buzzerEnabled,
      'buzzerDurationMs': buzzerDurationMs > 5000 ? 5000 : buzzerDurationMs,
      'vibrationAlertEnabled': vibrationAlertEnabled,
    };
  }

  List<String> validate() {
    final errors = <String>[];
    if (riskWarning < 0 || riskWarning > 90) {
      errors.add('Risk warning score threshold must be between 0 and 90.');
    }
    if (riskCritical < 10 || riskCritical > 100) {
      errors.add('Risk critical score threshold must be between 10 and 100.');
    }
    if (riskCritical <= riskWarning) {
      errors.add('Critical risk score ($riskCritical%) must be greater than warning risk score ($riskWarning%).');
    }
    if (buzzerDurationMs < 500 || buzzerDurationMs > 5000) {
      errors.add('Buzzer duration must be between 500ms and 5000ms (maximum 5 seconds).');
    }
    return errors;
  }

  RiskRules copyWith({
    int? riskWarning,
    int? riskCritical,
    bool? buzzerEnabled,
    int? buzzerDurationMs,
    bool? vibrationAlertEnabled,
  }) {
    return RiskRules(
      riskWarning: riskWarning ?? this.riskWarning,
      riskCritical: riskCritical ?? this.riskCritical,
      buzzerEnabled: buzzerEnabled ?? this.buzzerEnabled,
      buzzerDurationMs: (buzzerDurationMs != null && buzzerDurationMs > 5000)
          ? 5000
          : (buzzerDurationMs ?? this.buzzerDurationMs),
      vibrationAlertEnabled: vibrationAlertEnabled ?? this.vibrationAlertEnabled,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RiskRules &&
          runtimeType == other.runtimeType &&
          riskWarning == other.riskWarning &&
          riskCritical == other.riskCritical &&
          buzzerEnabled == other.buzzerEnabled &&
          buzzerDurationMs == other.buzzerDurationMs &&
          vibrationAlertEnabled == other.vibrationAlertEnabled;

  @override
  int get hashCode =>
      riskWarning.hashCode ^
      riskCritical.hashCode ^
      buzzerEnabled.hashCode ^
      buzzerDurationMs.hashCode ^
      vibrationAlertEnabled.hashCode;
}

class UiPreferences {
  final bool phoneVibrationEnabled;
  final bool visualPulseEnabled;
  final double animIntensity; // 0.0 .. 1.0

  const UiPreferences({
    this.phoneVibrationEnabled = true,
    this.visualPulseEnabled = true,
    this.animIntensity = 1.0,
  });

  factory UiPreferences.fromJson(Map<String, dynamic> json) {
    return UiPreferences(
      phoneVibrationEnabled: (json['phoneVibrationEnabled'] as bool?) ?? true,
      visualPulseEnabled: (json['visualPulseEnabled'] as bool?) ?? true,
      animIntensity: (json['animIntensity'] as num?)?.toDouble() ?? 1.0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'phoneVibrationEnabled': phoneVibrationEnabled,
      'visualPulseEnabled': visualPulseEnabled,
      'animIntensity': animIntensity,
    };
  }

  List<String> validate() {
    final errors = <String>[];
    if (animIntensity < 0.0 || animIntensity > 1.0) {
      errors.add('Animation intensity must be between 0.0 and 1.0.');
    }
    return errors;
  }

  UiPreferences copyWith({
    bool? phoneVibrationEnabled,
    bool? visualPulseEnabled,
    double? animIntensity,
  }) {
    return UiPreferences(
      phoneVibrationEnabled: phoneVibrationEnabled ?? this.phoneVibrationEnabled,
      visualPulseEnabled: visualPulseEnabled ?? this.visualPulseEnabled,
      animIntensity: animIntensity ?? this.animIntensity,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UiPreferences &&
          runtimeType == other.runtimeType &&
          phoneVibrationEnabled == other.phoneVibrationEnabled &&
          visualPulseEnabled == other.visualPulseEnabled &&
          animIntensity == other.animIntensity;

  @override
  int get hashCode =>
      phoneVibrationEnabled.hashCode ^
      visualPulseEnabled.hashCode ^
      animIntensity.hashCode;
}

class DeviceConfiguration {
  final int version;
  final DateTime? lastSyncTime;
  final TemperatureRules tempRules;
  final VibrationRules vibRules;
  final WaterRules waterRules;
  final SoundRules soundRules;
  final RiskRules riskRules;
  final UiPreferences uiPrefs;

  const DeviceConfiguration({
    this.version = 1,
    this.lastSyncTime,
    this.tempRules = const TemperatureRules(),
    this.vibRules = const VibrationRules(),
    this.waterRules = const WaterRules(),
    this.soundRules = const SoundRules(),
    this.riskRules = const RiskRules(),
    this.uiPrefs = const UiPreferences(),
  });

  factory DeviceConfiguration.initial() {
    return DeviceConfiguration(
      version: 1,
      lastSyncTime: null,
      tempRules: const TemperatureRules(),
      vibRules: const VibrationRules(),
      waterRules: const WaterRules(),
      soundRules: const SoundRules(),
      riskRules: const RiskRules(),
      uiPrefs: const UiPreferences(),
    );
  }

  factory DeviceConfiguration.fromJson(Map<String, dynamic> json) {
    final rawRules = json['rules'] as Map<String, dynamic>? ?? json;

    return DeviceConfiguration(
      version: (json['version'] as num?)?.toInt() ?? 1,
      lastSyncTime: json['lastSyncTime'] != null
          ? DateTime.tryParse(json['lastSyncTime'].toString())
          : DateTime.now(),
      tempRules: TemperatureRules.fromJson(rawRules),
      vibRules: VibrationRules.fromJson(rawRules),
      waterRules: WaterRules.fromJson(rawRules),
      soundRules: SoundRules.fromJson(rawRules),
      riskRules: RiskRules.fromJson(rawRules),
      uiPrefs: UiPreferences.fromJson(json['uiPrefs'] as Map<String, dynamic>? ?? {}),
    );
  }

  Map<String, dynamic> toJson() {
    final combinedRules = {
      ...tempRules.toJson(),
      ...vibRules.toJson(),
      ...waterRules.toJson(),
      ...soundRules.toJson(),
      ...riskRules.toJson(),
    };

    return {
      'type': 'config_set',
      'version': version,
      'lastSyncTime': lastSyncTime?.toIso8601String(),
      'rules': combinedRules,
      'uiPrefs': uiPrefs.toJson(),
    };
  }

  List<String> validate() {
    final errors = <String>[];
    errors.addAll(tempRules.validate());
    errors.addAll(vibRules.validate());
    errors.addAll(waterRules.validate());
    errors.addAll(soundRules.validate());
    errors.addAll(riskRules.validate());
    errors.addAll(uiPrefs.validate());
    return errors;
  }

  bool get isValid => validate().isEmpty;

  DeviceConfiguration copyWith({
    int? version,
    DateTime? lastSyncTime,
    TemperatureRules? tempRules,
    VibrationRules? vibRules,
    WaterRules? waterRules,
    SoundRules? soundRules,
    RiskRules? riskRules,
    UiPreferences? uiPrefs,
  }) {
    return DeviceConfiguration(
      version: version ?? this.version,
      lastSyncTime: lastSyncTime ?? this.lastSyncTime,
      tempRules: tempRules ?? this.tempRules,
      vibRules: vibRules ?? this.vibRules,
      waterRules: waterRules ?? this.waterRules,
      soundRules: soundRules ?? this.soundRules,
      riskRules: riskRules ?? this.riskRules,
      uiPrefs: uiPrefs ?? this.uiPrefs,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DeviceConfiguration &&
          runtimeType == other.runtimeType &&
          version == other.version &&
          tempRules == other.tempRules &&
          vibRules == other.vibRules &&
          waterRules == other.waterRules &&
          soundRules == other.soundRules &&
          riskRules == other.riskRules &&
          uiPrefs == other.uiPrefs;

  @override
  int get hashCode =>
      version.hashCode ^
      tempRules.hashCode ^
      vibRules.hashCode ^
      waterRules.hashCode ^
      soundRules.hashCode ^
      riskRules.hashCode ^
      uiPrefs.hashCode;
}
