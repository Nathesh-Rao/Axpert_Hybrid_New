// import 'dart:convert';
// import 'package:axpert/app/data/const/app_const.dart';
// import 'package:http/http.dart' as http;

// import '../models/client_id_result.dart';

// sealed class ApiResult<T> {}

// class ApiSuccess<T> extends ApiResult<T> {
//   final T data;
//   ApiSuccess(this.data);
// }

// class ApiError<T> extends ApiResult<T> {
//   final String message;
//   ApiError(this.message);
// }

// class ApiManager {
//   ApiManager._();
//   static final ApiManager instance = ApiManager._();

//   Future<ApiResult<ClientIdResult>> fetchProjectFromClientId(
//     String clientId,
//   ) async {
//     try {
//       final body = _buildClientIdRequest(clientId.trim().toLowerCase());

//       final response = await http
//           .post(
//             Uri.parse(AppConst.cloudUrl + AppConst.urlGetChoices),
//             body: body,
//             headers: {
//               'Content-Type': 'application/json',
//               'Accept': 'application/json',
//             },
//           )
//           .timeout(const Duration(seconds: 15));

//       if (response.statusCode == 200) {
//         final json = jsonDecode(response.body) as Map<String, dynamic>;

//         // Guard: check result exists and has data
//         final resultList = json['result'] as List?;
//         if (resultList == null || resultList.isEmpty) {
//           return ApiError('No project found for this access code.');
//         }

//         final rows = resultList[0]['result']['row'] as List?;
//         if (rows == null || rows.isEmpty) {
//           return ApiError('No project found for this access code.');
//         }

//         return ApiSuccess(ClientIdResult.fromJson(json));
//       }

//       if (response.statusCode == 404) {
//         return ApiError('Service not found. Check your network.');
//       }

//       return ApiError(
//         'Server error (${response.statusCode}). Please try again.',
//       );
//     } on http.ClientException {
//       return ApiError('Network error. Please check your connection.');
//     } on FormatException {
//       return ApiError('Invalid response from server.');
//     } catch (e) {
//       return ApiError('Something went wrong: $e');
//     }
//   }

//   // ── Request builder ───────────────────────────────────────────────
//   String _buildClientIdRequest(String clientId) {
//     return jsonEncode({
//       '_parameters': [
//         {
//           'getchoices': {
//             'axpapp': AppConst.cloudProject,
//             'username': AppConst.dummyUser,
//             'password': AppConst.dummyPwd,
//             'seed': AppConst.seedV,
//             'trace': 'true',
//             'sql': AppConst.sqlForClientId(clientId),
//             'direct': 'false',
//             'params': '',
//           },
//         },
//       ],
//     });
//   }
// }

// ignore_for_file: strict_top_level_inference, non_constant_identifier_names

import 'dart:async';
import 'dart:convert';
import 'package:axpert/app/core/utils/app_utility.dart';
import 'package:axpert/app/data/const/app_const.dart';
import 'package:axpert/app/data/models/auth_user_details_model.dart';
import 'package:axpert/app/data/services/api/api_endpoints.dart';
import 'package:axpert/app/data/services/storage/storage_service.dart';
import 'package:axpert/app/modules/webview/controller/webview_controller.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart';
import 'package:geolocator/geolocator.dart';
import '../../../core/common.dart';
import '../../../modules/offline_form_pages/models/models.dart';
import '../../models/client_id_result.dart';
import '../../models/signin_response.dart';
import '../connectivity/internet_connectivity.dart';
import '../log/log_service.dart';

sealed class ApiResult<T> {}

class ApiSuccess<T> extends ApiResult<T> {
  final T data;
  ApiSuccess(this.data);
}

class ApiError<T> extends ApiResult<T> {
  final String message;
  ApiError(this.message);
}

class ApiManager {
  ApiManager._();
  static final ApiManager instance = ApiManager._();

  static const _timeout = Duration(seconds: 15);
  // static const _defaultHeaders = {
  //   'Content-Type': 'application/json',
  //   'Accept': 'application/json',
  // };
  InternetConnectivity get _connectivity {
    if (Get.isRegistered<InternetConnectivity>()) {
      return Get.find<InternetConnectivity>();
    }
    return InternetConnectivity();
  }

  static var client = http.Client();
  var _baseBody = "";

  final String _baseUrl =
      "http://demo.agile-labs.com/axmclientidscripts/asbmenurest.dll/datasnap/rest/Tasbmenurest/getchoices";

