import 'package:sqflite/sqflite.dart';
import '../models/offline_notification_model.dart';

/// SQLite owns read flags and deduplication across UI/background isolates.
class OfflineNotificationStore {
  static const table = 'offline_notifications';
  static Future<void> create(DatabaseExecutor db) async {
    await db.execute('''CREATE TABLE IF NOT EXISTS $table (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      event_key TEXT NOT NULL, username TEXT NOT NULL, project_name TEXT NOT NULL,
      type TEXT NOT NULL, queue_id TEXT NOT NULL, record_id INTEGER,
      record_version INTEGER NOT NULL DEFAULT 0, trans_id TEXT NOT NULL DEFAULT '',
      caption TEXT NOT NULL DEFAULT '', title TEXT NOT NULL, message TEXT NOT NULL,
      created_at TEXT NOT NULL, is_read INTEGER NOT NULL DEFAULT 0,
      is_deleted INTEGER NOT NULL DEFAULT 0,
      success_count INTEGER NOT NULL DEFAULT 0, failed_count INTEGER NOT NULL DEFAULT 0,
      UNIQUE(username, project_name, event_key))''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS offline_notifications_scope '
      'ON $table(username, project_name, is_deleted, is_read, id)',
    );
  }

  final Database db;
  final String username;
  final String projectName;
  OfflineNotificationStore(this.db, this.username, this.projectName);
  String get scope => 'username = ? AND project_name = ?';
  List<Object?> get args => [username, projectName];

  Future<void> add(Map<String, Object?> event) async {
    // Tombstones retain the event key so a deleted message cannot reappear.
    await db.insert(table, {
      ...event,
      'username': username,
      'project_name': projectName,
      'created_at': DateTime.now().toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
  }

  Future<List<OfflineNotificationModel>> list() async => (await db.query(
    table,
    where: '$scope AND is_deleted = 0',
    whereArgs: args,
    orderBy: 'id DESC',
  )).map(OfflineNotificationModel.fromMap).toList();

  Future<int> unreadCount() async =>
      Sqflite.firstIntValue(
        await db.rawQuery(
          'SELECT COUNT(*) FROM $table WHERE $scope AND is_deleted = 0 AND is_read = 0',
          args,
        ),
      ) ??
      0;

  Future<void> markRead(Iterable<int> ids) async {
    // Only mark the displayed snapshot; a concurrent new arrival stays unread.
    final batch = db.batch();
    for (final id in ids) {
      batch.update(
        table,
        {'is_read': 1},
        where: '$scope AND id = ?',
        whereArgs: [...args, id],
      );
    }
    await batch.commit(noResult: true);
  }

  Future<void> delete(int id) async {
    await db.update(
      table,
      {'is_deleted': 1},
      where: '$scope AND id = ?',
      whereArgs: [...args, id],
    );
  }

  Future<void> restore(int id) async {
    await db.update(
      table,
      {'is_deleted': 0},
      where: '$scope AND id = ?',
      whereArgs: [...args, id],
    );
  }

  Future<void> clear() async {
    await db.update(table, {'is_deleted': 1}, where: scope, whereArgs: args);
  }
}
