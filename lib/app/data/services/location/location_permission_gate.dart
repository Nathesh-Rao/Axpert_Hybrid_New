import 'package:axpert/app/core/common.dart';
import 'package:get/get.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';

class LocationPermissionGate {
  static const _pendingKey = 'pending_location_permission_check';

  static Future<bool> hasPermission() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    final whenInUse = await Permission.locationWhenInUse.status;
    final always = await Permission.locationAlways.status;
    return serviceEnabled && whenInUse.isGranted && always.isGranted;
  }

  static Future<void> markPendingCheck() async {
    final pref = await SharedPreferences.getInstance();
    await pref.setBool(_pendingKey, true);
  }

  static Future<bool> consumePendingCheck() async {
    final pref = await SharedPreferences.getInstance();
    await pref.reload();
    final pending = pref.getBool(_pendingKey) ?? false;
    if (pending) await pref.remove(_pendingKey);
    return pending;
  }

  static Future<void> showBlockingUntilGranted() async {
    if (await hasPermission()) return;
    await Get.dialog(
      PopScope(canPop: false, child: const _LocationPermissionDialogContent()),
      barrierDismissible: false,
    );
  }
}

class _LocationPermissionDialogContent extends StatefulWidget {
  const _LocationPermissionDialogContent();
  @override
  State<_LocationPermissionDialogContent> createState() => _State();
}

class _State extends State<_LocationPermissionDialogContent>
    with WidgetsBindingObserver {
  bool _checking = true;
  bool _permanentlyDenied = false;
  bool _needsBackgroundSettingsStep = false;
  bool _inFlight = false; // re-entrancy guard

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkAndRequest();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Only re-check when the user is actually coming back from Settings —
    // not on every resume, since requesting a permission itself triggers
    // resume events and would otherwise cause a request loop.
    if (state == AppLifecycleState.resumed && _needsBackgroundSettingsStep) {
      _checkAndRequest();
    }
  }

  Future<void> _checkAndRequest() async {
    if (_inFlight) return; // guard against re-entrant calls
    _inFlight = true;
    setState(() => _checking = true);

    if (!await Geolocator.isLocationServiceEnabled()) {
      _inFlight = false;
      setState(() {
        _checking = false;
        _permanentlyDenied = false;
      });
      return;
    }

    var whenInUse = await Permission.locationWhenInUse.request();
    if (!whenInUse.isGranted) {
      _inFlight = false;
      setState(() {
        _checking = false;
        _permanentlyDenied = whenInUse.isPermanentlyDenied;
      });
      return;
    }

    var always = await Permission.locationAlways.status;
    if (always.isGranted) {
      _inFlight = false;
      if (mounted) Get.back();
      return;
    }

    // Android 11+ (and iOS "always") cannot be granted via a runtime dialog —
    // must be flipped manually in Settings. Try requesting once (works pre-API 30
    // and on some OEMs), then fall back to a Settings-only step either way.
    always = await Permission.locationAlways.request();
    _inFlight = false;

    if (always.isGranted) {
      if (mounted) Get.back();
      return;
    }

    setState(() {
      _checking = false;
      _needsBackgroundSettingsStep = true;
      _permanentlyDenied = always.isPermanentlyDenied;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      // Adds modern rounded corners to the dialog
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      elevation: 8,
      child: Padding(
        // Gives the content room to breathe without expanding to the whole screen
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        child: Column(
          mainAxisSize:
              MainAxisSize.min, // Ensures it only takes the height it needs
          children: [
            // Icon with a soft circular background
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Theme.of(context).primaryColor.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Lottie.asset(
                "assets/lotties/location.json",
                width: 100.w,
                // color: Theme.of(context).primaryColor,
              ),
            ),
            const SizedBox(height: 24),

            // Title text
            Text(
              "Location Access",
              style: GoogleFonts.poppins(
                fontSize: 22,
                fontWeight: FontWeight.w600,
                letterSpacing: -0.5,
                color: AppColors.AXMDark,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),

            // Subtitle/Body text
            Text(
              _needsBackgroundSettingsStep
                  ? "To accurately track your routes and update geolocation data even when the app is in the background, please open Settings and select 'Allow all the time'."
                  : "This feature requires location access to establish your starting point, track live movement, and calculate precise routes.",
              style: GoogleFonts.poppins(
                fontSize: 15,
                color: Colors.grey.shade600,
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),

            // Action Button
            SizedBox(
              width: double
                  .infinity, // Makes the button stretch nicely across the dialog
              height: 52,
              child: _checking
                  ? const Center(child: CircularProgressIndicator())
                  : ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        elevation: 0,
                        backgroundColor: Theme.of(context).primaryColor,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      onPressed:
                          (_needsBackgroundSettingsStep || _permanentlyDenied)
                          ? openAppSettings
                          : _checkAndRequest,
                      child: Text(
                        (_needsBackgroundSettingsStep || _permanentlyDenied)
                            ? "Open Settings"
                            : "Grant Permission",
                        style: GoogleFonts.poppins(
                          fontSize: 16.sp,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
