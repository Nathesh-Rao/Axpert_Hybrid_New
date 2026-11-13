// ignore_for_file: non_constant_identifier_names

import 'dart:async';
import 'dart:convert';
import 'dart:developer';

import 'package:axpert/app/core/common.dart';
import 'package:axpert/app/widgets/project_logo.dart';
import 'package:axpert/app/widgets/connection_style.dart';
import 'package:axpert/app/core/common/methods.dart';
import 'package:axpert/app/data/const/app_const.dart';
import 'package:axpert/app/data/enums/auth_enums.dart';
import 'package:axpert/app/data/models/project_model.dart';
import 'package:axpert/app/data/services/api/api_endpoints.dart';
import 'package:axpert/app/data/services/api/api_manger.dart';
import 'package:axpert/app/data/services/connectivity/internet_connectivity.dart';
import 'package:axpert/app/data/services/storage/storage_service.dart';
import 'package:axpert/app/data/services/project_logo_cache.dart';
import 'package:axpert/app/db/project_database.dart';
import 'package:axpert/app/modules/webview/controller/webview_controller.dart';
import 'package:axpert/app/modules/webview/webview_view.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:uuid/uuid.dart';
import 'package:crypto/crypto.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

import '../../offline_form_pages/db/db.dart';

typedef _LoginAttempt = ({
  ProjectModel project,
  String username,
  String passwordHash,
  String rememberedPassword,
  bool remember,
});

class AuthController extends GetxController {
  Rxn<ProjectModel> selectedProject = Rxn<ProjectModel>();
  Rxn<Color> selectedColor = Rxn<Color>();
  // WebViewController webViewController = Get.find();

  var rememberMe = false.obs;
  var googleSignInVisible = false.obs;
  var ddSelectedValue = "power".obs;
  var userTypeList = [].obs;
  var showPassword = true.obs;
  TextEditingController userNameController = TextEditingController();
  TextEditingController userPasswordController = TextEditingController();
  TextEditingController otpFieldController = TextEditingController();
  final passwordFocus = FocusNode();
  var errUserName = ''.obs;
  var errPassword = ''.obs;
  dynamic fcmId;
  var willBio_userAuthenticate = false.obs;
  var isBiometricAvailable = false.obs;
  var currentProjectName = ''.obs;
  var isUserDataLoading = false.obs;
  var isOtpLoading = false.obs;
  var isOTP_auth = false.obs;
  var isPWD_auth = false.obs;
  var isSigninApiCalling = false.obs;
  var isOfflineLoginMode = false.obs;
  var signInApiStatusMessage = ''.obs;
  var otpChars = '4'.obs;
  var otpExpiryTime = '2'.obs;
  var authType = AuthType.none.obs;
  var otpMsg = ''.obs;
  var otpLoginKey = ''.obs;
  var otpErrorText = ''.obs;
  bool isAxpertConnectEstablished = false;
  bool _isAuthFromBiometric = false;
  _LoginAttempt? _pendingOtpLogin;
  final projects = <ProjectModel>[].obs;
  TextEditingController oPassCtrl = TextEditingController();
  TextEditingController nPassCtrl = TextEditingController();
  TextEditingController cnPassCtrl = TextEditingController();
  var errOPass = ''.obs;
  var errNPass = ''.obs;
  var errCNPass = ''.obs;
  var showOldPass = false.obs;
  var showNewPass = false.obs;
  var showConNewPass = false.obs;
  // ── Timer State ────────────────────────────────────────────────────────
  RxInt otpRemainingSeconds = 0.obs;
  Timer? _otpTimer;

  bool get isOtpTimerActive => otpRemainingSeconds.value > 0;

  void onLoad() async {
    await refreshCurrentProject();
  }

  void projectChanged(int p1) async {
    biometricInputChanged();
    _rememberedBiometricUser = null;
    await StorageService.saveLastSelectedProject(p1);
    onLoad();
  }

  @override
  onInit() {
    super.onInit();
    fetchProjects();
    onLoad();
  }

  Future<void> fetchProjects() async {
    // isLoadingProjects.value = true;
    projects.clear();
    final result = await ProjectDatabase.instance.getAll();
    switch (result) {
      case DbSuccess(:final data):
        projects.assignAll(data);
        unawaited(_refreshProjectLogoCache(data));
      case DbError(:final message):
        error(message);
    }
    // isLoadingProjects.value = false;
  }

  Future<void> _refreshProjectLogoCache(List<ProjectModel> values) async {
    final refreshed = await Future.wait(values.map(ProjectLogoCache.refresh));
    for (final updated in refreshed) {
      if (updated.logoData == null) continue;
      final index = projects.indexWhere((item) => item.id == updated.id);
      if (index >= 0) projects[index] = updated;
      if (selectedProject.value?.id == updated.id) {
        selectedProject.value = updated;
      }
    }
  }

