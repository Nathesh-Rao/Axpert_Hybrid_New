import 'dart:developer';

import 'package:axpert/app/core/common/methods.dart';
import 'package:axpert/app/data/services/api_manger.dart';
import 'package:axpert/app/modules/webview/webview_view.dart';
import 'package:get/get.dart';

import 'dart:async';
import 'dart:io';

import 'package:axpert/app/modules/webview/webview_view.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:get/get.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../core/common.dart';
import '../../../data/const/app_const.dart';
import '../../../data/services/storage_service.dart';

class WebViewController extends GetxController {
  // ── State ────────────────────────────────────────────────────────

  final RxString currentUrl = ''.obs;
  final RxString pageTitle = ''.obs;

  final RxBool isLoading = true.obs;
  final RxInt loadingProgress = 0.obs;

  final RxBool canGoBack = false.obs;
  final RxBool canGoForward = false.obs;

  // ── Chrome visibility ───────────────────────────────────────────
  bool isAxpertConnectEstablished = false;
  final RxBool isChromeVisible = true.obs;

  int _lastScrollY = 0;

  // ── WebView controller ──────────────────────────────────────────

  InAppWebViewController? _webViewController;

  InAppWebViewController? get webViewController => _webViewController;

  // ── Download state ──────────────────────────────────────────────

  final RxBool isFileDownloading = false.obs;

  // ── WebView page state ──────────────────────────────────────────

  final RxBool isCalendarPage = false.obs;

  final RxBool isSessionExpired = false.obs;
  // ── Long swipe state ────────────────────────────────────────────

  bool _handled = false;
  bool _longPressActive = false;
  double _startY = 0;

  Timer? _longPressTimer;

  String username = '';
  String projectname = '';
  var willAuth = false;

  // ── File extensions ─────────────────────────────────────────────
  @override
  void onInit() {
    isAxpertConnectEstablished = false;
    _initializeWebSession();
    super.onInit();
  }

  @override
  void onReady() {
    updateUserDetaiils();
    getBiometricStatus();
    super.onReady();
  }

  final List<String> imageExtensions = [
    'jpg',
    'jpeg',
    'png',
    'gif',
    'bmp',
    'ico',
    'xlsx',
    'xls',
    'docx',
    'doc',
    'pdf',
  ];

  // ────────────────────────────────────────────────────────────────
  // userDetails
  // ────────────────────────────────────────────────────────────────

  Future<void> _initializeWebSession() async {
    var sessionid = StorageService.sessionId ?? '';

    if (sessionid.isEmpty) {
      print("Error: Session ID is empty!");
      return;
    }

    var url = await AppConst.getFullWebUrl(
      "aspx/mainnew.aspx?authKey=AXPERT-$sessionid",
    );

    currentUrl.value = '';
    openWebView(url: url);
  }

  // ────────────────────────────────────────────────────────────────
  // userDetails
  // ────────────────────────────────────────────────────────────────

  void updateUserDetaiils() {
    username = StorageService.userName ?? '';
    projectname = StorageService.projectName ?? '';
  }

  // ────────────────────────────────────────────────────────────────
  // getBiometricStatus
  // ────────────────────────────────────────────────────────────────

