import 'package:flutter/material.dart';
import '../controllers/machine_controller.dart';
import '../services/bluetooth_service.dart';

/// Reusable full-screen Emergency Stop Overlay.
/// Displays over any active tab when a latched emergency condition exists.
class EmergencyStopOverlay extends StatefulWidget {
  final MachineController controller;

  const EmergencyStopOverlay({
    super.key,
    required this.controller,
  });

  @override
  State<EmergencyStopOverlay> createState() => _EmergencyStopOverlayState();
}

class _EmergencyStopOverlayState extends State<EmergencyStopOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );

    _scaleAnimation = Tween<double>(begin: 0.88, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutBack),
    );

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.12).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );

    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const cardBg = Color(0xFF151619);
    const redAccent = Color(0xFFFF3D00);

    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, child) {
        final telemetry = widget.controller.telemetry;
        final isBtConnected = widget.controller.connectionState == DeviceBtState.connected;
        final cause = telemetry.cause.isNotEmpty ? telemetry.cause.toUpperCase() : 'CRITICAL THRESHOLD BREACHED';
        final isDismissedLocal = widget.controller.isEmergencyOverlayAcknowledged;

        if (isDismissedLocal) {
          // User acknowledged overlay visually, but latched emergency badge remains active in app bar
          return const SizedBox.shrink();
        }

        return FadeTransition(
          opacity: _fadeAnimation,
          child: Material(
            color: Colors.transparent,
            child: Container(
              color: Colors.black.withValues(alpha: 0.88),
              child: SafeArea(
                child: Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    child: ScaleTransition(
                      scale: _scaleAnimation,
                      child: Container(
                        constraints: const BoxConstraints(maxWidth: 460),
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: cardBg,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: redAccent, width: 2.0),
                          boxShadow: [
                            BoxShadow(
                              color: redAccent.withValues(alpha: 0.35),
                              blurRadius: 24,
                              spreadRadius: 4,
                            ),
                          ],
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Emergency Icon with Restrained Pulse
                            ScaleTransition(
                              scale: _pulseAnimation,
                              child: Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: redAccent.withValues(alpha: 0.18),
                                  shape: BoxShape.circle,
                                  border: Border.all(color: redAccent, width: 2),
                                ),
                                child: const Icon(
                                  Icons.report_problem_rounded,
                                  color: redAccent,
                                  size: 44,
                                ),
                              ),
                            ),
                            const SizedBox(height: 14),

                            // Heading
                            const Text(
                              'EMERGENCY STOP',
                              style: TextStyle(
                                color: redAccent,
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.2,
                              ),
                            ),
                            const SizedBox(height: 6),

                            // Connection Warning Badge if lost
                            if (!isBtConnected) ...[
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFF3D00).withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: const Color(0xFFFF3D00)),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.bluetooth_disabled, color: Colors.white, size: 14),
                                    SizedBox(width: 6),
                                    Text(
                                      'CONNECTION LOST — EMERGENCY LATCHED',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 10),
                            ],

                            // Critical Cause Display Card
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(0xFF08090B),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: redAccent.withValues(alpha: 0.5)),
                              ),
                              child: Column(
                                children: [
                                  const Text(
                                    'CRITICAL TRIGGER REASON',
                                    style: TextStyle(
                                      color: Color(0xFFA0A0A0),
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 0.8,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    cause,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 14),

                            // Sensor Readings Summary
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(0xFF08090B),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: const Color(0xFF22242B)),
                              ),
                              child: Column(
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      const Text('Machine Risk Score:', style: TextStyle(color: Color(0xFFA0A0A0), fontSize: 11)),
                                      Text('${telemetry.risk}%', style: const TextStyle(color: redAccent, fontWeight: FontWeight.bold, fontSize: 13)),
                                    ],
                                  ),
                                  const Divider(color: Color(0xFF22242B), height: 12),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      const Text('Temperature:', style: TextStyle(color: Color(0xFFA0A0A0), fontSize: 11)),
                                      Text('${telemetry.temp.toStringAsFixed(1)} °C', style: const TextStyle(color: Colors.white, fontSize: 11, fontFamily: 'monospace')),
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      const Text('SW-420 Vibration:', style: TextStyle(color: Color(0xFFA0A0A0), fontSize: 11)),
                                      Text(telemetry.isVibrationDetected ? 'DETECTED' : 'CLEAR', style: TextStyle(color: telemetry.isVibrationDetected ? redAccent : Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      const Text('Water Sensor:', style: TextStyle(color: Color(0xFFA0A0A0), fontSize: 11)),
                                      Text('${telemetry.water} ADC', style: const TextStyle(color: Colors.white, fontSize: 11, fontFamily: 'monospace')),
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      const Text('Sound Monitoring:', style: TextStyle(color: Color(0xFFA0A0A0), fontSize: 11)),
                                      Text('${(telemetry.soundLevel * 100).toInt()}%', style: TextStyle(color: telemetry.isAbnormalSound ? redAccent : Colors.white, fontSize: 11, fontFamily: 'monospace')),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),

                            // Action Buttons
                            Row(
                              children: [
                                // Acknowledge Button
                                Expanded(
                                  child: OutlinedButton(
                                    onPressed: () {
                                      widget.controller.acknowledgeEmergencyOverlay();
                                    },
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: Colors.white,
                                      side: const BorderSide(color: Color(0xFF383A42)),
                                      padding: const EdgeInsets.symmetric(vertical: 12),
                                      minimumSize: const Size(48, 48),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                    ),
                                    child: const Text('Acknowledge', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                  ),
                                ),
                                const SizedBox(width: 10),

                                // Emergency Reset Button ('R')
                                Expanded(
                                  child: ElevatedButton(
                                    onPressed: isBtConnected
                                        ? () {
                                            widget.controller.requestSystemReset();
                                          }
                                        : null,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: redAccent,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(vertical: 12),
                                      minimumSize: const Size(48, 48),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                    ),
                                    child: const Text('Reset Hardware ("R")', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            const Text(
                              'Note: Recovery of physical sensors does not clear a latched emergency. Hardwired safety interlocks operate independently.',
                              style: TextStyle(color: Color(0xFFA0A0A0), fontSize: 9),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
