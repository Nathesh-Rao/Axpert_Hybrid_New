import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../widgets/connection_style.dart';
import '../../widgets/project_logo.dart';
import '../../data/enums/project_enums.dart';
import 'controller/project_controller.dart';
import 'widget/project_hero_qr_widget.dart';
import 'widget/connection_editor.dart';

class ProjectView extends GetView<ProjectController> {
  const ProjectView({super.key});
  @override
  Widget build(BuildContext context) => PopScope(
    canPop: false,
    onPopInvokedWithResult: (didPop, result) async {
      if (didPop) return;
      if (controller.currentTileState.value !=
          ProjectAddingState.defaultState) {
        controller.onTileCloseClick();
      } else {
        await controller.showExitConfirmationSheet();
      }
    },
    child: Scaffold(
      backgroundColor: ConnectionStyle.bg(context),
      bottomNavigationBar: Obx(() {
        if (controller.currentTileState.value !=
                ProjectAddingState.defaultState ||
            MediaQuery.viewInsetsOf(context).bottom > 0) {
          return const SizedBox.shrink();
        }
        return SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Text(
              'Powered by Axpert',
              textAlign: TextAlign.center,
              style: ConnectionStyle.text(
                context,
                11,
                color: ConnectionStyle.muted(context),
              ),
            ),
          ),
        );
      }),
      body: Stack(
        children: [
          CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Stack(
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(bottom: 110),
                      child: ConnectionHero(
                        radius: 34,
                        child: SafeArea(
                          bottom: false,
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(22, 20, 22, 76),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const ConnectionMark(),
                                    const SizedBox(width: 10),
                                    Text(
                                      'Axpert',
                                      style: ConnectionStyle.text(
                                        context,
                                        18,
                                        weight: FontWeight.w700,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 22),
                                Text(
                                  _greeting(),
                                  style: ConnectionStyle.text(
                                    context,
                                    13,
                                    color: Colors.white70,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  "Let's connect\nyour workspace",
                                  style: ConnectionStyle.text(
                                    context,
                                    27,
                                    weight: FontWeight.w800,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: 0,
                      left: 18,
                      right: 18,
                      child: Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: ConnectionStyle.card(context),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color: ConnectionStyle.line(context),
                          ),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x3316275C),
                              blurRadius: 30,
                              offset: Offset(0, 12),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 44,
                                  height: 44,
                                  decoration: BoxDecoration(
                                    color: ConnectionStyle.tint(context),
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: const Icon(
                                    Icons.power_outlined,
                                    color: ConnectionStyle.navy,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Add a connection',
                                        style: ConnectionStyle.text(
                                          context,
                                          16,
                                          weight: FontWeight.w700,
                                        ),
                                      ),
                                      const SizedBox(height: 3),
                                      Text(
                                        'Scan a QR code or enter your project URL.',
                                        style: ConnectionStyle.text(
                                          context,
                                          12,
                                          color: ConnectionStyle.muted(context),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Expanded(
                                  child: ConnectionButton(
                                    label: 'Scan QR',
                                    icon: Icons.qr_code_scanner,
                                    orange: true,
                                    onPressed: controller.onScanQRClick,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: ConnectionButton(
                                    label: 'Add URL',
                                    icon: Icons.link,
                                    soft: true,
                                    onPressed: controller.onAddManuallyClick,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(22, 24, 22, 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Connected apps',
                          style: ConnectionStyle.text(
                            context,
                            15,
                            weight: FontWeight.w700,
                          ),
                        ),
                      ),
                      Obx(
                        () => Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: ConnectionStyle.tint(context),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '${controller.projects.length} active',
                            style: ConnectionStyle.text(
                              context,
                              12,
                              weight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Obx(() {
                if (controller.isLoadingProjects.value) {
                  return const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.all(40),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                  );
                }
                if (controller.projects.isEmpty) {
                  return SliverFillRemaining(
                    hasScrollBody: false,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(18, 0, 18, 20),
                      child: Column(
                        children: [
                          Expanded(
                            child: Container(
                              width: double.infinity,
                              constraints: const BoxConstraints(minHeight: 160),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(22),
                                border: Border.all(
                                  color: ConnectionStyle.line(context),
                                ),
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(
                                    Icons.add_to_photos_outlined,
                                    size: 62,
                                    color: ConnectionStyle.orange,
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    'Connect your first app',
                                    style: ConnectionStyle.text(
                                      context,
                                      15,
                                      weight: FontWeight.w700,
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.all(12),
                                    child: Text(
                                      'Your projects appear here once you add a connection.',
                                      textAlign: TextAlign.center,
                                      style: ConnectionStyle.text(
                                        context,
                                        12,
                                        color: ConnectionStyle.muted(context),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }
                return SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  sliver: SliverList.builder(
                    itemCount: controller.projects.length,
                    itemBuilder: (context, index) {
                      final p = controller.projects.reversed.toList()[index];
                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: ConnectionStyle.card(context),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: ConnectionStyle.line(context),
                          ),
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 6,
                          ),
                          onTap: () => controller.onProjectTileClick(p),
                          leading: ProjectLogo(
                            url: p.logourl,
                            projectName: p.schemaName,
                            size: 42,
                          ),
                          title: Text(
                            p.caption.isEmpty ? p.schemaName : p.caption,
                            style: ConnectionStyle.text(
                              context,
                              14,
                              weight: FontWeight.w700,
                            ),
                          ),
                          subtitle: Text(
                            p.url,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: ConnectionStyle.text(
                              context,
                              12,
                              color: ConnectionStyle.muted(context),
                            ),
                          ),
                          trailing: PopupMenuButton<String>(
                            tooltip: 'Project options',
                            position: PopupMenuPosition.under,
                            offset: const Offset(0, 6),
                            color: ConnectionStyle.card(context),
                            surfaceTintColor: Colors.transparent,
                            elevation: 10,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                            constraints: const BoxConstraints(
                              minWidth: 240,
                              maxWidth: 280,
                            ),
                            icon: Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: ConnectionStyle.field(context),
                                border: Border.all(
                                  color: ConnectionStyle.line(context),
                                ),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(
                                Icons.more_horiz_rounded,
                                color: ConnectionStyle.muted(context),
                                size: 22,
                              ),
                            ),
                            onSelected: (action) async {
                              if (action == 'edit') {
                                controller.onEditProjectClick(p);
                                return;
                              }
                              final confirmed = await showDialog<bool>(
                                context: context,
                                builder: (c) => AlertDialog(
                                  backgroundColor: ConnectionStyle.card(c),
                                  surfaceTintColor: Colors.transparent,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(24),
                                  ),
                                  icon: Container(
                                    width: 56,
                                    height: 56,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: const Color(
                                        0xffC7364B,
                                      ).withValues(alpha: .1),
                                    ),
                                    child: const Icon(
                                      Icons.delete_outline_rounded,
                                      size: 28,
                                      color: Color(0xffC7364B),
                                    ),
                                  ),
                                  title: Text(
                                    'Remove connection?',
                                    style: ConnectionStyle.text(
                                      c,
                                      20,
                                      weight: FontWeight.w800,
                                    ),
                                  ),
                                  content: Text(
                                    'Remove ${p.caption.isEmpty ? p.schemaName : p.caption} from this device?',
                                    style: ConnectionStyle.text(
                                      c,
                                      14,
                                      color: ConnectionStyle.muted(c),
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(c, false),
                                      style: TextButton.styleFrom(
                                        foregroundColor: ConnectionStyle.muted(
                                          c,
                                        ),
                                      ),
                                      child: const Text('Cancel'),
                                    ),
                                    FilledButton(
                                      style: FilledButton.styleFrom(
                                        backgroundColor: const Color(
                                          0xffC7364B,
                                        ),
                                        foregroundColor: Colors.white,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                        ),
                                      ),
                                      onPressed: () => Navigator.pop(c, true),
                                      child: const Text('Remove'),
                                    ),
                                  ],
                                ),
                              );
                              if (confirmed == true && p.id != null) {
                                await controller.deleteProject(p.id!);
                              }
                            },
                            itemBuilder: (_) => [
                              PopupMenuItem<String>(
                                value: 'edit',
                                height: 72,
                                child: _projectAction(
                                  context,
                                  Icons.edit_outlined,
                                  'Edit',
                                  'Update connection details',
                                  ConnectionStyle.navy,
                                ),
                              ),
                              const PopupMenuDivider(height: 1),
                              PopupMenuItem<String>(
                                value: 'delete',
                                height: 72,
                                child: _projectAction(
                                  context,
                                  Icons.delete_outline_rounded,
                                  'Remove',
                                  'Remove from this device',
                                  const Color(0xffC7364B),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                );
              }),
              const SliverToBoxAdapter(child: SizedBox(height: 16)),
            ],
          ),
          Obx(() {
            final state = controller.currentTileState.value;
            if (state == ProjectAddingState.defaultState) {
              return const SizedBox.shrink();
            }
            return Positioned.fill(
              child: Stack(
                children: [
                  ModalBarrier(
                    color: Colors.black54,
                    dismissible: !controller.isProjectSaving.value,
                    onDismiss: controller.onTileCloseClick,
                  ),
                  Align(
                    alignment: Alignment.bottomCenter,
                    child: Container(
                      constraints: BoxConstraints(
                        maxHeight: MediaQuery.sizeOf(context).height * .88,
                      ),
                      padding: EdgeInsets.fromLTRB(
                        20,
                        12,
                        20,
                        MediaQuery.viewInsetsOf(context).bottom,
                      ),
                      decoration: BoxDecoration(
                        color: ConnectionStyle.card(context),
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(28),
                        ),
                      ),
                      child: SafeArea(
                        top: false,
                        child: SingleChildScrollView(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 40,
                                height: 4,
                                decoration: BoxDecoration(
                                  color: ConnectionStyle.line(context),
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      state == ProjectAddingState.qrScan
                                          ? 'Scan QR code'
                                          : state == ProjectAddingState.urlEdit
                                          ? 'Edit connection'
                                          : 'Add by URL',
                                      style: ConnectionStyle.text(
                                        context,
                                        18,
                                        weight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                  IconButton(
                                    onPressed: controller.isProjectSaving.value
                                        ? null
                                        : controller.onTileCloseClick,
                                    icon: const Icon(Icons.close),
                                  ),
                                ],
                              ),
                              if (state == ProjectAddingState.qrScan)
                                const SizedBox(
                                  height: 320,
                                  child: ProjectHeroQrWidget(),
                                )
                              else
                                const ConnectionEditor(),
                              const SizedBox(height: 20),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    ),
  );
  String _greeting() {
    final h = DateTime.now().hour;
    return h < 12
        ? 'Good morning'
        : h < 17
        ? 'Good afternoon'
        : 'Good evening';
  }

  Widget _projectAction(
    BuildContext context,
    IconData icon,
    String title,
    String description,
    Color color,
  ) => Row(
    children: [
      Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: color.withValues(alpha: .1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: color, size: 20),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: ConnectionStyle.text(
                context,
                14,
                weight: FontWeight.w700,
                color: color,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              description,
              style: ConnectionStyle.text(
                context,
                11,
                color: ConnectionStyle.muted(context),
              ),
            ),
          ],
        ),
      ),
    ],
  );
}
