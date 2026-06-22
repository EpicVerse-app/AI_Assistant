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
    if (isoDate == null || isoDate.isEmpty) {
      return _formatDate(fallback);
    }
    final parsed = DateTime.tryParse(isoDate);
    if (parsed != null) return _formatDate(parsed);

    final parts = isoDate.split('-');
    if (parts.length == 3) {
      final year = int.tryParse(parts[0]);
      final month = int.tryParse(parts[1]);
      final day = int.tryParse(parts[2]);
      if (year != null && month != null && day != null) {
        return _formatDate(DateTime(year, month, day));
      }
    }
    return isoDate;
  }

  static String formatDisplayTime(String? time, DateTime fallback) {
    if (time != null && time.isNotEmpty) return time;
    final hour = fallback.hour > 12 ? fallback.hour - 12 : fallback.hour;
    final period = fallback.hour >= 12 ? 'PM' : 'AM';
    final minute = fallback.minute.toString().padLeft(2, '0');
    return '${hour == 0 ? 12 : hour}:$minute $period';
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

  static String _formatDate(DateTime date) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
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
