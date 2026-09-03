import 'dart:ui';

import 'package:axpert/app/controller/global_controller.dart';
import 'package:axpert/app/data/services/storage/storage_service.dart';

import '../../../core/common.dart';
import '../auto_sync/sync.dart';
import '../controller/offline_form_controller.dart';
import '../models/models.dart';
import '../widgets/widgets.dart';

class OfflineListingPage extends GetView<OfflineFormController> {
  const OfflineListingPage({super.key});

  @override
  Widget build(BuildContext context) {
    // Get.put(OfflineStaticFormController());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      controller.getAllPages();
    });

    return Scaffold(
      drawer: _buildDrawer(context),

      appBar: AppBar(
        elevation: 0,
        backgroundColor: Color(0xFFF8F7F4),
        foregroundColor: AppColors.AXMDark,
        leading: Builder(
          builder: (ctx) {
            return IconButton(
              icon: const Icon(Icons.menu),
              onPressed: () {
                Scaffold.of(ctx).openDrawer();
              },
            );
          },
        ),
        automaticallyImplyLeading: false,
        title: Text(
          "Offline Forms",
          style: GoogleFonts.poppins(
            fontSize: 14.sp,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
      //       floatingActionButton: FloatingActionButton(onPressed: () async{
      //           final String sessionId =
      //         await AppStorage().retrieveValue(AppStorage.SESSIONID) ?? "";
      //  await  OfflineDbModule.tempCallActivemessageData(queueId: "1783573212667",sessionId: sessionId);
      //       }),
      bottomNavigationBar: Column(
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
                              color: AppColors.baseBlue.withValues(alpha: 0.1),
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
      backgroundColor: Color(0xFFF8F7F4),
      body: Column(
        children: [
          SizedBox(height: 20),
          Expanded(
            child: Obx(() {
              var sortedList = controller.allPages.where(
                (p) => p.pageType.toLowerCase() == 'form',
              );

              return GridView.builder(
                padding: EdgeInsets.symmetric(horizontal: 10),
                itemCount: sortedList.length,
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  childAspectRatio: 1,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                ),
                // itemBuilder: (context, index) => _pageTile(
                //   controller.allPages[index],
                //   index,
                // ),
                itemBuilder: (_, index) {
                  return _getGridTile(index);

                  // if (page.transId != "inward_entry") {
                  //   return OfflinePageCardCupertino(
                  //     page: page,
                  //     index: index,
                  //     onTap: () => controller.loadPage(page),
                  //     useColoredTile: true,
                  //   );

                  //   // return CircleAvatar();
                  // } else {
                  //   final rawpage = controller.allRawPages[index];
                  //   return SquareActionTile(
                  //     icon: Icons.pages,
                  //     title: rawpage["caption"],
                  //     onTap: () async {
                  //       await inwardEntryDynamicController.prepareForm(rawpage);
                  //       Get.to(
                  //         () => InwardEntryDynamicPageV1(schema: rawpage),
                  //         transition: Transition.rightToLeft,
                  //       );
                  //     },
                  //   );
                  // }
                },
              );
            }),
          ),
        ],
      ),
      // floatingActionButton: FloatingActionButton(
      //   onPressed:
      //   child: Icon(Icons.pages),
      // ),
    );
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

  Widget _getGridTile(int index) {
    var sortedList = controller.allPages
        .where((p) => p.pageType.toLowerCase() == 'form')
        .toList();
    final page = sortedList[index];
    // final rawPage = controller.allRawPages[index];

    if (page.pageType == "form") {
      // if (page.transId == "inward_entry") {

      return FormActionTile(
        icon: Icons.pages,
        title: page.caption,
        onTap: () async {
          await controller.prepareForm(page.schema).then((_) {
            Get.toNamed(Routes.OFFLINE_FORM_PAGE);
          });
          // Get.to(
          //   () => InwardEntryDynamicPageV1(schema: rawPage),
          //   transition: Transition.rightToLeft,
          // );
        },
      );
      // return FormActionTile(
      //   icon: Icons.pages,
      //   title: rawPage["caption"],
      //   onTap: () => controller.loadPage(page),
      // );
      // } else {
      //   return OfflinePageCardCupertino(
      //     page: page,
      //     index: index,
      //     onTap: () => controller.loadPage(page),
      //     useColoredTile: true,
      //   );
      // }

      // return OfflinePageCardCupertino(
      //   page: page,
      //   index: index,
      //   onTap: () => controller.loadPage(page),
      //   useColoredTile: true,
      // );
    } else if (page.pageType == "iview") {
      return Obx(
        () => ReportActionTile(
          isDisabled: !controller.isConnected.value,
          icon: Icons.report,
          title: page.caption,
          onTap: () {
            controller.onReportCardClick(page.transId);
          },
        ),
      );
    } else {
      return SizedBox.shrink();
    }
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
                    title: "Sync All",
                    subtitle: "Push pending & refetch everything",
                    onTap: controller.actionSyncAll,
                  ),
                  _simpleRow(
                    icon: Icons.description,
                    color: Colors.indigo,
                    title: "Refetch Forms",
                    subtitle: "Reload offline forms",
                    onTap: controller.actionRefetchForms,
                  ),
                  _simpleRow(
                    icon: Icons.storage,
                    color: Colors.teal,
                    title: "Refetch Datasources",
                    subtitle: "Reload lookup data",
                    onTap: controller.actionRefetchDatasources,
                  ),
                  _simpleRow(
                    icon: Icons.unarchive_rounded,
                    color: Colors.teal,
                    title: "Export Database",
                    subtitle: "Backup offline DB for debugging",
                    onTap: controller.actionExportDatabase,
                  ),
                  _simpleRow(
                    icon: Icons.archive_rounded,
                    color: Colors.deepOrange,
                    title: "Import Database",
                    subtitle: "Restore or overwrite local DB file",
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
                      title: "Push Pending records",
                      subtitle: "Upload pending records to server",
                      onTap: controller.actionPushPendingByCachedSave,
                      badge: controller.pendingCount.value != 0
                          ? controller.pendingCount.value.toString()
                          : null,
                    ),
                  ),
                  Obx(
                    () => _simpleRow(
                      icon: Icons.refresh_sharp,
                      color: Colors.deepOrange,
                      title: "Queue status",
                      subtitle: "Refresh pending queues from server",
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
                              title: "Clear Pending Queue",
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
                              title: "Clear ALL Offline Data",
                              subtitle: "Deletes everything except user",
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
        leading: Icon(icon, size: 20, color: iconColor),
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
