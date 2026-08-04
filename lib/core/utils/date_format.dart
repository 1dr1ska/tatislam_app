/// Format a [date] as a relative time string (e.g. "5 мин. элек").
String formatRelativeDate(DateTime date) {
  final now = DateTime.now();
  final diff = now.difference(date);

  if (diff.inMinutes < 60) {
    return '${diff.inMinutes} мин. элек';
  } else if (diff.inHours < 24) {
    return '${diff.inHours} сәг. элек';
  } else {
    return '${diff.inDays} көн элек';
  }
}

/// Format a [date] as an absolute date-time string (e.g. "2024-03-15 14:30").
String formatDateTime(DateTime date) {
  return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
}
