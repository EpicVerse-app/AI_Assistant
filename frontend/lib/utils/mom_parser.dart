import 'date_time_utils.dart';

class ParsedActionItem {
  const ParsedActionItem({
    required this.task,
    required this.owner,
    required this.dueDate,
    required this.priority,
  });

  final String task;
  final String owner;
  final String dueDate;
  final String priority;
}

class MomParser {
  static List<String> bulletLines(String? text) {
    if (text == null || text.trim().isEmpty) return [];
    if (text.trim().toLowerCase() == 'not mentioned') return [];

    return text
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .map((line) => line.startsWith('- ') ? line.substring(2).trim() : line)
        .toList();
  }

  static List<String> attendees(String? text) {
    if (text == null || text.trim().isEmpty) return [];
    if (text.trim().toLowerCase() == 'not mentioned') return [];

    return text
        .split(',')
        .map((name) => name.trim())
        .where((name) => name.isNotEmpty && name.toLowerCase() != 'not mentioned')
        .toList();
  }

  static List<ParsedActionItem> actionItems(String? text) {
    final lines = bulletLines(text);
    final items = <ParsedActionItem>[];

    for (final line in lines) {
      final match = RegExp(
        r'^(.+?) — Assigned by: (.+?) → Assignee: (.+?) \| Deadline: (.+)$',
      ).firstMatch(line);

      if (match != null) {
        items.add(
          ParsedActionItem(
            task: match.group(1)!.trim(),
            owner: match.group(3)!.trim(),
            dueDate: match.group(4)!.trim(),
            priority: _priorityForTask(match.group(1)!),
          ),
        );
      } else {
        items.add(
          ParsedActionItem(
            task: line,
            owner: '—',
            dueDate: '—',
            priority: _priorityForTask(line),
          ),
        );
      }
    }
    return items;
  }

  static String executiveSummary(List<String> bullets) {
    if (bullets.isEmpty) return 'No summary available.';
    return bullets.join(' ');
  }

  static String formatDisplayDate(String? isoDate, DateTime fallback) {
    return DateTimeUtils.formatDate(fallback);
  }

  static String formatDisplayTime(String? time, DateTime fallback) {
    return DateTimeUtils.formatTime(fallback);
  }

  static String formatDuration(int? seconds) {
    if (seconds == null || seconds <= 0) return '00:00:00';
    final h = seconds ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    final s = seconds % 60;
    if (h > 0) {
      return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    }
    return '00:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  static String initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }

  static String _priorityForTask(String task) {
    final lower = task.toLowerCase();
    if (lower.contains('urgent') ||
        lower.contains('critical') ||
        lower.contains('asap') ||
        lower.contains('hire')) {
      return 'High';
    }
    return 'Medium';
  }
}