  Future<void> refreshCurrentProject() async {
    biometricInputChanged();
    final refresh = _biometricCheck;
    isOTP_auth.value = false;
    isPWD_auth.value = false;
    authType.value = AuthType.none;
    final project = await StorageService.getLastSelectedProject();
    if (isClosed || refresh != _biometricCheck) return;
    selectedProject.value = project;
    currentProjectName.value = selectedProject.value?.schemaName ?? '';
    selectedColor.value = AppColors.colorFromHex(
      selectedProject.value?.color ?? '',
    );

    final connection = project == null
        ? ''
        : StorageService.connectionLoginKey(project);
    if (project != null) await _migrateConfirmedBiometricLogin(project);
    if (isClosed || refresh != _biometricCheck) return;
    final rememberedUser = StorageService.getRememberedUser(connection);
    var userName = rememberedUser;
    if (userName == null && project != null) {
      final offlineUser = await OfflineDbModule.getLatestOfflineUserForProject(
        project.schemaName,
      );
      if (isClosed || refresh != _biometricCheck) return;
      userName = offlineUser?[OfflineDBConstants.COL_USERNAME]?.toString();
    }
    _rememberedBiometricUser = rememberedUser;
    rememberMe.value = rememberedUser != null;
    userNameController.text = userName ?? '';
    userPasswordController.text = rememberedUser == null
        ? ''
        : StorageService.getRememberedPassword(connection) ?? '';

    if (rememberedUser != null) await setWillAuthenticate();
  }

  Future<void> _migrateConfirmedBiometricLogin(ProjectModel project) async {
    // The legacy keys used only the project name. Reuse an enrollment only
    // when the saved session and remembered credentials prove its scope.
    if (StorageService.lastBiometricLogin(project) != null ||
        StorageService.projectName != project.schemaName ||
        StorageService.webUrl != project.url ||
        StorageService.armUrl != project.armurl) {
      return;
    }
    final name = project.schemaName;
    final user = StorageService.getRememberedUser(name);
    final password = StorageService.getRememberedPassword(name);
    if (user == null ||
        user.isEmpty ||
        user != StorageService.userName ||
        password == null ||
        password.trim().isEmpty ||
        StorageService.getWillBiometricAuthenticateForThisUser(
              projectName: name,
              username: user,
            ) !=
            true) {
      return;
    }
    final hash = generateMd5(AppConst.SEED + generateMd5(password.trim()));
    final legacyLogin = StorageService.retrieveLastLoginData(name);
    if (legacyLogin?['username'] != user || legacyLogin?['password'] != hash) {
      return;
    }
    await StorageService.rememberCredentialsForProject(
      projectName: StorageService.connectionLoginKey(project),
      username: user,
      password: password,
      group: ddSelectedValue.value,
    );
    await StorageService.saveCompletedBiometricLogin(
      project: project,
      username: user,
      passwordHash: hash,
      remember: true,
    );
    await StorageService.enrollLastBiometricLogin(project, user);
  }

  var isBiometricLoading = false.obs;
  int _biometricCheck = 0;
  bool _biometricPromptOpen = false;
  Map<String, dynamic>? _verifiedBiometricLogin;
  String? _verifiedBiometricConnection;
  String? _rememberedBiometricUser;

  void biometricInputChanged() {
    _biometricCheck++;
    isBiometricLoading.value = false;
    isBiometricAvailable.value = false;
    willBio_userAuthenticate.value = false;
    isOfflineLoginMode.value = false;
  }

  void biometricLoginInputEdited() {
    if (rememberMe.value &&
        _rememberedBiometricUser == userNameController.text.trim()) {
      unawaited(setWillAuthenticate(autoPrompt: false));
    } else {
      biometricInputChanged();
    }
  }

  Map<String, dynamic>? _eligibleBiometricLogin(ProjectModel project) {
    if (!rememberMe.value || !StorageService.canAuthenticate) return null;
    final login = StorageService.lastBiometricLogin(project);
    final remembered = StorageService.getRememberedUser(
      StorageService.connectionLoginKey(project),
    );
    if (login?['enrolled'] != true ||
        remembered != login?['username'] ||
        login?['username'] != userNameController.text.trim() ||
        (login?['password']?.toString().isEmpty ?? true)) {
      return null;
    }
    return login;
  }

  Future<void> setWillAuthenticate({bool autoPrompt = true}) async {
    biometricInputChanged();
    final project = selectedProject.value;
    if (project == null || _eligibleBiometricLogin(project) == null) return;
    final check = _biometricCheck;
    isBiometricLoading.value = true;
    final result = await ApiManager.instance.checkBiometricFlag(
      baseUrl: project.armurl.trim(),
      appName: project.schemaName.trim(),
    );
    if (isClosed || check != _biometricCheck) return;
    isBiometricLoading.value = false;
    final currentProject = selectedProject.value;
    if (currentProject == null ||
        StorageService.connectionLoginKey(currentProject) !=
            StorageService.connectionLoginKey(project)) {
      return;
    }
    final enabled = result is ApiSuccess<bool> && result.data;
    isBiometricAvailable.value = enabled;
    willBio_userAuthenticate.value =
        enabled && _eligibleBiometricLogin(project) != null;
    if (autoPrompt && willBio_userAuthenticate.value) {
      unawaited(displayAuthenticationDialog());
    }
  }

