import 'dart:convert';
import 'dart:developer';
import 'dart:io';

import 'package:axpert/app/core/utils/utils.dart';
import 'package:axpert/app/data/const/app_const.dart';
import 'package:axpert/app/data/models/project_model.dart';
import 'package:axpert/app/data/services/log/log_service.dart';
import 'package:axpert/app/data/services/notification/local_notification.dart';
import 'package:axpert/app/data/services/storage/storage_service.dart';
import 'package:axpert/app/db/project_database.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:geolocator/geolocator.dart';
import 'package:get_storage/get_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/common.dart';
import '../../../modules/offline_form_pages/db/db.dart';
import '../../models/firebase_message_model.dart';
import '../api/api_manger.dart';
import '../location/location_permission_gate.dart';
import '../location/location_service.dart';

FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

NotificationDetails notificationDetails = NotificationDetails(
  android: AndroidNotificationDetails(
    'Default',
    'Default',
    icon: "@mipmap/ic_launcher",
    channelDescription: 'Default Notification',
    importance: Importance.max,
    priority: Priority.high,
    ticker: 'ticker',
  ),
);
var hasNotificationPermission = true;

Future<void> initializeNotification() async {
  FirebaseMessaging messaging = FirebaseMessaging.instance;
  if (Platform.isAndroid) {
    flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()!
        .requestNotificationsPermission();
  }
  NotificationSettings settings = await messaging.requestPermission(
    alert: true,
    announcement: false,
    badge: true,
    carPlay: false,
    criticalAlert: false,
    provisional: false,
    sound: true,
  );
  if (settings.authorizationStatus == AuthorizationStatus.authorized) {
    hasNotificationPermission = true;
  } else
    hasNotificationPermission = false;

  AndroidInitializationSettings initializationSettingsAndroid =
      AndroidInitializationSettings('@mipmap/ic_launcher');
  DarwinInitializationSettings
  initializationSettingsDarwin = DarwinInitializationSettings(
    // todo find replacement
    /// [DarwinInitializationSettings] is updated with new sdk changes and the below callback been removed from package
    // onDidReceiveLocalNotification: onDidReceiveLocalNotification,
  );
  InitializationSettings initializationSettings = InitializationSettings(
    android: initializationSettingsAndroid,
    iOS: initializationSettingsDarwin,
  );
  await flutterLocalNotificationsPlugin.initialize(
    settings: initializationSettings,
    onDidReceiveNotificationResponse: onDidReceiveNotificationResponse,
  );

  var fcmID = await messaging.getToken();
  // globalVariableController.FCMID.value = fcmID ?? '';
  await StorageService.setFCMID(fcmID ?? "");
  print("FCMID: $fcmID");
  LogService.writeOnConsole(
    message: "initialize()=> FirebaseMessagesHandler: FCMID: $fcmID",
  );
}

void onMessageListener(RemoteMessage message) {
  log(message.data.toString(), name: "onMessageListener");
  if (message.data.containsKey('axm_queueid')) {
    OfflineDbModule.processCachedSaveQueueFCM(message.data);
  } else {
    decodeFirebaseMessage(message);
  }
}

@pragma('vm:entry-point')
Future<void> onBackgroundMessageListner(RemoteMessage message) async {
  await GetStorage.init();
  print("Background message: ${message.data}");
  decodeFirebaseMessage(message, isBackground: true);
}

void onMessageOpenAppListener(RemoteMessage message) {
  // print("Opened in android");
  // try {
  //   Get.toNamed(Routes.NotificationPage);
  // } catch (e) {
  //   Get.toNamed(Routes.SplashScreen);
  // }

  Get.toNamed(Routes.SPLASH);
}

void onDidReceiveNotificationResponse(
  NotificationResponse notificationResponse,
) async {
  // print("Opened in iOS");
  // try {
  //   Get.toNamed(Routes.NotificationPage);
  // } catch (e) {
  //   Get.toNamed(Routes.SPLASH);
  // }

  Get.toNamed(Routes.SPLASH);
}

void onDidReceiveLocalNotification(id, title, body, payload) {}

