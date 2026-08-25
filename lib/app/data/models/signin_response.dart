class SignInResponse {
  final bool isSuccess;
  final String message;
  final String? otpLoginKey;
  final bool isDuplicateSession;
  final bool isChangePassword;
  final Map<String, dynamic>
  rawData; // Keep the raw data for processSignInDataResponse

  SignInResponse({
    required this.isSuccess,
    required this.message,
    this.otpLoginKey,
    this.isDuplicateSession = false,
    this.isChangePassword = false,
    required this.rawData,
  });

  factory SignInResponse.fromJson(Map<String, dynamic> json) {
    return SignInResponse(
      isSuccess: json["success"]?.toString().toLowerCase() == "true",
      message: json["message"]?.toString() ?? "Login failed",
      otpLoginKey: json["OTPLoginKey"]?.toString(),
      isDuplicateSession: json["duplicate_session"] == true,
      isChangePassword: json["change_password"] == true,
      rawData: json, // Save the raw json["result"] map
    );
  }
}