  Future<void> displayAuthenticationDialog() async {
    final project = selectedProject.value;
    if (project == null ||
        _biometricPromptOpen ||
        _isAuthFromBiometric ||
        isSigninApiCalling.value ||
        isUserDataLoading.value ||
        !isBiometricAvailable.value ||
        !willBio_userAuthenticate.value) {
      return;
    }
    final login = _eligibleBiometricLogin(project);
    if (login == null) return;
    if (!await _hasNetworkInterface()) return;
    final check = _biometricCheck;
    _biometricPromptOpen = true;
    try {
      if (!await CommonMethods.showBiometricDialog() ||
          isClosed ||
          check != _biometricCheck ||
          selectedProject.value != project) {
        return;
      }
      final current = _eligibleBiometricLogin(project);
      if (current?['username'] != login['username'] ||
          current?['password'] != login['password']) {
        return;
      }
      _verifiedBiometricLogin = login;
      _verifiedBiometricConnection = StorageService.connectionLoginKey(project);
      _isAuthFromBiometric = true;
      await startLoginProcess();
    } catch (error) {
      log(
        'Biometric sign-in failed: ${error.runtimeType}',
        name: 'AuthController',
      );
    } finally {
      _isAuthFromBiometric = false;
      _verifiedBiometricLogin = null;
      _verifiedBiometricConnection = null;
      _biometricPromptOpen = false;
    }
  }

  Future<String> getVersionName() async {
    PackageInfo packageInfo = await PackageInfo.fromPlatform();
    // String appName = packageInfo.appName;
    // String packageName = packageInfo.packageName;
    var version = packageInfo.version;
    // String buildNumber = packageInfo.buildNumber;
    AppConst.APP_VERSION = version; //+ "." + AppConst.APP_RELEASE_ID;
    return AppConst.APP_VERSION;
  }

  Future<void> startLoginProcess() async {
    if (isOfflineLoginMode.value) return;
    if (!await _hasNetworkInterface()) {
      await _beginOfflineLogin();
      return;
    }

    final nextAuthType = await getLoginUserDetailsAndAuthType();
    if (isOfflineLoginMode.value) return;
    authType.value = nextAuthType;

    if (authType.value == AuthType.otpOnly || _isAuthFromBiometric) {
      await callSignInAPI();
    }
    log("isPWD_auth.value ${isPWD_auth.value}", name: "lkey");
    log("remeberme ${rememberMe.value}", name: "lkey");
    if (isPWD_auth.value) {
      if (!rememberMe.value && !_isAuthFromBiometric) {
        userPasswordController.clear();
      }
      FocusScope.of(Get.context!).requestFocus(passwordFocus);
    }

    switch (authType.value) {
      case AuthType.both:
        debugPrint("✅ Both Password and OTP authentication are required.");
        break;
      case AuthType.passwordOnly:
        debugPrint("🔐 Only Password authentication is required.");
        break;
      case AuthType.otpOnly:
        debugPrint("📲 Only OTP authentication is required.");
        break;
      case AuthType.none:
        debugPrint("❌ No authentication required.");
        break;
    }
  }

  Future<bool> _hasNetworkInterface() async {
    try {
      final results = await Connectivity().checkConnectivity();
      final connected = results.any(
        (result) => result != ConnectivityResult.none,
      );
      if (Get.isRegistered<InternetConnectivity>()) {
        Get.find<InternetConnectivity>().isConnected.value = connected;
      }
      return connected;
    } catch (_) {
      return Get.isRegistered<InternetConnectivity>() &&
          Get.find<InternetConnectivity>().isConnected.value;
    }
  }

  bool _isNetworkUnavailableMessage(String message) {
    final normalized = message.toLowerCase();
    return const [
      'network error',
      'request timed out',
      'socketexception',
      'failed host lookup',
      'connection refused',
      'connection reset',
      'network is unreachable',
      'no address associated with hostname',
    ].any(normalized.contains);
  }

  Future<bool> _beginOfflineLogin() async {
    final project = selectedProject.value;
    final username = userNameController.text.trim();
    errUserName.value = '';
    errPassword.value = '';
    if (project == null || username.isEmpty) return false;

    isUserDataLoading.value = true;
    Map<String, dynamic>? user;
    try {
      user = await OfflineDbModule.getOfflineUser(
        projectName: project.schemaName,
        username: username,
      );
    } finally {
      isUserDataLoading.value = false;
    }
    final isAvailable =
        (user?[OfflineDBConstants.COL_IS_OFFLINE_AVAILABLE] as num?)?.toInt() ==
        1;
    final passwordHash =
        user?[OfflineDBConstants.COL_PASSWORD_HASH]?.toString() ?? '';
    if (!isAvailable || passwordHash.isEmpty) {
      isOfflineLoginMode.value = false;
      isPWD_auth.value = false;
      isOTP_auth.value = false;
      authType.value = AuthType.none;
      errUserName.value =
          'You are not an offline user. Connect to the internet and sign in first.';
      return false;
    }

    isOfflineLoginMode.value = true;
    isPWD_auth.value = true;
    isOTP_auth.value = false;
    authType.value = AuthType.passwordOnly;
    userPasswordController.clear();
    FocusScope.of(Get.context!).requestFocus(passwordFocus);
    return true;
  }

