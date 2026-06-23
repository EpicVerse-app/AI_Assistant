import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../models/meeting.dart';

class ApiService {
  static const String baseUrl = 'https://ai-assistant-api-9xhb.onrender.com';
  static const Duration _timeout = Duration(seconds: 120);

  // Upload audio file → returns meeting_id
  static Future<String> uploadAudio(
    File audioFile, {
    String? clientId,
  }) async {
    final uri = Uri.parse('$baseUrl/transcription/upload');
    final request = http.MultipartRequest('POST', uri);

    if (clientId != null) {
      request.fields['client_id'] = clientId;
    }

    request.files.add(
      await http.MultipartFile.fromPath('file', audioFile.path),
    );

    final streamedResponse = await request.send().timeout(_timeout);
    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode != 200) {
      throw Exception('Upload failed (${response.statusCode}): ${response.body}');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    return data['meeting_id'] as String;
  }

  // Poll transcription status until done or failed
  static Future<Meeting> pollTranscription(
    String meetingId, {
    Duration interval = const Duration(seconds: 3),
    int maxAttempts = 100,
  }) async {
    for (var i = 0; i < maxAttempts; i++) {
      await Future<void>.delayed(interval);
      final meeting = await getTranscript(meetingId);
      if (meeting.isDone || meeting.isFailed) return meeting;
    }
    throw Exception('Transcription timed out for $meetingId');
  }

  // Get transcript
  static Future<Meeting> getTranscript(String meetingId) async {
    final uri = Uri.parse('$baseUrl/transcription/$meetingId');
    final response = await http.get(uri).timeout(_timeout);

    if (response.statusCode != 200) {
      throw Exception('Get transcript failed: ${response.body}');
    }

    return Meeting.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  // Translate transcript → English
  static Future<String> translate(String meetingId) async {
    final uri = Uri.parse('$baseUrl/translation/$meetingId');
    final response = await http.post(uri).timeout(_timeout);

    if (response.statusCode != 200) {
      throw Exception('Translation failed: ${response.body}');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    return data['translation'] as String? ?? '';
  }

  // Generate MoM or conversation summary
  static Future<String> generateSummary(
    String meetingId, {
    String type = 'meeting',
  }) async {
    final uri = Uri.parse('$baseUrl/summary/$meetingId');
    final response = await http
        .post(
          uri,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'type': type}),
        )
        .timeout(_timeout);

    if (response.statusCode != 200) {
      throw Exception('Summary failed: ${response.body}');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    return data['summary'] as String? ?? '';
  }

  // Delete meeting (transcript + MoM; server audio kept; local audio untouched)
  static Future<void> deleteMeeting(String meetingId) async {
    final uri = Uri.parse('$baseUrl/transcription/$meetingId');
    final response = await http.delete(uri).timeout(_timeout);

    if (response.statusCode != 200) {
      throw Exception('Delete meeting failed: ${response.body}');
    }
  }

  // Delete audio file from server
  static Future<void> deleteAudio(String meetingId) async {
    final uri = Uri.parse('$baseUrl/transcription/$meetingId/audio');
    final response = await http.delete(uri).timeout(_timeout);

    if (response.statusCode != 200) {
      throw Exception('Delete audio failed: ${response.body}');
    }
  }

  // Fetch all meetings (newest first) for home screen
  static Future<List<Map<String, dynamic>>> getMeetings() async {
    final uri = Uri.parse('$baseUrl/transcription/list/all');
    final response = await http.get(uri).timeout(_timeout);

    if (response.statusCode != 200) {
      throw Exception('Failed to load meetings: ${response.body}');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    return List<Map<String, dynamic>>.from(data['meetings'] as List);
  }

  // Fetch full meeting detail (transcript + translation + summary)
  static Future<Meeting> getMeetingDetail(String meetingId) async {
    final uri = Uri.parse('$baseUrl/transcription/$meetingId/detail');
    final response = await http.get(uri).timeout(_timeout);

    if (response.statusCode != 200) {
      throw Exception('Failed to load meeting: ${response.body}');
    }

    return Meeting.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  // Check if backend is reachable (Render free tier may take 30–60s to wake).
  static Future<bool> isReachable({
    Duration timeout = const Duration(seconds: 60),
  }) async {
    try {
      final uri = Uri.parse('$baseUrl/health');
      final response = await http.get(uri).timeout(timeout);
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  static String audioPlayUrl(String meetingId) =>
      '$baseUrl/transcription/$meetingId/audio/play';

  static Future<Map<String, dynamic>?> getAudioInfo(String meetingId) async {
    try {
      final uri = Uri.parse('$baseUrl/transcription/$meetingId/audio/info');
      final response = await http.get(uri).timeout(_timeout);
      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
    } catch (_) {}
    return null;
  }
}
