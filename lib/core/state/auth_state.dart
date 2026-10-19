import 'dart:async';
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/widgets.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../features/auth/providers/auth_provider.dart';
import '../../features/profile/providers/settings_provider.dart';
import '../../features/cloudisk/screens/cloud_sync_prompt_screen.dart';
import '../../features/cloudisk/services/cloud_backup_manager.dart';
import '../../features/profile/services/backup_provider_refresh.dart';
import '../../features/library/services/library_storage.dart';
import '../../features/workspace/services/electricity_service.dart';
import '../utils/secure_storage_helper.dart';
import '../network/cookie_manager.dart';
import '../services/webview_cache_service.dart';
import '../../features/homework/providers/homework_provider.dart';
import '../../features/notice/providers/notice_provider.dart';
import '../../features/timetable/services/timetable_storage.dart';
import '../../features/timetable/services/timetable_service.dart';
import '../../features/workspace/services/campus_card_service.dart';
import '../../features/workspace/providers/campus_card_cache_provider.dart';
import '../../features/workspace/providers/electricity_cache_provider.dart';
import '../../features/library/providers/library_provider.dart';
import '../../features/questionnaire/providers/questionnaire_cache_provider.dart';
import '../../features/leave/providers/leave_cache_provider.dart';
import '../../features/repairs/providers/repair_cache_provider.dart';
import '../../features/exam/providers/exam_provider.dart';
import '../../features/exam/services/exam_storage.dart';
import '../../features/timetable/services/timetable_subscription_service.dart';
import '../../features/timetable/providers/timetable_status_provider.dart';
import '../ai/services/ai_memory_storage.dart';
import '../services/ydjwxt_auth_service.dart';
import '../services/home_widget_service.dart';
import '../constants/app_constants.dart';
import 'package:logger/logger.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';

/// 认证状态枚举
enum AuthStatus {
  unauthenticated, // 未登录
  authenticating, // 正在登录
  authenticated, // 已登录
}

/// 认证状态模型
class AuthState {
  final AuthStatus status;
  final String? errorMessage;
  final String? username;
  final String? realName;
  final String? uid;
  final String? avatarUrl;
  final bool isGuestMode;
  final bool isInitialized;

  const AuthState({
    required this.status,
    this.errorMessage,
    this.username,
    this.realName,
    this.uid,
    this.avatarUrl,
    this.isGuestMode = false,
    this.isInitialized = false,
  });

  /// 初始状态 - 未登录
  const AuthState.initial()
      : this(
            status: AuthStatus.unauthenticated,
            isGuestMode: false,
            isInitialized: true);

  /// 正在登录状态
  const AuthState.authenticating()
      : this(
            status: AuthStatus.authenticating,
            isGuestMode: false,
            isInitialized: false);

  /// 已登录状态
  const AuthState.authenticated({
    String? username,
    String? realName,
    String? uid,
    String? avatarUrl,
  }) : this(
          status: AuthStatus.authenticated,
          username: username,
          realName: realName,
          uid: uid,
          avatarUrl: avatarUrl,
        );

  /// 登录失败状态
  const AuthState.error(String message)
      : this(status: AuthStatus.unauthenticated, errorMessage: message);

  static const _sentinel = Object();

  /// 复制并修改状态
  AuthState copyWith({
    AuthStatus? status,
    Object? errorMessage = _sentinel,
    String? username,
    String? realName,
    String? uid,
    String? avatarUrl,
    bool? isGuestMode,
    bool? isInitialized,
  }) {
    return AuthState(
      status: status ?? this.status,
      errorMessage: identical(errorMessage, _sentinel)
          ? this.errorMessage
          : (errorMessage as String?),
      username: username ?? this.username,
      realName: realName ?? this.realName,
      uid: uid ?? this.uid,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      isGuestMode: isGuestMode ?? this.isGuestMode,
      isInitialized: isInitialized ?? this.isInitialized,
    );
  }

