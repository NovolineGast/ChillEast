import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/network/cookie_manager.dart';
import '../../../core/utils/app_logger.dart';
import '../../../core/utils/secure_storage_helper.dart';
import '../../auth/services/http_login_service.dart';
import '../../profile/services/backup_export_service.dart';
import 'cloudisk_service.dart';

/// 开启时的首次同步结果：下拉覆盖 / 本地推上 / 失败。
enum InitialSyncOutcome { pulled, pushed, failed }

class InitialSyncResult {
  final InitialSyncOutcome outcome;
  final Map<String, dynamic>? backup;

  const InitialSyncResult(this.outcome, [this.backup]);
}

/// 本地备份 → 学习通云盘自动同步。
///
/// 文件名：`chilleast-backup-b-{stamp}.json`（读取兼容历史 a/b 槽位），
/// stamp 为 `yyyyMMdd-HHmmss`（字典序即时间序，删除失败也能肉眼定位最新）。
/// 写入时固定为槽位 b（兼容老版本/MCP识别正则，且 'b' > 'a' 消除轮换字典序错位），
/// 校验成功后删除**所有**其它同前缀旧文件（即使某次删除失败，下次同步也会收敛清理）。
class CloudBackupManager {
  static final CloudBackupManager instance = CloudBackupManager._internal();
  CloudBackupManager._internal();

  static const String filePrefix = 'chilleast-backup-';
  static const String fixedSlot = 'b';
  static const String sidecarFileName = 'chilleast-sidecar-v2.json';
  static const int defaultKeepCount = 3;
  static const String toggleKey = 'cloud_backup_auto_sync';
  static const String promptDecidedKey = 'cloud_backup_prompt_decided';
  static const String _activeSlotKey = 'cloud_backup_active_slot';
  static const String _activeResidKey = 'cloud_backup_active_resid';
  static const String _activeEncryptedIdKey =
      'cloud_backup_active_encrypted_id';
  static const Duration _debounce = Duration(seconds: 10);

  final _logger = AppLogger.instance;
  final CloudiskService _cloudisk = CloudiskService();
  Timer? _debounceTimer;
  bool _running = false;
  bool _requeued = false;
  bool _refreshingAuth = false;

  /// 文件名：slot 为 a/b（新备份固定使用 'b'）。
  static String buildFileName([String slot = fixedSlot, DateTime? time]) {
    final t = time ?? DateTime.now();
    String two(int v) => v.toString().padLeft(2, '0');
    final stamp = '${t.year}${two(t.month)}${two(t.day)}-'
        '${two(t.hour)}${two(t.minute)}${two(t.second)}';
    return '$filePrefix$slot-$stamp.json';
  }

  /// 解析备份文件名 → (slot, stamp)，不匹配返回 null。
  static ({String slot, String stamp})? parseFileName(String name) {
    final m = RegExp(
      '^${RegExp.escape(filePrefix)}([ab])-(\\d{8}-\\d{6})\\.json\$',
    ).firstMatch(name);
    if (m == null) return null;
    return (slot: m.group(1)!, stamp: m.group(2)!);
  }

  /// 目标槽位：固定为 b，兼容历史调用。
  static String pickTargetSlot([String? activeSlot]) => fixedSlot;

  /// 从目录条目中挑出最新的备份文件（按 stamp 字典序即时间序）。
  /// 忽略非备份文件；无备份返回 null。
  static Map<String, String>? pickLatestBackupEntry(
    List<Map<String, dynamic>> entries,
  ) {
    Map<String, String>? best;
    for (final e in entries) {
      final name = e['name']?.toString() ?? '';
      final parsed = parseFileName(name);
      if (parsed == null) continue;
      final resid = e['id']?.toString() ?? '';
      final encryptedId = e['encryptedId']?.toString() ?? '';
      if (resid.isEmpty || encryptedId.isEmpty) continue;
      if (best == null || parsed.stamp.compareTo(best['stamp']!) > 0) {
        best = {
          'resid': resid,
          'encryptedId': encryptedId,
          'puid': e['puid']?.toString() ?? '',
          'name': name,
          'slot': parsed.slot,
          'stamp': parsed.stamp,
        };
      }
    }
    return best;
  }

