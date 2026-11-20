import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:geolocator/geolocator.dart';
import 'location_track_processor.dart';
import '../log/crash_reporting_service.dart';

@pragma('vm:entry-point')
void startLocationCallback() {
  FlutterForegroundTask.setTaskHandler(LocationTaskHandler());
}

class LocationTaskHandler extends TaskHandler {
  @override
  Future<void> onStart(DateTime timestamp, dynamic starter) async {
    await CrashReportingService.initializeBackground();
  }

  @override
  Future<void> onRepeatEvent(DateTime timestamp, [dynamic sendPort]) async {
    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
      await processTrackedIdentifiers(position);
    } catch (error, stack) {
      await CrashReportingService.record(
        error,
        stack,
        reason: 'location_tracking',
      );
    }
  }

  @override
  void onNotificationButtonPressed(String id) {}

  @override
  void onNotificationPressed() {
    FlutterForegroundTask.launchApp();
  }

  @override
  Future<void> onDestroy(DateTime timestamp, [dynamic sendPort]) async {}
}
