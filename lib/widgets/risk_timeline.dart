import 'package:flutter/material.dart';
import '../models/telemetry.dart';

class RiskTimeline extends StatelessWidget {
  final List<TelemetryData> history; // Last 60 telemetry readings

  const RiskTimeline({
    super.key,
    required this.history,
  });

  @override
  Widget build(BuildContext context) {
    const cardBg = Color(0xFF151619);
    const borderCol = Color(0xFF22242B);
    const yellowAccent = Color(0xFFF5D400);

    final hasData = history.isNotEmpty;

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
          // Header Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.show_chart_rounded, color: yellowAccent, size: 18),
                  SizedBox(width: 8),
                  Text(
                    'Risk History Trend',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: hasData
                      ? yellowAccent.withValues(alpha: 0.15)
                      : const Color(0xFF22242B),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: hasData ? yellowAccent : const Color(0xFF383A42),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: hasData ? yellowAccent : const Color(0xFFA0A0A0),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      hasData ? 'LIVE' : 'WAITING',
                      style: TextStyle(
                        color: hasData ? yellowAccent : const Color(0xFFA0A0A0),
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Bounded Chart Canvas Area (Height: 180px)
          SizedBox(
            height: 180,
            width: double.infinity,
            child: !hasData
                ? CustomPaint(
                    painter: TimelinePlaceholderPainter(),
                    child: const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.timeline_rounded, color: Color(0xFFA0A0A0), size: 32),
                          SizedBox(height: 8),
                          Text(
                            'Awaiting Telemetry Stream',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Connect Bluetooth to render live machine risk score trends',
                            style: TextStyle(color: Color(0xFFA0A0A0), fontSize: 10),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  )
                : CustomPaint(
                    painter: TimelinePainter(history: history),
                  ),
          ),
        ],
      ),
    );
  }
}

class TimelinePainter extends CustomPainter {
  final List<TelemetryData> history;

  TimelinePainter({required this.history});

  @override
  void paint(Canvas canvas, Size size) {
    if (history.isEmpty) return;

    final double width = size.width;
    final double height = size.height;

    // Horizontal grid lines & threshold labels
    final gridLinePaint = Paint()
      ..color = const Color(0xFF22242B)
      ..strokeWidth = 1.0;

    // Warning threshold line (35%)
    final warnY = height - (0.35 * height);
    final warnPaint = Paint()
      ..color = const Color(0xFFF5D400).withValues(alpha: 0.3)
      ..strokeWidth = 1.0;
    canvas.drawLine(Offset(0, warnY), Offset(width, warnY), warnPaint);

    // Critical threshold line (70%)
    final critY = height - (0.70 * height);
    final critPaint = Paint()
      ..color = const Color(0xFFFF3D00).withValues(alpha: 0.3)
      ..strokeWidth = 1.0;
    canvas.drawLine(Offset(0, critY), Offset(width, critY), critPaint);

    // Baseline grid lines
    for (int i = 1; i <= 3; i++) {
      double y = height * (i / 4.0);
      canvas.drawLine(Offset(0, y), Offset(width, y), gridLinePaint);
    }

    // Plot risk curve
    double stepX = history.length > 1 ? width / (60 - 1) : width;
    double startX = width - ((history.length - 1) * stepX);

    final path = Path();
    final fillPath = Path();
    final points = <Offset>[];

    for (int i = 0; i < history.length; i++) {
      double x = startX + (i * stepX);
      double clampedRisk = history[i].risk.clamp(0, 100).toDouble();
      double y = height - (clampedRisk / 100.0 * height);
      Offset p = Offset(x, y);
      points.add(p);

      if (i == 0) {
        path.moveTo(x, y);
        fillPath.moveTo(x, height);
        fillPath.lineTo(x, y);
      } else {
        path.lineTo(x, y);
        fillPath.lineTo(x, y);
      }
    }

    if (points.isNotEmpty) {
      fillPath.lineTo(points.last.dx, height);
      fillPath.close();

      // Area fill gradient
      final fillPaint = Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            const Color(0xFFF5D400).withValues(alpha: 0.25),
            const Color(0xFFF5D400).withValues(alpha: 0.0),
          ],
        ).createShader(Rect.fromLTWH(0, 0, width, height));

      canvas.drawPath(fillPath, fillPaint);
    }

    // Line stroke
    final linePaint = Paint()
      ..color = const Color(0xFFF5D400)
      ..strokeWidth = 2.2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    canvas.drawPath(path, linePaint);

    // Current reading dot
    if (points.isNotEmpty) {
      final lastPoint = points.last;

      final dotOuterPaint = Paint()
        ..color = const Color(0xFFF5D400).withValues(alpha: 0.4);
      canvas.drawCircle(lastPoint, 6.0, dotOuterPaint);

      final dotInnerPaint = Paint()..color = const Color(0xFFF5D400);
      canvas.drawCircle(lastPoint, 3.5, dotInnerPaint);
    }
  }

  @override
  bool shouldRepaint(covariant TimelinePainter oldDelegate) {
    return oldDelegate.history.length != history.length ||
        (history.isNotEmpty && oldDelegate.history.isNotEmpty &&
            oldDelegate.history.last.timestamp != history.last.timestamp);
  }
}

class TimelinePlaceholderPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final double width = size.width;
    final double height = size.height;

    final gridLinePaint = Paint()
      ..color = const Color(0xFF1E2026)
      ..strokeWidth = 1.0;

    for (int i = 1; i <= 4; i++) {
      double y = height * (i / 5.0);
      canvas.drawLine(Offset(0, y), Offset(width, y), gridLinePaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
