import 'offline_send_banner_state.dart';

/// A read-only snapshot of already stored notifications. It contains no form
/// payloads and never changes queue status, read flags, or retry eligibility.
class OfflineBatchBannerSnapshot {
  const OfflineBatchBannerSnapshot({
    required this.scope,
    required this.lastId,
    this.baseline = false,
    this.events = const [],
  });
  final String scope;
  final int lastId;
  final bool baseline;
  final List<Map<String, dynamic>> events;
}

/// UI-only correlation. Queues created in a known manual send are aggregated;
/// uncorrelated/background queues show their own result rather than assuming
/// unrelated queues belong to the same send. The durable notifications remain
/// the source of truth across isolates and controller/app recreation.
class OfflineBatchBannerUpdates {
  String? scope;
  int lastId = 0;
  String? _latestQueue;
  final _events = <String, Map<String, dynamic>>{};
  final _groups = <String, Set<String>>{};
  final _groupForQueue = <String, String>{};
  final _unsent = <String, int>{};

  void trackSubmission(
    String run,
    Iterable<String> queues, {
    int unsentBatches = 0,
  }) {
    final ids = queues.toSet();
    if (ids.isEmpty) return;
    _groups[run] = ids;
    _unsent[run] = unsentBatches;
    for (final id in ids) {
      _groupForQueue[id] = run;
    }
  }

  bool consume(OfflineBatchBannerSnapshot snapshot) {
    if (snapshot.baseline || scope != snapshot.scope) {
      scope = snapshot.scope;
      lastId = snapshot.lastId;
      _events.clear();
      _groups.clear();
      _groupForQueue.clear();
      _unsent.clear();
      _latestQueue = null;
      return false; // Do not replay historical messages on login/project change.
    }
    var changed = false;
    for (final event in snapshot.events) {
      if ((event['id'] as int) <= lastId) continue;
      final queue = event['queue_id'] as String;
      final previous = _events[queue];
      // A valid parsed result supersedes an earlier unconfirmed batch issue.
      // A later malformed response must not erase a confirmed record result.
      if (previous?['event_key'] == '$queue:result' &&
          event['event_key'] != '$queue:result')
        continue;
      _events[queue] = event;
      if (event['is_deleted'] != 1) {
        _latestQueue = queue;
        changed = true;
      }
    }
    lastId = snapshot.lastId;
    return changed;
  }

  OfflineSendBannerState? get latest {
    final queue = _latestQueue;
    if (queue == null) return null;
    final run = _groupForQueue[queue];
    final ids = run == null ? {queue} : _groups[run]!;
    var processed = 0, successful = 0, failed = 0, unknownIssues = 0;
    for (final id in ids) {
      final event = _events[id];
      if (event == null) continue;
      if (event['event_key'] == '$id:result') {
        processed++;
        successful += (event['success_count'] as num?)?.toInt() ?? 0;
        failed += (event['failed_count'] as num?)?.toInt() ?? 0;
      } else if (event['type'] == 'batch_error') {
        unknownIssues++;
      }
    }
    final unsent = _unsent[run] ?? 0;
    final issues = failed > 0 || unknownIssues > 0 || unsent > 0;
    final complete = processed == ids.length;
    final title = unknownIssues > 0 && processed == 0
        ? 'Submission needs attention'
        : !complete
        ? '$processed of ${ids.length} batches processed'
        : issues
        ? 'Completed with issues'
        : successful > 0
        ? '${run == null ? '' : 'All '}$successful records submitted'
        : 'Batch processing completed';
    final detail = unknownIssues > 0 && processed == 0
        ? 'Tap to view the batch error'
        : '$successful submitted${failed > 0 ? ' · $failed need attention' : ''}'
              '${unknownIssues > 0 ? ' · Batch needs attention' : ''}'
              '${unsent > 0 ? ' · $unsent ${unsent == 1 ? 'batch' : 'batches'} not sent' : ''}'
              '${!complete && !issues ? ' · ${ids.length - processed} ${ids.length - processed == 1 ? 'batch' : 'batches'} pending' : ''}';
    return OfflineSendBannerState(
      phase: issues
          ? OfflineSendBannerPhase.issues
          : complete
          ? OfflineSendBannerPhase.done
          : OfflineSendBannerPhase.processing,
      title: title,
      description: detail,
      progress: complete || unknownIssues > 0 ? null : processed / ids.length,
    );
  }
}
