import 'package:flutter/material.dart';
import '../../../core/utils/l10n_extension.dart';

/// 课表空状态组件
class EmptyTimetableState extends StatelessWidget {
  /// 自动同步是否开启。
  final bool autoSyncEnabled;

  /// 是否正在后台执行自动同步。仅在自动同步开启且真正同步中时显示“正在同步”及转圈；
  /// 同步完成后或关闭时退出转圈，显示暂无课表并提示点刷新按钮手动同步。
  final bool isSyncing;

  const EmptyTimetableState({
    super.key,
    this.autoSyncEnabled = true,
    this.isSyncing = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final showLoading = autoSyncEnabled && isSyncing;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: theme.primaryColor.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                showLoading
                    ? Icons.calendar_today_outlined
                    : (autoSyncEnabled
                        ? Icons.calendar_today_outlined
                        : Icons.cloud_off_outlined),
                size: 64,
                color: theme.primaryColor,
              ),
            ),
            const SizedBox(height: 32),
            Text(
              showLoading
                  ? context.l10n.timetableSyncing
                  : context.l10n.noLocalTimetable,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).brightness == Brightness.dark ? Colors.white : const Color(0xFF202124),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              showLoading
                  ? context.l10n.timetableSyncingDesc
                  : context.l10n.tapRefreshButtonToSync,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Theme.of(context).brightness == Brightness.dark ? Colors.white70 : const Color(0xFF5F6368),
                height: 1.5,
              ),
            ),
            if (showLoading) ...[
              const SizedBox(height: 32),
              const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
