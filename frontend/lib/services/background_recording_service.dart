import 'dart:async';
import 'dart:io';

import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:record/record.dart';

import 'recording_task_handler.dart';

typedef RecordingEventHandler = void Function(Map<String, dynamic> event);

/// Handles lock-screen and background recording.
/// Android uses a microphone foreground service; iOS uses background audio mode.
class BackgroundRecordingService {
  BackgroundRecordingService._();

  static final BackgroundRecordingService instance =
      BackgroundRecordingService._();

  AudioRecorder? _iosRecorder;
  bool _initialized = false;
  DateTime? _startedAt;
  Timer? _iosTimer;
  final List<RecordingEventHandler> _listeners = [];

  static const _serviceId = 512;

  void addListener(RecordingEventHandler listener) {
    if (!_listeners.contains(listener)) _listeners.add(listener);
  }

  void removeListener(RecordingEventHandler listener) {
    _listeners.remove(listener);
  }

  void _emit(Map<String, dynamic> event) {
    for (final listener in List<RecordingEventHandler>.from(_listeners)) {
      listener(event);
    }
  }

  Completer<String?>? _stopCompleter;

  Future<void> init() async {
    if (_initialized) return;

    if (Platform.isAndroid) {
      FlutterForegroundTask.initCommunicationPort();
      FlutterForegroundTask.addTaskDataCallback(_onTaskData);

      FlutterForegroundTask.init(
        androidNotificationOptions: AndroidNotificationOptions(
          channelId: 'meeting_recording',
          channelName: 'Meeting Recording',
          channelDescription: 'Shown while a meeting is being recorded',
          channelImportance: NotificationChannelImportance.HIGH,
          priority: NotificationPriority.HIGH,
          onlyAlertOnce: true,
        ),
        iosNotificationOptions: const IOSNotificationOptions(
          showNotification: true,
          playSound: false,
        ),
        foregroundTaskOptions: ForegroundTaskOptions(
          eventAction: ForegroundTaskEventAction.repeat(1000),
          autoRunOnBoot: false,
          autoRunOnMyPackageReplaced: false,
          allowWakeLock: true,
          allowWifiLock: true,
        ),
      );
    }

    _initialized = true;
  }

  void _onTaskData(Object data) {
    if (data is! Map) return;
    final event = Map<String, dynamic>.from(data);
    final type = event['event'] as String?;
    if (type == 'stopped') {
      _startedAt = null;
      final path = event['path'] as String?;
      _stopCompleter?.complete(path);
      _stopCompleter = null;
      _emit(event);
    } else if (type == 'error') {
      _startedAt = null;
      _emit(event);
    } else if (type == 'tick' && _startedAt != null) {
      _emit({
        'event': 'tick',
        'elapsed': DateTime.now().difference(_startedAt!),
      });
    } else {
      _emit(event);
    }
  }

  AudioRecorder get _recorder => _iosRecorder ??= AudioRecorder();

  Future<void> _ensurePermissions() async {
    final micOk = await _recorder.hasPermission();
    if (!micOk) {
      throw Exception('Microphone permission denied.');
    }

    if (Platform.isAndroid) {
      final notif = await FlutterForegroundTask.checkNotificationPermission();
      if (notif != NotificationPermission.granted) {
        await FlutterForegroundTask.requestNotificationPermission();
      }
    }
  }

  Future<void> start(String path) async {
    await _ensurePermissions();
    _startedAt = DateTime.now();

    if (Platform.isAndroid) {
      final saved = await FlutterForegroundTask.saveData(
        key: recordingPathStorageKey,
        value: path,
      );
      if (!saved) {
        throw Exception('Could not save recording path.');
      }
      final result = await FlutterForegroundTask.startService(
        serviceId: _serviceId,
        serviceTypes: [ForegroundServiceTypes.microphone],
        notificationTitle: 'Recording meeting',
        notificationText: 'Recording in progress…',
        callback: recordingTaskCallback,
      );
      if (result is ServiceRequestFailure) {
        throw Exception(result.error);
      }
      return;
    }

    await _recorder.start(recordConfig, path: path);
    _iosTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_startedAt == null) return;
      _emit({
        'event': 'tick',
        'elapsed': DateTime.now().difference(_startedAt!),
      });
    });
    _emit({'event': 'started'});
  }

  Future<String?> stop() async {
    _iosTimer?.cancel();
    _iosTimer = null;

    if (Platform.isAndroid) {
      if (await FlutterForegroundTask.isRunningService) {
        _stopCompleter = Completer<String?>();
        FlutterForegroundTask.sendDataToTask('stop');
        return _stopCompleter!.future;
      }
      _startedAt = null;
      return null;
    }

    final path = await _recorder.stop();
    _startedAt = null;
    return path;
  }

  Future<bool> get isRecording async {
    if (Platform.isAndroid) {
      return FlutterForegroundTask.isRunningService;
    }
    return _recorder.isRecording();
  }

  Future<void> dispose() async {
    _iosTimer?.cancel();
    if (Platform.isAndroid) {
      FlutterForegroundTask.removeTaskDataCallback(_onTaskData);
    }
    await _iosRecorder?.dispose();
    _iosRecorder = null;
  }

  /// Clears stale recording state after returning from background.
  Future<void> resetAfterAppRestart() async {
    if (!Platform.isIOS) return;
    _iosTimer?.cancel();
    _iosTimer = null;
    _startedAt = null;
    final recorder = _iosRecorder;
    if (recorder == null) return;
    try {
      if (await recorder.isRecording()) {
        await recorder.stop();
      }
    } catch (_) {}
  }
}
