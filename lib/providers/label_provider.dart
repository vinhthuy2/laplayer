import 'package:flutter/foundation.dart';
import '../models/label.dart';
import '../services/database_service.dart';

class LabelProvider extends ChangeNotifier {
  final DatabaseService _db;
  final int projectId;
  List<Label> _labels = [];

  List<Label> get labels => _labels;

  LabelProvider({required this.projectId, DatabaseService? db})
      : _db = db ?? DatabaseService();

  Future<void> loadLabels() async {
    _labels = await _db.getLabelsByProject(projectId);
    notifyListeners();
  }

  Future<void> addLabel(int timestampMs, String caption,
      {int? colorValue}) async {
    final label = Label(
      projectId: projectId,
      timestampMs: timestampMs,
      caption: caption,
      sortOrder: _labels.length,
      colorValue: colorValue,
    );
    final id = await _db.insertLabel(label);
    _labels.add(label.copyWith(id: id));
    _labels.sort((a, b) => a.timestampMs.compareTo(b.timestampMs));
    notifyListeners();
  }

  Future<void> updateLabel(int labelId,
      {int? timestampMs, String? caption, int? colorValue}) async {
    final index = _labels.indexWhere((l) => l.id == labelId);
    if (index == -1) return;
    final updated = _labels[index].copyWith(
      timestampMs: timestampMs,
      caption: caption,
      colorValue: colorValue,
    );
    await _db.updateLabel(updated);
    _labels[index] = updated;
    _labels.sort((a, b) => a.timestampMs.compareTo(b.timestampMs));
    notifyListeners();
  }

  Future<void> updateCaption(int labelId, String newCaption) async {
    await updateLabel(labelId, caption: newCaption);
  }

  Future<void> deleteLabel(int labelId) async {
    await _db.deleteLabel(labelId);
    _labels.removeWhere((l) => l.id == labelId);
    notifyListeners();
  }

  int? nextLabelIndex(int currentPositionMs) {
    for (int i = 0; i < _labels.length; i++) {
      if (_labels[i].timestampMs > currentPositionMs) return i;
    }
    return null;
  }

  int? previousLabelIndex(int currentPositionMs) {
    for (int i = _labels.length - 1; i >= 0; i--) {
      if (_labels[i].timestampMs < currentPositionMs - 500) return i;
    }
    return null;
  }
}