  Future<void> completeOfflineLogin() async {
    if (!isOfflineLoginMode.value || isSigninApiCalling.value) return;
    final project = selectedProject.value;
    final username = userNameController.text.trim();
    final password = userPasswordController.text;
    if (project == null) return;
    if (password.trim().isEmpty) {
      errPassword.value = 'Password is required';
      return;
    }

    isSigninApiCalling.value = true;
    signInApiStatusMessage.value = 'Checking offline credentials...';
    errPassword.value = '';
    try {
      final valid = await OfflineDbModule.validateOfflineLogin(
        projectName: project.schemaName,
        username: username,
        password: password,
      );
      if (!valid) {
        errPassword.value = 'Incorrect password';
        return;
      }

      await OfflineDbModule.markOfflineLogin(
        projectName: project.schemaName,
        username: username,
      );
      await StorageService.cacheProjectDetails(
        projectName: project.schemaName,
        userName: username,
        webUrl: project.url,
        armUrl: project.armurl,
      );
      await StorageService.saveUserSession(
        token: '',
        sessionId: '',
        userName: username,
        nickName: username,
        projectname: project.schemaName,
      );
      await StorageService.setOfflineMode(true);
      userPasswordController.clear();
      await Get.offAllNamed(Routes.OFFLINE_LISTING_PAGE);
    } finally {
      isSigninApiCalling.value = false;
      signInApiStatusMessage.value = '';
    }
  }

  bool validateForm() {
    if (_isAuthFromBiometric) return true;

    errPassword.value = errUserName.value = "";
    if (userNameController.text.toString().trim() == "") {
      errUserName.value = "Enter User Name";
      return false;
    }
    if (isPWD_auth.value) {
      if (userPasswordController.text.toString().trim() == "") {
        errPassword.value = "Password is required";
        return false;
      }
    }
    return true;
  }

  Future<AuthType> getLoginUserDetailsAndAuthType() async {
    isUserDataLoading.value = true;
    FocusManager.instance.primaryFocus?.unfocus();

    final projectName = selectedProject.value?.schemaName ?? '';
    final username =
        _verifiedBiometricLogin?['username']?.toString() ??
        userNameController.text.trim();
    // 2. Call the new ApiManager method
    final result = await ApiManager.instance.getLoginUserDetails(
      projectName: projectName,
      userName: username,
    );

    isUserDataLoading.value = false;

    // 3. Handle the result cleanly
    switch (result) {
      case ApiSuccess(data: final authUserdetails):
        // globalVariableController.USER_NAME.value = userName;

        // Safely extract auth flags (adding fallback defaults '?? false' just in case)
        isPWD_auth.value = authUserdetails.pwdauth ?? false;

        if (authUserdetails.otpauth == true) {
          isOTP_auth.value = true;
          otpChars.value = authUserdetails.otpsettings?.otpchars ?? "0";
          otpExpiryTime.value = authUserdetails.otpsettings?.otpexpiry ?? "0";
        } else {
          isOTP_auth.value = false;
        }

        // Determine Auth Type
        if (isPWD_auth.value && isOTP_auth.value) return AuthType.both;
        if (isPWD_auth.value) return AuthType.passwordOnly;
        if (isOTP_auth.value) return AuthType.otpOnly;

        return AuthType.none;

      case ApiError(message: final errorMsg):
        if (_isNetworkUnavailableMessage(errorMsg)) {
          await _beginOfflineLogin();
          return AuthType.none;
        }
        Get.snackbar(
          "Error",
          errorMsg, // Shows exactly what went wrong (network issue or backend message)
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.redAccent,
          colorText: Colors.white,
        );
        return AuthType.none;
    }
  }

  void _startLogin() {
    isSigninApiCalling.value = true;
    _updateLoginStatus('Signing you in..');
  }

  void _updateLoginStatus(String msg) {
    signInApiStatusMessage.value = msg;
  }

  void _stopLogin() {
    isSigninApiCalling.value = false;
    _updateLoginStatus('');
  }

