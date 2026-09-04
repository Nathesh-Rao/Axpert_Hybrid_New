// ignore_for_file: non_constant_identifier_names

import 'dart:async';
import 'dart:convert';
import 'dart:developer';

import 'package:axpert/app/core/common.dart';
import 'package:axpert/app/core/common/methods.dart';
import 'package:axpert/app/data/const/app_const.dart';
import 'package:axpert/app/data/enums/auth_enums.dart';
import 'package:axpert/app/data/models/project_model.dart';
import 'package:axpert/app/data/services/api/api_endpoints.dart';
import 'package:axpert/app/data/services/api/api_manger.dart';
import 'package:axpert/app/data/services/storage/storage_service.dart';
import 'package:axpert/app/db/project_database.dart';
import 'package:axpert/app/modules/webview/controller/webview_controller.dart';
import 'package:axpert/app/modules/webview/webview_view.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:uuid/uuid.dart';
import 'package:crypto/crypto.dart';

import '../../offline_form_pages/db/db.dart';

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
  var signInApiStatusMessage = ''.obs;
  var otpChars = '4'.obs;
  var otpExpiryTime = '2'.obs;
  var authType = AuthType.none.obs;
  var otpMsg = ''.obs;
  var otpLoginKey = ''.obs;
  var otpErrorText = ''.obs;
  bool isDuplicate_session = false;
  bool isAxpertConnectEstablished = false;
  bool _isAuthFromBiometric = false;
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
      case DbError(:final message):
        error(message);
    }
    // isLoadingProjects.value = false;
  }

  Future<void> refreshCurrentProject() async {
    isOTP_auth.value = false;
    isPWD_auth.value = false;
    authType.value = AuthType.none;
    selectedProject.value = await StorageService.getLastSelectedProject();
    currentProjectName.value = selectedProject.value?.schemaName ?? '';
    selectedColor.value = AppColors.colorFromHex(
      selectedProject.value?.color ?? '',
    );

    var userName = StorageService.getRememberedUser(currentProjectName.value);
    if (userName != null) {
      rememberMe.value = true;
      userNameController.text = userName;
      userPasswordController.text =
          StorageService.getRememberedPassword(currentProjectName.value) ?? '';

      await setWillAuthenticate();
    } else {
      rememberMe.value = false;
      userNameController.text = '';
      userPasswordController.text = '';
    }
  }

  var isBiometricLoading = false.obs;

  Future<void> setWillAuthenticate() async {
    isBiometricLoading.value = true;
    await checkBiometricFlag();
    isBiometricLoading.value = false;

    var willAuth = StorageService.getWillBiometricAuthenticateForThisUser(
      projectName: selectedProject.value?.schemaName.trim() ?? '',
      username: userNameController.text.toString().trim(),
    );
    print(("Login willAuth: $willAuth"));
    // LogService.writeLog(
    //     message:
    //         "[i] LoginController\nScope: setWillAuthenticate()\nLogin willAuth: $willAuth");

    if (willAuth != null) {
      willBio_userAuthenticate.value = willAuth;
    }
    if (isBiometricAvailable.value) displayAuthenticationDialog();
  }

  void displayAuthenticationDialog() async {
    if (willBio_userAuthenticate.value) {
      try {
        if (await CommonMethods.showBiometricDialog()) {
          _isAuthFromBiometric = true;
          await startLoginProcess();
          // loginButtonClicked(bodyArgs: retrieveLastLoginData());
        }
      } catch (e) {
        print(e.toString());
        if (e.toString().contains('NotAvailable') &&
            e.toString().contains('Authentication failure')) {
          error(" Oops Only Biometric is allowed.");
        }
      } finally {
        _isAuthFromBiometric = false;
      }
    } else {
      print("willAuthenticate => $willBio_userAuthenticate");
    }
  }

  Future<void> checkBiometricFlag() async {
    final baseUrl = selectedProject.value?.armurl.trim() ?? '';
    final appName = selectedProject.value?.schemaName.trim() ?? '';

    final result = await ApiManager.instance.checkBiometricFlag(
      baseUrl: baseUrl,
      appName: appName,
    );

    switch (result) {
      case ApiSuccess(data: final isEnabled):
        isBiometricAvailable.value = isEnabled;
        debugPrint("User Biometric info (enabled): $isEnabled");
        break;
      case ApiError(message: final errorMsg):
        isBiometricAvailable.value = false;
        debugPrint("Failed to check biometric flag: $errorMsg");
        break;
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
    authType.value = await getLoginUserDetailsAndAuthType();

    if (authType.value == AuthType.otpOnly || _isAuthFromBiometric) {
      await callSignInAPI();
    }

    if (isPWD_auth.value) {
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

    // 1. Gather data for the request
    // Note: Assuming you have a way to pass the base ARM url here.
    // If AppConst.getFullARMUrl simply gives the full string, you can adjust the ApiManager slightly.

    var projectName = selectedProject.value?.schemaName ?? '';
    // 1. Retrieve the data
    final lastData = StorageService.retrieveLastLoginData(projectName);

    // 2. Extract values safely first (this avoids the ternary '?' syntax crash)
    final savedUsername = lastData?["username"]?.toString() ?? "";
    // final savedPassword = lastData?["password"]?.toString() ?? "";

    // 3. Now assign them cleanly
    var username = _isAuthFromBiometric
        ? savedUsername
        : userNameController.text.toString().trim();

    // var password = _isAuthFromBiometric
    //     ? savedPassword
    //     : generateMd5(
    //         AppConst.SEED +
    //             generateMd5(userPasswordController.text.toString().trim()),
    //       );
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
    if (!validateForm()) return;

    FocusManager.instance.primaryFocus?.unfocus();
    // LoadingScreen.show();
    _startLogin();

    // 1. Build the request body
    var projectName = selectedProject.value?.schemaName ?? '';
    // 1. Retrieve the data
    final lastData = StorageService.retrieveLastLoginData(projectName);

    // 2. Extract values safely first (this avoids the ternary '?' syntax crash)
    final savedUsername = lastData?["username"]?.toString() ?? "";
    final savedPassword = lastData?["password"]?.toString() ?? "";

    // 3. Now assign them cleanly
    var username = _isAuthFromBiometric
        ? savedUsername
        : userNameController.text.toString().trim();

    var password = _isAuthFromBiometric
        ? savedPassword
        : generateMd5(
            AppConst.SEED +
                generateMd5(userPasswordController.text.toString().trim()),
          );

    var signInBody = {
      "appname": projectName,
      "username": username,
      "Seed": AppConst.SEED,
      "password": password,
      "Language": "English",
      "SessionId": getGUID(),
      "Globalvars": false,
    };
    log(signInBody.toString(), name: "callSignInAPI body");
    if (isDuplicate_session) signInBody["ClearPreviousSession"] = true;
    if (isOTP_auth.value) signInBody["OtpAuth"] = "T";

    var url = await AppConst.getFullARMUrl(ApiEndpoints.API_SIGNIN);

    final result = await ApiManager.instance.signIn(url: url, body: signInBody);

    // LoadingScreen.dismiss();

    switch (result) {
      case ApiSuccess(data: final response):
        log(response.rawData.toString(), name: "callSignInAPI");
        if (response.isSuccess) {
          StorageService.storeLastLoginData(projectName, signInBody);

          if (response.message == "Login Successful.") {
            // showDialog_changePassword();
            StorageService.saveUserRole(
              response.rawData["role"].toString().toLowerCase(),
            );
            await OfflineDbModule.saveUser(
              projectName: currentProjectName.value,
              username: userNameController.text.toString().trim(),
              passwordHash: userPasswordController.text.toString().trim(),
              loginResult: response.rawData,
            );
            await processSignInDataResponse(projectName, response.rawData);
          } else if (response.otpLoginKey != null) {
            otpMsg.value = response.message;
            otpLoginKey.value = response.otpLoginKey!;
            debugPrint(
              "Otpmsg: ${otpMsg.value} \nOtpkey: ${otpLoginKey.value}",
            );
            Get.toNamed(Routes.OTP);
          }
        } else {
          // Backend processed the request but threw a business logic error
          if (response.isDuplicateSession) {
            isDuplicate_session = true;
            showDialog_duplicateSession(
              message: response.message,
              color: selectedColor.value,
            );
          } else if (response.isChangePassword) {
            showDialog_changePassword();
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

  Future<void> processSignInDataResponse(
    String projectname,
    Map<String, dynamic> json,
  ) async {
    final userName = userNameController.text.trim();

    final token = json["token"]?.toString() ?? "";
    final sessionId = json["ARMSessionId"]?.toString() ?? "";

    final nickName = json["nickname"]?.toString() ?? userName;
    await StorageService.cacheProjectDetails(
      projectName: projectname,
      userName: userName,
      webUrl: selectedProject.value?.url ?? '',
      armUrl: selectedProject.value?.armurl ?? '',
    );
    await StorageService.saveUserSession(
      token: token,
      sessionId: sessionId,
      userName: userName,
      nickName: nickName,
      projectname: projectname,
    );

    // If you still need to log the change password status:
    // final changePwd = json["ChangePassword"]?.toString() ?? "false";
    // await StorageService.setString(StorageService._keyChangePassword, changePwd);
    // LogService.writeLog(
    //   message: "[-] LoginController\nScope:SignInResponse()\nSession saved for user: $userName"
    // );

    // 2. Handle Remember Me state
    if (rememberMe.value) {
      StorageService.rememberCredentialsForProject(
        projectName: projectname,
        username: userNameController.text.trim(),
        password: userPasswordController.text,
        group: ddSelectedValue.value,
      );
    } else {
      StorageService.forgetCredentialsForProject(projectname);
    }

    // 3. Navigate
    await _processLoginAndGoToHomePage();
  }

  Future<void> _processLoginAndGoToHomePage() async {
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
    await Get.toNamed(Routes.WEBVIEW);
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

  void showDialog_duplicateSession({required String message, Color? color}) {
    // Make sure to close any existing dialogs first
    if (Get.isDialogOpen ?? false) Get.back();

    Get.dialog(
      Dialog(
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
                  color:
                      color ??
                      AppColors.darkBlue, // Ensure MyColors is imported
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                message,
                style: GoogleFonts.poppins(fontSize: 15, color: Colors.black87),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        foregroundColor: color ?? AppColors.darkBlue,
                        backgroundColor: Colors.white,

                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(color: color ?? AppColors.darkBlue),
                        ),
                      ),
                      onPressed: () =>
                          Get.back(), // Just close the dialog instead of offAll
                      child: const Text("No"),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: color ?? AppColors.darkBlue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                      onPressed: () {
                        Get.back(); // Close dialog first
                        callSignInAPI(); // Then call API
                      },
                      child: const Text("Yes"),
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

  void showDialog_changePassword() {
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
                  Image.network(
                    selectedProject.value?.logourl ?? "",
                    height: 45,
                    errorBuilder: (_, _, _) {
                      return Image.asset(
                        "assets/images/axpert_logo_new.png",
                        height: 45,
                      );
                    },
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
                          onPressed: () => changePasswordCalled(),
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

  void changePasswordCalled() async {
    if (!validForm()) return;

    FocusManager.instance.primaryFocus?.unfocus();

    var projectName = selectedProject.value?.schemaName ?? '';
    final lastData = StorageService.retrieveLastLoginData(projectName);

    final savedUsername = lastData?["username"]?.toString() ?? "";
    var url = await AppConst.getFullARMUrl(ApiEndpoints.API_CHANGE_PASSWORD);
    var appName = projectName;
    var username = savedUsername;

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
    if (!validateOTPField()) return;

    isOtpLoading.value = true;
    final result = await ApiManager.instance.validateLoginOTP(
      otpLoginKey: otpLoginKey.value,
      otp: otpFieldController.text.trim(),
    );
    isOtpLoading.value = false;

    switch (result) {
      case ApiSuccess(data: final response):
        await processSignInDataResponse(currentProjectName.value, response);
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
