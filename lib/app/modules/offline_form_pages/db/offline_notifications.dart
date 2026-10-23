part of 'offline_db_module.dart';

class OfflineNotifications {
  static Future<OfflineUpdateNotificationRun?> beginUpdate() async {
    try {
      final scope = await OfflineDbModule._getLastOfflineUserScope();
      if (scope == null) return null;
      return OfflineUpdateNotificationRun(
        scope['username']!,
        scope['projectName']!,
        OfflineDbModule.getGUID(),
      );
    } catch (e) {
      LogService.writeLog(
        message: '[OFFLINE_NOTIFICATION] Could not capture update scope: $e',
      );
      return null; // Notification problems never prevent the original operation.
    }
  }

  static bool _retrying = false;
  static final Map<String, DateTime> _lastRetry = {};
  static Future<void> retryTriggeredResults() async {
    if (_retrying) return;
    _retrying = true;
    try {
      final scope = await OfflineDbModule._getLastOfflineUserScope();
      if (scope == null) return;
      final rows = await OfflineDbModule._database.query(
        OfflineDBConstants.TABLE_CACHED_SAVE_QUEUE,
        columns: ['queue_id', 'fcm_response'],
        where:
            "username = ? AND project_name = ? AND status = ? AND fcm_response != ''",
        whereArgs: [
          scope['username'],
          scope['projectName'],
          OfflineDBConstants.QUEUE_STATUS_PENDING,
        ],
        orderBy: 'updated_at ASC',
      );
      for (final row in rows) {
        final queueId = row['queue_id'] as String;
        final last = _lastRetry[queueId];
        if (last != null &&
            DateTime.now().difference(last) < const Duration(seconds: 20)) {
          continue;
        }
        final data = jsonDecode(row['fcm_response'] as String);
        if (data is Map<String, dynamic> && data.containsKey('axm_queueid')) {
          _lastRetry[queueId] = DateTime.now();
          await OfflineDbModule.processCachedSaveQueueFCM(data);
          break; // Keep each UI tick small; subsequent batches get their turn.
        }
      }
    } catch (e) {
      LogService.writeLog(
        message: '[OFFLINE_NOTIFICATION] Deferred result retry failed: $e',
      );
    } finally {
      _retrying = false;
    }
  }

  // The active offline scope follows the existing offline page/record queries.
  static Future<OfflineNotificationStore?> store() async {
    final scope = await OfflineDbModule._getLastOfflineUserScope();
    if (scope == null) return null;
    return OfflineNotificationStore(
      OfflineDbModule._database,
      scope['username']!,
      scope['projectName']!,
    );
  }

  static Future<List<OfflineNotificationModel>> list() async =>
      await (await store())?.list() ?? [];
  static Future<int> unreadCount() async =>
      await (await store())?.unreadCount() ?? 0;

  /// Observe parsed results already saved by the existing notification path.
  /// No network calls or notification/queue writes are performed here.
  static Future<OfflineBatchBannerSnapshot?> batchBannerSnapshot({
    String? previousScope,
    int afterId = 0,
  }) async {
    final scopedStore = await store();
    if (scopedStore == null) return null;
    final scopeKey = jsonEncode([
      scopedStore.username,
      scopedStore.projectName,
    ]);
    final newest =
        Sqflite.firstIntValue(
          await scopedStore.db.rawQuery(
            'SELECT MAX(id) FROM offline_notifications WHERE ${scopedStore.scope}',
            scopedStore.args,
          ),
        ) ??
        0;
    if (previousScope != scopeKey) {
      return OfflineBatchBannerSnapshot(
        scope: scopeKey,
        lastId: newest,
        baseline: true,
      );
    }
    if (newest <= afterId) {
      return OfflineBatchBannerSnapshot(scope: scopeKey, lastId: afterId);
    }
    final events = await scopedStore.db.rawQuery(
      '''
      SELECT n.id, n.queue_id, n.event_key, n.type, n.success_count,
             n.failed_count, n.is_deleted
      FROM offline_notifications n
      JOIN cached_save_queue q ON q.queue_id = n.queue_id
        AND q.username = n.username AND q.project_name = n.project_name
      WHERE n.username = ? AND n.project_name = ? AND n.id > ? AND n.id <= ?
        AND n.type IN ('batch_success', 'batch_error')
        AND (q.source_table = ? OR q.source_table IS NULL OR q.source_table = '')
      ORDER BY n.id ASC
    ''',
      [
        ...scopedStore.args,
        afterId,
        newest,
        OfflineDBConstants.TABLE_PENDING_REQUESTS,
      ],
    );
    return OfflineBatchBannerSnapshot(
      scope: scopeKey,
      lastId: newest,
      events: events,
    );
  }

  static Future<void> markRead(Iterable<int> ids) async =>
      (await store())?.markRead(ids);
  static Future<void> delete(int id) async {
    await (await store())?.delete(id);
    LogService.writeLog(
      message: '[OFFLINE_NOTIFICATION] Deleted notification=$id',
    );
  }

