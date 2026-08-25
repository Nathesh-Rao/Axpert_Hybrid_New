import 'dart:io';

import 'package:axpert/app/core/utils/app_utility.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'app/core/common.dart';
import 'app/data/services/storage_service.dart';
import 'app/db/project_database.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppUtility.init();
  await StorageService.init();
  await ProjectDatabase.instance.init();
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
