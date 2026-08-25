import 'dart:developer';

import 'package:axpert/app/core/common.dart';
import 'package:axpert/app/modules/project/controller/project_controller.dart';
import 'package:axpert/app/core/theme/app_colors.dart';
import 'package:axpert/app/widgets/widgets.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get_core/src/get_main.dart';
import 'package:get/get_instance/get_instance.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class ProjectHeroQrWidget extends StatefulWidget {
  const ProjectHeroQrWidget({super.key});

  @override
  State<ProjectHeroQrWidget> createState() => _ProjectHeroQrWidgetState();
}

class _ProjectHeroQrWidgetState extends State<ProjectHeroQrWidget>
    with SingleTickerProviderStateMixin {
  final ProjectController _projectController = Get.find();
  final MobileScannerController _scannerCtrl = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
    facing: CameraFacing.back,
  );

  late final AnimationController _animCtrl;
  late final Animation<double> _scanAnim;

  bool _detected = false;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true); // bounces top ↔ bottom

    _scanAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    _scannerCtrl.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) async {
    if (_detected) return;
    final barcode = capture.barcodes.firstOrNull;
    final value = barcode?.rawValue;
    if (value != null && value.isNotEmpty) {
      _detected = true;
      log(value.toString(), name: "qr code");
      await _projectController.onQRDetected(value);
      _detected = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.all(1),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: CustomPaint(
          foregroundPainter: _DashedBorderPainter(
            color: Colors.transparent,
            strokeWidth: 2.5,
            dashWidth: 10,
            dashSpace: 6,
            radius: 16,
          ),
          child: Stack(
            children: [
              // ── Camera feed ──────────────────────────────────
              MobileScanner(controller: _scannerCtrl, onDetect: _onDetect),

              // ── Dark vignette overlay ─────────────────────────
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withOpacity(0.25),
                        Colors.transparent,
                        Colors.transparent,
                        Colors.black.withOpacity(0.25),
                      ],
                      stops: const [0.0, 0.2, 0.8, 1.0],
                    ),
                  ),
                ),
              ),

              // ── Scanning line ────────────────────────────────
              Positioned.fill(
                child: AnimatedBuilder(
                  animation: _scanAnim,
                  builder: (context, _) {
                    return CustomPaint(
                      painter: _ScanLinePainter(progress: _scanAnim.value),
                    );
                  },
                ),
              ),

              Positioned.fill(
                child: Obx(
                  () => AnimatedContainer(
                    duration: Durations.short4,
                    color: _projectController.isProjectSaving.value
                        ? Colors.white
                        : Colors.transparent,
                    child: Center(
                      child: FadeIn(
                        key: ValueKey(_projectController.isProjectSaving.value),
                        duration: Durations.short4,
                        child: _projectController.isProjectSaving.value
                            ? Column(
                                mainAxisSize: MainAxisSize.min,
                                spacing: 20,
                                children: [
                                  LoadingLottieWidget(),
                                  Text(
                                    _projectController
                                        .projectSavingInfoText
                                        .value,
                                    style: GoogleFonts.dmSans(
                                      fontSize: 15.sp,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              )
                            : SizedBox.shrink(),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────────────
// Scan Line Painter
// ────────────────────────────────────────────────────────────────────
class _ScanLinePainter extends CustomPainter {
  final double progress; // 0.0 (top) → 1.0 (bottom)

  const _ScanLinePainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final y = progress * size.height;

    // Glow behind the line
    final glowPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          AppColors.lightPrimary.withOpacity(0.0),
          AppColors.lightPrimary.withOpacity(0.18),
          AppColors.lightPrimary.withOpacity(0.0),
        ],
        stops: const [0.0, 0.5, 1.0],
      ).createShader(Rect.fromLTWH(0, y - 24, size.width, 48));

    canvas.drawRect(Rect.fromLTWH(0, y - 24, size.width, 48), glowPaint);

    // The line itself
    final linePaint = Paint()
      ..shader = LinearGradient(
        colors: [
          AppColors.lightPrimary.withOpacity(0.0),
          AppColors.lightPrimary,
          AppColors.lightPrimary.withOpacity(0.0),
        ],
        stops: const [0.0, 0.5, 1.0],
      ).createShader(Rect.fromLTWH(0, y, size.width, 2))
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    canvas.drawLine(Offset(0, y), Offset(size.width, y), linePaint);
  }

  @override
  bool shouldRepaint(_ScanLinePainter old) => old.progress != progress;
}

// ────────────────────────────────────────────────────────────────────
// Dashed Border Painter
// ────────────────────────────────────────────────────────────────────
class _DashedBorderPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;
  final double dashWidth;
  final double dashSpace;
  final double radius;

  const _DashedBorderPainter({
    required this.color,
    required this.strokeWidth,
    required this.dashWidth,
    required this.dashSpace,
    required this.radius,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final rect = Rect.fromLTWH(
      strokeWidth / 2,
      strokeWidth / 2,
      size.width - strokeWidth,
      size.height - strokeWidth,
    );
    final rrect = RRect.fromRectAndRadius(rect, Radius.circular(radius));
    final path = Path()..addRRect(rrect);

    canvas.drawPath(_buildDashedPath(path), paint);
  }

  Path _buildDashedPath(Path source) {
    final result = Path();
    for (final metric in source.computeMetrics()) {
      double distance = 0;
      while (distance < metric.length) {
        final remaining = metric.length - distance;
        final draw = remaining < dashWidth ? remaining : dashWidth;
        result.addPath(
          metric.extractPath(distance, distance + draw),
          Offset.zero,
        );
        distance += dashWidth + dashSpace;
      }
    }
    return result;
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