  Future<void> callSignInAPI() async {
    if (isSigninApiCalling.value || !validateForm()) return;
    final project = selectedProject.value;
    if (project == null) return;
    if (_isAuthFromBiometric &&
        (_verifiedBiometricConnection !=
                StorageService.connectionLoginKey(project) ||
            _eligibleBiometricLogin(project)?['username'] !=
                _verifiedBiometricLogin?['username'])) {
      return;
    }
    final username =
        _verifiedBiometricLogin?['username']?.toString() ??
        userNameController.text.trim();
    final rawPassword = userPasswordController.text.trim();
    final password =
        _verifiedBiometricLogin?['password']?.toString() ??
        generateMd5(AppConst.SEED + generateMd5(rawPassword));
    final _LoginAttempt attempt = (
      project: project,
      username: username,
      passwordHash: rawPassword.isNotEmpty || _isAuthFromBiometric
          ? password
          : '',
      rememberedPassword: userPasswordController.text,
      remember: rememberMe.value,
    );
    await _submitSignIn(attempt, password: password, useOtp: isOTP_auth.value);
  }

  Future<void> _submitSignIn(
    _LoginAttempt attempt, {
    required String password,
    required bool useOtp,
    bool clearPreviousSession = false,
  }) async {
    if (isClosed || isSigninApiCalling.value) return;
    _pendingOtpLogin = null;
    FocusManager.instance.primaryFocus?.unfocus();
    _startLogin();
    final project = attempt.project;
    final username = attempt.username;
    var signInBody = {
      "appname": project.schemaName,
      "username": username,
      "Seed": AppConst.SEED,
      "password": password,
      "Language": "English",
      "SessionId": getGUID(),
      "Globalvars": false,
      "ClearPreviousSession": clearPreviousSession,
      if (useOtp) "OtpAuth": "T",
    };
    final armBase = project.armurl.trim();
    final url = armBase.isEmpty
        ? ApiEndpoints.API_SIGNIN
        : '${armBase.endsWith('/') ? armBase : '$armBase/'}${ApiEndpoints.API_SIGNIN}';

    final result = await ApiManager.instance.signIn(url: url, body: signInBody);

    // LoadingScreen.dismiss();

    switch (result) {
      case ApiSuccess(data: final response):
        log(response.rawData.toString(), name: "callSignInAPI");
        if (response.isSuccess) {
          if (response.message == "Login Successful.") {
            StorageService.saveUserRole(
              response.rawData["role"].toString().toLowerCase(),
            );
            await _completeSignIn(attempt, response.rawData);
          } else if (response.otpLoginKey != null) {
            _pendingOtpLogin = attempt;
            otpMsg.value = response.message;
            otpLoginKey.value = response.otpLoginKey!;
            debugPrint(
              "Otpmsg: ${otpMsg.value} \nOtpkey: ${otpLoginKey.value}",
            );
            startOtpTimer();
            Get.toNamed(Routes.OTP);
          }
        } else {
          // Backend processed the request but threw a business logic error
          if (response.isDuplicateSession) {
            showDialog_duplicateSession(
              message: response.message,
              onConfirm: () => _submitSignIn(
                attempt,
                password: password,
                useOtp: useOtp,
                clearPreviousSession: true,
              ),
            );
          } else if (response.isChangePassword) {
            showDialog_changePassword(username: username);
          } else {
            if (Get.isDialogOpen ?? false) Get.back();
            Get.snackbar(
              "Error",
              response.message,
              snackPosition: SnackPosition.BOTTOM,
              backgroundColor: Colors.redAccent,
              colorText: Colors.white,
            );
          }
        }
        break;

      case ApiError(message: final errorMsg):
        // True network or parsing crashes
        if (Get.isDialogOpen ?? false) Get.back();
        if (_isNetworkUnavailableMessage(errorMsg)) {
          await _beginOfflineLogin();
          break;
        }
        Get.snackbar(
          "Error",
          errorMsg,
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.redAccent,
          colorText: Colors.white,
        );
        break;
    }

    _stopLogin();
  }

  String getGUID() {
    final uuid = Uuid();
    // Generate a v4 (random) GUID
    String guid = uuid.v4();
    return guid;
  }

  String generateMd5(String input) {
    return md5.convert(utf8.encode(input)).toString();
  }

