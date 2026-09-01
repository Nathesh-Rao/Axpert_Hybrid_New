import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';

class LocationService {
  static final Map _rMap = {"hasError": true, "eMsg": "default eMsg"};
  static String _rAddress = "Default city, Default state, Default country";
  static final bool _isLocationServiceEnabled = false;

  static Future<Position> determineCurrentLocation() async {
    bool serviceEnabled;
    LocationPermission permission;
    print("longitude 1");
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      print("longitude 12$serviceEnabled");

      // return Future.error('Location services are disabled.');
    }

    permission = await Geolocator.checkPermission();

    print("permission++++++++$permission");
    // if (permission == LocationPermission.denied) {
    print("longitude 1234");

    //  print("longitude "+permission.longitude.toString());
    permission = await Geolocator.requestPermission();

    if (permission == LocationPermission.denied) {
      return Future.error('Location permissions are denied');
    }
    // }

    if (permission == LocationPermission.deniedForever) {
      return Future.error(
        'Location permissions are permanently denied, we cannot request permissions.',
      );
    }
    return await Geolocator.getCurrentPosition();
  }

  static Future startLocationTracking() async {
    // try {
    //   await BackgroundLocationTrackerManager.startTracking();
    //   // LogService.writeLog(tag: "Service Started", subtag: "Service Started", message: "Service Started");
    // } catch (e) {
    //   LogService.writeLog(message: e.toString());
    // }
  }

  static Future stopLocationTracking(String identifier) async {
    // try {
    //   var pref = await SharedPreferences.getInstance();
    //   await pref.reload();
    //   String val = await pref.getString("outerData") ?? "{}";
    //   Map outerData = jsonDecode(val);
    //   if (outerData.containsKey(identifier)) outerData.remove(identifier);
    //   if (outerData.length == 0 || identifier.toUpperCase() == "ALL") {
    //     await BackgroundLocationTrackerManager.stopTracking();
    //     await pref.remove("outerData");
    //     // LogService.writeLog(tag: "Service Stopped", subtag: "Service Stopped", message: "Service Stopped");
    //   } else {
    //     val = jsonEncode(outerData);
    //     await pref.setString("outerData", val);
    //   }
    // } catch (e) {
    //   // LogService.writeLog(tag: "Error in Stopping Service", subtag: "Error in Stopping Service", message: "Error in Stopping Service ${e}");
    // }
  }

  static Future<Map<dynamic, dynamic>> getAddress({
    required double lat,
    required double lon,
  }) async {
    List<Placemark> placemarks = await placemarkFromCoordinates(lat, lon);

    if (placemarks.isNotEmpty) {
      Placemark data = placemarks.first;
      // rAddress = "${data.subAdminArea}, ${data.adminArea}, ${data.countryName}";
      if (kDebugMode) {
        print(data.toString());
      }
      _rAddress =
          "${data.subLocality}, ${data.locality}, ${data.administrativeArea}";
      _rMap.remove("hasError");
      _rMap.remove("eMsg");
      _rMap.addAll({"hasError": false});
      _rMap.addAll({"data": _rAddress});

      return Future.value(_rMap);
    } else {
      _rMap.remove("hasError");
      _rMap.remove("eMsg");
      _rMap.addAll({"hasError": false});
      _rMap.addAll({"eMgs": "No data available"});
      return Future.value(_rMap);
    }
  }
}
