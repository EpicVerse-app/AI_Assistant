/// Parse API timestamps and format them in the device local timezone.
///
/// The backend stores [created_at] as UTC. Naive ISO strings (no `Z`) are treated
/// as UTC and converted to the device local clock.
class DateTimeUtils {
  DateTimeUtils._();

  static final RegExp _timezoneSuffix =
      RegExp(r'([zZ]|[+-]\d{2}:\d{2}(:\d{2})?)$');

  /// Prefer [epochMs] when the API includes it; otherwise parse [iso].
  static DateTime parseApi(String? iso, {int? epochMs}) {
    if (epochMs != null) {
      return DateTime.fromMillisecondsSinceEpoch(epochMs, isUtc: true).toLocal();
    }
    if (iso == null || iso.isEmpty) return DateTime.now();

    final trimmed = iso.trim();
    final normalized =
        _timezoneSuffix.hasMatch(trimmed) ? trimmed : '${trimmed}Z';
    return DateTime.parse(normalized).toLocal();
  }

  static int? epochMsFromJson(Map<String, dynamic> json) {
    final raw = json['created_at_ms'];
    if (raw is int) return raw;
    if (raw is num) return raw.toInt();
    return null;
  }

  static String formatCardDateTime(String? iso, {int? epochMs}) {
    final dt = parseApi(iso, epochMs: epochMs);
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    final h = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final m = dt.minute.toString().padLeft(2, '0');
    final ampm = dt.hour < 12 ? 'AM' : 'PM';
    return '${months[dt.month - 1]} ${dt.day}, ${dt.year}  $h:$m $ampm';
  }

  static String formatDate(DateTime date) {
    final local = date.isUtc ? date.toLocal() : date;
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${local.day} ${months[local.month - 1]} ${local.year}';
  }

  static String formatTime(DateTime date) {
    final local = date.isUtc ? date.toLocal() : date;
    final hour = local.hour % 12 == 0 ? 12 : local.hour % 12;
    final minute = local.minute.toString().padLeft(2, '0');
    final period = local.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $period';
  }

  /// Device timezone offset sent on upload so the backend can store local metadata.
  static int deviceTimezoneOffsetMinutes() =>
      DateTime.now().timeZoneOffset.inMinutes;
}
