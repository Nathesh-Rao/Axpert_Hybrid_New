import 'dart:io';
import 'package:axpert/app/data/const/app_const.dart';
import 'package:axpert/app/modules/webview/controller/webview_controller.dart';
import 'package:axpert/app/modules/webview/webview_view.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:file_downloader_flutter/file_downloader_flutter.dart';

import 'package:uuid/uuid.dart';

// class AppUtility {
//   AppUtility._();

//   static String _deviceId = '';
//   static String _lastGuid = '';

//   static Future<void> init() async {
//     final info = DeviceInfoPlugin();
//     if (Platform.isAndroid) {
//       final android = await info.androidInfo;
//       _deviceId = android.id;
//     } else if (Platform.isIOS) {
//       final ios = await info.iosInfo;
//       _deviceId = ios.identifierForVendor ?? '';
//     }
//   }

//   static String get deviceId => _deviceId;
//   static String get lastGuid => _lastGuid;

//   static String generateUrlForWebView(String webUrl, String projectName) {
//     _lastGuid = const Uuid().v1();
//     final base = _getBaseUrl(webUrl);
//     final suffix =
//         'aspx/Signin.aspx'
//         '?hybridGUID=$_lastGuid'
//         '&deviceid=$_deviceId'
//         '&projName=$projectName';

//     return base.endsWith('/') ? '$base$suffix' : '$base/$suffix';
//   }

//   static String _getBaseUrl(String url) {
//     final lower = url.toLowerCase();
//     if (lower.contains('/aspx')) {
//       return url.substring(0, lower.indexOf('/aspx'));
//     }
//     return url.endsWith('/') ? url : '$url/';
//   }

// }

import 'dart:io';
import 'dart:math';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:get/get.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:uuid/uuid.dart';

// TODO: Ensure your custom imports (FileDownloaderFlutter, InAppWebViewer, AppColors) are added here

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
    AppConst.GUID = _lastGuid;
    final base = getBaseUrl(webUrl);
    final suffix =
        'aspx/Signin.aspx'
        '?hybridGUID=$_lastGuid'
        '&deviceid=$_deviceId'
        '&projName=$projectName';

    return base.endsWith('/') ? '$base$suffix' : '$base/$suffix';
  }

  static String getBaseUrl(String url) {
    final lower = url.toLowerCase();
    if (lower.contains('/aspx')) {
      return url.substring(0, lower.indexOf('/aspx'));
    }
    return url.endsWith('/') ? url : '$url/';
  }

  static int generateRandomNumber() {
    return Random().nextInt(9998999) + 1000;
  }

  static String getProjectInitials(String projectName) {
    final names = projectName.trim().split(" ");
    String initials = "";
    final numWords = min(2, names.length);

    for (var i = 0; i < numWords; i++) {
      if (names[i].isNotEmpty) {
        initials += names[i][0];
      }
    }
    return initials.toUpperCase();
  }

  static Future<void> navToWebsite(
    BuildContext context,
    String webUrl,
    String projectName,
    bool isFirstLoad,
    bool isFromNotification,
  ) async {
    try {
      Map<String, dynamic> sendMap;

      if (isFromNotification) {
        sendMap = {
          "website_notification": webUrl,
          "isFirstLoad_notification": isFirstLoad,
        };
      } else {
        sendMap = {
          "website": webUrl,
          "isFirstLoad": isFirstLoad,
          "projectName": projectName,
        };
      }

      var status = await Permission.storage.status;
      if (!status.isGranted) {
        await Permission.storage.request();
      }

      // Replaced old Navigator.push with modern GetX routing if you have migrated InAppWebViewer
      Get.to(() => WebviewView());
      WebViewController webController = Get.find();
      webController.preData = sendMap;
      // webController.loadData();
    } on PlatformException catch (e) {
      debugPrint("Failed to navigate: '${e.message}'.");
    }
  }

  static Future<void> downloadFileInAppWebView({
    required InAppWebViewController controller,
    required DownloadStartRequest downloadStartRequest,
    void Function(String? path)? onDownloadComplete,
    void Function(String? error)? onDownloadError,
  }) async {
    final url = downloadStartRequest.url.toString();
    debugPrint("downloadFile_inAppWebView started: $url");

    if (url.startsWith("blob")) {
      debugPrint("Blob data detected");

      // Refactored JS injection to a clean multiline string
      final String functionBody =
          """
        var xhr = new XMLHttpRequest();
        var blobUrl = '$url';
        xhr.open('GET', blobUrl, true);
        xhr.responseType = 'blob';
        xhr.onload = function(e) {
          if (this.status == 200) {
            var blob = this.response;
            var reader = new FileReader();
            reader.readAsDataURL(blob);
            reader.onloadend = function() {
              var base64data = reader.result;
              var base64ContentArray = base64data.split(",");
              var decodedFile = base64ContentArray[1];
              window.flutter_inappwebview.callHandler('blobToBase64Handler', decodedFile, 'pdf');
            };
          }
        };
        xhr.send();
      """;

      await controller.evaluateJavascript(source: functionBody).then((result) {
        debugPrint(result.toString());
        _download(url, onDownloadComplete, onDownloadError);
      });
    } else {
      _download(url, onDownloadComplete, onDownloadError);
    }
  }

  static void _download(
    String url,
    void Function(String? path)? onComplete,
    void Function(String? error)? onDownloadError,
  ) async {
    try {
      debugPrint("download Url: $url");
      String fname = url.split('/').last.split('.').first;
      fname = Uri.decodeFull(fname);
      debugPrint("download FileName: $fname");

      var path = await FileDownloaderFlutter().urlFileSaver(
        url: url,
        fileName: fname,
      );

      if (onComplete != null) {
        onComplete(path);
      }
      _showDownloadSnackBar(message: "File downloaded to $path");
    } catch (e) {
      if (onDownloadError != null) {
        onDownloadError(e.toString());
      }
      _showDownloadSnackBar(
        message: "Something went wrong\n${e.toString()}",
        isError: true,
      );
      debugPrint("Download error: ${e.toString()}");
    }
  }

  static void _showDownloadSnackBar({
    required String message,
    bool isError = false,
  }) {
    Get.showSnackbar(
      GetSnackBar(
        duration: const Duration(seconds: 3),
        backgroundColor: !isError ? Colors.green : Colors.red,
        icon: Icon(
          !isError ? Icons.check_circle : Icons.error,
          color: Colors.white,
        ),
        titleText: Text(
          !isError ? "Success" : "Failed",
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        messageText: Text(message, style: const TextStyle(color: Colors.white)),
      ),
    );
  }
}
