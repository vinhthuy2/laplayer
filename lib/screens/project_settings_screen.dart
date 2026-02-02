import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/project.dart';
import '../services/database_service.dart';
import '../theme/app_theme.dart';
import '../utils/time_format.dart';

class ProjectSettingsScreen extends StatefulWidget {
  final Project project;

  const ProjectSettingsScreen({super.key, required this.project});

  @override
  State<ProjectSettingsScreen> createState() => _ProjectSettingsScreenState();
}

class _ProjectSettingsScreenState extends State<ProjectSettingsScreen> {
  final _db = DatabaseService();
  late TextEditingController _nameController;
  late TextEditingController _bpmController;
  late TextEditingController _anchorController;
  double _fontSize = 64.0;
  Color _bgColor = Colors.black;
  Color _countdownBgColor = Colors.black;

  static const _bgColorPresets = [
    Colors.black,
    Color(0xFF1A237E),
    Color(0xFF1B5E20),
    Color(0xFFB71C1C),
    Color(0xFF4A148C),
  ];

  static const _countdownColorPresets = [
    Colors.black,
    Color(0xFF3E2723),
    Color(0xFF0D47A1),
    Color(0xFFE65100),
    Colors.white,
  ];

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.project.name);
    _bpmController =
        TextEditingController(text: widget.project.bpm.toInt().toString());
    _anchorController = TextEditingController(
        text: formatTimestamp(widget.project.anchorTimestampMs));
    _loadPrefs();
  }

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final key = 'project_${widget.project.id}';
    setState(() {
      _fontSize = prefs.getDouble('${key}_fontSize') ?? 64.0;
      _bgColor = Color(prefs.getInt('${key}_bgColor') ?? 0xFF000000);
      _countdownBgColor =
          Color(prefs.getInt('${key}_countdownBgColor') ?? 0xFF000000);
    });
  }

  Future<void> _savePrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final key = 'project_${widget.project.id}';
    await prefs.setDouble('${key}_fontSize', _fontSize);
    await prefs.setInt('${key}_bgColor', _bgColor.toARGB32());
    await prefs.setInt('${key}_countdownBgColor', _countdownBgColor.toARGB32());
  }

  Future<void> _saveProject() async {
    final anchorMs =
        parseTimestamp(_anchorController.text.trim()) ?? widget.project.anchorTimestampMs;
    final updated = widget.project.copyWith(
      name: _nameController.text.trim(),
      bpm: double.tryParse(_bpmController.text) ?? widget.project.bpm,
      anchorTimestampMs: anchorMs,
    );
    await _db.updateProject(updated);
  }

  @override
  void dispose() {
    _saveProject();
    _nameController.dispose();
    _bpmController.dispose();
    _anchorController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Project',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(labelText: 'Project Name'),
            onChanged: (_) => _saveProject(),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _bpmController,
            decoration: const InputDecoration(labelText: 'BPM'),
            keyboardType: TextInputType.number,
            onChanged: (_) => _saveProject(),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _anchorController,
                  decoration: const InputDecoration(
                    labelText: 'Beat Anchor',
                    hintText: 'mm:ss.SSS',
                  ),
                  keyboardType: TextInputType.datetime,
                  onChanged: (_) => _saveProject(),
                ),
              ),
              const SizedBox(width: 8),
              TextButton(
                onPressed: () {
                  _anchorController.text = formatTimestamp(0);
                  _saveProject();
                },
                child: const Text('Reset'),
              ),
            ],
          ),
          const SizedBox(height: 32),
          const Text(
            'Practice Mode Display',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          // Font size slider
          Row(
            children: [
              const Text('Small', style: TextStyle(color: AppColors.textSecondary)),
              Expanded(
                child: Slider(
                  value: _fontSize,
                  min: 48,
                  max: 96,
                  onChanged: (value) {
                    setState(() => _fontSize = value);
                    _savePrefs();
                  },
                ),
              ),
              const Text('Large', style: TextStyle(color: AppColors.textSecondary)),
            ],
          ),
          // Preview
          Container(
            height: 80,
            margin: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: _bgColor,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.white24),
            ),
            child: Center(
              child: Text(
                'Sample',
                style: TextStyle(
                  fontSize: _fontSize.clamp(24, 48),
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          // Caption background color
          const Text('Caption Background',
              style: TextStyle(color: AppColors.textSecondary)),
          const SizedBox(height: 8),
          Row(
            children: _bgColorPresets.map((color) {
              final selected = _bgColor.toARGB32() == color.toARGB32();
              return Padding(
                padding: const EdgeInsets.only(right: 12),
                child: GestureDetector(
                  onTap: () {
                    setState(() => _bgColor = color);
                    _savePrefs();
                  },
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: selected ? AppColors.accent : Colors.white24,
                        width: selected ? 3 : 1,
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
          // Countdown background color
          const Text('Countdown Background',
              style: TextStyle(color: AppColors.textSecondary)),
          const SizedBox(height: 8),
          Row(
            children: _countdownColorPresets.map((color) {
              final selected =
                  _countdownBgColor.toARGB32() == color.toARGB32();
              return Padding(
                padding: const EdgeInsets.only(right: 12),
                child: GestureDetector(
                  onTap: () {
                    setState(() => _countdownBgColor = color);
                    _savePrefs();
                  },
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: selected ? AppColors.accent : Colors.white24,
                        width: selected ? 3 : 1,
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}
