enum AlertSeverity { info, warning, critical }

class MachineAlert {
  final String id;
  final AlertSeverity severity;
  final String title;
  final String cause;
  final String recommendation;
  final int? riskScore;
  final DateTime timestamp;
  final bool isAcknowledged;

  const MachineAlert({
    required this.id,
    required this.severity,
    required this.title,
    required this.cause,
    required this.recommendation,
    this.riskScore,
    required this.timestamp,
    this.isAcknowledged = false,
  });

  MachineAlert copyWith({
    bool? isAcknowledged,
  }) {
    return MachineAlert(
      id: id,
      severity: severity,
      title: title,
      cause: cause,
      recommendation: recommendation,
      riskScore: riskScore,
      timestamp: timestamp,
      isAcknowledged: isAcknowledged ?? this.isAcknowledged,
    );
  }
}