  Future<void> _completeSignIn(
    _LoginAttempt attempt,
    Map<String, dynamic> json, {
    bool isFromOtp = false,
  }) async {
    final projectname = attempt.project.schemaName;
    final userName = attempt.username;

    final token = json["token"]?.toString() ?? "";
    final sessionId = json["ARMSessionId"]?.toString() ?? "";

    final nickName = json["nickname"]?.toString() ?? userName;
    await StorageService.cacheProjectDetails(
      projectName: projectname,
      userName: userName,
      webUrl: attempt.project.url,
      armUrl: attempt.project.armurl,
    );
    await StorageService.saveUserSession(
      token: token,
      sessionId: sessionId,
      userName: userName,
      nickName: nickName,
      projectname: projectname,
    );
    await StorageService.setOfflineMode(false);

    // If you still need to log the change password status:
    // final changePwd = json["ChangePassword"]?.toString() ?? "false";
    // await StorageService.setString(StorageService._keyChangePassword, changePwd);
    // LogService.writeLog(
    //   message: "[-] LoginController\nScope:SignInResponse()\nSession saved for user: $userName"
    // );

    final rawPassword = attempt.rememberedPassword.trim();
    await OfflineDbModule.saveUser(
      projectName: projectname,
      username: userName,
      passwordHash: rawPassword.isEmpty ? '' : generateMd5(rawPassword),
      loginResult: json,
    );

    // 2. Handle Remember Me state
    final connection = StorageService.connectionLoginKey(attempt.project);
    if (attempt.remember) {
      await StorageService.rememberCredentialsForProject(
        projectName: connection,
        username: userName,
        password: attempt.rememberedPassword,
        group: ddSelectedValue.value,
      );
    } else {
      await StorageService.forgetCredentialsForProject(connection);
    }
    _rememberedBiometricUser = attempt.remember ? userName : null;
    await StorageService.saveCompletedBiometricLogin(
      project: attempt.project,
      username: userName,
      passwordHash: attempt.passwordHash,
      remember: attempt.remember,
    );

    // 3. Navigate
    await _processLoginAndGoToHomePage(isFromOtp: isFromOtp);
  }

  Future<void> _processLoginAndGoToHomePage({bool isFromOtp = false}) async {
    //mobile Notification
    _updateLoginStatus('connecting to axpert');
    await _callApiForMobileNotification();
    //connect to Axpert
    // await _callApiForConnectToAxpert();
    // Get.offAllNamed(Routes.LandingPage);
    //
    //burnur code for navigating to ess portal - amrith--->

    // var sessionid = StorageService.sessionId ?? '';

    // if (sessionid.isEmpty) return;
    // var url = await AppConst.getFullWebUrl(
    //   "aspx/mainnew.aspx?authKey=AXPERT-$sessionid",
    // );

    // var webviewController = Get.put(WebViewController());
    // webviewController.currentUrl.value = '';
    // Get.to(Routes.WEBVIEW);
    // webviewController.openWebView(url: url);
    // WebViewController.open(url: url);
    // isPWD_auth.value = false;
    isOTP_auth.value = false;
    isPWD_auth.value = false;
    authType.value = AuthType.none;
    if (isFromOtp) {
      await Get.offNamed(Routes.WEBVIEW);
    } else {
      await Get.toNamed(Routes.WEBVIEW);
    }
    // Let the completed sign-in release its busy state before prompting again.
    if (!isClosed) unawaited(setWillAuthenticate());
  }

  Future<void> _callApiForMobileNotification() async {
    var imei = '';

    final deviceInfoPlugin = DeviceInfoPlugin();
    final deviceInfo = defaultTargetPlatform == TargetPlatform.android
        ? await deviceInfoPlugin.androidInfo
        : defaultTargetPlatform == TargetPlatform.iOS
        ? await deviceInfoPlugin.iosInfo
        : null;

    if (deviceInfo == null) {
      AppConst.DEVICE_ID = '';
    } else {
      final allInfo = deviceInfo.data;
      imei =
          allInfo['id']?.toString() ??
          allInfo['identifierForVendor']?.toString() ??
          '';
    }

    // LogService.writeLog(message: "[i] IMEI : $imei");

    var url = await AppConst.getFullARMUrl(
      ApiEndpoints.API_MOBILE_NOTIFICATION,
    );
    var sessionId = StorageService.sessionId ?? "";
    var fcm = fcmId = StorageService.fcmid ?? "0";
    print("AUTHCONTROLLER. fcmid $fcm");
    // Calling the API manager is now super simple
    final result = await ApiManager.instance.sendMobileNotificationDetails(
      url: url,
      sessionId: sessionId,
      firebaseId: fcm,
      imei: imei,
    );

    switch (result) {
      case ApiSuccess():
        debugPrint("Mobile Notification Registered Successfully.");
        break;
      case ApiError(message: final errorMsg):
        debugPrint("Mobile Notification API Failed: $errorMsg");
        break;
    }
  }