  /// 从目录条目中挑出 sidecar 伴随文件
  static Map<String, String>? pickSidecarEntry(
    List<Map<String, dynamic>> entries,
  ) {
    for (final e in entries) {
      final name = e['name']?.toString() ?? '';
      if (name == sidecarFileName) {
        final resid = e['id']?.toString() ?? '';
        final encryptedId = e['encryptedId']?.toString() ?? '';
        if (resid.isNotEmpty && encryptedId.isNotEmpty) {
          return {
            'resid': resid,
            'encryptedId': encryptedId,
            'puid': e['puid']?.toString() ?? '',
            'name': name,
          };
        }
      }
    }
    return null;
  }

  /// 从目录条目中挑出需删除的 resid（同前缀且排除最新的 keepCount 份备份）。
  /// 严格保留包含本次上传 [keepResid] 在内的最新 [keepCount] 份（默认 3 份），
  /// 更早的陈旧快照加入待删除列表。
  static List<Map<String, String>> pickStaleEntries(
    List<Map<String, dynamic>> entries,
    String keepResid, {
    int keepCount = defaultKeepCount,
  }) {
    final valid = <({String resid, String encryptedId, String puid, String stamp})>[];
    for (final e in entries) {
      final name = e['name']?.toString() ?? '';
      final parsed = parseFileName(name);
      if (parsed == null) continue;
      final resid = e['id']?.toString() ?? '';
      final encryptedId = e['encryptedId']?.toString() ?? '';
      if (resid.isEmpty || encryptedId.isEmpty) continue;
      valid.add((
        resid: resid,
        encryptedId: encryptedId,
        puid: e['puid']?.toString() ?? '',
        stamp: parsed.stamp,
      ));
    }

    // 依时间戳倒序排列（最新的在最前）
    valid.sort((a, b) => b.stamp.compareTo(a.stamp));

    final keptResids = <String>{};
    if (keepResid.isNotEmpty && valid.any((v) => v.resid == keepResid)) {
      keptResids.add(keepResid);
    }

    for (final item in valid) {
      if (keptResids.length >= keepCount) break;
      keptResids.add(item.resid);
    }

    final stale = <Map<String, String>>[];
    for (final item in valid) {
      if (!keptResids.contains(item.resid) && item.resid != keepResid) {
        stale.add({
          'resid': item.resid,
          'encryptedId': item.encryptedId,
          'puid': item.puid,
        });
      }
    }
    return stale;
  }

  /// 提取新版本特有的数据构建 sidecar 伴随文件数据结构
  static Map<String, dynamic> buildSidecarData(
      Map<String, dynamic> backupData) {
    final settings = backupData['settings'] is Map
        ? Map<String, dynamic>.from(backupData['settings'] as Map)
        : <String, dynamic>{};
    final appearance = settings['appearance'] is Map
        ? Map<String, dynamic>.from(settings['appearance'] as Map)
        : <String, dynamic>{};
    final localData = backupData['localData'] is Map
        ? Map<String, dynamic>.from(backupData['localData'] as Map)
        : <String, dynamic>{};

    final colors = settings['customCourseColors'];
    final subscription = settings['timetableSubscription'];
    final room2 = settings['electricityRoom2'];
    final feedAutoSort = appearance['feedAutoSort'];
    final exams = localData['examList'] ?? localData['manualExamList'];
    final memories = localData['aiMemories'];

    return {
      'format': 'chilleast-sidecar',
      'version': 2,
      'updatedAt': DateTime.now().toIso8601String(),
      'settings': {
        if (colors != null) 'customCourseColors': colors,
        if (subscription != null) 'timetableSubscription': subscription,
        if (room2 != null) 'electricityRoom2': room2,
        'appearance': {
          if (feedAutoSort != null) 'feedAutoSort': feedAutoSort,
        },
      },
      'localData': {
        if (exams != null) 'examList': exams,
        if (memories != null) 'aiMemories': memories,
      },
      // 顶层平铺别名兼容
      if (colors != null) 'customCourseColors': colors,
      if (subscription != null) 'timetableSubscription': subscription,
      if (room2 != null) 'electricityRoom2': room2,
      if (feedAutoSort != null) 'feedAutoSort': feedAutoSort,
      if (exams != null) 'examList': exams,
      if (memories != null) 'aiMemories': memories,
    };
  }

