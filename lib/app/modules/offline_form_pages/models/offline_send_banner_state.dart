import 'cached_save_item_model.dart';

/// Presentation only: these counts never select records or change queue state.
enum OfflineSendBannerPhase {
  checkingSession,
  checkingQueues,
  uploading,
  processing,
  done,
  issues,
}

class OfflineSendBannerState {
  const OfflineSendBannerState({
    required this.phase,
    required this.title,
    required this.description,
    this.progress,
  });

  final OfflineSendBannerPhase phase;
  final String title;
  final String description;
  final double? progress;
  bool get isBusy =>
      phase == OfflineSendBannerPhase.checkingSession ||
      phase == OfflineSendBannerPhase.checkingQueues ||
      phase == OfflineSendBannerPhase.uploading;
  bool get hasIssues => phase == OfflineSendBannerPhase.issues;
  bool get isProcessing => phase == OfflineSendBannerPhase.processing;
  bool get animatesProgress => isBusy || isProcessing;
  bool get showsProgress => isBusy || progress != null;
  Duration get displayDuration =>
      hasIssues ? const Duration(minutes: 2) : const Duration(seconds: 5);

  /// Queue IDs are allocated during preparation, before an upload is accepted.
  /// Count actual accepted statuses instead of the existing sentQueueIds set.
  static int acceptedBatches(Iterable<CachedSaveItemModel> items) => items
      .where(
        (item) =>
            item.fcmRecived ||
            const {
              QueueSubmissionStatus.pending,
              QueueSubmissionStatus.success,
              QueueSubmissionStatus.partial,
              QueueSubmissionStatus.refetch,
            }.contains(item.submissionStatus),
      )
      .length;

  factory OfflineSendBannerState.uploading({
    required String message,
    required int totalBatches,
    required Iterable<CachedSaveItemModel> items,
  }) {
    final accepted = acceptedBatches(items);
    final batch = RegExp(
      r'(Building Payload|Uploading batch) (\d+)/(\d+)',
    ).firstMatch(message);
    final preparing = batch?.group(1) == 'Building Payload';
    final audit = message.toLowerCase().contains('audit');
    return OfflineSendBannerState(
      phase: OfflineSendBannerPhase.uploading,
      title: audit
          ? 'Sending audit logs'
          : preparing
          ? 'Preparing offline records'
          : 'Sending offline records',
      description: batch != null
          ? 'Batch ${batch.group(2)} of ${batch.group(3)} · You can keep working'
          : audit
          ? 'Finishing this sync · You can keep working'
          : 'Preparing records · You can keep working',
      // A continuous bar supports any configured batch count. Unknown totals
      // remain indeterminate; never invent a percentage for preparation.
      progress: totalBatches > 0
          ? (accepted / totalBatches).clamp(0.0, 1.0)
          : null,
    );
  }
}
