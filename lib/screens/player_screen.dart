import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/label.dart';
import '../models/project.dart';
import '../providers/label_provider.dart';
import '../providers/theme_provider.dart';
import '../services/audio_service.dart';
import '../services/database_service.dart';
import '../theme/app_colors.dart';
import '../widgets/seek_bar.dart';
import '../widgets/circular_beat_grid.dart';
import '../widgets/label_tile.dart';
import '../utils/beat_grid.dart';
import '../utils/time_format.dart';
import 'practice_screen.dart';
import 'project_settings_screen.dart';

class PlayerScreen extends StatefulWidget {
  final Project project;

  const PlayerScreen({super.key, required this.project});

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> {
  final AudioService _audioService = AudioService();
  late LabelProvider _labelProvider;
  late Project _project;
  double _speed = 1.0;
  Duration? _dragPosition;
  String? _audioError;

  @override
  void initState() {
    super.initState();
    _project = widget.project;
    _labelProvider = LabelProvider(projectId: _project.id!);
    _labelProvider.loadLabels();
    _loadAudio();
  }

  Future<void> _loadAudio() async {
    final path = _project.audioFilePath;
    if (!File(path).existsSync()) {
      setState(() => _audioError = 'Audio file not found:\n$path');
      return;
    }
    try {
      await _audioService.load(path);
    } catch (e) {
      setState(() => _audioError = 'Failed to load audio: $e');
    }
  }

  @override
  void dispose() {
    _audioService.dispose();
    _labelProvider.dispose();
    super.dispose();
  }


  Future<void> _setAnchor() async {
    final posMs = _audioService.position.inMilliseconds;
    final updated = _project.copyWith(anchorTimestampMs: posMs);
    await DatabaseService().updateProject(updated);
    setState(() => _project = updated);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Anchor set at ${formatTimestamp(posMs)}'),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _addLabel() async {
    final posMs = _audioService.position.inMilliseconds;
    final result = await _showLabelDialog(
      title: 'Add Label',
      initialTimestampMs: posMs,
      initialCaption: '',
      initialColorValue: labelPresetColors[0],
    );
    if (result == null) return;
    await _labelProvider.addLabel(
      result.timestampMs,
      result.caption,
      colorValue: result.colorValue,
    );
  }

  Future<void> _editLabel(Label label) async {
    final result = await _showLabelDialog(
      title: 'Edit Label',
      initialTimestampMs: label.timestampMs,
      initialCaption: label.caption,
      initialColorValue: label.colorValue ?? labelPresetColors[0],
    );
    if (result == null) return;
    await _labelProvider.updateLabel(
      label.id!,
      timestampMs: result.timestampMs,
      caption: result.caption,
      colorValue: result.colorValue,
    );
  }

  Future<({int timestampMs, String caption, int colorValue})?> _showLabelDialog({
    required String title,
    required int initialTimestampMs,
    required String initialCaption,
    required int initialColorValue,
  }) async {
    final timestampController =
        TextEditingController(text: formatTimestamp(initialTimestampMs));
    final captionController =
        TextEditingController(text: initialCaption);
    int selectedColor = initialColorValue;

    return showDialog<({int timestampMs, String caption, int colorValue})>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final colors = ctx.colors;
          return AlertDialog(
            title: Text(title),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: timestampController,
                  decoration: const InputDecoration(
                    labelText: 'Timestamp',
                    hintText: 'mm:ss.SSS',
                  ),
                  keyboardType: TextInputType.datetime,
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: captionController,
                  autofocus: initialCaption.isEmpty,
                  decoration: const InputDecoration(
                    labelText: 'Caption',
                    hintText: 'e.g. Verse 1, Chorus',
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: labelPresetColors.map((c) {
                    final isSelected = c == selectedColor;
                    return GestureDetector(
                      onTap: () => setDialogState(() => selectedColor = c),
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: Color(c),
                          shape: BoxShape.circle,
                          border: isSelected
                              ? Border.all(color: colors.textPrimary, width: 3)
                              : null,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () {
                  final caption = captionController.text.trim();
                  if (caption.isEmpty) return;
                  final parsedMs = parseTimestamp(timestampController.text.trim())
                      ?? initialTimestampMs;
                  Navigator.pop(ctx, (
                    timestampMs: parsedMs,
                    caption: caption,
                    colorValue: selectedColor,
                  ));
                },
                child: Text(initialCaption.isEmpty ? 'Add' : 'Save'),
              ),
            ],
          );
        },
      ),
    );
  }


  void _seekToNextLabel() {
    final idx = _labelProvider.nextLabelIndex(
      _audioService.position.inMilliseconds,
    );
    if (idx != null) {
      _audioService.seek(
        Duration(milliseconds: _labelProvider.labels[idx].timestampMs),
      );
    }
  }

