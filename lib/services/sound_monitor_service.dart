import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';

enum SoundMonitorState {
  idle,
  starting,
  running,
  stopping,
  permissionRequired,
}

/// Manages phone microphone sound capture, local audio feature extraction,
/// and privacy/consent controls.
class SoundMonitorService extends ChangeNotifier {
  final AudioRecorder _audioRecorder = AudioRecorder();

  SoundMonitorState _state = SoundMonitorState.idle;
  SoundMonitorState get state => _state;

  bool get isMonitoring => _state == SoundMonitorState.running;

  bool _hasPermission = false;
  bool get hasPermission => _hasPermission;

  double _lastLevel = 0.0; // Relative normalized sound level 0.0 to 1.0
  double get lastLevel => isMonitoring ? _lastLevel : 0.0;
  double get currentLevel => isMonitoring ? _lastLevel : 0.0;

  double _lastPeak = 0.0; // Relative normalized peak level 0.0 to 1.0
  double get lastPeak => isMonitoring ? _lastPeak : 0.0;
  double get currentPeak => isMonitoring ? _lastPeak : 0.0;

  String get displayLevel => isMonitoring ? '${(_lastLevel * 100).toStringAsFixed(0)}%' : '--';
  String get displayPeak => isMonitoring ? '${(_lastPeak * 100).toStringAsFixed(0)}%' : '--';

  String get statusBadgeText {
    switch (_state) {
      case SoundMonitorState.running:
        return 'LISTENING';
      case SoundMonitorState.starting:
        return 'STARTING';
      case SoundMonitorState.stopping:
        return 'STOPPING';
      case SoundMonitorState.permissionRequired:
        return 'PERMISSION REQUIRED';
      case SoundMonitorState.idle:
        return 'OFF';
    }
  }

  int _sequenceId = 0;
  int _sessionId = 0;

  double _smoothedLevel = 0.0;
  double _smoothedPeak = 0.0;

  String _statusMessage = 'Sound Monitoring Disabled';
  String get statusMessage => _statusMessage;

  Timer? _sampleTimer;
  StreamController<Map<String, dynamic>>? _soundFeatureController;
  Stream<Map<String, dynamic>> get soundFeatureStream =>
      _soundFeatureController?.stream ?? const Stream.empty();

  SoundMonitorService() {
    _soundFeatureController = StreamController<Map<String, dynamic>>.broadcast();
  }

  /// Request runtime microphone permission from Android system dialog.
  Future<bool> requestMicrophonePermission() async {
    try {
      var status = await Permission.microphone.request();
      _hasPermission = status.isGranted;
      if (!_hasPermission) {
        _state = SoundMonitorState.permissionRequired;
        _statusMessage = 'Sound Monitoring Disabled: Permission required.';
      } else {
        _statusMessage = 'Microphone permission granted.';
      }
      notifyListeners();
      return _hasPermission;
    } catch (e) {
      debugPrint('Error requesting microphone permission: $e');
      _state = SoundMonitorState.permissionRequired;
      _statusMessage = 'Sound Monitoring Disabled: Permission failed ($e)';
      notifyListeners();
      return false;
    }
  }