  _generateBody(String ClientId) {
    return "{\"_parameters\":[{\"getchoices\":"
        "{\"axpapp\":\"${AppConst.CLOUD_PROJECT}\","
        "\"username\":\"${AppConst.DUMMY_USER}\","
        "\"password\":\"${AppConst.DUMMYUSER_PWD}\","
        "\"seed\":\"${AppConst.SEED_V}\","
        "\"trace\":\"true\","
        "\"sql\":\"${AppConst.getSQLforClientID(ClientId)}\","
        "\"direct\":\"false\","
        "\"params\":\"\"}}]}";
  }

  Map<String, String> _buildHeaders({
    required bool isBearer,
    Map<String, String>? extraHeaders,
  }) {
    final headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };

    if (isBearer) {
      final token = StorageService.token ?? "";
      headers['Authorization'] = 'Bearer $token';
    }

    if (extraHeaders != null) {
      headers.addAll(extraHeaders);
    }
    return headers;
  }

  Future<Map<String, dynamic>> _getFromServer(
    String url, {
    bool isBearer = false,
    Map<String, String>? extraHeaders,
  }) async {
    debugPrint(url);
    final headers = _buildHeaders(
      isBearer: isBearer,
      extraHeaders: extraHeaders,
    );

    final response = await http
        .get(Uri.parse(url), headers: headers)
        .timeout(_timeout);

    debugPrint(response.body);
    return _handleResponse(response);
  }

  Future<Map<String, dynamic>> _postToServer(
    String url, {
    required String body,
    bool isBearer = false,
    Map<String, String>? extraHeaders,
  }) async {
    final headers = _buildHeaders(
      isBearer: isBearer,
      extraHeaders: extraHeaders,
    );

    final response = await http
        .post(Uri.parse(url), headers: headers, body: body)
        .timeout(_timeout);

    return _handleResponse(response);
  }

  Map<String, dynamic> _handleResponse(http.Response response) {
    if (response.statusCode == 200) {
      var decoded = jsonDecode(response.body);
      if (decoded is String) {
        decoded = jsonDecode(decoded);
      }

      return decoded as Map<String, dynamic>;
    }

    if (response.statusCode == 404) {
      throw _ApiException('Invalid URL. Please check your server address.');
    }

    if (response.statusCode == 400 || response.statusCode == 401) {
      var decoded = jsonDecode(response.body);
      if (decoded is String) {
        decoded = jsonDecode(decoded);
      }

      var message =
          decoded['result']['message'] ?? 'Session expired or invalid request.';

      throw _ApiException(message);
    }

    throw _ApiException(
      'Server error (${response.statusCode}). Please try again.',
    );
  }

  // ── Typed endpoint methods ────────────────────────────────────────

  Future<ApiResult<ClientIdResult>> fetchProjectFromClientId(
    String clientId,
  ) async {
    try {
      final body = _buildClientIdRequest(clientId.trim().toLowerCase());
      final json = await _postToServer(
        ApiEndpoints.CLOUDE_URL + ApiEndpoints.URL_GET_CHOICES,
        body: body,
      );

      final resultList = json['result'] as List?;
      if (resultList == null || resultList.isEmpty) {
        return ApiError('No project found for this access code.');
      }

      final rows = resultList[0]['result']['row'] as List?;
      if (rows == null || rows.isEmpty) {
        return ApiError('No project found for this access code.');
      }

      return ApiSuccess(ClientIdResult.fromJson(json));
    } on _ApiException catch (e) {
      return ApiError(e.message);
    } on TimeoutException {
      return ApiError('Request timed out. Please try again.');
    } on http.ClientException {
      return ApiError('Network error. Please check your connection.');
    } on FormatException {
      return ApiError('Invalid response from server.');
    } catch (e) {
      return ApiError('Something went wrong: $e');
    }
  }

  Future<ApiResult<bool>> checkArmStatus(String baseUrl) async {
    baseUrl += baseUrl.endsWith("/") ? "" : "/";
    try {
      final data = await _getFromServer(
        baseUrl + ApiEndpoints.API_GET_APPSTATUS,
      );

      final dataString = data.toString().toLowerCase();

      if (dataString.isNotEmpty &&
          dataString.contains("running successfully")) {
        return ApiSuccess(true);
      } else {
        return ApiError(
          'Server reached, but application is not running successfully.',
        );
      }
    } on _ApiException catch (e) {
      return ApiError(e.message);
    } on TimeoutException {
      return ApiError('Request timed out. Please try again.');
    } on http.ClientException {
      return ApiError('Network error. Please check your connection.');
    } on FormatException {
      return ApiError('Invalid response from server.');
    } catch (e) {
      return ApiError('Something went wrong: $e');
    }
  }

  Future<ApiResult<bool>> validateConnectionName({
    required String baseUrl,
    required String appName,
  }) async {
    baseUrl += baseUrl.endsWith("/") ? "" : "/";
    final url = baseUrl + ApiEndpoints.API_GET_SIGNINDETAILS;
    final body = jsonEncode({"appname": appName});

    try {
      final data = await _postToServer(url, body: body);

      final resultObj = data["result"] as Map<String, dynamic>?;
      final message = resultObj?["message"]?.toString().toLowerCase() ?? "";
      final dataObj = resultObj?["data"] as Map<String, dynamic>?;
      final value = dataObj?["Value"];

      if (message == "success" && value is! String) {
        return ApiSuccess(true);
      } else {
        final errorMessage = value?.toString() ?? "Invalid connection name.";
        return ApiError(errorMessage);
      }
    } on _ApiException catch (e) {
      return ApiError(e.message);
    } on TimeoutException {
      return ApiError('Request timed out. Please try again.');
    } on http.ClientException {
      return ApiError('Network error. Please check your connection.');
    } on FormatException {
      return ApiError('Invalid response from server.');
    } catch (e) {
      return ApiError('Something went wrong: $e');
    }
  }

  // ── Request builder ───────────────────────────────────────────────
  String _buildClientIdRequest(String clientId) {
    return jsonEncode({
      '_parameters': [
        {
          'getchoices': {
            'axpapp': AppConst.cloudProject,
            'username': AppConst.DUMMY_USER,
            'password': AppConst.DUMMYUSER_PWD,
            'seed': AppConst.SEED_V,
            'trace': 'true',
            'sql': AppConst.sqlForClientId(clientId),
            'direct': 'false',
            'params': '',
          },
        },
      ],
    });
  }

  Future<ApiResult<AuthUserDetailsModel>> getLoginUserDetails({
    required String projectName,
    required String userName,
  }) async {
    var url = await AppConst.getFullARMUrl(
      ApiEndpoints.API_GET_LOGINUSER_DETAILS,
    );
    // baseUrl += baseUrl.endsWith("/") ? "" : "/";
    // final url =
    //     baseUrl + ApiEndpoints.API_GET_LOGINUSER_DETAILS; // Or ApiEndpoints...

    final body = jsonEncode({"appname": projectName, "UserName": userName});

    try {
      final data = await _postToServer(url, body: body);

      final resultObj = data["result"] as Map<String, dynamic>?;
      if (resultObj == null) {
        return ApiError('Invalid response format from server.');
      }

      final isSuccess =
          resultObj["success"]?.toString().toLowerCase() == "true";

      if (isSuccess) {
        // Successfully parsed the user details
        return ApiSuccess(AuthUserDetailsModel.fromJson(resultObj));
      } else {
        // Backend returned a specific error message
        final errorMessage =
            resultObj["message"]?.toString() ?? "Failed to get user details.";
        return ApiError(errorMessage);
      }
    } on _ApiException catch (e) {
      return ApiError(e.message);
    } on TimeoutException {
      return ApiError('Request timed out. Please try again.');
    } on http.ClientException {
      return ApiError('Network error. Please check your connection.');
    } on FormatException {
      return ApiError('Invalid response from server.');
    } catch (e) {
      return ApiError('Something went wrong: $e');
    }
  }

  Future<ApiResult<SignInResponse>> signIn({
    required String url,
    required Map<String, dynamic> body,
  }) async {
    try {
      final data = await _postToServer(url, body: jsonEncode(body));

      final resultObj = data["result"] as Map<String, dynamic>?;
      if (resultObj == null) {
        return ApiError('Invalid response format from server.');
      }

      return ApiSuccess(SignInResponse.fromJson(resultObj));
    } on _ApiException catch (e) {
      return ApiError(e.message);
    } on TimeoutException {
      return ApiError('Request timed out. Please try again.');
    } on http.ClientException {
      return ApiError('Network error. Please check your connection.');
    } on FormatException {
      return ApiError('Invalid response from server.');
    } catch (e) {
      return ApiError('Something went wrong: $e');
    }
  }

  Future<ApiResult<bool>> sendMobileNotificationDetails({
    required String url,
    required String sessionId,
    required String firebaseId,
    required String imei,
  }) async {
    try {
      final body = jsonEncode({
        'ARMSessionId': sessionId,
        'firebaseId': firebaseId,
        'ImeiNo': imei,
      });

      await _postToServer(url, body: body, isBearer: true);

      return ApiSuccess(true);
    } on _ApiException catch (e) {
      return ApiError(e.message);
    } on TimeoutException {
      return ApiError('Request timed out. Please try again.');
    } on http.ClientException {
      return ApiError('Network error. Please check your connection.');
    } on FormatException {
      return ApiError('Invalid response from server.');
    } catch (e) {
      return ApiError('Something went wrong: $e');
    }
  }

  Future<ApiResult<String>> changePassword({
    required String url,
    required String appName,
    required String username,
    required String oldPasswordHash,
    required String newPassword,
  }) async {
    try {
      final body = jsonEncode({
        "appname": appName,
        "username": username,
        "OldPassword": oldPasswordHash,
        "NewPassword": newPassword,
      });

      final data = await _postToServer(url, body: body, isBearer: true);

      final resultObj = data["result"] as Map<String, dynamic>?;
      if (resultObj == null) {
        return ApiError('Invalid response format from server.');
      }

      final isSuccess =
          resultObj["success"]?.toString().toLowerCase() == "true";
      final message =
          resultObj["message"]?.toString() ?? "Failed to process request.";

      if (isSuccess) {
        return ApiSuccess(message);
      } else {
        return ApiError(message);
      }
    } on _ApiException catch (e) {
      return ApiError(e.message);
    } on TimeoutException {
      return ApiError('Request timed out. Please try again.');
    } on http.ClientException {
      return ApiError('Network error. Please check your connection.');
    } on FormatException {
      return ApiError('Invalid response from server.');
    } catch (e) {
      return ApiError('Something went wrong: $e');
    }
  }

  Future<ApiResult<bool>> connectToAxpert() async {
    try {
      final url = await AppConst.getFullARMUrl(
        ApiEndpoints.API_CONNECTTOAXPERT,
      );

      final body = jsonEncode({'ARMSessionId': StorageService.sessionId ?? ''});

      final data = await _postToServer(url, body: body, isBearer: true);
      print(data);
      final resultObj = data['result'] as Map<String, dynamic>?;

      if (resultObj == null) {
        return ApiError('Invalid response format from server.');
      }

      final isSuccess =
          resultObj['success']?.toString().toLowerCase() == 'true';

      if (isSuccess) {
        debugPrint('connectToAxpert: ${data.toString()}');

        return ApiSuccess(true);
      }

      final message =
          resultObj['message']?.toString() ?? 'Failed to connect to Axpert.';

      return ApiError(message);
    } on _ApiException catch (e) {
      return ApiError(e.message);
    } on TimeoutException {
      return ApiError('Request timed out. Please try again.');
    } on http.ClientException {
      return ApiError('Network error. Please check your connection.');
    } on FormatException {
      return ApiError('Invalid response from server.');
    } catch (e) {
      return ApiError('Something went wrong: $e');
    }
  }

  Future<ApiResult<bool>> signOut() async {
    try {
      final body = jsonEncode({'ARMSessionId': StorageService.sessionId ?? ''});

      final url = await AppConst.getFullARMUrl(ApiEndpoints.API_SIGNOUT);

      await _postToServer(url, body: body, isBearer: true);

      return ApiSuccess(true);
    } on _ApiException catch (e) {
      return ApiError(e.message);
    } on TimeoutException {
      return ApiError('Request timed out. Please try again.');
    } on http.ClientException {
      return ApiError('Network error. Please check your connection.');
    } on FormatException {
      return ApiError('Invalid response from server.');
    } catch (e) {
      return ApiError('Something went wrong: $e');
    }
  }

  Future<ApiResult<Map<String, dynamic>>> requestForgotPasswordOTP({
    required String appName,
    required String username,
    required String email,
  }) async {
    try {
      final url = await AppConst.getFullARMUrl(ApiEndpoints.API_FORGOTPASSWORD);
      final body = jsonEncode({
        "appname": appName,
        "username": username,
        'email': email,
      });

      final data = await _postToServer(url, body: body);
      final resultObj = data["result"] as Map<String, dynamic>?;

      if (resultObj == null) {
        return ApiError('Invalid response format from server.');
      }

      if (resultObj["success"]?.toString().toLowerCase() == "false") {
        return ApiError(
          resultObj["message"]?.toString() ?? 'Failed to send OTP.',
        );
      }

      return ApiSuccess(resultObj);
    } on _ApiException catch (e) {
      return ApiError(e.message);
    } on TimeoutException {
      return ApiError('Request timed out. Please try again.');
    } on http.ClientException {
      return ApiError('Network error. Please check your connection.');
    } catch (e) {
      return ApiError('Something went wrong: $e');
    }
  }

  Future<ApiResult<String>> validateUserOTP({
    required String regId,
    required String otp,
  }) async {
    try {
      final url = await AppConst.getFullARMUrl(
        ApiEndpoints.API_OTP_VALIDATE_USER,
      );
      final body = jsonEncode({'regid': regId, 'otp': otp});

      final data = await _postToServer(url, body: body);
      final resultObj = data["result"] as Map<String, dynamic>?;

      if (resultObj == null) {
        return ApiError('Invalid response format from server.');
      }

      if (resultObj["success"]?.toString().toLowerCase() == "false") {
        return ApiError(resultObj["message"]?.toString() ?? 'Invalid OTP.');
      }

      return ApiSuccess(resultObj["message"]?.toString() ?? 'OTP Validated.');
    } on _ApiException catch (e) {
      return ApiError(e.message);
    } on TimeoutException {
      return ApiError('Request timed out. Please try again.');
    } on http.ClientException {
      return ApiError('Network error. Please check your connection.');
    } catch (e) {
      return ApiError('Something went wrong: $e');
    }
  }

  Future<ApiResult<String>> resetPasswordWithOTP({
    required String appName,
    required String email,
    required String regId,
    required String updatedPassword,
    required String otp,
  }) async {
    try {
      final url = await AppConst.getFullARMUrl(
        ApiEndpoints.API_VALIDATE_FORGETPASSWORD,
      );
      final body = jsonEncode({
        'appname': appName,
        'email': email,
        'regid': regId,
        'updatedPassword': updatedPassword,
        'otp': otp,
      });

      final data = await _postToServer(url, body: body);
      final resultObj = data["result"] as Map<String, dynamic>?;

      if (resultObj == null) {
        return ApiError('Invalid response format from server.');
      }

      if (resultObj["success"]?.toString().toLowerCase() == "false") {
        return ApiError(
          resultObj["message"]?.toString() ?? 'Failed to reset password.',
        );
      }

      return ApiSuccess(
        resultObj["message"]?.toString() ?? 'Password reset successfully.',
      );
    } on _ApiException catch (e) {
      return ApiError(e.message);
    } on TimeoutException {
      return ApiError('Request timed out. Please try again.');
    } on http.ClientException {
      return ApiError('Network error. Please check your connection.');
    } catch (e) {
      return ApiError('Something went wrong: $e');
    }
  }

  Future<ApiResult<List<String>>> getUserGroups({
    required String appName,
  }) async {
    try {
      final url = await AppConst.getFullARMUrl(ApiEndpoints.API_GET_USERGROUPS);
      final body = jsonEncode({"appname": appName});

      final data = await _postToServer(url, body: body);

      final resultObj = data["result"] as Map<String, dynamic>?;
      if (resultObj == null)
        return ApiError('Invalid response format from server.');

      final dataList = resultObj["data"] as List?;
      if (dataList == null) return ApiError('No user groups found.');

      List<String> groups = [];
      for (var item in dataList) {
        if (item["usergroup"] != null) {
          groups.add(item["usergroup"].toString());
        }
      }

      return ApiSuccess(groups);
    } on _ApiException catch (e) {
      return ApiError(e.message);
    } on TimeoutException {
      return ApiError('Request timed out. Please try again.');
    } on http.ClientException {
      return ApiError('Network error. Please check your connection.');
    } catch (e) {
      return ApiError('Something went wrong: $e');
    }
  }

  Future<ApiResult<Map<String, dynamic>>> validateLoginOTP({
    required String otpLoginKey,
    required String otp,
  }) async {
    try {
      final url = await AppConst.getFullARMUrl(ApiEndpoints.API_VALIDATE_OTP);
      final body = jsonEncode({"OtpLoginKey": otpLoginKey, "OTP": otp});

      final data = await _postToServer(url, body: body);
      final resultObj = data["result"] as Map<String, dynamic>?;

      if (resultObj == null) return ApiError('Invalid response format.');
      if (resultObj["success"]?.toString().toLowerCase() == "false") {
        return ApiError(resultObj["message"]?.toString() ?? 'Invalid OTP.');
      }
      return ApiSuccess(resultObj);
    } on _ApiException catch (e) {
      return ApiError(e.message);
    } catch (e) {
      return ApiError('Something went wrong: $e');
    }
  }

  Future<ApiResult<String>> resendLoginOTP({
    required String otpLoginKey,
  }) async {
    try {
      final url = await AppConst.getFullARMUrl(ApiEndpoints.API_RESEND_OTP);
      final body = jsonEncode({"OtpLoginKey": otpLoginKey});

      final data = await _postToServer(url, body: body);
      final resultObj = data["result"] as Map<String, dynamic>?;

      if (resultObj == null) return ApiError('Invalid response format.');
      if (resultObj["success"]?.toString().toLowerCase() == "false") {
        return ApiError(
          resultObj["message"]?.toString() ?? 'Failed to resend OTP.',
        );
      }
      return ApiSuccess(
        resultObj["message"]?.toString() ?? 'OTP resent successfully.',
      );
    } on _ApiException catch (e) {
      return ApiError(e.message);
    } catch (e) {
      return ApiError('Something went wrong: $e');
    }
  }

  Future<ApiResult<bool>> checkBiometricFlag({
    required String baseUrl,
    required String appName,
  }) async {
    baseUrl += baseUrl.endsWith("/") ? "" : "/";
    final url = baseUrl + ApiEndpoints.API_GET_SIGNINDETAILS;
    final body = jsonEncode({"appname": appName});

    try {
      final data = await _postToServer(url, body: body);

      final resultObj = data["result"] as Map<String, dynamic>?;
      if (resultObj == null) {
        return ApiError('Invalid response format from server.');
      }

      if (resultObj["success"]?.toString().toLowerCase() == "true") {
        final dataObj = resultObj["data"];
        if (dataObj != null) {
          final isEnabled =
              dataObj["enablefingerprint"] == true ||
              dataObj["enablefingerprint"]?.toString().toLowerCase() == "true";
          return ApiSuccess(isEnabled);
        }
      }

      return ApiSuccess(false);
    } on _ApiException catch (e) {
      return ApiError(e.message);
    } on TimeoutException {
      return ApiError('Request timed out. Please try again.');
    } on http.ClientException {
      return ApiError('Network error. Please check your connection.');
    } on FormatException {
      return ApiError('Invalid response from server.');
    } catch (e) {
      return ApiError('Something went wrong: $e');
    }
  }

  Future<ApiResult<bool>> postHybridNotificationInfoToServer({
    required String firebaseToken,
    required String guid,
    required String deviceId,
  }) async {
    try {
      var baseUrl = AppUtility.getBaseUrl(StorageService.webUrl ?? '');
      var url = baseUrl + AppConst.SET_HYBRID_NOTIFICATION_INFO;

      final body = jsonEncode({
        "notification_info": {
          "GUID": guid,
          "firebase_id": firebaseToken,
          "imei_no": deviceId,
        },
      });

      final data = await _postToServer(url, body: body);

      debugPrint("Hybrid Notification Info Result: $data");
      return ApiSuccess(true);
    } on _ApiException catch (e) {
      return ApiError(e.message);
    } on TimeoutException {
      return ApiError('Request timed out. Please try again.');
    } on http.ClientException {
      return ApiError('Network error. Please check your connection.');
    } catch (e) {
      return ApiError('Something went wrong: $e');
    }
  }

  Future<ApiResult<bool>> postHybridInfoToServer({
    required Position location,
    required String guid,
  }) async {
    try {
      // Building the URL directly inside the method
      final baseUrl = AppUtility.getBaseUrl(StorageService.webUrl ?? '');
      final finalUrl = baseUrl + AppConst.SET_HYBRID_INFO;

      // Cleanly encoding the location data
      final body = jsonEncode({
        "location_info": {
          "GUID": guid,
          "latitude": location.latitude.toString(),
          "longitude": location.longitude.toString(),
          "altitude": location.altitude.toString(),
          "accuracy": location.accuracy.toString(),
          "speed": location.speed.toString(),
          "heading": location.heading.toString(),
          "timestamp": location.timestamp.toIso8601String(),
        },
      });

      debugPrint("postHybridInfoToServer Request: $finalUrl");
      debugPrint("Payload: $body");

      final data = await _postToServer(finalUrl, body: body);

      debugPrint("Hybrid Info Result: $data");
      return ApiSuccess(true);
    } on _ApiException catch (e) {
      return ApiError(e.message);
    } on TimeoutException {
      return ApiError('Request timed out. Please try again.');
    } on http.ClientException {
      return ApiError('Network error. Please check your connection.');
    } catch (e) {
      return ApiError('Something went wrong: $e');
    }
  }

  Future<String> postDsToServer({
    required String url,
    var header = '',
    required String body,
    bool isBearer = true,
    bool strictAuth = true,
    bool show_errorSnackbar = true,
  }) async {
    final String apiName = url.substring(url.lastIndexOf("/") + 1, url.length);
    const String tag = "[POST_DS]";

    if (!await _connectivity.connectionStatus) {
      LogService.writeLog(message: "$tag NO_CONNECTIVITY api=$apiName");
      return '__NO_CONNECTIVITY__';
    }

    try {
      if (header == '') header = {"Content-Type": "application/json"};
      if (isBearer) {
        header = {
          "Content-Type": "application/json",
          'Authorization': 'Bearer ${StorageService.token ?? ""}',
        };
      }
      // LogService.writeLog(
      //   message: "$tag REQUEST api=$apiName url=$url body=$body",
      // );

      final response = await client.post(
        Uri.parse(url),
        headers: header,
        body: body,
      );
      print(
        "$tag RESPONSE api=$apiName statusCode=${response.statusCode} "
        "body=${response.body}",
      );
      // LogService.writeLog(
      //   message: "$tag RESPONSE api=$apiName statusCode=${response.statusCode} "
      //       "body=${response.body}",
      // );

      // ── 200: success, hand back the real body ──────────────────
      // amr i added the 206 here beacuse the response from axlist have a response code of 206 for partial success
      if (response.statusCode == 200 || response.statusCode == 206) {
        return response.body;
      }

      // ── 401 / 400 / 500: check for session-expiry, otherwise
      // still return the real body wrapped with an error marker
      // instead of silently discarding it ──────────────────────
      if (response.statusCode == 401 ||
          response.statusCode == 400 ||
          response.statusCode == 500) {
        bool isSessionInvalid = false;
        try {
          final decoded = jsonDecode(response.body);
          final String message = (decoded['result']?['message'] ?? '')
              .toString()
              .toLowerCase();
          isSessionInvalid = message.contains('sessionid is not valid');
        } catch (_) {
          isSessionInvalid = response.body.toString().toLowerCase().contains(
            'sessionid is not valid',
          );
        }

        if (strictAuth && isSessionInvalid) {
          LogService.writeLog(
            message:
                "$tag SESSION_INVALID api=$apiName statusCode=${response.statusCode}",
          );
          try {
            WebViewController webViewController = Get.find();
            webViewController.showSessionExpiredDialog();
          } catch (_) {}
          return '__AUTH_FAILED__${response.body}';
        }

        showErrorSnack(
          title: "Error! ${response.statusCode}",
          message: "$apiName: ${response.body}",
          show_errorSnackbar: show_errorSnackbar,
        );
        return '__ERROR_${response.statusCode}__${response.body}';
      }

      // ── 404 ──────────────────────────────────────────────────
      if (response.statusCode == 404) {
        LogService.writeLog(message: "$tag NOT_FOUND api=$apiName");
        showErrorSnack(
          title: "Error 404",
          message: "Invalid Url",
          show_errorSnackbar: show_errorSnackbar,
        );
        return strictAuth
            ? '__AUTH_FAILED__${response.body}'
            : '__ERROR_404__${response.body}';
      }

      // ── any other status code ───────────────────────────────
      var msg = response.body.toString();
      if (msg.contains("message")) {
        try {
          final jsonResp = jsonDecode(response.body);
          msg = jsonResp['result']['message'].toString();
        } catch (_) {}
      }
      showErrorSnack(
        title: "Error! ${response.statusCode}",
        message: "$apiName: $msg",
        show_errorSnackbar: show_errorSnackbar,
      );
      return '__ERROR_${response.statusCode}__${response.body}';
    } catch (e, st) {
      LogService.writeLog(message: "$tag EXCEPTION api=$apiName error=$e\n$st");
      showErrorSnack(
        title: "Error!",
        message: e.toString(),
        show_errorSnackbar: show_errorSnackbar,
      );
      return '__EXCEPTION__${e.toString()}';
    }
  }

  bool isDsErrorResponse(String response) {
    return response.isEmpty ||
        response.startsWith('__ERROR_') ||
        response.startsWith('__AUTH_FAILED__') ||
        response.startsWith('__EXCEPTION__') ||
        response.startsWith('__NO_CONNECTIVITY__');
  }

  void showErrorSnack({
    title = 'Error',
    message = 'Server busy, Please try again later.',
    show_errorSnackbar = true,
  }) {
    if (show_errorSnackbar) {
      Get.snackbar(
        title,
        message,
        snackPosition: SnackPosition.BOTTOM,
        colorText: Colors.white,
        backgroundColor: Colors.redAccent,
      );
    }
  }

  postToServer({
    String url = '',
    var header = '',
    String body = '',
    String ClientID = '',
    bool isBearer = false,
    var show_errorSnackbar = true,
  }) async {
    var API_NAME = url.substring(url.lastIndexOf("/") + 1, url.length);
    if (await _connectivity.connectionStatus)
      try {
        if (ClientID != '') _baseBody = _generateBody(ClientID.toLowerCase());
        if (url == '') url = _baseUrl;
        if (header == '') header = {"Content-Type": "application/json"};
        if (body == '') body = _baseBody;
        if (isBearer)
          header = {
            "Content-Type": "application/json",
            'Authorization': 'Bearer ${StorageService.token ?? ""}',
          };
        print("API_POST_URL: $url");
        // print("Post header: $header");
        print("API_POST_BODY:$body");
        var response = await client.post(
          Uri.parse(url),
          headers: header,
          body: body,
        );

        // print("API_RESPONSE_DATA: $API_NAME: ${response.body}\n");
        // print("");
        if (response.statusCode == 200) {
          LogService.writeLog(
            message:
                "[^] [POST] URL:$url\nAPI_NAME: $API_NAME\nBody: $body\nStatusCode: ${response.statusCode}\nResponse: ${response.body}",
          );
          return response.body;
        }
        if (response.statusCode == 404) {
          print("API_ERROR: $API_NAME: ${response.body}");
          LogService.writeLog(
            message:
                "[ERROR] API_ERROR\nURL:$url\nAPI_NAME: $API_NAME\nBody: $body\nStatusCode: ${response.statusCode}\nResponse: ${response.body}",
          );

          Get.snackbar(
            "Error ${response.statusCode}",
            "Invalid Url",
            snackPosition: SnackPosition.BOTTOM,
            backgroundColor: Colors.redAccent,
            colorText: Colors.white,
          );
          showErrorSnack(
            title: "Error!",
            message: response.statusCode.toString(),
            show_errorSnackbar: show_errorSnackbar,
          );
        } else {
          if (response.statusCode == 400 || response.statusCode == 401) {
            LogService.writeLog(
              message:
                  "[ERROR] API_ERROR\nURL:$url\nAPI_NAME: $API_NAME\nBody: $body\nStatusCode: ${response.statusCode}\nResponse: ${response.body}",
            );
            if (response.body.toString().toLowerCase().contains(
              "sessionid is not valid",
            )) {
              WebViewController webViewController = Get.find();
              webViewController.showSessionExpiredDialog();
            } else {
              return response.body;
            }
          } else {
            print("API_ERROR: $API_NAME: ${response.body}");
            LogService.writeLog(
              message:
                  "[ERROR] API_ERROR\nURL:$url\nAPI_NAME: $API_NAME\nBody: $body\nStatusCode: ${response.statusCode}\nResponse: ${response.body}",
            );

            // Get.snackbar("Error " + response.statusCode.toString(), "Internal server error",
            //     snackPosition: SnackPosition.BOTTOM, backgroundColor: Colors.redAccent, colorText: Colors.white);
            var msg = response.body.toString();
            if (response.body.toString().contains("message")) {
              try {
                var jsonResp = jsonDecode(response.body);
                // print(jsonResp);
                msg = jsonResp['result']['message'].toString();
              } catch (e) {
                print(e);
              }
            }
            showErrorSnack(
              title: "Error! ${response.statusCode.toString()}",
              message: "$API_NAME: $msg",
              show_errorSnackbar: show_errorSnackbar,
            );
          }
        }
      } catch (e) {
        print("API_ERROR: $API_NAME: ${e.toString()}");
        LogService.writeLog(
          message:
              "[ERROR] API_ERROR\nURL:$url\nAPI_NAME: $API_NAME\nBody: $body\nError: ${e.toString()}",
        );

        // Get.snackbar("Error ", e.toString(), snackPosition: SnackPosition.BOTTOM, backgroundColor: Colors.redAccent, colorText: Colors.white);
        showErrorSnack(
          title: "Error!",
          message: e.toString(),
          show_errorSnackbar: show_errorSnackbar,
        );
      }

    return "";
  }

  Future<SubmitdataApiresponsemodel> postQueueToServer({
    String url = '',
    var header = '',
    String body = '',
    String ClientID = '',
    bool isBearer = false,
    var show_errorSnackbar = true,
  }) async {
    var API_NAME = url.substring(url.lastIndexOf("/") + 1, url.length);

    if (await _connectivity.connectionStatus) {
      try {
        if (ClientID != '') _baseBody = _generateBody(ClientID.toLowerCase());
        if (url == '') url = _baseUrl;
        if (header == '') header = {"Content-Type": "application/json"};
        if (body == '') body = _baseBody;
        if (isBearer) {
          header = {
            "Content-Type": "application/json",
            'Authorization': 'Bearer ${StorageService.token}',
          };
        }

        print("API_POST_URL: $url");
        print("API_POST_BODY: $body");

        http.Response response = await client.post(
          Uri.parse(url),
          headers: header,
          body: body,
        );

        LogService.writeLog(
          message:
              "[^] [POST] URL:$url\nAPI_NAME: $API_NAME\nBody: $body\nStatusCode: ${response.statusCode}\nResponse: ${response.body}",
        );

        // Return a Map containing both pieces of data
        return SubmitdataApiresponsemodel.fromHttpResponse(response);
      } catch (e) {
        print("API_ERROR: $API_NAME: ${e.toString()}");
        LogService.writeLog(
          message:
              "[ERROR] API_ERROR\nURL:$url\nAPI_NAME: $API_NAME\nBody: $body\nError: ${e.toString()}",
        );

        showErrorSnack(
          title: "Error!",
          message: e.toString(),
          show_errorSnackbar: show_errorSnackbar,
        );

        return SubmitdataApiresponsemodel.failure(
          message: e.toString(),
          statusCode: 0,
        );
      }
    }

    return SubmitdataApiresponsemodel.failure(
      message: "No Internet Connection",
      statusCode: 500,
    );
  }
}

class _ApiException implements Exception {
  final String message;
  _ApiException(this.message);
}
