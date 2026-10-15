import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Handles phone vibration for critical predictive maintenance events.
/// Implements strict deduplication so vibration triggers ONLY ONCE
/// per newly detected critical event.
class VibrationService {
  bool _isCriticalActive = false;

  /// Check whether the phone currently considers critical vibration armed/active
  bool get isCriticalActive => _isCriticalActive;

  /// Process new telemetry risk/status state.
  /// Trigger a brief vibration ONLY when transitioning into a CRITICAL event.
  Future<void> handleCriticalStateChange(bool isCritical) async {
    if (isCritical) {
      if (!_isCriticalActive) {
        // State transition: NON-CRITICAL -> CRITICAL
        _isCriticalActive = true;
        await _vibratePattern();
      }
    } else {
      // System recovered to SAFE or MODERATE
      _isCriticalActive = false;
    }
  }

  /// Perform a brief, distinct haptic vibration for critical alerts.
  Future<void> _vibratePattern() async {
    try {
      // First impact
      await HapticFeedback.heavyImpact();
      await Future.delayed(const Duration(milliseconds: 150));
      // Second impact for double-pulse alert pattern
      await HapticFeedback.heavyImpact();
    } catch (e) {
      debugPrint('Vibration service error: $e');
    }
  }

  /// Reset internal vibration state tracking manually if required.
  void reset() {
    _isCriticalActive = false;
  }
}
