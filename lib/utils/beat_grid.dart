class BeatGrid {
  final double bpm;
  final int anchorMs;

  BeatGrid({required this.bpm, required this.anchorMs});

  double get beatIntervalMs => 60000.0 / bpm;

  /// Snap a timestamp to the nearest beat.
  int snapToBeat(int timestampMs) {
    final interval = beatIntervalMs;
    final offset = (timestampMs - anchorMs) / interval;
    return (anchorMs + offset.round() * interval).round();
  }

  /// Get beat number relative to anchor (0 = anchor beat, negative = before).
  int beatNumber(int timestampMs) {
    return ((timestampMs - anchorMs) / beatIntervalMs).floor();
  }

  /// Get all beat positions (in ms) between [startMs] and [endMs].
  List<int> beatsInRange(int startMs, int endMs) {
    final interval = beatIntervalMs;
    final offsetFromAnchor = (startMs - anchorMs) / interval;
    var firstBeatIndex = offsetFromAnchor.ceil();
    final beats = <int>[];
    for (var i = firstBeatIndex;; i++) {
      final ms = (anchorMs + i * interval).round();
      if (ms > endMs) break;
      if (ms >= startMs) beats.add(ms);
    }
    return beats;
  }

  /// Whether [timestampMs] falls on the first beat of a measure (beat 1 of 4).
  bool isMeasureStart(int timestampMs) {
    final beatIdx = ((timestampMs - anchorMs) / beatIntervalMs).round();
    return beatIdx % 4 == 0;
  }
}
