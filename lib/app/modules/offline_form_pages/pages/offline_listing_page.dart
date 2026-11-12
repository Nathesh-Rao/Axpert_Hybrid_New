import 'dart:ui';

import 'package:axpert/app/controller/global_controller.dart';
import 'package:axpert/app/data/services/storage/storage_service.dart';
import 'package:flutter/cupertino.dart';

import '../../../core/common.dart';
import '../auto_sync/sync.dart';
import '../controller/offline_form_controller.dart';
import '../db/db.dart';
import '../models/models.dart';
import '../widgets/offline_send_status_banner.dart';

class OfflineListingPage extends StatefulWidget {
  const OfflineListingPage({super.key});

  @override
  State<OfflineListingPage> createState() => _OfflineListingPageState();
}

class _OfflineListingPageState extends State<OfflineListingPage> {
  late final controller = Get.find<OfflineFormController>();
  bool _listView = false;
  String _query = '';

  static const _formAccentColors = <(Color, Color)>[
    (Color(0xFF3045A7), Color(0xFFEDF1FF)),
    (Color(0xFFB45309), Color(0xFFFFF1E2)),
    (Color(0xFF7046B9), Color(0xFFF1EAFE)),
    (Color(0xFF237A59), Color(0xFFE6F5ED)),
    (Color(0xFF0F7490), Color(0xFFE4F5F9)),
    (Color(0xFFB74468), Color(0xFFFFEAF0)),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        controller.getAllPages();
        _loadLastRefresh();
      }
    });
  }

  Future<void> _loadLastRefresh() async {
    final timestamp = await OfflineDbModule.getLastSyncedTimestamp();
    if (mounted && timestamp != null && timestamp.isNotEmpty) {
      OfflineBackgroundSyncService.instance.lastSyncedAt.value = timestamp;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      drawer: _buildDrawer(context),
      //       floatingActionButton: FloatingActionButton(onPressed: () async{
      //           final String sessionId =
      //         await AppStorage().retrieveValue(AppStorage.SESSIONID) ?? "";
      //  await  OfflineDbModule.tempCallActivemessageData(queueId: "1783573212667",sessionId: sessionId);
      //       }),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Obx(
              () => Visibility(
                visible: OfflineBackgroundSyncService.instance.isSyncing.value,
                child: Container(
                  margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: AppColors.baseBlue.withValues(alpha: 0.15),
                      width: 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.baseBlue.withValues(alpha: 0.05),
                        blurRadius: 10,
                        spreadRadius: 0,
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                      child: Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.baseBlue.withValues(alpha: 0.08),
                        ),
                        child: Row(
                          children: [
                            // Leading Icon
                            Container(
                              padding: EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: AppColors.baseBlue.withValues(
                                  alpha: 0.1,
                                ),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.cloud_sync_rounded,
                                color: AppColors.baseBlue,
                                size: 16,
                              ),
                            ),
                            SizedBox(width: 12),

                            // Text Hierarchy
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    "Background sync is active.",
                                    style: GoogleFonts.poppins(
                                      color: AppColors.baseBlue,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13,
                                    ),
                                  ),
                                  Text(
                                    OfflineBackgroundSyncService
                                        .instance
                                        .statusMessage
                                        .value,
                                    style: GoogleFonts.poppins(
                                      color: AppColors.baseBlue.withValues(
                                        alpha: 0.7,
                                      ),
                                      fontWeight: FontWeight.w500,
                                      fontSize: 11,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),

                            // Trailing Spinner
                            SizedBox(width: 12),
                            SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: AppColors.baseBlue,
                                strokeCap: StrokeCap.round,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            _datSourcefetchWidget(),
          ],
        ),
      ),
      backgroundColor: theme.brightness == Brightness.dark
          ? theme.colorScheme.surface
          : const Color(0xFFF3F5FB),
      body: SafeArea(top: false, child: _buildDashboard()),
    );
  }

  Widget _buildDashboard() {
    return Obx(() {
      final forms = controller.allPages
          .where((page) => page.pageType.toLowerCase() == 'form')
          .toList();
      final matches = forms
          .where((page) => page.caption.toLowerCase().contains(_query))
          .toList();
      final loading = forms.isEmpty && controller.isLoading.value;

      return CustomScrollView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        slivers: [
          SliverToBoxAdapter(child: _buildOverview(forms.length)),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            sliver: SliverToBoxAdapter(child: _buildFormControls()),
          ),
          if (matches.isEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Center(
                  child: loading
                      ? const CircularProgressIndicator()
                      : Text(
                          forms.isEmpty
                              ? 'No forms available offline'
                              : 'No matching forms',
                          textAlign: TextAlign.center,
                        ),
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 72),
              sliver: _buildForms(matches),
            ),
        ],
      );
    });
  }

  Widget _buildOverview(int formCount) {
    final theme = Theme.of(context);
    final syncService = OfflineBackgroundSyncService.instance;
    return Stack(
      children: [
        Positioned.fill(
          bottom: 44,
          child: ClipRect(
            child: Stack(
              fit: StackFit.expand,
              children: [
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFF252B65), Color(0xFF454FAB)],
                    ),
                  ),
                ),
                Positioned(
                  top: -120,
                  right: -115,
                  child: Container(
                    width: 330,
                    height: 330,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          Color(0xFFE0A152),
                          Color(0x88A98470),
                          Color(0x005D67B9),
                        ],
                        stops: [0, 0.52, 1],
                      ),
                      border: Border.all(color: Color(0x33FFFFFF)),
                    ),
                  ),
                ),
                Positioned(
                  top: -150,
                  right: -145,
                  child: Container(
                    width: 390,
                    height: 390,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Color(0x1FFFFFFF), width: 18),
                    ),
                  ),
                ),
                Positioned(
                  top: -110,
                  right: -105,
                  child: Container(
                    width: 310,
                    height: 310,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Color(0x1FFFFFFF)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(
            16,
            MediaQuery.paddingOf(context).top + 4,
            16,
            4,
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Builder(
                    builder: (ctx) => IconButton(
                      tooltip: 'Open offline menu',
                      onPressed: () => Scaffold.of(ctx).openDrawer(),
                      color: Colors.white,
                      icon: const Icon(Icons.menu_rounded, size: 27),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      'Offline Forms',
                      style: theme.textTheme.titleLarge?.copyWith(
                        color: Colors.white,
                        fontSize: 19,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Obx(
                    () => IconButton(
                      tooltip: 'Offline notifications',
                      onPressed: controller.openOfflineNotifications,
                      color: Colors.white,
                      icon: Badge(
                        backgroundColor: const Color(0xFFF3AB57),
                        textColor: const Color(0xFF20244C),
                        isLabelVisible:
                            controller.unreadOfflineNotifications.value > 0,
                        label: Text(
                          controller.unreadOfflineNotifications.value > 99
                              ? '99+'
                              : controller.unreadOfflineNotifications.value
                                    .toString(),
                        ),
                        child: const Icon(Icons.notifications_none_rounded),
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: controller.openOfflinesettings,
                    tooltip: 'Offline settings',
                    color: Colors.white,
                    icon: const Icon(Icons.tune_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: const Color(0x29FFFFFF),
                      border: Border.all(color: const Color(0x55FFFFFF)),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(
                      Icons.cloud_off_outlined,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '$formCount ${formCount == 1 ? 'form' : 'forms'} available offline',
                          style: theme.textTheme.titleLarge?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Obx(
                          () => Text(
                            _lastRefreshLabel(syncService.lastSyncedAt.value),
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: const Color(0xFFE1E5FF),
                            ),
                          ),
                        ),
                        if (formCount > 0) ...[
                          const SizedBox(height: 8),
                          DecoratedBox(
                            decoration: BoxDecoration(
                              color: const Color(0xFF365874),
                              borderRadius: BorderRadius.circular(18),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 8,
                                    height: 8,
                                    decoration: const BoxDecoration(
                                      color: Color(0xFF7ED69C),
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Ready to work offline',
                                    style: theme.textTheme.labelMedium
                                        ?.copyWith(
                                          color: const Color(0xFFD6FFEA),
                                          fontWeight: FontWeight.w700,
                                        ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Obx(
                () => OfflineSendStatusBanner(
                  state: controller.dashboardSendStatus,
                  onSend: controller.actionPushPendingByCachedSave,
                  onNotifications: controller.openOfflineNotifications,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _lastRefreshLabel(String? timestamp) {
    if (timestamp == null || timestamp.isEmpty) return 'Not refreshed yet';
    try {
      final refreshed = DateTime.parse(timestamp).toLocal();
      final now = DateTime.now();
      final day = DateTime(refreshed.year, refreshed.month, refreshed.day);
      final today = DateTime(now.year, now.month, now.day);
      final dateLabel = day == today
          ? 'today'
          : day == today.subtract(const Duration(days: 1))
          ? 'yesterday'
          : '${refreshed.month}/${refreshed.day}/${refreshed.year}';
      final time = MaterialLocalizations.of(
        context,
      ).formatTimeOfDay(TimeOfDay.fromDateTime(refreshed));
      return 'Last refreshed $dateLabel at $time';
    } catch (_) {
      return 'Last refreshed time unavailable';
    }
  }

  Widget _buildFormControls() {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Offline Forms',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            DecoratedBox(
              decoration: BoxDecoration(
                color: const Color(0xFFEAF0FB),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _viewToggle(
                      Icons.grid_view_rounded,
                      'Grid view',
                      !_listView,
                      () => setState(() => _listView = false),
                    ),
                    _viewToggle(
                      Icons.format_list_bulleted_rounded,
                      'List view',
                      _listView,
                      () => setState(() => _listView = true),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        TextField(
          onChanged: (text) =>
              setState(() => _query = text.trim().toLowerCase()),
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(
            hintText: 'Search forms',
            prefixIcon: const Icon(Icons.search_rounded),
            filled: true,
            fillColor: theme.colorScheme.surface,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: Color(0xFFDCE3F1)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(
                color: Color(0xFF5268C8),
                width: 1.4,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _viewToggle(
    IconData icon,
    String tooltip,
    bool selected,
    VoidCallback onPressed,
  ) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: selected ? Colors.white : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(10),
          child: SizedBox(
            width: 42,
            height: 42,
            child: Icon(
              icon,
              size: 20,
              color: selected
                  ? const Color(0xFF3045A7)
                  : const Color(0xFF63708D),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildForms(List<OfflineFormPageModel> forms) {
    if (_listView) {
      return SliverList.separated(
        itemCount: forms.length,
        itemBuilder: (context, index) => _formCard(forms[index], compact: true),
        separatorBuilder: (context, index) => const SizedBox(height: 10),
      );
    }

    return SliverLayoutBuilder(
      builder: (context, constraints) {
        final scaledText = MediaQuery.textScalerOf(context).scale(14);
        final columns = constraints.crossAxisExtent < 270 || scaledText > 22
            ? 1
            : constraints.crossAxisExtent >= 590
            ? 3
            : 2;
        return SliverGrid.builder(
          itemCount: forms.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            mainAxisExtent: 82 + 1.2 * scaledText,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
          ),
          itemBuilder: (context, index) =>
              _formCard(forms[index], compact: false),
        );
      },
    );
  }

  Widget _formCard(OfflineFormPageModel page, {required bool compact}) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final (iconColor, iconBackground) = _formAccentFor(page.caption);
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(18),
      side: BorderSide(
        color: dark ? const Color(0xFF343A50) : const Color(0xFFDCE3F1),
      ),
    );
    final icon = Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: dark ? iconBackground.withValues(alpha: 0.2) : iconBackground,
        borderRadius: BorderRadius.circular(13),
      ),
      child: Icon(Icons.description_outlined, size: 22, color: iconColor),
    );
    final caption = Text(
      page.caption,
      maxLines: compact ? null : 2,
      overflow: compact ? null : TextOverflow.ellipsis,
      style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
    );
    final chevron = Icon(
      Icons.chevron_right_rounded,
      size: 20,
      color: theme.colorScheme.onSurfaceVariant,
    );
    return Material(
      color: theme.colorScheme.surface,
      elevation: 2,
      shadowColor: const Color(0x2614254B),
      shape: shape,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () async {
          await controller.prepareForm(page.schema);
          Get.toNamed(Routes.OFFLINE_FORM_PAGE);
        },
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: compact
              ? Row(
                  children: [
                    icon,
                    const SizedBox(width: 12),
                    Expanded(child: caption),
                    chevron,
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [icon, chevron],
                    ),
                    const SizedBox(height: 8),
                    caption,
                  ],
                ),
        ),
      ),
    );
  }

  (Color, Color) _formAccentFor(String title) {
    final normalized = title.trim().toLowerCase();
    var hash = normalized.length;
    for (final codeUnit in normalized.codeUnits) {
      hash = (hash * 31 + codeUnit) & 0x7fffffff;
    }
    return _formAccentColors[hash % _formAccentColors.length];
  }

  Widget _datSourcefetchWidget() {
    return Obx(() {
      if (!GlobalVariableController.to.isDataSourcefetchingOnStart.value) {
        return SizedBox.shrink();
      }
      final int completed =
          GlobalVariableController.to.completedDsCountOnStart.value;
      final int total = GlobalVariableController.to.totalDsCountOnStart.value;
      final double progress = total > 0 ? (completed / total) : 0.0;

      return Container(
        margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: AppColors.baseBlue.withValues(alpha: 0.15),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.baseBlue.withValues(alpha: 0.05),
              blurRadius: 10,
              spreadRadius: 0,
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.baseBlue.withValues(alpha: 0.08),
              ),
              child: Row(
                children: [
                  SizedBox(
                    height: 42,
                    width: 42,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Container(
                          padding: EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppColors.baseBlue.withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Spin(
                            infinite: true,
                            child: Icon(
                              Icons.sync_rounded,
                              color: AppColors.baseBlue,
                              size: 16,
                            ),
                          ),
                        ),
                        Positioned.fill(
                          child: CircularProgressIndicator(
                            value:
                                progress, // Dynamically updates based on count
                            strokeWidth: 2.5,
                            backgroundColor: AppColors.baseBlue.withValues(
                              alpha: 0.15,
                            ),
                            color: AppColors.baseBlue,
                            strokeCap: StrokeCap.round,
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(
                    width: 16,
                  ), // A bit more spacing to accommodate the new circle size
                  // Text Hierarchy
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          "Syncing DataSources",
                          style: GoogleFonts.poppins(
                            color: AppColors.baseBlue,
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                        Text(
                          "Syncing $completed of $total",
                          style: GoogleFonts.poppins(
                            color: AppColors.baseBlue.withValues(alpha: 0.7),
                            fontWeight: FontWeight.w500,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    });
  }

  Widget _buildDrawer(BuildContext context) {
    final bg = const Color(0xFFF8F7F4);
    return Drawer(
      backgroundColor: bg,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ===== HEADER =====
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              child: Text(
                "Offline Data Manager",
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.AXMDark,
                ),
              ),
            ),
            Divider(height: 1, color: Colors.grey.shade300),

            Expanded(
              child: ListView(
                children: [
                  _sectionHeader("Sync"),
                  _simpleRow(
                    icon: Icons.sync,
                    color: AppColors.darkBlue,
                    title: "Refresh",
                    subtitle: "Refresh all offline forms or choose a form",
                    onTap: controller.actionRefresh,
                  ),
                  _simpleRow(
                    icon: Icons.unarchive_rounded,
                    color: Colors.teal,
                    title: "Export Offline Backup",
                    subtitle: "Save a backup of your offline data",
                    onTap: controller.actionExportDatabase,
                  ),
                  _simpleRow(
                    icon: Icons.archive_rounded,
                    color: Colors.deepOrange,
                    title: "Restore Offline Backup",
                    subtitle:
                        "Restore a backup and replace current offline data",
                    onTap: controller.actionImportDatabase,
                  ),
                  // _simpleRow(
                  //   icon: Icons.restart_alt_rounded,
                  //   color: Colors.brown,
                  //   title: "Sync Settings",
                  //   subtitle: "configure your background sync",
                  //   onTap: () {
                  //     // Get.to(() => SyncSettingsScreen());
                  //   },
                  // ),
                  Divider(height: 1, color: Colors.grey.shade300),
                  _sectionHeader("Queue"),

                  // Obx(() => _simpleRow(
                  //       icon: Icons.upload_file,
                  //       color: Colors.deepOrange,
                  //       title: "Push Pending Uploads",
                  //       subtitle: "Upload queued data to server",
                  //       onTap: offlineFormController.actionPushPending,
                  //       badge: offlineFormController.pendingCount.value != 0
                  //           ? offlineFormController.pendingCount.value
                  //               .toString()
                  //           : null,
                  //     )),
                  Obx(
                    () => _simpleRow(
                      icon: Icons.upload,
                      color: Colors.green,
                      title: controller.sendPendingRecordsDisabled
                          ? 'Sending…'
                          : 'Send Pending Records',
                      subtitle: controller.sendPendingRecordsDisabled
                          ? 'Please wait for the current sync to finish'
                          : 'Send records saved offline to the server',
                      isDisabled: controller.sendPendingRecordsDisabled,
                      isBusy: controller.sendPendingRecordsDisabled,
                      onTap: () {
                        // Close only the drawer so the top banner is visible.
                        Navigator.of(context).pop();
                        controller.actionPushPendingByCachedSave();
                      },
                      badge: controller.pendingCount.value != 0
                          ? controller.pendingCount.value.toString()
                          : null,
                    ),
                  ),
                  Obx(
                    () => _simpleRow(
                      icon: Icons.refresh_sharp,
                      color: Colors.deepOrange,
                      title: "Check Submission Status",
                      subtitle: "Check the status of submitted records",
                      onTap: controller.actionRefreshQueues,
                      badge: controller.pendingQueuesCount.value != 0
                          ? controller.pendingQueuesCount.value.toString()
                          : null,
                    ),
                  ),

                  (StorageService.userRole ?? '') == 'default'
                      ? Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Divider(height: 1, color: Colors.grey.shade300),
                            Row(children: [_sectionHeader("Admin Panel")]),
                            // _simpleRow(
                            //   icon: Icons.delete_outline,
                            //   color: Colors.redAccent,
                            //   title: "Clear Forms Cache",
                            //   subtitle: "Remove offline forms",
                            //   onTap: offlineFormController.actionClearForms,
                            // ),
                            // _simpleRow(
                            //   icon: Icons.delete_sweep,
                            //   color: Colors.red,
                            //   title: "Clear Datasources Cache",
                            //   subtitle: "Remove cached datasources",
                            //   onTap: offlineFormController
                            //       .actionClearDatasources,
                            // ),
                            _simpleRow(
                              icon: Icons.clear_all,
                              color: Colors.brown,
                              title: "Delete Pending Submissions",
                              subtitle: "Delete all pending submissions",
                              onTap: controller.actionClearPending,
                            ),

                            // _simpleRow(
                            //   icon: Icons.history_edu_rounded,
                            //   color: Colors.blueGrey,
                            //   title: "View Audit Logs",
                            //   subtitle:
                            //       "Track user actions and system events",
                            //   onTap: () => Get.to(() => AuditLogPage()),
                            // ),
                            Divider(height: 1, color: Colors.grey.shade300),
                            Row(children: [_sectionHeader("Danger zone")]),
                            _simpleRow(
                              icon: Icons.warning,
                              color: Colors.red.shade900,
                              title: "Delete All Offline Data",
                              subtitle:
                                  "Remove all offline data except your user profile",
                              onTap: controller.actionClearAll,
                              isDanger: true,
                            ),
                          ],
                        )
                      : SizedBox.shrink(),

                  // : Center(
                  //     child:
                  //         Text(globalVariableController.USER_ROLE.value)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Text(
        title.toUpperCase(),
        style: GoogleFonts.poppins(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: AppColors.AXMGray,
          letterSpacing: 0.8,
        ),
      ),
    );
  }

  Widget _simpleRow({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    bool isDanger = false,
    bool isDisabled = false,
    bool isBusy = false,
    String? badge,
  }) {
    final Color iconColor = isDisabled ? Colors.grey.shade400 : color;

    final Color titleColor = isDisabled
        ? Colors.grey.shade400
        : (isDanger ? Colors.red : AppColors.AXMDark);

    final Color subTitleColor = isDisabled
        ? Colors.grey.shade300
        : AppColors.AXMGray;

    return Badge(
      isLabelVisible: badge != null,
      offset: Offset(-50, 0),
      backgroundColor: AppColors.maroon,
      label: Text(badge.toString()),
      textStyle: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 10),
      child: ListTile(
        dense: true,
        visualDensity: const VisualDensity(horizontal: 0, vertical: -2),
        enabled: !isDisabled,
        leading: isBusy
            ? SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: iconColor,
                ),
              )
            : Icon(icon, size: 20, color: iconColor),
        title: Text(
          title,
          style: GoogleFonts.poppins(
            fontSize: 13.5,
            fontWeight: FontWeight.w500,
            color: titleColor,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: GoogleFonts.poppins(fontSize: 11, color: subTitleColor),
        ),
        trailing: isDisabled ? null : const Icon(Icons.chevron_right, size: 18),
        onTap: isDisabled ? null : onTap,
      ),
    );
  }
}

class OfflinePageCardCupertino extends StatelessWidget {
  final OfflineFormPageModel page;
  final int index;
  final VoidCallback onTap;
  final bool useColoredTile;

  const OfflinePageCardCupertino({
    super.key,
    required this.page,
    required this.index,
    required this.onTap,
    this.useColoredTile = true,
  });

  @override
  Widget build(BuildContext context) {
    final Color accentColor = useColoredTile
        ? AppColors.getOfflineColorByIndex(index)
        : Colors.blueGrey.shade600;

    final Color bgColor = accentColor.withOpacity(0.12);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 10,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ---------- ICON ----------
            Container(
              height: 44,
              width: 44,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.9),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                Icons.description_outlined,
                size: 24,
                color: accentColor,
              ),
            ),

            const Spacer(),

            // ---------- TITLE ----------
            Text(
              page.caption,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),

            const SizedBox(height: 6),

            // ---------- ATTACHMENT INDICATOR ----------
            if (page.attachments)
              Row(
                children: [
                  Icon(Icons.attach_file, size: 14, color: accentColor),
                  const SizedBox(width: 4),
                  Text(
                    'Attachments',
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      color: Colors.black54,
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
