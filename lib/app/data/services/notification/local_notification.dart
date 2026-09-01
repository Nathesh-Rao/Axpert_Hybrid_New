import 'package:axpert/app/core/utils/utils.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class LocalNotificationService {
  static final FlutterLocalNotificationsPlugin notificationPlugin =
      FlutterLocalNotificationsPlugin();

  static BuildContext? mContext;

  static void initialize(BuildContext context) {
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    mContext = context;
    // Settings for iOS
    // var iosInitializationSettings = new IOSInitializationSettings(
    //     onDidReceiveLocalNotification: onDidReceiveLocalNotification);
    final InitializationSettings initializationSetting = InitializationSettings(
      android: initializationSettingsAndroid,
      // iOS: initializationSettingsDarwin,
    );

    notificationPlugin.initialize(
      settings: initializationSetting,
      // onSelectNotification: onSelectNotification
    );
    debugPrint("LocalNotificationService: Initialisation complete");
  }

  // static Future<void> onSelectNotification(String? payload) async {
  //   print("LocalNotificationService: Inside onSelectNotification");
  //   if (payload != null) {
  //     await Navigator.of(mContext!).pushNamed(NotificationScreen.routeName);
  //   }
  // }
  static Future<void> onSelectNotification(String? payload) async {
    if (payload != null) {
      debugPrint("payload : $payload");
      if (payload.isNotEmpty) {
        AppUtility.navToWebsite(mContext!, payload, "", true, true);
      }
    }
  }

  static Future onDidReceiveLocalNotification(
    int id,
    String? title,
    String? body,
    String? payload,
  ) async {
    print("LocalNotificationService: onDidReceiveLocalNotification");
  }

  static void displayNotification(
    String title,
    String body,
    String? payload,
  ) async {
    try {
      final id = 888; //DateTime.now().millisecondsSinceEpoch ~/ 1000;
      final NotificationDetails notificationDetails = NotificationDetails(
        android: AndroidNotificationDetails(
          "General Notification",
          "Axpert General Notification",
          priority: Priority.low,
        ),
        //     iOS: IOSNotificationDetails(
        //   presentAlert: true,
        //   presentBadge: true,
        //   presentSound: true,
        // )
      );
      await notificationPlugin.show(
        id: id,
        title: title,
        body: body,
        notificationDetails: notificationDetails,
        payload: payload,
      );
    } catch (e) {
      print(e);
    }
  }
}
