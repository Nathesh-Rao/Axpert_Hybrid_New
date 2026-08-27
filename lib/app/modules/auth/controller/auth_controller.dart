// ignore_for_file: non_constant_identifier_names

import 'dart:convert';

import 'package:axpert/app/core/common.dart';
import 'package:axpert/app/data/const/app_const.dart';
import 'package:axpert/app/data/enums/auth_enums.dart';
import 'package:axpert/app/data/models/project_model.dart';
import 'package:axpert/app/data/services/api_endpoints.dart';
import 'package:axpert/app/data/services/api_manger.dart';
import 'package:axpert/app/data/services/storage_service.dart';
import 'package:axpert/app/modules/webview/controller/webview_controller.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:uuid/uuid.dart';
import 'package:crypto/crypto.dart';

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
  var otpChars = '4'.obs;
  var otpExpiryTime = '2'.obs;
  var authType = AuthType.none.obs;
  var otpMsg = ''.obs;
  var otpLoginKey = ''.obs;
  var otpErrorText = ''.obs;
  bool isDuplicate_session = false;
  bool isAxpertConnectEstablished = false;
  final bool _isAuthFromBiometric = false;

  TextEditingController oPassCtrl = TextEditingController();
  TextEditingController nPassCtrl = TextEditingController();
  TextEditingController cnPassCtrl = TextEditingController();
  var errOPass = ''.obs;
  var errNPass = ''.obs;
  var errCNPass = ''.obs;
  var showOldPass = false.obs;
  var showNewPass = false.obs;
  var showConNewPass = false.obs;

  void onLoad() async {
    await refreshCurrentProject();
  }

  Future<void> refreshCurrentProject() async {
    selectedProject.value = await StorageService.getLastSelectedProject();
    currentProjectName.value = selectedProject.value?.schemaName ?? '';
    selectedColor.value = AppColors.colorFromHex(
      selectedProject.value?.color ?? '',
    );
  }

  Future<String> getVersionName() async {
    PackageInfo packageInfo = await PackageInfo.fromPlatform();
    // String appName = packageInfo.appName;
    // String packageName = packageInfo.packageName;
    var version = packageInfo.version;
    // String buildNumber = packageInfo.buildNumber;
    AppConst.APP_VERSION = version; //+ "." + Const.APP_RELEASE_ID;
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
    // If Const.getFullARMUrl simply gives the full string, you can adjust the ApiManager slightly.

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
  }

  void _stopLogin() {
    isSigninApiCalling.value = false;
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

    if (isDuplicate_session) signInBody["ClearPreviousSession"] = true;
    if (isOTP_auth.value) signInBody["OtpAuth"] = "T";

    var url = await AppConst.getFullARMUrl(ApiEndpoints.API_SIGNIN);

    // 2. Call ApiManager
    print(url);
    print(signInBody.toString());
    final result = await ApiManager.instance.signIn(url: url, body: signInBody);

    // LoadingScreen.dismiss();

    // 3. Handle UI States

    switch (result) {
      case ApiSuccess(data: final response):
        if (response.isSuccess) {
          StorageService.storeLastLoginData(projectName, signInBody);

          if (response.message == "Login Successful.") {
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
            showDialog_duplicateSession(response.message);
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

    await StorageService.saveUserSession(
      token: token,
      sessionId: sessionId,
      userName: userName,
      nickName: nickName,
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
    await _callApiForMobileNotification();
    //connect to Axpert
    // await _callApiForConnectToAxpert();
    // Get.offAllNamed(Routes.LandingPage);
    //
    //burnur code for navigating to ess portal - amrith--->
    final result = await ApiManager.instance.connectToAxpert();

    if (result is ApiSuccess<bool>) {
      isAxpertConnectEstablished = result.data;
    } else if (result is ApiError<bool>) {
      error(result.message);
    }
    var sessionid = StorageService.sessionId ?? '';
    var url = await AppConst.getFullWebUrl(
      "aspx/mainnew.aspx?authKey=AXPERT-$sessionid",
    );

    WebViewController.open(url: url);
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
    var fcm = fcmId ?? "0";

    // Calling the API manager is now super simple
    final result = await ApiManager.instance.sendMobileNotificationDetails(
      url: url,
      sessionId: sessionId,
      firebaseId: fcm,
      imei: imei,
    );

    switch (result) {
      case ApiSuccess():
        print("Mobile Notification Registered Successfully.");
        break;
      case ApiError(message: final errorMsg):
        print("Mobile Notification API Failed: $errorMsg");
        break;
    }
  }

  void showDialog_duplicateSession(String message) {
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
              const Text(
                "Duplicate Session",
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppColors.darkBlue, // Ensure MyColors is imported
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                message,
                style: const TextStyle(fontSize: 15, color: Colors.black87),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
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
                        backgroundColor: AppColors.darkBlue,
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
                  Image.asset("assets/images/axpert_03.png", height: 45),
                  const SizedBox(height: 24),
                  const Text(
                    "Reset Password",
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: AppColors.darkBlue,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    "Please enter your existing password and choose a new password.",
                    textAlign: TextAlign.center,
                    style: TextStyle(
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
                      Expanded(
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onPressed: () => Get.back(),
                          child: const Text("Cancel"),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            backgroundColor: AppColors.darkBlue,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 0,
                          ),
                          onPressed: () => changePasswordCalled(),
                          child: const Text(
                            "Save",
                            style: TextStyle(fontWeight: FontWeight.bold),
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
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          // Now it correctly listens to changes in the error text!
          errorText: error.value.isEmpty ? null : error.value,
          filled: true,
          fillColor: AppColors.grey400, // Ensure MyColors is defined
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
            borderSide: BorderSide(color: AppColors.darkBlue, width: 1.5),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Colors.redAccent, width: 1.5),
          ),
          suffixIcon: IconButton(
            icon: Icon(
              showPassword.value ? Icons.visibility_off : Icons.visibility,
              color: Colors.grey.shade600,
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
          titleStyle: const TextStyle(
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
}
