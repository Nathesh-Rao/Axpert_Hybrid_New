import 'dart:convert';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';

/// Reads the outerData map from prefs, checks each tracked identifier's
/// interval against its lastApiCall, and posts location for any that are due.
/// Called from both the Android background isolate (TaskHandler) and the
/// iOS foreground position-stream listener.
Future<void> processTrackedIdentifiers(Position position) async {
  final pref = await SharedPreferences.getInstance();
  await pref.reload();
  final outerDataStr = pref.getString("outerData") ?? "{}";

  Map outerMap;
  try {
    outerMap = jsonDecode(outerDataStr);
  } catch (_) {
    return;
  }

  for (final key in outerMap.keys.toList()) {
    final Map inner = outerMap[key];
    final interval = (inner['interval'] ?? "0").toString();
    final lastData = (inner['lastData'] ?? "").toString();
    final lastApiCall = (inner['lastApiCall'] ?? "0").toString();

    if (lastData.isEmpty || interval == "0") continue;

    bool shouldCall = false;
    if (lastApiCall == "0") {
      shouldCall = true;
    } else {
      try {
        final dt = DateFormat("dd-MM-yyyy HH:mm:ss").parse(lastApiCall);
        final diff = DateTime.now().difference(dt).inMinutes;
        shouldCall = diff >= (int.tryParse(interval) ?? 0);
      } catch (_) {
        shouldCall = true;
      }
    }

    if (!shouldCall) continue;

    inner['lastApiCall'] = DateFormat(
      "dd-MM-yyyy HH:mm:ss",
    ).format(DateTime.now());
    outerMap[key] = inner;
    await pref.setString("outerData", jsonEncode(outerMap));

    try {
      final data = jsonDecode(lastData) as Map<String, dynamic>;
      await _postLocationForIdentifier(data, position);
    } catch (_) {
      // malformed lastData for this identifier — skip, don't crash the loop
    }
  }
}

Future<void> _postLocationForIdentifier(
  Map<String, dynamic> data,
  Position position,
) async {
  String locName = "";
  try {
    final placemarks = await placemarkFromCoordinates(
      position.latitude,
      position.longitude,
    );
    if (placemarks.isNotEmpty) {
      final p = placemarks.first;
      locName =
          "${p.street},${p.subLocality},${p.administrativeArea},${p.postalCode}";
    }
  } catch (_) {}

  data['current_name'] = locName;
  data['current_loc'] = jsonEncode({
    "lat": position.latitude.toString(),
    "long": position.longitude.toString(),
  });

  // expectedlocations distance calc — ported from the old getLocationAndCallApi
  if (data['expectedlocations'] != null) {
    try {
      final stringList = data['expectedlocations'];
      final decoded = stringList is String
          ? jsonDecode(stringList)
          : stringList;
      final listOfItems = [];
      for (final item in decoded) {
        final distance = Geolocator.distanceBetween(
          double.parse(item['lat'].toString()),
          double.parse(item['long'].toString()),
          position.latitude,
          position.longitude,
        );
        item['dist'] = distance;
        listOfItems.add(item);
      }
      data['expectedlocations'] = jsonEncode(listOfItems);
    } catch (_) {}
  }

  final url = (data['armurl'] ?? "").toString().trim();
  if (url.isEmpty) return;

  try {
    await http.post(
      Uri.parse(url),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode(data),
    );
  } catch (_) {
    // next interval tick will retry naturally
  }
}
