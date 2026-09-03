import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../data/models/project_model.dart';

// ── Result wrapper ────────────────────────────────────────────────────
sealed class DbResult<T> {}

class DbSuccess<T> extends DbResult<T> {
  final T data;
  DbSuccess(this.data);
}

class DbError<T> extends DbResult<T> {
  final String message;
  DbError(this.message);
}

// ── Duplicate reasons ─────────────────────────────────────────────────
enum DuplicateReason { urlAndName, captionExists, none }

// ─────────────────────────────────────────────────────────────────────
// ProjectDatabase
// ─────────────────────────────────────────────────────────────────────
class ProjectDatabase {
  ProjectDatabase._();
  static final ProjectDatabase instance = ProjectDatabase._();

  static Database? _db;

  static const _dbName = 'axpert.db';
  static const _dbVersion = 4;
  static const _table = 'projects';

  // ── Open / init ───────────────────────────────────────────────────

  Future<void> init() async => await _database;

  Future<Database> get _database async {
    _db ??= await _initDb();
    return _db!;
  }

  Future<Database> _initDb() async {
    final dir = await getDatabasesPath();
    final path = p.join(dir, _dbName);

    return openDatabase(
      path,
      version: _dbVersion,
      onCreate: (db, _) async {
        await db.execute('''
    CREATE TABLE $_table (
      id          INTEGER PRIMARY KEY AUTOINCREMENT,
      url         TEXT    NOT NULL,
      armurl      TEXT    NOT NULL DEFAULT '',
      schema_name TEXT    NOT NULL,
      caption     TEXT    NOT NULL DEFAULT '',
      logourl     TEXT    NOT NULL DEFAULT '',
      color       TEXT    NOT NULL DEFAULT '',
      created_at  INTEGER NOT NULL DEFAULT (strftime('%s','now'))
    )
  ''');
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        final columns = await db.rawQuery('PRAGMA table_info($_table)');
        final columnNames = columns.map((c) => c['name'] as String).toSet();

        if (oldVersion < 2 && !columnNames.contains('armurl')) {
          await db.execute(
            "ALTER TABLE $_table ADD COLUMN armurl TEXT NOT NULL DEFAULT ''",
          );
          await db.execute('DROP INDEX IF EXISTS idx_url_schema');
          await db.execute(
            'CREATE UNIQUE INDEX idx_url_schema ON $_table (url, armurl, schema_name)',
          );
        }
        if (oldVersion < 3 && !columnNames.contains('logourl')) {
          await db.execute(
            "ALTER TABLE $_table ADD COLUMN logourl TEXT NOT NULL DEFAULT ''",
          );
        }
        if (oldVersion < 4 && !columnNames.contains('color')) {
          await db.execute(
            "ALTER TABLE $_table ADD COLUMN color TEXT NOT NULL DEFAULT ''",
          );
        }
      },
    );
  }

  // ── Get all ───────────────────────────────────────────────────────
  Future<DbResult<List<ProjectModel>>> getAll() async {
    try {
      final db = await _database;
      final rows = await db.query(_table, orderBy: 'created_at ASC');
      return DbSuccess(rows.map(ProjectModel.fromMap).toList());
    } catch (e) {
      return DbError('Failed to load projects: $e');
    }
  }

  // ── Get by id ─────────────────────────────────────────────────────
  Future<DbResult<ProjectModel?>> getById(int id) async {
    try {
      final db = await _database;
      final rows = await db.query(
        _table,
        where: 'id = ?',
        whereArgs: [id],
        limit: 1,
      );
      if (rows.isEmpty) return DbSuccess(null);
      return DbSuccess(ProjectModel.fromMap(rows.first));
    } catch (e) {
      return DbError('Failed to fetch project: $e');
    }
  }

  // ── Get by schemaName ─────────────────────────────────────────────
  Future<DbResult<ProjectModel?>> getBySchemaName(String schemaName) async {
    try {
      final db = await _database;
      final rows = await db.query(
        _table,
        where: 'schema_name = ?',
        whereArgs: [schemaName.trim()],
        limit: 1,
      );
      if (rows.isEmpty) return DbSuccess(null);
      return DbSuccess(ProjectModel.fromMap(rows.first));
    } catch (e) {
      return DbError('Failed to fetch project: $e');
    }
  }

