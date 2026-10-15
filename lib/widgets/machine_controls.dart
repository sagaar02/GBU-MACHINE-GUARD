import 'package:flutter/material.dart';
import '../controllers/machine_controller.dart';
import '../services/bluetooth_service.dart';

class MachineControls extends StatelessWidget {
  final MachineController controller;

  const MachineControls({
    super.key,
    required this.controller,
  });

  bool get isConnected => controller.connectionState == DeviceBtState.connected;
  bool get isPending => controller.isCommandPending;

  @override
  Widget build(BuildContext context) {
    const cardBg = Color(0xFF151619);
    const borderCol = Color(0xFF22242B);
    const yellowAccent = Color(0xFFF5D400);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderCol, width: 1.0),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.tune_rounded, color: yellowAccent, size: 18),
                  SizedBox(width: 8),
                  Text(
                    'Quick Fault Injection',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              if (!isConnected)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF3D00).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    'DISCONNECTED',
                    style: TextStyle(
                      color: Color(0xFFFF3D00),
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),

          // Command Feedback Banner if active
          if (controller.commandFeedback.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: controller.commandSuccess == true
                    ? const Color(0xFF00E676).withValues(alpha: 0.15)
                    : (controller.commandSuccess == false
                        ? const Color(0xFFFF3D00).withValues(alpha: 0.15)
                        : yellowAccent.withValues(alpha: 0.15)),
                borderRadius: BorderRadius.circular(8),
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
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      controller.commandFeedback,
                      style: TextStyle(
                        color: controller.commandSuccess == true
                            ? const Color(0xFF00E676)
                            : (controller.commandSuccess == false
                                ? const Color(0xFFFF3D00)
                                : yellowAccent),
                        fontSize: 11,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 14, color: Color(0xFFA0A0A0)),
                    onPressed: () => controller.clearCommandFeedback(),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],

          // Quick Controls Grid (Responsive 2-column or 1-column)
          LayoutBuilder(
            builder: (context, constraints) {
              final crossCount = constraints.maxWidth < 320 ? 1 : 2;
              final ratio = crossCount == 1 ? 2.8 : 1.7;

              return GridView.count(
                crossAxisCount: crossCount,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: ratio,
                children: [
                  // 1. Thermal Fault ('T')
                  _QuickControlCard(
                    title: 'Thermal Fault',
                    subtitle: 'Injects 48.5°C state',
                    code: 'T',
                    icon: Icons.local_fire_department_rounded,
                    accentColor: yellowAccent,
                    enabled: isConnected && !isPending,
                    onPressed: () => controller.sendCommand('T', 'Thermal Fault'),
                  ),
                  // 2. Vibration Fault ('D')
                  _QuickControlCard(
                    title: 'Vibration Fault',
                    subtitle: 'Triggers SW-420 DO',
                    code: 'D',
                    icon: Icons.vibration_rounded,
                    accentColor: yellowAccent,
                    enabled: isConnected && !isPending,
                    onPressed: () => controller.sendCommand('D', 'Vibration Fault'),
                  ),
                  // 3. Water Leak ('L')
                  _QuickControlCard(
                    title: 'Water Leak',
                    subtitle: 'Injects 1200 ADC leak',
                    code: 'L',
                    icon: Icons.water_drop_rounded,
                    accentColor: yellowAccent,
                    enabled: isConnected && !isPending,
                    onPressed: () => controller.sendCommand('L', 'Water Leak'),
                  ),
                  // 4. Clear Faults ('C')
                  _QuickControlCard(
                    title: 'Clear Faults',
                    subtitle: 'Restores physical sensors',
                    code: 'C',
                    icon: Icons.cleaning_services_rounded,
                    accentColor: const Color(0xFF00E676),
                    enabled: isConnected && !isPending,
                    onPressed: () => controller.sendCommand('C', 'Clear Faults'),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _QuickControlCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final String code;
  final IconData icon;
  final Color accentColor;
  final bool enabled;
  final VoidCallback onPressed;

  const _QuickControlCard({
    required this.title,
    required this.subtitle,
    required this.code,
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
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          constraints: const BoxConstraints(minHeight: 48, minWidth: 48),
          decoration: BoxDecoration(
            color: const Color(0xFF08090B),
            borderRadius: BorderRadius.circular(10),
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
                  Icon(icon, color: effectiveColor, size: 18),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                    decoration: BoxDecoration(
                      color: effectiveColor.withValues(alpha: 0.2),
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
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: titleColor,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: Color(0xFFA0A0A0),
                      fontSize: 9,
                    ),
                    maxLines: 1,
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