  /// Start acoustic sound monitoring using the phone's built-in microphone.
  Future<bool> startMonitoring() async {
    if (_state == SoundMonitorState.starting || _state == SoundMonitorState.running) {
      return true;
    }

    _state = SoundMonitorState.starting;
    _statusMessage = 'Initializing Microphone...';
    notifyListeners();

    if (!_hasPermission) {
      bool granted = await requestMicrophonePermission();
      if (!granted) {
        _state = SoundMonitorState.permissionRequired;
        _statusMessage = 'Sound Monitoring Disabled: Permission required.';
        notifyListeners();
        return false;
      }
    }

    try {
      // Check plugin recording capability
      bool isRecordingAvailable = await _audioRecorder.hasPermission();
      if (!isRecordingAvailable) {
        _state = SoundMonitorState.permissionRequired;
        _statusMessage = 'Sound Monitoring Disabled: System unpermitted.';
        notifyListeners();
        return false;
      }

      // Increment session ID so any stale timer callbacks from past sessions are ignored
      _sessionId++;
      final currentSession = _sessionId;

      // Start actual audio recording session so getAmplitude captures live mic input
      if (!await _audioRecorder.isRecording()) {
        final tempPath = '${Directory.systemTemp.path}/gbu_mic_stream.m4a';
        await _audioRecorder.start(
          const RecordConfig(encoder: AudioEncoder.aacLc),
          path: tempPath,
        );
      }

      // Check if user clicked Stop while recorder was starting
      if (_state != SoundMonitorState.starting || _sessionId != currentSession) {
        await _audioRecorder.stop();
        _lastLevel = 0.0;
        _lastPeak = 0.0;
        _state = SoundMonitorState.idle;
        _statusMessage = 'Sound Monitoring Disabled';
        notifyListeners();
        return false;
      }

      _state = SoundMonitorState.running;
      _statusMessage = 'Listening (Phone Microphone)';
      notifyListeners();

      // Poll amplitude levels at ~4Hz (every 250ms)
      _sampleTimer?.cancel();
      _sampleTimer = Timer.periodic(const Duration(milliseconds: 250), (_) async {
        if (_state != SoundMonitorState.running || _sessionId != currentSession) return;

        try {
          Amplitude amp = await _audioRecorder.getAmplitude();

          // Session re-check after async getAmplitude returns
          if (_state != SoundMonitorState.running || _sessionId != currentSession) return;

          // Amplitude returns current in dB (typically -160dB to 0dB)
          double rawDb = amp.current;
          double peakDb = amp.max;

          // Normalize dB (-80dB..0dB mapped to 0.0..1.0 relative level)
          double normLevel = ((rawDb + 80.0) / 80.0).clamp(0.0, 1.0);
          double normPeak = ((peakDb + 80.0) / 80.0).clamp(0.0, 1.0);

          // Apply EMA exponential smoothing (alpha = 0.35) to reject transient noise spikes
          _smoothedLevel = (_smoothedLevel == 0.0) ? normLevel : (_smoothedLevel * 0.65) + (normLevel * 0.35);
          _smoothedPeak = (_smoothedPeak == 0.0) ? normPeak : (_smoothedPeak * 0.65) + (normPeak * 0.35);

          _lastLevel = double.parse(_smoothedLevel.toStringAsFixed(2));
          _lastPeak = double.parse(_smoothedPeak.toStringAsFixed(2));
          _sequenceId++;

          // Emit compact sound feature payload for Bluetooth SPP transmission
          final featurePacket = {
            'type': 'sound',
            'level': _lastLevel,
            'peak': _lastPeak,
            'seq': _sequenceId,
            'timestamp': DateTime.now().millisecondsSinceEpoch,
          };

          _soundFeatureController?.add(featurePacket);
          notifyListeners();
        } catch (e) {
          debugPrint('Amplitude sampling error: $e');
          await stopMonitoring();
          _statusMessage = 'Sound Monitoring Disabled: Sampling error ($e)';
          notifyListeners();
        }
      });

      return true;
    } catch (e) {
      debugPrint('Failed to start microphone: $e');
      _statusMessage = 'Sound Monitoring Disabled: Initialization failed ($e)';
      _state = SoundMonitorState.idle;
      _lastLevel = 0.0;
      _lastPeak = 0.0;
      notifyListeners();
      return false;
    }
  }

  /// Inject a simulated acoustic sound level (useful for testing or fault injection).
  /// Ignored completely if sound monitoring is currently OFF.
  void injectSimulatedSoundLevel(double level) {
    if (!isMonitoring) {
      debugPrint('Cannot inject sound level: Sound monitoring is OFF.');
      return;
    }

    _lastLevel = level.clamp(0.0, 1.0);
    _lastPeak = (level * 1.15).clamp(0.0, 1.0);
    _statusMessage = 'Simulated Sound Level: ${(_lastLevel * 100).toInt()}%';

    final featurePacket = {
      'type': 'sound',
      'level': double.parse(_lastLevel.toStringAsFixed(2)),
      'peak': double.parse(_lastPeak.toStringAsFixed(2)),
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    };

    _soundFeatureController?.add(featurePacket);
    notifyListeners();
  }

  bool _isDisposed = false;

  @override
  void notifyListeners() {
    if (!_isDisposed) {
      super.notifyListeners();
    }
  }

  /// Stop microphone capture immediately and release all resources.
  Future<void> stopMonitoring() async {
    if (_state == SoundMonitorState.idle && _lastLevel == 0.0 && _lastPeak == 0.0) {
      _statusMessage = 'Sound Monitoring Disabled';
      return;
    }

    _state = SoundMonitorState.stopping;
    _sessionId++; // Immediately invalidate any in-flight sample callbacks
    _statusMessage = 'Stopping Microphone...';
    notifyListeners();

    _sampleTimer?.cancel();
    _sampleTimer = null;

    _lastLevel = 0.0;
    _lastPeak = 0.0;
    _smoothedLevel = 0.0;
    _smoothedPeak = 0.0;

    try {
      if (await _audioRecorder.isRecording()) {
        await _audioRecorder.stop();
      }
    } catch (e) {
      debugPrint('Error stopping audio recorder: $e');
    } finally {
      _state = SoundMonitorState.idle;
      _statusMessage = 'Sound Monitoring Disabled';
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    _sessionId++;
    _sampleTimer?.cancel();
    _sampleTimer = null;
    _state = SoundMonitorState.idle;
    _lastLevel = 0.0;
    _lastPeak = 0.0;
    try {
      _audioRecorder.stop();
      _audioRecorder.dispose();
    } catch (_) {}
    _soundFeatureController?.close();
    super.dispose();
  }
}


