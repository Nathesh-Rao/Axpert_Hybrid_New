import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:axpert/app/data/services/api/api_manger.dart';
import 'package:axpert/app/data/services/connectivity/internet_connectivity.dart';
import 'package:axpert/app/data/services/storage/storage_service.dart';
import 'package:axpert/app/modules/offline_form_pages/controller/offline_form_controller.dart';
import 'package:axpert/app/modules/offline_form_pages/db/offline_db_constants.dart';
import 'package:axpert/app/modules/offline_form_pages/db/offline_db_module.dart';
import 'package:axpert/app/modules/offline_form_pages/db/offline_notification_store.dart';
import 'package:axpert/app/modules/offline_form_pages/db/offline_bundle_service.dart';
import 'package:axpert/app/modules/offline_form_pages/models/offline_record_correction.dart';
import 'package:axpert/app/modules/offline_form_pages/models/offline_update_messages.dart';
import 'package:axpert/app/modules/offline_form_pages/models/offline_refresh_report.dart';
import 'package:axpert/app/modules/offline_form_pages/widgets/offline_refresh_notification.dart';
import 'package:axpert/app/modules/offline_form_pages/widgets/offline_send_status_banner.dart';
import 'package:axpert/app/modules/offline_form_pages/models/offline_send_banner_state.dart';
import 'package:axpert/app/modules/offline_form_pages/widgets/cached_save_dialog.dart';
import 'package:axpert/app/modules/offline_form_pages/widgets/cached_refresh_dialog.dart';
import 'package:axpert/app/modules/offline_form_pages/widgets/sync_progress_dialog.dart';
import 'package:axpert/app/modules/offline_form_pages/pages/offline_form_page.dart';
import 'package:axpert/app/modules/offline_form_pages/pages/offline_notifications_page.dart';
import 'package:axpert/app/core/common.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/src/google_fonts_base.dart' as font_loader;
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class _Online extends InternetConnectivity {
  @override
  Future<void> connectivity_listen() async {} // No platform stream in tests.
  @override
  Future<bool> get connectionStatus async => true;
  @override
  Future<bool> check() async => true;
}

const _lookupSyntaxError =
    '42601: syntax error at or near ";"\r\n\r\nPOSITION: 127';

class _FormController extends OfflineFormController {
  @override
  // Deliberately omit live connectivity and timer setup in isolated tests.
  // ignore: must_call_super
  void onInit() {} // Avoid real connectivity subscriptions in widget tests.
}

class _SendingController extends _FormController {
  final session = Completer<bool>();
  var validationCalls = 0;
  @override
  Future<bool> validateSession() {
    validationCalls++;
    return session.future;
  }
}

class _MountedResetController extends _FormController {
  bool delayLookupLoading = false;
  int lookupLoads = 0;
  @override
  Future<void> loadDatasources() async {
    lookupLoads++;
    if (delayLookupLoading) {
      await Future<void>.delayed(const Duration(milliseconds: 120));
    }
    await super.loadDatasources();
  }
}

