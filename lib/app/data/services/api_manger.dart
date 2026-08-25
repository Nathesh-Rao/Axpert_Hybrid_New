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

import 'dart:async';
import 'dart:convert';
import 'package:axpert/app/data/const/app_const.dart';
import 'package:axpert/app/data/models/auth_user_details_model.dart';
import 'package:axpert/app/data/services/api_endpoints.dart';
import 'package:axpert/app/data/services/storage_service.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart';

import '../models/client_id_result.dart';
import '../models/signin_response.dart';

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
      throw _ApiException('Session expired or invalid request.');
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
            'username': AppConst.dummyUser,
            'password': AppConst.dummyPwd,
            'seed': AppConst.seedV,
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
    required String baseUrl, // Pass the ARM URL here
    required String projectName,
    required String userName,
  }) async {
    baseUrl += baseUrl.endsWith("/") ? "" : "/";
    final url =
        baseUrl +
        ApiEndpoints.API_GET_LOGINUSER_DETAILS; // Or ApiEndpoints...

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
}

class _ApiException implements Exception {
  final String message;
  _ApiException(this.message);
}
