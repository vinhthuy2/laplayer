import 'dart:math';
import 'package:flutter/material.dart';
import '../models/label.dart';
import '../theme/app_colors.dart';
import '../theme/beat_grid_colors.dart';
import '../utils/beat_grid.dart';
import '../utils/time_format.dart';

class CircularBeatGrid extends StatefulWidget {
  final Duration position;
  final Duration duration;
  final List<Label> labels;
  final ValueChanged<Duration> onSeek;
  final ValueChanged<Duration>? onDragUpdate;
  final double? bpm;
  final int anchorMs;

  const CircularBeatGrid({
    super.key,
    required this.position,
    required this.duration,
    required this.labels,
    required this.onSeek,
    this.onDragUpdate,
    this.bpm,
    this.anchorMs = 0,
  });

  @override
  State<CircularBeatGrid> createState() => _CircularBeatGridState();
}

class _CircularBeatGridState extends State<CircularBeatGrid> {
  double? _dragFraction;

  double get _totalMs => widget.duration.inMilliseconds.toDouble();

  Duration _fractionToDuration(double fraction) {
    return Duration(milliseconds: (fraction.clamp(0.0, 1.0) * _totalMs).toInt());
  }

  /// Convert a local position relative to the center into an angle-based fraction.
  /// 12 o'clock = 0, clockwise.
  double? _positionToFraction(Offset localPos, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final dx = localPos.dx - center.dx;
    final dy = localPos.dy - center.dy;
    // atan2(dx, -dy) gives angle from 12 o'clock, clockwise
    var angle = atan2(dx, -dy);
    if (angle < 0) angle += 2 * pi;
    return angle / (2 * pi);
  }

