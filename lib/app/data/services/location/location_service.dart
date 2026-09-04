// lib/app/data/services/location/location_service.dart
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'location_task_handler.dart';
import 'location_track_processor.dart';

class LocationService {
  static StreamSubscription<Position>? _iosPositionSub;

  /// Call once, early in main(), before runApp().
  static Future<void> initForegroundTask() async {
    if (!Platform.isAndroid) return;

    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'axpert_location_tracking',
        channelName: 'Location Tracking',
        channelDescription: 'Used to track location in the background.',
      ),
      iosNotificationOptions: const IOSNotificationOptions(
        showNotification: false,
      ),
      foregroundTaskOptions: ForegroundTaskOptions(
        eventAction: ForegroundTaskEventAction.repeat(15000), // tick every 15s; actual API calls gated by per-identifier interval
        autoRunOnBoot: true,
        allowWakeLock: true,
        allowWifiLock: true,
      ),
    );
  }

  static Future startLocationTracking() async {
    if (Platform.isAndroid) {
      final hasPermission = await FlutterForegroundTask.checkNotificationPermission();
      if (hasPermission != NotificationPermission.granted) {
        await FlutterForegroundTask.requestNotificationPermission();
      }
      final isRunning = await FlutterForegroundTask.isRunningService;
      if (!isRunning) {
        await FlutterForegroundTask.startService(
          serviceId: 256,
          notificationTitle: 'Axpert',
          notificationText: 'Tracking location in background',
          callback: startLocationCallback,
        );
      }
    } else if (Platform.isIOS) {
      if (_iosPositionSub != null) return; // already tracking

      _iosPositionSub = Geolocator.getPositionStream(
        locationSettings: AppleSettings(
          accuracy: LocationAccuracy.high,
          activityType: ActivityType.other,
          distanceFilter: 20,
          pauseLocationUpdatesAutomatically: false,
          showBackgroundLocationIndicator: true,
          allowBackgroundLocationUpdates: true,
        ),
      ).listen((position) async {
        await processTrackedIdentifiers(position);
      });
    }
  }

  static Future stopLocationTracking(String identifier) async {
    final pref = await SharedPreferences.getInstance();
    await pref.reload();
    String val = pref.getString("outerData") ?? "{}";
    Map outerData;
    try {
      outerData = jsonDecode(val);
    } catch (_) {
      outerData = {};
    }

    if (outerData.containsKey(identifier)) outerData.remove(identifier);

    if (outerData.isEmpty || identifier.toUpperCase() == "ALL") {
      if (Platform.isAndroid) {
        if (await FlutterForegroundTask.isRunningService) {
          await FlutterForegroundTask.stopService();
        }
      } else {
        await _iosPositionSub?.cancel();
        _iosPositionSub = null;
      }
      await pref.remove("outerData");
    } else {
      await pref.setString("outerData", jsonEncode(outerData));
    }
  }

  // --- unchanged from your current file ---
  static Future<Position> determineCurrentLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      // handled by LocationPermissionGate before this is ever reached
    }
    LocationPermission permission = await Geolocator.checkPermission();
    permission = await Geolocator.requestPermission();
    if (permission == LocationPermission.denied) {
      return Future.error('Location permissions are denied');
    }
    if (permission == LocationPermission.deniedForever) {
      return Future.error('Location permissions are permanently denied, we cannot request permissions.');
    }
    return await Geolocator.getCurrentPosition();
  }

  static Future<Map<dynamic, dynamic>> getAddress({
    required double lat,
    required double lon,
  }) async {
    List<Placemark> placemarks = await placemarkFromCoordinates(lat, lon);
    if (placemarks.isNotEmpty) {
      Placemark data = placemarks.first;
      final address = "${data.subLocality}, ${data.locality}, ${data.administrativeArea}";
      if (kDebugMode) print(data.toString());
      return {"hasError": false, "data": address};
    }
    return {"hasError": false, "eMsg": "No data available"};
  }
}