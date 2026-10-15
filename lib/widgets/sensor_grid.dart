import 'package:flutter/material.dart';
import '../models/telemetry.dart';

class SensorGrid extends StatelessWidget {
  final TelemetryData telemetry;
  final bool isValid;
  final bool isSoundMonitoringActive;

  const SensorGrid({
    super.key,
    required this.telemetry,
    required this.isValid,
    this.isSoundMonitoringActive = true,
  });

  @override
  Widget build(BuildContext context) {
    final bool isTempCritical = isValid && telemetry.temp >= 45.0;
    final bool isTempWarning = isValid && telemetry.temp >= 35.0 && !isTempCritical;

    final bool isVibActive = isValid && telemetry.isVibrationDetected;

    final bool isWaterCritical = isValid && telemetry.water >= 1000;
    final bool isWaterWarning = isValid && telemetry.water >= 100 && !isWaterCritical;

    return LayoutBuilder(
      builder: (context, constraints) {
        final crossCount = constraints.maxWidth < 320 ? 1 : 2;
        final ratio = crossCount == 1 ? 2.6 : 1.45;

        final bool isSoundCritical = isValid && isSoundMonitoringActive && telemetry.soundLevel >= 0.80;
        final bool isSoundWarning = isValid && isSoundMonitoringActive && telemetry.soundLevel >= 0.50 && !isSoundCritical;

        return GridView.count(
          crossAxisCount: crossCount,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: ratio,
          children: [
            // 1. Temperature Card
            _SensorCard(
              title: 'Temperature',
              icon: Icons.thermostat_outlined,
              value: isValid ? '${telemetry.temp.toStringAsFixed(1)} °C' : '--',
              accentColor: !isValid
                  ? const Color(0xFF6E7280)
                  : (isTempCritical
                      ? const Color(0xFFFF3D00)
                      : (isTempWarning ? const Color(0xFFFFC107) : const Color(0xFF00E676))),
              isHighlighted: isTempCritical || isTempWarning,
            ),
            // 2. Humidity Card
            _SensorCard(
              title: 'Humidity (DHT11)',
              icon: Icons.water_outlined,
              value: isValid ? '${telemetry.hum.toStringAsFixed(1)} %' : '--',
              accentColor: !isValid ? const Color(0xFF6E7280) : const Color(0xFFFFC107),
              isHighlighted: false,
            ),
            // 3. SW-420 Vibration Card
            _SensorCard(
              title: 'Vibration (SW-420)',
              icon: Icons.vibration_rounded,
              value: isValid
                  ? (telemetry.isVibrationDetected
                      ? 'ACTIVE (${telemetry.vibrationCount} Hz)'
                      : 'CLEAR (0 Hz)')
                  : '--',
              accentColor: !isValid
                  ? const Color(0xFF6E7280)
                  : (isVibActive ? const Color(0xFFFF3D00) : const Color(0xFF00E676)),
              isHighlighted: isVibActive,
            ),
            // 4. Water Level Card
            _SensorCard(
              title: 'Water Sensor',
              icon: Icons.water_drop_outlined,
              value: isValid ? '${telemetry.water} ADC' : '--',
              accentColor: !isValid
                  ? const Color(0xFF6E7280)
                  : (isWaterCritical
                      ? const Color(0xFFFF3D00)
                      : (isWaterWarning ? const Color(0xFFFFC107) : const Color(0xFF00E676))),
              isHighlighted: isWaterCritical || isWaterWarning,
            ),
            // 5. Sound Level (Mic) Card
            _SensorCard(
              title: isSoundMonitoringActive ? 'Relative Sound (Mic)' : 'Sound (Disabled)',
              icon: isSoundMonitoringActive ? Icons.mic_rounded : Icons.mic_off_rounded,
              value: (isValid && isSoundMonitoringActive)
                  ? '${(telemetry.soundLevel * 100).toStringAsFixed(0)}%'
                  : '--',
              accentColor: (!isValid || !isSoundMonitoringActive)
                  ? const Color(0xFF6E7280)
                  : (isSoundCritical
                      ? const Color(0xFFFF3D00)
                      : (isSoundWarning ? const Color(0xFFFFC107) : const Color(0xFF00E676))),
              isHighlighted: isSoundMonitoringActive && (isSoundCritical || isSoundWarning),
            ),
          ],
        );
      },
    );
  }
}

class _SensorCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final String value;
  final Color accentColor;
  final bool isHighlighted;

  const _SensorCard({
    required this.title,
    required this.icon,
    required this.value,
    required this.accentColor,
    required this.isHighlighted,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF000000), // OLED Black
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isHighlighted ? accentColor : const Color(0xFF1E2026),
          width: isHighlighted ? 1.5 : 1.0,
        ),
        boxShadow: isHighlighted
            ? [
                BoxShadow(
                  color: accentColor.withValues(alpha: 0.2),
                  blurRadius: 8,
                )
              ]
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(icon, color: accentColor, size: 20),
              if (isHighlighted)
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: accentColor,
                    shape: BoxShape.circle,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: const TextStyle(
              color: Color(0xFF9E9E9E),
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: TextStyle(
                color: accentColor,
                fontSize: 18,
                fontWeight: FontWeight.bold,
                fontFamily: 'monospace',
              ),
            ),
          ),
        ],
      ),
    );
  }
}
