/// Run length as "0:42", "12:05" or "1:02:10".
String formatDuration(Duration duration) {
  final hours = duration.inHours;
  final minutes = duration.inMinutes.remainder(60);
  final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
  return hours > 0
      ? '$hours:${minutes.toString().padLeft(2, '0')}:$seconds'
      : '$minutes:$seconds';
}

/// How long ago [at] was: "just now", "5 min ago", "2 h ago", "yesterday",
/// "3 d ago".
String formatAgo(DateTime at, {DateTime? now}) {
  final elapsed = (now ?? DateTime.now()).difference(at);
  return switch (elapsed) {
    Duration(inMinutes: < 1) => 'just now',
    Duration(inMinutes: final m) when m < 60 => '$m min ago',
    Duration(inHours: final h) when h < 24 => '$h h ago',
    Duration(inHours: < 48) => 'yesterday',
    Duration(inDays: final d) => '$d d ago',
  };
}

const _months = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

/// Calendar days from [at] to [now] in local time (0 = same day,
/// 1 = yesterday; negative for future days).
int calendarDaysBetween(DateTime at, DateTime now) {
  final a = at.toLocal();
  final b = now.toLocal();
  // UTC midnights, so DST changes don't skew the count.
  return DateTime.utc(
    b.year,
    b.month,
    b.day,
  ).difference(DateTime.utc(a.year, a.month, a.day)).inDays;
}

/// Local time of day as "9:14 AM".
String formatClock(DateTime at) {
  final local = at.toLocal();
  final hour = local.hour % 12 == 0 ? 12 : local.hour % 12;
  final minute = local.minute.toString().padLeft(2, '0');
  return '$hour:$minute ${local.hour < 12 ? 'AM' : 'PM'}';
}

/// "Sep 9", or "Sep 9, 2025" outside the current year.
String formatMonthDay(DateTime at, {DateTime? now}) {
  final local = at.toLocal();
  final label = '${_months[local.month - 1]} ${local.day}';
  return local.year == (now ?? DateTime.now()).toLocal().year
      ? label
      : '$label, ${local.year}';
}

/// Day and time: "today, 9:14 AM", "yesterday, 8:02 PM", "Sep 9, 8:02 PM".
String formatDayTime(DateTime at, {DateTime? now}) {
  final today = now ?? DateTime.now();
  final day = switch (calendarDaysBetween(at, today)) {
    0 => 'today',
    1 => 'yesterday',
    _ => formatMonthDay(at, now: today),
  };
  return '$day, ${formatClock(at)}';
}

/// When something happened, briefly: "2 h ago" (today), "yesterday",
/// "Sep 9".
String formatWhen(DateTime at, {DateTime? now}) {
  final today = now ?? DateTime.now();
  return switch (calendarDaysBetween(at, today)) {
    <= 0 => formatAgo(at, now: today),
    1 => 'yesterday',
    _ => formatMonthDay(at, now: today),
  };
}

/// Start of a streak: "9:14 AM" (today), "yesterday", "Sep 10".
String formatSince(DateTime at, {DateTime? now}) {
  final today = now ?? DateTime.now();
  return switch (calendarDaysBetween(at, today)) {
    <= 0 => formatClock(at),
    1 => 'yesterday',
    _ => formatMonthDay(at, now: today),
  };
}