  // ── Add ───────────────────────────────────────────────────────────
  Future<DbResult<ProjectModel>> add(ProjectModel project) async {
    try {
      final dup = await checkDuplicate(
        url: project.url,
        armurl: project.armurl,
        schemaName: project.schemaName,
        caption: project.caption,
      );
      if (dup != DuplicateReason.none) return DbError(_dupMessage(dup));

      final db = await _database;
      final id = await db.insert(
        _table,
        project.toMap(),
        conflictAlgorithm: ConflictAlgorithm.fail,
      );
      return DbSuccess(project.copyWith(id: id));
    } catch (e) {
      return DbError('Failed to add project: $e');
    }
  }

  // ── Update ────────────────────────────────────────────────────────
  Future<DbResult<ProjectModel>> update(ProjectModel project) async {
    try {
      if (project.id == null) return DbError('Project has no ID');

      final dup = await checkDuplicate(
        url: project.url,
        armurl: project.armurl,
        schemaName: project.schemaName,
        caption: project.caption,
        excludeId: project.id,
      );
      if (dup != DuplicateReason.none) return DbError(_dupMessage(dup));

      final db = await _database;
      await db.update(
        _table,
        project.toMap(),
        where: 'id = ?',
        whereArgs: [project.id],
        conflictAlgorithm: ConflictAlgorithm.fail,
      );
      return DbSuccess(project);
    } catch (e) {
      return DbError('Failed to update project: $e');
    }
  }

  // ── Delete ────────────────────────────────────────────────────────
  Future<DbResult<bool>> delete(int id) async {
    try {
      final db = await _database;
      final count = await db.delete(_table, where: 'id = ?', whereArgs: [id]);
      if (count == 0) return DbError('Project not found');
      return DbSuccess(true);
    } catch (e) {
      return DbError('Failed to delete project: $e');
    }
  }

  // ── Duplicate check ───────────────────────────────────────────────
  /// Checks url+schemaName combo first, then caption.
  /// Pass [excludeId] when updating to ignore the current row.
  Future<DuplicateReason> checkDuplicate({
    required String url,
    required String armurl,
    required String schemaName,
    required String caption,
    int? excludeId,
  }) async {
    final db = await _database;

    // 1. url + schema_name
    final nameRows = await db.query(
      _table,
      where: excludeId != null
          ? 'url = ? AND armurl = ? AND schema_name = ? AND id != ?'
          : 'url = ? AND armurl = ? AND schema_name = ?',
      whereArgs: excludeId != null
          ? [url.trim(), armurl.trim(), schemaName.trim(), excludeId]
          : [url.trim(), armurl.trim(), schemaName.trim()],
      limit: 1,
    );
    if (nameRows.isNotEmpty) return DuplicateReason.urlAndName;

    // 2. caption (only if non-empty)
    if (caption.trim().isNotEmpty) {
      final taken = await isCaptionTaken(
        caption: caption,
        excludeId: excludeId,
      );
      if (taken) return DuplicateReason.captionExists;
    }

    return DuplicateReason.none;
  }

  /// Standalone caption uniqueness check.
  Future<bool> isCaptionTaken({required String caption, int? excludeId}) async {
    if (caption.trim().isEmpty) return false;
    final db = await _database;
    final rows = await db.query(
      _table,
      where: excludeId != null ? 'caption = ? AND id != ?' : 'caption = ?',
      whereArgs: excludeId != null
          ? [caption.trim(), excludeId]
          : [caption.trim()],
      limit: 1,
    );
    return rows.isNotEmpty;
  }

  // ── Close ─────────────────────────────────────────────────────────
  Future<void> close() async {
    final db = await _database;
    await db.close();
    _db = null;
  }

  // ── Helpers ───────────────────────────────────────────────────────
  String _dupMessage(DuplicateReason reason) => switch (reason) {
    DuplicateReason.urlAndName =>
      'A project with this URL and name already exists.',
    DuplicateReason.captionExists =>
      'This caption is already used by another project.',
    DuplicateReason.none => '',
  };

  // ── Get project by exact schema name ──────────────────────────────
  Future<DbResult<ProjectModel>> getProjectUrlFromProjectName(
    String projectName,
  ) async {
    try {
      final db = await _database;

      final result = await db.rawQuery(
        'SELECT * FROM $_table WHERE schema_name = ?',
        [projectName.trim()],
      );

      if (result.isNotEmpty) {
        return DbSuccess(ProjectModel.fromMap(result.first));
      } else {
        // Instead of returning a blank Project("", ""), we leverage your new DbResult pattern
        return DbError('Project not found');
      }
    } catch (e) {
      return DbError('Failed to fetch project: $e');
    }
  }
}
