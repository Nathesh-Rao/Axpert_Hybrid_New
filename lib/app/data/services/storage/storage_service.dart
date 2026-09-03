import 'dart:convert';

import 'package:axpert/app/data/models/project_model.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../db/project_database.dart';

class StorageService {
  static late SharedPreferences _prefs;
  static const _keyIsFirstTime = 'is_first_time';
  static const _keyLastSelectedProject = 'last_selected_project';
  static const _keyLastLoginData = 'last_login_data';
  static const _keyToken = 'auth_token';
  static const _userRole = 'user_role';
  static const _keySessionId = 'arm_session_id';
  static const _keyUserName = 'user_name';
  static const _keyNickName = 'nick_name';
  static const _projectName = 'project_name';
  static const _webUrl = 'web_url';
  static const _armUrl = 'arm_url';
  static const _isLogEnabled = 'isLogEnabled';
  static const _keyChangePassword = 'user_change_password';
  static const _isShowNotifyEnabled = 'is_show_notify_enabled';
  static const _keyRememberedUsers = 'remembered_users';
  static const _keyRememberedPasswords = 'remembered_passwords';
  static const _keyRememberedGroups = 'remembered_groups';
  static const _keyCanAuthenticate = 'can_authenticate';
  static const _keyWillAuthenticateForUser = 'will_authenticate_for_user';
  static const _autoSync = 'auto_sync';
  static const _autoSyncMaster = '_auto_sync_master';
  static const _batchSize = 'batch_size';
  static const _offlineSyncInterval = '_offline_sync_interval';
  static const _fcmid = 'fcm_id';
  static const _keyBackgroundNotifications = 'background_notifications';
  static const _keyNotificationList = 'notification_list';
  static const _keyNotificationUnread = 'notification_unread';
  static String? get token => _prefs.getString(_keyToken);
  static String? get sessionId => _prefs.getString(_keySessionId);
  static String? get userName => _prefs.getString(_keyUserName);
  static String? get nickName => _prefs.getString(_keyNickName);
  static String? get projectName => _prefs.getString(_projectName);
  static String? get armUrl => _prefs.getString(_armUrl);
  static String? get userRole => _prefs.getString(_userRole);
  static String? get webUrl => _prefs.getString(_webUrl);
  static String? get fcmid => _prefs.getString(_fcmid);
  static bool? get isLogEnabled => _prefs.getBool(_isLogEnabled);
  static bool? get autoSync => _prefs.getBool(_autoSync);
  static bool? get autoSyncMaster => _prefs.getBool(_autoSyncMaster);
  static bool get isFirstTime => _prefs.getBool(_keyIsFirstTime) ?? true;
  static bool get isShowNotifyEnabled =>
      _prefs.getBool(_isShowNotifyEnabled) ?? true;
  static int? get batchSize => _prefs.getInt(_batchSize);
  static int? get offlineSyncInterval => _prefs.getInt(_offlineSyncInterval);

  static Map<String, dynamic> _getMap(String key) {
    final dataString = _prefs.getString(key);
    if (dataString == null || dataString.isEmpty) return {};

    try {
      return jsonDecode(dataString) as Map<String, dynamic>;
    } catch (e) {
      _prefs.remove(key);
      return {};
    }
  }

  static Future<void> setFirstTimeDone() =>
      _prefs.setBool(_keyIsFirstTime, false);
  static Future<void> setFCMID(String id) => _prefs.setString(_fcmid, id);
  static Future<void> setisShowNotify(bool v) =>
      _prefs.setBool(_isShowNotifyEnabled, v);
  static Future<void> setAutoSync(bool v) => _prefs.setBool(_autoSync, v);
  static Future<void> setBatchSize(int v) => _prefs.setInt(_batchSize, v);
  static Future<void> setSyncInterval(int v) =>
      _prefs.setInt(_offlineSyncInterval, v);
  static Future<void> setLogEnabled(bool v) => _prefs.setBool(_isLogEnabled, v);
  static Future<void> setAutoSyncMaster(bool v) =>
      _prefs.setBool(_autoSyncMaster, v);

  static int? get lastSelectedProjectId =>
      _prefs.getInt(_keyLastSelectedProject);

  static Future<void> saveLastSelectedProject(int id) =>
      _prefs.setInt(_keyLastSelectedProject, id);

  static Future<void> clearLastSelectedProject() =>
      _prefs.remove(_keyLastSelectedProject);
  static Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  static Future<void> setString(String key, String value) async =>
      await _prefs.setString(key, value);

  static String? getString(String key) => _prefs.getString(key);

  static Future<void> setBool(String key, bool value) async =>
      await _prefs.setBool(key, value);

