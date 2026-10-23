import 'dart:convert';
import 'package:axpert/app/data/services/storage/storage_service.dart';
import 'package:axpert/app/modules/offline_form_pages/controller/offline_form_controller.dart';
import 'package:axpert/app/modules/offline_form_pages/db/offline_db_module.dart';
import 'package:axpert/app/modules/offline_form_pages/models/models.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:axpert/app/data/services/api/api_manger.dart';
import 'package:axpert/app/data/services/connectivity/internet_connectivity.dart';
import 'package:axpert/app/modules/offline_form_pages/widgets/sync_progress_dialog.dart';
import 'package:google_fonts/google_fonts.dart';

class _OnlineConnectivity extends InternetConnectivity {
  @override
  // Match the existing connectivity service API.
  // ignore: non_constant_identifier_names
  Future<void> connectivity_listen() async {}
  @override
  Future<bool> get connectionStatus async => true;
  @override
  Future<bool> check() async => true;
}

class _RefreshController extends OfflineFormController {
  final calls = <String?>[];
  @override
  Future<void> actionSyncAll({String? transId, String? caption}) async {
    calls.add(transId);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final datasourceIds = <String>[];
  final batches = <Map>[];
  var storedPassword = '';
  var lookupNames = '';
  var formIds = ['form-a', 'form-b'];
  late http.Client originalClient;
  const channel = MethodChannel('com.tekartik.sqflite');

  setUpAll(() async {
    originalClient = ApiManager.client;
    databaseFactory = databaseFactorySqflitePlugin;
    SharedPreferences.setMockInitialValues({'web_url': 'https://example.com'});
    await StorageService.init();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          final args = call.arguments is Map
              ? call.arguments as Map
              : <dynamic, dynamic>{};
          switch (call.method) {
            case 'getDatabasesPath':
              return '/test-offline';
            case 'openDatabase':
              return {'id': 71};
            case 'query':
              final sql = args['sql'] as String;
              if (sql.contains('user_version')) {
                return [
                  {'user_version': 12},
                ];
              }
              if (sql.contains('FROM offline_user')) {
                return [
                  {
                    'username': 'tester',
                    'project_name': 'project',
                    'password_hash': storedPassword,
                  },
                ];
              }
              if (sql.contains('FROM offline_pages')) {
                return formIds
                    .map(
                      (id) => {
                        'page_json': jsonEncode({'transid': id}),
                      },
                    )
                    .toList();
              }
              if (sql.contains('FROM offline_datasources')) {
                datasourceIds.add((args['arguments'] as List).last as String);
                if (lookupNames.isNotEmpty) {
                  return [
                    {'datasource_names': lookupNames},
                  ];
                }
              }
              return [];
            case 'execute':
              return null;
            case 'batch':
              batches.add(Map.from(args));
              return [];
            case 'delete':
            case 'update':
              return 0;
            case 'insert':
              return 1;
            default:
              throw StateError('Unexpected database call: ${call.method}');
          }
        });
    await OfflineDbModule.init();
  });

  setUp(() async {
    Get.testMode = true;
    datasourceIds.clear();
    batches.clear();
    storedPassword = '';
    lookupNames = '';
    formIds = ['form-a', 'form-b'];
    await StorageService.setString('arm_session_id', 'existing-session');
  });
  tearDown(() {
    if (ApiManager.client != originalClient) ApiManager.client.close();
    ApiManager.client = originalClient;
    Get.reset();
  });
  tearDownAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('omitting form ID visits every downloaded form', () async {
    await OfflineDbModule.refreshAllDatasourcesFromDownloadedPages(
      isrefetching: true,
    );
    expect(datasourceIds, ['form-a', 'form-b']);
  });

  test('selected form refresh visits only its datasources', () async {
    await OfflineDbModule.refreshAllDatasourcesFromDownloadedPages(
      transId: 'form-b',
      isrefetching: true,
    );
    expect(datasourceIds, ['form-b']);
  });

  for (final selected in <String?>[null, 'form-b']) {
    for (final partial in [false, true]) {
      test(
        '${selected ?? "all"} counts ${partial ? "partial" : "session"} lookup failures',
        () async {
          lookupNames = 'ds_one,ds_two';
          Get.put<InternetConnectivity>(_OnlineConnectivity());
          ApiManager.client = MockClient(
            (_) async => http.Response(
              jsonEncode({
                'result': partial
                    ? {
                        'success': true,
                        'data': [
                          {'adsname': 'ds_one', 'data': []},
                        ],
                      }
                    : {'success': false, 'message': 'SessionId is not valid'},
              }),
              partial ? 200 : 400,
            ),
          );
          final progress = SyncProgressModel();
          final operations = SyncProgressModel();
          await OfflineDbModule.refreshAllDatasourcesFromDownloadedPages(
            transId: selected,
            isrefetching: true,
            progressModel: progress,
            operationProgress: operations,
          );
          final formCount = selected == null ? 2 : 1;
          expect(progress.successCount.value, partial ? formCount : 0);
          expect(
            progress.failureCount.value,
            partial ? formCount : formCount * 2,
          );
          expect(progress.syncErrors.length, progress.failureCount.value);
          expect(operations.totalItems.value, formCount);
          expect(operations.failureCount.value, formCount);
          expect(operations.successCount.value, 0);
        },
      );
    }
  }

  test('valid empty lookup results count as successes', () async {
    lookupNames = 'ds_one,ds_two';
    Get.put<InternetConnectivity>(_OnlineConnectivity());
    ApiManager.client = MockClient(
      (_) async => http.Response(
        jsonEncode({
          'result': {
            'success': true,
            'data': [
              {'adsname': 'ds_one', 'data': []},
              {'adsname': 'ds_two', 'data': []},
            ],
          },
        }),
        200,
      ),
    );
    final progress = SyncProgressModel();
    final operations = SyncProgressModel();
    await OfflineDbModule.refreshAllDatasourcesFromDownloadedPages(
      transId: 'form-b',
      isrefetching: true,
      progressModel: progress,
      operationProgress: operations,
    );
    expect(progress.successCount.value, 2);
    expect(progress.failureCount.value, 0);
    expect(operations.totalItems.value, 1);
    expect(operations.successCount.value, 1);
    expect(operations.failureCount.value, 0);
  });

  testWidgets('completed refresh displays its failure count', (tester) async {
    GoogleFonts.config.allowRuntimeFetching = false;
    final progress = SyncProgressModel();
    progress.init(total: 3);
    progress.increment();
    progress.increment(isSuccess: false);
    progress.increment(isSuccess: false);
    progress.completeWithError(
      errorMsg: 'Two lookups failed',
      statuscode: 'REFRESH_INCOMPLETE',
    );
    await tester.pumpWidget(
      GetMaterialApp(
        home: Scaffold(body: SyncProgressDialog(progressModel: progress)),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Failed'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
    expect(find.text('Two lookups failed'), findsOneWidget);
  });

  for (final config in <(String?, int, bool)>[
    (null, 2, true),
    (null, 4, true),
    ('form-b', 2, true),
    (null, 4, false),
    ('form-b', 2, false),
  ]) {
    final (selected, formCount, hasLookups) = config;
    testWidgets(
      '${selected ?? "all"} counts operations dynamically for $formCount forms, lookups=$hasLookups',
      (tester) async {
        GoogleFonts.config.allowRuntimeFetching = false;
        lookupNames = hasLookups ? 'ds_one,ds_two' : '';
        formIds = [
          'form-a',
          'form-b',
          if (formCount == 4) ...['form-c', 'form-d'],
        ];
        Get.put<InternetConnectivity>(_OnlineConnectivity());
        ApiManager.client = MockClient(
          (_) async => http.Response(
            '{"result":{"success":false,"message":"SessionId is not valid"}}',
            400,
          ),
        );
        final controller = OfflineFormController();
        await tester.pumpWidget(
          GetMaterialApp(home: const Scaffold(body: SizedBox())),
        );
        final refresh = http.runWithClient(
          () => controller.actionSyncAll(transId: selected, caption: 'Form B'),
          () => MockClient((request) async {
            if (request.url.path.endsWith('AxValidateSession')) {
              return http.Response('{"result":{"success":true}}', 200);
            }
            return http.Response(
              jsonEncode(
                formIds.map((id) => {'transid': id, 'fields': []}).toList(),
              ),
              200,
            );
          }),
        );
        await tester.pumpAndSettle();
        await tester.tap(
          find.text(selected == null ? 'Start Sync' : 'Refresh'),
        );
        await tester.runAsync(() => refresh);
        await tester.pumpAndSettle();
        final progress = tester
            .widget<SyncProgressDialog>(find.byType(SyncProgressDialog))
            .progressModel;
        final base = selected == null ? 2 : 1;
        final lookupCalls = hasLookups ? (selected == null ? formCount : 1) : 0;
        expect(progress.totalItems.value, base + lookupCalls);
        expect(progress.successCount.value, base);
        expect(progress.failureCount.value, lookupCalls);
        expect(progress.isCompletedWithError.value, hasLookups);
        await tester.pumpWidget(const SizedBox());
      },
    );
  }

  test('session preflight keeps a valid session without signing in', () async {
    final requests = <String>[];
    final valid = await http.runWithClient(
      OfflineDbModule.ensureValidSession,
      () => MockClient((request) async {
        requests.add(request.url.path);
        return http.Response('{"result":{"success":true}}', 200);
      }),
    );
    expect(valid, isTrue);
    expect(requests, ['AxAuth/api/v1/AxValidateSession']);
    expect(StorageService.sessionId, 'existing-session');
    expect(batches, isEmpty);
  });

  test('expired session renews using the existing login function', () async {
    storedPassword = 'test-password';
    final requests = <String>[];
    final valid = await http.runWithClient(
      OfflineDbModule.ensureValidSession,
      () => MockClient((request) async {
        requests.add(request.url.path);
        if (request.url.path.endsWith('AxValidateSession')) {
          return http.Response(
            '{"result":{"success":false,"message":"SessionId is not valid"}}',
            400,
          );
        }
        return http.Response(
          jsonEncode({
            'result': {
              'success': true,
              'message': 'Login Successful.',
              'token': 'renewed-token',
              'ARMSessionId': 'renewed-session',
            },
          }),
          200,
        );
      }),
    );
    expect(valid, isTrue);
    expect(requests, [
      'AxAuth/api/v1/AxValidateSession',
      'AxAuth/api/v1/Signin',
    ]);
    expect(StorageService.sessionId, 'renewed-session');
    expect(batches, isEmpty);
  });

  test(
    'unrenewable session is rejected without changing the form cache',
    () async {
      final valid = await http.runWithClient(
        OfflineDbModule.ensureValidSession,
        () => MockClient(
          (_) async => http.Response('{"result":{"success":false}}', 400),
        ),
      );
      expect(valid, isFalse);
      expect(batches, isEmpty);
      expect(StorageService.sessionId, 'existing-session');
    },
  );

  for (final selected in <String?>[null, 'form-b']) {
    test(
      'form cache replacement is scoped to ${selected ?? "all forms"}',
      () async {
        final pages = await http.runWithClient(
          () => OfflineDbModule.fetchAndStoreOfflinePages(transId: selected),
          () => MockClient(
            (_) async => http.Response(
              jsonEncode([
                {'transid': 'form-a', 'fields': []},
                {'transid': 'form-b', 'fields': []},
              ]),
              200,
            ),
          ),
        );
        expect(
          pages.map((page) => page['transid']),
          selected == null ? ['form-a', 'form-b'] : ['form-b'],
        );
        final deletes = (batches.first['operations'] as List).cast<Map>();
        expect(deletes.length, 2);
        for (final operation in deletes) {
          expect(
            operation['arguments'],
            selected == null
                ? ['tester', 'project']
                : ['tester', 'project', selected],
          );
          expect(
            operation['sql'],
            selected == null
                ? isNot(contains('trans_id = ?'))
                : contains('trans_id = ?'),
          );
        }
        expect(
          (batches.last['operations'] as List).length,
          selected == null ? 2 : 1,
        );
      },
    );
  }

  test('missing selected form retains existing cache', () async {
    final pages = await http.runWithClient(
      () => OfflineDbModule.fetchAndStoreOfflinePages(transId: 'missing'),
      () =>
          MockClient((_) async => http.Response('[{"transid":"form-a"}]', 200)),
    );
    expect(pages, isEmpty);
    expect(batches, isEmpty);
  });

  for (final selection in ['Refresh All', 'Expense Claim']) {
    testWidgets(
      '$selection routes to the existing action with the correct ID',
      (tester) async {
        final controller = _RefreshController();
        controller.allPages.add(
          OfflineFormPageModel.fromJson({
            'transid': 'expense',
            'caption': 'Expense Claim',
          }),
        );
        await tester.pumpWidget(
          GetMaterialApp(
            home: Scaffold(
              body: TextButton(
                onPressed: controller.actionRefresh,
                child: const Text('Refresh'),
              ),
            ),
          ),
        );
        await tester.tap(find.text('Refresh'));
        await tester.pumpAndSettle();
        await tester.tap(find.text(selection));
        await tester.pumpAndSettle();
        expect(controller.calls, [
          selection == 'Refresh All' ? null : 'expense',
        ]);
      },
    );
  }
}
