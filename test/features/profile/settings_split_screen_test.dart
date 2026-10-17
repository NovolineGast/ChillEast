import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ChillEast/features/profile/screens/settings_screen.dart';
import 'package:ChillEast/features/profile/screens/language_settings_screen.dart';
import 'package:ChillEast/features/profile/screens/appearance_settings_screen.dart';
import 'package:ChillEast/core/widgets/embedded_detail_pane.dart';
import 'package:ChillEast/l10n/app_localizations.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Widget buildTestableWidget({
    required WidgetTester tester,
    required Widget child,
    required double width,
    required double height,
    List<Override> overrides = const [],
  }) {
    tester.view.physicalSize = Size(width, height);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    return ProviderScope(
      overrides: overrides,
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('zh'),
        home: MediaQuery(
          data: MediaQueryData(
            size: Size(width, height),
          ),
          child: SizedBox(
            width: width,
            height: height,
            child: child,
          ),
        ),
      ),
    );
  }

  group('SettingsScreen Split Screen Tests', () {
    testWidgets('Wide screen: tapping setting item opens it in right EmbeddedDetailPane',
        (tester) async {
      await tester.pumpWidget(
        buildTestableWidget(
          tester: tester,
          child: const SettingsScreen(),
          width: 900,
          height: 600,
        ),
      );
      await tester.pumpAndSettle();

      // Before tapping: no EmbeddedDetailPane
      expect(find.byType(EmbeddedDetailPane), findsNothing);

      // Tap "语言"
      final languageFinder = find.widgetWithText(InkWell, '语言');
      expect(languageFinder, findsOneWidget);
      await tester.tap(languageFinder);
      await tester.pumpAndSettle();

      // After tapping: EmbeddedDetailPane is rendered on the right half
      expect(find.byType(EmbeddedDetailPane), findsOneWidget);
      expect(find.byType(LanguageSettingsScreen), findsOneWidget);

      // Tap another setting item: "外观"
      final appearanceFinder = find.widgetWithText(InkWell, '外观');
      expect(appearanceFinder, findsOneWidget);
      await tester.tap(appearanceFinder);
      await tester.pumpAndSettle();

      // The right pane switches to AppearanceSettingsScreen
      expect(find.byType(AppearanceSettingsScreen), findsOneWidget);
      expect(find.byType(LanguageSettingsScreen), findsNothing);

      // Tap back button inside right pane
      final backButton = find.descendant(
        of: find.byType(EmbeddedDetailPane),
        matching: find.byType(BackButton),
      );
      expect(backButton, findsOneWidget);
      await tester.tap(backButton);
      await tester.pumpAndSettle();

      // Right pane is closed, restored to full width
      expect(find.byType(EmbeddedDetailPane), findsNothing);
      expect(find.byType(AppearanceSettingsScreen), findsNothing);
    });

    testWidgets('Wide screen: dynamically narrowing degrades to full-screen route push',
        (tester) async {
      await tester.pumpWidget(
        buildTestableWidget(
          tester: tester,
          child: const SettingsScreen(),
          width: 900,
          height: 600,
        ),
      );
      await tester.pumpAndSettle();

      // Tap "语言" to embed it
      await tester.tap(find.widgetWithText(InkWell, '语言'));
      await tester.pumpAndSettle();
      expect(find.byType(EmbeddedDetailPane), findsOneWidget);

      // Resize window to narrow (400 width)
      tester.view.physicalSize = const Size(400, 800);
      await tester.pump();
      await tester.pumpAndSettle();

      // Embedded pane is cleared, LanguageSettingsScreen is pushed onto root Navigator
      expect(find.byType(EmbeddedDetailPane), findsNothing);
      expect(find.byType(LanguageSettingsScreen), findsOneWidget);
    });

    testWidgets('Narrow screen: tapping setting item opens as full-screen route directly',
        (tester) async {
      await tester.pumpWidget(
        buildTestableWidget(
          tester: tester,
          child: const SettingsScreen(),
          width: 400,
          height: 800,
        ),
      );
      await tester.pumpAndSettle();

      // Tap "语言"
      await tester.tap(find.widgetWithText(InkWell, '语言'));
      await tester.pumpAndSettle();

      // Directly pushed without EmbeddedDetailPane
      expect(find.byType(EmbeddedDetailPane), findsNothing);
      expect(find.byType(LanguageSettingsScreen), findsOneWidget);
    });
  });
}
