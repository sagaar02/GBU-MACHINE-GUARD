import 'package:flutter/material.dart';
import '../models/machine_alert.dart';
import '../controllers/machine_controller.dart';

class AlertFeed extends StatelessWidget {
  final MachineController controller;

  const AlertFeed({
    super.key,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    final alerts = controller.alerts;
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
              Row(
                children: [
                  const Icon(Icons.notifications_active_rounded, color: yellowAccent, size: 18),
                  const SizedBox(width: 8),
                  const Text(
                    'SYSTEM ALERT FEED',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.0,
                    ),
                  ),
                  if (alerts.where((a) => !a.isAcknowledged).isNotEmpty) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFF3D00),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${alerts.where((a) => !a.isAcknowledged).length} NEW',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              const Text(
                'Edge Engine Log',
                style: TextStyle(color: Color(0xFFA0A0A0), fontSize: 10),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (alerts.isEmpty)
            Container(
              padding: const EdgeInsets.all(20),
              alignment: Alignment.center,
              child: const Column(
                children: [
                  Icon(Icons.check_circle_outline, color: Color(0xFF00E676), size: 36),
                  SizedBox(height: 8),
                  Text(
                    'ALL SYSTEMS NOMINAL',
                    style: TextStyle(
                      color: Color(0xFF00E676),
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'No active warnings or emergency trip state transitions detected.',
                    style: TextStyle(color: Color(0xFFA0A0A0), fontSize: 11),
                  ),
                ],
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: alerts.length > 8 ? 8 : alerts.length,
              separatorBuilder: (ctx, idx) => const SizedBox(height: 10),
              itemBuilder: (ctx, idx) {
                final alert = alerts[idx];
                return _AlertTile(
                  alert: alert,
                  onAcknowledge: () => controller.acknowledgeAlert(alert.id),
                );
              },
            ),
        ],
      ),
    );
  }
}

class _AlertTile extends StatelessWidget {
  final MachineAlert alert;
  final VoidCallback onAcknowledge;

  const _AlertTile({
    required this.alert,
    required this.onAcknowledge,
  });

  Color get severityColor {
    switch (alert.severity) {
      case AlertSeverity.critical:
        return const Color(0xFFFF3D00);
      case AlertSeverity.warning:
        return const Color(0xFFF5D400);
      case AlertSeverity.info:
        return const Color(0xFF38BDF8);
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = severityColor;
    final isAck = alert.isAcknowledged;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF08090B),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isAck ? const Color(0xFF22242B) : color.withValues(alpha: 0.6),
          width: isAck ? 1.0 : 1.5,
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
                    alert.severity == AlertSeverity.critical
                        ? Icons.report_problem_rounded
                        : Icons.info_outline_rounded,
                    color: isAck ? const Color(0xFFA0A0A0) : color,
                    size: 16,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    alert.title,
                    style: TextStyle(
                      color: isAck ? const Color(0xFFA0A0A0) : Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      decoration: isAck ? TextDecoration.lineThrough : null,
                    ),
                  ),
                ],
              ),
              Text(
                '${alert.timestamp.hour.toString().padLeft(2, '0')}:${alert.timestamp.minute.toString().padLeft(2, '0')}:${alert.timestamp.second.toString().padLeft(2, '0')}',
                style: const TextStyle(
                  color: Color(0xFFA0A0A0),
                  fontSize: 10,
                  fontFamily: 'monospace',
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Cause: ${alert.cause}',
            style: const TextStyle(color: Color(0xFFCBD5E1), fontSize: 11),
          ),
          const SizedBox(height: 4),
          Text(
            'Recommendation: ${alert.recommendation}',
            style: const TextStyle(color: Color(0xFFA0A0A0), fontSize: 10),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              if (alert.riskScore != null)
                Text(
                  'Risk Score: ${alert.riskScore}%',
                  style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold),
                )
              else
                const SizedBox.shrink(),
              if (!isAck)
                ElevatedButton.icon(
                  onPressed: onAcknowledge,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00E676),
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    minimumSize: const Size(48, 34),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    elevation: 1,
                  ),
                  icon: const Icon(Icons.check_circle_outline, size: 14),
                  label: const Text('Acknowledge', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                )
              else
                const Row(
                  children: [
                    Icon(Icons.check_rounded, size: 12, color: Color(0xFFA0A0A0)),
                    SizedBox(width: 2),
                    Text(
                      'Acknowledged',
                      style: TextStyle(color: Color(0xFFA0A0A0), fontSize: 9, fontStyle: FontStyle.italic),
                    ),
                  ],
                ),
            ],
          ),
        ],
      ),
    );
  }
}
