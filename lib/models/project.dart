class Project {
  final int? id;
  final String name;
  final String audioFilePath;
  final double bpm;
  final DateTime createdAt;
  final DateTime lastOpenedAt;
  final int anchorTimestampMs;

  Project({
    this.id,
    required this.name,
    required this.audioFilePath,
    required this.bpm,
    required this.createdAt,
    required this.lastOpenedAt,
    this.anchorTimestampMs = 0,
  });

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'name': name,
      'audioFilePath': audioFilePath,
      'bpm': bpm,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'lastOpenedAt': lastOpenedAt.millisecondsSinceEpoch,
      'anchorTimestampMs': anchorTimestampMs,
    };
  }

  factory Project.fromMap(Map<String, dynamic> map) {
    return Project(
      id: map['id'] as int?,
      name: map['name'] as String,
      audioFilePath: map['audioFilePath'] as String,
      bpm: (map['bpm'] as num).toDouble(),
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['createdAt'] as int),
      lastOpenedAt:
          DateTime.fromMillisecondsSinceEpoch(map['lastOpenedAt'] as int),
      anchorTimestampMs: map['anchorTimestampMs'] as int? ?? 0,
    );
  }

  Project copyWith({
    int? id,
    String? name,
    String? audioFilePath,
    double? bpm,
    DateTime? createdAt,
    DateTime? lastOpenedAt,
    int? anchorTimestampMs,
  }) {
    return Project(
      id: id ?? this.id,
      name: name ?? this.name,
      audioFilePath: audioFilePath ?? this.audioFilePath,
      bpm: bpm ?? this.bpm,
      createdAt: createdAt ?? this.createdAt,
      lastOpenedAt: lastOpenedAt ?? this.lastOpenedAt,
      anchorTimestampMs: anchorTimestampMs ?? this.anchorTimestampMs,
    );
  }
}
