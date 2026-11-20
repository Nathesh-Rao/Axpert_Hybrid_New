import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

/// Remote diagnostics only. Reporting failures never interrupt application work.
class CrashReportingService {
  static const _supportIdKey = 'crashlytics_support_id';
  static const _testReports = bool.fromEnvironment('CRASHLYTICS_TEST_REPORT');
  static String? supportId;
  static bool _ready = false;

  static void installErrorHandlers() {
    FlutterError.onError = (details) {
      FlutterError.presentError(details);
      unawaited(
        record(
          details.exception,
          details.stack ?? StackTrace.current,
          reason: 'flutter_framework_error',
          fatal: true,
        ),
      );
    };
    PlatformDispatcher.instance.onError = (error, stack) {
      unawaited(
        record(error, stack, reason: 'uncaught_isolate_error', fatal: true),
      );
      return true;
    };
  }

  static Future<void> initializeBackground() async {
    try {
      await Firebase.initializeApp().timeout(const Duration(seconds: 5));
      await initialize();
      installErrorHandlers();
      await identifyInstallation();
    } catch (error) {
      debugPrint('Background crash reporting initialization failed: $error');
    }
  }

  static Future<void> initialize() async {
    try {
      await FirebaseCrashlytics.instance
          .setCrashlyticsCollectionEnabled(kReleaseMode || _testReports)
          .timeout(const Duration(seconds: 5));
      _ready = true;
    } catch (error) {
      debugPrint('Crash reporting initialization failed: $error');
    }
  }

  static Future<void> identifyInstallation() async {
    try {
      final preferences = await SharedPreferences.getInstance();
      var id = preferences.getString(_supportIdKey);
      if (id == null || id.isEmpty) {
        id = const Uuid().v4();
        await preferences.setString(_supportIdKey, id);
      }
      supportId = id;
      if (_ready) {
        await FirebaseCrashlytics.instance
            .setCustomKey('support_id', id)
            .timeout(const Duration(seconds: 3));
        await FirebaseCrashlytics.instance
            .setUserIdentifier(id)
            .timeout(const Duration(seconds: 3));
      }
    } catch (error, stack) {
      await record(error, stack, reason: 'support_id_initialization');
    }
  }

  static Future<void> record(
    Object error,
    StackTrace stack, {
    required String reason,
    bool fatal = false,
  }) async {
    if (!_ready) {
      debugPrint(
        'Error before crash reporting was ready ($reason): $error\n$stack',
      );
      return;
    }
    try {
      await FirebaseCrashlytics.instance
          .recordError(error, stack, reason: reason, fatal: fatal)
          .timeout(const Duration(seconds: 5));
    } catch (reportError) {
      debugPrint('Unable to record crash report: $reportError');
    }
  }

  /// Observe slow startup without cancelling or retrying the underlying work.
  /// Permission dialogs deliberately have no elapsed-time warning.
  static Future<T> startupStep<T>(
    String name,
    Future<T> Function() action, {
    bool watchDelay = true,
  }) async {
    await _stage(name);
    final started = Stopwatch()..start();
    final timer = watchDelay
        ? Timer(const Duration(seconds: 60), () {
            unawaited(
              record(
                StateError('Startup step exceeded 60 seconds'),
                StackTrace.current,
                reason: 'startup_delay:$name',
              ),
            );
          })
        : null;
    try {
      return await action();
    } finally {
      timer?.cancel();
      if (_ready) {
        try {
          await FirebaseCrashlytics.instance
              .log('$name finished after ${started.elapsedMilliseconds}ms')
              .timeout(const Duration(seconds: 3));
        } catch (_) {
          // SDK diagnostics must not replace the original operation result.
        }
      }
    }
  }

  static Future<void> _stage(String name) async {
    if (!_ready) return;
    try {
      await FirebaseCrashlytics.instance
          .setCustomKey('startup_stage', name)
          .timeout(const Duration(seconds: 3));
      await FirebaseCrashlytics.instance
          .log('Startup: $name')
          .timeout(const Duration(seconds: 3));
    } catch (_) {
      // Preserve startup even when diagnostics are unavailable.
    }
  }

  static Future<void> recordScreen(String route) async {
    if (!_ready) return;
    final screen = route.split('?').first;
    try {
      await FirebaseCrashlytics.instance
          .setCustomKey('screen', screen)
          .timeout(const Duration(seconds: 3));
      await FirebaseCrashlytics.instance
          .log('Screen: $screen')
          .timeout(const Duration(seconds: 3));
    } catch (_) {
      // Navigation does not depend on diagnostics.
    }
  }

  static Future<void> startupComplete() async {
    await _stage('ready');
    if (_testReports) {
      await record(
        StateError('Crashlytics integration verification'),
        StackTrace.current,
        reason: 'integration_test',
      );
    }
  }
}
