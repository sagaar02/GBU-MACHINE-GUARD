import 'package:flutter/material.dart';
import '../controllers/machine_controller.dart';
import '../services/bluetooth_service.dart';
import '../widgets/connection_badge.dart';
import '../widgets/risk_gauge.dart';
import '../widgets/sensor_grid.dart';
import '../widgets/risk_timeline.dart';
import '../widgets/machine_controls.dart';

class DashboardScreen extends StatelessWidget {
  final MachineController controller;
  final ValueChanged<int>? onNavigateToTab;

  const DashboardScreen({
    super.key,
    required this.controller,
    this.onNavigateToTab,
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
        final isStale = isConnected && controller.isDataStale;

        return Scaffold(
          backgroundColor: const Color(0xFF08090B),
          appBar: AppBar(
            backgroundColor: const Color(0xFF08090B),
            elevation: 0,
            toolbarHeight: 64,
            title: Row(
              children: [
                // Yellow square icon logo
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: yellowAccent,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.area_chart_rounded,
                    color: Colors.black,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 10),
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'GBU',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                    Text(
                      'PREDICTIVE MAINTENANCE',
                      style: TextStyle(
                        color: Color(0xFFA0A0A0),
                        fontSize: 9,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ],
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
                  padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 10.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Disconnected Guidance Banner
                      if (!isConnected) ...[
                        Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFF3D00).withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFFFF3D00).withValues(alpha: 0.4)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.bluetooth_searching, color: Color(0xFFFF3D00), size: 18),
                              const SizedBox(width: 8),
                              const Expanded(
                                child: Text(
                                  'BLUETOOTH DISCONNECTED: Connect to EdgeAI_Predictive_Node to view live telemetry.',
                                  style: TextStyle(
                                    color: Color(0xFFFF3D00),
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              TextButton(
                                onPressed: () => controller.connect(),
                                style: TextButton.styleFrom(
                                  foregroundColor: yellowAccent,
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  minimumSize: Size.zero,
                                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                ),
                                child: const Text('Connect', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                              ),
                            ],
                          ),
                        ),
                      ],

                      // Stale Data Warning Banner
                      if (isStale) ...[
                        Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: yellowAccent.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: yellowAccent),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.timer_off_outlined, color: yellowAccent, size: 18),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'STALE TELEMETRY: Last JSON packet arrived ${controller.dataAgeSeconds}s ago.',
                                  style: const TextStyle(
                                    color: yellowAccent,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],

                      // 1. Machine Health Card (Centered Risk Gauge)
                      RiskGauge(
                        riskScore: telemetry.risk,
                        status: telemetry.status,
                        cause: telemetry.cause,
                        timestamp: telemetry.timestamp,
                        isValid: isValid,
                      ),

                      const SizedBox(height: 12),

                      // 2. 2x2 Sensor Summaries Grid
                      SensorGrid(
                        telemetry: telemetry,
                        isValid: isValid,
                        isSoundMonitoringActive: controller.soundMonitor.isMonitoring,
                      ),

                      const SizedBox(height: 12),

                      // 3. Risk History Card (Sparkline Chart)
                      RiskTimeline(history: controller.history),

                      const SizedBox(height: 12),

                      // 4. Quick Controls Card
                      MachineControls(controller: controller),

                      const SizedBox(height: 16),
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
}
