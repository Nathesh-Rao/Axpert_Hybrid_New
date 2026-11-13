// ignore_for_file: non_constant_identifier_names

import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';

import '../../../core/common.dart';

class InternetConnectivity extends GetxController {
  var isConnected = false.obs;

  InternetConnectivity() {
    connectivity_listen();
  }

  Future<bool> check() async {
    var connectivityResult = await (Connectivity().checkConnectivity());
    if (connectivityResult.contains(ConnectivityResult.mobile)) {
      isConnected.value = true;
      return true;
    } else if (connectivityResult.contains(ConnectivityResult.wifi)) {
      isConnected.value = true;
      return true;
    }
    isConnected.value = false;
    showError();
    return false;
  }

  Future<bool> get connectionStatus => check();

  void showError() {
    // Login and offline form routes handle missing connectivity in their own
    // flows; a global modal would block offline work.
    if (const {
      Routes.SPLASH,
      Routes.LOGIN,
      Routes.OFFLINE_LISTING_PAGE,
      Routes.OFFLINE_FORM_PAGE,
    }.contains(Get.currentRoute)) {
      return;
    }
    Get.defaultDialog(
      contentPadding: EdgeInsets.all(10),
      titlePadding: EdgeInsets.only(top: 20),
      title: "No Connection!",
      middleText: "Please check your internet connectivity",
      barrierDismissible: false,
      //"No Internet Connections are available.\nPlease try again later",
      confirm: ElevatedButton(
        onPressed: () async {
          Get.back();
          Timer(Duration(milliseconds: 400), () async {
            check().then((value) {
              if (value == true) {
                doRefresh(Get.currentRoute);
              }
            });
          });
        },
        child: Text("Ok"),
      ),
      // cancel: TextButton(
      //     onPressed: () {
      //       Get.back();
      //     },
      //     child: Text("Ok"))
    );
  }

  Future<void> connectivity_listen() async {
    Connectivity().onConnectivityChanged.listen((
      List<ConnectivityResult> result,
    ) async {
      if (result.contains(ConnectivityResult.mobile) ||
          result.contains(ConnectivityResult.wifi)) {
        isConnected.value = true;
      } else {
        isConnected.value = false;
        showError();
      }
    });
  }
}

void doRefresh(String currentRoute) {
  print(currentRoute);
  switch (currentRoute) {
    case Routes.LOGIN:
      // LoginController loginController = Get.find();
      // loginController.fetchUserTypeList();
      break;
    default:
      break;
  }
}
