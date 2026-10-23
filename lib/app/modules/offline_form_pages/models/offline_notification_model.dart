import 'dart:convert';
import 'offline_refresh_report.dart';

class OfflineNotificationModel {
  final int id;
  final String eventKey;
  final String username;
  final String projectName;
  final String type;
  final String queueId;
  final int? recordId;
  final int recordVersion;
  final String transId;
  final String caption;
  final String title;
  final String message;
  final DateTime createdAt;
  final bool isRead;
  final int successCount;
  final int failedCount;
  final OfflineRefreshReport? refreshReport;
  bool get isUpdate =>
      type.startsWith('refresh_') ||
      type.startsWith('export_') ||
      type == 'lookup_error';
  bool get isRefreshSummary =>
      type == 'refresh_success' || type == 'refresh_warning';

  const OfflineNotificationModel({
    required this.id,
    required this.eventKey,
    required this.username,
    required this.projectName,
    required this.type,
    required this.queueId,
    this.recordId,
    this.recordVersion = 0,
    this.transId = '',
    this.caption = '',
    required this.title,
    required this.message,
    required this.createdAt,
    this.isRead = false,
    this.successCount = 0,
    this.failedCount = 0,
    this.refreshReport,
  });

  factory OfflineNotificationModel.fromMap(Map<String, dynamic> row) {
    var message = row['message'] as String;
    OfflineRefreshReport? report;
    // Versioned envelope in the existing message column avoids altering the DB
    // schema. Legacy notifications, exports and submission errors stay plain text.
    if ((row['type'] as String).startsWith('refresh_')) {
      try {
        final data = jsonDecode(message);
        if (data is Map && data['refresh_report_version'] == 1) {
          message = data['message'] as String;
          report = OfflineRefreshReport.fromMap(
            Map<String, dynamic>.from(data['report'] as Map),
          );
        }
      } catch (_) {
        /* Retain readable text if an optional report is malformed. */
      }
    }
    return OfflineNotificationModel(
      id: row['id'] as int,
      eventKey: row['event_key'] as String,
      username: row['username'] as String,
      projectName: row['project_name'] as String,
      type: row['type'] as String,
      queueId: row['queue_id'] as String,
      recordId: row['record_id'] as int?,
      recordVersion: row['record_version'] as int? ?? 0,
      transId: row['trans_id'] as String? ?? '',
      caption: row['caption'] as String? ?? '',
      title: row['title'] as String,
      message: message,
      refreshReport: report,
      createdAt: DateTime.parse(row['created_at'] as String),
      isRead: row['is_read'] == 1,
      successCount: row['success_count'] as int? ?? 0,
      failedCount: row['failed_count'] as int? ?? 0,
    );
  }
}
