import 'package:flutter/material.dart';
import '../models/label.dart';
import '../utils/time_format.dart';

class LabelTile extends StatelessWidget {
  final Label label;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  final VoidCallback onEdit;

  const LabelTile({
    super.key,
    required this.label,
    required this.onTap,
    required this.onDelete,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: Key('label_${label.id}'),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        color: Colors.red,
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      confirmDismiss: (_) async {
        return showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Delete Label'),
            content: const Text('Delete this label?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child:
                    const Text('Delete', style: TextStyle(color: Colors.red)),
              ),
            ],
          ),
        );
      },
      onDismissed: (_) => onDelete(),
      child: ListTile(
        leading: Icon(Icons.circle, size: 10, color: label.color),
        title: Text(label.caption),
        subtitle: Text(
          formatTimestamp(label.timestampMs),
          style: const TextStyle(
            fontFamily: 'monospace',
            color: Colors.white54,
          ),
        ),
        onTap: onTap,
        onLongPress: onEdit,
      ),
    );
  }
}
