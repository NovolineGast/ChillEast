import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ChillEast/core/state/auth_state.dart';
import 'package:ChillEast/features/workspace/screens/functions_screen.dart';
import 'package:ChillEast/features/workspace/screens/campus_card_recharge_screen.dart';
import 'package:ChillEast/features/workspace/screens/electricity_recharge_screen.dart';
import 'package:ChillEast/features/workspace/screens/payment_code_screen.dart';
import 'package:ChillEast/features/workspace/models/electricity_model.dart';
import 'package:ChillEast/features/workspace/services/campus_card_service.dart';
import 'package:ChillEast/features/workspace/services/electricity_service.dart';
import 'package:ChillEast/core/widgets/embedded_detail_pane.dart';
import 'package:ChillEast/l10n/app_localizations.dart';

class FakeCampusCardService extends CampusCardService {
  FakeCampusCardService();

  @override
  Future<Map<String, dynamic>> fetchPaymentCode({bool isRetry = false, bool forceRefresh = false}) async {
    return {'paycode': '123456', 'info': 'test user', 'qrBase64': null};
  }

  @override
  Future<CampusCardInfo> fetchRechargeInfo({bool isRetry = false, bool forceRefresh = false}) async {
    return CampusCardInfo(name: '测试用户', idserial: '123456', balance: '100.00');
  }
}

class FakeElectricityService extends ElectricityService {
  FakeElectricityService(super.ref);

  @override
  Future<List<ElectricityArea>> getAreas() async => [];
  @override
  Future<List<ElectricityBuilding>> getBuildings(String areaName) async => [];
  @override
  Future<List<ElectricityRoom>> getRooms(String areaName, String buildingName) async => [];
}

class FakeAuthNotifier extends StateNotifier<AuthState> implements AuthNotifier {
  FakeAuthNotifier() : super(const AuthState(status: AuthStatus.authenticated, username: 'test_user'));

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Widget buildTestWidget() {
    return ProviderScope(
      overrides: [
        authStateProvider.overrideWith((ref) => FakeAuthNotifier()),
        campusCardServiceProvider.overrideWith((ref) => FakeCampusCardService()),
        electricityServiceProvider.overrideWith((ref) => FakeElectricityService(ref)),
      ],
      child: const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: Locale('zh'),
        home: Scaffold(
          body: FunctionsScreen(),
        ),
      ),
    );
  }

  testWidgets('FunctionsScreen on tablet: campus card recharge opens in right pane and disappears on back', (tester) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(buildTestWidget());
    await tester.pumpAndSettle();

    // Verify initially no EmbeddedDetailPane
    expect(find.byType(EmbeddedDetailPane), findsNothing);

    // Tap campus card recharge
    final cardRechargeBtn = find.text('校园卡充值');
    expect(cardRechargeBtn, findsOneWidget);
    await tester.tap(cardRechargeBtn);
    await tester.pumpAndSettle();

    // Verify right pane has opened with CampusCardRechargeScreen
    expect(find.byType(EmbeddedDetailPane), findsOneWidget);
    expect(find.byType(CampusCardRechargeScreen), findsOneWidget);

    // Tap back button inside CampusCardRechargeScreen
    final backBtn = find.descendant(
      of: find.byType(CampusCardRechargeScreen),
      matching: find.byIcon(Icons.arrow_back),
    );
    expect(backBtn, findsOneWidget);
    await tester.tap(backBtn);
    await tester.pumpAndSettle();

    // Verify right pane completely disappeared and is not left blank
    expect(find.byType(EmbeddedDetailPane), findsNothing);
    expect(find.byType(CampusCardRechargeScreen), findsNothing);
  });

  testWidgets('FunctionsScreen on tablet: electricity recharge opens in right pane and disappears on back', (tester) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(buildTestWidget());
    await tester.pumpAndSettle();

    // Verify initially no EmbeddedDetailPane
    expect(find.byType(EmbeddedDetailPane), findsNothing);

    // Tap electricity recharge
    final eleRechargeBtn = find.text('电费充值');
    expect(eleRechargeBtn, findsOneWidget);
    await tester.tap(eleRechargeBtn);
    await tester.pumpAndSettle();

    // Verify right pane has opened with ElectricityRechargeScreen
    expect(find.byType(EmbeddedDetailPane), findsOneWidget);
    expect(find.byType(ElectricityRechargeScreen), findsOneWidget);

    // Tap back button inside ElectricityRechargeScreen
    final backBtn = find.descendant(
      of: find.byType(ElectricityRechargeScreen),
      matching: find.byIcon(Icons.arrow_back),
    );
    expect(backBtn, findsOneWidget);
    await tester.tap(backBtn);
    await tester.pumpAndSettle();

    // Verify right pane completely disappeared
    expect(find.byType(EmbeddedDetailPane), findsNothing);
    expect(find.byType(ElectricityRechargeScreen), findsNothing);
  });

  testWidgets('FunctionsScreen on tablet: payment code opens in right pane and disappears on back', (tester) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(buildTestWidget());
    await tester.pumpAndSettle();

    // Verify initially no EmbeddedDetailPane
    expect(find.byType(EmbeddedDetailPane), findsNothing);

    // Tap payment code
    final payCodeBtn = find.text('付款码');
    expect(payCodeBtn, findsOneWidget);
    await tester.tap(payCodeBtn);
    await tester.pumpAndSettle();

    // Verify right pane has opened with PaymentCodeScreen
    expect(find.byType(EmbeddedDetailPane), findsOneWidget);
    expect(find.byType(PaymentCodeScreen), findsOneWidget);

    // Tap back button inside PaymentCodeScreen
    final backBtn = find.descendant(
      of: find.byType(PaymentCodeScreen),
      matching: find.byIcon(Icons.arrow_back),
    );
    expect(backBtn, findsOneWidget);
    await tester.tap(backBtn);
    await tester.pumpAndSettle();

    // Verify right pane completely disappeared
    expect(find.byType(EmbeddedDetailPane), findsNothing);
    expect(find.byType(PaymentCodeScreen), findsNothing);
  });
}
