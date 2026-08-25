import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:uuid/uuid.dart';

class AppUtility {
  AppUtility._();

  static String _deviceId = '';
  static String _lastGuid = '';

  static Future<void> init() async {
    final info = DeviceInfoPlugin();
    if (Platform.isAndroid) {
      final android = await info.androidInfo;
      _deviceId = android.id;
    } else if (Platform.isIOS) {
      final ios = await info.iosInfo;
      _deviceId = ios.identifierForVendor ?? '';
    }
  }

  static String get deviceId => _deviceId;
  static String get lastGuid => _lastGuid;

  static String generateUrlForWebView(String webUrl, String projectName) {
    _lastGuid = const Uuid().v1();
    final base = _getBaseUrl(webUrl);
    final suffix =
        'aspx/Signin.aspx'
        '?hybridGUID=$_lastGuid'
        '&deviceid=$_deviceId'
        '&projName=$projectName';

    return base.endsWith('/') ? '$base$suffix' : '$base/$suffix';
  }

  static String _getBaseUrl(String url) {
    final lower = url.toLowerCase();
    if (lower.contains('/aspx')) {
      return url.substring(0, lower.indexOf('/aspx'));
    }
    return url.endsWith('/') ? url : '$url/';
  }
}