  static Future<void> restore(int id) async {
    await (await store())?.restore(id);
    LogService.writeLog(
      message: '[OFFLINE_NOTIFICATION] Restored notification=$id',
    );
  }

  static Future<void> clear() async {
    await (await store())?.clear();
    LogService.writeLog(
      message: '[OFFLINE_NOTIFICATION] Cleared current scope messages',
    );
  }

  static Future<void> add({
    required String username,
    required String projectName,
    required String eventKey,
    required String type,
    required String queueId,
    required String title,
    required String message,
    int? recordId,
    int recordVersion = 0,
    String transId = '',
    String caption = '',
    int successCount = 0,
    int failedCount = 0,
  }) async {
    // Notification failures must never change the existing sync result.
    try {
      await OfflineNotificationStore(
        OfflineDbModule._database,
        username,
        projectName,
      ).add({
        'event_key': eventKey,
        'type': type,
        'queue_id': queueId,
        'record_id': recordId,
        'record_version': recordVersion,
        'trans_id': transId,
        'caption': caption,
        'title': title,
        'message': message,
        'success_count': successCount,
        'failed_count': failedCount,
      });
      LogService.writeLog(
        message:
            '[OFFLINE_NOTIFICATION] Stored type=$type queue=$queueId record=$recordId',
      );
    } catch (e) {
      LogService.writeLog(message: '[OFFLINE_NOTIFICATION] Storage failed: $e');
    }
  }

  static Future<Map<String, dynamic>?> loadRecord(int id) async {
    final scope = await OfflineDbModule._getLastOfflineUserScope();
    if (scope == null) return null;
    final rows = await OfflineDbModule._database.query(
      OfflineDBConstants.TABLE_PENDING_REQUESTS,
      columns: [
        'id',
        'status',
        'response',
        'record_version',
        'current_queue_id',
      ],
      where: 'id = ? AND username = ? AND project_name = ?',
      whereArgs: [id, scope['username'], scope['projectName']],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    final raw = await OfflineDbModule._readLargeString(
      table: OfflineDBConstants.TABLE_PENDING_REQUESTS,
      column: OfflineDBConstants.COL_REQUEST_JSON,
      where: 'id = ? AND username = ? AND project_name = ?',
      whereArgs: [id, scope['username'], scope['projectName']],
    );
    if (raw == null) return null;
    return {...rows.single, 'payload': jsonDecode(raw)};
  }

  static Future<List<int>> eligibleIds(String queueId) async {
    final queues = await OfflineDbModule._database.query(
      OfflineDBConstants.TABLE_CACHED_SAVE_QUEUE,
      where: 'queue_id = ?',
      whereArgs: [queueId],
      limit: 1,
    );
    if (queues.isEmpty) return [];
    final queue = queues.single;
    if (queue['source_table'] == OfflineDBConstants.TABLE_AUDIT_LOGS) return [];
    final ids = (jsonDecode(queue['axm_recids'] as String? ?? '[]') as List)
        .map((id) => int.tryParse(id.toString()))
        .whereType<int>()
        .toList();
    if (ids.isEmpty) return [];
    final rows = await OfflineDbModule._database.query(
      OfflineDBConstants.TABLE_PENDING_REQUESTS,
      columns: ['id'],
      where:
          'id IN (${List.filled(ids.length, '?').join(',')}) '
          'AND username = ? AND project_name = ? '
          "AND (current_queue_id = ? OR (current_queue_id = '' AND record_version = 0))",
      whereArgs: [...ids, queue['username'], queue['project_name'], queueId],
    );
    return rows.map((row) => row['id'] as int).toList();
  }

  static Future<void> queueIssue(String queueId, String message) async {
    final rows = await OfflineDbModule._database.query(
      OfflineDBConstants.TABLE_CACHED_SAVE_QUEUE,
      where: 'queue_id = ?',
      whereArgs: [queueId],
      limit: 1,
    );
    if (rows.isEmpty ||
        rows.single['source_table'] == OfflineDBConstants.TABLE_AUDIT_LOGS) {
      return;
    }
    await add(
      username: rows.single['username'] as String,
      projectName: rows.single['project_name'] as String,
      eventKey: '$queueId:issue:${OfflineDbModule.generateMd5(message)}',
      type: 'batch_error',
      queueId: queueId,
      title: 'Submission needs attention',
      message: message,
    );
  }

  static Future<void> queueResult(
    String queueId,
    Map<String, dynamic> data, {
    required int successCount,
    required int failedCount,
  }) async {
    try {
      final queues = await OfflineDbModule._database.query(
        OfflineDBConstants.TABLE_CACHED_SAVE_QUEUE,
        where: 'queue_id = ?',
        whereArgs: [queueId],
        limit: 1,
      );
      if (queues.isEmpty ||
          queues.single['source_table'] ==
              OfflineDBConstants.TABLE_AUDIT_LOGS) {
        return;
      }
      final queue = queues.single;
      final user = queue['username'] as String;
      final project = queue['project_name'] as String;
      await add(
        username: user,
        projectName: project,
        eventKey: '$queueId:result',
        type: failedCount == 0 ? 'batch_success' : 'batch_error',
        queueId: queueId,
        title: failedCount == 0
            ? 'Batch processed successfully'
            : 'Batch processed with issues',
        message: '$successCount successful • $failedCount failed',
        successCount: successCount,
        failedCount: failedCount,
      );
      final eligible = (await eligibleIds(queueId)).toSet();
      for (final item in OfflineDbModule._parseTransactionList(
        data['failed_transactions'],
      )) {
        final id = int.tryParse(item['axm_recid']?.toString() ?? '');
        if (id == null || !eligible.contains(id)) continue;
        final rows = await OfflineDbModule._database.query(
          OfflineDBConstants.TABLE_PENDING_REQUESTS,
          columns: ['record_version', 'response'],
          where: 'id = ? AND username = ? AND project_name = ?',
          whereArgs: [id, user, project],
          limit: 1,
        );
        if (rows.isEmpty) continue;
        final raw = await OfflineDbModule._readLargeString(
          table: OfflineDBConstants.TABLE_PENDING_REQUESTS,
          column: OfflineDBConstants.COL_REQUEST_JSON,
          where: 'id = ?',
          whereArgs: [id],
        );
        if (raw == null) continue;
        final payload = jsonDecode(raw) as Map<String, dynamic>;
        final transId = payload['transid']?.toString() ?? '';
        final pages = await OfflineDbModule._database.query(
          OfflineDBConstants.TABLE_OFFLINE_PAGES,
          columns: [OfflineDBConstants.COL_PAGE_JSON],
          where: 'trans_id = ? AND username = ? AND project_name = ?',
          whereArgs: [transId, user, project],
          limit: 1,
        );
        final caption = pages.isEmpty
            ? transId
            : (jsonDecode(pages.single['page_json'] as String)
                          as Map)['caption']
                      ?.toString() ??
                  transId;
        final message = errorMessage(item);
        await add(
          username: user,
          projectName: project,
          eventKey: '$queueId:record:$id',
          type: 'record_error',
          queueId: queueId,
          recordId: id,
          recordVersion: rows.single['record_version'] as int? ?? 0,
          transId: transId,
          caption: caption,
          title: 'Record needs correction',
          message: message,
        );
      }
    } catch (e) {
      LogService.writeLog(
        message: '[OFFLINE_NOTIFICATION] Result notifications failed: $e',
      );
    }
  }

  static String errorMessage(Map<String, dynamic> item) {
    dynamic error = item['error_message'];
    if (error is String) {
      try {
        error = jsonDecode(error);
      } catch (_) {
        return error;
      }
    }
    if (error is Map) {
      final result = error['result'];
      return (result is Map ? result['message'] : error['message'])
              ?.toString() ??
          'Record could not be submitted.';
    }
    return 'Record could not be submitted.';
  }
}

/// Capture user/project once, so a late callback belongs to the initiating operation.
class OfflineUpdateNotificationRun {
  final String username, projectName, id;
  OfflineUpdateNotificationRun(this.username, this.projectName, this.id);

