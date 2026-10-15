import 'package:flutter/material.dart';
import '../controllers/machine_controller.dart';
import '../services/bluetooth_service.dart';
import '../widgets/connection_badge.dart';

class SensorsScreen extends StatelessWidget {
  final MachineController controller;

  const SensorsScreen({
    super.key,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    const yellowAccent = Color(0xFFF5D400);

    return ListenableBuilder(
      listenable: controller,
      builder: (context, child) {
        final telemetry = controller.telemetry;
        final isConnected = controller.connectionState == DeviceBtState.connected;
        final isValid = telemetry.isValid && isConnected;

        return Scaffold(
          backgroundColor: const Color(0xFF08090B),
          appBar: AppBar(
            backgroundColor: const Color(0xFF08090B),
            title: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'SENSOR TELEMETRY',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.1,
                  ),
                ),
                Text(
                  'Live Transducer & Sensor Array',
                  style: TextStyle(color: Color(0xFFA0A0A0), fontSize: 10),
                ),
              ],
            ),
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: 12.0),
                child: ConnectionBadge(controller: controller),
              ),
            ],
          ),
          body: SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 800),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Info Card
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF151619),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: yellowAccent.withValues(alpha: 0.3),
                          ),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.info_outline_rounded, color: yellowAccent, size: 20),
                            SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Tap any sensor card to inspect hardware threshold specifications, pin mapping, and physical diagnostic advice.',
                                style: TextStyle(color: Color(0xFFCBD5E1), fontSize: 11),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // 1. Temperature Sensor
                      _DetailedSensorCard(
                        title: 'Temperature (DHT11)',
                        value: isValid ? '${telemetry.temp.toStringAsFixed(1)} °C' : 'Waiting for data',
                        rawDetail: 'DHT11 Data Pin on GPIO 23',
                        icon: Icons.thermostat_rounded,
                        accentColor: !isValid
                            ? const Color(0xFFA0A0A0)
                            : (telemetry.temp >= 45.0
                                ? const Color(0xFFFF3D00)
                                : (telemetry.temp >= 35.0 ? yellowAccent : const Color(0xFF00E676))),
                        status: !isValid
                            ? 'DISCONNECTED'
                            : (telemetry.temp >= 45.0 ? 'OVERHEATING' : (telemetry.temp >= 35.0 ? 'ELEVATED' : 'NORMAL')),
                        onTap: () => _showSensorBottomSheet(
                          context,
                          'Thermal Transducer (DHT11)',
                          'Monitors bearing friction, thermal expansion, and heat dissipation across the mechanical shaft.',
                          'Normal: < 35°C | Warning: 35-45°C | Critical: >= 45°C',
                          isValid ? '${telemetry.temp.toStringAsFixed(1)} °C' : 'N/A',
                          'If temperature exceeds 45°C, verify cooling lines and inspect lubricant viscosity immediately.',
                        ),
                      ),
                      const SizedBox(height: 12),

                      // 2. Humidity Sensor
                      _DetailedSensorCard(
                        title: 'Relative Humidity (DHT11)',
                        value: isValid ? '${telemetry.hum.toStringAsFixed(1)} %' : 'Waiting for data',
                        rawDetail: 'DHT11 Humidity Sensor on GPIO 23',
                        icon: Icons.water_outlined,
                        accentColor: !isValid ? const Color(0xFFA0A0A0) : yellowAccent,
                        status: !isValid ? 'DISCONNECTED' : 'NOMINAL',
                        onTap: () => _showSensorBottomSheet(
                          context,
                          'Relative Humidity Transducer',
                          'Measures ambient relative humidity around the electronics enclosure to detect condensation risk.',
                          'Nominal Operating Range: 20% to 90% RH',
                          isValid ? '${telemetry.hum.toStringAsFixed(1)} %' : 'N/A',
                          'Ensure enclosure seals remain tight to prevent atmospheric moisture condensation on ESP32 PCB.',
                        ),
                      ),
                      const SizedBox(height: 12),

                      // 3. SW-420 Vibration Sensor Module
                      _DetailedSensorCard(
                        title: 'SW-420 Vibration Sensor',
                        value: isValid
                            ? (telemetry.isVibrationDetected
                                ? 'ACTIVE (${telemetry.vibrationCount} pulses/s)'
                                : 'CLEAR (0 pulses/s)')
                            : 'Waiting for data',
                        rawDetail: 'Digital Input DO on GPIO 19 (1-sec window pulse count)',
                        icon: Icons.vibration_rounded,
                        accentColor: !isValid
                            ? const Color(0xFFA0A0A0)
                            : (telemetry.isVibrationDetected
                                ? const Color(0xFFFF3D00)
                                : const Color(0xFF00E676)),
                        status: !isValid
                            ? 'DISCONNECTED'
                            : (telemetry.isVibrationDetected ? 'VIBRATION ACTIVE' : 'STABLE'),
                        onTap: () => _showSensorBottomSheet(
                          context,
                          'SW-420 Vibration Sensor Module',
                          'Monitors mechanical oscillations and shaft vibration events using a digital spring switch module on ESP32 GPIO 19.',
                          'Digital Output DO: Active HIGH/LOW edge pulse accumulator counted over 1000ms sliding window.',
                          isValid
                              ? (telemetry.isVibrationDetected
                                  ? 'DETECTED (vibration=1, ${telemetry.vibrationCount} pulses/sec)'
                                  : 'CLEAR (vibration=0, 0 pulses/sec)')
                              : 'N/A',
                          'If excessive vibration is detected, check shaft alignment, bearing play, and dampening mounts.',
                        ),
                      ),
                      const SizedBox(height: 12),

                      // 4. Fluid Seepage (Water Leak)
                      _DetailedSensorCard(
                        title: 'Water Seepage Sensor',
                        value: isValid ? '${telemetry.water} ADC' : 'Waiting for data',
                        rawDetail: '12-bit ADC Analog Moisture Input (GPIO 34 / ADC1)',
                        icon: Icons.water_drop_rounded,
                        accentColor: !isValid
                            ? const Color(0xFFA0A0A0)
                            : (telemetry.water >= 1000
                                ? const Color(0xFFFF3D00)
                                : (telemetry.water >= 100 ? yellowAccent : const Color(0xFF00E676))),
                        status: !isValid
                            ? 'DISCONNECTED'
                            : (telemetry.water >= 1000
                                ? 'CRITICAL LEAK'
                                : (telemetry.water >= 100 ? 'MOISTURE DETECTED' : 'DRY')),
                        onTap: () => _showSensorBottomSheet(
                          context,
                          'Moisture Seepage Sensor',
                          'Detects conductive fluid accumulation, hydraulic oil leaks, or coolant pipe seepage.',
                          'Dry: 0-99 ADC | Warning Moisture: 100-999 ADC | Critical Leak: >= 1000 ADC',
                          isValid ? '${telemetry.water} ADC' : 'N/A',
                          'If fluid seepage exceeds 1000 ADC, isolate hydraulic lines and inspect gasket seals immediately.',
                        ),
                      ),
                      const SizedBox(height: 12),

                      // 5. Acoustic Sound Transducer (Phone Microphone)
                      _DetailedSensorCard(
                        title: controller.soundMonitor.isMonitoring
                            ? 'Relative Sound (Phone Mic)'
                            : 'Relative Sound (Microphone OFF)',
                        value: (isValid && controller.soundMonitor.isMonitoring)
                            ? '${(telemetry.soundLevel * 100).toStringAsFixed(0)}% (${telemetry.soundLevel.toStringAsFixed(2)})'
                            : '--',
                        rawDetail: controller.soundMonitor.isMonitoring
                            ? 'Android Phone Microphone via SoundMonitorService Stream'
                            : 'Sound Monitoring Disabled — Microphone Inactive',
                        icon: controller.soundMonitor.isMonitoring
                            ? Icons.mic_rounded
                            : Icons.mic_off_rounded,
                        accentColor: (!isValid || !controller.soundMonitor.isMonitoring)
                            ? const Color(0xFFA0A0A0)
                            : (telemetry.soundLevel >= 0.80
                                ? const Color(0xFFFF3D00)
                                : (telemetry.soundLevel >= 0.50 ? yellowAccent : const Color(0xFF00E676))),
                        status: !controller.soundMonitor.isMonitoring
                            ? 'OFF'
                            : (!isValid
                                ? 'DISCONNECTED'
                                : (telemetry.soundLevel >= 0.80
                                    ? 'ABNORMAL NOISE'
                                    : (telemetry.soundLevel >= 0.50 ? 'ELEVATED NOISE' : 'QUIET'))),
                        onTap: () => _showSensorBottomSheet(
                          context,
                          'Acoustic Sound Monitoring',
                          controller.soundMonitor.isMonitoring
                              ? 'Uses the phone microphone to monitor machinery sound levels locally and stream compact relative features (0.0 to 1.0) over Bluetooth SPP.'
                              : 'Sound monitoring is currently DISABLED. Turn on the phone microphone in Machine Controls to capture acoustic machine features.',
                          'Quiet: < 0.50 | Warning Elevated: 0.50-0.79 | Critical Noise: >= 0.80',
                          controller.soundMonitor.isMonitoring
                              ? '${(telemetry.soundLevel * 100).toStringAsFixed(0)}% relative level'
                              : 'DISABLED (OFF)',
                          'If abnormal sound is detected, inspect gear mesh, bearing squeal, or loose structural fasteners.',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _showSensorBottomSheet(
    BuildContext context,
    String title,
    String description,
    String threshold,
    String liveValue,
    String recommendation,
  ) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF151619),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.analytics_outlined, color: Color(0xFFF5D400)),
                    const SizedBox(width: 8),
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Color(0xFFA0A0A0)),
                  onPressed: () => Navigator.pop(ctx),
                ),
              ],
            ),
            const Divider(color: Color(0xFF22242B)),
            const SizedBox(height: 8),
            Text(description, style: const TextStyle(color: Color(0xFFCBD5E1), fontSize: 13)),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFF08090B),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFF22242B)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Live Telemetry:', style: TextStyle(color: Color(0xFFA0A0A0), fontSize: 11)),
                      Text(liveValue, style: const TextStyle(color: Color(0xFFF5D400), fontWeight: FontWeight.bold, fontSize: 12)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text('Threshold Rules: $threshold', style: const TextStyle(color: Color(0xFFA0A0A0), fontSize: 10)),
                ],
              ),
            ),
            const SizedBox(height: 12),
            const Text('Maintenance Action:', style: TextStyle(color: Color(0xFFF5D400), fontWeight: FontWeight.bold, fontSize: 12)),
            const SizedBox(height: 4),
            Text(recommendation, style: const TextStyle(color: Color(0xFFA0A0A0), fontSize: 11)),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

class _DetailedSensorCard extends StatelessWidget {
  final String title;
  final String value;
  final String rawDetail;
  final IconData icon;
  final Color accentColor;
  final String status;
  final VoidCallback onTap;

  const _DetailedSensorCard({
    required this.title,
    required this.value,
    required this.rawDetail,
    required this.icon,
    required this.accentColor,
    required this.status,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(16),
          constraints: const BoxConstraints(minHeight: 48, minWidth: 48),
          decoration: BoxDecoration(
            color: const Color(0xFF151619),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFF22242B), width: 1.0),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: accentColor, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            color: Color(0xFFA0A0A0),
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: accentColor.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            status,
                            style: TextStyle(
                              color: accentColor,
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      value,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'monospace',
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      rawDetail,
                      style: const TextStyle(
                        color: Color(0xFFA0A0A0),
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: Color(0xFFA0A0A0)),
            ],
          ),
        ),
      ),
    );
  }
}