  Future<void> getBiometricStatus() async {
    var tag = "getBiometricStatus";
    var willAuthLocal = StorageService.getWillBiometricAuthenticateForThisUser(
      projectName: projectname,
      username: username,
    );

    log("willAuthLocal : $willAuthLocal", name: tag);
    if (willAuthLocal == null || willAuthLocal == false) {
      Get.bottomSheet(
        PopScope(
          canPop: false,
          child: Container(
            padding: EdgeInsets.only(
              top: 12,
              left: 24,
              right: 24,
              bottom: MediaQuery.of(Get.context!).padding.bottom + 24,
            ),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  height: 4,
                  width: 48,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                const SizedBox(height: 32),

                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: AppColors.darkBlue.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.fingerprint_rounded,
                    color: AppColors.darkBlue,
                    size: 64,
                  ),
                ),
                const SizedBox(height: 24),

                // Title
                Text(
                  "Biometric Authentication",
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w700,
                    fontSize: 22,
                    color: AppColors.darkBlue,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),

                // Subtitle
                Text(
                  "Log into your project account faster and more securely using your phone's biometric credentials.",
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w400,
                    fontSize: 14,
                    color: Colors.grey.shade600,
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),

                // Primary Action Button
                SizedBox(
                  width: double.infinity,
                  height: 55,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.darkBlue,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    onPressed: () async {
                      var willAuthenticate =
                          await CommonMethods.showBiometricDialog();
                      log("willAuthenticate : $willAuthenticate", name: tag);

                      Get.back();
                      await StorageService.setWillBiometricAuthenticateForThisUser(
                        projectName: projectname,
                        username: username,
                        willAuthenticate: willAuthenticate,
                      );
                      willAuth = willAuthenticate;
                    },
                    child: Text(
                      "Enable Biometric Login",
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Secondary Action Button
                SizedBox(
                  width: double.infinity,
                  height: 55,
                  child: TextButton(
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.grey.shade700,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    onPressed: () async {
                      Get.back();
                      await StorageService.setWillBiometricAuthenticateForThisUser(
                        projectName: projectname,
                        username: username,
                        willAuthenticate: false,
                      );
                      willAuth = false;
                    },
                    child: Text(
                      "Skip for now",
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        isDismissible: false,
        isScrollControlled: true,
        enableDrag: false,
        barrierColor: Colors.black.withValues(alpha: 0.4),
        enterBottomSheetDuration: const Duration(milliseconds: 400),
      );
    } else {
      willAuth = willAuthLocal;
    }
  }

  // ────────────────────────────────────────────────────────────────
  // OPEN
  // ────────────────────────────────────────────────────────────────

  Future<void> openWebView({
    required String url,
    bool switchPage = true,
  }) async {
    // isProgressBarActive.value = true;
    // LandingPageController landingPageController = Get.find();
    // if (!landingPageController.isAxpertConnectEstablished) {
    //   await landingPageController.callApiForConnectToAxpert();
    // }

    // if (landingPageController.isAxpertConnectEstablished) {

    //       .then((_) {
    //     isProgressBarActive.value = false;
    //   });
    //   if (switchPage) currentIndex.value = 1;
    // }

    currentUrl.value = url;
    isSessionExpired.value = false;
    print("WebView URL loaded: $url");
    if (!await connectTOAxpert()) return;
    await _webViewController!.loadUrl(urlRequest: URLRequest(url: WebUri(url)));
  }

  Future<bool> connectTOAxpert() async {
    // if (isAxpertConnectEstablished) return true;
    final result = await ApiManager.instance.connectToAxpert();

    if (result is ApiSuccess<bool>) {
      isAxpertConnectEstablished = result.data;
      return true;
    } else if (result is ApiError<bool>) {
      return false;
    }

    return false;
  }

  // static void open({required String url, String? title}) {
  //   // Auto-upgrade http → https

  //   if (url.startsWith('http://')) {
  //     url = url.replaceFirst('http://', 'https://');
  //   }

  //   if (!Get.isRegistered<WebViewController>()) {
  //     Get.put(WebViewController());
  //   }

  //   final ctrl = Get.find<WebViewController>();

  //   ctrl.currentUrl.value = url;
  //   ctrl.pageTitle.value = title ?? '';
  //   ctrl.isLoading.value = true;
  //   ctrl.canGoBack.value = false;
  //   ctrl.canGoForward.value = false;
  //   ctrl.isChromeVisible.value = true;
  //   ctrl._lastScrollY = 0;

  //   Get.to(
  //     () => const WebviewView(),
  //     transition: Transition.fadeIn,

  //     duration: const Duration(milliseconds: 350),
  //   );
  // }

  // static void offAllOpen({required String url, String? title}) {
  //   // Auto-upgrade http → https

  //   if (url.startsWith('http://')) {
  //     url = url.replaceFirst('http://', 'https://');
  //   }

  //   if (!Get.isRegistered<WebViewController>()) {
  //     Get.put(WebViewController());
  //   }

  //   final ctrl = Get.find<WebViewController>();

  //   ctrl.currentUrl.value = url;
  //   ctrl.pageTitle.value = title ?? '';
  //   ctrl.isLoading.value = true;
  //   ctrl.canGoBack.value = false;
  //   ctrl.canGoForward.value = false;
  //   ctrl.isChromeVisible.value = true;
  //   ctrl._lastScrollY = 0;

  //   Get.offAll(
  //     () => const WebviewView(),
  //     transition: Transition.downToUp,
  //     duration: const Duration(milliseconds: 350),
  //   );
  // }

  // ────────────────────────────────────────────────────────────────
  // WEBVIEW ATTACH
  // ────────────────────────────────────────────────────────────────

  void attachWebViewController(InAppWebViewController nativeCtrl) {
    _webViewController = nativeCtrl;
  }

  // ────────────────────────────────────────────────────────────────
  // NAVIGATION
  // ────────────────────────────────────────────────────────────────

  Future<void> goBack() async {
    if (_webViewController != null) {
      await _webViewController!.goBack();
      await updateNavigationState();
    }
  }

  Future<void> goForward() async {
    if (_webViewController != null) {
      await _webViewController!.goForward();
      await updateNavigationState();
    }
  }

  Future<void> reload() async {
    if (_webViewController != null) {
      isLoading.value = true;
      loadingProgress.value = 0;

      await _webViewController!.reload();
    }
  }

  Future<void> updateNavigationState() async {
    if (_webViewController == null) return;

    final canBack = await _webViewController!.canGoBack();
    final canForward = await _webViewController!.canGoForward();

    updateNavState(canBack: canBack, canForward: canForward);
  }

  void closeScreen() {
    Get.back();
  }

  // ────────────────────────────────────────────────────────────────
  // PAGE EVENTS
  // ────────────────────────────────────────────────────────────────

  void onPageStarted(String url) {
    currentUrl.value = url;
    isLoading.value = true;
    loadingProgress.value = 0;

    isCalendarPage.value = url.toLowerCase().contains('dcalendar');
  }

  void onProgressChanged(int progress) {
    loadingProgress.value = progress;

    if (progress >= 100) {
      isLoading.value = false;
    }
  }

  Future<void> onPageFinished(String url) async {
    currentUrl.value = url;
    isLoading.value = false;
    loadingProgress.value = 100;

    isCalendarPage.value = url.toLowerCase().contains('dcalendar');

    await updateNavigationState();
  }

  void onTitleChanged(String title) {
    if (title.isNotEmpty) {
      pageTitle.value = title;
    }
  }

  void updateNavState({required bool canBack, required bool canForward}) {
    canGoBack.value = canBack;
    canGoForward.value = canForward;
  }

  // ────────────────────────────────────────────────────────────────
  // SCROLL / CHROME
  // ────────────────────────────────────────────────────────────────

  void onScrollChanged(int x, int y) {
    if (y > _lastScrollY + 10) {
      if (isChromeVisible.value) {
        isChromeVisible.value = false;
      }
    } else if (y < _lastScrollY - 5) {
      if (!isChromeVisible.value) {
        isChromeVisible.value = true;
      }
    }

    _lastScrollY = y;
  }

  void showChrome() {
    if (!isChromeVisible.value) {
      isChromeVisible.value = true;
    }
  }

  // ────────────────────────────────────────────────────────────────
  // BACK BUTTON
  // ────────────────────────────────────────────────────────────────

  // ────────────────────────────────────────────────────────────────
  // invalid session
  // ────────────────────────────────────────────────────────────────

  Future<bool> performBackButtonClick() async {
    var tag = "performBackButtonClick";
    final controller = _webViewController;

    if (controller == null) {
      log("_webViewController is null", name: tag);
      return true;
    }

    // Calendar page behaves like the old implementation.
    if (isCalendarPage.value) {
      closeScreen();
      return true;
    }

    try {
      final result = await controller.evaluateJavascript(
        source: """
          (function() {
            var btn = document.querySelector('.appBackBtn');

            if (btn) {
              btn.click();
              return true;
            }

            return false;
          })();
        """,
      );

      log("evaluateJavascript result : $result", name: tag);

      final handledInWeb =
          result == true || result?.toString().toLowerCase() == 'true';

      if (!handledInWeb) {
        closeScreen();
        return true;
      }
      _checkForMainUrl();
      return false;
    } catch (e) {
      log("catch error : $e", name: tag);

      closeScreen();
      return true;
    }
  }

  Future<bool> _checkForMainUrl() async {
    log("currentUrl.value : ${currentUrl.value}", name: "_checkForMainUrl");
    log(
      "_webViewController : ${await _webViewController?.getUrl()}",
      name: "_checkForMainUrl",
    );

    return false;
  }

  // ────────────────────────────────────────────────────────────────
  // DOWNLOAD
  // ────────────────────────────────────────────────────────────────

  Future<void> download(String url) async {
    try {
      isFileDownloading.value = true;

      print('Download URL: $url');

      // Keep your existing download implementation here.
      //
      // Example:
      //
      // await FileDownloaderFlutter().urlFileSaver(
      //   url: url,
      //   fileName: url.split('/').last.split('.').first,
      // );
    } catch (e) {
      print('Download error: $e');
    } finally {
      isFileDownloading.value = false;
    }
  }

  // ────────────────────────────────────────────────────────────────
  // URL HANDLING
  // ────────────────────────────────────────────────────────────────
  void showSessionExpiredDialog() {
    isSessionExpired.value = true;
  }

  Future<NavigationActionPolicy> handleUrlLoading(
    InAppWebViewController controller,
    NavigationAction navigationAction,
  ) async {
    final uri = navigationAction.request.url;

    if (uri == null) {
      return NavigationActionPolicy.ALLOW;
    }

    final url = uri.toString();

    print('Override URL: $url');

    // ── Session URL ───────────────────────────────────────────────

    if (url.toLowerCase().contains('sess.aspx')) {
      await controller.loadUrl(
        urlRequest: URLRequest(url: WebUri('$url?axmain=true')),
      );

      // Old implementation called:
      //
      // landingPageController.showSignOutDialog_sessionExpired();
      //
      // Ignored intentionally because LandingPageController
      // is not part of the new WebView architecture.

      showSessionExpiredDialog();
    }

    // ── File download ─────────────────────────────────────────────

    if (_isDownloadableFile(url)) {
      await download(url);

      return NavigationActionPolicy.CANCEL;
    }

    return NavigationActionPolicy.ALLOW;
  }

  bool _isDownloadableFile(String url) {
    final cleanUrl = url.toLowerCase().split('?').first;

    return imageExtensions.any((ext) => cleanUrl.endsWith('.$ext'));
  }

  // ────────────────────────────────────────────────────────────────
  // CONSOLE MESSAGE
  // ────────────────────────────────────────────────────────────────

  void onConsoleMessage(ConsoleMessage consoleMessage) {
    print('Console Message: $consoleMessage');

    if (consoleMessage.toString().contains('axm_mainpageloaded')) {
      // Old implementation:
      //
      // menuHomePageController...
      // landingPageController...
      // widget.webViewController.closeWebView();
      //
      // We only keep the WebView-specific behavior.
      // closeScreen();
      // controller
    }

    if (consoleMessage.toString().contains('Next Link')) {}
  }

  // ────────────────────────────────────────────────────────────────
  // LOCATION
  // ────────────────────────────────────────────────────────────────

  Future<GeolocationPermissionShowPromptResponse?> handleGeolocationPermission(
    InAppWebViewController controller,
    String origin,
  ) async {
    final status = await Permission.locationWhenInUse.request();

    if (status.isGranted) {
      return GeolocationPermissionShowPromptResponse(
        origin: origin,
        allow: true,
        retain: true,
      );
    }

    return GeolocationPermissionShowPromptResponse(
      origin: origin,
      allow: false,
      retain: false,
    );
  }

  // ────────────────────────────────────────────────────────────────
  // LONG SWIPE
  // ────────────────────────────────────────────────────────────────

  void onPointerDown(double y) {
    _startY = y;

    _longPressTimer?.cancel();

    _longPressTimer = Timer(const Duration(milliseconds: 300), () {
      _longPressActive = true;
    });
  }

  void onPointerMove(double y) {
    if (!_longPressActive) return;

    final dy = y - _startY;

    if (dy > 100 && !_handled) {
      onLongSwipe();
    }
  }

  void onPointerUp() {
    _longPressTimer?.cancel();
    _longPressActive = false;
  }

  Future<void> onLongSwipe() async {
    if (_handled) return;

    _handled = true;

    // View handles actual button visibility.
    showChrome();

    await Future.delayed(const Duration(seconds: 3));

    _handled = false;
  }

  // ────────────────────────────────────────────────────────────────
  // COOKIE
  // ────────────────────────────────────────────────────────────────

  Future<void> clearCookies() async {
    await CookieManager.instance().deleteAllCookies();

    print('Cookie cleared');
  }

  // ────────────────────────────────────────────────────────────────
  // CLEANUP
  // ────────────────────────────────────────────────────────────────

  @override
  void onClose() {
    _longPressTimer?.cancel();
    super.onClose();
  }
}
