import 'package:flutter/material.dart';
import '../controllers/machine_controller.dart';
import '../services/bluetooth_service.dart';
import '../widgets/connection_badge.dart';

class SettingsScreen extends StatelessWidget {
  final MachineController controller;

  const SettingsScreen({
    super.key,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    const yellowAccent = Color(0xFFF5D400);

    return ListenableBuilder(
      listenable: controller,
      builder: (context, child) {
        final isConnected = controller.connectionState == DeviceBtState.connected;
        final draft = controller.draftConfig;
        final hasEdits = controller.hasUnsavedConfigEdits;
        final isApplying = controller.isConfigApplying;

        return Scaffold(
          backgroundColor: const Color(0xFF08090B),
          appBar: AppBar(
            backgroundColor: const Color(0xFF08090B),
            elevation: 0,
            title: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'RULE SETTINGS & CONFIG',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.1,
                  ),
                ),
                Text(
                  'ESP32 Live Rule Synchronization & Interlocks',
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
                      // 1. Connection & Sync Banner
                      _buildSyncBanner(context, isConnected),
                      const SizedBox(height: 16),

                      // Error message banner if present
                      if (controller.configErrorMsg.isNotEmpty) ...[
                        Container(
                          padding: const EdgeInsets.all(12),
                          margin: const EdgeInsets.only(bottom: 16),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFF3D00).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFFFF3D00)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.error_outline_rounded, color: Color(0xFFFF3D00), size: 20),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  controller.configErrorMsg,
                                  style: const TextStyle(
                                    color: Color(0xFFFF3D00),
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],

                      // 2. Temperature Rules Section (DHT11 on GPIO 23)
                      _buildSectionCard(
                        title: 'TEMPERATURE THRESHOLD RULES',
                        subtitle: 'DHT11 Sensor on GPIO 23 — Friction & Friction Overheating',
                        icon: Icons.thermostat_rounded,
                        accentColor: yellowAccent,
                        children: [
                          _buildSliderRow(
                            label: 'Warning Temperature Threshold',
                            value: draft.tempRules.tempWarning,
                            unit: '°C',
                            min: 10.0,
                            max: 70.0,
                            divisions: 120,
                            enabled: isConnected && !isApplying,
                            onChanged: (val) {
                              controller.updateDraftConfig(
                                draft.copyWith(
                                  tempRules: draft.tempRules.copyWith(tempWarning: val),
                                ),
                              );
                            },
                          ),
                          const SizedBox(height: 12),
                          _buildSliderRow(
                            label: 'Critical Temperature Threshold',
                            value: draft.tempRules.tempCritical,
                            unit: '°C',
                            min: 20.0,
                            max: 90.0,
                            divisions: 140,
                            enabled: isConnected && !isApplying,
                            onChanged: (val) {
                              controller.updateDraftConfig(
                                draft.copyWith(
                                  tempRules: draft.tempRules.copyWith(tempCritical: val),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // 3. Vibration Sensor Rules (SW-420 DO on GPIO 19)
                      _buildSectionCard(
                        title: 'SW-420 VIBRATION SENSOR RULES',
                        subtitle: 'Digital DO Switch on GPIO 19 — Mechanical Oscillations',
                        icon: Icons.vibration_rounded,
                        accentColor: yellowAccent,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Active Signal Polarity',
                                    style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                                  ),
                                  Text(
                                    'Sets whether HIGH (1) or LOW (0) represents active vibration.',
                                    style: TextStyle(color: Color(0xFFA0A0A0), fontSize: 10),
                                  ),
                                ],
                              ),
                              DropdownButton<int>(
                                value: draft.vibRules.vibActiveState,
                                dropdownColor: const Color(0xFF151619),
                                style: const TextStyle(color: yellowAccent, fontSize: 11, fontWeight: FontWeight.bold),
                                onChanged: (isConnected && !isApplying)
                                    ? (val) {
                                        if (val != null) {
                                          controller.updateDraftConfig(
                                            draft.copyWith(
                                              vibRules: draft.vibRules.copyWith(vibActiveState: val),
                                            ),
                                          );
                                        }
                                      }
                                    : null,
                                items: const [
                                  DropdownMenuItem(value: 1, child: Text('Active HIGH (1)')),
                                  DropdownMenuItem(value: 0, child: Text('Active LOW (0)')),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          _buildSliderRow(
                            label: 'Debounce Interval',
                            value: draft.vibRules.vibDebounceMs.toDouble(),
                            unit: 'ms',
                            min: 0.0,
                            max: 200.0,
                            divisions: 40,
                            enabled: isConnected && !isApplying,
                            onChanged: (val) {
                              controller.updateDraftConfig(
                                draft.copyWith(
                                  vibRules: draft.vibRules.copyWith(vibDebounceMs: val.toInt()),
                                ),
                              );
                            },
                          ),
                          const SizedBox(height: 12),
                          _buildSliderRow(
                            label: 'Warning Event Count',
                            value: draft.vibRules.vibWarningCount.toDouble(),
                            unit: 'events',
                            min: 1.0,
                            max: 20.0,
                            divisions: 19,
                            enabled: isConnected && !isApplying,
                            onChanged: (val) {
                              controller.updateDraftConfig(
                                draft.copyWith(
                                  vibRules: draft.vibRules.copyWith(vibWarningCount: val.toInt()),
                                ),
                              );
                            },
                          ),
                          const SizedBox(height: 12),
                          _buildSliderRow(
                            label: 'Critical Event Count',
                            value: draft.vibRules.vibCriticalCount.toDouble(),
                            unit: 'events',
                            min: 2.0,
                            max: 50.0,
                            divisions: 48,
                            enabled: isConnected && !isApplying,
                            onChanged: (val) {
                              controller.updateDraftConfig(
                                draft.copyWith(
                                  vibRules: draft.vibRules.copyWith(vibCriticalCount: val.toInt()),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // 4. Water Seepage Rules (ADC on GPIO 34)
                      _buildSectionCard(
                        title: 'WATER SEEPAGE SENSOR RULES',
                        subtitle: '12-bit Analog ADC1_CH6 on GPIO 34 — Conductive Fluid Seepage',
                        icon: Icons.water_drop_rounded,
                        accentColor: yellowAccent,
                        children: [
                          _buildSliderRow(
                            label: 'Warning Moisture ADC Threshold',
                            value: draft.waterRules.waterWarning.toDouble(),
                            unit: 'ADC',
                            min: 10.0,
                            max: 2000.0,
                            divisions: 199,
                            enabled: isConnected && !isApplying,
                            onChanged: (val) {
                              controller.updateDraftConfig(
                                draft.copyWith(
                                  waterRules: draft.waterRules.copyWith(waterWarning: val.toInt()),
                                ),
                              );
                            },
                          ),
                          const SizedBox(height: 12),
                          _buildSliderRow(
                            label: 'Critical Leak ADC Threshold',
                            value: draft.waterRules.waterCritical.toDouble(),
                            unit: 'ADC',
                            min: 100.0,
                            max: 4095.0,
                            divisions: 399,
                            enabled: isConnected && !isApplying,
                            onChanged: (val) {
                              controller.updateDraftConfig(
                                draft.copyWith(
                                  waterRules: draft.waterRules.copyWith(waterCritical: val.toInt()),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // 5. Acoustic Sound Rules (Phone Mic)
                      _buildSectionCard(
                        title: 'ACOUSTIC SOUND MONITORING RULES',
                        subtitle: 'Phone Microphone RMS Feature Transceiver via Bluetooth SPP',
                        icon: Icons.mic_rounded,
                        accentColor: yellowAccent,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Sound Feature Stream',
                                    style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                                  ),
                                  Text(
                                    'Transmits local acoustic feature packets to ESP32',
                                    style: TextStyle(color: Color(0xFFA0A0A0), fontSize: 10),
                                  ),
                                ],
                              ),
                              Switch(
                                value: draft.soundRules.soundEnabled,
                                activeThumbColor: const Color(0xFF00E676),
                                onChanged: (isConnected && !isApplying)
                                    ? (val) {
                                        controller.updateDraftConfig(
                                          draft.copyWith(
                                            soundRules: draft.soundRules.copyWith(soundEnabled: val),
                                          ),
                                        );
                                      }
                                    : null,
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          _buildSliderRow(
                            label: 'Sound Warning Level',
                            value: draft.soundRules.soundWarning * 100,
                            unit: '%',
                            min: 10.0,
                            max: 90.0,
                            divisions: 80,
                            enabled: isConnected && !isApplying && draft.soundRules.soundEnabled,
                            onChanged: (val) {
                              controller.updateDraftConfig(
                                draft.copyWith(
                                  soundRules: draft.soundRules.copyWith(soundWarning: val / 100.0),
                                ),
                              );
                            },
                          ),
                          const SizedBox(height: 12),
                          _buildSliderRow(
                            label: 'Sound Critical Level',
                            value: draft.soundRules.soundCritical * 100,
                            unit: '%',
                            min: 20.0,
                            max: 100.0,
                            divisions: 80,
                            enabled: isConnected && !isApplying && draft.soundRules.soundEnabled,
                            onChanged: (val) {
                              controller.updateDraftConfig(
                                draft.copyWith(
                                  soundRules: draft.soundRules.copyWith(soundCritical: val / 100.0),
                                ),
                              );
                            },
                          ),
                          const SizedBox(height: 12),
                          _buildSliderRow(
                            label: 'Stale Data Cutoff Timeout',
                            value: draft.soundRules.soundStaleTimeoutMs.toDouble(),
                            unit: 'ms',
                            min: 1000.0,
                            max: 10000.0,
                            divisions: 90,
                            enabled: isConnected && !isApplying,
                            onChanged: (val) {
                              controller.updateDraftConfig(
                                draft.copyWith(
                                  soundRules: draft.soundRules.copyWith(soundStaleTimeoutMs: val.toInt()),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // 6. Risk & Alert Rules
                      _buildSectionCard(
                        title: 'MACHINE RISK & HARDWARE INTERLOCKS',
                        subtitle: 'Deterministic Baseline Machine Risk & ESP32 Hardware Outputs',
                        icon: Icons.shield_outlined,
                        accentColor: yellowAccent,
                        children: [
                          _buildSliderRow(
                            label: 'Warning Risk Score Threshold',
                            value: draft.riskRules.riskWarning.toDouble(),
                            unit: '%',
                            min: 10.0,
                            max: 65.0,
                            divisions: 55,
                            enabled: isConnected && !isApplying,
                            onChanged: (val) {
                              controller.updateDraftConfig(
                                draft.copyWith(
                                  riskRules: draft.riskRules.copyWith(riskWarning: val.toInt()),
                                ),
                              );
                            },
                          ),
                          const SizedBox(height: 12),
                          _buildSliderRow(
                            label: 'Critical Emergency Trip Threshold',
                            value: draft.riskRules.riskCritical.toDouble(),
                            unit: '%',
                            min: 35.0,
                            max: 95.0,
                            divisions: 60,
                            enabled: isConnected && !isApplying,
                            onChanged: (val) {
                              controller.updateDraftConfig(
                                draft.copyWith(
                                  riskRules: draft.riskRules.copyWith(riskCritical: val.toInt()),
                                ),
                              );
                            },
                          ),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'ESP32 Hardware Buzzer (GPIO 18)',
                                    style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                                  ),
                                  Text(
                                    'Active piezo buzzer tone during critical events',
                                    style: TextStyle(color: Color(0xFFA0A0A0), fontSize: 10),
                                  ),
                                ],
                              ),
                              Switch(
                                value: draft.riskRules.buzzerEnabled,
                                activeThumbColor: const Color(0xFF00E676),
                                onChanged: (isConnected && !isApplying)
                                    ? (val) {
                                        controller.updateDraftConfig(
                                          draft.copyWith(
                                            riskRules: draft.riskRules.copyWith(buzzerEnabled: val),
                                          ),
                                        );
                                      }
                                    : null,
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          _buildSliderRow(
                            label: 'Hardware Buzzer Auto-Timeout (Max 5s)',
                            value: draft.riskRules.buzzerDurationMs.toDouble(),
                            unit: 'ms',
                            min: 500.0,
                            max: 5000.0,
                            divisions: 9,
                            enabled: isConnected && !isApplying && draft.riskRules.buzzerEnabled,
                            onChanged: (val) {
                              int clampedVal = val.toInt();
                              if (clampedVal > 5000) clampedVal = 5000;
                              controller.updateDraftConfig(
                                draft.copyWith(
                                  riskRules: draft.riskRules.copyWith(buzzerDurationMs: clampedVal),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // 7. UI & Preference Options
                      _buildSectionCard(
                        title: 'MOBILE INTERFACE PREFERENCES',
                        subtitle: 'Local Phone Haptics & Dashboard Visual Effects',
                        icon: Icons.smartphone_rounded,
                        accentColor: yellowAccent,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Critical Event Phone Vibration',
                                    style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                                  ),
                                  Text(
                                    'Single haptic vibration on critical state transition',
                                    style: TextStyle(color: Color(0xFFA0A0A0), fontSize: 10),
                                  ),
                                ],
                              ),
                              Switch(
                                value: draft.uiPrefs.phoneVibrationEnabled,
                                activeThumbColor: const Color(0xFF00E676),
                                onChanged: (val) {
                                  controller.updateDraftConfig(
                                    draft.copyWith(
                                      uiPrefs: draft.uiPrefs.copyWith(phoneVibrationEnabled: val),
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Dashboard Visual Pulse Animation',
                                    style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                                  ),
                                  Text(
                                    'Glow & pulse animations on risk gauge icons',
                                    style: TextStyle(color: Color(0xFFA0A0A0), fontSize: 10),
                                  ),
                                ],
                              ),
                              Switch(
                                value: draft.uiPrefs.visualPulseEnabled,
                                activeThumbColor: const Color(0xFF00E676),
                                onChanged: (val) {
                                  controller.updateDraftConfig(
                                    draft.copyWith(
                                      uiPrefs: draft.uiPrefs.copyWith(visualPulseEnabled: val),
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 80), // Padding for bottom action bar
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Sticky Bottom Apply Bar
          bottomSheet: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(
              color: Color(0xFF151619),
              border: Border(top: BorderSide(color: Color(0xFF22242B), width: 1.0)),
            ),
            child: SafeArea(
              child: Row(
                children: [
                  if (hasEdits)
                    Expanded(
                      flex: 1,
                      child: OutlinedButton(
                        onPressed: isApplying ? null : () => controller.discardDraftConfig(),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFFA0A0A0),
                          side: const BorderSide(color: Color(0xFF383A42)),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: const Text('Discard Edits', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  if (hasEdits) const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      onPressed: (isConnected && hasEdits && !isApplying)
                          ? () => controller.applyConfiguration()
                          : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: yellowAccent,
                        foregroundColor: Colors.black,
                        disabledBackgroundColor: const Color(0xFF22242B),
                        disabledForegroundColor: const Color(0xFF6E7280),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: isApplying
                          ? const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                                ),
                                SizedBox(width: 8),
                                Text('Applying to ESP32...', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                              ],
                            )
                          : Text(
                              !isConnected
                                  ? 'Connect ESP32 to Apply'
                                  : (!hasEdits ? 'Settings Synchronized' : 'Apply Changes to ESP32'),
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSyncBanner(BuildContext context, bool isConnected) {
    Color statusColor;
    String statusLabel;
    IconData statusIcon;

    if (!isConnected) {
      statusColor = const Color(0xFFFF3D00);
      statusLabel = 'DISCONNECTED — READ ONLY';
      statusIcon = Icons.bluetooth_disabled;
    } else if (controller.isConfigApplying) {
      statusColor = const Color(0xFF0288D1);
      statusLabel = 'APPLYING CONFIGURATION...';
      statusIcon = Icons.sync_rounded;
    } else if (controller.hasUnsavedConfigEdits) {
      statusColor = const Color(0xFFF5D400);
      statusLabel = 'UNSAVED LOCAL EDITS';
      statusIcon = Icons.edit_note_rounded;
    } else {
      statusColor = const Color(0xFF00E676);
      statusLabel = 'CONNECTED & SYNCHRONIZED';
      statusIcon = Icons.check_circle_outline_rounded;
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF151619),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: statusColor.withValues(alpha: 0.6), width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(statusIcon, color: statusColor, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    statusLabel,
                    style: TextStyle(
                      color: statusColor,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.0,
                    ),
                  ),
                ],
              ),
              if (isConnected)
                TextButton.icon(
                  onPressed: controller.isConfigSyncing ? null : () => controller.fetchDeviceConfig(),
                  icon: const Icon(Icons.refresh_rounded, size: 14, color: Color(0xFFF5D400)),
                  label: const Text('Reload', style: TextStyle(color: Color(0xFFF5D400), fontSize: 11, fontWeight: FontWeight.bold)),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          const Divider(color: Color(0xFF22242B), height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Target Node:', style: TextStyle(color: Color(0xFFA0A0A0), fontSize: 11)),
              Text(BluetoothService.targetDeviceName, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 2),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Active Config Version:', style: TextStyle(color: Color(0xFFA0A0A0), fontSize: 11)),
              Text('v${controller.activeConfig.version}', style: const TextStyle(color: Color(0xFFF5D400), fontSize: 11, fontWeight: FontWeight.bold, fontFamily: 'monospace')),
            ],
          ),
          if (controller.activeConfig.lastSyncTime != null) ...[
            const SizedBox(height: 2),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Last Sync Time:', style: TextStyle(color: Color(0xFFA0A0A0), fontSize: 11)),
                Text(
                  '${controller.activeConfig.lastSyncTime!.hour.toString().padLeft(2, '0')}:${controller.activeConfig.lastSyncTime!.minute.toString().padLeft(2, '0')}:${controller.activeConfig.lastSyncTime!.second.toString().padLeft(2, '0')}',
                  style: const TextStyle(color: Colors.white, fontSize: 11, fontFamily: 'monospace'),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSectionCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color accentColor,
    required List<Widget> children,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF151619),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF22242B), width: 1.0),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: accentColor, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.0,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: const TextStyle(color: Color(0xFFA0A0A0), fontSize: 10),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(color: Color(0xFF22242B), height: 12),
          ...children,
        ],
      ),
    );
  }

  Widget _buildSliderRow({
    required String label,
    required double value,
    required String unit,
    required double min,
    required double max,
    required int divisions,
    required bool enabled,
    required ValueChanged<double> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(color: Color(0xFFCBD5E1), fontSize: 12)),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFF08090B),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: const Color(0xFF22242B)),
              ),
              child: Text(
                '${value.toStringAsFixed(value % 1 == 0 ? 0 : 1)} $unit',
                style: const TextStyle(
                  color: Color(0xFFF5D400),
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'monospace',
                ),
              ),
            ),
          ],
        ),
        SliderTheme(
          data: SliderThemeData(
            activeTrackColor: const Color(0xFFF5D400),
            inactiveTrackColor: const Color(0xFF22242B),
            thumbColor: const Color(0xFFF5D400),
            overlayColor: const Color(0xFFF5D400).withValues(alpha: 0.2),
            trackHeight: 3.0,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7.0),
          ),
          child: Slider(
            value: value.clamp(min, max),
            min: min,
            max: max,
            divisions: divisions,
            onChanged: enabled ? onChanged : null,
          ),
        ),
      ],
    );
  }
}
