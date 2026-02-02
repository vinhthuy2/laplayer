import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/project.dart';
import '../models/label.dart';

class DatabaseService {
  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'laplayer.db');

    return openDatabase(
      path,
      version: 2,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE projects (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            audioFilePath TEXT NOT NULL,
            bpm REAL NOT NULL,
            createdAt INTEGER NOT NULL,
            lastOpenedAt INTEGER NOT NULL,
            anchorTimestampMs INTEGER NOT NULL DEFAULT 0
          )
        ''');
        await db.execute('''
          CREATE TABLE labels (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            projectId INTEGER NOT NULL,
            timestampMs INTEGER NOT NULL,
            caption TEXT NOT NULL,
            sortOrder INTEGER NOT NULL,
            colorValue INTEGER,
            FOREIGN KEY (projectId) REFERENCES projects (id) ON DELETE CASCADE
          )
        ''');
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute(
              'ALTER TABLE labels ADD COLUMN colorValue INTEGER');
          await db.execute(
              'ALTER TABLE projects ADD COLUMN anchorTimestampMs INTEGER NOT NULL DEFAULT 0');
        }
      },
    );
  }

  // --- Projects ---

  Future<int> insertProject(Project project) async {
    final db = await database;
    return db.insert('projects', project.toMap());
  }

  Future<List<Project>> getAllProjects() async {
    final db = await database;
    final maps = await db.query('projects', orderBy: 'lastOpenedAt DESC');
    return maps.map((m) => Project.fromMap(m)).toList();
  }

  Future<Project?> getProject(int id) async {
    final db = await database;
    final maps = await db.query('projects', where: 'id = ?', whereArgs: [id]);
    if (maps.isEmpty) return null;
    return Project.fromMap(maps.first);
  }

  Future<int> updateProject(Project project) async {
    final db = await database;
    return db.update('projects', project.toMap(),
        where: 'id = ?', whereArgs: [project.id]);
  }

  Future<void> updateLastOpenedAt(int projectId) async {
    final db = await database;
    await db.update(
      'projects',
      {'lastOpenedAt': DateTime.now().millisecondsSinceEpoch},
      where: 'id = ?',
      whereArgs: [projectId],
    );
  }

  Future<int> deleteProject(int id) async {
    final db = await database;
    await db.delete('labels', where: 'projectId = ?', whereArgs: [id]);
    return db.delete('projects', where: 'id = ?', whereArgs: [id]);
  }

  // --- Labels ---

  Future<int> insertLabel(Label label) async {
    final db = await database;
    return db.insert('labels', label.toMap());
  }

  Future<List<Label>> getLabelsByProject(int projectId) async {
    final db = await database;
    final maps = await db.query('labels',
        where: 'projectId = ?',
        whereArgs: [projectId],
        orderBy: 'timestampMs ASC');
    return maps.map((m) => Label.fromMap(m)).toList();
  }

  Future<int> updateLabel(Label label) async {
    final db = await database;
    return db.update('labels', label.toMap(),
        where: 'id = ?', whereArgs: [label.id]);
  }

  Future<int> deleteLabel(int id) async {
    final db = await database;
    return db.delete('labels', where: 'id = ?', whereArgs: [id]);
  }
}
