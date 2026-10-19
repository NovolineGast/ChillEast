import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/l10n_extension.dart';
import '../../../core/widgets/brand_switch.dart';
import '../../timetable/services/timetable_subscription_service.dart';
import '../providers/settings_provider.dart';

/// 课表订阅与在线同步页：管理调停后课表的 Cloudflare R2 云端日历订阅。
class TimetableSubscriptionScreen extends ConsumerStatefulWidget {
  const TimetableSubscriptionScreen({super.key});

  @override
  ConsumerState<TimetableSubscriptionScreen> createState() =>
      _TimetableSubscriptionScreenState();
}

class _TimetableSubscriptionScreenState
    extends ConsumerState<TimetableSubscriptionScreen> {
  bool _isSwitching = false;
  bool _isResetting = false;

  Future<void> _handleToggle(bool value) async {
    if (_isSwitching) return;
    setState(() => _isSwitching = true);
    final l10n = context.l10n;

    try {
      await ref
          .read(settingsProvider.notifier)
          .setTimetableSubscriptionEnabled(value);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.syncFailed(e.toString())),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSwitching = false);
    }
  }

  Future<void> _handleCopyUrl(String url) async {
    await Clipboard.setData(ClipboardData(text: url));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.l10n.subscriptionUrlCopied),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }


  Future<void> _handleResetUrl() async {
    if (_isResetting) return;
    final l10n = context.l10n;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.resetSubscriptionConfirmTitle),
        content: Text(l10n.resetSubscriptionConfirmMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(
              l10n.confirm,
              style: const TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _isResetting = true);
    try {
      await ref
          .read(settingsProvider.notifier)
          .resetTimetableSubscriptionUuid();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.syncFailed(e.toString())),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isResetting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final l10n = context.l10n;
    final state = ref.watch(settingsProvider);
    final isEnabled = state.timetableSubscriptionEnabled;
    final uuid = state.timetableSubscriptionUuid ?? '';
    final subscriptionUrl = uuid.isNotEmpty
        ? TimetableSubscriptionService.buildSubscriptionUrl(uuid)
        : '';

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(l10n.timetableSubscription),
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: isDark ? Colors.white : const Color(0xFF202124),
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
        iconTheme: IconThemeData(
          color: isDark ? Colors.white : Colors.black87,
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          // 开关项
          InkWell(
            onTap: _isSwitching ? null : () => _handleToggle(!isEnabled),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  const Icon(
                    Icons.cloud_upload_outlined,
                    size: 24,
                    color: Color(0xFF5F6368),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      l10n.timetableSubscriptionAutoUpload,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w400,
                        color:
                            isDark ? Colors.white : const Color(0xFF202124),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (_isSwitching)
                    const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  else
                    BrandSwitch(
                      value: isEnabled,
                      onChanged: _handleToggle,
                    ),
                ],
              ),
            ),
          ),

          if (isEnabled && subscriptionUrl.isNotEmpty) ...[
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.timetableSubscriptionUrl,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white70 : const Color(0xFF5F6368),
                    ),
                  ),
                  const SizedBox(height: 8),
                  // URL 显示框
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.transparent,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: isDark
                            ? Colors.white12
                            : const Color(0xFFE0E0E0),
                      ),
                    ),
                    child: SelectableText(
                      subscriptionUrl,
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 13,
                        color: isDark
                            ? const Color(0xFF8AB4F8)
                            : const Color(0xFF1A73E8),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  // 操作按钮组：只保留复制链接和重置链接，同一行右对齐并对齐样式
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton.icon(
                        onPressed: () => _handleCopyUrl(subscriptionUrl),
                        icon: const Icon(Icons.copy_rounded, size: 18),
                        label: Text(l10n.copySubscriptionUrl),
                        style: TextButton.styleFrom(
                          foregroundColor: isDark
                              ? Colors.white70
                              : const Color(0xFF5F6368),
                        ),
                      ),
                      const SizedBox(width: 4),
                      TextButton.icon(
                        onPressed: _isResetting ? null : _handleResetUrl,
                        icon: const Icon(Icons.refresh_rounded, size: 18),
                        label: Text(l10n.resetSubscriptionUrl),
                        style: TextButton.styleFrom(
                          foregroundColor: isDark
                              ? Colors.white70
                              : const Color(0xFF5F6368),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
