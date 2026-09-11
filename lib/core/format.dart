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
