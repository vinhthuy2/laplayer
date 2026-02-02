import 'package:flutter/material.dart';

const List<int> labelPresetColors = [
  0xFFFFC107, // Amber
  0xFFF44336, // Red
  0xFF2196F3, // Blue
  0xFF4CAF50, // Green
  0xFF9C27B0, // Purple
  0xFFFF9800, // Orange
  0xFF00BCD4, // Cyan
  0xFFE91E63, // Pink
];

class Label {
  final int? id;
  final int projectId;
  final int timestampMs;
  final String caption;
  final int sortOrder;
  final int? colorValue;

  Label({
    this.id,
    required this.projectId,
    required this.timestampMs,
    required this.caption,
    required this.sortOrder,
    this.colorValue,
  });

  Color get color => Color(colorValue ?? labelPresetColors[0]);

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'projectId': projectId,
      'timestampMs': timestampMs,
      'caption': caption,
      'sortOrder': sortOrder,
      'colorValue': colorValue,
    };
  }

  factory Label.fromMap(Map<String, dynamic> map) {
    return Label(
      id: map['id'] as int?,
      projectId: map['projectId'] as int,
      timestampMs: map['timestampMs'] as int,
      caption: map['caption'] as String,
      sortOrder: map['sortOrder'] as int,
      colorValue: map['colorValue'] as int?,
    );
  }

  Label copyWith({
    int? id,
    int? projectId,
    int? timestampMs,
    String? caption,
    int? sortOrder,
    int? colorValue,
  }) {
    return Label(
      id: id ?? this.id,
      projectId: projectId ?? this.projectId,
      timestampMs: timestampMs ?? this.timestampMs,
      caption: caption ?? this.caption,
      sortOrder: sortOrder ?? this.sortOrder,
      colorValue: colorValue ?? this.colorValue,
    );
  }
}
