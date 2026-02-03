import 'package:flutter/material.dart';
import '../models/project.dart';
import '../services/database_service.dart';
import '../services/audio_import_service.dart';
import '../theme/app_colors.dart';

class NewProjectDialog extends StatefulWidget {
  const NewProjectDialog({super.key});

  @override
  State<NewProjectDialog> createState() => _NewProjectDialogState();
}

class _NewProjectDialogState extends State<NewProjectDialog> {
  final _nameController = TextEditingController();
  final _bpmController = TextEditingController();
  final _audioImportService = AudioImportService();
  String? _audioFilePath;
  String? _audioFileName;
  bool _importing = false;

  Future<void> _pickAudioFile() async {
    setState(() => _importing = true);
    final path = await _audioImportService.pickAndCopyAudioFile();
    if (path != null) {
      setState(() {
        _audioFilePath = path;
        _audioFileName = _audioImportService.getFileName(path);
        _importing = false;
      });
    } else {
      setState(() => _importing = false);
    }
  }

  Future<void> _create() async {
    final name = _nameController.text.trim();
    final bpm = double.tryParse(_bpmController.text.trim());

    if (name.isEmpty || bpm == null || _audioFilePath == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in all fields')),
      );
      return;
    }

    final now = DateTime.now();
    final project = Project(
      name: name,
      audioFilePath: _audioFilePath!,
      bpm: bpm,
      createdAt: now,
      lastOpenedAt: now,
    );

    await DatabaseService().insertProject(project);
    if (mounted) Navigator.pop(context, true);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _bpmController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return AlertDialog(
      title: const Text('New Project'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Project Name',
                hintText: 'e.g. My Song Practice',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _bpmController,
              decoration: const InputDecoration(
                labelText: 'BPM',
                hintText: 'e.g. 120',
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 16),
            _importing
                ? const CircularProgressIndicator()
                : _audioFilePath != null
                    ? Row(
                        children: [
                          Icon(Icons.check_circle, color: colors.success),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _audioFileName ?? 'File selected',
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      )
                    : OutlinedButton.icon(
                        onPressed: _pickAudioFile,
                        icon: const Icon(Icons.audio_file),
                        label: const Text('Choose Audio File'),
                      ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _create,
          child: const Text('Create'),
        ),
      ],
    );
  }
}
