import 'package:intl/intl.dart';
import '../../../core/common.dart';
import '../models/offline_notification_model.dart';
import '../models/offline_refresh_report.dart';
import '../models/offline_update_messages.dart';

const _refreshPurple = Color(0xFF6250AC);

/// Only notifications carrying the new report use this UI. Legacy messages and
/// record correction continue through their existing widgets/navigation.
class OfflineRefreshNotificationCard extends StatelessWidget {
  final OfflineNotificationModel notification;
  final VoidCallback? onTap;
  const OfflineRefreshNotificationCard({
    super.key,
    required this.notification,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final success = notification.type == 'refresh_success';
    final status = success ? Colors.teal : Colors.orange.shade800;
    return Material(
      color: theme.colorScheme.surface,
      borderRadius: BorderRadius.circular(23),
      child: InkWell(
        borderRadius: BorderRadius.circular(23),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _ResultIcon(
                    success
                        ? Icons.check_circle_outline_rounded
                        : Icons.error_outline_rounded,
                    status,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          notification.title,
                          style: _text(14, weight: FontWeight.w600),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          notification.caption,
                          style: _text(11, color: _refreshPurple),
                        ),
                      ],
                    ),
                  ),
                  if (onTap != null)
                    const Icon(
                      Icons.chevron_right_rounded,
                      color: _refreshPurple,
                      size: 20,
                    ),
                ],
              ),
              const SizedBox(height: 20),
              if (notification.refreshReport!.forms.isEmpty)
                Text(
                  notification.message,
                  style: _text(12, color: theme.colorScheme.onSurfaceVariant),
                )
              else
                _CardRefreshBreakdown(report: notification.refreshReport!),
              const SizedBox(height: 18),
              Divider(
                height: 1,
                color: theme.dividerColor.withValues(alpha: .15),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      DateFormat(
                        'dd MMM, h:mm a',
                      ).format(notification.createdAt),
                      style: _text(
                        11,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  if (onTap != null)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'View details',
                          style: _text(
                            11,
                            color: _refreshPurple,
                            weight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(
                          Icons.north_east_rounded,
                          size: 13,
                          color: _refreshPurple,
                        ),
                      ],
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Card-only presentation. Keep the detailed result/error widgets unchanged.
class _CardRefreshBreakdown extends StatelessWidget {
  final OfflineRefreshReport report;
  const _CardRefreshBreakdown({required this.report});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final teal = theme.brightness == Brightness.dark
        ? Colors.teal.shade200
        : const Color(0xFF35766F);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(13),
          decoration: BoxDecoration(
            color: _refreshPurple.withValues(
              alpha: theme.brightness == Brightness.dark ? .15 : .07,
            ),
            borderRadius: BorderRadius.circular(13),
          ),
          child: Wrap(
            spacing: 14,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            alignment: WrapAlignment.spaceBetween,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.file_copy_outlined,
                    size: 16,
                    color: _refreshPurple,
                  ),
                  const SizedBox(width: 7),
                  Text(
                    'Offline forms',
                    style: _text(12, weight: FontWeight.w500),
                  ),
                ],
              ),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  if (report.failedForms == 0 && report.updatedForms > 0)
                    Icon(
                      Icons.check_circle_outline_rounded,
                      size: 13,
                      color: teal,
                    ),
                  Text(
                    '${report.updatedForms}/${report.forms.length} updated',
                    style: _text(
                      12,
                      color: report.failedForms == 0 ? teal : colors.onSurface,
                      weight: FontWeight.w500,
                    ),
                  ),
                  if (report.failedForms > 0)
                    Text(
                      '· ${report.failedForms} failed',
                      style: _text(11, color: colors.error),
                    ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 22),
        Row(
          children: [
            Icon(Icons.list_alt_rounded, size: 16, color: teal),
            const SizedBox(width: 7),
            Text(
              'Lookup data',
              style: _text(12, color: teal, weight: FontWeight.w500),
            ),
          ],
        ),
        const SizedBox(height: 4),
        for (final form in report.forms)
          Padding(
            padding: const EdgeInsets.only(top: 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      flex: 6,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 4,
                            height: 4,
                            margin: const EdgeInsets.only(top: 7, right: 7),
                            decoration: BoxDecoration(
                              color: teal,
                              shape: BoxShape.circle,
                            ),
                          ),
                          Expanded(
                            child: Text(
                              form.caption,
                              style: _text(12, weight: FontWeight.w500),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    Flexible(
                      flex: 5,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            !form.lookupsCompleted
                                ? 'Not refreshed'
                                : form.totalLookups == 0
                                ? 'No lookup data'
                                : '${form.updatedLookups}/${form.totalLookups} updated',
                            textAlign: TextAlign.right,
                            style: _text(
                              12,
                              color: colors.onSurfaceVariant,
                              weight: FontWeight.w500,
                            ),
                          ),
                          if (form.lookupsCompleted &&
                              form.totalLookups > 0) ...[
                            const SizedBox(height: 6),
                            if (form.failedLookups > 0)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 7,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: colors.error.withValues(alpha: .07),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  '${form.failedLookups} failed',
                                  style: _text(11, color: colors.error),
                                ),
                              )
                            else
                              Text(
                                'All updated',
                                style: _text(11, color: teal),
                              ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
                if (!form.lookupsCompleted)
                  Padding(
                    padding: const EdgeInsets.only(top: 5),
                    child: Text(
                      form.formError != null
                          ? 'Lookup update skipped: form download failed.'
                          : 'Lookup update was not completed.',
                      style: _text(11, color: colors.onSurfaceVariant),
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

class OfflineRefreshDetailsDialog extends StatelessWidget {
  final OfflineNotificationModel notification;
  const OfflineRefreshDetailsDialog({super.key, required this.notification});
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final success = notification.type == 'refresh_success';
    final color = success ? Colors.teal : Colors.orange.shade800;
    return Dialog(
      backgroundColor: theme.colorScheme.surface,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 430,
          maxHeight: MediaQuery.sizeOf(context).height * .88,
        ),
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Flexible(
                    child: Container(
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: .08),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 8,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            success
                                ? Icons.check_circle_outline_rounded
                                : Icons.error_outline_rounded,
                            color: color,
                            size: 16,
                          ),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              success ? 'Completed' : 'Needs attention',
                              style: _text(
                                11,
                                color: color,
                                weight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    tooltip: 'Close details',
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded),
                    iconSize: 20,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  notification.title,
                  style: _text(20, weight: FontWeight.w600),
                ),
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 12,
                runSpacing: 6,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.refresh_rounded,
                        size: 15,
                        color: _refreshPurple,
                      ),
                      const SizedBox(width: 5),
                      Flexible(
                        child: Text(
                          notification.caption,
                          style: _text(
                            12,
                            color: _refreshPurple,
                            weight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                  Text(
                    DateFormat(
                      'dd MMM · h:mm a',
                    ).format(notification.createdAt),
                    style: _text(11, color: theme.colorScheme.onSurfaceVariant),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _RefreshBreakdown(
                        report: notification.refreshReport!,
                        compact: false,
                      ),
                      // Non-lookup issues (e.g. pending upload failure) still need a clear
                      // explanation, without repeating the form/lookup totals above.
                      if (notification.refreshReport!.forms.isEmpty ||
                          (notification.type == 'refresh_error' &&
                              notification.refreshReport!.failedForms == 0) ||
                          notification.message.contains(
                            'pending records could not',
                          )) ...[
                        const SizedBox(height: 14),
                        Text(
                          notification.message,
                          style: _text(
                            12,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                      if (!success)
                        Padding(
                          padding: const EdgeInsets.only(top: 16),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                Icons.info_outline_rounded,
                                size: 16,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'After resolving an issue, refresh the affected form again.',
                                  style: _text(
                                    11,
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: _refreshPurple,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: () => Navigator.pop(context),
                  child: Text(
                    'Close',
                    style: _text(
                      13,
                      color: Colors.white,
                      weight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RefreshBreakdown extends StatelessWidget {
  final OfflineRefreshReport report;
  final bool compact;
  const _RefreshBreakdown({required this.report, required this.compact});
  @override
  Widget build(BuildContext context) {
    if (report.forms.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final tint = _refreshPurple.withValues(
      alpha: theme.brightness == Brightness.dark ? .15 : .05,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: tint,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Category(Icons.file_copy_outlined, 'Offline forms'),
              if (!compact)
                Padding(
                  padding: const EdgeInsets.only(top: 5),
                  child: Text(
                    'Forms you open and fill in offline.',
                    style: _text(11, color: muted),
                  ),
                ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    '${report.updatedForms}/${report.forms.length}',
                    style: _text(compact ? 17 : 22, weight: FontWeight.w600),
                  ),
                  Text('updated', style: _text(12, color: muted)),
                  if (report.failedForms > 0)
                    Text(
                      '· ${report.failedForms} failed',
                      style: _text(12, color: theme.colorScheme.error),
                    ),
                ],
              ),
              if (!compact)
                for (final form in report.forms.where(
                  (form) => form.formError != null,
                ))
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: _InlineError(
                      title: '${form.caption} · Download failed',
                      message: form.formError!,
                    ),
                  ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        _Category(
          Icons.list_alt_rounded,
          compact ? 'Lookup data' : 'Lookup data by form',
        ),
        if (!compact)
          Padding(
            padding: const EdgeInsets.only(top: 5),
            child: Text(
              'Dropdown options and reference data.',
              style: _text(11, color: muted),
            ),
          ),
        const SizedBox(height: 10),
        Container(
          width: double.infinity,
          padding: compact
              ? EdgeInsets.zero
              : const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: compact ? Colors.transparent : tint,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            children: [
              for (var i = 0; i < report.forms.length; i++) ...[
                if (!compact && i > 0)
                  Divider(
                    height: 1,
                    thickness: .7,
                    color: theme.dividerColor.withValues(alpha: .2),
                  ),
                _FormLookupResult(form: report.forms[i], compact: compact),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _FormLookupResult extends StatelessWidget {
  final OfflineRefreshFormResult form;
  final bool compact;
  const _FormLookupResult({required this.form, required this.compact});
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  form.caption,
                  style: _text(12, weight: FontWeight.w600),
                ),
              ),
              const SizedBox(width: 10),
              Flexible(
                child: Text(
                  !form.lookupsCompleted
                      ? 'Not refreshed'
                      : form.totalLookups == 0
                      ? 'No lookup data'
                      : '${form.updatedLookups}/${form.totalLookups} updated',
                  textAlign: TextAlign.right,
                  style: _text(
                    12,
                    color: form.lookupsCompleted ? _refreshPurple : muted,
                    weight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          if (!form.lookupsCompleted)
            Padding(
              padding: const EdgeInsets.only(top: 5),
              child: Text(
                form.formError != null
                    ? 'Lookup update skipped: form download failed.'
                    : 'Lookup update was not completed.',
                style: _text(11, color: muted),
              ),
            ),
          if (form.lookupsCompleted && form.totalLookups > 0)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Wrap(
                spacing: 12,
                runSpacing: 5,
                children: [
                  Text(
                    '${form.updatedLookups} updated',
                    style: _text(11, color: Colors.teal),
                  ),
                  Text(
                    form.failedLookups > 0
                        ? '${form.failedLookups} failed'
                        : 'All lookup data updated',
                    style: _text(
                      11,
                      color: form.failedLookups > 0
                          ? theme.colorScheme.error
                          : Colors.teal,
                    ),
                  ),
                ],
              ),
            ),
          if (!compact && form.lookupErrors.isNotEmpty)
            Theme(
              data: theme.copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                key: PageStorageKey('lookup-errors-${form.transId}'),
                initiallyExpanded: form.lookupErrors.length == 1,
                tilePadding: EdgeInsets.zero,
                childrenPadding: EdgeInsets.zero,
                dense: true,
                visualDensity: VisualDensity.compact,
                title: Text(
                  form.lookupErrors.length == 1
                      ? 'Lookup error'
                      : 'View ${form.lookupErrors.length} lookup errors',
                  style: _text(
                    11,
                    color: _refreshPurple,
                    weight: FontWeight.w500,
                  ),
                ),
                children: [
                  for (final error in form.lookupErrors)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 13),
                      child: _InlineError(
                        title: '${error.caption} · Failed',
                        message: error.message,
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _InlineError extends StatelessWidget {
  final String title, message;
  const _InlineError({required this.title, required this.message});
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.error_outline_rounded, size: 18, color: colors.error),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: _text(11, color: colors.error, weight: FontWeight.w500),
              ),
              const SizedBox(height: 4),
              Text(
                lookupErrorDisplayText(message),
                style: _text(11, color: colors.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Category extends StatelessWidget {
  final IconData icon;
  final String title;
  const _Category(this.icon, this.title);
  @override
  Widget build(BuildContext context) => Row(
    children: [
      Icon(icon, size: 17, color: _refreshPurple),
      const SizedBox(width: 7),
      Expanded(
        child: Text(title, style: _text(13, weight: FontWeight.w600)),
      ),
    ],
  );
}

class _ResultIcon extends StatelessWidget {
  final IconData icon;
  final Color color;
  const _ResultIcon(this.icon, this.color);
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(11),
    decoration: BoxDecoration(
      color: color.withValues(alpha: .09),
      borderRadius: BorderRadius.circular(14),
    ),
    child: Icon(icon, color: color, size: 23),
  );
}

TextStyle _text(
  double size, {
  Color? color,
  FontWeight weight = FontWeight.w400,
}) => GoogleFonts.poppins(
  fontSize: size,
  fontWeight: weight,
  color: color,
  height: 1.5,
);
