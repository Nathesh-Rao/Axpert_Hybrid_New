import 'dart:developer';

import 'package:axpert/app/data/const/app_const.dart';
import 'package:axpert/app/data/models/qr_payload.dart';
import 'package:axpert/app/data/services/api_manger.dart';
import 'package:axpert/app/data/services/storage_service.dart';
import 'package:axpert/app/db/project_database.dart';
import 'package:axpert/app/data/models/project_model.dart';
import 'package:axpert/app/data/enums/project_enums.dart';

import 'package:axpert/app/core/utils/haptic_manager.dart';
import 'package:palette_generator/palette_generator.dart';

import 'package:permission_handler/permission_handler.dart';
import 'package:http/http.dart' as http;

import '../../../core/common.dart';

// ─────────────────────────────────────────────────────────────────────
class ProjectController extends GetxController
    with GetSingleTickerProviderStateMixin {
  // ── Card / animation state ────────────────────────────────────────
  final currentTileState = ProjectAddingState.defaultState.obs;
  // final isTileAnimationEnd = true.obs;
  final isAccessCodeLoading = false.obs;
  final defaultTileHeight = 250.h;
  final qrTileHeight = 1.sw;
  final urlTileHeight = 500.h;
  final accessCodeTileHeight = 350.h;

  // ── Project list ──────────────────────────────────────────────────
  final projects = <ProjectModel>[].obs;
  final isLoadingProjects = false.obs;
  final editingProject = Rxn<ProjectModel>();
  final isProjectSaving = false.obs;
  final projectSavingInfoText = ''.obs;

  void projectSavingStarted() {
    isProjectSaving.value = true;
    projectSavingInfoText.value = "Saving project";
  }

  void updateSavingInfoText(String s) {
    projectSavingInfoText.value = s;
  }

  void projectSavingStopped() {
    isProjectSaving.value = false;
    projectSavingInfoText.value = "Done";
  }

  @override
  void onInit() {
    super.onInit();
    _initManualTab();
    fetchProjects();
  }

  // ── Fetch all from DB ─────────────────────────────────────────────
  Future<void> fetchProjects() async {
    isLoadingProjects.value = true;
    final result = await ProjectDatabase.instance.getAll();
    switch (result) {
      case DbSuccess(:final data):
        projects.assignAll(data);
      case DbError(:final message):
        _showErrorSnackbar(message);
    }
    isLoadingProjects.value = false;
  }

  // ── QR detected callback (pass this to QrScannerWidget) ──────────
  Future<void> onQRDetected(String raw) async {
    // 1. Parse & validate
    projectSavingStarted();
    final payload = QrPayload.tryParse(raw);
    if (payload == null) {
      HapticManager.error();
      _showInvalidQrSnackbar();
      return;
    }

    updateSavingInfoText("Validating ARM");
    var isProjectValid = await _checkArmStatus(armUrl: payload.armUrl);
    if (!isProjectValid) {
      projectSavingStopped();
      return;
    }

    updateSavingInfoText("Validating Connection");
    var isConnectionValid = await _validateConnectionName(
      baseUrl: payload.armUrl,
      appName: payload.pName,
    );
    if (!isConnectionValid) {
      projectSavingStopped();
      return;
    }

    updateSavingInfoText("fetching project details");
    var logoUrl = await getLogoUrl(
      webUrl: payload.pUrl,
      projectName: payload.pName,
    );
    final logocolor = logoUrl.isNotEmpty
        ? await extractLogoColorHex(logoUrl)
        : '';

    // 2. Build model
    final project = ProjectModel(
      logourl: logoUrl,
      color: logocolor,
      url: payload.pUrl,
      armurl: payload.armUrl,
      schemaName: payload.pName,
      caption: payload.pName, // pname doubles as caption like old app
    );

    // 3. Save to DB
    final result = await ProjectDatabase.instance.add(project);
    switch (result) {
      case DbSuccess(:final data):
        HapticManager.success();
        if (StorageService.isFirstTime) {
          await StorageService.setFirstTimeDone();
        }
        projects.add(data);
        await fetchProjects();
        _goToDefault();
        _showSuccessSnackbar("${data.schemaName} added successfully.");

      case DbError(:final message):
        // Duplicate or other DB error — show message, stay on QR screen
        HapticManager.error();
        Get.snackbar(
          '',
          '',
          titleText: const SizedBox.shrink(),
          messageText: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.accentRed.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.error_outline_rounded,
                  color: AppColors.accentRed,
                  size: 18,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  message,
                  style:  GoogleFonts.poppins(
                    color: AppColors.textWhite,
                    fontSize: 13,
                    fontWeight: FontWeight.w400,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: AppColors.cardBackground,
          borderRadius: 14,
          borderColor: AppColors.glassBorder,
          borderWidth: 0.8,
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          duration: const Duration(seconds: 3),
          boxShadows: const [
            BoxShadow(
              color: AppColors.shadowColor,
              blurRadius: 16,
              offset: Offset(2, 2),
            ),
          ],
        );
    }
    projectSavingStopped();
  }
  // ── Delete project ────────────────────────────────────────────────

  // void onEditProjectClick({required ProjectModel project}) {
  //   if (currentTileState.value == ProjectAddingState.defaultState ||
  //       currentTileState.value == ProjectAddingState.defaultState) {
  //     isTileAnimationEnd.value = false;
  //   }

  //   webUrlCtrl.text = project.url;
  //   connectionNameCtrl.text = project.schemaName;
  //   connectionCaptionCtrl.text = project.schemaName;

  //   currentTileState.value = ProjectAddingState.urlEdit;
  // }

  void onEditProjectClick(ProjectModel project) {
    editingProject.value = project;
    var trimmedProjectUrl = project.url.replaceAll("https://", "");
    var trimmedArmUrl = project.armurl.replaceAll("https://", "");
    webUrlCtrl.text = trimmedProjectUrl;
    armUrlCtrl.text = trimmedArmUrl;
    connectionNameCtrl.text = project.schemaName;
    connectionCaptionCtrl.text = project.caption;

    manualTabCtrl.animateTo(0);
    manualTabIndex.value = 0;
    if (currentTileState.value == ProjectAddingState.defaultState ||
        currentTileState.value == ProjectAddingState.defaultState) {}
    currentTileState.value = ProjectAddingState.urlEdit;
  }

  void cancelEdit() {
    editingProject.value = null;
    _clearManualForm();
    _goToDefault();
  }

  // ── Delete project ────────────────────────────────────────────────
  Future<void> deleteProject(int id) async {
    final result = await ProjectDatabase.instance.delete(id);
    switch (result) {
      case DbSuccess():
        projects.removeWhere((p) => p.id == id);
      case DbError(:final message):
        _showErrorSnackbar(message);
    }
  }

  // ── Tile animation ────────────────────────────────────────────────
  // void onAnimationEnd() => isTileAnimationEnd.value = true;

  void _goToDefault() {
    currentTileState.value = ProjectAddingState.defaultState;
  }

  // ── Button handlers ───────────────────────────────────────────────
  Future<void> onScanQRClick() async {
    final hasPermission = await checkCameraPermission();
    if (hasPermission) {
      currentTileState.value = ProjectAddingState.qrScan;
    } else {
      Get.snackbar(
        '',
        '',
        titleText: const SizedBox.shrink(),
        messageText: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.accentRed.withOpacity(0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.no_photography_outlined,
                color: AppColors.accentRed,
                size: 18,
              ),
            ),
            const SizedBox(width: 12),
             Expanded(
              child: Text(
                'Enable camera permission to access the QR scanner.',
                style: GoogleFonts.poppins(
                  color: AppColors.textWhite,
                  fontSize: 13,
                  fontWeight: FontWeight.w400,
                  height: 1.4,
                ),
              ),
            ),
          ],
        ),
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: AppColors.cardBackground,
        borderRadius: 14,
        borderColor: AppColors.glassBorder,
        borderWidth: 0.8,
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        duration: const Duration(seconds: 3),
        boxShadows: const [
          BoxShadow(
            color: AppColors.shadowColor,
            blurRadius: 16,
            offset: Offset(2, 2),
          ),
        ],
      );
    }
  }

  void onAddManuallyClick() {
    _clearManualForm();
    currentTileState.value = ProjectAddingState.urlDetails;
    webUrlFocusNode.requestFocus();
  }

  void _clearManualForm() {
    webUrlCtrl.clear();
    armUrlCtrl.clear();
    connectionNameCtrl.clear();
    connectionCaptionCtrl.clear();
    accessCodeCtrl.clear();
    manualTabCtrl.animateTo(0);
    manualTabIndex.value = 0;
    editingProject.value = null;
  }

  void onTileCloseClick() {
    editingProject.value = null;
    currentTileState.value = ProjectAddingState.defaultState;
  }

  // ── Camera permission ─────────────────────────────────────────────
  Future<bool> checkCameraPermission() async {
    final status = await Permission.camera.status;
    if (status == PermissionStatus.granted) return true;
    final result = await Permission.camera.request();
    return result == PermissionStatus.granted;
  }

  // ── Snackbar helpers ──────────────────────────────────────────────
  void _showInvalidQrSnackbar() {
    Get.snackbar(
      '',
      '',
      titleText: const SizedBox.shrink(),
      messageText: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.accentRed.withOpacity(0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.qr_code_2_rounded,
              color: AppColors.accentRed,
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
           Expanded(
            child: Text(
              'Invalid QR code. Please scan a valid AXI project QR.',
              style: GoogleFonts.poppins(
                color: AppColors.textWhite,
                fontSize: 13,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: AppColors.cardBackground,
      borderRadius: 14,
      borderColor: AppColors.glassBorder,
      borderWidth: 0.8,
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      duration: const Duration(seconds: 3),
      boxShadows: const [
        BoxShadow(
          color: AppColors.shadowColor,
          blurRadius: 16,
          offset: Offset(2, 2),
        ),
      ],
    );
  }

  void _showSuccessSnackbar(String msg) {
    Get.snackbar(
      '',
      '',
      titleText: const SizedBox.shrink(),
      messageText: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.primaryGreen.withOpacity(0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.check_circle_outline_rounded,
              color: AppColors.primaryGreen,
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              msg,
              style:  GoogleFonts.poppins(
                color: AppColors.textWhite,
                fontSize: 13,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: AppColors.cardBackground,
      borderRadius: 14,
      borderColor: AppColors.glassBorder,
      borderWidth: 0.8,
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      duration: const Duration(seconds: 3),
      boxShadows: const [
        BoxShadow(
          color: AppColors.shadowColor,
          blurRadius: 16,
          offset: Offset(2, 2),
        ),
      ],
    );
  }

  void _showErrorSnackbar(String message) {
    Get.snackbar(
      '',
      '',
      titleText: const SizedBox.shrink(),
      messageText: Text(
        message,
        style:  GoogleFonts.poppins(color: AppColors.textSecondary, fontSize: 13),
      ),
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: AppColors.cardBackground,
      borderRadius: 14,
      borderColor: AppColors.glassBorder,
      borderWidth: 0.8,
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      duration: const Duration(seconds: 3),
    );
  }

  // ── Paste these into ProjectController ───────────────────────────────
  //
  // 1. Add SingleGetTickerProviderMixin to the class:
  //    class ProjectController extends GetxController with SingleGetTickerProviderMixin {
  //
  // 2. Add these fields:

  // ── Manual form tab ───────────────────────────────────────────────
  late final TabController manualTabCtrl;
  final manualTabIndex = 0.obs;

  // ── Manual form text controllers ──────────────────────────────────
  final webUrlCtrl = TextEditingController();
  final armUrlCtrl = TextEditingController();
  final connectionNameCtrl = TextEditingController();
  final connectionCaptionCtrl = TextEditingController();
  final accessCodeCtrl = TextEditingController();

  final webUrlFocusNode = FocusNode();
  final armUrlFocusNode = FocusNode();
  final connectionNameFocusNode = FocusNode();
  final connectionCaptionFocusNode = FocusNode();
  final accessCodeFocusNode = FocusNode();

  // 3. Init tab controller in onInit():
  void _initManualTab() {
    manualTabCtrl = TabController(length: 2, vsync: this);
    manualTabCtrl.addListener(() {
      if (!manualTabCtrl.indexIsChanging) {
        manualTabIndex.value = manualTabCtrl.index;
      }
    });
  }

  // 4. Add save handlers:

  // void onSaveUrlDetails() {
  //   final url = webUrlCtrl.text.trim();
  //   final name = connectionNameCtrl.text.trim();

  //   if (url.isEmpty || name.isEmpty) {
  //     _showErrorSnackbar('Please fill in the Web URL and Connection Name.');
  //     return;
  //   }

  //   final project = ProjectModel(
  //     url: url,
  //     schemaName: name,
  //     caption: connectionCaptionCtrl.text.trim(),
  //   );

  //   _addProject(project);
  // }
  final formKey = GlobalKey<FormState>();

  final Map<String, GlobalKey<FormFieldState>> fieldKeys = {
    'webUrl': GlobalKey<FormFieldState>(),
    'armUrl': GlobalKey<FormFieldState>(),
    'connectionName': GlobalKey<FormFieldState>(),
    'connectionCaption': GlobalKey<FormFieldState>(),
  };

  bool validate() {
    return (formKey.currentState?.validate() ?? false);
  }

  bool validateField(GlobalKey<FormFieldState>? key) {
    return (key?.currentState?.validate() ?? false);
  }

  String? validateUrl(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Please enter a URL';
    }

    final urlRegExp = RegExp(
      r'^(https?:\/\/)?([\w\d\-]+\.)+\w{2,}(\/.*)?$',
      caseSensitive: false,
    );

    if (!urlRegExp.hasMatch(value.trim())) {
      return 'Please enter a valid URL';
    }

    return null;
  }

  String? validateNormalField(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Please enter a connection name';
    }

    if (value.trim().length < 3) {
      return 'Name must be at least 3 characters long';
    }

    return null;
  }

  void onSaveUrlDetails() async {
    if (!validate()) {
      HapticManager.warning();
      return;
    }
    projectSavingStarted();
    final rawUrl = webUrlCtrl.text.trim();
    final rawArmUrl = armUrlCtrl.text.trim();
    final name = connectionNameCtrl.text.trim();

    // Auto-add https if missing
    String url = rawUrl;
    String armurl = rawArmUrl;
    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      url = 'https://$url';
      // webUrlCtrl.text = url; // reflect in field
    }
    if (!armurl.startsWith('http://') && !armurl.startsWith('https://')) {
      armurl = 'https://$armurl';
      // webUrlCtrl.text = url; // reflect in field
    }
    // debugPrint(rawArmUrl);
    // debugPrint(rawArmUrl);
    // // Upgrade http → https
    // if (url.startsWith('http://')) {
    //   url = url.replaceFirst('http://', 'https://');
    //   // webUrlCtrl.text = url;
    // }

    // URI parse check
    final uri = Uri.tryParse(url);
    if (uri == null || !uri.hasScheme || !uri.hasAuthority) {
      _showErrorSnackbar('Please enter a valid URL.');
      HapticManager.warning();
      projectSavingStopped();
      return;
    }
    final armuri = Uri.tryParse(armurl);
    if (armuri == null || !armuri.hasScheme || !armuri.hasAuthority) {
      _showErrorSnackbar('Please enter a valid ARM URL.');
      HapticManager.warning();
      projectSavingStopped();

      return;
    }

    updateSavingInfoText("Validating ARM");
    var isProjectValid = await _checkArmStatus(armUrl: armurl);
    if (!isProjectValid) {
      projectSavingStopped();
      return;
    }

    updateSavingInfoText("Validating Connection");
    var isConnectionValid = await _validateConnectionName(
      baseUrl: armurl,
      appName: name,
    );
    if (!isConnectionValid) {
      projectSavingStopped();
      return;
    }

    updateSavingInfoText("Fetching project details");
    var logoUrl = await getLogoUrl(webUrl: url, projectName: name);
    final logocolor = logoUrl.isNotEmpty
        ? await extractLogoColorHex(logoUrl)
        : '';

    if (editingProject.value != null) {
      // ── Update existing ──────────────────────────────────────────
      await _updateProject(
        editingProject.value!.copyWith(
          color: logocolor,
          logourl: logoUrl,
          url: url,
          armurl: armurl,
          schemaName: name,
          caption: connectionCaptionCtrl.text.trim(),
        ),
      );
    } else {
      // ── Add new ──────────────────────────────────────────────────
      await _addProject(
        ProjectModel(
          color: logocolor,
          logourl: logoUrl,
          url: url,
          armurl: armurl,
          schemaName: name,
          caption: connectionCaptionCtrl.text.trim(),
        ),
      );
    }

    projectSavingStopped();
  }

  // ── Update DB + list ──────────────────────────────────────────────
  Future<void> _updateProject(ProjectModel project) async {
    final result = await ProjectDatabase.instance.update(project);
    switch (result) {
      case DbSuccess(:final data):
        // Replace in list reactively
        final index = projects.indexWhere((p) => p.id == data.id);
        if (index != -1) projects[index] = data;
        editingProject.value = null;
        _clearManualForm();
        _goToDefault();
        _showSuccessSnackbar('${data.schemaName} updated successfully.');
        HapticManager.success();
      case DbError(:final message):
        _showErrorSnackbar(message);
        HapticManager.error();
    }
  }

  Future<void> onSaveAccessCode() async {
    final code = accessCodeCtrl.text.trim();

    if (code.isEmpty) {
      _showErrorSnackbar('Please enter a connection code.');
      HapticManager.warning();
      return;
    }

    isAccessCodeLoading.value = true;

    final result = await ApiManager.instance.fetchProjectFromClientId(code);

    isAccessCodeLoading.value = false;

    switch (result) {
      case ApiSuccess(:final data):
        var logoUrl = await getLogoUrl(
          webUrl: data.webUrl,
          projectName: data.projectName,
        );
        final logocolor = logoUrl.isNotEmpty
            ? await extractLogoColorHex(logoUrl)
            : '';
        await _addProject(
          ProjectModel(
            color: logocolor,
            logourl: logoUrl,
            url: data.webUrl,
            armurl: data.armUrl,
            schemaName: data.projectName,
            caption: data.projectName,
          ),
        );

      case ApiError(:final message):
        _showErrorSnackbar(message);
        HapticManager.error();
    }
  }

  Future<void> _addProject(ProjectModel project) async {
    final result = await ProjectDatabase.instance.add(project);
    switch (result) {
      case DbSuccess(:final data):
        if (StorageService.isFirstTime) {
          await StorageService.setFirstTimeDone();
        }
        projects.add(data);
        _clearManualForm();
        _goToDefault();
        _showSuccessSnackbar("${data.schemaName} added successfully.");
        HapticManager.success();
      case DbError(:final message):
        _showErrorSnackbar(message);
        HapticManager.error();
    }
  }

  Future<bool> _checkArmStatus({required String armUrl}) async {
    ApiResult result = await ApiManager.instance.checkArmStatus(armUrl);

    if (result is ApiError) {
      _showErrorSnackbar(result.message);
      return false;
    } else {
      return true;
    }
  }

  Future<bool> _validateConnectionName({
    required String baseUrl,
    required String appName,
  }) async {
    ApiResult result = await ApiManager.instance.validateConnectionName(
      baseUrl: baseUrl,
      appName: appName,
    );
    if (result is ApiError) {
      _showErrorSnackbar(result.message);
      return false;
    } else {
      return true;
    }
  }

  // static Future<String> getLogoUrl({
  //   required String webUrl,
  //   required String projectName,
  // }) async {
  //   try {
  //     var entryPoint = "$projectName/${AppConst.NETWORK_APP_LOGO_FILE_NAME}";
  //     var baseUrl = webUrl.endsWith("/")
  //         ? webUrl + entryPoint
  //         : "$webUrl/$entryPoint";
  //     log(baseUrl.toString(), name: "getLogoUrl");
  //     final jpg = Uri.parse("$baseUrl.jpg");
  //     final png = Uri.parse("$baseUrl.png");

  //     final jpgResponse = await http.head(jpg);
  //     if (jpgResponse.statusCode == 200) {
  //       return jpg.toString();
  //     }

  //     final pngResponse = await http.head(png);
  //     if (pngResponse.statusCode == 200) {
  //       return png.toString();
  //     }

  //     return "";
  //   } catch (e) {
  //     debugPrint(e.toString());
  //   }
  //   return "";
  // }

  static Future<String> getLogoUrl({
    required String webUrl,
    required String projectName,
  }) async {
    try {
      final entryPoint = "$projectName/${AppConst.NETWORK_APP_LOGO_FILE_NAME}";
      final baseUrl = webUrl.endsWith("/")
          ? webUrl + entryPoint
          : "$webUrl/$entryPoint";

      log(baseUrl, name: "getLogoUrl");

      final jpg = Uri.parse("$baseUrl.jpg");
      final png = Uri.parse("$baseUrl.png");

      final results = await Future.wait([
        _checkImageExists(jpg),
        _checkImageExists(png),
      ]);

      if (results[0]) return jpg.toString();
      if (results[1]) return png.toString();

      return "";
    } catch (e) {
      debugPrint(e.toString());
      return "";
    }
  }

  static Future<bool> _checkImageExists(Uri uri) async {
    try {
      log(uri.toString(), name: "getLogoUrl URI");
      final response = await http.get(uri).timeout(const Duration(seconds: 6));

      if (response.statusCode != 200) return false;

      // Guard against servers returning a 200 HTML error/placeholder page
      final contentType = response.headers['content-type'] ?? '';
      if (!contentType.startsWith('image/')) return false;

      return true;
    } catch (e) {
      debugPrint('Logo check failed for $uri: $e');
      return false;
    }
  }

  @override
  void onClose() {
    manualTabCtrl.dispose();
    webUrlCtrl.dispose();
    armUrlCtrl.dispose();
    connectionNameCtrl.dispose();
    connectionCaptionCtrl.dispose();
    accessCodeCtrl.dispose();
    //---------------------
    webUrlFocusNode.dispose();
    armUrlFocusNode.dispose();
    connectionNameFocusNode.dispose();
    connectionCaptionFocusNode.dispose();
    accessCodeFocusNode.dispose();
    super.onClose();
  }

  void onProjectTileClick(ProjectModel project) async {
    HapticManager.selection();
    if (project.id != null) {
      await StorageService.saveLastSelectedProject(project.id!);
    }
    // final url = AppUtility.generateUrlForWebView(
    //   project.url,
    //   project.schemaName,
    // );
    // WebViewController.open(
    //   url: url,
    //   title: project.caption.isNotEmpty ? project.caption : project.schemaName,
    // );

    Get.toNamed(Routes.LOGIN);
  }

  Future<void> showExitConfirmationSheet() {
    return Get.bottomSheet(
      Container(
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          boxShadow: [
            BoxShadow(
              color: AppColors.shadowColor,
              offset: const Offset(0, -4),
              blurRadius: 20,
              spreadRadius: 2,
            ),
          ],
        ),
        padding: EdgeInsets.only(
          left: 24,
          right: 24,
          top: 12,
          bottom: MediaQuery.of(Get.context!).padding.bottom + 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Drag handle ─────────────────────────────────────
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: AppColors.grey300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // ── Icon ────────────────────────────────────────────
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

            // ── Title ───────────────────────────────────────────
            Text(
              'Exit App?',
              style: GoogleFonts.poppins(
                color: AppColors.textOnLight,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),

            8.verticalSpace,

            Text(
              'Are you sure you want to close the app?',
              textAlign: TextAlign.center,
              style: GoogleFonts.dmSans(
                color: AppColors.grey600,
                fontSize: 13,
                height: 1.5,
              ),
            ),

            24.verticalSpace,

            // ── Stay + Exit row ─────────────────────────────────
            Row(
              children: [
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

                Expanded(
                  child: SizedBox(
                    height: 55.h,
                    child: ElevatedButton(
                      onPressed: () {
                        Get.back(); // close sheet
                        SystemNavigator.pop(); // kill app
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
                        'Exit',
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
          ],
        ),
      ),
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: AppColors.grey900.withOpacity(0.4),
    );
  }

  Future<String> extractLogoColorHex(String logoUrl) async {
    if (logoUrl.isEmpty) return '';
    try {
      final palette = await PaletteGenerator.fromImageProvider(
        NetworkImage(logoUrl),
        size: const Size(100, 100),
        maximumColorCount: 10,
      );

      final color =
          palette.darkVibrantColor?.color ??
          palette.vibrantColor?.color ??
          palette.dominantColor?.color ??
          palette.mutedColor?.color;

      // final color =
      //     palette.vibrantColor?.color ??
      //     palette.darkVibrantColor?.color ??
      //     palette.dominantColor?.color ??
      //     palette.mutedColor?.color;

      // final color = palette.lightVibrantColor?.color;
      if (color == null) return '';

      return '#${color.toARGB32().toRadixString(16).substring(2).padLeft(6, '0')}';
    } catch (e) {
      debugPrint('Color extraction failed for $logoUrl: $e');
      return '';
    }
  }
}
