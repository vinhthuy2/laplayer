import 'package:flutter/material.dart';
import '../models/project.dart';
import '../theme/app_colors.dart';

class ProjectCard extends StatelessWidget {
  final Project project;
  final int labelCount;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  final VoidCallback onEdit;

  const ProjectCard({
    super.key,
    required this.project,
    required this.labelCount,
    required this.onTap,
    required this.onDelete,
    required this.onEdit,
  });

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);
    if (diff.inDays == 0) return 'Today';
    if (diff.inDays == 1) return 'Yesterday';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${date.month}/${date.day}/${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Dismissible(
      key: Key('project_${project.id}'),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        color: colors.destructive,
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      confirmDismiss: (direction) async {
        return showDialog<bool>(
          context: context,
          builder: (ctx) {
            final dlgColors = ctx.colors;
            return AlertDialog(
              title: const Text('Delete Project'),
              content: Text('Delete "${project.name}"? This cannot be undone.'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: Text('Delete',
                      style: TextStyle(color: dlgColors.destructiveText)),
                ),
              ],
            );
          },
        );
      },
      onDismissed: (_) => onDelete(),
      child: Card(
        child: ListTile(
          title: Text(
            project.name,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          subtitle: Text(
            '${project.bpm.toInt()} BPM · $labelCount labels',
          ),
          trailing: Text(
            _formatDate(project.lastOpenedAt),
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          onTap: onTap,
          onLongPress: onEdit,
        ),
      ),
    );
  }
}
