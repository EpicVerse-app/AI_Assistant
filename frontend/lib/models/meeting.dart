class Meeting {
  final String meetingId;
  final String? clientId;
  final String? meetingDate;
  final String? meetingTime;
  final int? durationSeconds;
  final String? language;
  final String status;
  final DateTime createdAt;
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
    this.transcript,
    this.translation,
    this.summary,
    this.momSections,
  });

  factory Meeting.fromJson(Map<String, dynamic> json) {
    return Meeting(
      meetingId: json['meeting_id'] as String,
      clientId: json['client_id'] as String?,
      meetingDate: json['meeting_date'] as String?,
      meetingTime: json['meeting_time'] as String?,
      durationSeconds: json['duration_seconds'] as int?,
      language: json['language'] as String?,
      status: json['status'] as String? ?? 'uploaded',
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String) ?? DateTime.now()
          : DateTime.now(),
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

  String get displayDate {
    if (meetingDate != null) return meetingDate!;
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${months[createdAt.month - 1]} ${createdAt.day}, ${createdAt.year}';
  }

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
      'transcript': transcript,
      'translation': translation,
      'summary': summary,
      'mom': momSections,
    };
  }
}
