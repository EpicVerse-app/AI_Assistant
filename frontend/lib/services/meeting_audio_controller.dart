import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';

import 'api_service.dart';
import 'local_audio_storage.dart';

class MeetingAudioController extends ChangeNotifier {
  MeetingAudioController();

  final AudioPlayer _player = AudioPlayer();
  bool _initialized = false;
  bool _loading = false;
  String? _error;
  bool _available = false;
  bool _isLocal = false;

  double _speed = 1.0;

  bool get loading => _loading;
  String? get error => _error;
  bool get available => _available;
  bool get isLocal => _isLocal;
  bool get isPlaying => _player.playing;
  double get speed => _speed;
  Duration get position => _player.position;
  Duration get duration => _player.duration ?? Duration.zero;

  Future<void> load(String meetingId) async {
    if (_initialized) return;
    _loading = true;
    _error = null;
    notifyListeners();

    try {
      // 1. Try the permanent local copy saved at upload time.
      final localPath = await LocalAudioStorage.getLocalPath(meetingId);
      if (localPath != null) {
        await _player.setFilePath(localPath);
        _initialized = true;
        _available = true;
        _isLocal = true;
        return;
      }

      // 2. Check the server has audio for this meeting.
      final info = await ApiService.getAudioInfo(meetingId);
      if (info == null) {
        _available = false;
        _error =
            'Recording not found on this device. Record or upload from this phone to keep a local copy.';
        return;
      }

      // 3. Download the file to a temp path so ExoPlayer can seek it reliably
      //    (streaming via AudioSource.uri requires Range-request support which
      //    our backend does not implement).
      final tmpDir = await getTemporaryDirectory();
      final tmpFile = File('${tmpDir.path}/audio_$meetingId.wav');

      if (!tmpFile.existsSync()) {
        final response = await http.get(
          Uri.parse(ApiService.audioPlayUrl(meetingId)),
          headers: ApiService.authHeaders,
        );
        if (response.statusCode != 200) {
          _available = false;
          _error = 'Server returned ${response.statusCode} for audio.';
          return;
        }
        await tmpFile.writeAsBytes(response.bodyBytes);
      }

      await _player.setFilePath(tmpFile.path);
      _initialized = true;
      _available = true;
      _isLocal = false;
    } catch (e) {
      _available = false;
      _error = 'Could not load audio: $e';
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> togglePlayPause() async {
    if (!_initialized || !_available) return;
    if (_player.playing) {
      await _player.pause();
    } else {
      await _player.play();
    }
    notifyListeners();
  }

  Future<void> setSpeed(double speed) async {
    if (!_initialized) return;
    _speed = speed;
    await _player.setSpeed(speed);
    notifyListeners();
  }

  Future<void> seek(Duration position) async {
    if (!_initialized) return;
    await _player.seek(position);
    notifyListeners();
  }

  Future<void> stop() async {
    await _player.stop();
    notifyListeners();
  }

  void listen() {
    _player.positionStream.listen((_) => notifyListeners());
    _player.durationStream.listen((_) => notifyListeners());
    _player.playerStateStream.listen((_) => notifyListeners());
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }
}
