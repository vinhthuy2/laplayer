import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/label.dart';
import '../models/project.dart';
import '../providers/label_provider.dart';
import '../services/audio_service.dart';
import '../services/database_service.dart';
import '../theme/app_theme.dart';
import '../widgets/seek_bar.dart';
import '../widgets/label_tile.dart';
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
    _project = _project;
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
        builder: (ctx, setDialogState) => AlertDialog(
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
                            ? Border.all(color: Colors.white, width: 3)
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
        ),
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

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: _labelProvider,
      child: Scaffold(
        appBar: AppBar(
          title: Text(_project.name),
          actions: [
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
        body: Column(
          children: [
            if (_audioError != null)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                color: Colors.red.shade900,
                child: Text(
                  _audioError!,
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                ),
              ),
            const SizedBox(height: 16),
            // BPM + Speed display (long-press to set anchor)
            GestureDetector(
              onLongPress: _setAnchor,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${_project.bpm.toInt()} BPM · ${_speed}x',
                    style: const TextStyle(
                      fontSize: 18,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  if (_project.anchorTimestampMs > 0) ...[
                    const SizedBox(width: 8),
                    Icon(Icons.anchor, size: 14, color: AppColors.accent),
                    const SizedBox(width: 2),
                    Text(
                      formatTimestamp(_project.anchorTimestampMs),
                      style: const TextStyle(
                        fontSize: 12,
                        fontFamily: 'monospace',
                        color: AppColors.accent,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 8),
            // Time display
            StreamBuilder<Duration>(
              stream: _audioService.positionStream,
              builder: (context, posSnap) {
                final pos = _dragPosition ?? posSnap.data ?? Duration.zero;
                return StreamBuilder<Duration?>(
                  stream: _audioService.durationStream,
                  builder: (context, durSnap) {
                    final dur = durSnap.data ?? Duration.zero;
                    return Text(
                      '${formatDuration(pos)} / ${formatDuration(dur)}',
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 20,
                        color: AppColors.textPrimary,
                      ),
                    );
                  },
                );
              },
            ),
            const SizedBox(height: 8),
            // Seek bar
            StreamBuilder<Duration>(
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
            ),
            // Transport controls
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  icon: const Icon(Icons.skip_previous, size: 36),
                  onPressed: _seekToPreviousLabel,
                ),
                const SizedBox(width: 16),
                StreamBuilder<bool>(
                  stream: _audioService.playerStateStream
                      .map((state) => state.playing),
                  builder: (context, snapshot) {
                    final playing = snapshot.data ?? false;
                    return IconButton(
                      icon: Icon(
                        playing ? Icons.pause_circle : Icons.play_circle,
                        size: 56,
                        color: AppColors.accent,
                      ),
                      onPressed: _audioService.togglePlayPause,
                    );
                  },
                ),
                const SizedBox(width: 16),
                IconButton(
                  icon: const Icon(Icons.skip_next, size: 36),
                  onPressed: _seekToNextLabel,
                ),
              ],
            ),
            // Speed slider
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                children: [
                  const Text('Speed', style: TextStyle(color: AppColors.textSecondary)),
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
                  Text(
                    '${_speed}x',
                    style: const TextStyle(color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
            const Divider(),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Row(
                children: [
                  const Text(
                    'Labels',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            // Labels list
            Expanded(
              child: Consumer<LabelProvider>(
                builder: (context, labelProv, _) {
                  if (labelProv.labels.isEmpty) {
                    return const Center(
                      child: Text(
                        'No labels yet.\nPlay the song and tap + to mark sections.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white54),
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
              ),
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: _addLabel,
          child: const Icon(Icons.add),
        ),
      ),
    );
  }
}
