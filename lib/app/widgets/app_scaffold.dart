import '../core/common.dart';

class AppScaffold extends StatelessWidget {
  final Widget? body;
  final PreferredSizeWidget? appBar;

  final Widget? floatingActionButton;
  final FloatingActionButtonLocation? floatingActionButtonLocation;

  final Widget? drawer;
  final Widget? endDrawer;

  final Widget? bottomNavigationBar;
  final Widget? bottomSheet;

  final Widget? persistentFooterButtons;

  final bool resizeToAvoidBottomInset;
  final bool extendBody;
  final bool extendBodyBehindAppBar;
  final bool safeArea;

  final EdgeInsetsGeometry padding;

  const AppScaffold({
    super.key,
    this.body,
    this.appBar,
    this.floatingActionButton,
    this.floatingActionButtonLocation,
    this.drawer,
    this.endDrawer,
    this.bottomNavigationBar,
    this.bottomSheet,
    this.persistentFooterButtons,
    this.resizeToAvoidBottomInset = true,
    this.extendBody = true,
    this.extendBodyBehindAppBar = true,
    this.safeArea = false,
    this.padding = EdgeInsetsGeometry.zero,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,

        statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,

        statusBarBrightness: isDark ? Brightness.dark : Brightness.light,

        systemNavigationBarColor: Colors.transparent,

        systemNavigationBarDividerColor: Colors.transparent,

        systemNavigationBarIconBrightness: isDark
            ? Brightness.light
            : Brightness.dark,
      ),
      child: Container(
        decoration: BoxDecoration(gradient: context.colors.scaffoldGradient),
        child: Scaffold(
          backgroundColor: Colors.transparent,

          appBar: appBar,

          body: safeArea
              ? SafeArea(
                  child: Padding(
                    padding: padding,
                    child: body ?? 1.horizontalSpace,
                  ),
                )
              : Padding(padding: padding, child: body),

          drawer: drawer,
          endDrawer: endDrawer,

          floatingActionButton: floatingActionButton,
          floatingActionButtonLocation: floatingActionButtonLocation,

          bottomNavigationBar: bottomNavigationBar,
          bottomSheet: bottomSheet,

          resizeToAvoidBottomInset: resizeToAvoidBottomInset,

          extendBody: extendBody,
          extendBodyBehindAppBar: extendBodyBehindAppBar,
        ),
      ),
    );
  }
}
