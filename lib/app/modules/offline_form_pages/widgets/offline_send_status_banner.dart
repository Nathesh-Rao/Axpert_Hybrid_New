import 'package:flutter/material.dart';

import '../models/offline_send_banner_state.dart';

/// A non-modal view of the existing manual sync. No upload work runs here.
class OfflineSendStatusBanner extends StatefulWidget {
  const OfflineSendStatusBanner({
    super.key,
    required this.state,
    required this.onNotifications,
  });
  final OfflineSendBannerState state;
  final VoidCallback onNotifications;

  @override
  State<OfflineSendStatusBanner> createState() =>
      _OfflineSendStatusBannerState();
}

class _OfflineSendStatusBannerState extends State<OfflineSendStatusBanner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _motion = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2400),
  );

  void _updateAnimation() {
    // Respect the platform's reduced-motion/accessibility preference.
    if (MediaQuery.disableAnimationsOf(context)) {
      _motion.stop();
      _motion.value = widget.state.animatesProgress ? 0 : 1;
    } else if (widget.state.animatesProgress) {
      if (!_motion.isAnimating) _motion.repeat();
    } else {
      _motion.stop();
      _motion.duration = const Duration(milliseconds: 450);
      _motion.forward(from: 0);
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
    if (oldWidget.state.animatesProgress != widget.state.animatesProgress ||
        oldWidget.state.phase != widget.state.phase) {
      _motion.duration = const Duration(milliseconds: 2400);
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
    final dark = Theme.of(context).brightness == Brightness.dark;
    final accent = state.hasIssues
        ? (dark ? const Color(0xFFFFBE7A) : const Color(0xFFAD631C))
        : state.animatesProgress
        ? (dark ? const Color(0xFFCAB3FF) : const Color(0xFF7046B9))
        : (dark ? const Color(0xFF8EDBB2) : const Color(0xFF237A59));
    final fill = state.hasIssues
        ? (dark ? const Color(0xFF35281E) : const Color(0xFFFFF0DF))
        : state.animatesProgress
        ? (dark ? const Color(0xFF2C253D) : const Color(0xFFEEE6FA))
        : (dark ? const Color(0xFF20332A) : const Color(0xFFE8F5ED));
    return Semantics(
      liveRegion: true,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
        child: Material(
          color: fill,
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            // Completion details live in the existing notification page.
            onTap: state.isBusy ? null : widget.onNotifications,
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: dark ? const Color(0xFF393342) : Colors.white,
                          borderRadius: BorderRadius.circular(11),
                        ),
                        alignment: Alignment.center,
                        child: AnimatedBuilder(
                          animation: _motion,
                          builder: (_, child) => state.animatesProgress
                              ? RotationTransition(turns: _motion, child: child)
                              : Transform.scale(
                                  scale:
                                      .75 +
                                      .25 *
                                          Curves.easeOutBack.transform(
                                            _motion.value,
                                          ),
                                  child: child,
                                ),
                          child: Icon(
                            state.animatesProgress
                                ? Icons.sync_rounded
                                : state.hasIssues
                                ? Icons.error_outline_rounded
                                : Icons.done_all_rounded,
                            size: 19,
                            color: accent,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              state.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: accent,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              state.description,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 11,
                                color: dark
                                    ? const Color(0xFFDACFE3)
                                    : const Color(0xFF6D5580),
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (!state.isBusy) ...[
                        const SizedBox(width: 6),
                        Icon(Icons.north_east_rounded, color: accent, size: 17),
                      ],
                    ],
                  ),
                  if (state.showsProgress) ...[
                    const SizedBox(height: 10),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(3),
                      child: LinearProgressIndicator(
                        value: state.progress,
                        minHeight: 3,
                        color: accent,
                        backgroundColor: accent.withValues(alpha: .15),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