  @override
  String toString() =>
      'AuthState(status: $status, errorMessage: $errorMessage, username: $username, realName: $realName, uid: $uid, avatarUrl: $avatarUrl, isGuestMode: $isGuestMode, isInitialized: $isInitialized)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AuthState &&
          runtimeType == other.runtimeType &&
          status == other.status &&
          errorMessage == other.errorMessage &&
          username == other.username &&
          realName == other.realName &&
          uid == other.uid &&
          avatarUrl == other.avatarUrl &&
          isGuestMode == other.isGuestMode &&
          isInitialized == other.isInitialized;

  @override
  int get hashCode =>
      status.hashCode ^
      errorMessage.hashCode ^
      username.hashCode ^
      realName.hashCode ^
      uid.hashCode ^
      avatarUrl.hashCode ^
      isGuestMode.hashCode ^
      isInitialized.hashCode;

  /// 是否有本地保存的账号信息
  bool get hasAccount => username != null && username!.isNotEmpty;
}

/// AuthState Provider
final authStateProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier(ref);
});

/// AuthNotifier - 管理认证状态
class AuthNotifier extends StateNotifier<AuthState> {
  final Ref _ref;
  final _logger = Logger();

  Timer? _splashTimeoutTimer;

  AuthNotifier(this._ref) : super(const AuthState.authenticating()) {
    // 5 秒超时保底，防止极端异常或底层平台通道死锁导致闪屏卡住
    _splashTimeoutTimer = Timer(const Duration(seconds: 5), () {
      FlutterNativeSplash.remove();
    });

    // 创建 Provider 时立即触发检查，确保异常时也能移除闪屏图
    Future.microtask(() async {
      try {
        await checkAuthStatus();
      } catch (e, stack) {
        _logger.e('💥 Unhandled error in checkAuthStatus: $e\n$stack');
        if (mounted) {
          state = const AuthState.initial().copyWith(isInitialized: true);
        }
      } finally {
        _splashTimeoutTimer?.cancel();
        _splashTimeoutTimer = null;
        FlutterNativeSplash.remove();
      }
    });
  }

  @override
  void dispose() {
    _splashTimeoutTimer?.cancel();
    _splashTimeoutTimer = null;
    super.dispose();
  }

  Future<void> checkAuthStatus() async {
    _logger.i('🔍 Initializing auth status...');

    try {
      // 登录服务负责每次登录前清理 Cookie，这里不再重复清理。
      // 没有保存凭据时仍单独清理，避免游客态残留旧会话。
      // 一次读取凭据和缓存资料，减少开屏阶段的安全存储调用。
      final snapshot = await SecureStorageHelper().readAuthSnapshot();
      final hasCreds = snapshot.hasCredentials;
      final profile = snapshot.profile;
      final username = snapshot.username;

      if (!hasCreds) {
        try {
          await AppCookieManager().clearSsoCookies();
        } catch (e) {
          _logger.w('⚠️ Clear SSO cookies on unauthenticated failed: $e');
        }
        _logger.i('👋 No credentials found, stay unauthenticated');
        if (!mounted) return;
        state = const AuthState.initial().copyWith(isInitialized: true);
        FlutterNativeSplash.remove();
        return;
      }

    // 🚀 优化：先读取资料完成初始化，展示 UI，不要在白屏等登录结果
    state = AuthState.authenticated(
      username: username,
      realName: profile['realName'],
      uid: profile['uid'],
      avatarUrl: profile['avatarUrl'],
    ).copyWith(isInitialized: true, status: AuthStatus.authenticating);
    _logger.i('📱 Profile restored, marked as initialized');
    FlutterNativeSplash.remove();

    // 启动只做轻量会话探测：持久化 Cookie 仍然有效就直接复用，
    // 跳过整套登录链；只有探测到失效才走完整静默登录（会先清旧 Cookie 再重登）。
    try {
      if (await _ref.read(authServiceProvider).hasValidPersistedSession()) {
        _logger.i('✅ Persisted session valid, reusing cookies');
        state = state.copyWith(status: AuthStatus.authenticated);
        _schedulePostLoginWork(username, includeLibrary: false);
        return;
      }
      _logger.i('⚠️ Persisted session expired, silent re-login...');
    } catch (e) {
      _logger.w('⚠️ Session probe failed ($e), falling back to silent login');
    }

    // 3. 异步尝试自动登录 (不影响/阻塞初始化状态)
    try {
      state = state.copyWith(status: AuthStatus.authenticating);
      await _ref.read(authServiceProvider).silentLogin(
            username: snapshot.username,
            password: snapshot.password,
          );

      _logger.i('✅ Auto-login success, refreshing info...');
      state = state.copyWith(status: AuthStatus.authenticated);

      // 首帧之后再启动非认证业务，避免和登录网络抢首屏资源。
      _schedulePostLoginWork(username, includeLibrary: false);
    } catch (e) {
      _logger.e('❌ Auto-login failed: $e');

      // 4. 失败处理 - 保持已有资料，仅更新状态和错误信息
      String errorMsg = '登录异常: $e';
      if (e.toString().contains('AuthException') ||
          e.toString().contains('Unauthorized') ||
          e.toString().contains('密码错误')) {
        _logger.w('Credentials invalid, clearing storage');
        errorMsg = '凭据已失效，请重新登录';
      } else if (e.toString().contains('TimeoutException') ||
          e.toString().contains('timeout')) {
        _logger.w('Auto-login timeout');
        errorMsg = '登录超时(网速慢)，请尝试手动刷新';
      }

      state = state.copyWith(
        status: AuthStatus.unauthenticated,
        errorMessage: errorMsg,
        isInitialized: true,
      );
    }
    } catch (e) {
      _logger.e('Error during checkAuthStatus: $e');
      if (mounted) {
        state = const AuthState.initial().copyWith(isInitialized: true);
      }
    } finally {
      FlutterNativeSplash.remove();
    }
  }

