import 'package:axpert/app/modules/offline_form_pages/controller/offline_form_controller.dart';
import 'package:axpert/app/modules/offline_form_pages/auto_sync/offline_background_sync_service.dart';
import 'package:axpert/app/modules/offline_form_pages/models/cached_save_item_model.dart';
import 'package:axpert/app/modules/offline_form_pages/models/offline_send_banner_state.dart';
import 'package:axpert/app/modules/offline_form_pages/models/offline_batch_banner_updates.dart';
import 'package:axpert/app/modules/offline_form_pages/widgets/offline_send_status_banner.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

CachedSaveItemModel batch(
  QueueSubmissionStatus status, {
  bool received = false,
}) => CachedSaveItemModel(
  submissionStatus: status,
  qId: 'q',
  totalItems: 2,
  successItems: 0,
  failedItems: 0,
  fcmRecived: received,
  smallStatusMessage: '',
);

void main() {
  Map<String, dynamic> result(
    int id,
    String queue,
    int success,
    int failure, {
    bool issue = false,
    bool deleted = false,
  }) => {
    'id': id,
    'queue_id': queue,
    'event_key': issue ? '$queue:issue:test' : '$queue:result',
    'type': issue || failure > 0 ? 'batch_error' : 'batch_success',
    'success_count': success,
    'failed_count': failure,
    'is_deleted': deleted ? 1 : 0,
  };
  OfflineBatchBannerUpdates tracker() => OfflineBatchBannerUpdates()
    ..consume(
      const OfflineBatchBannerSnapshot(
        scope: 'scope',
        lastId: 0,
        baseline: true,
      ),
    );

  test(
    'backend results aggregate only the known send and retain partial errors',
    () {
      final updates = tracker()
        ..trackSubmission('run', ['q1', 'q2', 'q3', 'q4']);
      expect(
        updates.consume(
          OfflineBatchBannerSnapshot(
            scope: 'scope',
            lastId: 3,
            events: [
              result(1, 'q1', 30, 0),
              result(2, 'q2', 30, 0),
              result(3, 'q3', 26, 4),
            ],
          ),
        ),
        isTrue,
      );
      final partial = updates.latest!;
      expect(partial.title, '3 of 4 batches processed');
      expect(partial.description, '86 submitted · 4 need attention');
      expect(partial.progress, .75);
      expect(partial.isBusy, isFalse);
      expect(partial.displayDuration, const Duration(minutes: 2));
      expect(
        updates.consume(
          OfflineBatchBannerSnapshot(
            scope: 'scope',
            lastId: 4,
            events: [result(4, 'q4', 30, 0)],
          ),
        ),
        isTrue,
      );
      expect(updates.latest!.title, 'Completed with issues');
      expect(updates.latest!.description, '116 submitted · 4 need attention');
    },
  );

  test(
    'processing results do not disable sending and final success is confirmed',
    () {
      final updates = tracker()..trackSubmission('run', ['q1', 'q2']);
      updates.consume(
        OfflineBatchBannerSnapshot(
          scope: 'scope',
          lastId: 1,
          events: [result(1, 'q1', 30, 0)],
        ),
      );
      expect(updates.latest!.phase, OfflineSendBannerPhase.processing);
      expect(updates.latest!.isBusy, isFalse);
      expect(updates.latest!.animatesProgress, isTrue);
      updates.consume(
        OfflineBatchBannerSnapshot(
          scope: 'scope',
          lastId: 2,
          events: [result(2, 'q2', 30, 0)],
        ),
      );
      expect(updates.latest!.title, 'All 60 records submitted');
      expect(updates.latest!.displayDuration, const Duration(seconds: 5));
    },
  );

  test(
    'batch issues never invent record counts and confirmed results supersede them',
    () {
      final updates = tracker();
      updates.consume(
        OfflineBatchBannerSnapshot(
          scope: 'scope',
          lastId: 1,
          events: [result(1, 'q1', 0, 0, issue: true)],
        ),
      );
      expect(updates.latest!.title, 'Submission needs attention');
      expect(updates.latest!.description, 'Tap to view the batch error');
      updates.consume(
        OfflineBatchBannerSnapshot(
          scope: 'scope',
          lastId: 2,
          events: [result(2, 'q1', 7, 0)],
        ),
      );
      expect(updates.latest!.title, '7 records submitted');
      expect(
        updates.consume(
          OfflineBatchBannerSnapshot(
            scope: 'scope',
            lastId: 3,
            events: [result(3, 'q1', 0, 0, issue: true)],
          ),
        ),
        isFalse,
      );
      expect(updates.latest!.hasIssues, isFalse);
    },
  );

  test(
    'deduplication, deleted events, unrelated sends and scope changes stay isolated',
    () {
      final updates = tracker()..trackSubmission('run', ['q1', 'q2']);
      final first = OfflineBatchBannerSnapshot(
        scope: 'scope',
        lastId: 1,
        events: [result(1, 'q1', 4, 0)],
      );
      expect(updates.consume(first), isTrue);
      expect(updates.consume(first), isFalse);
      updates.consume(
        OfflineBatchBannerSnapshot(
          scope: 'scope',
          lastId: 2,
          events: [result(2, 'other', 9, 0)],
        ),
      );
      expect(updates.latest!.title, '9 records submitted');
      expect(
        updates.consume(
          OfflineBatchBannerSnapshot(
            scope: 'scope',
            lastId: 3,
            events: [result(3, 'deleted', 0, 2, deleted: true)],
          ),
        ),
        isFalse,
      );
      updates.consume(
        const OfflineBatchBannerSnapshot(
          scope: 'other-scope',
          lastId: 3,
          baseline: true,
        ),
      );
      expect(updates.latest, isNull);
    },
  );

  test(
    'backend progress scales beyond thirty batches without a fixed total',
    () {
      final updates = tracker()
        ..trackSubmission('large-run', List.generate(36, (i) => 'q$i'));
      updates.consume(
        OfflineBatchBannerSnapshot(
          scope: 'scope',
          lastId: 35,
          events: List.generate(35, (i) => result(i + 1, 'q$i', 30, 0)),
        ),
      );
      expect(updates.latest!.title, '35 of 36 batches processed');
      expect(updates.latest!.progress, closeTo(35 / 36, .00001));
      updates.consume(
        OfflineBatchBannerSnapshot(
          scope: 'scope',
          lastId: 36,
          events: [result(36, 'q35', 30, 0)],
        ),
      );
      expect(updates.latest!.title, 'All 1080 records submitted');
    },
  );

  test('unsent batches prevent misleading all-success results', () {
    final updates = tracker()..trackSubmission('run', ['q1'], unsentBatches: 1);
    updates.consume(
      OfflineBatchBannerSnapshot(
        scope: 'scope',
        lastId: 1,
        events: [result(1, 'q1', 8, 0)],
      ),
    );
    expect(updates.latest!.hasIssues, isTrue);
    expect(updates.latest!.description, contains('1 batch not sent'));
  });

  testWidgets(
    'new errors restart two-minute banner expiry; success keeps five seconds',
    (tester) async {
      final controller = OfflineFormController();
      const error = OfflineSendBannerState(
        phase: OfflineSendBannerPhase.issues,
        title: 'Completed with issues',
        description: '4 records need attention',
      );
      controller.showSendPendingBanner(error);
      await tester.pump(const Duration(seconds: 119));
      expect(controller.currentSendPendingBanner, same(error));
      const newer = OfflineSendBannerState(
        phase: OfflineSendBannerPhase.issues,
        title: 'Completed with issues',
        description: '5 records need attention',
      );
      controller.showSendPendingBanner(newer);
      await tester.pump(const Duration(seconds: 119));
      expect(controller.currentSendPendingBanner, same(newer));
      await tester.pump(const Duration(seconds: 1));
      expect(controller.currentSendPendingBanner, isNull);
      controller.showSendPendingBanner(
        const OfflineSendBannerState(
          phase: OfflineSendBannerPhase.done,
          title: 'All records submitted',
          description: 'View notifications',
        ),
      );
      await tester.pump(const Duration(seconds: 4));
      expect(controller.currentSendPendingBanner, isNotNull);
      await tester.pump(const Duration(seconds: 1));
      expect(controller.currentSendPendingBanner, isNull);
      controller.onClose();
    },
  );

  test('allocated queue IDs do not count as accepted batches', () {
    expect(
      OfflineSendBannerState.acceptedBatches([
        batch(QueueSubmissionStatus.created),
        batch(QueueSubmissionStatus.sending),
        batch(QueueSubmissionStatus.error),
        batch(QueueSubmissionStatus.pending),
        batch(QueueSubmissionStatus.error, received: true),
      ]),
      2,
    );
  });

  test('batch counts and progress support more than thirty batches', () {
    final state = OfflineSendBannerState.uploading(
      message: 'Uploading batch 120/136 to server...',
      totalBatches: 136,
      items: List.generate(119, (_) => batch(QueueSubmissionStatus.pending)),
    );
    expect(state.description, contains('Batch 120 of 136'));
    expect(state.progress, closeTo(119 / 136, .00001));
    expect(state.title, 'Sending offline records');
  });

  test('unknown totals are indeterminate and audit phase is identified', () {
    expect(
      OfflineSendBannerState.uploading(
        message: 'Preparing...',
        totalBatches: 0,
        items: [],
      ).progress,
      isNull,
    );
    expect(
      OfflineSendBannerState.uploading(
        message: 'Pushing audit logs...',
        totalBatches: 2,
        items: [],
      ).title,
      'Sending audit logs',
    );
  });

  test(
    'manual and background activity disable the action independently',
    () async {
      final controller = OfflineFormController();
      final background = OfflineBackgroundSyncService.instance;
      try {
        controller.isSendingPendingRecords.value = true;
        expect(controller.sendPendingRecordsDisabled, isTrue);
        await controller
            .actionPushPendingByCachedSave(); // Repeated tap cannot reach DB/network.
        controller.isSendingPendingRecords.value = false;
        background.isSyncing.value = true;
        expect(controller.sendPendingRecordsDisabled, isTrue);
        await controller.actionPushPendingByCachedSave();
        background.isSyncing.value = false;
        expect(controller.sendPendingRecordsDisabled, isFalse);
      } finally {
        background.isSyncing.value = false;
        controller.onClose();
      }
    },
  );

  testWidgets(
    'compact banner rotates only while busy and opens completion notifications',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 600));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      var opened = 0;
      final busy = OfflineSendBannerState.uploading(
        message: 'Uploading batch 12/36 to server...',
        totalBatches: 36,
        items: List.generate(11, (_) => batch(QueueSubmissionStatus.pending)),
      );
      Widget host(OfflineSendBannerState state, {bool reduceMotion = false}) =>
          MaterialApp(
            home: MediaQuery(
              data: MediaQueryData(disableAnimations: reduceMotion),
              child: Scaffold(
                body: Align(
                  alignment: Alignment.topCenter,
                  child: OfflineSendStatusBanner(
                    state: state,
                    onNotifications: () => opened++,
                  ),
                ),
              ),
            ),
          );
      await tester.pumpWidget(host(busy));
      expect(
        tester.getSize(find.byType(OfflineSendStatusBanner)).height,
        lessThan(100),
      );
      final rotation = find.descendant(
        of: find.byType(OfflineSendStatusBanner),
        matching: find.byType(RotationTransition),
      );
      final turns = tester.widget<RotationTransition>(rotation).turns;
      final initial = turns.value;
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
      expect(turns.value, isNot(initial));
      await tester.tap(find.text('Sending offline records'));
      expect(opened, 0);
      await tester.pumpWidget(host(busy, reduceMotion: true));
      await tester.pump();
      final reduced = turns.value;
      await tester.pump(const Duration(seconds: 1));
      expect(turns.value, reduced);
      await tester.pumpWidget(
        host(
          const OfflineSendBannerState(
            phase: OfflineSendBannerPhase.done,
            title: 'Records sent for processing',
            description: '36 batches queued · View notifications',
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(rotation, findsNothing);
      await tester.tap(find.text('Records sent for processing'));
      expect(opened, 1);
      expect(tester.takeException(), isNull);
    },
  );
}
