import 'package:intl/intl.dart';
import '../../../core/common.dart';
import '../models/offline_notification_model.dart';
import 'offline_refresh_notification.dart';

class OfflineNotificationCard extends StatelessWidget {
  final OfflineNotificationModel notification;
  final VoidCallback? onTap;
  const OfflineNotificationCard({
    super.key,
    required this.notification,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    if (notification.refreshReport != null) {
      return OfflineRefreshNotificationCard(
        notification: notification,
        onTap: onTap,
      );
    }
    final theme = Theme.of(context);
    final error = notification.type.contains('error');
    final queued = notification.type == 'batch_queued';
    final warning = notification.type.endsWith('_warning');
    final color = error
        ? theme.colorScheme.error
        : warning
        ? Colors.orange.shade800
        : queued
        ? AppColors.primaryPurple
        : Colors.teal;
    return Material(
      color: theme.colorScheme.surface,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(11),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: .1),
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: Icon(
                      notification.type == 'lookup_error'
                          ? Icons.storage_rounded
                          : notification.type.startsWith('export_')
                          ? Icons.archive_outlined
                          : error || warning
                          ? Icons.error_outline_rounded
                          : queued
                          ? Icons.layers_outlined
                          : Icons.check_circle_outline_rounded,
                      color: color,
                      size: 23,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          notification.title,
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          notification.recordId == null
                              ? notification.isUpdate
                                    ? notification.caption
                                    : notification.queueId.isEmpty
                                    ? 'Offline submission'
                                    : 'Queue #${notification.queueId}'
                              : '${notification.caption}\nRecord #${notification.recordId}',
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (onTap != null)
                    Icon(Icons.chevron_right_rounded, color: color),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                notification.message,
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  height: 1.6,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              if (notification.recordId == null &&
                  (notification.isRefreshSummary ||
                      notification.type.startsWith('batch_')) &&
                  (notification.successCount + notification.failedCount >
                      0)) ...[
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    _status(
                      '${notification.successCount} ${notification.isRefreshSummary ? 'lookups updated' : 'successful'}',
                      Colors.teal,
                    ),
                    _status(
                      '${notification.failedCount} failed',
                      theme.colorScheme.error,
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 12),
              Text(
                DateFormat('dd MMM, h:mm a').format(notification.createdAt),
                style: GoogleFonts.poppins(
                  fontSize: 11,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _status(String text, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      color: color.withValues(alpha: .1),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Text(
      text,
      style: GoogleFonts.poppins(
        fontSize: 11,
        color: color,
        fontWeight: FontWeight.w500,
      ),
    ),
  );
}