  void _schedulePostLoginWork(String? username,
      {required bool includeLibrary}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || state.status != AuthStatus.authenticated) return;
      unawaited(_runPostLoginWork(username, includeLibrary: includeLibrary));
    });
  }

  Future<void> _runPostLoginWork(String? username,
      {required bool includeLibrary}) async {
    // 1. 启动并在自动静默登录后，优先尝试拉取云端最新备份并覆盖应用到本地
    await _pullCloudBackupSilently();

    if (!mounted || state.status != AuthStatus.authenticated) return;
    if (username != null) {
      unawaited(_ref.read(homeworkProvider.notifier).refresh(username));
      unawaited(_ref.read(noticeProvider.notifier).refresh());
    }
    if (includeLibrary) {
      unawaited(_ref.read(cachedLibraryReserveProvider.notifier).refresh());
    }
    unawaited(_refreshUserInfo());
    unawaited(_ref.read(campusCardServiceProvider).authenticate());
    unawaited(_pullTimetableSilently());
  }

  /// 静默拉取云端最新备份并应用到本地
  Future<void> _pullCloudBackupSilently() async {
    try {
      final backup =
          await CloudBackupManager.instance.pullLatestOnStartup();
      if (backup != null && mounted) {
        await BackupProviderRefresh.refreshAfterRestore(_ref, backup);
        _logger.i('☁️ Startup cloud backup pull completed and applied');
      }
    } catch (e) {
      _logger.w('⚠️ Silent cloud backup pull failed: $e');
    }
  }

  /// 刷新用户资料
  Future<void> _refreshUserInfo() async {
    try {
      final info = await _ref.read(authServiceProvider).fetchFullUserInfo();
      if (info.isNotEmpty) {
        final realName = info['realName'];
        final username = info['username'];
        final uid = info['uid'];
        final avatarUrl = info['avatarUrl'];

        // 更新状态
        state = state.copyWith(
          username: username,
          realName: realName,
          uid: uid,
          avatarUrl: avatarUrl,
        );

        // 持久化到本地
        if (realName != null && uid != null) {
          await SecureStorageHelper().saveProfileInfo(
            realName: realName,
            uid: uid,
            avatarUrl: avatarUrl,
          );
        }
      }
    } catch (e) {
      _logger.w('⚠️ Refresh user info failed: $e');
    }
  }

  /// 退出登录
  Future<void> logout() async {
    try {
      try {
        await _ref.read(authServiceProvider).logout();
      } catch (e) {
        _logger.w('⚠️ authServiceProvider.logout failed: $e');
      }

      try {
        _ref.read(noticeProvider.notifier).clear();
      } catch (_) {}

      // 退出登录时删除本地课表数据 (ICS, 元数据, 原始课程列表, 规则以及课程列表 JSON)
      try {
        final storage = TimetableStorage();
        await storage.deleteTimetable();
        await storage.deleteMetadata();
        await storage.deleteCourseList();
        await storage.deleteRawCourseList();
        await storage.deleteRules();
        await _ref.read(timetableStatusProvider.notifier).refresh();
      } catch (e) {
        _logger.w('⚠️ delete timetable data failed: $e');
      }

      // 退出登录时删除本地作业数据
      try {
        await _ref.read(homeworkProvider.notifier).clearAll();
      } catch (e) {
        _logger.w('⚠️ clear homework failed: $e');
      }

      // 退出登录时删除本地考试日程
      try {
        await ExamStorage().deleteExamList();
        await _ref.read(examProvider.notifier).refresh();
      } catch (e) {
        _logger.w('⚠️ delete exam list failed: $e');
      }

      // 退出登录时清空 AI 记忆
      try {
        await AiMemoryStorage().clearAll();
      } catch (e) {
        _logger.w('⚠️ clear AI memory failed: $e');
      }

      // 退出登录时清空小组件日程数据
      try {
        await HomeWidgetService().clearWidgets();
      } catch (e) {
        _logger.w('⚠️ clear HomeWidget failed: $e');
      }

      // 退出登录时清空教务 JWT Token
      try {
        YdjwxtAuthService().clearToken();
      } catch (e) {
        _logger.w('⚠️ clear Ydjwxt token failed: $e');
      }

      // 退出登录时清理日历订阅配置与 UUID
      try {
        await TimetableSubscriptionService().clearSubscriptionOnLogout();
      } catch (e) {
        _logger.w('⚠️ clear subscription failed: $e');
      }

      // 退出登录时清空问卷缓存
      try {
        await _ref.read(questionnaireCacheProvider.notifier).clear();
      } catch (_) {}

      // 退出登录时清空请假和报修缓存
      try {
        await _ref.read(leaveCacheProvider.notifier).clear();
        await _ref.read(repairCacheProvider.notifier).clear();
      } catch (_) {}

      // 退出登录时清空校园卡与宿舍电费缓存及持久化
      try {
        _ref.read(campusCardCacheProvider.notifier).clear();
        await _ref.read(campusCardServiceProvider).clearSession();
      } catch (e) {
        _logger.w('⚠️ clear campus card session failed: $e');
      }

      try {
        _ref.read(electricityCacheProvider.notifier).clear();
        await _ref.read(electricityServiceProvider).clearAllSavedRooms();
      } catch (e) {
        _logger.w('⚠️ Clear saved electricity rooms on logout failed: $e');
      }

      // 退出登录时清空图书馆预约
      try {
        await LibraryStorage.clearReserves();
      } catch (_) {}

      // 退出登录时重置云备份状态（待同步任务、槽位定位、开关）
      try {
        await CloudBackupManager.instance.resetOnLogout();
      } catch (e) {
        _logger.w('⚠️ resetOnLogout failed: $e');
      }

      try {
        await _ref.read(settingsProvider.notifier).reload();
      } catch (e) {
        _logger.w('⚠️ Reload settings after logout failed: $e');
      }

      // 退出登录时深度清理 WebView 缓存与 WebStorage 数据
      try {
        await WebViewCacheService.clearCache(includeDiskFiles: true, clearStorage: true);
      } catch (e) {
        _logger.w('⚠️ Clear WebView cache on logout failed: $e');
      }

      // 退出登录时删除本地头像文件
      try {
        await _deleteLocalAvatars();
      } catch (e) {
        _logger.w('⚠️ Delete avatars failed: $e');
      }
    } finally {
      state = const AuthState.initial();
    }
  }

  /// 删除文档目录下的本地头像缓存（avatar_<uid>.png）。
  Future<void> _deleteLocalAvatars() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      await for (final entity in dir.list()) {
        final name = entity.path.split(Platform.pathSeparator).last;
        if (entity is File &&
            name.startsWith('avatar_') &&
            name.endsWith('.png')) {
          try {
            await entity.delete();
          } catch (_) {}
        }
      }
    } catch (e) {
      _logger.w('⚠️ Delete local avatars on logout failed: $e');
    }
  }

  /// 设置状态为正在登录
  void setAuthenticating() {
    state = const AuthState.authenticating();
  }

  /// 设置状态为已登录并保存凭据 (由 LoginScreen 调用)
  Future<void> login(String username, String password) async {
    try {
      state = state.copyWith(status: AuthStatus.authenticating);
      await _ref.read(authServiceProvider).login(username, password);

      // 标记为已登录
      state = AuthState.authenticated(username: username).copyWith(
        isInitialized: true,
      );

      // 手动登录成功且未看过当前版本引导时，推一屏推荐向导
      try {
        final prefs = await SharedPreferences.getInstance();
        final lastSeen =
            prefs.getInt(CloudSyncPromptScreen.kLastSeenGuideVersionKey) ?? 0;
        if (lastSeen < CloudSyncPromptScreen.kCurrentOnboardingGuideVersion) {
          _ref.read(cloudSyncPromptPendingProvider.notifier).state = true;
        }
      } catch (_) {}

      // 首帧之后再启动非认证业务，登录页可以立即关闭。
      _schedulePostLoginWork(username, includeLibrary: true);
    } catch (e) {
      state = AuthState.error(e.toString());
      rethrow;
    }
  }

  /// 设置状态为已登录
  void setAuthenticated() {
    state = state.copyWith(status: AuthStatus.authenticated);
  }

  /// 设置状态为未登录(带错误信息)
  void setUnauthenticated([String? errorMessage]) {
    state = errorMessage != null
        ? AuthState.error(errorMessage)
        : const AuthState.initial();
  }

  /// 清除错误信息
  void clearError() {
    if (state.errorMessage != null) {
      state = state.copyWith(errorMessage: null);
    }
  }

  /// 进入访客模式 (跳过登录)
  void enterGuestMode() {
    state = state.copyWith(isGuestMode: true);
  }

  /// 登录后自动同步课表（本地有课表也会全量同步，保证最新）。
  /// 仅受设置里的自动同步开关控制，关闭则直接跳过。
  Future<void> _pullTimetableSilently() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final autoSync =
          prefs.getBool(SettingsNotifier.timetableAutoSyncKey) ?? true;
      if (!autoSync) {
        _logger.i('📅 Timetable auto-sync disabled, skipping.');
        return;
      }

      _ref.read(timetableSyncInProgressProvider.notifier).state = true;
      _logger.i('📅 Starting background timetable sync...');

      await TimetableService().downloadAndSaveTimetable(
        semester: AppConstants.defaultSemester,
        firstWeekMonday: null,
      );

      // 同步后重排上课提醒，避免新课表与旧提醒不一致
      try {
        await _ref.read(settingsProvider.notifier).rescheduleNotifications();
      } catch (e) {
        _logger.w('⚠️ Reschedule after timetable sync failed: $e');
      }

      _logger.i('✅ Background timetable sync success');
    } catch (e) {
      _logger.w('⚠️ Background timetable sync failed: $e');
    } finally {
      _ref.read(timetableSyncInProgressProvider.notifier).state = false;
      // 无论后台同步成功或失败完成，均显式调用 refresh 广播课表状态变更，退出转圈
      try {
        await _ref.read(timetableStatusProvider.notifier).refresh();
      } catch (e) {
        _logger.w('⚠️ Refresh timetableStatusProvider failed: $e');
      }
    }
  }
}
