import 'package:flutter/material.dart';
import '../controllers/machine_controller.dart';
import '../models/machine_alert.dart';
import '../widgets/connection_badge.dart';

class AlertsScreen extends StatefulWidget {
  final MachineController controller;

  const AlertsScreen({
    super.key,
    required this.controller,
  });

  @override
  State<AlertsScreen> createState() => _AlertsScreenState();
}

class _AlertsScreenState extends State<AlertsScreen> {
  String _selectedFilter = 'ALL'; // ALL, CRITICAL, WARNING

  @override
  Widget build(BuildContext context) {
    const yellowAccent = Color(0xFFF5D400);

    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, child) {
        final allAlerts = widget.controller.alerts;

        final filteredAlerts = allAlerts.where((alert) {
          if (_selectedFilter == 'CRITICAL') return alert.severity == AlertSeverity.critical;
          if (_selectedFilter == 'WARNING') return alert.severity == AlertSeverity.warning;
          return true;
        }).toList();

        final unackCount = allAlerts.where((a) => !a.isAcknowledged).length;

        return Scaffold(
          backgroundColor: const Color(0xFF08090B),
          appBar: AppBar(
            backgroundColor: const Color(0xFF08090B),
            title: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'SYSTEM ALERT CENTER',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.1,
                  ),
                ),
                Text(
                  'Edge Rule Engine Log',
                  style: TextStyle(color: Color(0xFFA0A0A0), fontSize: 10),
                ),
              ],
            ),
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: 12.0),
                child: ConnectionBadge(controller: widget.controller),
              ),
            ],
          ),
          body: SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 800),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Filter Chips & Acknowledge All Action
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Wrap(
                            spacing: 8,
                            children: [
                              _FilterChip(
                                label: 'ALL (${allAlerts.length})',
                                isSelected: _selectedFilter == 'ALL',
                                accentColor: yellowAccent,
                                onSelected: () => setState(() => _selectedFilter = 'ALL'),
                              ),
                              _FilterChip(
                                label: 'CRITICAL',
                                isSelected: _selectedFilter == 'CRITICAL',
                                accentColor: const Color(0xFFFF3D00),
                                onSelected: () => setState(() => _selectedFilter = 'CRITICAL'),
                              ),
                              _FilterChip(
                                label: 'WARNING',
                                isSelected: _selectedFilter == 'WARNING',
                                accentColor: yellowAccent,
                                onSelected: () => setState(() => _selectedFilter = 'WARNING'),
                              ),
                            ],
                          ),
                          if (unackCount > 0)
                            TextButton(
                              onPressed: () {
                                for (var alert in allAlerts) {
                                  widget.controller.acknowledgeAlert(alert.id);
                                }
                              },
                              style: TextButton.styleFrom(
                                foregroundColor: const Color(0xFF00E676),
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              ),
                              child: const Text('Ack All', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                            ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Alert List
                      Expanded(
                        child: filteredAlerts.isEmpty
                            ? Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(Icons.check_circle_outline, color: Color(0xFF00E676), size: 48),
                                    const SizedBox(height: 12),
                                    Text(
                                      _selectedFilter == 'ALL'
                                          ? 'NO ACTIVE ALERTS'
                                          : 'NO $_selectedFilter ALERTS',
                                      style: const TextStyle(
                                        color: Color(0xFF00E676),
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    const Text(
                                      'Machine telemetric rules report nominal operational status.',
                                      style: TextStyle(color: Color(0xFFA0A0A0), fontSize: 11),
                                    ),
                                  ],
                                ),
                              )
                            : ListView.separated(
                                itemCount: filteredAlerts.length,
                                separatorBuilder: (ctx, idx) => const SizedBox(height: 12),
                                itemBuilder: (ctx, idx) {
                                  final alert = filteredAlerts[idx];
                                  return _AlertDetailCard(
                                    alert: alert,
                                    onAcknowledge: () => widget.controller.acknowledgeAlert(alert.id),
                                  );
                                },
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
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final Color accentColor;
  final VoidCallback onSelected;

  const _FilterChip({
    required this.label,
    required this.isSelected,
    this.accentColor = const Color(0xFFF5D400),
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final color = isSelected ? accentColor : const Color(0xFFA0A0A0);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onSelected,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          constraints: const BoxConstraints(minHeight: 40, minWidth: 48),
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: isSelected ? color.withValues(alpha: 0.18) : const Color(0xFF151619),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: color.withValues(alpha: isSelected ? 0.8 : 0.3)),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: isSelected ? Colors.white : const Color(0xFFA0A0A0),
              fontSize: 10,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
      ),
    );
  }
}

class _AlertDetailCard extends StatelessWidget {
  final MachineAlert alert;
  final VoidCallback onAcknowledge;

  const _AlertDetailCard({
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
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF151619),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isAck ? const Color(0xFF22242B) : color.withValues(alpha: 0.7),
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
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    alert.title,
                    style: TextStyle(
                      color: isAck ? const Color(0xFFA0A0A0) : Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
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
          const SizedBox(height: 8),
          Text(
            'Root Cause: ${alert.cause}',
            style: const TextStyle(color: Color(0xFFCBD5E1), fontSize: 12),
          ),
          const SizedBox(height: 4),
          Text(
            'Recommendation: ${alert.recommendation}',
            style: const TextStyle(color: Color(0xFFA0A0A0), fontSize: 11),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              if (alert.riskScore != null)
                Text(
                  'Recorded Risk: ${alert.riskScore}%',
                  style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold),
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
                    minimumSize: const Size(48, 36),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    elevation: 1,
                  ),
                  icon: const Icon(Icons.check_circle_outline, size: 14),
                  label: const Text('Acknowledge', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                )
              else
                const Row(
                  children: [
                    Icon(Icons.check_rounded, size: 14, color: Color(0xFFA0A0A0)),
                    SizedBox(width: 4),
                    Text(
                      'Acknowledged',
                      style: TextStyle(color: Color(0xFFA0A0A0), fontSize: 10, fontStyle: FontStyle.italic),
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
