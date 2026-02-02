import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/project.dart';
import '../models/label.dart';
import '../services/audio_service.dart';
import '../theme/app_theme.dart';
import '../utils/time_format.dart';

enum PracticeState { waiting, countdown, caption }

class PracticeDisplayState {
  final PracticeState state;
  final int beat;
  final int beatsElapsed;
  final double beatFraction;
  final String caption;
  final String nextCaption;
  final Color bgColor;

  const PracticeDisplayState({
    required this.state,
    required this.beat,
    required this.beatsElapsed,
    required this.beatFraction,
    required this.caption,
    required this.nextCaption,
    required this.bgColor,
  });
}

class PracticeScreen extends StatefulWidget {
  final Project project;
  final AudioService audioService;
  final List<Label> labels;

  const PracticeScreen({
    super.key,
    required this.project,
    required this.audioService,
    required this.labels,
  });

  @override
  State<PracticeScreen> createState() => _PracticeScreenState();
}

class _PracticeScreenState extends State<PracticeScreen> {
  double _fontSize = 64.0;
  Color _bgColor = Colors.black;

  final List<double> _speeds = [0.5, 0.75, 1.0, 1.25, 1.5];
  int _speedIndex = 2;

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    _loadDisplayConfig();
    if (!widget.audioService.isPlaying) {
      widget.audioService.play();
    }
  }

  @override
  void dispose() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    super.dispose();
  }

  Future<void> _loadDisplayConfig() async {
    final prefs = await SharedPreferences.getInstance();
    final key = 'project_${widget.project.id}';
    setState(() {
      _fontSize = prefs.getDouble('${key}_fontSize') ?? 64.0;
      _bgColor = Color(prefs.getInt('${key}_bgColor') ?? 0xFF000000);
    });
  }

  double get _effectiveBeatIntervalMs {
    final speed = _speeds[_speedIndex];
    return 60000.0 / (widget.project.bpm * speed);
  }

  void _cycleSpeed() {
    setState(() {
      _speedIndex = (_speedIndex + 1) % _speeds.length;
    });
    widget.audioService.setSpeed(_speeds[_speedIndex]);
  }

  PracticeDisplayState _computeState(Duration position) {
    final posMs = position.inMilliseconds;
    final beatIntervalMs = _effectiveBeatIntervalMs;
    final countdownDurationMs = (4 * beatIntervalMs).toInt();

    for (int i = 0; i < widget.labels.length; i++) {
      final label = widget.labels[i];
      final countdownStartMs = label.timestampMs - countdownDurationMs;

      // Check if we're in countdown zone for this label
      if (posMs >= countdownStartMs && posMs < label.timestampMs) {
        final elapsed = (posMs - countdownStartMs).toDouble();
        final beatsElapsed = (elapsed / beatIntervalMs).floor();
        final currentBeat = 4 - beatsElapsed;
        final beatFraction = (elapsed % beatIntervalMs) / beatIntervalMs;

        // Label color dimmed for countdown
        final labelColor = label.color;
        final dimmed = Color.lerp(Colors.black, labelColor, 0.3)!;
        final bright = Color.lerp(Colors.black, labelColor, 0.6)!;
        final flashBg = Color.lerp(
            bright, dimmed, (beatFraction / 0.3).clamp(0.0, 1.0))!;

        return PracticeDisplayState(
          state: PracticeState.countdown,
          beat: currentBeat.clamp(1, 4),
          beatsElapsed: beatsElapsed.clamp(0, 4),
          beatFraction: beatFraction,
          caption: '',
          nextCaption: label.caption,
          bgColor: flashBg,
        );
      }

      // Check if we're showing this label's caption
      final nextCountdownStart = i + 1 < widget.labels.length
          ? widget.labels[i + 1].timestampMs - countdownDurationMs
          : double.infinity;

      if (posMs >= label.timestampMs && posMs < nextCountdownStart) {
        return PracticeDisplayState(
          state: PracticeState.caption,
          beat: 4,
          beatsElapsed: 0,
          beatFraction: 0,
          caption: label.caption,
          nextCaption: '',
          bgColor: label.color,
        );
      }
    }

    return PracticeDisplayState(
      state: PracticeState.waiting,
      beat: 4,
      beatsElapsed: 0,
      beatFraction: 0,
      caption: '',
      nextCaption: '',
      bgColor: _bgColor,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.labels.isEmpty) {
      return Scaffold(
        backgroundColor: _bgColor,
        body: GestureDetector(
          onTap: widget.audioService.togglePlayPause,
          onVerticalDragEnd: (details) {
            if (details.primaryVelocity != null &&
                details.primaryVelocity! > 300) {
              Navigator.pop(context);
            }
          },
          child: const Center(
            child: Text(
              'No labels added yet.\nGo back and add labels first.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white54, fontSize: 20),
            ),
          ),
        ),
      );
    }

    return StreamBuilder<Duration>(
      stream: widget.audioService.positionStream,
      builder: (context, snapshot) {
        final pos = snapshot.data ?? Duration.zero;
        final displayState = _computeState(pos);

        return Scaffold(
          backgroundColor: displayState.bgColor,
          body: GestureDetector(
            onTap: widget.audioService.togglePlayPause,
            onVerticalDragEnd: (details) {
              if (details.primaryVelocity != null &&
                  details.primaryVelocity! > 300) {
                Navigator.pop(context);
              }
            },
            child: SafeArea(
              child: Column(
                children: [
                  Expanded(
                    child: Center(
                      child: _buildContent(displayState),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            GestureDetector(
                              onTap: _cycleSpeed,
                              child: Text(
                                '${_speeds[_speedIndex]}x',
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 18,
                                ),
                              ),
                            ),
                            const SizedBox(width: 24),
                            GestureDetector(
                              onTap: () =>
                                  widget.audioService.seek(Duration.zero),
                              child: const Icon(
                                Icons.replay,
                                color: Colors.white70,
                                size: 22,
                              ),
                            ),
                          ],
                        ),
                        StreamBuilder<Duration>(
                          stream: widget.audioService.positionStream,
                          builder: (context, snap) {
                            return Text(
                              formatDuration(snap.data ?? Duration.zero),
                              style: const TextStyle(
                                fontFamily: 'monospace',
                                color: Colors.white70,
                                fontSize: 16,
                              ),
                            );
                          },
                        ),
                        GestureDetector(
                          onTap: () => Navigator.pop(context),
                          child: const Text(
                            '× Exit',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 18,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildContent(PracticeDisplayState ds) {
    switch (ds.state) {
      case PracticeState.waiting:
        return StreamBuilder<Duration>(
          stream: widget.audioService.positionStream,
          builder: (context, snap) {
            final pos = snap.data ?? Duration.zero;
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Playing',
                  style: TextStyle(color: Colors.white38, fontSize: 16),
                ),
                const SizedBox(height: 8),
                Text(
                  formatDuration(pos),
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    color: Colors.white54,
                    fontSize: 32,
                  ),
                ),
              ],
            );
          },
        );

      case PracticeState.countdown:
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Next: ${ds.nextCaption}',
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 20,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              '${ds.beat}',
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 120,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(4, (i) {
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: Icon(
                    Icons.circle,
                    size: 16,
                    color: i < ds.beatsElapsed
                        ? AppColors.accent
                        : Colors.white24,
                  ),
                );
              }),
            ),
          ],
        );

      case PracticeState.caption:
        return Text(
          ds.caption,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: _fontSize,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        );
    }
  }
}
