/// Format milliseconds as "mm:ss.SSS"
String formatTimestamp(int ms) {
  final totalSeconds = ms ~/ 1000;
  final minutes = totalSeconds ~/ 60;
  final seconds = totalSeconds % 60;
  final millis = ms % 1000;
  return '${minutes.toString().padLeft(2, '0')}:'
      '${seconds.toString().padLeft(2, '0')}.'
      '${millis.toString().padLeft(3, '0')}';
}

/// Format Duration as "mm:ss.SSS"
String formatDuration(Duration d) {
  return formatTimestamp(d.inMilliseconds);
}

/// Parse "mm:ss.SSS" or "mm:ss" back to milliseconds. Returns null on failure.
int? parseTimestamp(String text) {
  final match =
      RegExp(r'^(\d+):(\d{1,2})(?:\.(\d{1,3}))?$').firstMatch(text);
  if (match == null) return null;
  final minutes = int.parse(match.group(1)!);
  final seconds = int.parse(match.group(2)!);
  final millisStr = (match.group(3) ?? '0').padRight(3, '0');
  final millis = int.parse(millisStr);
  return (minutes * 60 + seconds) * 1000 + millis;
}
