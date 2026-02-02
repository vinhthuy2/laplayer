import 'package:flutter/material.dart';
import '../models/label.dart';
import '../theme/app_theme.dart';
import '../utils/beat_grid.dart';

class SeekBar extends StatefulWidget {
  final Duration position;
  final Duration duration;
  final List<Label> labels;
  final ValueChanged<Duration> onSeek;
  final ValueChanged<Duration>? onDragUpdate;
  final double? bpm;
  final int anchorMs;

  const SeekBar({
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
  State<SeekBar> createState() => _SeekBarState();
}

class _SeekBarState extends State<SeekBar> {
  double? _dragValue;
  double _zoomLevel = 1.0;
  final ScrollController _scrollController = ScrollController();
  bool _isDragging = false;

  double get _totalMs => widget.duration.inMilliseconds.toDouble();

  static const double _beatHeight = 24.0;
  static const double _labelMarkerHeight = 8.0;
  static const double _totalHeight = _beatHeight + _labelMarkerHeight + 4;
  static const double _maxBeatWidth = 20.0;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(SeekBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Auto-scroll to keep playhead visible when not dragging
    if (!_isDragging && _zoomLevel > 1.0 && _scrollController.hasClients) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _autoScrollToPlayhead();
      });
    }
  }

  void _autoScrollToPlayhead() {
    if (!_scrollController.hasClients || _totalMs <= 0) return;
    final fraction = widget.position.inMilliseconds / _totalMs;
    final contentWidth = _scrollController.position.maxScrollExtent +
        _scrollController.position.viewportDimension;
    final targetScroll = fraction * contentWidth -
        _scrollController.position.viewportDimension / 2;
    final clamped = targetScroll.clamp(
        0.0, _scrollController.position.maxScrollExtent);
    _scrollController.jumpTo(clamped);
  }

  @override
  Widget build(BuildContext context) {
    if (_totalMs <= 0 || widget.bpm == null || widget.bpm! <= 0) {
      return _buildFallbackSlider();
    }
    return _buildBeatGrid();
  }

  Widget _buildBeatGrid() {
    final beatGrid =
        BeatGrid(bpm: widget.bpm!, anchorMs: widget.anchorMs);
    final beats = beatGrid.beatsInRange(0, _totalMs.toInt());
    if (beats.isEmpty) return _buildFallbackSlider();

    final posMs = _dragValue ?? widget.position.inMilliseconds.toDouble();

    // Build label lookup: beat ms → list of labels on that beat
    final labelMap = <int, List<Label>>{};
    for (final label in widget.labels) {
      final snapped = beatGrid.snapToBeat(label.timestampMs);
      labelMap.putIfAbsent(snapped, () => []).add(label);
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final availableWidth = constraints.maxWidth;
          final maxZoom =
              (_maxBeatWidth * beats.length) / availableWidth;
          final effectiveMaxZoom = maxZoom.clamp(1.0, 20.0);

          return GestureDetector(
            onDoubleTap: () {
              setState(() => _zoomLevel = 1.0);
            },
            onScaleStart: (_) {},
            onScaleUpdate: (details) {
              if (details.pointerCount >= 2) {
                setState(() {
                  _zoomLevel =
                      (_zoomLevel * details.scale).clamp(1.0, effectiveMaxZoom);
                });
              }
            },
            child: SizedBox(
              height: _totalHeight,
              child: _zoomLevel > 1.0
                  ? SingleChildScrollView(
                      controller: _scrollController,
                      scrollDirection: Axis.horizontal,
                      child: _buildBeatGridContent(
                        beats,
                        beatGrid,
                        posMs,
                        labelMap,
                        availableWidth * _zoomLevel,
                      ),
                    )
                  : _buildBeatGridContent(
                      beats,
                      beatGrid,
                      posMs,
                      labelMap,
                      availableWidth,
                    ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildBeatGridContent(
    List<int> beats,
    BeatGrid beatGrid,
    double posMs,
    Map<int, List<Label>> labelMap,
    double contentWidth,
  ) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onHorizontalDragStart: (details) {
        _isDragging = true;
        _handleDrag(details.localPosition.dx, contentWidth, beats);
      },
      onHorizontalDragUpdate: (details) {
        _handleDrag(details.localPosition.dx, contentWidth, beats);
      },
      onHorizontalDragEnd: (_) {
        _isDragging = false;
        if (_dragValue != null) {
          widget.onSeek(Duration(milliseconds: _dragValue!.toInt()));
          setState(() => _dragValue = null);
        }
      },
      onTapUp: (details) {
        final fraction = (details.localPosition.dx / contentWidth).clamp(0.0, 1.0);
        final ms = fraction * _totalMs;
        widget.onSeek(Duration(milliseconds: ms.toInt()));
      },
      child: CustomPaint(
        size: Size(contentWidth, _totalHeight),
        painter: _BeatGridPainter(
          beats: beats,
          beatGrid: beatGrid,
          positionMs: posMs,
          totalMs: _totalMs,
          labels: widget.labels,
          labelMap: labelMap,
          anchorMs: widget.anchorMs,
        ),
      ),
    );
  }

  void _handleDrag(double dx, double contentWidth, List<int> beats) {
    final fraction = (dx / contentWidth).clamp(0.0, 1.0);
    final ms = fraction * _totalMs;
    setState(() => _dragValue = ms);
    widget.onDragUpdate?.call(Duration(milliseconds: ms.toInt()));
  }

  Widget _buildFallbackSlider() {
    final positionMs =
        _dragValue ?? widget.position.inMilliseconds.toDouble();
    final maxMs = _totalMs > 0 ? _totalMs : 1.0;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: SizedBox(
        height: 40,
        child: SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 4,
            trackShape: const RoundedRectSliderTrackShape(),
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 12),
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 24),
          ),
          child: Slider(
            value: positionMs.clamp(0.0, maxMs),
            max: maxMs,
            onChanged: (value) {
              setState(() => _dragValue = value);
              widget.onDragUpdate
                  ?.call(Duration(milliseconds: value.toInt()));
            },
            onChangeEnd: (value) {
              widget.onSeek(Duration(milliseconds: value.toInt()));
              setState(() => _dragValue = null);
            },
          ),
        ),
      ),
    );
  }
}