class _TestFontManifest implements AssetManifest {
  @override
  List<String> listAssets() => [
    for (final family in ['Poppins', 'Manrope', 'Inter'])
      for (final variant in ['Regular', 'Medium', 'SemiBold', 'Bold', 'Light'])
        '$family-$variant.ttf',
  ];
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _TestPaths extends PathProviderPlatform {
  final String directory;
  _TestPaths(this.directory);
  @override
  Future<String?> getTemporaryPath() async => directory;
  @override
  Future<String?> getApplicationDocumentsPath() async => directory;
}

Map<String, dynamic> _field(String name, String caption, {String type = 'c'}) =>
    {
      'fld_name': name,
      'fld_caption': caption,
      'fld_type': type,
      'data_type': 'c',
      'order': 1,
      'allowempty': 'T',
      'def_value': '',
    };
Map<String, dynamic> _schema() => {
  'transid': 'inward',
  'caption': 'Inward Entry',
  'fields': [
    _field('item_code', 'Item Code'),
    _field('supplier', 'Supplier'),
    _field('quantity', 'Quantity', type: 'n'),
  ],
};
Map<String, dynamic> _payload() => {
  'transid': 'inward',
  'action': 'create',
  'axm_recid': '0',
  'submitdata': {
    'dc1': {
      'row1': {
        'item_code': 'ITEM001',
        'supplier': 'Agile',
        'quantity': '25',
        'unknown': 'keep',
        'attachment': [
          {'path': '/saved/photo.jpg'},
        ],
      },
    },
    'dc2': {
      'row1': {'detail': 'keep this row'},
    },
  },
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory directory;
  late Database db;
  late http.Client originalClient;
  late List<Map<String, dynamic>> migrated;
  late OfflineNotificationStore store;

  setUpAll(() async {
    GoogleFonts.config.allowRuntimeFetching = false;
    // Font loading is orthogonal to these interaction tests. Supply a local
    // valid font so async DB work cannot trigger runtime font downloads.
    font_loader.assetManifest = _TestFontManifest();
    final packageConfig = File('.dart_tool/package_config.json').absolute;
    final packages =
        jsonDecode(await packageConfig.readAsString())['packages'] as List;
    final flutter = packages.firstWhere((p) => p['name'] == 'flutter');
    final sdk = Directory.fromUri(
      packageConfig.uri.resolve(flutter['rootUri'] as String),
    ).parent.parent;
    final font = await File(
      path.join(
        sdk.path,
        'bin',
        'cache',
        'artifacts',
        'material_fonts',
        'roboto-regular.ttf',
      ),
    ).readAsBytes();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMessageHandler(
          'flutter/assets',
          (message) async => ByteData.sublistView(font),
        );
    SharedPreferences.setMockInitialValues({
      'arm_url': 'https://example.test/',
      'web_url': 'https://example.test',
      'user_name': 'tester',
      'project_name': 'project',
      'arm_session_id': 'test-session',
      'auth_token': 'test-token',
    });
    await StorageService.init();
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfiNoIsolate;
    directory = await Directory.systemTemp.createTemp(
      'offline-notifications-test-',
    );
    PathProviderPlatform.instance = _TestPaths(directory.path);
    await databaseFactory.setDatabasesPath(directory.path);
    final old = await databaseFactory.openDatabase(
      path.join(directory.path, 'offline_forms.db'),
      options: OpenDatabaseOptions(
        version: 12,
        onCreate: (db, _) async {
          for (final sql in [
            OfflineDBConstants.CREATE_PENDING_REQUESTS_TABLE,
            OfflineDBConstants.CREATE_OFFLINE_USER_TABLE,
            OfflineDBConstants.CREATE_OFFLINE_PAGES_TABLE,
            OfflineDBConstants.CREATE_DATASOURCES_TABLE,
            OfflineDBConstants.CREATE_DATASOURCE_DATA_TABLE,
            OfflineDBConstants.CREATE_AUDIT_LOGS_TABLE,
            OfflineDBConstants.CREATE_CACHED_SAVE_QUEUE_TABLE,
            OfflineDBConstants.CREATE_SYNC_LOCK_TABLE,
          ]) {
            await db.execute(sql);
          }
          await db.insert('offline_pending_requests', {
            'username': 'tester',
            'project_name': 'project',
            'request_json': jsonEncode(_payload()),
            'status': 2,
          });
        },
      ),
    );
    await old.close();
    await OfflineDbModule.init();
    db = await databaseFactory.openDatabase(
      path.join(directory.path, 'offline_forms.db'),
    );
    migrated = await db.query('offline_pending_requests');
    originalClient = ApiManager.client;
  });

  setUp(() async {
    Get.testMode = true;
    for (final table in [
      'offline_pending_requests',
      'cached_save_queue',
      'offline_user',
      'offline_pages',
      'ax_audit_logs',
      'offline_notifications',
      'offline_sync_lock',
    ]) {
      await db.delete(table);
    }
    await db.insert('offline_user', {
      'username': 'tester',
      'project_name': 'project',
      'password_hash': '',
      'last_login_at': DateTime.now().toIso8601String(),
    });
    await db.insert('offline_pages', {
      'username': 'tester',
      'project_name': 'project',
      'trans_id': 'inward',
      'page_json': jsonEncode(_schema()),
    });
    store = OfflineNotificationStore(db, 'tester', 'project');
    Get.put<InternetConnectivity>(_Online());
    await StorageService.setBatchSize(2);
  });
  tearDown(() async {
    if (ApiManager.client != originalClient) ApiManager.client.close();
    ApiManager.client = originalClient;
    Get.reset();
  });
  tearDownAll(() async {
    await db.close();
    await directory.delete(recursive: true);
  });

  Future<int> seedRecord({
    String queue = 'q1',
    int status = 3,
    int version = 0,
  }) async {
    final id = await OfflineDbModule.savePayloadForQueue(payload: _payload());
    await db.update(
      'offline_pending_requests',
      {'status': status, 'current_queue_id': queue, 'record_version': version},
      where: 'id = ?',
      whereArgs: [id],
    );
    return id;
  }

  Future<void> seedQueue(List<int> ids, {String queue = 'q1'}) async {
    await db.insert('cached_save_queue', {
      'queue_id': queue,
      'username': 'tester',
      'project_name': 'project',
      'axm_recids': jsonEncode(ids),
      'status': 0,
      'payloads_count': ids.length,
      'created_at': DateTime.now().toIso8601String(),
      'updated_at': DateTime.now().toIso8601String(),
    });
  }

  void mockDetails(Map<String, dynamic>? data) {
    ApiManager.client = MockClient((request) async {
      expect(jsonDecode(request.body)['sqlparams']['pmsgtypes'], 'q1');
      return http.Response(
        jsonEncode({
          'result': {
            'success': true,
            'data': [
              {
                'adsname': 'ds_mobile_axactivemsg',
                'data': data == null
                    ? []
                    : [
                        {
                          'msgtype': 'q1',
                          'displaycontent': jsonEncode({
                            'message': {'data': data},
                          }),
                        },
                      ],
              },
            ],
          },
        }),
        200,
      );
    });
  }

  Map<String, dynamic> failed(int id, String message) => {
    'axm_recid': '$id',
    'error_message': {
      'result': {'message': message},
    },
  };
  Future<void> addEvent(
    String key, {
    String type = 'batch_queued',
    int? record,
  }) => store.add({
    'event_key': key,
    'type': type,
    'queue_id': 'q1',
    'title': 'Record needs correction',
    'message':
        'Item Code value exceeds the maximum allowed length of 5 characters',
    'record_id': record,
    'caption': 'Inward Entry',
    'trans_id': 'inward',
  });

  test('v12 migration preserves existing offline payloads', () async {
    expect(await db.getVersion(), 13);
    expect(migrated.single['request_json'], jsonEncode(_payload()));
    expect(migrated.single['record_version'], 0);
    expect(migrated.single['current_queue_id'], '');
  });
  test(
    'read snapshots, deletion, undo and clear are scoped and deduplicated',
    () async {
      await addEvent('accepted');
      await addEvent('accepted');
      final first = (await store.list()).single;
      await addEvent('result');
      await store.markRead([first.id]);
      expect(
        await store.unreadCount(),
        1,
      ); // New arrival was not in the snapshot.
      await store.delete(first.id);
      await addEvent('accepted');
      expect(
        (await store.list()).length,
        1,
      ); // Deleted event does not resurrect.
      await store.restore(first.id);
      expect((await store.list()).length, 2);
      final other = OfflineNotificationStore(db, 'someone', 'other-project');
      await other.add({
        'event_key': 'accepted',
        'type': 'batch_queued',
        'queue_id': 'q2',
        'title': 'Other project',
        'message': 'keep',
      });
      await store.clear();
      expect(await store.list(), isEmpty);
      expect(await store.unreadCount(), 0);
      expect((await other.list()).length, 1);
      expect(await db.query('offline_pages'), isNotEmpty);
      expect(await db.query('ax_audit_logs'), isEmpty);
    },
  );
  test('notification history survives reopening a SQLite connection', () async {
    final file = path.join(directory.path, 'notification-restart.db');
    var connection = await databaseFactory.openDatabase(file);
    await OfflineNotificationStore.create(connection);
    var history = OfflineNotificationStore(connection, 'tester', 'project');
    await history.add({
      'event_key': 'persist',
      'type': 'batch_queued',
      'queue_id': 'q',
      'title': 'Saved',
      'message': 'Keep',
    });
    await connection.close();
    connection = await databaseFactory.openDatabase(file);
    history = OfflineNotificationStore(connection, 'tester', 'project');
    expect((await history.list()).single.title, 'Saved');
    expect(await history.unreadCount(), 1);
    await connection.close();
  });
  test(
    'API details produce batch counts and per-record errors, not trigger counts',
    () async {
      final good = await seedRecord(), bad = await seedRecord();
      await seedQueue([good, bad]);
      mockDetails({
        'axm_queueid': 'q1',
        'status': 'partial_success',
        'success_transactions': [
          {'axm_recid': '$good'},
        ],
        'failed_transactions': [failed(bad, 'Item Code is too long')],
      });
      await OfflineDbModule.processCachedSaveQueueFCM({
        'axm_queueid': 'q1',
        'status': 'success',
      });
      final messages = await store.list();
      expect(messages.length, 2);
      expect(messages.first.recordId, bad);
      expect(messages.first.caption, 'Inward Entry');
      expect(messages.last.successCount, 1);
      expect(messages.last.failedCount, 1);
      expect(
        (await db.query(
          'offline_pending_requests',
          where: 'id = ?',
          whereArgs: [bad],
        )).single['status'],
        2,
      );
      await OfflineDbModule.processCachedSaveQueueFCM({
        'axm_queueid': 'q1',
        'status': 'partial_success',
      });
      expect((await store.list()).length, 2);
    },
  );
  test(
    'success triggers still fetch detailed results and preserve full success',
    () async {
      final id = await seedRecord();
      await seedQueue([id]);
      mockDetails({'axm_queueid': 'q1', 'status': 'success'});
      await OfflineDbModule.processCachedSaveQueueFCM({
        'axm_queueid': 'q1',
        'status': 'success',
      });
      expect((await db.query('offline_pending_requests')).single['status'], 1);
      expect((await store.list()).single.successCount, 1);
    },
  );
  test('missing details keep queue pending for another check', () async {
    final id = await seedRecord();
    await seedQueue([id]);
    mockDetails(null);
    await OfflineDbModule.processCachedSaveQueueFCM({
      'axm_queueid': 'q1',
      'status': 'failed',
    });
    expect((await db.query('cached_save_queue')).single['status'], 0);
    expect((await db.query('offline_pending_requests')).single['status'], 3);
    expect((await store.list()).single.type, 'batch_error');
  });
  test('conflicting record IDs do not overwrite records', () async {
    final id = await seedRecord();
    await seedQueue([id]);
    mockDetails({
      'axm_queueid': 'q1',
      'status': 'partial_success',
      'success_transactions': [
        {'axm_recid': '$id'},
      ],
      'failed_transactions': [failed(id, 'Error')],
    });
    await OfflineDbModule.processCachedSaveQueueFCM({'axm_queueid': 'q1'});
    expect((await db.query('offline_pending_requests')).single['status'], 3);
    expect((await db.query('cached_save_queue')).single['status'], 0);
  });
  test(
    'correction updates same row, stamps ID, audits and ignores stale queue results',
    () async {
      final id = await seedRecord(status: 2);
      await seedQueue([id]);
      final corrected = _payload();
      corrected['submitdata']['dc1']['row1']['item_code'] = 'ITEM1';
      expect(
        await OfflineDbModule.savePayloadForQueue(
          payload: corrected,
          existingRecordId: id,
          expectedVersion: 0,
          expectedUsername: 'tester',
          expectedProjectName: 'project',
        ),
        id,
      );
      var row = (await db.query('offline_pending_requests')).single;
      expect(row['status'], 0);
      expect(row['record_version'], 1);
      expect(jsonDecode(row['request_json'] as String)['axm_recid'], '$id');
      expect(
        (await db.query('ax_audit_logs')).single['action'],
        'OFFLINE_RECORD_CORRECTION',
      );
      mockDetails({'axm_queueid': 'q1', 'status': 'success'});
      await OfflineDbModule.processCachedSaveQueueFCM({
        'axm_queueid': 'q1',
        'status': 'success',
      });
      row = (await db.query('offline_pending_requests')).single;
      expect(row['status'], 0);
      expect(row['record_version'], 1);
    },
  );
  test('correction refuses queued records and a stale version', () async {
    final id = await seedRecord();
    expect(
      await OfflineDbModule.savePayloadForQueue(
        payload: _payload(),
        existingRecordId: id,
        expectedVersion: 0,
        expectedUsername: 'tester',
        expectedProjectName: 'project',
      ),
      -1,
    );
    await db.update('offline_pending_requests', {
      'status': 2,
      'record_version': 1,
    });
    expect(
      await OfflineDbModule.savePayloadForQueue(
        payload: _payload(),
        existingRecordId: id,
        expectedVersion: 0,
        expectedUsername: 'tester',
        expectedProjectName: 'project',
      ),
      -1,
    );
    expect(
      (await db.query('offline_pending_requests')).single['record_version'],
      1,
    );
  });
  test(
    'busy sync defers trigger durably and refuses correction without blocking editing',
    () async {
      final id = await seedRecord(status: 2);
      await seedQueue([id]);
      await OfflineDbModule.tryAcquireCachedSaveLock(owner: 'test-background');
      await OfflineDbModule.processCachedSaveQueueFCM({'axm_queueid': 'q1'});
      expect(
        jsonDecode(
          (await db.query('cached_save_queue')).single['fcm_response']
              as String,
        )['axm_queueid'],
        'q1',
      );
      expect(
        await OfflineDbModule.savePayloadForQueue(
          payload: _payload(),
          existingRecordId: id,
          expectedVersion: 0,
          expectedUsername: 'tester',
          expectedProjectName: 'project',
        ),
        -1,
      );
      await OfflineDbModule.releaseCachedSaveLock(owner: 'test-background');
    },
  );
  test(
    'whole phrase matching handles free prose, names and ambiguous messages',
    () {
      final fields = [
        _field('item_code', 'Item Code'),
        _field('code', 'Code'),
        _field('supplier', 'Supplier'),
      ];
      expect(
        matchOfflineErrorField('Invalid ITEM   CODE value', fields),
        'item_code',
      );
      expect(
        matchOfflineErrorField('item_code exceeds limit', fields),
        'item_code',
      );
      expect(matchOfflineErrorField('Barcode failed', fields), isNull);
      expect(
        matchOfflineErrorField('Item Code and Supplier are invalid', fields),
        isNull,
      );
      expect(
        matchOfflineErrorField(
          '22001: value too long for type character varying(5)',
          fields,
        ),
        isNull,
      );
      expect(
        matchOfflineErrorField('Item Code invalid', [
          ...fields,
          _field('other', 'Item Code'),
        ]),
        isNull,
      );
    },
  );

  testWidgets(
    'parsed API results update the banner without changing read flags or extending duplicate errors',
    (tester) async {
    final controller = _FormController();
    await controller.refreshBatchResultBanner();
      final first = await seedRecord();
      final second = await seedRecord();
      await seedQueue([first, second]);
      mockDetails({
        'axm_queueid': 'q1',
        'status': 'partial_success',
        'success_transactions': [
          {'axm_recid': first.toString()},
        ],
        'failed_transactions': [failed(second, 'Item Code is too long')],
      });
      await tester.runAsync(
        () => OfflineDbModule.processCachedSaveQueueFCM({
          'axm_queueid': 'q1',
          'status': 'partial_success',
        }),
      );
      final unread = await store.unreadCount();
      await controller.refreshNotificationCount();
      final banner = controller.currentSendPendingBanner!;
      expect(banner.hasIssues, isTrue);
      expect(banner.description, '1 submitted · 1 need attention');
      expect(controller.sendPendingRecordsDisabled, isFalse);
      expect(await store.unreadCount(), unread);
      await tester.pump(const Duration(seconds: 118));
      await controller.refreshNotificationCount();
      expect(controller.currentSendPendingBanner, same(banner));
      await tester.pump(const Duration(seconds: 2));
      expect(controller.currentSendPendingBanner, isNull);
      expect(await store.unreadCount(), unread);
      expect(
        (await db.query(
          'offline_pending_requests',
          orderBy: 'id',
        )).map((row) => row['status']),
        [1, 2],
      );
      controller.onClose();
    },
  );

  test(
    'audit and historical notifications do not become new result banners',
    () async {
      await seedQueue([1]);
      await db.update('cached_save_queue', {
        'source_table': OfflineDBConstants.TABLE_AUDIT_LOGS,
      });
      final controller = _FormController();
      await controller.refreshBatchResultBanner();
      await addEvent('audit-error', type: 'batch_error');
      await controller.refreshBatchResultBanner();
      expect(controller.currentSendPendingBanner, isNull);
      expect(await store.unreadCount(), 1);
      final nextController = _FormController();
      await nextController.refreshBatchResultBanner();
      expect(nextController.currentSendPendingBanner, isNull);
      controller.onClose();
      nextController.onClose();
    },
  );

  test(
    'submission presentation keeps legacy/form rows and hides audit rows',
    () {
      final controller = _FormController();
      expect(
        controller
            .formSubmissionQueues([
              {'queue_id': 'legacy'},
              {
                'queue_id': 'form',
                'source_table': OfflineDBConstants.TABLE_PENDING_REQUESTS,
              },
              {
                'queue_id': 'audit',
                'source_table': OfflineDBConstants.TABLE_AUDIT_LOGS,
              },
            ])
            .map((row) => row['queue_id']),
        ['legacy', 'form'],
      );
    },
  );

  test(
    'audit-only queues stay available to backend but have no submission badge',
    () async {
      await seedQueue([1], queue: 'audit-only');
      await db.update('cached_save_queue', {
        'source_table': OfflineDBConstants.TABLE_AUDIT_LOGS,
      });
      final controller = _FormController();
      await controller.refreshPendingQueuesCount();
      expect(controller.pendingQueuesCount.value, 0);
      expect((await OfflineDbModule.getPendigQueuesToRefresh()).length, 1);
    },
  );

  testWidgets(
    'submission UI hides audits before and after resolving all queue types',
    (tester) async {
      for (final queue in ['form-1', 'audit-1', 'form-2', 'audit-2']) {
        await seedQueue([1], queue: queue);
        if (queue.startsWith('audit')) {
          await db.update(
            'cached_save_queue',
            {'source_table': OfflineDBConstants.TABLE_AUDIT_LOGS},
            where: 'queue_id = ?',
            whereArgs: [queue],
          );
        }
      }
      final rows = await OfflineDbModule.getPendigQueuesToRefresh();
      expect(rows.length, 4); // The shared query is deliberately unfiltered.
      final controller = Get.put<OfflineFormController>(_FormController());
      await controller.refreshPendingQueuesCount();
      expect(controller.pendingQueuesCount.value, 2);
      final requestedQueues = <String>[];
      ApiManager.client = MockClient((request) async {
        requestedQueues.addAll(
          (jsonDecode(request.body)['sqlparams']['pmsgtypes'] as String).split(
            ',',
          ),
        );
        return http.Response('{"result":{"success":true,"data":[]}}', 200);
      });
      await tester.pumpWidget(
        GetMaterialApp(
          home: Scaffold(
            body: CachedRefreshDialogWidget(refreshQueueRows: rows),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('form-1'), findsOneWidget);
      expect(find.text('form-2'), findsOneWidget);
      expect(find.text('audit-1'), findsNothing);
      expect(find.text('audit-2'), findsNothing);
      expect(find.textContaining('Found 2 pending queue(s)'), findsOneWidget);
      await tester.tap(find.text('Refresh and Continue'));
      for (
        var step = 0;
        step < 100 && !controller.isPendingQueResolveComplete.value;
        step++
      ) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 10)),
        );
        await tester.pump(const Duration(milliseconds: 20));
      }
      await tester.pumpAndSettle();
      expect(
        requestedQueues,
        unorderedEquals(['form-1', 'audit-1', 'form-2', 'audit-2']),
      );
      expect(
        controller.pendingQueResolveResults.length,
        4,
      ); // Audit resolution still runs.
      expect(find.text('form-1'), findsOneWidget);
      expect(find.text('form-2'), findsOneWidget);
      expect(find.text('audit-1'), findsNothing);
      expect(find.text('audit-2'), findsNothing);
      expect(find.text('2 not found on server'), findsOneWidget);
      expect(
        (await db.query('cached_save_queue')).length,
        4,
      ); // No queues deleted or rewritten for display.
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  test(
    'manual send preserves batching and creates one accepted notification per record batch',
    () async {
      for (var i = 0; i < 3; i++) {
        await OfflineDbModule.savePayloadForQueue(payload: _payload());
      }
      final pushedCounts = <int>[];
      ApiManager.client = MockClient((request) async {
        final parameters = jsonDecode(
          jsonDecode(request.body)['queuedata'],
        )['_parameters'][0];
        if (parameters['data'][0]['transid'] == 'inward') {
          pushedCounts.add((parameters['data'] as List).length);
        }
        return http.Response('{"result":{"success":true}}', 200);
      });
      await OfflineDbModule.startCachedSave(controller: _FormController());
      expect(pushedCounts, [2, 1]);
      final messages = await store.list();
      expect(messages.length, 2);
      expect(messages.every((e) => e.type == 'batch_queued'), isTrue);
      final records = await db.query('offline_pending_requests');
      expect(
        records.every(
          (r) =>
              r['status'] == 3 && (r['current_queue_id'] as String).isNotEmpty,
        ),
        isTrue,
      );
    },
  );

  for (final scenario in ['success', 'failure', 'previous queue']) {
    testWidgets('manual send banner preserves flow: $scenario', (tester) async {
      int? oldRecord;
      if (scenario == 'previous queue') {
        oldRecord = await seedRecord(queue: 'older');
        await seedQueue([oldRecord], queue: 'older');
      }
      for (var i = 0; i < 3; i++) {
        await OfflineDbModule.savePayloadForQueue(payload: _payload());
      }
      final calls = <String>[];
      final pushedCounts = <int>[];
      ApiManager.client = MockClient((request) async {
        final body = jsonDecode(request.body) as Map;
        if (!body.containsKey('queuedata')) {
          calls.add('resolve');
          return http.Response('{"result":{"success":true,"data":[]}}', 200);
        }
        final parameters = jsonDecode(body['queuedata'])['_parameters'][0];
        if (parameters['data'][0]['transid'] == 'inward') {
          calls.add('upload');
          pushedCounts.add((parameters['data'] as List).length);
          if (scenario == 'failure' && pushedCounts.length == 2) {
            return http.Response('{"result":{"success":false}}', 200);
          }
        }
        return http.Response('{"result":{"success":true}}', 200);
      });
      final controller = _SendingController();
      await tester.pumpWidget(
        GetMaterialApp(
          home: Scaffold(
            body: Obx(() {
              final state = controller.currentSendPendingBanner;
              return state == null
                  ? const SizedBox()
                  : Align(
                      alignment: Alignment.topCenter,
                      child: OfflineSendStatusBanner(
                        state: state,
                        onNotifications: () {},
                      ),
                    );
            }),
          ),
        ),
      );
      final sending = controller.actionPushPendingByCachedSave();
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 60)),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Upload Now'));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 60)),
      );
      await tester.pump(const Duration(milliseconds: 300));
      expect(controller.sendPendingRecordsDisabled, isTrue);
      expect(controller.validationCalls, 1);
      expect(find.text('Checking your session'), findsOneWidget);
      await controller
          .actionPushPendingByCachedSave(); // Double taps are ignored.
      expect(controller.validationCalls, 1);
      controller.session.complete(true);
      var finished = false;
      unawaited(sending.whenComplete(() => finished = true));
      // Allow real filesystem I/O and fake UI microtasks to make progress
      // together, without waiting for an intentionally rotating icon.
      for (var step = 0; step < 300 && !finished; step++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 10)),
        );
        await tester.pump(const Duration(milliseconds: 20));
      }
      expect(finished, isTrue);
      await sending;
      await tester.pump(const Duration(milliseconds: 450));
      expect(find.byType(CachedSaveDialogWidget), findsNothing);
      expect(find.byType(CachedRefreshDialogWidget), findsNothing);
      expect(pushedCounts, [2, 1]);
      expect(controller.sendPendingRecordsDisabled, isFalse);
      expect(controller.isLoading.value, isFalse);
      expect(
        controller.currentSendPendingBanner!.phase,
        scenario == 'failure'
            ? OfflineSendBannerPhase.issues
            : OfflineSendBannerPhase.done,
      );
      final messages = await store.list();
      expect(
        messages.where((e) => e.type == 'batch_queued').length,
        scenario == 'failure' ? 1 : 2,
      );
      expect(
        messages.where((e) => e.type == 'batch_error').length,
        scenario == 'failure' ? 1 : 0,
      );
      if (oldRecord != null) {
        expect(calls.first, 'resolve');
        expect(
          (await db.query(
            'offline_pending_requests',
            where: 'id = ?',
            whereArgs: [oldRecord],
          )).single['status'],
          3,
        );
      }
      // Finishing releases the same shared lock and hides presentation only.
      expect(
        await OfflineDbModule.tryAcquireCachedSaveLock(owner: 'banner-test'),
        isTrue,
      );
      await OfflineDbModule.releaseCachedSaveLock(owner: 'banner-test');
      await tester.pump(Duration(seconds: scenario == 'failure' ? 121 : 6));
      expect(controller.currentSendPendingBanner, isNull);
      controller.onClose();
      await tester.pumpWidget(const SizedBox());
    });
  }

  test(
    'background send and polling share durable notification generation',
    () async {
      for (var i = 0; i < 3; i++) {
        await OfflineDbModule.savePayloadForQueue(payload: _payload());
      }
      // Existing audit upload still uses ApiManager; background record calls use
      // the raw HTTP client. Both are stubbed, without contacting a live server.
      ApiManager.client = MockClient(
        (_) async => http.Response('{"result":{"success":true}}', 200),
      );
      final result = await http.runWithClient(
        () => OfflineDbModule.runCachedSave(),
        () => MockClient(
          (_) async => http.Response('{"result":{"success":true}}', 200),
        ),
      );
      expect(result.status, CachedSaveStatus.success);
      expect(result.totalPushed, 3);
      expect(
        (await store.list()).where((e) => e.type == 'batch_queued').length,
        2,
      );
      final queues = await db.query(
        'cached_save_queue',
        where: 'source_table = ?',
        whereArgs: ['offline_pending_requests'],
      );
      await http.runWithClient(
        () =>
            OfflineDbModule.resolvePendingCachedSaveQueueBatchesBackgroundSafe(),
        () => MockClient(
          (_) async => http.Response(
            jsonEncode({
              'result': {
                'success': true,
                'data': [
                  {
                    'adsname': 'ds_mobile_axactivemsg',
                    'data': [
                      for (final queue in queues)
                        {
                          'msgtype': queue['queue_id'],
                          'displaycontent': jsonEncode({
                            'message': {
                              'data': {
                                'axm_queueid': queue['queue_id'],
                                'status': 'success',
                              },
                            },
                          }),
                        },
                    ],
                  },
                ],
              },
            }),
            200,
          ),
        ),
      );
      expect(
        (await db.query(
          'offline_pending_requests',
        )).every((r) => r['status'] == 1),
        isTrue,
      );
      expect(
        (await store.list()).where((e) => e.type == 'batch_success').length,
        2,
      );
    },
  );

  test(
    'background queue trigger fetches detailed record failures without UI',
    () async {
      final id = await seedRecord();
      await seedQueue([id]);
      await http.runWithClient(
        () => OfflineDbModule.processCachedSaveQueueFCM({
          'axm_queueid': 'q1',
        }, isBackground: true),
        () => MockClient(
          (_) async => http.Response(
            jsonEncode({
              'result': {
                'success': true,
                'data': [
                  {
                    'adsname': 'ds_mobile_axactivemsg',
                    'data': [
                      {
                        'msgtype': 'q1',
                        'displaycontent': jsonEncode({
                          'message': {
                            'data': {
                              'axm_queueid': 'q1',
                              'status': 'failed',
                              'failed_transactions': [
                                failed(id, 'Database validation failed'),
                              ],
                            },
                          },
                        }),
                      },
                    ],
                  },
                ],
              },
            }),
            200,
          ),
        ),
      );
      expect((await store.list()).first.recordId, id);
      expect((await db.query('offline_pending_requests')).single['status'], 2);
    },
  );

  testWidgets(
    'new offline saves keep the form open and reset for consecutive records',
    (tester) async {
      final controller = Get.put<OfflineFormController>(_FormController());
      final formSchema = _schema();
      (formSchema['fields'] as List)[1]['def_value'] = 'Default supplier';
      (formSchema['fields'] as List)[2]['def_value'] = '1';
      (formSchema['fields'] as List).addAll(<Map<String, dynamic>>[
        for (var i = 0; i < 12; i++) _field('extra_$i', 'Extra field $i'),
      ]);
      await controller.prepareForm(formSchema);
      await tester.pumpWidget(
        ScreenUtilInit(
          builder: (_, _) => GetMaterialApp(
            home: const Scaffold(body: Text('Offline listing')),
            getPages: [
              GetPage(
                name: Routes.OFFLINE_FORM_PAGE,
                page: () => const OfflineFormPage(),
              ),
            ],
          ),
        ),
      );
      Get.toNamed(Routes.OFFLINE_FORM_PAGE);
      await tester.pumpAndSettle();
      final formRoute = Get.currentRoute;
      controller.textCtrls['item_code']!.text = 'FIRST';
      controller.textCtrls['supplier']!.text = 'First supplier';
      controller.textCtrls['quantity']!.text = '25';
      controller.scrollCtrl.jumpTo(100);
      await tester.runAsync(() => controller.onFormSubmit());
      await tester.pumpAndSettle();
      expect(find.byType(OfflineFormPage), findsOneWidget);
      expect(Get.currentRoute, formRoute);
      expect(controller.textCtrls['item_code']!.text, '');
      expect(controller.textCtrls['supplier']!.text, 'Default supplier');
      expect(controller.textCtrls['quantity']!.text, '1');
      expect(controller.scrollCtrl.offset, 0);
      expect(controller.errors, isEmpty);
      expect(controller.isLoading.value, isFalse);
      expect(controller.isFormPreparing.value, isFalse);
      controller.textCtrls['item_code']!.text = 'SECOND';
      await tester.runAsync(() => controller.onFormSubmit());
      await tester.pumpAndSettle();
      final records = await db.query('offline_pending_requests', orderBy: 'id');
      expect(records.length, 2);
      final values = records
          .map(
            (record) => jsonDecode(
              record['request_json'] as String,
            )['submitdata']['dc1']['row1'],
          )
          .toList();
      expect(values[0]['item_code'], 'FIRST');
      expect(values[0]['supplier'], 'First supplier');
      expect(values[1]['item_code'], 'SECOND');
      expect(values[1]['supplier'], 'Default supplier');
      expect(records.every((record) => record['status'] == 0), isTrue);
      expect(find.byType(OfflineFormPage), findsOneWidget);
      expect(controller.textCtrls['item_code']!.text, '');
      expect(tester.takeException(), isNull);
      await tester.pump(const Duration(seconds: 8));
      await tester.pumpAndSettle();
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'focused form reset keeps mounted controllers alive between frames',
    (tester) async {
      final controller = Get.put<OfflineFormController>(
        _MountedResetController(),
      );
      // Real downloaded schemas are JSON-decoded (List<dynamic> fields).
      final formSchema =
          jsonDecode(jsonEncode(_schema())) as Map<String, dynamic>;
      (formSchema['fields'] as List).add(<String, dynamic>{
        ..._field('unit', 'Unit', type: 'dd'),
        'datasource': 'units',
        'def_value': 'UNIT-A',
      });
      await controller.prepareForm(formSchema);
      controller.datasourceMap['units'] = [
        {'unit': 'UNIT-A'},
        {'unit': 'UNIT-B'},
      ];
      controller.dropdownCtrls['unit']!.value = 'UNIT-B';
      final original = controller.textCtrls['item_code']!;
      final originalDropdown = controller.dropdownCtrls['unit']!;
      await tester.pumpWidget(
        ScreenUtilInit(
          builder: (_, _) => GetMaterialApp(home: const OfflineFormPage()),
        ),
      );
      final entry = find.byWidgetPredicate(
        (widget) => widget is TextFormField && widget.controller == original,
      );
      await tester.enterText(entry, 'FOCUSED');
      await tester.pump();
      (controller as _MountedResetController).delayLookupLoading = true;
      final saving = controller.onFormSubmit();
      var finished = false;
      unawaited(saving.whenComplete(() => finished = true));
      // Pump real frames during reset, instead of awaiting all I/O before any
      // frame (which can conceal disposal of controllers still used by fields).
      for (var step = 0; step < 80 && !finished; step++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 10)),
        );
        await tester.pump(const Duration(milliseconds: 20));
      }
      expect(finished, isTrue);
      await saving;
      expect(tester.takeException(), isNull);
      expect(identical(controller.textCtrls['item_code'], original), isTrue);
      expect(
        identical(controller.dropdownCtrls['unit'], originalDropdown),
        isTrue,
      );
      expect(originalDropdown.value, 'UNIT-A');
      expect(controller.getDropdownOptions('unit'), ['UNIT-A', 'UNIT-B']);
      expect(
        controller.lookupLoads,
        1,
      ); // No mid-reset reload/empty lookup map.
      expect(original.text, '');
      expect(find.byType(OfflineFormPage), findsOneWidget);
      expect((await db.query('offline_pending_requests')).length, 1);
      await tester.pump(const Duration(seconds: 4));
      await tester.pumpAndSettle();
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'validation failure keeps entered values and does not start a new record',
    (tester) async {
      final controller = Get.put<OfflineFormController>(_FormController());
      final formSchema = _schema();
      (formSchema['fields'] as List)[0]['allowempty'] = 'F';
      await controller.prepareForm(formSchema);
      controller.textCtrls['supplier']!.text = 'Keep this supplier';
      await tester.pumpWidget(GetMaterialApp(home: const Scaffold()));
      await controller.onFormSubmit();
      await tester.pumpAndSettle();
      expect(await db.query('offline_pending_requests'), isEmpty);
      expect(controller.textCtrls['supplier']!.text, 'Keep this supplier');
      expect(controller.errors['item_code'], 'Item Code is required');
      await tester.pump(const Duration(seconds: 4));
      await tester.pumpAndSettle();
      await tester.pumpWidget(const SizedBox());
    },
  );

  for (final errorMessage in [
    'Item Code is too long',
    '22001: value too long for type character varying(5)',
  ]) {
    testWidgets(
      'record card opens hydrated form and saves correction: $errorMessage',
      (tester) async {
        final id = await seedRecord(status: 2);
        await seedQueue([id]);
        await db.update('offline_pending_requests', {'response': errorMessage});
        await addEvent('record', type: 'record_error', record: id);
        final controller = Get.put<OfflineFormController>(_FormController());
        await tester.pumpWidget(
          ScreenUtilInit(
            builder: (_, _) => GetMaterialApp(
              home: OfflineNotificationsPage(formController: controller),
              getPages: [
                GetPage(
                  name: Routes.OFFLINE_FORM_PAGE,
                  page: () => const OfflineFormPage(),
                ),
              ],
            ),
          ),
        );
        await tester.runAsync(() async {
          await Future<void>.delayed(const Duration(milliseconds: 80));
        });
        await tester.pumpAndSettle();
        await tester.tap(find.text('Record needs correction'));
        await tester.runAsync(() async {
          await Future<void>.delayed(const Duration(milliseconds: 100));
        });
        await tester.pumpAndSettle();
        expect(controller.textCtrls['item_code']!.text, 'ITEM001');
        expect(controller.textCtrls['supplier']!.text, 'Agile');
        expect(
          controller.errors['item_code'],
          errorMessage.startsWith('Item Code') ? errorMessage : isNull,
        );
        expect(controller.correctionMessage.value, errorMessage);
        expect(find.text('Save Changes'), findsOneWidget);
        controller.textCtrls['item_code']!.text = 'ITEM1';
        final merged = controller.generateSubmitPayloadCachedSave();
        expect(merged['submitdata']['dc1']['row1']['unknown'], 'keep');
        expect(merged['submitdata']['dc1']['row1']['attachment'], [
          {'path': '/saved/photo.jpg'},
        ]);
        expect(merged['submitdata']['dc2']['row1']['detail'], 'keep this row');
        await tester.runAsync(() => controller.onFormSubmit());
        await tester.pumpAndSettle();
        final saved = (await db.query('offline_pending_requests')).single;
        expect(saved['id'], id);
        expect(saved['record_version'], 1);
        expect(saved['status'], 0);
        expect(
          jsonDecode(
            saved['request_json'] as String,
          )['submitdata']['dc1']['row1']['item_code'],
          'ITEM1',
        );
        expect(
          (await db.query('ax_audit_logs')).single['action'],
          'OFFLINE_RECORD_CORRECTION',
        );
        await tester.pump(const Duration(seconds: 4));
        await tester.pumpAndSettle();
        await tester.pumpWidget(const SizedBox());
      },
    );
  }

  testWidgets(
    'panel clears badge and supports swipe, undo, clear confirmation',
    (tester) async {
      await addEvent('a');
      await addEvent('b');
      final controller = Get.put<OfflineFormController>(_FormController());
      await tester.pumpWidget(
        GetMaterialApp(
          home: OfflineNotificationsPage(formController: controller),
        ),
      );
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 80));
      });
      await tester.pumpAndSettle();
      expect(await store.unreadCount(), 0);
      expect(find.byType(Dismissible), findsNWidgets(2));
      await tester.drag(find.byType(Dismissible).first, const Offset(-600, 0));
      await tester.pumpAndSettle();
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 50));
      });
      await tester.pump();
      expect((await store.list()).length, 1);
      await tester.tap(find.text('Undo'));
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 50));
      });
      await tester.pumpAndSettle();
      expect((await store.list()).length, 2);
      await tester.tap(find.text('Clear All').first);
      await tester.pumpAndSettle();
      expect(find.text('Clear all notifications?'), findsOneWidget);
      await tester.tap(find.text('Clear All').last);
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 50));
      });
      await tester.pumpAndSettle();
      expect(find.text('You’re up to date'), findsOneWidget);
      expect(await store.list(), isEmpty);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'deletion Undo bar disappears after four seconds without restoring the message',
    (tester) async {
      await addEvent('expires');
      final controller = Get.put<OfflineFormController>(_FormController());
      await tester.pumpWidget(
        GetMaterialApp(
          home: OfflineNotificationsPage(formController: controller),
        ),
      );
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 80));
      });
      await tester.pumpAndSettle();
      await tester.drag(find.byType(Dismissible), const Offset(-600, 0));
      await tester.pumpAndSettle();
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 80));
      });
      await tester.pumpAndSettle();
      expect(find.text('Notification deleted'), findsOneWidget);
      expect(find.text('Undo'), findsOneWidget);
      await tester.pump(const Duration(seconds: 2));
      expect(find.text('Undo'), findsOneWidget);
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();
      expect(find.text('Notification deleted'), findsNothing);
      expect(find.text('Undo'), findsNothing);
      expect(await store.list(), isEmpty);
      await tester.pumpWidget(const SizedBox());
    },
  );

  for (final scope in <String?>[null, 'inward']) {
    for (final outcome in [
      'success',
      'lookup_error',
      'syntax_error',
      'bulk_error',
      'timeout',
      'form_error',
      'empty_rows',
      'no_lookups',
    ]) {
      testWidgets('refresh ${scope ?? 'all'} notifications: $outcome', (
        tester,
      ) async {
        final pages = [
          for (var i = 0; i < 3; i++)
            {
              'transid': i == 0 ? 'inward' : 'form-$i',
              'caption': i == 0 ? 'Inward Entry' : 'Form $i',
              'fields': outcome == 'no_lookups'
                  ? []
                  : [
                      {
                        ..._field('item_code', 'Items'),
                        'datasource': 'ds_items',
                      },
                      {
                        ..._field('supplier', 'Suppliers'),
                        'datasource': 'ds_suppliers',
                      },
                    ],
            },
        ];
        var lookupCalls = 0;
        ApiManager.client = MockClient((request) async {
          lookupCalls++;
          if (outcome == 'timeout')
            return http.Response(
              '{"result":{"success":false,"message":"Lookup download timed out"}}',
              200,
            );
          if (outcome == 'bulk_error')
            return http.Response(
              '{"result":{"success":false,"message":"22001: value too long for type character varying(5)"}}',
              200,
            );
          final names = (jsonDecode(request.body)['ADSNames'] as List)
              .cast<String>();
          return http.Response(
            jsonEncode({
              'result': {
                'success': true,
                'data': [
                  for (final name in names)
                    if (['lookup_error', 'syntax_error'].contains(outcome) &&
                        name == 'ds_suppliers')
                      {
                        'adsname': name,
                        'error': outcome == 'syntax_error'
                            ? _lookupSyntaxError
                            : 'Suppliers are temporarily unavailable. Please try again later.',
                      }
                    else
                      {
                        'adsname': name,
                        'data': outcome == 'empty_rows'
                            ? []
                            : [
                                {'name': 'Saved data'},
                              ],
                      },
                ],
              },
            }),
            200,
          );
        });
        final controller = _FormController();
        await tester.pumpWidget(
          ScreenUtilInit(
            builder: (_, _) => GetMaterialApp(home: const Scaffold()),
          ),
        );
        final refresh = http.runWithClient(
          () =>
              controller.actionSyncAll(transId: scope, caption: 'Inward Entry'),
          () => MockClient(
            (request) async => request.url.path.endsWith('AxValidateSession')
                ? http.Response('{"result":{"success":true}}', 200)
                : http.Response(
                    outcome == 'form_error' ? '{}' : jsonEncode(pages),
                    outcome == 'form_error' ? 500 : 200,
                  ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text(scope == null ? 'Start Sync' : 'Refresh'));
        await tester.runAsync(() => refresh);
        await tester.pumpAndSettle();
        final progress = tester
            .widget<SyncProgressDialog>(find.byType(SyncProgressDialog))
            .progressModel;
        final messages = await store.list();
        final formCount = scope == null ? 3 : 1;
        if (outcome == 'form_error') {
          expect(lookupCalls, 0);
          expect(messages.length, 1);
          expect(messages.single.type, 'refresh_error');
          expect(messages.single.title, contains('could not be downloaded'));
          expect(messages.single.refreshReport!.failedForms, 1);
          expect(
            messages.single.refreshReport!.forms.single.formError,
            isNotNull,
          );
          expect(
            messages.single.refreshReport!.forms.single.lookupsCompleted,
            isFalse,
          );
          expect(
            jsonDecode(
              (await db.query('offline_pages')).single['page_json'] as String,
            )['caption'],
            'Inward Entry',
          );
        } else {
          final failed = ['lookup_error', 'syntax_error'].contains(outcome)
              ? formCount
              : ['bulk_error', 'timeout'].contains(outcome)
              ? formCount * 2
              : 0;
          final totalLookups = outcome == 'no_lookups' ? 0 : formCount * 2;
          final summary = messages.where((m) => m.isRefreshSummary).single;
          final report = summary.refreshReport!;
          final errors = report.forms
              .expand((form) => form.lookupErrors)
              .toList();
          expect(errors.length, failed);
          expect(messages.length, 1);
          expect(
            messages.where((message) => message.type == 'lookup_error'),
            isEmpty,
          );
          expect(report.updatedForms, formCount);
          expect(report.forms.length, formCount);
          for (final form in report.forms) {
            expect(form.lookupsCompleted, isTrue);
            expect(form.totalLookups, outcome == 'no_lookups' ? 0 : 2);
            expect(
              form.failedLookups,
              ['lookup_error', 'syntax_error'].contains(outcome)
                  ? 1
                  : ['bulk_error', 'timeout'].contains(outcome)
                  ? 2
                  : 0,
            );
          }
          expect(summary.successCount, totalLookups - failed);
          expect(summary.failedCount, failed);
          expect(
            summary.type,
            failed == 0 ? 'refresh_success' : 'refresh_warning',
          );
          expect(
            summary.message,
            startsWith(
              '$formCount ${formCount == 1 ? 'form' : 'forms'} updated.',
            ),
          );
          // One bulk failure contributes one API failure, irrespective of lookup-card count.
          expect(lookupCalls, outcome == 'no_lookups' ? 0 : formCount);
          expect(
            progress.totalItems.value,
            (scope == null ? 2 : 1) + lookupCalls,
          );
          expect(progress.failureCount.value, failed == 0 ? 0 : formCount);
          for (final error in errors) {
            expect(error.caption, isNotEmpty);
            expect(error.datasource, isNotEmpty);
            if (outcome == 'bulk_error') {
              expect(
                error.message,
                '22001: value too long for type character varying(5)',
              );
            }
            if (outcome == 'syntax_error') {
              expect(error.message, _lookupSyntaxError);
              expect(error.datasource, 'ds_suppliers');
            }
            if (outcome == 'lookup_error')
              expect(
                error.message,
                'Suppliers are temporarily unavailable. Please try again later.',
              );
            if (outcome == 'timeout')
              expect(error.message, 'Lookup download timed out');
          }
        }
        await tester.pumpWidget(const SizedBox());
      });
    }
  }

  testWidgets('cancelled refresh adds no messages and makes no data calls', (
    tester,
  ) async {
    final controller = _FormController();
    await tester.pumpWidget(GetMaterialApp(home: const Scaffold()));
    final refresh = controller.actionSyncAll();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel').first);
    await tester.pumpAndSettle();
    await tester.runAsync(() => refresh);
    expect(await store.list(), isEmpty);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
    'uneven form lookup totals remain dynamic and menus do not count as forms',
    (tester) async {
      final pages = [
        {
          'transid': 'inward',
          'caption': 'Inward Entry',
          'fields': [
            {..._field('supplier', 'Suppliers'), 'datasource': 'supplier'},
          ],
        },
        {
          'transid': 'outward',
          'caption': 'Outward Entry',
          'fields': [
            for (final ds in ['items', 'units', 'locations'])
              {..._field(ds, ds), 'datasource': ds},
          ],
        },
        {'transid': 'simple', 'caption': 'Simple form', 'fields': []},
        {
          'transid': 'menu',
          'caption': 'Navigation',
          'page_type': 'menu',
          'fields': [],
        },
      ];
      var calls = 0;
      ApiManager.client = MockClient((request) async {
        calls++;
        final names = (jsonDecode(request.body)['ADSNames'] as List)
            .cast<String>();
        return http.Response(
          jsonEncode({
            'result': {
              'success': true,
              'data': [
                for (final ds in names)
                  ds == 'units'
                      ? {
                          'adsname': ds,
                          'error': 'Units are temporarily unavailable.',
                        }
                      : {'adsname': ds, 'data': []},
              ],
            },
          }),
          200,
        );
      });
      await tester.pumpWidget(GetMaterialApp(home: const Scaffold()));
      final controller = _FormController();
      final refresh = http.runWithClient(
        () => controller.actionSyncAll(),
        () => MockClient(
          (request) async => http.Response(
            request.url.path.endsWith('AxValidateSession')
                ? '{"result":{"success":true}}'
                : jsonEncode(pages),
            200,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Start Sync'));
      await tester.runAsync(() => refresh);
      await tester.pumpAndSettle();
      final notification = (await store.list()).single;
      final report = notification.refreshReport!;
      expect(report.updatedForms, 3);
      expect(notification.message, startsWith('3 forms updated.'));
      expect(report.forms.map((form) => form.totalLookups), [1, 3, 0]);
      expect(report.forms.map((form) => form.updatedLookups), [1, 2, 0]);
      expect(report.forms.map((form) => form.failedLookups), [0, 1, 0]);
      expect(
        report.forms[1].lookupErrors.single.message,
        'Units are temporarily unavailable.',
      );
      expect(calls, 2);
      final progress = tester
          .widget<SyncProgressDialog>(find.byType(SyncProgressDialog))
          .progressModel;
      expect(progress.totalItems.value, 4);
      expect(progress.failureCount.value, 1);
      expect(await store.unreadCount(), 1);
      await tester.pumpWidget(const SizedBox());
    },
  );

  test(
    'refresh report persists independently from history and submission messages',
    () async {
      final report = OfflineRefreshReport([
        OfflineRefreshFormResult(
          transId: 'inward',
          caption: 'Inward Entry',
          formUpdated: true,
          lookupsCompleted: true,
          updatedLookups: 4,
          failedLookups: 1,
          lookupErrors: [
            const OfflineLookupError(
              datasource: 'supplier',
              caption: 'Suppliers',
              message: 'Try again later.',
            ),
          ],
        ),
      ]);
      final run = (await OfflineNotifications.beginUpdate())!;
      await run.notify(
        event: 'summary',
        type: 'refresh_warning',
        title: 'Refresh completed with issues',
        message: 'Readable summary',
        refreshReport: report,
      );
      report.forms.single.updatedLookups = 99;
      final read = (await OfflineNotificationStore(
        db,
        'tester',
        'project',
      ).list()).single;
      expect(read.message, 'Readable summary');
      expect(read.refreshReport!.forms.single.updatedLookups, 4);
      expect(
        read.refreshReport!.forms.single.lookupErrors.single.caption,
        'Suppliers',
      );
      await run.notify(
        event: 'legacy',
        type: 'lookup_error',
        title: 'Legacy lookup error',
        message: 'Plain legacy message',
      );
      expect((await store.list()).first.refreshReport, isNull);
      expect((await store.list()).length, 2);
      expect((await db.query('ax_audit_logs')).length, 0);
    },
  );

  testWidgets(
    'integrated refresh dialog separates categories and fits a narrow screen with expanded errors',
    (tester) async {
      tester.view.physicalSize = const Size(320, 720);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final report = OfflineRefreshReport([
        OfflineRefreshFormResult(
          transId: 'inward',
          caption: 'Inward Entry',
          formUpdated: true,
          lookupsCompleted: true,
          updatedLookups: 4,
          failedLookups: 1,
          lookupErrors: [
            const OfflineLookupError(
              datasource: 'supplier',
              caption: 'Suppliers',
              message:
                  'Suppliers are temporarily unavailable. Please try again later.',
            ),
          ],
        ),
        OfflineRefreshFormResult(
          transId: 'purchase',
          caption: 'Purchase Order',
          formError:
              'The server did not return this form. Try refreshing Purchase Order again.',
        ),
        OfflineRefreshFormResult(
          transId: 'stock',
          caption: 'Stock Transfer with a longer form caption',
          formUpdated: true,
          lookupsCompleted: true,
          failedLookups: 3,
          lookupErrors: [
            for (final name in ['Warehouses', 'Units', 'Locations'])
              OfflineLookupError(
                datasource: name,
                caption: name,
                message: name == 'Warehouses'
                    ? _lookupSyntaxError
                    : '$name could not be downloaded. Please try refreshing this form again.',
              ),
          ],
        ),
      ]);
      final run = (await OfflineNotifications.beginUpdate())!;
      await run.notify(
        event: 'summary',
        type: 'refresh_warning',
        title: 'Refresh completed with issues',
        caption: 'Refresh All',
        message: 'Refresh completed with issues',
        refreshReport: report,
      );
      final notification = (await store.list()).single;
      await tester.pumpWidget(
        GetMaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: OfflineRefreshNotificationCard(
                notification: notification,
                onTap: () => Get.dialog(
                  OfflineRefreshDetailsDialog(notification: notification),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('4/5 updated'), findsOneWidget);
      expect(find.text('Not refreshed'), findsOneWidget);
      await tester.tap(find.text('Refresh completed with issues'));
      await tester.pumpAndSettle();
      expect(find.text('Purchase Order · Download failed'), findsOneWidget);
      expect(find.text('Suppliers · Failed'), findsOneWidget);
      expect(find.text('Dropdown options and reference data.'), findsOneWidget);
      await tester.ensureVisible(find.text('View 3 lookup errors'));
      await tester.tap(find.text('View 3 lookup errors'));
      await tester.pumpAndSettle();
      expect(find.text('Warehouses · Failed'), findsOneWidget);
      expect(
        find.text('42601: syntax error at or near ";"\nPOSITION: 127'),
        findsOneWidget,
      );
      expect(find.text('Locations · Failed'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();
      await tester.pumpWidget(const SizedBox());
    },
  );

  test(
    'lookup messages preserve clear explanations and polish technical errors',
    () {
      String format(String error) => friendlyLookupFailure(
        lookup: 'Suppliers',
        form: 'Inward Entry',
        error: error,
      );
      expect(
        format('Supplier list is not available for this user.'),
        'Supplier list is not available for this user.',
      );
      expect(
        format('No lookup data returned'),
        contains('wasn’t returned by the server'),
      );
      expect(
        format('SocketException: Failed host lookup'),
        contains('internet connection'),
      );
      expect(
        format('TimeoutException: timed out'),
        contains('server took too long'),
      );
      expect(
        format('DatabaseException: SQLITE_FULL'),
        contains('saved on this device'),
      );
      expect(format('SessionId is not valid'), contains('Sign in again'));
      expect(
        format('22001: value too long for type character varying(5)'),
        isNot(contains('22001')),
      );
      expect(
        format('<html>HTTP 500 Internal error</html>'),
        isNot(contains('<html>')),
      );
      expect(
        offlineLookupCaption({
          'fields': [
            {'fld_caption': 'Supplier', 'datasource': 'ds_supplier'},
          ],
        }, 'ds_supplier'),
        'Supplier',
      );
      expect(offlineLookupCaption({}, 'ds_unknown'), 'ds_unknown');
    },
  );

  test(
    'export completion captures scope, deduplicates and uses file logs only',
    () async {
      final run = (await OfflineNotifications.beginUpdate())!;
      await run.exportResult(
        success: true,
        filePath: '/Downloads/backup.axbundle',
      );
      await run.exportResult(
        success: true,
        filePath: '/Downloads/backup.axbundle',
      );
      final saved = (await store.list()).single;
      expect(saved.type, 'export_success');
      expect(saved.message, contains('saved to Downloads'));
      expect(saved.message, contains('backup.axbundle'));
      expect(saved.caption, 'Export Offline Backup');
      expect(await db.query('ax_audit_logs'), isEmpty);
      expect(await db.query('offline_pages'), isNotEmpty);
      final shared = (await OfflineNotifications.beginUpdate())!;
      await shared.exportResult(
        success: true,
        shared: true,
        filePath: '/tmp/backup.axbundle',
      );
      expect(
        (await store.list()).first.message,
        contains('handed to the selected app'),
      );
      final unconfirmed = (await OfflineNotifications.beginUpdate())!;
      await unconfirmed.exportResult(
        success: true,
        shared: true,
        confirmed: false,
      );
      expect((await store.list()).first.type, 'export_warning');
      final failure = (await OfflineNotifications.beginUpdate())!;
      await failure.exportResult(
        success: false,
        error: 'DB-only upload is not available',
      );
      expect((await store.list()).first.type, 'export_error');
      expect(
        (await store.list()).first.message,
        contains('Choose Full Backup'),
      );
    },
  );

  test(
    'inactive DB-only upload cannot falsely report successful export',
    () async {
      await expectLater(
        OfflineBundleService.uploadDBFile(),
        throwsUnsupportedError,
      );
      expect(await store.list(), isEmpty);
    },
  );

  testWidgets(
    'update card opens details without entering record correction mode',
    (tester) async {
      final run = (await OfflineNotifications.beginUpdate())!;
      await run.notify(
        event: 'lookup',
        type: 'lookup_error',
        title: 'Suppliers could not be updated',
        caption: 'Inward Entry · Lookup data',
        transId: 'inward',
        message:
            'The server took too long to respond. Please try refreshing again.',
      );
      final controller = Get.put<OfflineFormController>(_FormController());
      await tester.pumpWidget(
        GetMaterialApp(
          home: OfflineNotificationsPage(formController: controller),
        ),
      );
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 80));
      });
      await tester.pumpAndSettle();
      expect(find.text('Inward Entry · Lookup data'), findsOneWidget);
      expect(find.text('Offline submission'), findsNothing);
      await tester.tap(find.text('Suppliers could not be updated'));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(controller.editingRecordId, isNull);
      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();
      await tester.pumpWidget(const SizedBox());
    },
  );
}