  void showDialog_duplicateSession({
    required String message,
    required Future<void> Function() onConfirm,
  }) {
    // Make sure to close any existing dialogs first
    if (Get.isDialogOpen ?? false) Get.back();

    final context = Get.context!;
    const loginBlue = ConnectionStyle.navy;
    final accentText = ConnectionStyle.dark(context)
        ? const Color(0xff9DB6FF)
        : loginBlue;
    Get.dialog(
      Dialog(
        backgroundColor: ConnectionStyle.card(context),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.warning_amber_rounded,
                color: Colors.orange,
                size: 48,
              ),
              const SizedBox(height: 16),
              Text(
                "Duplicate Session",
                style: GoogleFonts.poppins(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: accentText,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                message,
                style: GoogleFonts.poppins(
                  fontSize: 15,
                  color: ConnectionStyle.ink(context),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        foregroundColor: accentText,
                        backgroundColor: ConnectionStyle.card(context),

                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(color: accentText),
                        ),
                      ),
                      onPressed: () =>
                          Get.back(), // Just close the dialog instead of offAll
                      child: const Text("No"),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ConnectionButton(
                      label: 'Yes',
                      onPressed: () async {
                        Get.back();
                        await onConfirm();
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      barrierDismissible: false,
    );
  }

  void showDialog_changePassword({required String username}) {
    if (Get.isDialogOpen ?? false) Get.back();

    // Clear fields
    oPassCtrl.clear();
    nPassCtrl.clear();
    cnPassCtrl.clear();

    // Clear errors
    errOPass.value = "";
    errNPass.value = "";
    errCNPass.value = "";

    // Reset password visibility
    showOldPass.value = false;
    showNewPass.value = false;
    showConNewPass.value = false;

    Get.dialog(
      barrierDismissible: false,
      PopScope(
        canPop: false,
        child: Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: Get.height * 0.85),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Obx(
                    () => ProjectLogo(
                      url: selectedProject.value?.logourl ?? '',
                      imageBytes: selectedProject.value?.logoData,
                      projectName: currentProjectName.value,
                      size: 45,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    "Reset Password",
                    style: GoogleFonts.poppins(
                      fontSize: 22,
                      fontWeight: FontWeight.w500,
                      color: selectedColor.value ?? AppColors.darkBlue,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "Please enter your existing password and choose a new password.",
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(
                      color: Colors.grey,
                      fontSize: 14,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Notice we are passing the RxString itself (errOPass), NOT .value!
                  buildPasswordField(
                    controller: oPassCtrl,
                    label: "Existing Password",
                    hint: "Enter existing password",
                    showPassword: showOldPass,
                    error: errOPass,
                  ),
                  const SizedBox(height: 16),
                  buildPasswordField(
                    controller: nPassCtrl,
                    label: "New Password",
                    hint: "Enter new password",
                    showPassword: showNewPass,
                    error: errNPass,
                  ),
                  const SizedBox(height: 16),
                  buildPasswordField(
                    controller: cnPassCtrl,
                    label: "Confirm Password",
                    hint: "Re-enter new password",
                    showPassword: showConNewPass,
                    error: errCNPass,
                  ),
                  const SizedBox(height: 32),

                  Row(
                    children: [
                      // Expanded(
                      //   child: OutlinedButton(
                      //     style: OutlinedButton.styleFrom(
                      //       foregroundColor:
                      //           selectedColor.value ?? AppColors.darkBlue,
                      //       padding: const EdgeInsets.symmetric(vertical: 14),
                      //       shape: RoundedRectangleBorder(
                      //         borderRadius: BorderRadius.circular(12),
                      //         side: BorderSide(color: AppColors.accentCoral),
                      //       ),
                      //     ),
                      //     onPressed: () => Get.back(),

                      //     child: const Text("Cancel"),
                      //   ),
                      // ),
                      Expanded(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            foregroundColor:
                                selectedColor.value ?? AppColors.darkBlue,

                            backgroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: BorderSide(
                                color:
                                    selectedColor.value ?? AppColors.darkBlue,
                              ),
                            ),
                            elevation: 0,
                          ),
                          onPressed: () => Get.back(),
                          child: Text(
                            "Cancel",
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            backgroundColor:
                                selectedColor.value ?? AppColors.darkBlue,

                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 0,
                          ),
                          onPressed: () =>
                              changePasswordCalled(username: username),
                          child: Text(
                            "Save",
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // Helper Widget
  Widget buildPasswordField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required RxBool showPassword,
    required RxString error, // CHANGED from String to RxString
  }) {
    return Obx(
      () => TextField(
        controller: controller,
        obscureText: !showPassword.value,
        style: GoogleFonts.poppins(fontWeight: FontWeight.w500),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: GoogleFonts.poppins(
            fontWeight: FontWeight.w500,
            color: (selectedColor.value ?? AppColors.darkBlue).withValues(
              alpha: 0.5,
            ),
          ),
          hintStyle: GoogleFonts.poppins(
            fontWeight: FontWeight.w500,
            color: (selectedColor.value ?? AppColors.darkBlue).withValues(
              alpha: 0.15,
            ),
          ),
          floatingLabelStyle: GoogleFonts.poppins(
            fontWeight: FontWeight.w500,
            color: (selectedColor.value ?? AppColors.darkBlue),
          ),
          hintText: hint,
          // Now it correctly listens to changes in the error text!
          errorText: error.value.isEmpty ? null : error.value,
          filled: true,
          fillColor: (selectedColor.value ?? AppColors.darkBlue).withValues(
            alpha: 0.1,
          ), // Ensure MyColors is defined
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 16,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
              color: selectedColor.value ?? AppColors.darkBlue,
              width: 1.5,
            ),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Colors.redAccent, width: 1.5),
          ),
          suffixIcon: IconButton(
            icon: Icon(
              showPassword.value ? Icons.visibility_off : Icons.visibility,
              color: (selectedColor.value ?? AppColors.darkBlue).withValues(
                alpha: 0.5,
              ),
            ),
            onPressed: showPassword.toggle,
          ),
        ),
      ),
    );
  }

  Future<void> changePasswordCalled({required String username}) async {
    if (!validForm()) return;

    FocusManager.instance.primaryFocus?.unfocus();

    var projectName = selectedProject.value?.schemaName ?? '';
    var url = await AppConst.getFullARMUrl(ApiEndpoints.API_CHANGE_PASSWORD);
    var appName = projectName;

    var oldPasswordHash = generateMd5(oPassCtrl.text.trim());
    var newPassword = nPassCtrl.text.trim();

    final result = await ApiManager.instance.changePassword(
      url: url,
      appName: appName,
      username: username,
      oldPasswordHash: oldPasswordHash,
      newPassword: newPassword,
    );

    // 4. Handle Result cleanly
    switch (result) {
      case ApiSuccess(data: final successMessage):
        Get.defaultDialog(
          title: "Success!",
          middleText: successMessage,
          titleStyle: GoogleFonts.poppins(
            color: AppColors.darkBlue,
            fontWeight: FontWeight.bold,
          ),
          confirm: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.darkBlue,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () {
              userPasswordController.clear();
              Get.close(
                2,
              ); // Closes the Success Dialog AND the Change Password Dialog
            },
            child: const Text("Ok"),
          ),
        );
        break;

      case ApiError(message: final errorMsg):
        error(errorMsg);
        break;
    }
  }

  bool validForm() {
    errOPass.value = '';
    errNPass.value = '';
    errCNPass.value = '';

    if (oPassCtrl.text.trim().isEmpty) {
      errOPass.value = "Enter Existing password";
      return false;
    }

    if (nPassCtrl.text.trim().isEmpty) {
      errNPass.value = "Enter New password";
      return false;
    }

    if (cnPassCtrl.text.trim().isEmpty) {
      errCNPass.value = "Enter Confirm password";
      return false;
    }

    if (nPassCtrl.text.trim() != cnPassCtrl.text.trim()) {
      errCNPass.value = "New password and Confirm password do not match";
      return false;
    }

    return true;
  }

  void error(String msg) {
    Get.snackbar(
      "Error!",
      msg,
      snackPosition: SnackPosition.BOTTOM,
      colorText: Colors.white,
      backgroundColor: Colors.red,
    );
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

  String get otpFormattedTime {
    final minutes = (otpRemainingSeconds.value ~/ 60).toString().padLeft(
      1,
      '0',
    );
    final seconds = (otpRemainingSeconds.value % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds min';
  }

  void startOtpTimer() {
    _otpTimer?.cancel();
    otpRemainingSeconds.value = (int.tryParse(otpExpiryTime.value) ?? 2) * 60;
    _otpTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (otpRemainingSeconds.value > 0) {
        otpRemainingSeconds.value--;
      } else {
        timer.cancel();
      }
    });
  }

  @override
  void onClose() {
    _otpTimer?.cancel(); // Prevent memory leaks when controller dies
    super.onClose();
  }

  // ── OTP Methods ────────────────────────────────────────────────────────
  bool validateOTPField() {
    otpErrorText.value = "";
    final requiredLength = int.tryParse(otpChars.value) ?? 4;

    if (otpFieldController.text.length < requiredLength) {
      otpErrorText.value = "Enter full $requiredLength-digit OTP";
      return false;
    }
    return true;
  }

  Future<void> callVerifyOTP() async {
    final attempt = _pendingOtpLogin;
    if (attempt == null || isOtpLoading.value || !validateOTPField()) return;

    isOtpLoading.value = true;
    final result = await ApiManager.instance.validateLoginOTP(
      otpLoginKey: otpLoginKey.value,
      otp: otpFieldController.text.trim(),
    );
    isOtpLoading.value = false;
    if (!identical(_pendingOtpLogin, attempt)) return;

    switch (result) {
      case ApiSuccess(data: final response):
        _pendingOtpLogin = null;
        otpFieldController.clear();
        await _completeSignIn(attempt, response, isFromOtp: true);
        break;
      case ApiError(message: final errorMsg):
        otpErrorText.value = errorMsg;
        break;
    }
  }

  Future<void> callResendOTP() async {
    otpErrorText.value = '';
    otpFieldController.clear();
    isOtpLoading.value = true;

    final result = await ApiManager.instance.resendLoginOTP(
      otpLoginKey: otpLoginKey.value,
    );
    isOtpLoading.value = false;

    switch (result) {
      case ApiSuccess(data: final successMsg):
        Get.snackbar(
          "Success",
          successMsg,
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.green,
          colorText: Colors.white,
        );
        startOtpTimer(); // Restart timer on success
        break;
      case ApiError(message: final errorMsg):
        otpErrorText.value = errorMsg;
        break;
    }
  }
}
