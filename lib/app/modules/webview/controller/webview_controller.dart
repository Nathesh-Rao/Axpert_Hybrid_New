import 'package:axpert/app/modules/webview/webview_view.dart';
import 'package:get/get.dart';

class WebViewController extends GetxController {
  // ── State ────────────────────────────────────────────────────────
  final RxString currentUrl = ''.obs;
  final RxString pageTitle = ''.obs;
  final RxBool isLoading = true.obs;
  final RxInt loadingProgress = 0.obs;
  final RxBool canGoBack = false.obs;
  final RxBool canGoForward = false.obs;

  // ── Chrome (top bar + bottom nav) visibility ──────────────────────
  final RxBool isChromeVisible = true.obs;
  int _lastScrollY = 0;

  // Internal webview controller reference (set from view)
  dynamic _webViewController;

  // ── Open (the only method you need to call) ───────────────────────
  static void open({required String url, String? title}) {
    // Auto-upgrade http → https
    if (url.startsWith('http://')) {
      url = url.replaceFirst('http://', 'https://');
    }

    if (!Get.isRegistered<WebViewController>()) {
      Get.put(WebViewController());
    }

    final ctrl = Get.find<WebViewController>();
    ctrl.currentUrl.value = url;
    ctrl.pageTitle.value = title ?? '';
    ctrl.isLoading.value = true;
    ctrl.canGoBack.value = false;
    ctrl.canGoForward.value = false;
    ctrl.isChromeVisible.value = true;
    ctrl._lastScrollY = 0;

    Get.to(
      () => const WebviewView(),
      transition: Transition.fadeIn,
      duration: const Duration(milliseconds: 350),
    );
  }

  static void offAllOpen({required String url, String? title}) {
    // Auto-upgrade http → https
    if (url.startsWith('http://')) {
      url = url.replaceFirst('http://', 'https://');
    }

    if (!Get.isRegistered<WebViewController>()) {
      Get.put(WebViewController());
    }

    final ctrl = Get.find<WebViewController>();
    ctrl.currentUrl.value = url;
    ctrl.pageTitle.value = title ?? '';
    ctrl.isLoading.value = true;
    ctrl.canGoBack.value = false;
    ctrl.canGoForward.value = false;
    ctrl.isChromeVisible.value = true;
    ctrl._lastScrollY = 0;

    Get.offAll(
      () => const WebviewView(),
      transition: Transition.downToUp,
      duration: const Duration(milliseconds: 350),
    );
  }

  // ── Called from the view to hand over the native controller ──────
  void attachWebViewController(dynamic nativeCtrl) {
    _webViewController = nativeCtrl;
  }

  // ── Navigation helpers ───────────────────────────────────────────
  Future<void> goBack() async {
    if (_webViewController != null) await _webViewController.goBack();
  }

  Future<void> goForward() async {
    if (_webViewController != null) await _webViewController.goForward();
  }

  Future<void> reload() async {
    if (_webViewController != null) await _webViewController.reload();
  }

  void closeScreen() => Get.back();

  // ── WebView event callbacks ──────────────────────────────────────
  void onPageStarted(String url) {
    currentUrl.value = url;
    isLoading.value = true;
    loadingProgress.value = 0;
  }

  void onProgressChanged(int progress) {
    loadingProgress.value = progress;
    if (progress == 100) isLoading.value = false;
  }

  void onPageFinished(String url) {
    currentUrl.value = url;
    isLoading.value = false;
    loadingProgress.value = 100;
  }

  void onTitleChanged(String title) {
    if (title.isNotEmpty) pageTitle.value = title;
  }

  void updateNavState({required bool canBack, required bool canForward}) {
    canGoBack.value = canBack;
    canGoForward.value = canForward;
  }

  // ── Scroll-aware chrome visibility ───────────────────────────────
  void onScrollChanged(int x, int y) {
    // Scrolling down → hide chrome
    if (y > _lastScrollY + 10) {
      if (isChromeVisible.value) isChromeVisible.value = false;
    }
    // Scrolling up → show chrome
    else if (y < _lastScrollY - 5) {
      if (!isChromeVisible.value) isChromeVisible.value = true;
    }
    _lastScrollY = y;
  }

  // Tap anywhere on webview → always reveal chrome
  void showChrome() {
    if (!isChromeVisible.value) isChromeVisible.value = true;
  }
}
