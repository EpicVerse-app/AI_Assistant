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

@pragma('vm:entry-point')
void recordingTaskCallback() {
  FlutterForegroundTask.setTaskHandler(RecordingTaskHandler());
}

class RecordingTaskHandler extends TaskHandler {
  final AudioRecorder _recorder = AudioRecorder();

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

    FlutterForegroundTask.updateService(
      notificationTitle: 'Recording meeting',
      notificationText: 'Tap Stop in the app or notification to finish',
      notificationButtons: const [
        NotificationButton(id: _stopButtonId, text: 'Stop'),
      ],
    );

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
    }
  }

  @override
  void onNotificationButtonPressed(String id) {
    if (id == _stopButtonId) {
      _finishRecording();
    }
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
