import 'package:flutter/material.dart';
import '../controllers/machine_controller.dart';
import '../services/bluetooth_service.dart';
import '../services/sound_monitor_service.dart';
import '../widgets/connection_badge.dart';

class ControlsScreen extends StatelessWidget {
  final MachineController controller;

  const ControlsScreen({
    super.key,
    required this.controller,
  });

  bool get isConnected => controller.connectionState == DeviceBtState.connected;
  bool get isPending => controller.isCommandPending;

  @override
  Widget build(BuildContext context) {
    const yellowAccent = Color(0xFFF5D400);

    return ListenableBuilder(
      listenable: controller,
      builder: (context, child) {
        return Scaffold(
          backgroundColor: const Color(0xFF08090B),
          appBar: AppBar(
            backgroundColor: const Color(0xFF08090B),
            title: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'MACHINE CONTROLS',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.1,
                  ),
                ),
                Text(
                  'SPP Transceiver & Hardware Interlocks',
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
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Disconnected Notice / Guidance Banner
                  if (!isConnected) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFF3D00).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFFF3D00).withValues(alpha: 0.5)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.bluetooth_disabled_rounded, color: Color(0xFFFF3D00), size: 20),
                          const SizedBox(width: 10),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Bluetooth Stream Disconnected',
                                  style: TextStyle(
                                    color: Color(0xFFFF3D00),
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                SizedBox(height: 2),
                                Text(
                                  'Hardware control commands are disabled until an active SPP connection to EdgeAI_Predictive_Node is established.',
                                  style: TextStyle(color: Color(0xFFA0A0A0), fontSize: 10),
                                ),
                              ],
                            ),
                          ),
                          TextButton(
                            onPressed: () => controller.connect(),
                            style: TextButton.styleFrom(
                              foregroundColor: yellowAccent,
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            ),
                            child: const Text('Connect', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Status / Command Feedback Banner
                  if (controller.commandFeedback.isNotEmpty) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: controller.commandSuccess == true
                            ? const Color(0xFF00E676).withValues(alpha: 0.15)
                            : (controller.commandSuccess == false
                                ? const Color(0xFFFF3D00).withValues(alpha: 0.15)
                                : yellowAccent.withValues(alpha: 0.15)),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: controller.commandSuccess == true
                              ? const Color(0xFF00E676)
                              : (controller.commandSuccess == false
                                  ? const Color(0xFFFF3D00)
                                  : yellowAccent),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            controller.commandSuccess == true
                                ? Icons.check_circle_outline
                                : (controller.commandSuccess == false
                                    ? Icons.error_outline
                                    : Icons.info_outline),
                            color: controller.commandSuccess == true
                                ? const Color(0xFF00E676)
                                : (controller.commandSuccess == false
                                    ? const Color(0xFFFF3D00)
                                    : yellowAccent),
                            size: 18,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              controller.commandFeedback,
                              style: TextStyle(
                                color: controller.commandSuccess == true
                                    ? const Color(0xFF00E676)
                                    : (controller.commandSuccess == false
                                        ? const Color(0xFFFF3D00)
                                        : yellowAccent),
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close, size: 16, color: Color(0xFFA0A0A0)),
                            onPressed: () => controller.clearCommandFeedback(),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Section: Phone Microphone Sound Monitoring Control
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFF151619),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: controller.soundMonitor.isMonitoring
                            ? const Color(0xFF00E676)
                            : (controller.soundMonitor.state == SoundMonitorState.stopping ||
                                    controller.soundMonitor.state == SoundMonitorState.starting
                                ? yellowAccent
                                : const Color(0xFF22242B)),
                        width: 1.2,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.mic_rounded,
                                  color: controller.soundMonitor.isMonitoring
                                      ? const Color(0xFF00E676)
                                      : (controller.soundMonitor.state == SoundMonitorState.stopping ||
                                              controller.soundMonitor.state == SoundMonitorState.starting
                                          ? yellowAccent
                                          : const Color(0xFFA0A0A0)),
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                const Text(
                                  'PHONE MICROPHONE MONITOR',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 1.0,
                                  ),
                                ),
                              ],
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: controller.soundMonitor.isMonitoring
                                    ? const Color(0xFF00E676).withValues(alpha: 0.15)
                                    : (controller.soundMonitor.state == SoundMonitorState.stopping ||
                                            controller.soundMonitor.state == SoundMonitorState.starting
                                        ? yellowAccent.withValues(alpha: 0.15)
                                        : const Color(0xFF22242B)),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                controller.soundMonitor.statusBadgeText,
                                style: TextStyle(
                                  color: controller.soundMonitor.isMonitoring
                                      ? const Color(0xFF00E676)
                                      : (controller.soundMonitor.state == SoundMonitorState.stopping ||
                                              controller.soundMonitor.state == SoundMonitorState.starting
                                          ? yellowAccent
                                          : const Color(0xFFA0A0A0)),
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    controller.soundMonitor.isMonitoring
                                        ? 'Relative Level: ${controller.soundMonitor.displayLevel} | Peak: ${controller.soundMonitor.displayPeak}'
                                        : 'Sound Monitoring Disabled',
                                    style: TextStyle(
                                      color: controller.soundMonitor.isMonitoring
                                          ? const Color(0xFF00E676)
                                          : const Color(0xFFCBD5E1),
                                      fontSize: 11,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    controller.soundMonitor.isMonitoring
                                        ? 'Uses phone microphone locally. Only compact normalized sound features (0.0 - 1.0) are computed.'
                                        : controller.soundMonitor.statusMessage,
                                    style: const TextStyle(color: Color(0xFF6E7280), fontSize: 9, fontStyle: FontStyle.italic),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            ElevatedButton.icon(
                              onPressed: controller.soundMonitor.state == SoundMonitorState.starting ||
                                      controller.soundMonitor.state == SoundMonitorState.stopping
                                  ? null
                                  : () {
                                      if (controller.soundMonitor.isMonitoring) {
                                        controller.stopSoundMonitoring();
                                      } else {
                                        controller.startSoundMonitoring();
                                      }
                                    },
                              icon: Icon(
                                controller.soundMonitor.isMonitoring ? Icons.stop_rounded : Icons.play_arrow_rounded,
                                size: 16,
                              ),
                              label: Text(
                                controller.soundMonitor.isMonitoring ? 'STOP' : 'START',
                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: controller.soundMonitor.isMonitoring
                                    ? const Color(0xFFFF3D00)
                                    : yellowAccent,
                                foregroundColor: controller.soundMonitor.isMonitoring ? Colors.white : Colors.black,
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Section 1: Routine Fault Injection Commands
                  const Row(
                    children: [
                      Icon(Icons.bug_report_outlined, color: yellowAccent, size: 18),
                      SizedBox(width: 8),
                      Text(
                        'FAULT INJECTION COMMANDS',
                        style: TextStyle(
                          color: Color(0xFFA0A0A0),
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.0,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Transmits single-byte SPP commands to simulate machine failure modes.',
                    style: TextStyle(color: Color(0xFFA0A0A0), fontSize: 10),
                  ),
                  const SizedBox(height: 12),

                  LayoutBuilder(
                    builder: (context, constraints) {
                      final crossCount = constraints.maxWidth < 320 ? 1 : 2;
                      final ratio = crossCount == 1 ? 2.5 : 1.35;

                      return GridView.count(
                        crossAxisCount: crossCount,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        mainAxisSpacing: 12,
                        crossAxisSpacing: 12,
                        childAspectRatio: ratio,
                        children: [
                          // 1. Thermal Fault ('T')
                          _DetailedControlCard(
                            title: 'Thermal Fault',
                            code: 'T',
                            description: 'Injects simulated 48.5°C overheating state.',
                            icon: Icons.local_fire_department_rounded,
                            accentColor: yellowAccent,
                            enabled: isConnected && !isPending,
                            onPressed: () => controller.sendCommand('T', 'THERMAL FAULT'),
                          ),
                          // 2. Vibration Fault ('D')
                          _DetailedControlCard(
                            title: 'Vibration Fault',
                            code: 'D',
                            description: 'Triggers SW-420 DO vibration alert switch.',
                            icon: Icons.vibration_rounded,
                            accentColor: yellowAccent,
                            enabled: isConnected && !isPending,
                            onPressed: () => controller.sendCommand('D', 'VIBRATION FAULT'),
                          ),
                          // 3. Water Leak ('L')
                          _DetailedControlCard(
                            title: 'Water Leak',
                            code: 'L',
                            description: 'Injects simulated 1200 ADC fluid seepage.',
                            icon: Icons.water_drop_rounded,
                            accentColor: yellowAccent,
                            enabled: isConnected && !isPending,
                            onPressed: () => controller.sendCommand('L', 'WATER LEAK'),
                          ),
                          // 4. Abnormal Sound Fault ('S')
                          _DetailedControlCard(
                            title: 'Sound Fault',
                            code: 'S',
                            description: 'Injects simulated high acoustic noise event.',
                            icon: Icons.graphic_eq_rounded,
                            accentColor: yellowAccent,
                            enabled: isConnected && !isPending,
                            onPressed: () => controller.triggerSoundFault(),
                          ),
                          // 5. Clear Faults ('C')
                          _DetailedControlCard(
                            title: 'Clear Faults',
                            code: 'C',
                            description: 'Clears all injected faults & restores sensors.',
                            icon: Icons.cleaning_services_rounded,
                            accentColor: const Color(0xFF00E676),
                            enabled: isConnected && !isPending,
                            onPressed: () => controller.sendCommand('C', 'CLEAR FAULTS'),
                          ),
                        ],
                      );
                    },
                  ),

                  const SizedBox(height: 24),

                  // Section 2: Safety & Critical Operations
                  const Row(
                    children: [
                      Icon(Icons.shield_outlined, color: Color(0xFFFF3D00), size: 18),
                      SizedBox(width: 8),
                      Text(
                        'SAFETY & CRITICAL OPERATIONS',
                        style: TextStyle(
                          color: Color(0xFFFF3D00),
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.0,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Confirmation-gated commands that alter node hardware safety states.',
                    style: TextStyle(color: Color(0xFFA0A0A0), fontSize: 10),
                  ),
                  const SizedBox(height: 12),

                  LayoutBuilder(
                    builder: (context, constraints) {
                      final crossCount = constraints.maxWidth < 320 ? 1 : 2;
                      final ratio = crossCount == 1 ? 2.5 : 1.35;

                      return GridView.count(
                        crossAxisCount: crossCount,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        mainAxisSpacing: 12,
                        crossAxisSpacing: 12,
                        childAspectRatio: ratio,
                        children: [
                          // 5. Safety Override ('O')
                          _DetailedControlCard(
                            title: 'Safety Override',
                            code: 'O',
                            description: 'Overrides alarm buzzer & resets alert outputs.',
                            icon: Icons.shield_rounded,
                            accentColor: const Color(0xFFFF3D00),
                            enabled: isConnected && !isPending,
                            onPressed: () => _confirmSafetyOverride(context),
                          ),
                          // 6. System Reset ('R')
                          _DetailedControlCard(
                            title: 'System Reset',
                            code: 'R',
                            description: 'Triggers soft hardware reboot on ESP32.',
                            icon: Icons.restart_alt_rounded,
                            accentColor: const Color(0xFFFF3D00),
                            enabled: isConnected && !isPending,
                            onPressed: () => _confirmSystemReset(context),
                          ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _confirmSafetyOverride(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF151619),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Color(0xFFFF3D00)),
            SizedBox(width: 8),
            Text(
              'Confirm Safety Override',
              style: TextStyle(color: Colors.white, fontSize: 16),
            ),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Transmits command "O" to request a safety override on the ESP32 node.',
              style: TextStyle(color: Color(0xFFCBD5E1), fontSize: 13),
            ),
            SizedBox(height: 12),
            Text(
              '• Confirmation Gated: Outcome displays as PENDING until confirmed by telemetry.\n'
              '• Interlock Protection: Does NOT disable physical hardware emergency stop switches.',
              style: TextStyle(color: Color(0xFFA0A0A0), fontSize: 11),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Color(0xFFA0A0A0))),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              controller.requestSafetyOverride();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF3D00),
              foregroundColor: Colors.white,
            ),
            child: const Text('Send Override ("O")', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _confirmSystemReset(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF151619),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.restart_alt_rounded, color: Color(0xFFFF3D00)),
            SizedBox(width: 8),
            Text(
              'Confirm System Reset',
              style: TextStyle(color: Colors.white, fontSize: 16),
            ),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Transmits command "R" to trigger a soft hardware reboot on the ESP32.',
              style: TextStyle(color: Color(0xFFCBD5E1), fontSize: 13),
            ),
            SizedBox(height: 12),
            Text(
              '• Stream Interruption: Telemetry stream will disconnect temporarily during reboot.\n'
              '• Reconnection: App will attempt automatic reconnection after ESP32 Bluetooth stack restarts.',
              style: TextStyle(color: Color(0xFFA0A0A0), fontSize: 11),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Color(0xFFA0A0A0))),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              controller.requestSystemReset();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF3D00),
              foregroundColor: Colors.white,
            ),
            child: const Text('Send Reset ("R")', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}

class _DetailedControlCard extends StatelessWidget {
  final String title;
  final String code;
  final String description;
  final IconData icon;
  final Color accentColor;
  final bool enabled;
  final VoidCallback onPressed;

  const _DetailedControlCard({
    required this.title,
    required this.code,
    required this.description,
    required this.icon,
    required this.accentColor,
    required this.enabled,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveColor = enabled ? accentColor : const Color(0xFF383A42);
    final titleColor = enabled ? Colors.white : const Color(0xFFA0A0A0);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: enabled ? onPressed : null,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(12),
          constraints: const BoxConstraints(minHeight: 48, minWidth: 48),
          decoration: BoxDecoration(
            color: const Color(0xFF151619),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: effectiveColor.withValues(alpha: enabled ? 0.6 : 0.2),
              width: 1.2,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Icon(icon, color: effectiveColor, size: 20),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: effectiveColor.withValues(alpha: 0.25),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      "'$code'",
                      style: TextStyle(
                        color: effectiveColor,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: titleColor,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    description,
                    style: const TextStyle(
                      color: Color(0xFFA0A0A0),
                      fontSize: 10,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
