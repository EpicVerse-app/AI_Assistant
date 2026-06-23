import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Keeps a permanent on-device copy of each meeting recording.
class LocalAudioStorage {
  LocalAudioStorage._();

  static const _indexKey = 'local_meeting_audio';

  static Future<Directory> _audioDir() async {
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory('${docs.path}/meeting_audio');
    if (!dir.existsSync()) {
      dir.createSync(recursive: true);
    }
    return dir;
  }

  static Future<Map<String, dynamic>> _readIndex() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_indexKey);
    if (raw == null) return {};
    return Map<String, dynamic>.from(jsonDecode(raw) as Map);
  }

  static Future<void> _writeIndex(Map<String, dynamic> index) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_indexKey, jsonEncode(index));
  }

  /// Copy [sourcePath] into app storage and link it to [meetingId].
  static Future<String> saveForMeeting(
    String meetingId,
    String sourcePath, {
    int? durationSeconds,
  }) async {
    final source = File(sourcePath);
    if (!source.existsSync()) {
      throw Exception('Source audio file not found: $sourcePath');
    }

    final dir = await _audioDir();
    final ext = _extension(sourcePath);
    final dest = File('${dir.path}/$meetingId$ext');

    await source.copy(dest.path);

    final index = await _readIndex();
    index[meetingId] = {
      'path': dest.path,
      'savedAt': DateTime.now().toIso8601String(),
      if (durationSeconds != null) 'durationSeconds': durationSeconds,
    };
    await _writeIndex(index);
    return dest.path;
  }

  static String _extension(String path) {
    final dot = path.lastIndexOf('.');
    if (dot == -1) return '.wav';
    final ext = path.substring(dot).toLowerCase();
    const allowed = {'.wav', '.mp3', '.m4a', '.aac', '.ogg', '.flac', '.opus'};
    return allowed.contains(ext) ? ext : '.wav';
  }

  static Future<String?> getLocalPath(String meetingId) async {
    final index = await _readIndex();
    final entry = index[meetingId];
    if (entry is! Map) return null;

    final path = entry['path'] as String?;
    if (path == null || !File(path).existsSync()) return null;
    return path;
  }

  static Future<bool> hasLocal(String meetingId) async {
    return (await getLocalPath(meetingId)) != null;
  }

  static Future<int?> getLocalDurationSeconds(String meetingId) async {
    final index = await _readIndex();
    final entry = index[meetingId];
    if (entry is Map && entry['durationSeconds'] is num) {
      return (entry['durationSeconds'] as num).round();
    }
    return null;
  }

  static Future<List<String>> allMeetingIds() async {
    final index = await _readIndex();
    final ids = <String>[];
    for (final entry in index.entries) {
      final path = (entry.value as Map?)?['path'] as String?;
      if (path != null && File(path).existsSync()) {
        ids.add(entry.key);
      }
    }
    return ids;
  }
}
