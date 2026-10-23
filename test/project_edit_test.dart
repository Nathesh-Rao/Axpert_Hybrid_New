import 'package:axpert/app/data/enums/project_enums.dart';
import 'package:axpert/app/data/models/project_model.dart';
import 'package:axpert/app/db/project_database.dart';
import 'package:axpert/app/modules/project/controller/project_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:sqflite/sqflite.dart';

class _EditController extends ProjectController {
  @override
  Future<void> fetchProjects() async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('com.tekartik.sqflite');
  final queries = <Map<dynamic, dynamic>>[];

  setUp(() {
    Get.testMode = true;
    GoogleFonts.config.allowRuntimeFetching = false;
    queries.clear();
    databaseFactory = databaseFactorySqflitePlugin;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          switch (call.method) {
            case 'getDatabasesPath':
              return '/test';
            case 'openDatabase':
              return {'id': 1};
            case 'query':
              final args = call.arguments as Map;
              final sql = args['sql'] as String;
              if (sql.contains('user_version')) {
                return [{'user_version': 4}];
              }
              queries.add(Map<dynamic, dynamic>.from(args));
              // A different project owns the requested caption.
              return sql.contains('caption = ?') ? [{'id': 2}] : [];
            case 'execute':
            case 'closeDatabase':
              return null;
            default:
              throw StateError('Unexpected database call: ${call.method}');
          }
        });
  });

  tearDown(() async {
    await ProjectDatabase.instance.close();
    Get.reset();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  testWidgets('new project rejects an existing caption and retains inputs', (tester) async {
    await tester.pumpWidget(
      ScreenUtilInit(builder: (_, _) => const MaterialApp(home: SizedBox())),
    );
    final controller = Get.put<ProjectController>(_EditController());
    final formKey = GlobalKey<FormState>();
    await tester.pumpWidget(GetMaterialApp(
      home: Scaffold(body: Form(key: formKey, child: const SizedBox())),
    ));
    controller.onAddManuallyClick();
    controller.webUrlCtrl.text = 'https://example.com/new-project';
    controller.armUrlCtrl.text = 'https://example.com/arm';
    controller.connectionNameCtrl.text = 'new-project';
    controller.connectionCaptionCtrl.text = '  Taken caption  ';

    controller.onSaveUrlDetails(formKey);
    await tester.pumpAndSettle();

    expect(queries.length, 2);
    expect(queries[0]['sql'], isNot(contains('id != ?')));
    expect(queries[1]['sql'], isNot(contains('id != ?')));
    expect(queries[1]['arguments'], ['Taken caption']);
    expect(controller.editingProject.value, isNull);
    expect(controller.currentTileState.value, ProjectAddingState.urlDetails);
    expect(controller.connectionCaptionCtrl.text, '  Taken caption  ');
    expect(controller.webUrlCtrl.text, 'https://example.com/new-project');
    expect(controller.isProjectSaving.value, isFalse);
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
  });

  test('database add rejects an existing caption before inserting', () async {
    final result = await ProjectDatabase.instance.add(const ProjectModel(
      url: 'https://example.com/new-project',
      armurl: 'https://example.com/arm',
      schemaName: 'new-project',
      caption: '  Taken caption  ',
    ));

    expect(result, isA<DbError<ProjectModel>>());
    expect((result as DbError<ProjectModel>).message,
        'This caption is already used by another project.');
    expect(queries.length, 2);
    expect(queries[1]['arguments'], ['Taken caption']);
    expect(queries[1]['sql'], isNot(contains('id != ?')));
  });

  testWidgets('editing preserves URLs and caption', (tester) async {
    await tester.pumpWidget(
      ScreenUtilInit(builder: (_, _) => const MaterialApp(home: SizedBox())),
    );
    final controller = Get.put<ProjectController>(_EditController());
    const project = ProjectModel(
      id: 1,
      url: 'https://example.com/project',
      armurl: 'http://example.com/arm',
      schemaName: 'project',
      caption: 'Original caption',
    );

    controller.onEditProjectClick(project);

    expect(controller.webUrlCtrl.text, project.url);
    expect(controller.armUrlCtrl.text, project.armurl);
    expect(controller.connectionCaptionCtrl.text, project.caption);
    expect(controller.currentTileState.value, ProjectAddingState.urlEdit);
    await tester.pumpAndSettle();
  });

  testWidgets('duplicate checks exclude edited ID and retain entered values', (
    tester,
  ) async {
    await tester.pumpWidget(
      ScreenUtilInit(builder: (_, _) => const MaterialApp(home: SizedBox())),
    );
    final controller = Get.put<ProjectController>(_EditController());
    final formKey = GlobalKey<FormState>();
    await tester.pumpWidget(
      GetMaterialApp(
        home: Scaffold(body: Form(key: formKey, child: const SizedBox())),
      ),
    );
    const project = ProjectModel(
      id: 1,
      url: 'https://example.com/project',
      armurl: 'https://example.com/arm',
      schemaName: 'project',
      caption: 'Original caption',
    );
    controller.onEditProjectClick(project);
    controller.connectionCaptionCtrl.text = 'Taken caption';

    controller.onSaveUrlDetails(formKey);
    await tester.pumpAndSettle();

    expect(queries.length, 2);
    expect(queries[0]['sql'], contains('id != ?'));
    expect(queries[0]['arguments'], [project.url, project.armurl, 'project', 1]);
    expect(queries[1]['arguments'], ['Taken caption', 1]);
    expect(controller.editingProject.value?.id, 1);
    expect(controller.currentTileState.value, ProjectAddingState.urlEdit);
    expect(controller.connectionCaptionCtrl.text, 'Taken caption');
    expect(controller.webUrlCtrl.text, project.url);
    expect(controller.isProjectSaving.value, isFalse);
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
  });
}