  @override
  Widget build(BuildContext context) {
    if (_totalMs <= 0 || widget.bpm == null || widget.bpm! <= 0) {
      return _buildFallbackSlider();
    }

    final colors = context.colors;
    final gridColors = BeatGridColors(
      accent: colors.primary,
      accentMuted: colors.primaryMuted,
      accentSubtle: colors.primarySubtle,
      emptyStrong: colors.beatGridEmptyStrong,
      empty: colors.beatGridEmpty,
      playhead: colors.beatGridPlayhead,
      anchorStroke: colors.primary,
    );

    final beatGrid = BeatGrid(bpm: widget.bpm!, anchorMs: widget.anchorMs);
    final beats = beatGrid.beatsInRange(0, _totalMs.toInt());
    if (beats.isEmpty) return _buildFallbackSlider();

    final posMs = _dragFraction != null
        ? _dragFraction! * _totalMs
        : widget.position.inMilliseconds.toDouble();

    // Label lookup: beat ms → list of labels
    final labelMap = <int, List<Label>>{};
    for (final label in widget.labels) {
      final snapped = beatGrid.snapToBeat(label.timestampMs);
      labelMap.putIfAbsent(snapped, () => []).add(label);
    }

    // Find current label caption
    String currentCaption = '';
    for (int i = widget.labels.length - 1; i >= 0; i--) {
      if (posMs >= widget.labels[i].timestampMs) {
        currentCaption = widget.labels[i].caption;
        break;
      }
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final side = min(constraints.maxWidth, constraints.maxHeight);
        final boxSize = Size(side, side);

        return Center(
          child: SizedBox(
            width: side,
            height: side,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapUp: (details) {
                final frac = _positionToFraction(details.localPosition, boxSize);
                if (frac != null) {
                  widget.onSeek(_fractionToDuration(frac));
                }
              },
              onPanStart: (details) {
                final frac = _positionToFraction(details.localPosition, boxSize);
                if (frac != null) {
                  setState(() => _dragFraction = frac);
                  widget.onDragUpdate?.call(_fractionToDuration(frac));
                }
              },
              onPanUpdate: (details) {
                final frac = _positionToFraction(details.localPosition, boxSize);
                if (frac != null) {
                  setState(() => _dragFraction = frac);
                  widget.onDragUpdate?.call(_fractionToDuration(frac));
                }
              },
              onPanEnd: (_) {
                if (_dragFraction != null) {
                  widget.onSeek(_fractionToDuration(_dragFraction!));
                  setState(() => _dragFraction = null);
                }
              },
              child: Stack(
                alignment: Alignment.center,
                children: [
                  CustomPaint(
                    size: boxSize,
                    painter: _CircularBeatGridPainter(
                      beats: beats,
                      beatGrid: beatGrid,
                      positionMs: posMs,
                      totalMs: _totalMs,
                      labels: widget.labels,
                      labelMap: labelMap,
                      anchorMs: widget.anchorMs,
                      colors: gridColors,
                    ),
                  ),
                  // Center text
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        formatTimestamp(posMs.toInt()),
                        style: TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 22,
                          color: colors.textPrimary,
                        ),
                      ),
                      if (currentCaption.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          currentCaption,
                          style: TextStyle(
                            fontSize: 14,
                            color: colors.textSecondary,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildFallbackSlider() {
    final positionMs = widget.position.inMilliseconds.toDouble();
    final maxMs = _totalMs > 0 ? _totalMs : 1.0;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: SizedBox(
        height: 40,
        child: Slider(
          value: positionMs.clamp(0.0, maxMs),
          max: maxMs,
          onChanged: (value) {
            widget.onDragUpdate?.call(Duration(milliseconds: value.toInt()));
          },
          onChangeEnd: (value) {
            widget.onSeek(Duration(milliseconds: value.toInt()));
          },
        ),
      ),
    );
  }
}

class _CircularBeatGridPainter extends CustomPainter {
  final List<int> beats;
  final BeatGrid beatGrid;
  final double positionMs;
  final double totalMs;
  final List<Label> labels;
  final Map<int, List<Label>> labelMap;
  final int anchorMs;
  final BeatGridColors colors;

  _CircularBeatGridPainter({
    required this.beats,
    required this.beatGrid,
    required this.positionMs,
    required this.totalMs,
    required this.labels,
    required this.labelMap,
    required this.anchorMs,
    required this.colors,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (beats.isEmpty || totalMs <= 0) return;

    final center = Offset(size.width / 2, size.height / 2);
    final outerPadding = 16.0;
    final ringThickness = 22.0;
    final outerRadius = size.width / 2 - outerPadding;
    final innerRadius = outerRadius - ringThickness;
    final beatCount = beats.length;

    // Gap between arcs
    final arcGap = beatCount > 500 ? 0.0 : 0.005;
    final totalGap = arcGap * beatCount;
    final totalArc = 2 * pi - totalGap;

    // Each beat gets a proportional arc based on its interval
    // For simplicity, equal arcs
    final beatArc = totalArc / beatCount;

    for (int i = 0; i < beatCount; i++) {
      final beatMs = beats[i];
      // Start angle: -pi/2 (12 o'clock) + accumulated angle
      final startAngle = -pi / 2 + i * (beatArc + arcGap);

      final isMeasureStart = beatGrid.isMeasureStart(beatMs);
      final isAnchor = (beatMs - anchorMs).abs() < beatGrid.beatIntervalMs / 2;
      final isFilled = beatMs <= positionMs;

      final isCurrentBeat = i < beatCount - 1
          ? positionMs >= beatMs && positionMs < beats[i + 1]
          : positionMs >= beatMs;

      // Color
      Color beatColor;
      if (isCurrentBeat) {
        beatColor = colors.accent;
      } else if (isFilled) {
        beatColor = isMeasureStart
            ? colors.accentMuted
            : colors.accentSubtle;
      } else {
        beatColor = isMeasureStart
            ? colors.emptyStrong
            : colors.empty;
      }

      // Draw arc segment
      final arcOuter = isMeasureStart ? outerRadius + 3 : outerRadius;
      final arcRect = Rect.fromCircle(center: center, radius: (arcOuter + innerRadius) / 2);
      final arcPaint = Paint()
        ..color = beatColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = arcOuter - innerRadius
        ..strokeCap = StrokeCap.butt;

      canvas.drawArc(arcRect, startAngle, beatArc, false, arcPaint);

      // Anchor border
      if (isAnchor) {
        // Inner edge
        final innerArcRect = Rect.fromCircle(center: center, radius: innerRadius);
        canvas.drawArc(
          innerArcRect,
          startAngle,
          beatArc,
          false,
          Paint()
            ..color = colors.anchorStroke
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2
            ..strokeCap = StrokeCap.butt,
        );
        // Outer edge
        final outerArcRect = Rect.fromCircle(center: center, radius: arcOuter);
        canvas.drawArc(
          outerArcRect,
          startAngle,
          beatArc,
          false,
          Paint()
            ..color = colors.anchorStroke
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2
            ..strokeCap = StrokeCap.butt,
        );
      }

      // Label marker dot outside ring
      if (labelMap.containsKey(beatMs)) {
        final labelsOnBeat = labelMap[beatMs]!;
        final markerColor = labelsOnBeat.first.color;
        final midAngle = startAngle + beatArc / 2;
        final dotRadius = outerRadius + outerPadding / 2 + 2;
        final dotCenter = Offset(
          center.dx + dotRadius * cos(midAngle),
          center.dy + dotRadius * sin(midAngle),
        );
        canvas.drawCircle(dotCenter, 4, Paint()..color = markerColor);
      }
    }

    // Playhead line
    final fraction = (positionMs / totalMs).clamp(0.0, 1.0);
    final playheadAngle = -pi / 2 + fraction * 2 * pi;
    final innerPoint = Offset(
      center.dx + innerRadius * cos(playheadAngle),
      center.dy + innerRadius * sin(playheadAngle),
    );
    final outerPoint = Offset(
      center.dx + (outerRadius + 3) * cos(playheadAngle),
      center.dy + (outerRadius + 3) * sin(playheadAngle),
    );
    canvas.drawLine(
      innerPoint,
      outerPoint,
      Paint()
        ..color = colors.playhead
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(covariant _CircularBeatGridPainter oldDelegate) {
    return oldDelegate.positionMs != positionMs ||
        oldDelegate.beats != beats ||
        oldDelegate.totalMs != totalMs ||
        oldDelegate.labels != labels ||
        oldDelegate.colors != colors;
  }
}