  Future<void> exportResult({
    required bool success,
    String? filePath,
    bool shared = false,
    bool confirmed = true,
    String? error,
  }) async {
    if (error != null)
      LogService.writeLog(
        message: '[OFFLINE_NOTIFICATION] Export failure: $error',
      );
    final name = filePath == null ? 'Your offline backup' : basename(filePath);
    final unavailable =
        error?.contains('DB-only upload is not available') == true;
    await notify(
      event: 'export',
      caption: 'Export Offline Backup',
      type: !success
          ? 'export_error'
          : !confirmed
          ? 'export_warning'
          : 'export_success',
      title: !success
          ? 'Offline backup could not be exported'
          : !confirmed
          ? 'Backup sharing could not be confirmed'
          : shared
          ? 'Offline backup sent to share app'
          : 'Offline backup exported',
      message: !success
          ? unavailable
                ? 'DB-only upload is not available. Choose Full Backup, then Download or Share.'
                : 'Your offline backup could not be exported. Please try again.'
          : !confirmed
          ? '$name was prepared, but the device could not confirm the share action.'
          : shared
          ? '$name was handed to the selected app. Delivery is handled by that app.'
          : '$name was saved to Downloads.',
    );
  }

  Future<void> notify({
    required String event,
    required String type,
    required String title,
    required String message,
    String caption = '',
    String transId = '',
    int successCount = 0,
    int failedCount = 0,
    OfflineRefreshReport? refreshReport,
  }) => OfflineNotifications.add(
    username: username,
    projectName: projectName,
    eventKey: '$id:$event',
    type: type,
    queueId: '',
    title: title,
    message: refreshReport == null
        ? message
        : jsonEncode({
            'refresh_report_version': 1,
            'message': message,
            'report': refreshReport.toMap(),
          }),
    caption: caption,
    transId: transId,
    successCount: successCount,
    failedCount: failedCount,
  );
}
