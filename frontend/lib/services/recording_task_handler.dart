import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:record/record.dart';

/// Persists the WAV path across isolates (main UI vs Android foreground service).
const recordingPathStorageKey = 'recording_path';

const recordConfig = RecordConfig(
  encoder: AudioEncoder.wav,
  sampleRate: 16000,
  numChannels: 1,
  audioInterruption: AudioInterruptionMode.pauseResume,
  iosConfig: IosRecordConfig(
    categoryOptions: [
      IosAudioCategoryOption.defaultToSpeaker,
      IosAudioCategoryOption.allowBluetooth,
      IosAudioCategoryOption.mixWithOthers,
    ],
  ),
);

const _stopButtonId = 'stop_recording';
const _pauseButtonId = 'pause_recording';
const _resumeButtonId = 'resume_recording';

@pragma('vm:entry-point')
void recordingTaskCallback() {
  FlutterForegroundTask.setTaskHandler(RecordingTaskHandler());
}

class RecordingTaskHandler extends TaskHandler {
  final AudioRecorder _recorder = AudioRecorder();
  bool _isPaused = false;

  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    final path = await FlutterForegroundTask.getData<String>(
      key: recordingPathStorageKey,
    );
    if (path == null || path.isEmpty) {
      FlutterForegroundTask.sendDataToMain({
        'event': 'error',
        'message': 'No recording path provided.',
      });
      await FlutterForegroundTask.stopService();
      return;
    }

    await _recorder.start(recordConfig, path: path);
    _isPaused = false;

    _updateNotification();

    FlutterForegroundTask.sendDataToMain({'event': 'started'});
  }

  @override
  void onRepeatEvent(DateTime timestamp) {
    FlutterForegroundTask.sendDataToMain({
      'event': 'tick',
      'elapsedMs': timestamp.millisecondsSinceEpoch,
    });
  }

  @override
  void onReceiveData(Object data) {
    if (data == 'stop') {
      _finishRecording();
    } else if (data == 'pause') {
      _pauseRecording();
    } else if (data == 'resume') {
      _resumeRecording();
    }
  }

  @override
  void onNotificationButtonPressed(String id) {
    if (id == _stopButtonId) {
      _finishRecording();
    } else if (id == _pauseButtonId) {
      _pauseRecording();
    } else if (id == _resumeButtonId) {
      _resumeRecording();
    }
  }

  Future<void> _pauseRecording() async {
    if (_isPaused) return;
    await _recorder.pause();
    _isPaused = true;
    _updateNotification();
    FlutterForegroundTask.sendDataToMain({'event': 'paused'});
  }

  Future<void> _resumeRecording() async {
    if (!_isPaused) return;
    await _recorder.resume();
    _isPaused = false;
    _updateNotification();
    FlutterForegroundTask.sendDataToMain({'event': 'resumed'});
  }

  void _updateNotification() {
    FlutterForegroundTask.updateService(
      notificationTitle: _isPaused ? 'Recording paused' : 'Recording meeting',
      notificationText: _isPaused
          ? 'Tap Resume to continue recording'
          : 'Tap Stop in the app or notification to finish',
      notificationButtons: [
        NotificationButton(
          id: _isPaused ? _resumeButtonId : _pauseButtonId,
          text: _isPaused ? 'Resume' : 'Pause',
        ),
        const NotificationButton(id: _stopButtonId, text: 'Stop'),
      ],
    );
  }

  Future<void> _finishRecording() async {
    final path = await _recorder.stop();
    await _recorder.dispose();
    await FlutterForegroundTask.removeData(key: recordingPathStorageKey);
    FlutterForegroundTask.sendDataToMain({
      'event': 'stopped',
      'path': path,
    });
    await FlutterForegroundTask.stopService();
  }

  @override
  Future<void> onDestroy(DateTime timestamp, bool isTimeout) async {
    if (await _recorder.isRecording()) {
      final path = await _recorder.stop();
      FlutterForegroundTask.sendDataToMain({
        'event': 'stopped',
        'path': path,
      });
    }
    await _recorder.dispose();
  }
}
