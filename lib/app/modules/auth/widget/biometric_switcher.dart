import '../../../core/common.dart';
import '../controller/auth_controller.dart';

class BiometricSwitcher extends GetView<AuthController> {
  const BiometricSwitcher({super.key});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final isLoading = controller.isBiometricLoading.value;
      final isAvailable =
          controller.isBiometricAvailable.value &&
          controller.willBio_userAuthenticate.value;

      // Hide entirely if not loading and not available
      if (!isLoading && !isAvailable) {
        return const SizedBox.shrink();
      }

      // AnimatedSize ensures the bounding box smoothly expands/shrinks
      // without throwing overflow errors when switching between Row and Column
      return AnimatedSize(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeOutBack, // Gives a slight, soothing bounce
        alignment: Alignment.center,
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          switchInCurve: Curves.easeIn,
          switchOutCurve: Curves.easeOut,
          // The keys on the children are critical for AnimatedSwitcher to know when to animate
          child: isLoading
              ? _buildLoadingStateContent()
              : _buildFingerprintButtonContent(context),
        ),
      );
    });
  }

  // --- Content Helper Methods ---

  Widget _buildLoadingStateContent() {
    return Padding(
      // ValueKey tells the AnimatedSwitcher this is a distinct widget
      key: const ValueKey('loading_state'),
      padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 12.0),
      child: Column(
        spacing: 10,
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(
            height: 14, // Made the spinner much smaller
            width: 14,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: AppColors.AXMGray, // Ensure AppColors is imported
            ),
          ),

          Text(
            "Checking biometrics",
            style: GoogleFonts.poppins(
              fontSize: 12, // Reduced font size
              fontWeight: FontWeight.w500,
              color: AppColors.AXMGray,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFingerprintButtonContent(BuildContext context) {
    return GestureDetector(
      key: const ValueKey('fingerprint_state'),
      behavior: HitTestBehavior.opaque, // Ensures the whole area is tappable
      onTap: () => controller.displayAuthenticationDialog(),
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.fingerprint_rounded,
              color: AppColors.darkBlue,
              size: 32, // Fixed smaller size instead of using MediaQuery
            ),
            const SizedBox(height: 4),
            Text(
              "Tap to Unlock",
              style: GoogleFonts.poppins(
                fontSize: 10, // Small detail text
                fontWeight: FontWeight.w600,
                color: AppColors.darkBlue,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
