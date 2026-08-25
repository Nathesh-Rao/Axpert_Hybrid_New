// ignore_for_file: constant_identifier_names

class ApiEndpoints {
  static const String URL_GET_CHOICES =
      'asbmenurest.dll/datasnap/rest/Tasbmenurest/getchoices';

  static const String CLOUDE_URL =
      'http://demo.agile-labs.com/axmclientidscripts/';

  // AXAUTH ARM Services
  static const String API_GET_SIGNINDETAILS = "AxAuth/api/v1/ARMSigninDetails";
  static const String API_SIGNIN = "AxAuth/api/v1/Signin"; //"api/v1/ARMSignIn";
  static const String API_GET_LOGINUSER_DETAILS =
      "AxAuth/api/v1/GetLoginUserDetails";
  static const String API_VALIDATE_OTP = "AxAuth/api/v1/ValidateOTP";
  static const String API_RESEND_OTP = "AxAuth/api/v1/ResendOTP";
  static const String API_CONNECTTOAXPERT = "AxAuth/api/v1/ARMConnectToAxpert";
  static const String API_FORGOTPASSWORD = "AxAuth/api/v1/AxForgotPassword";
  static const String API_CHANGE_PASSWORD = "AxAuth/api/v1/AxResetPassword";
  static const String API_SIGNOUT = "AxAuth/api/v1/ARMSignOut";

  //AxList ARM Services
  static const String API_GET_CARDS_WITH_DATA =
      "AxList/api/v1/GetCardsWithData";

  //AxUtils ARM Services
  static const String API_GET_MENU = "AxUtils/api/v1/ARMGetMenu";
  static const String API_GET_MENU_V2 = "AxUtils/api/v1/ARMGetMenu";

  // ARM_APIs ARM Services
  static const String API_GET_DATASOURCE_RESPONSE =
      "ARM_APIs/api/v1/ARMGetDataResponse";
  static const String API_GET_APPSTATUS = "ARM_APIs/api/v1/ARMAppStatus";
  static const String API_MOBILE_NOTIFICATION =
      "ARMNotificationHub/api/v1/ARMMobileNotification";
  static const String API_GET_DASHBOARD_DATA =
      "ARM_APIs/api/v1/ARMGetCardsData";
  static const String API_GET_PENDING_ACTIVETASK =
      "ARM_APIs/api/v1/ARMGetPendingActiveTasks";
  static const String API_GET_PENDING_ACTIVETASK_COUNT =
      "ARM_APIs/api/v1/ARMGetPendingActiveTasksCount";
  static const String API_GET_ACTIVETASK_DETAILS =
      "ARM_APIs/api/v1/ARMPEGGetTaskDetails";
  static const String API_GET_FILTERED_PENDING_TASK =
      "ARM_APIs/api/v1/ARMGetFilteredActiveTasks";
  static const String API_GET_COMPLETED_ACTIVETASK =
      "ARM_APIs/api/v1/ARMGetCompletedTasks";
  static const String API_GET_COMPLETED_ACTIVETASK_COUNT =
      "ARM_APIs/api/v1/ARMGetCompletedTasksCount";
  static const String API_GET_FILTERED_COMPLETED_TASK =
      "ARM_APIs/api/v1/ARMGetFilteredCompletedTasks";
  static const String API_DO_TASK_ACTIONS = "ARM_APIs/api/v1/ARMDoTaskAction";
  static const String API_GET_ALL_ACTIVE_TASKS =
      "ARM_APIs/api/v1/ARMGetAllActiveTasks";
  static const String API_GET_BULK_APPROVAL_COUNT =
      "ARM_APIs/api/v1/ARMGetBulkApprovalCount";
  static const String API_GET_BULK_ACTIVETASKS =
      "ARM_APIs/api/v1/ARMGetBulkActiveTasks";
  static const String API_POST_BULK_DO_BULK_ACTION =
      "ARM_APIs/api/v1/ARMDoBulkAction";
  static const String API_GET_SENDTOUSERS = "ARM_APIs/api/v1/ARMGetSendToUsers";
  static const String API_GET_FILE_BY_RECORDID =
      "ARM_APIs/api/v1/GetFileByRecordId";
  static const String BANNER_JSON_NAME = "mainpagebanner.json";

  static const String ARM_EXECUTE_PUBLISHED_API =
      "ARM_APIs/api/v1/ARMExecutePublishedAPI";
  static const String API_GET_ENCRYPTED_SECRET_KEY =
      "ARM_APIs/api/v1/ARMGetEncryptedSecret";
  static const String API_ARM_EXECUTE = "ARM_APIs/api/v1/ARMExecuteAPI";

  //OTHER ARM SERVICES
  static const String API_GET_USERGROUPS = "ARM_APIs/api/v1/ARMUserGroups";
  static const String API_AX_START_SESSION = "ARM_APIs/api/v1/AxStartSession";
  static const String API_ADDUSER = "ARM_APIs/api/v1/ARMAddUser";
  static const String API_OTP_VALIDATE_USER =
      "ARM_APIs/api/v1/ARMValidateAddUser";
  static const String API_VALIDATE_FORGETPASSWORD =
      "ARM_APIs/api/v1/ARMValidateForgotPassword";
  static const String API_GOOGLESIGNIN_SSO = "ARM_APIs/api/v1/ARMSigninSSO";
  static const String API_GET_HOMEPAGE_CARDS =
      "ARM_APIs/api/v1/ARMGetHomePageCards";
  static const String API_GET_HOMEPAGE_CARDS_v2 =
      "ARM_APIs/api/v2/ARMGetHomePageCards";
  static const String API_AXSCRIPT = "ARM_APIs/api/v1/AxScript";
}
