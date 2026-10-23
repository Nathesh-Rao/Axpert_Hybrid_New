import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:axpert/app/widgets/connection_style.dart';
import 'package:axpert/app/widgets/project_logo.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _Headers implements HttpHeaders {
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _Request implements HttpClientRequest {
  _Request(this.response);
  final Future<HttpClientResponse> response;
  @override
  HttpHeaders get headers => _Headers();
  @override
  Future<HttpClientResponse> close() => response;
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _Response extends Stream<List<int>> implements HttpClientResponse {
  _Response(this.bytes, {this.statusCode = 200});
  final Uint8List bytes;
  @override
  final int statusCode;
  @override
  int get contentLength => bytes.length;
  @override
  HttpClientResponseCompressionState get compressionState =>
      HttpClientResponseCompressionState.notCompressed;
  @override
  StreamSubscription<List<int>> listen(
    void Function(List<int>)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) => Stream<List<int>>.value(bytes).listen(
    onData,
    onError: onError,
    onDone: onDone,
    cancelOnError: cancelOnError,
  );
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _Client implements HttpClient {
  _Client(this.responses);
  final Map<String, Future<HttpClientResponse>> responses;
  @override
  Future<HttpClientRequest> getUrl(Uri url) async =>
      _Request(responses[url.path]!);
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

Future<Uint8List> _png(
  int width,
  int height,
  Color ink, {
  bool transparent = false,
}) async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  if (!transparent) {
    canvas.drawRect(
      Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
      Paint()..color = Colors.white,
    );
  }
  canvas.drawRect(
    Rect.fromLTWH(width * .2, height * .2, width * .6, height * .6),
    Paint()..color = ink,
  );
  final picture = recorder.endRecording();
  final image = await picture.toImage(width, height);
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  picture.dispose();
  return data!.buffer.asUint8List();
}

Widget _host(
  String path, {
  double size = 84,
  bool? darkPlate,
  String project = 'Example',
}) => MaterialApp(
  home: Scaffold(
    body: Center(
      child: ProjectLogo(
        url: path.isEmpty ? '' : 'https://logos.test/$path',
        projectName: project,
        size: size,
        darkPlate: darkPlate,
      ),
    ),
  ),
);
Future<void> _decode(WidgetTester tester) async {
  for (var i = 0; i < 8; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 25)),
    );
    await tester.pump(const Duration(milliseconds: 50));
  }
  await tester.pumpAndSettle();
}

Color _plate(WidgetTester tester) {
  final containers = tester.widgetList<Container>(
    find.descendant(
      of: find.byType(ProjectLogo),
      matching: find.byType(Container),
    ),
  );
  return (containers
              .firstWhere(
                (c) =>
                    c.constraints?.maxWidth ==
                    tester.widget<ProjectLogo>(find.byType(ProjectLogo)).size,
              )
              .decoration
          as BoxDecoration)
      .color!;
}

