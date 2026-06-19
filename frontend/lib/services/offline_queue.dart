import 'dart:convert';
import 'dart:io';

import 'package:shared_preferences/shared_preferences.dart';

import 'api_service.dart';

class PendingUpload {
  final String audioPath;
  final DateTime recordedAt;

  PendingUpload({required this.audioPath, required this.recordedAt});

  Map<String, dynamic> toJson() => {
        'audioPath': audioPath,
        'recordedAt': recordedAt.toIso8601String(),
      };

  factory PendingUpload.fromJson(Map<String, dynamic> json) => PendingUpload(
        audioPath: json['audioPath'] as String,
        recordedAt: DateTime.parse(json['recordedAt'] as String),
      );
}

class OfflineQueue {
  static const String _key = 'pending_uploads';

  static Future<List<PendingUpload>> getAll() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_key) ?? [];
    return raw
        .map((e) => PendingUpload.fromJson(jsonDecode(e) as Map<String, dynamic>))
        .toList();
  }

  static Future<void> add(String audioPath) async {
    final prefs = await SharedPreferences.getInstance();
    final existing = prefs.getStringList(_key) ?? [];
    existing.add(jsonEncode(
      PendingUpload(audioPath: audioPath, recordedAt: DateTime.now()).toJson(),
    ));
    await prefs.setStringList(_key, existing);
  }

  static Future<void> remove(String audioPath) async {
    final prefs = await SharedPreferences.getInstance();
    final existing = prefs.getStringList(_key) ?? [];
    existing.removeWhere((e) {
      final decoded = jsonDecode(e) as Map<String, dynamic>;
      return decoded['audioPath'] == audioPath;
    });
    await prefs.setStringList(_key, existing);
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }

  /// Try uploading all pending files. Returns list of successfully uploaded meeting IDs.
  static Future<List<String>> syncPending({
    void Function(String audioPath)? onSuccess,
    void Function(String audioPath, Object error)? onError,
  }) async {
    final pending = await getAll();
    final uploaded = <String>[];

    for (final item in pending) {
      final file = File(item.audioPath);
      if (!file.existsSync()) {
        await remove(item.audioPath);
        continue;
      }

      try {
        final meetingId = await ApiService.uploadAudio(file);
        uploaded.add(meetingId);
        await remove(item.audioPath);
        onSuccess?.call(item.audioPath);
      } catch (e) {
        onError?.call(item.audioPath, e);
      }
    }

    return uploaded;
  }

  static Future<int> pendingCount() async {
    final list = await getAll();
    return list.length;
  }
}
