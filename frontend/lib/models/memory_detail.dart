import 'package:flutter/material.dart';

class MemoryDetail {
  const MemoryDetail({
    required this.meetingTopic,
    required this.meetingDate,
    required this.duration,
    required this.accentColor,
    required this.icon,
    required this.attendees,
    required this.summary,
    required this.decisions,
    required this.actionItems,
    required this.deadlines,
    required this.importantNotes,
  });

  final String meetingTopic;
  final DateTime meetingDate;
  final String duration;
  final Color accentColor;
  final IconData icon;
  final List<String> attendees;
  final String summary;
  final List<String> decisions;
  final List<String> actionItems;
  final List<String> deadlines;
  final List<String> importantNotes;

  String get formattedMeetingDate {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    final month = months[meetingDate.month - 1];
    final hour = meetingDate.hour > 12
        ? meetingDate.hour - 12
        : (meetingDate.hour == 0 ? 12 : meetingDate.hour);
    final period = meetingDate.hour >= 12 ? 'PM' : 'AM';
    final minute = meetingDate.minute.toString().padLeft(2, '0');
    return '$month ${meetingDate.day}, ${meetingDate.year} · $hour:$minute $period';
  }

  static MemoryDetail sample({
    required String title,
    required Color accentColor,
    required IconData icon,
    required String duration,
    required DateTime date,
  }) {
    return MemoryDetail(
      meetingTopic: title,
      meetingDate: date,
      duration: duration,
      accentColor: accentColor,
      icon: icon,
      attendees: const ['Alex', 'Sarah', 'Mike', 'Priya'],
      summary:
          'The team aligned on Q3 priorities, reviewed the product roadmap, and identified three critical milestones. Discussion focused on accelerating AI memory features while maintaining transcription accuracy.',
      decisions: const [
        'Prioritize AI summarization for Q3 launch',
        'Raise transcription accuracy target to 98%',
        'Run weekly customer feedback sessions',
      ],
      actionItems: const [
        'Schedule design review for memory detail screen',
        'Share updated roadmap with stakeholders',
        'Draft technical spec for real-time transcription',
        'Set up weekly customer feedback sessions',
      ],
      deadlines: const [
        'Share roadmap with stakeholders — Friday',
        'Technical spec draft — Next Wednesday',
        'Design review — Next Monday',
        'Weekly feedback sessions — Start next week',
      ],
      importantNotes: const [
        'Enterprise customers need higher transcription accuracy',
        'Cross-team sync required between design and engineering',
        'Beta launch target: end of Q3',
      ],
    );
  }
}
