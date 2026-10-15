import 'dart:math';
import 'package:flutter/material.dart';

class RiskGauge extends StatefulWidget {
  final int riskScore; // 0..100
  final String status;
  final String cause;
  final DateTime timestamp;
  final bool isValid;

  const RiskGauge({
    super.key,
    required this.riskScore,
    required this.status,
    required this.cause,
    required this.timestamp,
    required this.isValid,
  });

  @override
  State<RiskGauge> createState() => _RiskGaugeState();
}

class _RiskGaugeState extends State<RiskGauge> with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Color get statusColor {
    if (!widget.isValid) return const Color(0xFF6E7280);
    if (widget.riskScore >= 70 || widget.status == 'CRITICAL') {
      return const Color(0xFFFF3D00); // Vibrant Red
    }
    if (widget.riskScore >= 35 || widget.status == 'MODERATE' || widget.status == 'WARNING') {
      return const Color(0xFFFFC107); // Amber/Yellow
    }
    return const Color(0xFF00E676); // Vibrant Green (SAFE/NOMINAL)
  }

  String get statusText {
    if (!widget.isValid) return 'OFFLINE / AWAITING DATA';
    if (widget.riskScore >= 70 || widget.status == 'CRITICAL') return 'CRITICAL';
    if (widget.riskScore >= 35 || widget.status == 'MODERATE' || widget.status == 'WARNING') {
      return 'MODERATE';
    }
    return 'SAFE';
  }

  IconData get statusIcon {
    if (!widget.isValid) return Icons.offline_bolt_outlined;
    if (widget.riskScore >= 70 || widget.status == 'CRITICAL') return Icons.report_problem_rounded;
    if (widget.riskScore >= 35 || widget.status == 'MODERATE' || widget.status == 'WARNING') {
      return Icons.warning_amber_rounded;
    }
    return Icons.check_circle_outline_rounded;
  }

  String get recommendedAction {
    if (!widget.isValid) return 'Connect Bluetooth telemetry stream to monitor live risk.';
    if (widget.riskScore >= 70 || widget.status == 'CRITICAL') {
      return 'Halt machine operation immediately and perform emergency hardware check.';
    }
    if (widget.riskScore >= 35 || widget.status == 'MODERATE' || widget.status == 'WARNING') {
      return 'Monitor machine closely. Schedule preventive maintenance before failure.';
    }
    return 'All sensor parameters within nominal baseline limits.';
  }

  @override
  Widget build(BuildContext context) {
    final sColor = statusColor;
    final isCritical = widget.isValid && (widget.riskScore >= 70 || widget.status == 'CRITICAL');
    final isModerate = widget.isValid && (widget.riskScore >= 35 || widget.status == 'MODERATE' || widget.status == 'WARNING');

    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        final scale = (isCritical || isModerate) ? _pulseAnimation.value : 1.0;

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
          decoration: BoxDecoration(
            color: const Color(0xFF000000), // OLED Black
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: sColor.withValues(alpha: isCritical ? 0.9 : (isModerate ? 0.6 : 0.2)),
              width: isCritical ? 2.0 : 1.0,
            ),
            boxShadow: isCritical
                ? [
                    BoxShadow(
                      color: const Color(0xFFFF3D00).withValues(alpha: 0.25 * scale),
                      blurRadius: 16 * scale,
                      spreadRadius: 2,
                    )
                  ]
                : (isModerate
                    ? [
                        BoxShadow(
                          color: const Color(0xFFFFC107).withValues(alpha: 0.15 * scale),
                          blurRadius: 12 * scale,
                        )
                      ]
                    : null),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header title: MACHINE HEALTH
              const Text(
                'MACHINE HEALTH',
                style: TextStyle(
                  color: Color(0xFF9E9E9E),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 18),

              // Circular Animated Gauge
              SizedBox(
                width: 190,
                height: 190,
                child: TweenAnimationBuilder<double>(
                  tween: Tween<double>(begin: 0.0, end: widget.isValid ? widget.riskScore / 100.0 : 0.0),
                  duration: const Duration(milliseconds: 600),
                  curve: Curves.easeOutCubic,
                  builder: (context, value, child) {
                    return CustomPaint(
                      painter: FullRingGaugePainter(
                        progress: value,
                        ringColor: sColor,
                      ),
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              widget.isValid ? '${(value * 100).toInt()}%' : '--',
                              style: TextStyle(
                                color: sColor,
                                fontSize: 36,
                                fontWeight: FontWeight.bold,
                                fontFamily: 'sans-serif',
                              ),
                            ),
                            const SizedBox(height: 2),
                            const Text(
                              'RISK SCORE',
                              style: TextStyle(
                                color: Color(0xFF9E9E9E),
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 1.1,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 18),

              // Status Row
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    statusIcon,
                    color: sColor,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    statusText,
                    style: TextStyle(
                      color: sColor,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.8,
                    ),
                  ),
                ],
              ),

              if (widget.isValid) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: sColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: sColor.withValues(alpha: 0.3)),
                  ),
                  child: Column(
                    children: [
                      Text(
                        'Primary Cause: ${widget.cause}',
                        style: TextStyle(
                          color: sColor,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        recommendedAction,
                        style: const TextStyle(
                          color: Color(0xFFCBD5E1),
                          fontSize: 10,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class FullRingGaugePainter extends CustomPainter {
  final double progress; // 0.0 to 1.0
  final Color ringColor;

  FullRingGaugePainter({
    required this.progress,
    required this.ringColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width / 2) - 12;

    const startAngle = -pi / 2; // Top 12 o'clock position
    const totalSweep = 2 * pi;

    // Track background ring
    final bgPaint = Paint()
      ..color = const Color(0xFF1E2026)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10;

    canvas.drawCircle(center, radius, bgPaint);

    // Active progress arc
    final progressPaint = Paint()
      ..color = ringColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10
      ..strokeCap = StrokeCap.round;

    if (progress > 0) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        totalSweep * progress,
        false,
        progressPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant FullRingGaugePainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.ringColor != ringColor;
  }
}