void decodeFirebaseMessage(
  RemoteMessage message, {
  isBackground = false,
}) async {
  // AppStorage appStorage = AppStorage();
  var shouldDisplay = false;
  var notiProjectName = "";
  var projectName = StorageService.userName ?? "";
  print("project name: $projectName");
  var userName = (StorageService.userName ?? "").toString().trim();
  print("Message Received:${message.data}");
  var messageData = message.data;
  //check if it is service related...
  // const encoder = JsonEncoder.withIndent('  ');
  // String formattedData = encoder.convert(messageData);
  // globalVariableController.firebaseTestMessages.add(formattedData);

  if (messageData.containsKey("type")) //key from message
  {
    var receivedProjectName = messageData['project'].toString().trim();
    if (receivedProjectName != projectName) return;
    if (messageData['type'].toString().toLowerCase() == 'sendlocation') {
      //new functionality.....
      //update interval
      String interval = messageData['interval'].toString();
      String identifier = messageData['identifier'];
      print("Received Identifiers: $identifier");
      var pref = await SharedPreferences.getInstance();
      await pref.reload();
      String outerDataStr = pref.getString("outerData") ?? "{}";
      Map outerMap = jsonDecode(outerDataStr);
      Map innerDetails = {};
      if (outerMap.containsKey(identifier)) {
        innerDetails = outerMap[identifier];
      }
      innerDetails["interval"] = interval;
      innerDetails["lastData"] = jsonEncode(message.data);
      outerMap[identifier] = innerDetails;

      await pref.setString("outerData", jsonEncode(outerMap));
      print("Identifier saved: $identifier and data ${jsonEncode(outerMap)}");

      // await LocationService.startLocationTracking();
      // await Future.delayed(Duration(seconds: 5));

      await pref.setString("outerData", jsonEncode(outerMap));

      if (await LocationPermissionGate.hasPermission()) {
        // already granted (repeat case) — no UI, just start
        await LocationService.startLocationTracking();
      } else if (!isBackground) {
        await LocationPermissionGate.showBlockingUntilGranted();
        await LocationService.startLocationTracking();
      } else {
        await LocationPermissionGate.markPendingCheck();
      }

      // LocalNotificationService.displayNotification("service", "running", "");
      //Get location here

      // if (lastApiCall == "0")
      //   await getLocationAndCallApi(data);
      // else {
      //   var dt = DateFormat("dd-MM-yyyy HH:mm:ss").parse(lastApiCall);
      //   var diff = dt.difference(DateTime.now()).inMinutes;
      //   if (diff > int.parse(interval)) {
      //     await getLocationAndCallApi(data);
      //   }
      // }
    } else if (messageData['type'].toString().toLowerCase() == 'stoplocation') {
      // stopBackgroundLocationService();
      LocationService.stopLocationTracking(
        messageData['identifier'].toString(),
      );
    }
    return;
  }

  FirebaseMessageModel data;
  try {
    data = FirebaseMessageModel(
      message.data["notify_title"],
      message.data["notify_body"],
    );
    var projectDet = jsonDecode(message.data['project_details']);

    notiProjectName = projectDet["projectname"].toString();
    if (notiProjectName == projectName &&
        userName != "" &&
        projectDet["notify_to"].toString().toLowerCase().contains(
          userName.toLowerCase(),
        )) {}
    shouldDisplay = true;
  } catch (e) {
    print(e.toString());
    data = FirebaseMessageModel(
      "Axpert",
      "You have received a new notification",
    );
  }
  print(
    "hasNotificationPermission: $hasNotificationPermission: $shouldDisplay",
  );

  if (hasNotificationPermission) {
    try {
      if (shouldDisplay && (StorageService.isShowNotifyEnabled)) {
        await flutterLocalNotificationsPlugin.show(
          id: data.hashCode,
          title: data.title,
          body: data.body,
          notificationDetails: notificationDetails,
          payload: 'item x',
        );
      }
    } catch (e) {}
  }

  //save message

  if (shouldDisplay) {
    //get and modify old messages
    // await GetStorage.init();\

    if (isBackground) {
      await StorageService.addBackgroundNotification(message.data);

      print(
        'Background notification count: '
        '${StorageService.getBackgroundNotifications().length}',
      );
    } else {
      await StorageService.addNotification(
        projectName: notiProjectName,
        userName: userName,
        notification: message.data,
      );

      final unreadCount = await StorageService.incrementUnreadNotificationCount(
        projectName: notiProjectName,
        userName: userName,
      );

      print('Unread notification count: $unreadCount');
    }
    // try {
    // LandingPageController landingPageController = Get.find();
    // landingPageController.needRefreshNotification.value = true;
    // landingPageController.notificationPageRefresh.value = true;
    // landingPageController.showBadge.value = true;
    // landingPageController.badgeCount.value = notNo;
    // } catch (e) {}
  }
}

Future<void> getLocationAndCallApi(
  data, [
  String lat = "0",
  String long = "0",
]) async {
  print("Location parsing Initiated");
  String locName = "";
  if (lat == "0" && long == "0") {
    var sharedPref = await SharedPreferences.getInstance();
    await sharedPref.reload();
    lat = sharedPref.getString("lat") ?? "0";
    long = sharedPref.getString("long") ?? "0";
    //get Name of the location and call api
    //double check the values
    if (lat == "0" || long == "0") {
      await Future.delayed(Duration(seconds: 5));
      await sharedPref.reload();
      lat = sharedPref.getString("lat") ?? "0";
      long = sharedPref.getString("long") ?? "0";
    }
  }
  var currentLoc = {"lat": lat, "long": long};

  try {
    // LocationService locationService = LocationService();
    await LocationService.getAddress(
      lat: double.parse(lat),
      lon: double.parse(long),
    ).then((value) {
      locName = value['data'];
      print(value['data']);
    });
  } catch (e) {
    locName = " ";
    // LogService.writeLog(tag: "Error Parsing Location", subtag: "Location Parsing", message: e.toString());
  }

  // print(" Notification: lat: ${lat}, long: ${long}, Name: ${Const.LocName}");
  //decode and encode data
  var stringList = data['expectedlocations'];
  var listOfItems = [];
  for (var item in jsonDecode(stringList)) {
    var distance = Geolocator.distanceBetween(
      double.parse(item['lat']),
      double.parse(item['long']),
      double.parse(lat),
      double.parse(long),
    );
    item['dist'] = distance;
    print("Item: $item");
    listOfItems.add(item);
  }
  data['current_name'] = locName;
  data['current_loc'] = jsonEncode(currentLoc);
  data['expectedlocations'] = jsonEncode(listOfItems);

  var url = data['armurl'].toString().trim() ?? "";
  // var header = {"Content-Type": "application/json"};
  var postData = jsonEncode(data);
  print("PostData: $postData");
  try {
    // LogService.writeLog(tag: "Sending Data to Server", subtag: "Trying to call API", message: postData.toString());
    // var resp = await http.post(Uri.parse(url), body: postData, headers: header);
    var resp = await ApiManager.instance.postToServer(url: url, body: postData);
    print(resp.body.toString());
    // LogService.writeLog(tag: "Sending Data to Server", subtag: "Successfully sent", message: resp.body.toString());
  } catch (e) {
    print("Some error occured:");
  }
}