  /// 将云端 sidecar 中的新版本字段合并到主备份快照中（防老版本覆盖丢失新字段）
  static Map<String, dynamic> mergeSidecar(
    Map<String, dynamic> backup,
    Map<String, dynamic> sidecar,
  ) {
    final mergedBackup = Map<String, dynamic>.from(backup);
    final settings = mergedBackup['settings'] is Map
        ? Map<String, dynamic>.from(mergedBackup['settings'] as Map)
        : <String, dynamic>{};
    final localData = mergedBackup['localData'] is Map
        ? Map<String, dynamic>.from(mergedBackup['localData'] as Map)
        : <String, dynamic>{};

    final sidecarSettings = sidecar['settings'] is Map
        ? Map<String, dynamic>.from(sidecar['settings'] as Map)
        : <String, dynamic>{};
    final sidecarAppearance = sidecarSettings['appearance'] is Map
        ? Map<String, dynamic>.from(sidecarSettings['appearance'] as Map)
        : (sidecar['appearance'] is Map
            ? Map<String, dynamic>.from(sidecar['appearance'] as Map)
            : <String, dynamic>{});
    final sidecarLocalData = sidecar['localData'] is Map
        ? Map<String, dynamic>.from(sidecar['localData'] as Map)
        : <String, dynamic>{};

    // 1. customCourseColors: 若主快照缺失或为 null，从 sidecar 补齐
    if (!settings.containsKey('customCourseColors') ||
        settings['customCourseColors'] == null) {
      final val = sidecarSettings['customCourseColors'] ??
          sidecar['customCourseColors'];
      if (val != null) {
        settings['customCourseColors'] = val;
      }
    }

    // 2. timetableSubscription: 若主快照缺失或为 null，从 sidecar 补齐
    if (!settings.containsKey('timetableSubscription') ||
        settings['timetableSubscription'] == null) {
      final val = sidecarSettings['timetableSubscription'] ??
          sidecar['timetableSubscription'];
      if (val != null) {
        settings['timetableSubscription'] = val;
      }
    }

    // 3. electricityRoom2: 若主快照缺失或为 null，从 sidecar 补齐
    if (!settings.containsKey('electricityRoom2') ||
        settings['electricityRoom2'] == null) {
      final val = sidecarSettings['electricityRoom2'] ??
          sidecar['electricityRoom2'];
      if (val != null) {
        settings['electricityRoom2'] = val;
      }
    }

    // 4. appearance.feedAutoSort: 若主快照缺失或为 null，从 sidecar 补齐
    final appearance = settings['appearance'] is Map
        ? Map<String, dynamic>.from(settings['appearance'] as Map)
        : <String, dynamic>{};
    if (!appearance.containsKey('feedAutoSort') ||
        appearance['feedAutoSort'] == null) {
      final val = sidecarAppearance['feedAutoSort'] ??
          sidecar['feedAutoSort'];
      if (val != null) {
        appearance['feedAutoSort'] = val;
        settings['appearance'] = appearance;
      }
    }

    // 5. examList: 若主快照缺失或为 null，从 sidecar 补齐
    if ((!localData.containsKey('examList') &&
            !localData.containsKey('manualExamList')) ||
        (localData['examList'] == null &&
            localData['manualExamList'] == null)) {
      final val = sidecarLocalData['examList'] ??
          sidecar['examList'] ??
          sidecarLocalData['manualExamList'] ??
          sidecar['manualExamList'];
      if (val != null) {
        localData['examList'] = val;
      }
    }

    // 6. aiMemories: 若主快照缺失或为 null，从 sidecar 补齐
    if (!localData.containsKey('aiMemories') ||
        localData['aiMemories'] == null) {
      final val =
          sidecarLocalData['aiMemories'] ?? sidecar['aiMemories'];
      if (val != null) {
        localData['aiMemories'] = val;
      }
    }

    mergedBackup['settings'] = settings;
    mergedBackup['localData'] = localData;
    return mergedBackup;
  }