  void _seekToPreviousLabel() {
    final idx = _labelProvider.previousLabelIndex(
      _audioService.position.inMilliseconds,
    );
    if (idx != null) {
      _audioService.seek(
        Duration(milliseconds: _labelProvider.labels[idx].timestampMs),
      );
    } else {
      _audioService.seek(Duration.zero);
    }
  }

  void _seekToNextBeat() {
    if (_project.bpm <= 0) return;
    final grid = BeatGrid(bpm: _project.bpm, anchorMs: _project.anchorTimestampMs);
    final durMs = _audioService.duration?.inMilliseconds ?? 0;
    final ms = grid.nextBeat(_audioService.position.inMilliseconds, durMs);
    if (ms != null) {
      _audioService.seek(Duration(milliseconds: ms));
    }
  }

  void _seekToPreviousBeat() {
    if (_project.bpm <= 0) return;
    final grid = BeatGrid(bpm: _project.bpm, anchorMs: _project.anchorTimestampMs);
    final ms = grid.previousBeat(_audioService.position.inMilliseconds);
    if (ms != null) {
      _audioService.seek(Duration(milliseconds: ms));
    } else {
      _audioService.seek(Duration.zero);
    }
  }

  // --- Shared widgets ---

  Widget _buildBpmRow() {
    final colors = context.colors;
    return GestureDetector(
      onLongPress: _setAnchor,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '${_project.bpm.toInt()} BPM · ${_speed}x',
            style: TextStyle(fontSize: 16, color: colors.textSecondary),
          ),
          if (_project.anchorTimestampMs > 0) ...[
            const SizedBox(width: 6),
            Icon(Icons.anchor, size: 12, color: colors.primary),
          ],
        ],
      ),
    );
  }

  Widget _buildTimeDisplay() {
    final colors = context.colors;
    return StreamBuilder<Duration>(
      stream: _audioService.positionStream,
      builder: (context, posSnap) {
        final pos = _dragPosition ?? posSnap.data ?? Duration.zero;
        return StreamBuilder<Duration?>(
          stream: _audioService.durationStream,
          builder: (context, durSnap) {
            final dur = durSnap.data ?? Duration.zero;
            return Text(
              '${formatDuration(pos)} / ${formatDuration(dur)}',
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 18,
                color: colors.textPrimary,
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildSeekBar() {
    return StreamBuilder<Duration>(
      stream: _audioService.positionStream,
      builder: (context, posSnap) {
        return StreamBuilder<Duration?>(
          stream: _audioService.durationStream,
          builder: (context, durSnap) {
            return Consumer<LabelProvider>(
              builder: (context, labelProv, _) {
                return SeekBar(
                  position: posSnap.data ?? Duration.zero,
                  duration: durSnap.data ?? Duration.zero,
                  labels: labelProv.labels,
                  bpm: _project.bpm,
                  anchorMs: _project.anchorTimestampMs,
                  onSeek: (duration) {
                    setState(() => _dragPosition = null);
                    _audioService.seek(duration);
                  },
                  onDragUpdate: (duration) {
                    setState(() => _dragPosition = duration);
                  },
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildCircularSeekBar() {
    return StreamBuilder<Duration>(
      stream: _audioService.positionStream,
      builder: (context, posSnap) {
        return StreamBuilder<Duration?>(
          stream: _audioService.durationStream,
          builder: (context, durSnap) {
            return Consumer<LabelProvider>(
              builder: (context, labelProv, _) {
                return CircularBeatGrid(
                  position: posSnap.data ?? Duration.zero,
                  duration: durSnap.data ?? Duration.zero,
                  labels: labelProv.labels,
                  bpm: _project.bpm,
                  anchorMs: _project.anchorTimestampMs,
                  onSeek: (duration) {
                    setState(() => _dragPosition = null);
                    _audioService.seek(duration);
                  },
                  onDragUpdate: (duration) {
                    setState(() => _dragPosition = duration);
                  },
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildTransportRow({double iconSize = 36, double playSize = 56}) {
    final colors = context.colors;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          icon: Icon(Icons.skip_previous, size: iconSize),
          onPressed: _seekToPreviousLabel,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
        ),
        const SizedBox(width: 8),
        IconButton(
          icon: Icon(Icons.chevron_left, size: iconSize),
          onPressed: _seekToPreviousBeat,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
        ),
        const SizedBox(width: 8),
        StreamBuilder<bool>(
          stream: _audioService.playerStateStream.map((s) => s.playing),
          builder: (context, snapshot) {
            final playing = snapshot.data ?? false;
            return IconButton(
              icon: Icon(
                playing ? Icons.pause_circle : Icons.play_circle,
                size: playSize,
                color: colors.primary,
              ),
              onPressed: _audioService.togglePlayPause,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            );
          },
        ),
        const SizedBox(width: 8),
        IconButton(
          icon: Icon(Icons.chevron_right, size: iconSize),
          onPressed: _seekToNextBeat,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
        ),
        const SizedBox(width: 8),
        IconButton(
          icon: Icon(Icons.skip_next, size: iconSize),
          onPressed: _seekToNextLabel,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
        ),
      ],
    );
  }

  Widget _buildSpeedRow() {
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        children: [
          Text('Speed', style: TextStyle(color: colors.textSecondary, fontSize: 12)),
          Expanded(
            child: Slider(
              value: _speed,
              min: 0.5,
              max: 2.0,
              divisions: 6,
              label: '${_speed}x',
              onChanged: (value) {
                setState(() => _speed = value);
                _audioService.setSpeed(value);
              },
            ),
          ),
          Text('${_speed}x', style: TextStyle(color: colors.textSecondary, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildLabelsList() {
    final colors = context.colors;
    return Consumer<LabelProvider>(
      builder: (context, labelProv, _) {
        if (labelProv.labels.isEmpty) {
          return Center(
            child: Text(
              'No labels yet.\nTap + to mark sections.',
              textAlign: TextAlign.center,
              style: TextStyle(color: colors.textTertiary, fontSize: 13),
            ),
          );
        }
        return ListView.builder(
          itemCount: labelProv.labels.length,
          itemBuilder: (context, index) {
            final label = labelProv.labels[index];
            return LabelTile(
              label: label,
              onTap: () => _audioService.seek(
                Duration(milliseconds: label.timestampMs),
              ),
              onDelete: () => labelProv.deleteLabel(label.id!),
              onEdit: () => _editLabel(label),
            );
          },
        );
      },
    );
  }

  // --- Portrait layout (vertical stack) ---

  List<Widget> _buildPortraitBody() {
    return [
      const SizedBox(height: 8),
      _buildBpmRow(),
      const SizedBox(height: 4),
      Expanded(
        flex: 3,
        child: _buildCircularSeekBar(),
      ),
      _buildTransportRow(),
      _buildSpeedRow(),
      const Divider(),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: Row(
          children: [
            const Text('Labels', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
      Expanded(flex: 2, child: _buildLabelsList()),
    ];
  }

  // --- Landscape layout (side-by-side) ---

  Widget _buildLandscapeBody() {
    final colors = context.colors;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Left: controls
        Expanded(
          flex: 3,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [_buildBpmRow(), const SizedBox(width: 16), _buildTimeDisplay()],
                ),
                const SizedBox(height: 6),
                _buildSeekBar(),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildTransportRow(iconSize: 28, playSize: 44),
                    const SizedBox(width: 16),
                    Text('Speed', style: TextStyle(color: colors.textSecondary, fontSize: 12)),
                    SizedBox(
                      width: 120,
                      child: Slider(
                        value: _speed,
                        min: 0.5,
                        max: 2.0,
                        divisions: 6,
                        label: '${_speed}x',
                        onChanged: (value) {
                          setState(() => _speed = value);
                          _audioService.setSpeed(value);
                        },
                      ),
                    ),
                    Text('${_speed}x', style: TextStyle(color: colors.textSecondary, fontSize: 12)),
                  ],
                ),
              ],
            ),
          ),
        ),
        const VerticalDivider(width: 1),
        // Right: labels
        Expanded(
          flex: 2,
          child: Column(
            children: [
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Row(
                  children: [
                    Text('Labels', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
              Expanded(child: _buildLabelsList()),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return ChangeNotifierProvider.value(
      value: _labelProvider,
      child: Scaffold(
        appBar: AppBar(
          title: Text(_project.name),
          actions: [
            IconButton(
              icon: Icon(
                context.watch<ThemeProvider>().isDark
                    ? Icons.light_mode
                    : Icons.dark_mode,
              ),
              onPressed: () => context.read<ThemeProvider>().toggle(),
            ),
            IconButton(
              icon: const Icon(Icons.settings),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        ProjectSettingsScreen(project: _project),
                  ),
                );
              },
            ),
            IconButton(
              icon: const Icon(Icons.play_circle_outline),
              tooltip: 'Practice Mode',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => PracticeScreen(
                      project: _project,
                      audioService: _audioService,
                      labels: _labelProvider.labels,
                    ),
                  ),
                );
              },
            ),
          ],
        ),
        body: OrientationBuilder(
          builder: (context, orientation) {
            final isLandscape = orientation == Orientation.landscape;
            return Column(
              children: [
                if (_audioError != null)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(8),
                    color: colors.destructive,
                    child: Text(
                      _audioError!,
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                    ),
                  ),
                if (isLandscape)
                  Expanded(child: _buildLandscapeBody())
                else
                  ..._buildPortraitBody(),
              ],
            );
          },
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: _addLabel,
          child: const Icon(Icons.add),
        ),
      ),
    );
  }
}
