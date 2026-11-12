import 'package:flutter/material.dart';

import '../models/offline_send_banner_state.dart';

/// Shows the dashboard's existing sync state and delegates user actions.
class OfflineSendStatusBanner extends StatefulWidget {
  const OfflineSendStatusBanner({
    super.key,
    required this.state,
    required this.onNotifications,
    this.onSend,
  });

  final OfflineSendBannerState state;
  final VoidCallback onNotifications;
  final VoidCallback? onSend;

  @override
  State<OfflineSendStatusBanner> createState() =>
      _OfflineSendStatusBannerState();
}

class _OfflineSendStatusBannerState extends State<OfflineSendStatusBanner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _motion = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1800),
  );

  void _updateAnimation() {
    if (widget.state.animatesProgress &&
        !MediaQuery.disableAnimationsOf(context)) {
      if (!_motion.isAnimating) _motion.repeat();
    } else {
      _motion.stop();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _updateAnimation();
  }

  @override
  void didUpdateWidget(covariant OfflineSendStatusBanner oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.state.animatesProgress != widget.state.animatesProgress) {
      _updateAnimation();
    }
  }

  @override
  void dispose() {
    _motion.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final (icon, accent, tint) = switch (state.phase) {
      OfflineSendBannerPhase.confirmed => (
        Icons.check_rounded,
        dark ? const Color(0xFF9BE7BD) : const Color(0xFF226047),
        dark ? const Color(0xFF20382F) : const Color(0xFFE4F3E9),
      ),
      OfflineSendBannerPhase.pending || OfflineSendBannerPhase.issues => (
        state.hasIssues
            ? Icons.error_outline_rounded
            : Icons.cloud_upload_outlined,
        dark ? const Color(0xFFFFBE7A) : const Color(0xFF8D490D),
        dark ? const Color(0xFF3A2A21) : const Color(0xFFFFF1DF),
      ),
      _ => (
        state.animatesProgress
            ? Icons.sync_rounded
            : state.phase == OfflineSendBannerPhase.idle
            ? Icons.inbox_outlined
            : Icons.schedule_rounded,
        dark ? const Color(0xFFB8C9FF) : const Color(0xFF3045A7),
        dark ? const Color(0xFF283559) : const Color(0xFFEDF1FF),
      ),
    };
    final canOpenNotifications = switch (state.phase) {
      OfflineSendBannerPhase.waiting ||
      OfflineSendBannerPhase.processing ||
      OfflineSendBannerPhase.issues ||
      OfflineSendBannerPhase.done => true,
      _ => false,
    };
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(20),
      side: BorderSide(
        color: dark ? const Color(0xFF343A50) : const Color(0xFFDCE3F1),
      ),
    );
    final action = state.phase == OfflineSendBannerPhase.pending
        ? FilledButton(
            onPressed: widget.onSend,
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF294CAC),
              foregroundColor: Colors.white,
              minimumSize: const Size(48, 48),
              padding: const EdgeInsets.symmetric(horizontal: 12),
            ),
            child: const Text('Send records'),
          )
        : canOpenNotifications
        ? OutlinedButton(
            onPressed: widget.onNotifications,
            style: OutlinedButton.styleFrom(
              foregroundColor: accent,
              side: BorderSide(color: accent),
              minimumSize: const Size(60, 48),
              padding: const EdgeInsets.symmetric(horizontal: 7),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: const Tooltip(
              message: 'Open notifications',
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.notifications_none_rounded, size: 20),
                  SizedBox(width: 2),
                  Icon(Icons.chevron_right_rounded, size: 16),
                ],
              ),
            ),
          )
        : state.phase == OfflineSendBannerPhase.confirmed
        ? DecoratedBox(
            decoration: BoxDecoration(
              color: tint,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              child: Text(
                'Up to date',
                style: theme.textTheme.labelMedium?.copyWith(color: accent),
              ),
            ),
          )
        : null;
    final statusIcon = Icon(icon, size: 21, color: accent);
    final stackAction = MediaQuery.textScalerOf(context).scale(14) > 18;
    return Material(
      color: theme.colorScheme.surface,
      elevation: 4,
      shadowColor: const Color(0x2614254B),
      shape: shape,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: canOpenNotifications ? widget.onNotifications : null,
        excludeFromSemantics: true,
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: 12,
            vertical: state.isBusy ? 9 : 12,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: tint,
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: state.animatesProgress
                        ? RotationTransition(turns: _motion, child: statusIcon)
                        : statusIcon,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Semantics(
                      liveRegion: true,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            state.title,
                            maxLines: state.isBusy && !stackAction ? 2 : null,
                            overflow: state.isBusy && !stackAction
                                ? TextOverflow.ellipsis
                                : null,
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                              fontSize: state.isBusy ? 13 : null,
                              height: 1.25,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            state.description,
                            maxLines: state.isBusy && !stackAction ? 2 : null,
                            overflow: state.isBusy && !stackAction
                                ? TextOverflow.ellipsis
                                : null,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                              fontSize: state.isBusy ? 11 : null,
                              height: 1.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (action != null && !stackAction) ...[
                    const SizedBox(width: 8),
                    action,
                  ],
                ],
              ),
              if (action != null && stackAction) ...[
                const SizedBox(height: 8),
                action,
              ],
              if (state.showsProgress) ...[
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: LinearProgressIndicator(
                    value: state.progress,
                    minHeight: 4,
                    color: accent,
                    backgroundColor: tint,
                    semanticsLabel: 'Batch progress',
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