  static bool? getBool(String key) => _prefs.getBool(key);

  static Future<void> remove(String key) async => await _prefs.remove(key);

  static Future<void> clear() async => await _prefs.clear();

  static Future<ProjectModel?> getLastSelectedProject() async {
    final id = lastSelectedProjectId;
    if (id == null) return null;

    final result = await ProjectDatabase.instance.getById(id);
    switch (result) {
      case DbSuccess(:final data):
        return data;
      case DbError():
        return null;
    }
  }

  static Future<void> storeLastLoginData(
    String projectName,
    Map<String, dynamic> body,
  ) async {
    final existingDataString = _prefs.getString(_keyLastLoginData);
    Map<String, dynamic> allData = {};

    if (existingDataString != null && existingDataString.isNotEmpty) {
      try {
        allData = jsonDecode(existingDataString) as Map<String, dynamic>;
      } catch (e) {
        allData = {};
      }
    }

    allData[projectName] = body;
    await _prefs.setString(_keyLastLoginData, jsonEncode(allData));
  }

  static Future<void> saveUserRole(String role) async {
    await _prefs.setString(_userRole, role);
  }

  static Map<String, dynamic>? retrieveLastLoginData(String projectName) {
    final existingDataString = _prefs.getString(_keyLastLoginData);

    if (existingDataString == null || existingDataString.isEmpty) {
      return null;
    }

    try {
      final allData = jsonDecode(existingDataString) as Map<String, dynamic>;
      return allData[projectName] as Map<String, dynamic>?;
    } catch (e) {
      return null;
    }
  }

  static Future<void> saveUserSession({
    required String token,
    required String sessionId,
    required String userName,
    required String nickName,
    required String projectname,
  }) async {
    await _prefs.setString(_keyToken, token);
    await _prefs.setString(_keySessionId, sessionId);
    await _prefs.setString(_keyUserName, userName);
    await _prefs.setString(_keyNickName, nickName);
    await _prefs.setString(_projectName, projectname);
  }

  static Future<void> cacheProjectDetails({
    required String projectName,
    required String userName,
    required String webUrl,
    required String armUrl,
  }) async {
    await _prefs.setString(_keyUserName, userName);
    await _prefs.setString(_projectName, projectName);
    await _prefs.setString(_webUrl, webUrl);
    await _prefs.setString(_armUrl, armUrl);
  }

  static Future<void> rememberCredentialsForProject({
    required String projectName,
    required String username,
    required String password,
    required String group,
  }) async {
    final users = _getMap(_keyRememberedUsers);
    final passes = _getMap(_keyRememberedPasswords);
    final groups = _getMap(_keyRememberedGroups);

    users[projectName] = username;
    passes[projectName] = password;
    groups[projectName] = group;

    await _prefs.setString(_keyRememberedUsers, jsonEncode(users));
    await _prefs.setString(_keyRememberedPasswords, jsonEncode(passes));
    await _prefs.setString(_keyRememberedGroups, jsonEncode(groups));
  }

  static String? getRememberedUser(String projectName) {
    final users = _getMap(_keyRememberedUsers);
    return users[projectName] as String?;
  }

  static String? getRememberedPassword(String projectName) {
    final passes = _getMap(_keyRememberedPasswords);
    return passes[projectName] as String?;
  }

  static Future<void> forgetCredentialsForProject(String projectName) async {
    final users = _getMap(_keyRememberedUsers);
    final passes = _getMap(_keyRememberedPasswords);
    final groups = _getMap(_keyRememberedGroups);

    if (users.containsKey(projectName)) users.remove(projectName);
    if (passes.containsKey(projectName)) passes.remove(projectName);
    if (groups.containsKey(projectName)) groups.remove(projectName);

    await _prefs.setString(_keyRememberedUsers, jsonEncode(users));
    await _prefs.setString(_keyRememberedPasswords, jsonEncode(passes));
    await _prefs.setString(_keyRememberedGroups, jsonEncode(groups));
  }

  static Future<void> setCanAuthenticate(bool value) async {
    await _prefs.setBool(_keyCanAuthenticate, value);
  }

  static Future<void> setWillBiometricAuthenticateForThisUser({
    required String projectName,
    required String username,
    required bool willAuthenticate,
  }) async {
    final data = _getMap(_keyWillAuthenticateForUser);

    Map<String, dynamic> projectWise = {};
    if (data.containsKey(projectName) && data[projectName] is Map) {
      projectWise = Map<String, dynamic>.from(data[projectName]);
    }

    projectWise[username] = willAuthenticate;
    data[projectName] = projectWise;

    await _prefs.setString(_keyWillAuthenticateForUser, jsonEncode(data));
  }

