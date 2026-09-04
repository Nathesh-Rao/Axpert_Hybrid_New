import 'dart:io';

import 'package:axpert/app/core/utils/app_utility.dart';
import 'package:axpert/app/data/services/notification/notification_service.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'app/core/common.dart';
import 'app/data/services/location/location_service.dart';
import 'app/data/services/log/log_service.dart';
import 'app/data/services/notification/firebase_notificastion.dart';
import 'app/data/services/storage/storage_service.dart';
import 'app/db/project_database.dart';
import 'app/modules/offline_form_pages/auto_sync/sync.dart';
import 'app/modules/offline_form_pages/db/db.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await StorageService.init();
  await AppUtility.init();
  await ProjectDatabase.instance.init();
  await Firebase.initializeApp();
  // FirebaseMessaging.onBackgroundMessage(
  //   NotificationService.backgroundFirebaseMessageHandler,
  // );
  await LocationService.initForegroundTask();
  await initializeNotification();
  FirebaseMessaging.onMessage.listen(onMessageListener);
  FirebaseMessaging.onBackgroundMessage(onBackgroundMessageListner);
  FirebaseMessaging.onMessageOpenedApp.listen(onMessageOpenAppListener);

  if (Platform.isAndroid) {
    await InAppWebViewController.setWebContentsDebuggingEnabled(true);
  }
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      statusBarBrightness: Brightness.light,

      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );
  try {
    await OfflineDbModule.init();
    // await OfflineBackgroundSyncService.instance.initWorkManager();

    OfflineBackgroundSyncService.initCommunicationPort();

    LogService.writeLog(
      message: "[OFFLINE_DB_INIT_001][SUCCESS] Offline DB initialized",
    );
  } catch (e, st) {
    LogService.writeLog(
      message: "[OFFLINE_DB_INIT_001][FAILED] Offline DB init failed => $e",
    );
    LogService.writeLog(message: "[OFFLINE_DB_INIT_001][STACK] $st");
  }
  runApp(const AxpertApp());
}

class AxpertApp extends StatelessWidget {
  const AxpertApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ScreenUtilInit(
      designSize: const Size(402, 874),
      minTextAdapt: true,
      splitScreenMode: true,
      child: GetMaterialApp(
        title: 'AXPERT',
        debugShowCheckedModeBanner: false,

        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        themeMode: ThemeMode.light,

        initialRoute: AppPages.initial,
        getPages: AppPages.routes,

        defaultTransition: Transition.fadeIn,
        transitionDuration: const Duration(milliseconds: 300),

        locale: const Locale('en', 'US'),
        fallbackLocale: const Locale('en', 'US'),

        builder: (context, child) {
          return MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.noScaling),
            child: child!,
          );
        },
      ),
    );
  }
}