void main() {
  tearDown(() {
    debugNetworkImageHttpClientProvider = null;
    PaintingBinding.instance.imageCache.clear();
    PaintingBinding.instance.imageCache.clearLiveImages();
  });
  for (final shape in [(100, 100), (70, 110), (400, 50)]) {
    testWidgets(
      'logo ${shape.$1}x${shape.$2} fits without clipping or distortion',
      (tester) async {
        final bytes = (await tester.runAsync(
          () => _png(shape.$1, shape.$2, Colors.black),
        ))!;
        debugNetworkImageHttpClientProvider = () =>
            _Client({'/shape': Future.value(_Response(bytes))});
        await tester.pumpWidget(_host('shape'));
        await _decode(tester);
        final logo = tester.widget<Image>(
          find
              .descendant(
                of: find.byType(ProjectLogo),
                matching: find.byType(Image),
              )
              .first,
        );
        expect(logo.width! / logo.height!, closeTo(shape.$1 / shape.$2, .001));
        expect(
          logo.width! * logo.width! + logo.height! * logo.height!,
          closeTo(82.32 * 82.32, .01),
        );
        expect(logo.fit, BoxFit.contain);
        expect(
          find.descendant(
            of: find.byType(ProjectLogo),
            matching: find.byType(ClipOval),
          ),
          findsNothing,
        );
        expect(_plate(tester), Colors.white);
        expect(tester.getSize(find.byType(ProjectLogo)), const Size(84, 84));
        expect(tester.takeException(), isNull);
        debugNetworkImageHttpClientProvider = null;
      },
    );
  }
  testWidgets(
    'white transparent logo uses dark plate; opaque white background stays white; overrides work',
    (tester) async {
      final transparent = (await tester.runAsync(
        () => _png(100, 100, Colors.white, transparent: true),
      ))!;
      final opaque = (await tester.runAsync(
        () => _png(100, 100, Colors.white),
      ))!;
      debugNetworkImageHttpClientProvider = () => _Client({
        '/transparent': Future.value(_Response(transparent)),
        '/opaque': Future.value(_Response(opaque)),
      });
      await tester.pumpWidget(_host('transparent'));
      await _decode(tester);
      expect(_plate(tester), isNot(Colors.white));
      await tester.pumpWidget(_host('opaque'));
      await _decode(tester);
      expect(_plate(tester), Colors.white);
      await tester.pumpWidget(_host('opaque', darkPlate: true));
      await tester.pumpAndSettle();
      expect(_plate(tester), isNot(Colors.white));
      await tester.pumpWidget(_host('transparent', darkPlate: false));
      await _decode(tester);
      expect(_plate(tester), Colors.white);
      expect(tester.takeException(), isNull);
      debugNetworkImageHttpClientProvider = null;
    },
  );
  testWidgets('loading placeholder, failed URL and empty URL fallback', (
    tester,
  ) async {
    final pending = Completer<HttpClientResponse>();
    debugNetworkImageHttpClientProvider = () =>
        _Client({'/pending': pending.future});
    await tester.pumpWidget(_host('pending'));
    expect(find.byKey(const ValueKey('loading')), findsOneWidget);
    pending.complete(_Response(Uint8List(0), statusCode: 404));
    await _decode(tester);
    expect(find.byType(ConnectionMark), findsOneWidget);
    await tester.pumpWidget(_host(''));
    await tester.pumpAndSettle();
    expect(find.byType(ConnectionMark), findsOneWidget);
    expect(tester.takeException(), isNull);
    debugNetworkImageHttpClientProvider = null;
  });
  testWidgets(
    'switching project replaces pending logo and list-sized badge scales proportionally',
    (tester) async {
      final pending = Completer<HttpClientResponse>();
      final wide = (await tester.runAsync(() => _png(400, 50, Colors.blue)))!;
      final square = (await tester.runAsync(
        () => _png(100, 100, Colors.black),
      ))!;
      debugNetworkImageHttpClientProvider = () => _Client({
        '/old': pending.future,
        '/new': Future.value(_Response(wide)),
      });
      await tester.pumpWidget(_host('old'));
      await tester.pumpWidget(_host('new', size: 42, project: 'New'));
      await _decode(tester);
      pending.complete(_Response(square));
      await _decode(tester);
      final logo = tester.widget<Image>(
        find
            .descendant(
              of: find.byType(ProjectLogo),
              matching: find.byType(Image),
            )
            .first,
      );
      expect(logo.width! / logo.height!, closeTo(8, .001));
      expect(
        logo.width! * logo.width! + logo.height! * logo.height!,
        closeTo(41.16 * 41.16, .01),
      );
      await tester.pumpWidget(_host('new', size: 42, project: 'Other project'));
      await _decode(tester);
      expect(
        tester.getSemantics(find.byType(ProjectLogo)).label,
        contains('Other project logo'),
      );
      expect(tester.takeException(), isNull);
      debugNetworkImageHttpClientProvider = null;
    },
  );
}