  static bool? getWillBiometricAuthenticateForThisUser({
    required String projectName,
    required String username,
  }) {
    final canAuthenticate = _prefs.getBool(_keyCanAuthenticate) ?? false;
    if (!canAuthenticate) return false;

    final data = _getMap(_keyWillAuthenticateForUser);
    if (data.isEmpty) return null;

    final projectWise = data[projectName];
    if (projectWise is Map) {
      final userAuth = projectWise[username];
      if (userAuth is bool) {
        return userAuth;
      }
    }

    return null;
  }

  /// Stores a notification received while the app is in background.
  ///
  /// Each notification is stored as a JSON encoded string.
  static Future<void> addBackgroundNotification(
    Map<String, dynamic> notification,
  ) async {
    await _prefs.reload();

    final notifications =
        _prefs.getStringList(_keyBackgroundNotifications) ?? [];

    notifications.add(jsonEncode(notification));

    await _prefs.setStringList(_keyBackgroundNotifications, notifications);
  }

  /// Returns all notifications received while the app was in background.
  static List<String> getBackgroundNotifications() {
    return _prefs.getStringList(_keyBackgroundNotifications) ?? [];
  }

  /// Clears background notifications after they have been processed.
  static Future<void> clearBackgroundNotifications() async {
    await _prefs.remove(_keyBackgroundNotifications);
  }

  /// Adds a notification for a specific project and user.
  static Future<void> addNotification({
    required String projectName,
    required String userName,
    required Map<String, dynamic> notification,
  }) async {
    final oldMessages = _getMap(_keyNotificationList);

    Map<String, dynamic> projectWiseMessages = {};

    if (oldMessages[projectName] is Map) {
      projectWiseMessages = Map<String, dynamic>.from(oldMessages[projectName]);
    }

    List<dynamic> userWiseMessages = [];

    if (projectWiseMessages[userName] is List) {
      userWiseMessages = List<dynamic>.from(projectWiseMessages[userName]);
    }

    final messageList = <String>[
      jsonEncode(notification),
      ...userWiseMessages.map((e) => e.toString()),
    ];

    projectWiseMessages[userName] = messageList;
    oldMessages[projectName] = projectWiseMessages;

    await _prefs.setString(_keyNotificationList, jsonEncode(oldMessages));
  }

  /// Returns notifications for a specific project and user.
  static List<String> getNotifications({
    required String projectName,
    required String userName,
  }) {
    final oldMessages = _getMap(_keyNotificationList);

    final projectWiseMessages = oldMessages[projectName];

    if (projectWiseMessages is! Map) return [];

    final userWiseMessages = projectWiseMessages[userName];

    if (userWiseMessages is! List) return [];

    return userWiseMessages.map((e) => e.toString()).toList();
  }

  /// Gets the unread notification count for a project/user.
  static int getUnreadNotificationCount({
    required String projectName,
    required String userName,
  }) {
    final oldNotifyNum = _getMap(_keyNotificationUnread);

    final projectWiseNum = oldNotifyNum[projectName];

    if (projectWiseNum is! Map) return 0;

    final value = projectWiseNum[userName];

    if (value is int) return value;

    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  /// Increments the unread notification count for a project/user.
  static Future<int> incrementUnreadNotificationCount({
    required String projectName,
    required String userName,
  }) async {
    final oldNotifyNum = _getMap(_keyNotificationUnread);

    Map<String, dynamic> projectWiseNum = {};

    if (oldNotifyNum[projectName] is Map) {
      projectWiseNum = Map<String, dynamic>.from(oldNotifyNum[projectName]);
    }

    final currentCount =
        int.tryParse(projectWiseNum[userName]?.toString() ?? '0') ?? 0;

    final newCount = currentCount + 1;

    projectWiseNum[userName] = newCount.toString();
    oldNotifyNum[projectName] = projectWiseNum;

    await _prefs.setString(_keyNotificationUnread, jsonEncode(oldNotifyNum));

    return newCount;
  }

  /// Sets the unread notification count for a project/user.
  static Future<void> setUnreadNotificationCount({
    required String projectName,
    required String userName,
    required int count,
  }) async {
    final oldNotifyNum = _getMap(_keyNotificationUnread);

    Map<String, dynamic> projectWiseNum = {};

    if (oldNotifyNum[projectName] is Map) {
      projectWiseNum = Map<String, dynamic>.from(oldNotifyNum[projectName]);
    }

    projectWiseNum[userName] = count.toString();
    oldNotifyNum[projectName] = projectWiseNum;

    await _prefs.setString(_keyNotificationUnread, jsonEncode(oldNotifyNum));
  }
}
