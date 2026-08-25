import 'dart:convert';

import 'package:axpert/app/data/models/project_model.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../db/project_database.dart';

class StorageService {
  static late SharedPreferences _prefs;
  static const _keyIsFirstTime = 'is_first_time';
  static const _keyLastSelectedProject = 'last_selected_project';
  static const _keyLastLoginData = 'last_login_data';
  static const _keyToken = 'auth_token';
  static const _keySessionId = 'arm_session_id';
  static const _keyUserName = 'user_name';
  static const _keyNickName = 'nick_name';
  static const _keyChangePassword = 'user_change_password';
  static const _keyRememberedUsers = 'remembered_users';
  static const _keyRememberedPasswords = 'remembered_passwords';
  static const _keyRememberedGroups = 'remembered_groups';

  static String? get token => _prefs.getString(_keyToken);
  static String? get sessionId => _prefs.getString(_keySessionId);
  static String? get userName => _prefs.getString(_keyUserName);
  static String? get nickName => _prefs.getString(_keyNickName);
  static bool get isFirstTime => _prefs.getBool(_keyIsFirstTime) ?? true;

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
  }) async {
    await _prefs.setString(_keyToken, token);
    await _prefs.setString(_keySessionId, sessionId);
    await _prefs.setString(_keyUserName, userName);
    await _prefs.setString(_keyNickName, nickName);
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
}