  static const String _dirtyStorageKey = 'cloud_backup_is_dirty';
  int _sessionGeneration = 0;

  /// 本地数据有更改时调用（各存储落盘点）。去抖 10s 后同步一次。
  void markDirty() {
    _debounceTimer?.cancel();
    SharedPreferences.getInstance().then((p) {
      p.setBool(_dirtyStorageKey, true);
    }).catchError((_) {});
    _debounceTimer = Timer(_debounce, () => syncNow());
  }

  /// 立即同步一次（开关关闭时直接返回，除非 force）。
  Future<bool> syncNow({bool force = false}) async {
    if (_running) {
      _requeued = true;
      return false;
    }
    _running = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      if (!force && (prefs.getBool(toggleKey) ?? false) == false) return false;
      // 未登录（无保存凭证）则不同步，静默跳过
      if (!await SecureStorageHelper().hasCredentials()) return false;

      try {
        return await _doSync(prefs);
      } on CloudiskAuthException {
        // 超星会话过期：portal/index 的 Chaoxing Cookie 已失效。
        // HttpLoginService.login 本就是 portal/login→login6→index 全链路，
        // 重登一次即可重新签发 .chaoxing.com 10 件套，无需额外“绑定”请求。
        _cloudisk.invalidateSession();
        if (await _refreshChaoxingSession()) {
          _cloudisk.invalidateSession();
          try {
            return await _doSync(prefs);
          } on CloudiskAuthException {
            _cloudisk.invalidateSession();
            return false;
          }
        }
        return false;
      }
    } catch (e) {
      _logger.w('☁️ Cloud backup sync failed: $e');
      return false;
    } finally {
      _running = false;
      if (_requeued) {
        _requeued = false;
        markDirty();
      }
    }
  }

  /// 退出登录时重置：取消待同步任务并清除云端备份定位
  ///（槽位/resid/开关），避免下个账号复用上个账号的云盘位置。
  /// 下次登录后开关保持默认关闭，由用户手动开启。
  Future<void> resetOnLogout() async {
    _sessionGeneration++;
    _debounceTimer?.cancel();
    _debounceTimer = null;
    _running = false;
    _requeued = false;
    _cloudisk.invalidateSession();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(toggleKey);
      await prefs.remove(promptDecidedKey);
      await prefs.remove(_activeSlotKey);
      await prefs.remove(_activeResidKey);
      await prefs.remove(_activeEncryptedIdKey);
      await prefs.remove(_dirtyStorageKey);
    } catch (e) {
      _logger.w('☁️ Cloud backup logout reset failed: $e');
    }
  }

  /// 超星会话过期时用保存的凭证静默重登，把新 Cookie 发布到共享 Jar。
  /// 同一时间只跑一份，避免和前台登录打架。
  Future<bool> _refreshChaoxingSession() async {
    if (_refreshingAuth) return false;
    _refreshingAuth = true;
    final currentGen = _sessionGeneration;
    try {
      final snapshot = await SecureStorageHelper().readAuthSnapshot();
      final u = snapshot.username;
      final p = snapshot.password;
      if (u == null || u.isEmpty || p == null || p.isEmpty) return false;
      _logger.i('☁️ Chaoxing session expired, silent re-login…');
      final result = await HttpLoginService().login(u, p);

      // 校验世代与用户，若登出或换号则丢弃旧 Cookie，避免覆盖新会话
      final latestSnapshot = await SecureStorageHelper().readAuthSnapshot();
      if (_sessionGeneration != currentGen || latestSnapshot.username != u) {
        _logger.w('☁️ Silent re-login aborted: session generation mismatch or logged out');
        return false;
      }

      await AppCookieManager().saveHttpLoginCookies(result.cookies);
      _logger.i('☁️ Silent re-login ok, cookies refreshed');
      return true;
    } catch (e) {
      _logger.w('☁️ Silent re-login failed: $e');
      return false;
    } finally {
      _refreshingAuth = false;
    }
  }

  /// 应用启动并在静默登录后拉取云端最新备份。
  /// 若本地有未同步的离线修改（dirty），进行合并并把最新数据推上云端；
  /// 若本地无离线修改，则拉取云端最新备份写回本地。
  Future<Map<String, dynamic>?> pullLatestOnStartup() async {
    if (_running) {
      return null;
    }
    _running = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      if ((prefs.getBool(toggleKey) ?? false) == false) return null;
      if (!await SecureStorageHelper().hasCredentials()) return null;

      final isDirty = prefs.getBool(_dirtyStorageKey) ?? false;

      try {
        final pulled = await _pullAndApply(prefs);
        if (isDirty) {
          // 本地存在离线修改：合并后将最新数据推至云端并清除 dirty 标记
          _logger.i('☁️ Local offline edits detected, merging and syncing to cloud...');
          await _doSync(prefs);
        }
        return pulled;
      } on CloudiskAuthException {
        _cloudisk.invalidateSession();
        if (await _refreshChaoxingSession()) {
          _cloudisk.invalidateSession();
          try {
            final pulled = await _pullAndApply(prefs);
            if (isDirty) {
              await _doSync(prefs);
            }
            return pulled;
          } on CloudiskAuthException {
            _cloudisk.invalidateSession();
            return null;
          }
        }
        return null;
      }
    } catch (e) {
      _logger.w('☁️ Cloud backup startup pull failed: $e');
      return null;
    } finally {
      _running = false;
      if (_requeued) {
        _requeued = false;
        markDirty();
      }
    }
  }

  /// 开启开关时的首次同步：云上有备份就拉最新覆盖本地，
  /// 云上没有才把本地推上去。调用方在 pulled 时需刷新各 Provider。
  Future<InitialSyncResult> initialSync() async {
    if (_running) {
      _requeued = true;
      return const InitialSyncResult(InitialSyncOutcome.failed);
    }
    _running = true;
    try {
      if (!await SecureStorageHelper().hasCredentials()) {
        return const InitialSyncResult(InitialSyncOutcome.failed);
      }
      final prefs = await SharedPreferences.getInstance();
      try {
        return await _pullOrPush(prefs);
      } on CloudiskAuthException {
        _cloudisk.invalidateSession();
        if (await _refreshChaoxingSession()) {
          _cloudisk.invalidateSession();
          try {
            return await _pullOrPush(prefs);
          } on CloudiskAuthException {
            _cloudisk.invalidateSession();
            return const InitialSyncResult(InitialSyncOutcome.failed);
          }
        }
        return const InitialSyncResult(InitialSyncOutcome.failed);
      }
    } catch (e) {
      _logger.w('☁️ Cloud backup initial sync failed: $e');
      return const InitialSyncResult(InitialSyncOutcome.failed);
    } finally {
      _running = false;
      if (_requeued) {
        _requeued = false;
        markDirty();
      }
    }
  }

  /// 先找云端最新备份：有则下载覆盖本地，无则本地推上。
  Future<InitialSyncResult> _pullOrPush(SharedPreferences prefs) async {
    final pulled = await _pullAndApply(prefs);
    if (pulled != null) {
      return InitialSyncResult(InitialSyncOutcome.pulled, pulled);
    }
    final ok = await _doSync(prefs);
    return InitialSyncResult(
        ok ? InitialSyncOutcome.pushed : InitialSyncOutcome.failed);
  }

  /// 下载云端最新备份并写回本地。若云端无备份返回 null。
  Future<Map<String, dynamic>?> _pullAndApply(SharedPreferences prefs) async {
    final currentGen = _sessionGeneration;
    final session = await _cloudisk.ensureSession();
    final scan = await _findLatestBackupAndSidecar(session);
    final latest = scan.latestBackup;
    if (latest == null) return null;

    final bytes = await _cloudisk.downloadBytes(
      resid: latest['resid']!,
      encryptedId: latest['encryptedId']!,
      puid: latest['puid']!.isNotEmpty ? latest['puid']! : session.puid,
      folderId: session.rootDirId,
    );
    // 先校验再写回：坏文件不碰本地
    var backup =
        BackupExportService.parseBackupJson(utf8.decode(bytes));
    if (_sessionGeneration != currentGen) {
      _logger.w('☁️ Pull backup aborted: session generation changed');
      return null;
    }

    // 若云端存在 sidecar 伴随文件，拉取并合并补齐老版本可能缺失的新字段
    final sidecarEntry = scan.sidecarEntry;
    if (sidecarEntry != null) {
      try {
        final sidecarBytes = await _cloudisk.downloadBytes(
          resid: sidecarEntry['resid']!,
          encryptedId: sidecarEntry['encryptedId']!,
          puid: sidecarEntry['puid']!.isNotEmpty
              ? sidecarEntry['puid']!
              : session.puid,
          folderId: session.rootDirId,
        );
        final sidecarJson = jsonDecode(utf8.decode(sidecarBytes));
        if (sidecarJson is Map<String, dynamic>) {
          backup = mergeSidecar(backup, sidecarJson);
          _logger.i('☁️ Merged sidecar companion into backup snapshot');
        }
      } catch (e) {
        _logger.w('☁️ Pull sidecar failed: $e');
      }
    }

    if (_sessionGeneration != currentGen) {
      return null;
    }

    await BackupExportService.applyBackupData(backup);
    if (_sessionGeneration != currentGen) {
      return null;
    }
    await prefs.setString(_activeSlotKey, latest['slot']!);
    await prefs.setString(_activeResidKey, latest['resid']!);
    await prefs.setString(_activeEncryptedIdKey, latest['encryptedId']!);
    _logger.i('☁️ Cloud backup pulled: ${latest['name']}');
    return backup;
  }

  /// 翻页找云端最新的备份文件和 sidecar 伴随文件（最多 5 页）。
  Future<({Map<String, String>? latestBackup, Map<String, String>? sidecarEntry})>
      _findLatestBackupAndSidecar(
    CloudiskSession session,
  ) async {
    Map<String, String>? best;
    Map<String, String>? sidecar;
    var page = 1;
    const size = 60;
    for (var i = 0; i < 5; i++) {
      final result =
          await _cloudisk.listRes(parentId: session.rootDirId, page: page);
      final candidate = pickLatestBackupEntry(result.entries);
      if (candidate != null &&
          (best == null ||
              candidate['stamp']!.compareTo(best['stamp']!) > 0)) {
        best = candidate;
      }
      sidecar ??= pickSidecarEntry(result.entries);
      if (result.entries.length >= result.totalCount ||
          result.entries.length < size) {
        break;
      }
      page++;
    }
    return (latestBackup: best, sidecarEntry: sidecar);
  }

  Future<bool> _doSync(SharedPreferences prefs) async {
    final currentGen = _sessionGeneration;
    final data = await BackupExportService.buildBackupData();
    final bytes = utf8.encode(const JsonEncoder().convert(data));

    // 上传前完整性回环反序列化预检，确保包含 format: 'chilleast-backup' 且结构合法
    try {
      final decoded = jsonDecode(utf8.decode(bytes));
      if (decoded is! Map<String, dynamic> ||
          decoded['format'] != BackupExportService.backupFormat) {
        throw const FormatException('备份完整性校验失败：缺少合法 format 标识');
      }
    } catch (e) {
      _logger.e('☁️ Cloud backup pre-upload integrity check failed: $e');
      return false;
    }

    final session = await _cloudisk.ensureSession();
    final filename = buildFileName(fixedSlot, DateTime.now());

    final uploaded = await _cloudisk.uploadJson(
      folderId: session.rootDirId,
      filename: filename,
      bytes: bytes,
    );
    final resid = uploaded['resid'].toString();

    if (_sessionGeneration != currentGen) {
      _logger.w('☁️ Sync backup aborted: session generation changed');
      return false;
    }

    // 上传 sidecar 伴随文件（与老版本 main 1.0.12 双向兼容）
    String? sidecarResid;
    try {
      final sidecarData = buildSidecarData(data);
      final sidecarBytes =
          utf8.encode(const JsonEncoder().convert(sidecarData));
      final sidecarUploaded = await _cloudisk.uploadJson(
        folderId: session.rootDirId,
        filename: sidecarFileName,
        bytes: sidecarBytes,
      );
      sidecarResid = sidecarUploaded['resid']?.toString();
    } catch (e) {
      _logger.w('☁️ Sidecar sync failed: $e');
    }

    if (_sessionGeneration != currentGen) {
      return false;
    }

    // 收敛清理：滚动保留包含本次上传在内的最新 3 份快照，并清理旧 sidecar
    await _pruneOthers(session,
        keepResid: resid, keepSidecarResid: sidecarResid);

    if (_sessionGeneration != currentGen) {
      return false;
    }

    await prefs.setString(_activeSlotKey, fixedSlot);
    await prefs.setString(_activeResidKey, resid);
    await prefs.setString(_activeEncryptedIdKey,
        uploaded['encryptedId']?.toString() ?? '');
    await prefs.remove(_dirtyStorageKey);
    _logger.i('☁️ Cloud backup synced: $filename');
    return true;
  }

  Future<void> _pruneOthers(
    CloudiskSession session, {
    required String keepResid,
    String? keepSidecarResid,
    int keepCount = defaultKeepCount,
  }) async {
    final allEntries = <Map<String, dynamic>>[];
    var page = 1;
    const size = 60;
    // 最多翻 5 页，防异常大目录
    for (var i = 0; i < 5; i++) {
      final result =
          await _cloudisk.listRes(parentId: session.rootDirId, page: page);
      allEntries.addAll(result.entries);
      if (result.entries.length >= result.totalCount ||
          result.entries.length < size) {
        break;
      }
      page++;
    }

    final stale = pickStaleEntries(allEntries, keepResid, keepCount: keepCount);
    for (final s in stale) {
      if (s['encryptedId']!.isEmpty) continue;
      try {
        await _cloudisk.deleteRes(
          resid: s['resid']!,
          encryptedId: s['encryptedId']!,
          puid: s['puid']!.isNotEmpty ? s['puid']! : session.puid,
        );
      } catch (e) {
        // 单个删除失败不影响整体，下次同步继续收敛
        _logger.w('☁️ Prune backup ${s['resid']} failed: $e');
      }
    }

    // 清理旧的 sidecar 伴随文件
    if (keepSidecarResid != null) {
      for (final e in allEntries) {
        final name = e['name']?.toString() ?? '';
        if (name == sidecarFileName) {
          final resid = e['id']?.toString() ?? '';
          final encryptedId = e['encryptedId']?.toString() ?? '';
          if (resid.isNotEmpty &&
              encryptedId.isNotEmpty &&
              resid != keepSidecarResid) {
            try {
              await _cloudisk.deleteRes(
                resid: resid,
                encryptedId: encryptedId,
                puid: e['puid']?.toString() ?? session.puid,
              );
            } catch (e) {
              _logger.w('☁️ Prune old sidecar $resid failed: $e');
            }
          }
        }
      }
    }
  }
}
