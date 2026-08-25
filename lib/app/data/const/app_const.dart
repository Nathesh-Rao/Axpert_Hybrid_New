// ignore_for_file: non_constant_identifier_names, constant_identifier_names

import 'package:axpert/app/data/services/storage_service.dart';

class AppConst {
  AppConst._();

  // ── Cloud (client id lookup) ──────────────────────────────────────
  static const String cloudProject = 'axpmobileclient';

  static const String seedV = '1983';
  static const String SEED = "1993";
  static const String dummyUser = 'admin';
  static const String dummyPwd = 'a5ca360e803b868680e2b6f7805fcb9e';

  static String APP_RELEASE_ID = "";
  static String APP_RELEASE_DATE = "_FCM_TESTING_12082026";
  static String DEVICE_ID = "";
  static String APP_VERSION = "";
  static String GUID = "";

  // ── Project endpoints ─────────────────────────────────────────────
  static const String setHybridInfo = '/Webservice.asmx/SetHybridInfo';
  static const String setHybridNotificationInfo =
      '/Webservice.asmx/SetHybridNotifiInfo';
  static const String logout = 'webservice.asmx/SignOut';

  // ── SQL ───────────────────────────────────────────────────────────
  static String sqlForClientId(String clientId) =>
      "select projectname, scripts_uri, dbtype, expirydate, notify_uri, web_url "
      "from tblclientMST where clientid = '$clientId'";

  static const NETWORK_APP_LOGO_FILE_NAME = "axAppLogo";

  //   static String getFullARMUrl(String Entrypoint) {
  //   print("getFullARMUrl => ${globalVariableController.ARM_URL.value}");
  //   if (globalVariableController.ARM_URL.value == "") {
  //     var data = AppStorage().retrieveValue(AppStorage.ARM_URL) ?? "";
  //     return data.endsWith("/") ? data + Entrypoint : data + "/" + Entrypoint;
  //   } else
  //     return globalVariableController.ARM_URL.value.endsWith("/")
  //         ? globalVariableController.ARM_URL.value + Entrypoint
  //         : globalVariableController.ARM_URL.value + "/" + Entrypoint;
  // }

  static Future<String> getFullWebUrl(String entryPoint) async {
    var project = await StorageService.getLastSelectedProject();
    if (project == null) return entryPoint;
    var weburl = project.url;
    return weburl.endsWith("/") ? weburl + entryPoint : "$weburl/$entryPoint";
  }

  static Future<String> getFullARMUrl(String entryPoint) async {
    var project = await StorageService.getLastSelectedProject();
    if (project == null) return entryPoint;
    var armurl = project.armurl;
    return armurl.endsWith("/") ? armurl + entryPoint : "$armurl/$entryPoint";
  }
}
