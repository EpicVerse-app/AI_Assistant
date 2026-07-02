import 'dart:async';
import 'dart:io';

import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
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
  DateTime? _pausedAt;
  bool _isPaused = false;
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
      _pausedAt = null;
      _isPaused = false;
      final path = event['path'] as String?;
      _stopCompleter?.complete(path);
      _stopCompleter = null;
      _emit(event);
    } else if (type == 'error') {
      _startedAt = null;
      _pausedAt = null;
      _isPaused = false;
      _emit(event);
    } else if (type == 'paused') {
      _isPaused = true;
      _pausedAt = DateTime.now();
      _emit(event);
    } else if (type == 'resumed') {
      if (_pausedAt != null && _startedAt != null) {
        _startedAt = _startedAt!.add(DateTime.now().difference(_pausedAt!));
      }
      _isPaused = false;
      _pausedAt = null;
      _emit(event);
    } else if (type == 'tick' && _startedAt != null) {
      if (_isPaused) return;
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

  bool get isPaused => _isPaused;

  /// Requests "draw over other apps" permission if not already granted,
  /// then shows the floating recording bubble.
  Future<void> _showOverlay() async {
    if (!Platform.isAndroid) return;
    try {
      final granted = await FlutterOverlayWindow.isPermissionGranted();
      if (!granted) {
        await FlutterOverlayWindow.requestPermission();
      }
      if (await FlutterOverlayWindow.isPermissionGranted()) {
        await FlutterOverlayWindow.showOverlay(
          height: 64,
          width: WindowSize.matchParent,
          alignment: OverlayAlignment.topCenter,
          flag: OverlayFlag.defaultFlag,
          overlayTitle: 'Recording',
          overlayContent: 'Tap Stop to finish',
          enableDrag: true,
          positionGravity: PositionGravity.auto,
        );
        // Reset overlay timer
        await FlutterOverlayWindow.shareData('reset');
      }
    } catch (_) {
      // Overlay is optional — recording continues regardless
    }
  }

  Future<void> _closeOverlay() async {
    if (!Platform.isAndroid) return;
    try {
      if (await FlutterOverlayWindow.isActive()) {
        await FlutterOverlayWindow.closeOverlay();
      }
    } catch (_) {}
  }

  Future<void> start(String path) async {
    await _ensurePermissions();
    _startedAt = DateTime.now();
    _pausedAt = null;
    _isPaused = false;

    if (Platform.isAndroid) {
      // Stop any stale service left over from a previous session
      if (await FlutterForegroundTask.isRunningService) {
        await FlutterForegroundTask.stopService();
        await _closeOverlay();
        // Brief pause so Android has time to unbind the old service
        await Future<void>.delayed(const Duration(milliseconds: 400));
      }

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
      await _showOverlay();
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
    _pausedAt = null;
    _isPaused = false;

    if (Platform.isAndroid) {
      await _closeOverlay();
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

  Future<void> pause() async {
    if (_isPaused) return;

    if (Platform.isAndroid) {
      if (await FlutterForegroundTask.isRunningService) {
        FlutterForegroundTask.sendDataToTask('pause');
      }
      return;
    }

    await _recorder.pause();
    _iosTimer?.cancel();
    _iosTimer = null;
    _isPaused = true;
    _pausedAt = DateTime.now();
    _emit({'event': 'paused'});
  }

  Future<void> resume() async {
    if (!_isPaused) return;

    if (Platform.isAndroid) {
      if (await FlutterForegroundTask.isRunningService) {
        FlutterForegroundTask.sendDataToTask('resume');
      }
      return;
    }

    await _recorder.resume();
    if (_pausedAt != null && _startedAt != null) {
      _startedAt = _startedAt!.add(DateTime.now().difference(_pausedAt!));
    }
    _isPaused = false;
    _pausedAt = null;
    _iosTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_startedAt == null) return;
      _emit({
        'event': 'tick',
        'elapsed': DateTime.now().difference(_startedAt!),
      });
    });
    _emit({'event': 'resumed'});
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
    _iosTimer?.cancel();
    _iosTimer = null;
    _startedAt = null;
    _pausedAt = null;
    _isPaused = false;

    if (Platform.isIOS) {
      final recorder = _iosRecorder;
      if (recorder == null) return;
      try {
        if (await recorder.isRecording()) {
          await recorder.stop();
        }
      } catch (_) {}
    }
    // On Android: don't auto-stop the service — user may have intentionally
    // backgrounded the app while recording. The notification Stop button handles it.
  }
}
