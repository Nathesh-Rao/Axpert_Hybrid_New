import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../models/project_model.dart';
import '../../db/project_database.dart';

/// Downloads and persists the latest project logo for offline display.
class ProjectLogoCache {
  ProjectLogoCache._();
  static final Map<String, Future<Uint8List?>> _downloads = {};

  static Future<Uint8List?> download(String url) {
    final value = url.trim();
    if (value.isEmpty) return Future.value(null);
    return _downloads.putIfAbsent(value, () async {
      try {
        final response = await http
            .get(Uri.parse(value))
            .timeout(const Duration(seconds: 8));
        final contentType = (response.headers['content-type'] ?? '')
            .toLowerCase();
        if (response.statusCode != 200 ||
            (contentType.isNotEmpty && !contentType.startsWith('image/')) ||
            response.bodyBytes.isEmpty) {
          return null;
        }
        return Uint8List.fromList(response.bodyBytes);
      } catch (_) {
        return null;
      } finally {
        _downloads.remove(value);
      }
    });
  }

  static Future<ProjectModel> refresh(ProjectModel project) async {
    final bytes = await download(project.logourl);
    if (bytes == null || project.id == null) return project;
    final updated = project.copyWith(logoData: bytes);
    final result = await ProjectDatabase.instance.update(updated);
    return switch (result) {
      DbSuccess(:final data) => data,
      DbError() => project,
    };
  }
}
