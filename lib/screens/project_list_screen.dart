import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/project.dart';
import '../providers/theme_provider.dart';
import '../services/database_service.dart';
import '../theme/app_colors.dart';
import '../widgets/project_card.dart';
import 'new_project_dialog.dart';
import 'player_screen.dart';

class ProjectListScreen extends StatefulWidget {
  const ProjectListScreen({super.key});

  @override
  State<ProjectListScreen> createState() => _ProjectListScreenState();
}

class _ProjectListScreenState extends State<ProjectListScreen> {
  final _db = DatabaseService();
  List<Project> _projects = [];
  Map<int, int> _labelCounts = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadProjects();
  }

  Future<void> _loadProjects() async {
    final projects = await _db.getAllProjects();
    final counts = <int, int>{};
    for (final p in projects) {
      final labels = await _db.getLabelsByProject(p.id!);
      counts[p.id!] = labels.length;
    }
    setState(() {
      _projects = projects;
      _labelCounts = counts;
      _loading = false;
    });
  }

  Future<void> _openProject(Project project) async {
    await _db.updateLastOpenedAt(project.id!);
    if (!mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => PlayerScreen(project: project)),
    );
    _loadProjects();
  }

  Future<void> _deleteProject(int id) async {
    await _db.deleteProject(id);
    _loadProjects();
  }

  Future<void> _editProject(Project project) async {
    final nameController = TextEditingController(text: project.name);
    final bpmController =
        TextEditingController(text: project.bpm.toInt().toString());

    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: 24,
          right: 24,
          top: 24,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Edit Project',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: 'Project Name'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: bpmController,
              decoration: const InputDecoration(labelText: 'BPM'),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );

    if (result == true) {
      final updatedProject = project.copyWith(
        name: nameController.text.trim(),
        bpm: double.tryParse(bpmController.text) ?? project.bpm,
      );
      await _db.updateProject(updatedProject);
      _loadProjects();
    }
  }

  Future<void> _createProject() async {
    final created = await showDialog<bool>(
      context: context,
      builder: (_) => const NewProjectDialog(),
    );
    if (created == true) {
      _loadProjects();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('LaPlayer'),
        actions: [
          IconButton(
            icon: Icon(
              context.watch<ThemeProvider>().isDark
                  ? Icons.light_mode
                  : Icons.dark_mode,
            ),
            onPressed: () => context.read<ThemeProvider>().toggle(),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _projects.isEmpty
              ? _buildEmptyState()
              : ListView.builder(
                  padding: const EdgeInsets.only(top: 8, bottom: 80),
                  itemCount: _projects.length,
                  itemBuilder: (context, index) {
                    final project = _projects[index];
                    return ProjectCard(
                      project: project,
                      labelCount: _labelCounts[project.id] ?? 0,
                      onTap: () => _openProject(project),
                      onDelete: () => _deleteProject(project.id!),
                      onEdit: () => _editProject(project),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: _createProject,
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildEmptyState() {
    final colors = context.colors;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.music_note, size: 64, color: colors.textTertiary),
          const SizedBox(height: 16),
          Text(
            'No projects yet.\nImport a song to get started.',
            textAlign: TextAlign.center,
            style: TextStyle(color: colors.textSecondary),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _createProject,
            icon: const Icon(Icons.add),
            label: const Text('New Project'),
          ),
        ],
      ),
    );
  }
}
