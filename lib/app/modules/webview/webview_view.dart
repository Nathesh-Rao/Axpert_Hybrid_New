import 'dart:developer';

import 'package:animate_do/animate_do.dart';
import 'package:axpert/app/core/common.dart';
import 'package:axpert/app/data/services/api_manger.dart';
import 'package:axpert/app/modules/project/binding/project_binding.dart';
import 'package:axpert/app/modules/project/project_view.dart';
import 'package:axpert/app/modules/webview/controller/webview_controller.dart';
import 'package:axpert/app/core/routes/app_routes.dart';
import 'package:axpert/app/modules/webview/widgets/session_expired_widget.dart';
import 'package:axpert/app/widgets/widgets.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme/app_colors.dart';
import '../../widgets/axi_logo.dart';

const double _kTopBarHeight = 64.0;
const double _kBottomBarHeight = 64.0;

class WebviewView extends GetView<WebViewController> {
  const WebviewView({super.key});

  @override
  Widget build(BuildContext context) {
    print("CurrentURL => ${controller.currentUrl.value}");

    return PopScope(
      canPop: false, // always intercept back
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;

        if (controller.isSessionExpired.value) return;
        // await _handleBackPress(context);
        await controller.performBackButtonClick();
      },
      child: AppScaffold(
        // backgroundColor: AppColors.white,
        body: SafeArea(
          child: Column(
            children: [
              // ── TOP BAR ─────────────────────────────────────────────
              // Obx(
              //   () => AnimatedContainer(
              //     duration: const Duration(milliseconds: 300),
              //     curve: Curves.easeInOut,
              //     height: controller.isChromeVisible.value
              //         ? _kTopBarHeight
              //         : 0.0,
              //     child: ClipRect(child: _TopBar(controller: controller)),
              //   ),
              // ),

              // ── PROGRESS BAR ─────────────────────────────────────────
              // Obx(
              //   () => AnimatedContainer(
              //     duration: const Duration(milliseconds: 200),
              //     height: controller.isLoading.value ? 2.0 : 0.0,
              //     child: LinearProgressIndicator(
              //       value: controller.loadingProgress.value / 100,
              //       backgroundColor: Colors.transparent,
              //       valueColor: const AlwaysStoppedAnimation<Color>(
              //         AppColors.lightPrimary,
              //       ),
              //     ),
              //   ),
              // ),

              // ── WEBVIEW ──────────────────────────────────────────────
              // Expanded fills whatever space top + bottom leave behind.
              // NOT inside Obx — rebuilding kills the WebView.
              Expanded(
                child: Stack(
                  children: [
                    // Container(
                    //   decoration: BoxDecoration(
                    //     gradient: LinearGradient(
                    //       begin: Alignment.topCenter,
                    //       end: Alignment.bottomCenter,
                    //       colors: [AppColors.white, AppColors.grey50],
                    //     ),
                    //   ),
                    // ),
                    // InAppWebView(
                    //   initialUrlRequest: URLRequest(
                    //     url: WebUri(controller.currentUrl.value),
                    //   ),
                    //   initialSettings: InAppWebViewSettings(
                    //     javaScriptEnabled: true,
                    //     domStorageEnabled: true,
                    //     databaseEnabled: true,
                    //     mediaPlaybackRequiresUserGesture: false,
                    //     allowsInlineMediaPlayback: true,
                    //     useShouldOverrideUrlLoading: true,
                    //     transparentBackground: true,
                    //     mixedContentMode:
                    //         MixedContentMode.MIXED_CONTENT_ALWAYS_ALLOW,
                    //   ),
                    //   onWebViewCreated: (webCtrl) {
                    //     controller.attachWebViewController(webCtrl);
                    //   },
                    //   onReceivedServerTrustAuthRequest:
                    //       (webCtrl, challenge) async {
                    //         return ServerTrustAuthResponse(
                    //           action: ServerTrustAuthResponseAction.PROCEED,
                    //         );
                    //       },
                    //   onLoadStart: (webCtrl, url) {
                    //     controller.onPageStarted(url?.toString() ?? '');
                    //   },
                    //   onProgressChanged: (webCtrl, progress) {
                    //     controller.onProgressChanged(progress);
                    //   },
                    //   onLoadStop: (webCtrl, url) async {
                    //     controller.onPageFinished(url?.toString() ?? '');
                    //     final canBack = await webCtrl.canGoBack();
                    //     final canForward = await webCtrl.canGoForward();
                    //     controller.updateNavState(
                    //       canBack: canBack,
                    //       canForward: canForward,
                    //     );
                    //   },
                    //   onTitleChanged: (webCtrl, title) {
                    //     controller.onTitleChanged(title ?? '');
                    //   },
                    //   onReceivedError: (webCtrl, request, error) {
                    //     controller.isLoading.value = false;
                    //   },
                    //   onScrollChanged: (webCtrl, x, y) {
                    //     controller.onScrollChanged(x, y);
                    //   },
                    // ),
                    InAppWebView(
                      initialUrlRequest: URLRequest(
                        url: WebUri(controller.currentUrl.value),
                      ),

                      initialSettings: InAppWebViewSettings(
                        // ── Old settings ─────────────────────────────────────
                        transparentBackground: true,

                        javaScriptEnabled: true,

                        javaScriptCanOpenWindowsAutomatically: true,

                        domStorageEnabled: true,

                        databaseEnabled: true,

                        useShouldOverrideUrlLoading: true,

                        supportMultipleWindows: true,

                        geolocationEnabled: true,

                        clearCache: false,

                        mediaPlaybackRequiresUserGesture: false,

                        allowsInlineMediaPlayback: true,

                        mixedContentMode:
                            MixedContentMode.MIXED_CONTENT_ALWAYS_ALLOW,

                        // Keep this only if you actually need it.
                        useHybridComposition: false,

                        hardwareAcceleration: false,
                      ),

                      // ────────────────────────────────────────────────────────
                      // CREATED
                      // ────────────────────────────────────────────────────────
                      onWebViewCreated: (webCtrl) {
                        controller.attachWebViewController(webCtrl);

                        // Old InApplicationWebViewer cleared cookies
                        // during initialization.
                        controller.clearCookies();
                      },

                      // ────────────────────────────────────────────────────────
                      // SSL
                      // ────────────────────────────────────────────────────────
                      onReceivedServerTrustAuthRequest:
                          (webCtrl, challenge) async {
                            return ServerTrustAuthResponse(
                              action: ServerTrustAuthResponseAction.PROCEED,
                            );
                          },

                      // ────────────────────────────────────────────────────────
                      // LOAD START
                      // ────────────────────────────────────────────────────────
                      onLoadStart: (webCtrl, url) {
                        controller.onPageStarted(url?.toString() ?? '');
                      },

                      // ────────────────────────────────────────────────────────
                      // PROGRESS
                      // ────────────────────────────────────────────────────────
                      onProgressChanged: (webCtrl, progress) {
                        controller.onProgressChanged(progress);
                      },

                      // ────────────────────────────────────────────────────────
                      // LOAD STOP
                      // ────────────────────────────────────────────────────────
                      onLoadStop: (webCtrl, url) async {
                        await controller.onPageFinished(url?.toString() ?? '');
                      },

                      // ────────────────────────────────────────────────────────
                      // TITLE
                      // ────────────────────────────────────────────────────────
                      onTitleChanged: (webCtrl, title) {
                        controller.onTitleChanged(title ?? '');
                      },

                      // ────────────────────────────────────────────────────────
                      // ERROR
                      // ────────────────────────────────────────────────────────
                      onReceivedError: (webCtrl, request, error) {
                        controller.isLoading.value = false;
                      },

                      // ────────────────────────────────────────────────────────
                      // SCROLL
                      // ────────────────────────────────────────────────────────
                      onScrollChanged: (webCtrl, x, y) {
                        controller.onScrollChanged(x, y);
                      },

                      // ────────────────────────────────────────────────────────
                      // LOCATION
                      // ────────────────────────────────────────────────────────
                      onGeolocationPermissionsShowPrompt:
                          (webCtrl, origin) async {
                            return controller.handleGeolocationPermission(
                              webCtrl,
                              origin,
                            );
                          },

                      // ────────────────────────────────────────────────────────
                      // DOWNLOAD
                      // ────────────────────────────────────────────────────────
                      onDownloadStartRequest:
                          (webCtrl, downloadStartRequest) async {
                            final url = downloadStartRequest.url.toString();

                            print('Download requested: $url');

                            await controller.download(url);
                          },

                      // ────────────────────────────────────────────────────────
                      // CONSOLE
                      // ────────────────────────────────────────────────────────
                      onConsoleMessage: (webCtrl, consoleMessage) {
                        controller.onConsoleMessage(consoleMessage);
                      },

                      // ────────────────────────────────────────────────────────
                      // URL OVERRIDE
                      // ────────────────────────────────────────────────────────
                      shouldOverrideUrlLoading:
                          (webCtrl, navigationAction) async {
                            return controller.handleUrlLoading(
                              webCtrl,
                              navigationAction,
                            );
                          },

                      // ────────────────────────────────────────────────────────
                      // NEW WINDOW
                      // ────────────────────────────────────────────────────────
                      onCreateWindow: (webCtrl, createWindowRequest) async {
                        final windowId = createWindowRequest.windowId;

                        print('New WebView window: $windowId');

                        Get.to(
                          () => NewWindowPage(windowId: windowId),
                          transition: Transition.cupertino,
                          duration: const Duration(milliseconds: 500),
                        );

                        return true;
                      },
                    ),

                    Obx(
                      () => Align(
                        alignment: Alignment.bottomCenter,

                        child: FadeIn(
                          child:
                              (controller.isLoading.value ||
                                  controller.currentUrl.value.isEmpty)
                              ? LoadingLottieWidget(showColor: true)
                              : const SizedBox.shrink(),
                        ),
                      ),
                    ),

                    Obx(
                      () => controller.isSessionExpired.value
                          ? SessionExpiredWidget(
                              onLogin: () async {
                                controller.isLoading.value = true;
                                await ApiManager.instance.signOut();
                                Get.back();
                              },
                            )
                          : SizedBox.shrink(),
                    ),
                  ],
                ),
              ),

              // ── BOTTOM BAR ───────────────────────────────────────────
              // Obx(
              //   () => AnimatedContainer(
              //     duration: const Duration(milliseconds: 300),
              //     curve: Curves.easeInOut,
              //     height: controller.isChromeVisible.value
              //         ? _kBottomBarHeight
              //         : 0.0,
              //     child: ClipRect(child: _BottomNavBar(controller: controller)),
              //   ),
              // ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _handleBackPress(BuildContext context) async {
    // If webview can go back — just go back in history
    if (controller.canGoBack.value) {
      log(
        controller.canGoBack.value.toString(),
        name: "controller.canGoBack.value",
      );
      await controller.goBack();
      return;
    }

    // 2. Navigation stack has pages — go back to previous screen
    if (Navigator.canPop(context)) {
      log(
        Navigator.canPop(context).toString(),
        name: "Navigator.canPop(context)",
      );
      controller.closeScreen();
      return;
    }

    // No history left — show exit dialog
    Get.dialog(
      Dialog(
        backgroundColor: AppColors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: AppColors.grey200, width: 0.8),
        ),
        elevation: 0,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: AppColors.shadowColor,
                offset: const Offset(0, 4),
                blurRadius: 20,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // ── Icon ────────────────────────────────────────
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: AppColors.lightAccent.withOpacity(0.35),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.logout_rounded,
                    color: AppColors.lightPrimary,
                    size: 24,
                  ),
                ),

                16.verticalSpace,

                // ── Title ────────────────────────────────────────
                Text(
                  'Leave this page?',
                  style: GoogleFonts.poppins(
                    color: AppColors.textOnLight,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),

                8.verticalSpace,

                Text(
                  'You are about to close the current session.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.dmSans(
                    color: AppColors.grey600,
                    fontSize: 13,
                    height: 1.5,
                  ),
                ),

                24.verticalSpace,

                // ── Close + Stay row ─────────────────────────────
                Row(
                  children: [
                    // Stay
                    Expanded(
                      child: SizedBox(
                        height: 55.h,
                        child: OutlinedButton(
                          onPressed: Get.back,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.textOnLight,
                            side: const BorderSide(
                              color: AppColors.grey300,
                              width: 1,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Text(
                            'Stay',
                            style: GoogleFonts.dmSans(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                    ),

                    10.horizontalSpace,

                    // Close
                    Expanded(
                      child: SizedBox(
                        height: 55.h,
                        child: ElevatedButton(
                          onPressed: () {
                            Get.back(); // close dialog
                            SystemNavigator.pop();
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.accentRed,
                            foregroundColor: AppColors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Text(
                            'Close',
                            style: GoogleFonts.dmSans(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),

                10.verticalSpace,

                // ── Project list full-width button ────────────────
                SizedBox(
                  width: double.infinity,
                  height: 55.h,
                  child: TextButton.icon(
                    onPressed: () {
                      Get.back(); // close dialog
                      Get.to(
                        () => const ProjectView(),
                        binding: ProjectBinding(),
                        transition: Transition.upToDown,
                      );
                    },
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.lightPrimary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: const BorderSide(
                          color: AppColors.lightPrimary,
                          width: 0.8,
                        ),
                      ),
                    ),
                    icon: const Icon(Icons.grid_view_rounded, size: 16),
                    label: Text(
                      'Go to Project List',
                      style: GoogleFonts.dmSans(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      barrierDismissible: true,
      barrierColor: AppColors.grey900.withOpacity(0.4),
    );
  }
}

// ────────────────────────────────────────────────────────────────────
// Top Bar
// ────────────────────────────────────────────────────────────────────
class _TopBar extends StatelessWidget {
  final WebViewController controller;
  const _TopBar({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: _kTopBarHeight,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: AppColors.white,
        border: const Border(
          bottom: BorderSide(color: AppColors.grey200, width: 0.8),
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadowColor,
            offset: const Offset(0, 2),
            blurRadius: 8,
          ),
        ],
      ),
      child: Row(
        spacing: 15.w,
        children: [
          Hero(tag: AppHeroTags.splashLogo, child: const AxpertLogo(width: 30)),

          const Spacer(),
          GestureDetector(
            onTap: () {
              Get.to(
                () => const ProjectView(),
                binding: ProjectBinding(),
                transition: Transition.upToDown,
              );
            },
            child: CircleAvatar(
              backgroundColor: AppColors.grey100,
              child: Image.asset(
                "assets/icons/project_icon.png",
                width: 24.w,
                color: AppColors.textOnLight,
              ),
            ),
          ),
          GestureDetector(
            onTap: () {
              // Get.to(
              //   () => const ProjectView(),
              //   binding: ProjectBinding(),
              //   transition: Transition.upToDown,
              // );
            },
            child: CircleAvatar(
              backgroundColor: AppColors.grey100,
              child: Icon(
                Icons.insert_page_break_rounded,
                color: AppColors.textOnLight,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────────────
// Bottom Nav Bar
// ────────────────────────────────────────────────────────────────────
class _BottomNavBar extends StatelessWidget {
  final WebViewController controller;
  const _BottomNavBar({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Obx(
      () => Container(
        height: _kBottomBarHeight,
        padding: const EdgeInsets.symmetric(horizontal: 24),
        decoration: BoxDecoration(
          color: controller.isLoading.value ? null : AppColors.white,
          border: const Border(
            top: BorderSide(color: AppColors.grey200, width: 0.8),
          ),
          // boxShadow: [
          //   BoxShadow(
          //     color: AppColors.shadowColor,
          //     offset: const Offset(0, -2),
          //     blurRadius: 8,
          //   ),
          // ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            Obx(
              () => _NavButton(
                icon: Icons.arrow_back_ios_rounded,
                enabled: controller.canGoBack.value,
                onTap: controller.goBack,
              ),
            ),
            Obx(
              () => _NavButton(
                icon: Icons.arrow_forward_ios_rounded,
                enabled: controller.canGoForward.value,
                onTap: controller.goForward,
              ),
            ),
            Obx(
              () => Spin(
                animate: controller.isLoading.value,
                child: _NavButton(
                  icon: Icons.refresh_rounded,
                  enabled: true,
                  onTap: controller.reload,
                ),
              ),
            ),
            _NavButton(
              icon: Icons.close_rounded,
              enabled: true,
              onTap: controller.closeScreen,
              activeColor: AppColors.accentRed,
            ),
          ],
        ),
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;
  final Color activeColor;

  const _NavButton({
    required this.icon,
    required this.enabled,
    required this.onTap,
    this.activeColor = AppColors.textOnLight,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 200),
        opacity: enabled ? 1.0 : 0.3,
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: AppColors.grey100,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.grey200, width: 0.8),
          ),
          child: Icon(icon, color: activeColor, size: 18),
        ),
      ),
    );
  }
}

class NewWindowPage extends StatefulWidget {
  final int windowId;

  const NewWindowPage({super.key, required this.windowId});

  @override
  State<NewWindowPage> createState() => _NewWindowPageState();
}

class _NewWindowPageState extends State<NewWindowPage> {
  InAppWebViewController? controller;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: InAppWebView(
          windowId: widget.windowId,

          initialSettings: InAppWebViewSettings(
            javaScriptEnabled: true,
            domStorageEnabled: true,
            databaseEnabled: true,
            javaScriptCanOpenWindowsAutomatically: true,
            useShouldOverrideUrlLoading: true,
            supportMultipleWindows: true,
            transparentBackground: true,
          ),

          onWebViewCreated: (webCtrl) {
            controller = webCtrl;
          },

          onConsoleMessage: (controller, consoleMessage) {
            print(
              'New window console: '
              '$consoleMessage',
            );
          },

          onDownloadStartRequest: (controller, downloadStartRequest) async {
            final url = downloadStartRequest.url.toString();

            // Use your new download implementation.
            print('New window download: $url');
          },
        ),
      ),
    );
  }
}
