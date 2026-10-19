import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ChillEast/features/timetable/providers/timetable_status_provider.dart';
import 'package:ChillEast/features/timetable/widgets/empty_timetable_state.dart';
import 'package:ChillEast/l10n/app_localizations.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Issue #31: Timetable refresh closed loop & spinner exit', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('timetableStatusProvider.refresh triggers listeners even when boolean status remains unchanged', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      int listenerCallCount = 0;
      bool? lastState;

      container.listen<bool>(
        timetableStatusProvider,
        (prev, next) {
          listenerCallCount++;
          lastState = next;
        },
      );

      // 初始状态应为 false (无本地课表)
      expect(container.read(timetableStatusProvider), isFalse);

      // 调用 refresh()：无课表状态下结果仍然为 false，但 forceNotify 应保证通知到监听器
      await container.read(timetableStatusProvider.notifier).refresh();

      expect(listenerCallCount, greaterThanOrEqualTo(1));
      expect(lastState, isFalse);
    });

    test('timetableSyncInProgressProvider tracks background sync lifecycle', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(container.read(timetableSyncInProgressProvider), isFalse);

      // 模拟进入同步
      container.read(timetableSyncInProgressProvider.notifier).state = true;
      expect(container.read(timetableSyncInProgressProvider), isTrue);

      // 模拟同步结束
      container.read(timetableSyncInProgressProvider.notifier).state = false;
      expect(container.read(timetableSyncInProgressProvider), isFalse);
    });

    testWidgets('EmptyTimetableState displays spinner ONLY when isSyncing is true', (tester) async {
      // 1. autoSyncEnabled = true, isSyncing = true -> 显示转圈
      await tester.pumpWidget(
        const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: EmptyTimetableState(
              autoSyncEnabled: true,
              isSyncing: true,
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      // 2. autoSyncEnabled = true, isSyncing = false -> 退出转圈，显示暂无课表
      await tester.pumpWidget(
        const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: EmptyTimetableState(
              autoSyncEnabled: true,
              isSyncing: false,
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsNothing);

      // 3. autoSyncEnabled = false, isSyncing = true -> 自动同步关闭时不转圈
      await tester.pumpWidget(
        const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: EmptyTimetableState(
              autoSyncEnabled: false,
              isSyncing: true,
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsNothing);
    });
  });
}