class _BeatGridPainter extends CustomPainter {
  final List<int> beats;
  final BeatGrid beatGrid;
  final double positionMs;
  final double totalMs;
  final List<Label> labels;
  final Map<int, List<Label>> labelMap;
  final int anchorMs;

  _BeatGridPainter({
    required this.beats,
    required this.beatGrid,
    required this.positionMs,
    required this.totalMs,
    required this.labels,
    required this.labelMap,
    required this.anchorMs,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (beats.isEmpty || totalMs <= 0) return;

    final beatCount = beats.length;
    final gap = 1.0;
    final totalGaps = (beatCount - 1) * gap;
    final beatWidth = (size.width - totalGaps) / beatCount;
    final beatHeight = 24.0;
    final markerY = 0.0;
    final beatY = 12.0; // Leave room for label markers above

    for (int i = 0; i < beatCount; i++) {
      final beatMs = beats[i];
      final x = i * (beatWidth + gap);

      final isMeasureStart = beatGrid.isMeasureStart(beatMs);
      final isAnchor = (beatMs - anchorMs).abs() < beatGrid.beatIntervalMs / 2;
      final isFilled = beatMs <= positionMs;

      // Determine if this is the "current" beat
      final isCurrentBeat = i < beatCount - 1
          ? positionMs >= beatMs && positionMs < beats[i + 1]
          : positionMs >= beatMs;

      // Beat rectangle color
      Color beatColor;
      if (isCurrentBeat) {
        beatColor = AppColors.accent;
      } else if (isFilled) {
        beatColor =
            isMeasureStart ? AppColors.accent.withAlpha(160) : AppColors.accent.withAlpha(100);
      } else {
        beatColor = isMeasureStart
            ? const Color(0x4DFFFFFF) // white30
            : const Color(0x1FFFFFFF); // white12
      }

      // Draw beat rectangle
      final rect = Rect.fromLTWH(x, beatY, beatWidth, beatHeight);
      canvas.drawRect(rect, Paint()..color = beatColor);

      // Anchor indicator: bright border
      if (isAnchor) {
        canvas.drawRect(
          rect,
          Paint()
            ..color = AppColors.accent
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2,
        );
      }

      // Label markers above the beat
      if (labelMap.containsKey(beatMs)) {
        final labelsOnBeat = labelMap[beatMs]!;
        final markerColor = labelsOnBeat.first.color;
        final trianglePath = Path()
          ..moveTo(x + beatWidth / 2, markerY)
          ..lineTo(x + beatWidth / 2 + 4, markerY + 8)
          ..lineTo(x + beatWidth / 2 - 4, markerY + 8)
          ..close();
        canvas.drawPath(trianglePath, Paint()..color = markerColor);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _BeatGridPainter oldDelegate) {
    return oldDelegate.positionMs != positionMs ||
        oldDelegate.beats != beats ||
        oldDelegate.totalMs != totalMs ||
        oldDelegate.labels != labels;
  }
}
