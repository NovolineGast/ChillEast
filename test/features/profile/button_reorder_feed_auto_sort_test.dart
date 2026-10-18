import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ChillEast/features/cloudisk/services/cloud_backup_manager.dart';
import 'package:ChillEast/core/state/locale_provider.dart';
import 'package:ChillEast/core/utils/fallback_localizations_delegate.dart';
import 'package:ChillEast/features/profile/screens/button_reorder_screen.dart';
import 'package:ChillEast/l10n/app_localizations.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Widget buildTestWidget({
    required Widget child,
  }) {
    return ProviderScope(
      child: Consumer(
        builder: (context, ref, _) {
          final locale = ref.watch(localeProvider);
          return MaterialApp(
            localizationsDelegates: const [
              AppLocalizations.delegate,
              AppMaterialLocalizationsDelegate(),
              AppCupertinoLocalizationsDelegate(),
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            locale: locale ?? const Locale('zh'),
            supportedLocales: AppLocalizations.supportedLocales,
            home: child,
          );
        },
      ),
    );
  }

  group('ButtonReorderScreen Feed Auto Sort', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    tearDown(() async {
      await CloudBackupManager.instance.resetOnLogout();
    });

    testWidgets(
        'when autoSort is off, sort section is normal and dragging is enabled',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        buildTestWidget(
          child: const ButtonReorderScreen(
            title: '信息流设置',
            listType: 'feed',
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 验证存在自动排序开关，且当前为关
      final switchFinder = find.byType(SwitchListTile);
      expect(switchFinder, findsOneWidget);
      final switchTile = tester.widget<SwitchListTile>(switchFinder);
      expect(switchTile.value, isFalse);

      // 验证 ReorderableListView 的 buildDefaultDragHandles 为 true
      final reorderableFinder = find.byType(ReorderableListView);
      expect(reorderableFinder, findsOneWidget);
      final reorderableList =
          tester.widget<ReorderableListView>(reorderableFinder);
      expect(reorderableList.buildDefaultDragHandles, isTrue);

      // 验证 AnimatedOpacity 为 1.0，且无 ColorFiltered (置灰滤镜)
      final opacityFinder = find.byType(AnimatedOpacity);
      expect(opacityFinder, findsOneWidget);
      final opacityWidget = tester.widget<AnimatedOpacity>(opacityFinder);
      expect(opacityWidget.opacity, equals(1.0));

      final colorFilteredFinder = find.descendant(
        of: opacityFinder,
        matching: find.byType(ColorFiltered),
      );
      expect(colorFilteredFinder, findsNothing);
    });

    testWidgets(
        'when autoSort is turned on, sort section is grayed out and dragging is disabled',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        buildTestWidget(
          child: const ButtonReorderScreen(
            title: '信息流设置',
            listType: 'feed',
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 点击开启自动排序
      final switchFinder = find.byType(SwitchListTile);
      await tester.tap(switchFinder);
      await tester.pumpAndSettle();

      final switchTile = tester.widget<SwitchListTile>(switchFinder);
      expect(switchTile.value, isTrue);

      // 验证 ReorderableListView 的 buildDefaultDragHandles 为 false (不再允许拖动)
      final reorderableFinder = find.byType(ReorderableListView);
      final reorderableList =
          tester.widget<ReorderableListView>(reorderableFinder);
      expect(reorderableList.buildDefaultDragHandles, isFalse);

      // 验证存在 ColorFiltered 且 AnimatedOpacity 变灰 (< 0.5)
      final opacityFinder = find.byType(AnimatedOpacity);
      expect(opacityFinder, findsOneWidget);
      final opacityWidget = tester.widget<AnimatedOpacity>(opacityFinder);
      expect(opacityWidget.opacity, equals(0.38));

      final colorFilteredFinder = find.descendant(
        of: opacityFinder,
        matching: find.byType(ColorFiltered),
      );
      expect(colorFilteredFinder, findsOneWidget);

      // 再次点击关闭自动排序
      await tester.tap(switchFinder);
      await tester.pumpAndSettle();

      final switchTileOff = tester.widget<SwitchListTile>(switchFinder);
      expect(switchTileOff.value, isFalse);

      // 验证恢复允许拖动且不再置灰
      final reorderableListRestored =
          tester.widget<ReorderableListView>(reorderableFinder);
      expect(reorderableListRestored.buildDefaultDragHandles, isTrue);

      final opacityWidgetRestored =
          tester.widget<AnimatedOpacity>(opacityFinder);
      expect(opacityWidgetRestored.opacity, equals(1.0));

      expect(
        find.descendant(
          of: opacityFinder,
          matching: find.byType(ColorFiltered),
        ),
        findsNothing,
      );

      // 释放 CloudBackupManager.markDirty 的防抖定时器
      await tester.pump(const Duration(seconds: 15));
    });
  });
}
