import 'dart:convert';
import 'dart:developer';

import 'package:axpert/app/data/const/app_const.dart';
import 'package:axpert/app/data/services/storage/storage_service.dart';
import 'package:http/http.dart' as http;

import '../../../data/services/log/log_service.dart';
import '../db/db.dart';

const String _tag = '[OFFLINE_CONFIG]';

const int kDefaultSyncInterval = 15;
const int kDefaultCachedBatchSize = 30;

class OfflineConfigService {
  OfflineConfigService._();
  static final String _configUrl = OfflineDBConstants.OFFLINE_CONFIG_URL();

  static Future<void> fetchAndStore() async {
    try {
      final response = await http
          .get(Uri.parse(_configUrl))
          .timeout(const Duration(seconds: 10));

      if (response.statusCode != 200 || response.body.isEmpty) {
        LogService.writeLog(
          message:
              '$_tag Fetch failed — HTTP ${response.statusCode}. Using fallback: ${kDefaultSyncInterval}min.',
        );
        _useFallback();
        return;
      }

      final Map<String, dynamic> json = jsonDecode(response.body);
      LogService.writeLog(
        message:
            '$_tag Fetch success — HTTP ${response.statusCode}. ${json.toString()}',
      );

      final int interval =
          (json[AppConst.OFFLINE_SYNC_INTERVAL] as num?)?.toInt() ??
          kDefaultSyncInterval;
      final int batchSize =
          (json[AppConst.CACHED_BATCH_SIZE] as num?)?.toInt() ??
          kDefaultCachedBatchSize;
      StorageService.setSyncInterval(interval);
      StorageService.setBatchSize(batchSize);

      log('$_tag interval=${interval}min.', name: _tag);
      log('$_tag batchSize=$batchSize nos.', name: _tag);
      return;
    } catch (e) {
      LogService.writeLog(
        message:
            '$_tag Fetch error: $e. Using fallback: ${kDefaultSyncInterval}min.',
      );
      _useFallback();
      return;
    }
  }

  static int getCachedInterval() {
    final dynamic stored = StorageService.offlineSyncInterval;
    if (stored == null) return kDefaultSyncInterval;
    return int.tryParse(stored.toString()) ?? kDefaultSyncInterval;
  }

  static int getCachedBatchSize() {
    final dynamic stored = StorageService.batchSize;

    log(stored.toString(), name: "cached_batch_size");
    if (stored == null) return kDefaultCachedBatchSize;
    return int.tryParse(stored.toString()) ?? kDefaultCachedBatchSize;
  }

  static void _useFallback() {
    final int cached = getCachedInterval();
    final int cachedBatchSize = getCachedBatchSize();
    StorageService.setSyncInterval(cached);
    StorageService.setBatchSize(cachedBatchSize);
  }
}
