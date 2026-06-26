import '../utils/date_time_utils.dart';

class Meeting {
  final String meetingId;
  final String? clientId;
  final String? meetingDate;
  final String? meetingTime;
  final int? durationSeconds;
  final String? language;
  final String status;
  final DateTime createdAt;
  final String? errorMessage;
  String? transcript;
  String? translation;
  String? summary;
  Map<String, String>? momSections;

  Meeting({
    required this.meetingId,
    this.clientId,
    this.meetingDate,
    this.meetingTime,
    this.durationSeconds,
    this.language,
    required this.status,
    required this.createdAt,
    this.errorMessage,
    this.transcript,
    this.translation,
    this.summary,
    this.momSections,
  });

  factory Meeting.fromJson(Map<String, dynamic> json) {
    final epochMs = DateTimeUtils.epochMsFromJson(json);
    return Meeting(
      meetingId: json['meeting_id'] as String,
      clientId: json['client_id'] as String?,
      meetingDate: json['meeting_date'] as String?,
      meetingTime: json['meeting_time'] as String?,
      durationSeconds: json['duration_seconds'] as int?,
      language: json['language'] as String?,
      status: json['status'] as String? ?? 'uploaded',
      createdAt: DateTimeUtils.parseApi(
        json['created_at'] as String?,
        epochMs: epochMs,
      ),
      errorMessage: json['error_message'] as String?,
      transcript: json['transcript'] as String?,
      translation: json['translation'] as String?,
      summary: json['summary'] as String?,
      momSections: parseMomSections(json['mom']),
    );
  }

  static Map<String, String>? parseMomSections(dynamic raw) =>
      _parseMomSections(raw);

  static Map<String, String>? _parseMomSections(dynamic raw) {
    if (raw is! Map) return null;
    return raw.map((k, v) => MapEntry(k.toString(), v?.toString() ?? ''));
  }

  bool get isDone => status == 'done';
  bool get isFailed => status == 'failed';
  bool get isProcessing => status == 'processing' || status == 'uploaded';

  String get displayDate => DateTimeUtils.formatDate(createdAt);

  String get displayTime => DateTimeUtils.formatTime(createdAt);

  String get displayDuration {
    if (durationSeconds == null) return '';
    final m = durationSeconds! ~/ 60;
    final s = durationSeconds! % 60;
    if (m == 0) return '${s}s';
    return '${m}m ${s}s';
  }

  Map<String, dynamic> toLocalJson() {
    return {
      'meeting_id': meetingId,
      'client_id': clientId,
      'meeting_date': meetingDate,
      'meeting_time': meetingTime,
      'duration_seconds': durationSeconds,
      'language': language,
      'status': status,
      'created_at': createdAt.toIso8601String(),
      'error_message': errorMessage,
      'transcript': transcript,
      'translation': translation,
      'summary': summary,
      'mom': momSections,
    };
  }
}
