import 'dart:async';
import '../../../core/common.dart';
import '../../../data/services/log/log_service.dart';
import '../controller/offline_form_controller.dart';
import '../db/offline_db_module.dart';
import '../models/offline_notification_model.dart';
import '../widgets/offline_notification_card.dart';
import '../widgets/offline_refresh_notification.dart';

class OfflineNotificationsPage extends StatefulWidget {
  final OfflineFormController formController;
  const OfflineNotificationsPage({super.key, required this.formController});
  @override
  State<OfflineNotificationsPage> createState() =>
      _OfflineNotificationsPageState();
}

class _OfflineNotificationsPageState extends State<OfflineNotificationsPage> {
  List<OfflineNotificationModel> _messages = [];
  final Set<int> _deletingIds = {};
  Timer? _timer;
  bool _loading = true, _busy = false;
  int _loadEpoch = 0;
  String? _error;
  @override
  void initState() {
    super.initState();
    _load();
    _timer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (ModalRoute.of(context)?.isCurrent == true) _load();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    if (_busy) return;
    _busy = true;
    final epoch = _loadEpoch;
    try {
      final store = await OfflineNotifications.store();
      final rows = (await store?.list() ?? <OfflineNotificationModel>[])
          .where((item) => !_deletingIds.contains(item.id))
          .toList();
      if (!mounted || epoch != _loadEpoch) return;
      // A record form on top of the panel must not clear unread new arrivals.
      if (ModalRoute.of(context)?.isCurrent != false) {
        await store?.markRead(rows.map((e) => e.id));
      }
      if (!mounted || epoch != _loadEpoch) return;
      if (rows.any((item) => !item.isRead)) {
        LogService.writeLog(
          message:
              '[OFFLINE_NOTIFICATION] Viewed ${rows.length} messages; cleared displayed unread flags.',
        );
      }
      setState(() {
        _messages = rows;
        _loading = false;
        _error = null;
      });
      await widget.formController.refreshNotificationCount();
    } catch (e) {
      LogService.writeLog(
        message: '[OFFLINE_NOTIFICATION] Panel load failed: $e',
      );
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'Could not load notifications. Pull down to try again.';
        });
      }
    } finally {
      _busy = false;
    }
  }

  Future<void> _delete(OfflineNotificationModel item) async {
    // Dismissible requires immediate removal from the widget tree. Exclude
    // in-flight deletes from polling snapshots until the DB write completes.
    _deletingIds.add(item.id);
    setState(() => _messages.removeWhere((e) => e.id == item.id));
    try {
      final store = await OfflineNotifications.store();
      if (store?.username != item.username ||
          store?.projectName != item.projectName) {
        return;
      }
      await store!.delete(item.id);
      LogService.writeLog(
        message: '[OFFLINE_NOTIFICATION] Swipe deleted notification=${item.id}',
      );
      if (!mounted) return;
      setState(() => _messages.removeWhere((e) => e.id == item.id));
      await widget.formController.refreshNotificationCount();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Notification deleted'),
          // Action snackbars persist by default in this Flutter version.
          persist: false,
          duration: const Duration(seconds: 4),
          action: SnackBarAction(
            label: 'Undo',
            onPressed: () async {
              try {
                await store.restore(item.id);
                LogService.writeLog(
                  message:
                      '[OFFLINE_NOTIFICATION] Undo notification=${item.id}',
                );
                if (mounted) await _load();
              } catch (e) {
                LogService.writeLog(
                  message: '[OFFLINE_NOTIFICATION] Undo failed: $e',
                );
              }
            },
          ),
        ),
      );
    } catch (e) {
      LogService.writeLog(message: '[OFFLINE_NOTIFICATION] Delete failed: $e');
      _deletingIds.remove(item.id);
      await _load();
    } finally {
      _deletingIds.remove(item.id);
    }
  }

  Future<void> _clear() async {
    final store = await OfflineNotifications.store();
    if (!mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Clear all notifications?'),
        content: const Text(
          'This removes messages for this user and project. Offline records and submissions are kept.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Clear All'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      _loadEpoch++;
      await store?.clear();
      if (!mounted) return;
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      setState(() => _messages.clear());
      LogService.writeLog(
        message:
            '[OFFLINE_NOTIFICATION] Cleared all messages for current panel scope',
      );
      await _load();
      await widget.formController.refreshNotificationCount();
    } catch (e) {
      LogService.writeLog(message: '[OFFLINE_NOTIFICATION] Clear failed: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.brightness == Brightness.dark
          ? theme.colorScheme.surface
          : const Color(0xFFF7F6FB),
      appBar: AppBar(
        backgroundColor: theme.colorScheme.surface,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(
          'Notifications',
          style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w600),
        ),
        actions: [
          TextButton(
            onPressed: _messages.isEmpty ? null : _clear,
            child: Text(
              'Clear All',
              style: GoogleFonts.poppins(
                color: _messages.isEmpty
                    ? theme.disabledColor
                    : AppColors.primaryPurple,
              ),
            ),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(18),
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(_error!),
                    ),
                  if (_messages.isEmpty && _error == null)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 100),
                      child: Column(
                        children: [
                          Icon(
                            Icons.notifications_none_rounded,
                            size: 48,
                            color: AppColors.primaryPurple,
                          ),
                          const SizedBox(height: 18),
                          Text(
                            'You’re up to date',
                            style: GoogleFonts.poppins(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Offline updates will appear here.',
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  for (final item in _messages)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Dismissible(
                        key: ValueKey(item.id),
                        direction: DismissDirection.horizontal,
                        background: Container(
                          alignment: Alignment.centerLeft,
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.errorContainer,
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: Icon(
                            Icons.delete_outline,
                            color: theme.colorScheme.onErrorContainer,
                          ),
                        ),
                        secondaryBackground: Container(
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.errorContainer,
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: Icon(
                            Icons.delete_outline,
                            color: theme.colorScheme.onErrorContainer,
                          ),
                        ),
                        onDismissed: (_) => _delete(item),
                        child: OfflineNotificationCard(
                          notification: item,
                          onTap: item.recordId == null
                              ? item.isUpdate
                                    ? () => _showUpdateDetails(item)
                                    : null
                              : () async {
                                  await widget.formController
                                      .openNotificationRecord(item);
                                  if (mounted) await _load();
                                },
                        ),
                      ),
                    ),
                ],
              ),
            ),
    );
  }

  Future<void> _showUpdateDetails(OfflineNotificationModel item) async {
    LogService.writeLog(
      message:
          '[OFFLINE_NOTIFICATION] Viewed update notification=${item.id} type=${item.type}',
    );
    await showDialog<void>(
      context: context,
      builder: (context) => item.refreshReport != null
          ? OfflineRefreshDetailsDialog(notification: item)
          : AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: Text(
                item.title,
                style: GoogleFonts.poppins(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                ),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.caption,
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      item.message,
                      style: GoogleFonts.poppins(fontSize: 13, height: 1.6),
                    ),
                    if (item.isRefreshSummary) ...[
                      const SizedBox(height: 16),
                      Text(
                        'Lookup data: ${item.successCount} updated, ${item.failedCount} failed',
                        style: GoogleFonts.poppins(fontSize: 12),
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Close'),
                ),
              ],
            ),
    );
    if (mounted) await _load();
  }
}
