import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ChillEast/features/workspace/screens/electricity_recharge_screen.dart';
import 'package:ChillEast/features/workspace/services/electricity_service.dart';
import 'package:ChillEast/features/workspace/services/campus_card_service.dart';
import 'package:ChillEast/features/workspace/models/electricity_model.dart';
import 'package:ChillEast/l10n/app_localizations.dart';

class MockElectricityService extends ElectricityService {
  MockElectricityService(super.ref);

  @override
  Future<List<ElectricityArea>> getAreas() async {
    return [
      ElectricityArea(id: '金岸公寓空调', name: '金岸公寓空调'),
      ElectricityArea(id: '东湖校区', name: '东湖校区'),
    ];
  }

  @override
  Future<List<ElectricityBuilding>> getBuildings(String areaName) async {
    return [
      ElectricityBuilding(id: '金岸1栋', name: '金岸1栋'),
      ElectricityBuilding(id: '金岸2栋', name: '金岸2栋'),
    ];
  }

  @override
  Future<List<ElectricityRoom>> getRooms(String areaName, String buildingName) async {
    return [
      ElectricityRoom(id: '629', name: '629', mertype: 'yk'),
      ElectricityRoom(id: '630', name: '630', mertype: 'yk'),
    ];
  }

  @override
  Future<ElectricityBalanceInfo> getBalance({
    required String areaName,
    required String buildingName,
    required String roomId,
    required String mertype,
    int? slot,
  }) async {
    return ElectricityBalanceInfo(balance: '50.88', detail: '正常');
  }
}

class MockCampusCardService extends CampusCardService {
  MockCampusCardService();

  @override
  Future<CampusCardInfo> fetchRechargeInfo({bool isRetry = false, bool forceRefresh = false}) async {
    return CampusCardInfo(
      name: '测试用户',
      idserial: '123456',
      balance: '100.00',
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Widget buildTestWidget({int initialSlot = 0}) {
    return ProviderScope(
      overrides: [
        electricityServiceProvider.overrideWith((ref) => MockElectricityService(ref)),
        campusCardServiceProvider.overrideWith((ref) => MockCampusCardService()),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('zh'),
        home: ElectricityRechargeScreen(initialSlot: initialSlot),
      ),
    );
  }

  testWidgets('ElectricityRechargeScreen shows two cards, exactly one expanded, and allows accordion toggle', (tester) async {
    final service = ProviderContainer().read(electricityServiceProvider);
    await service.saveSavedRoom(
      const SavedElectricityRoom(
        areaName: '金岸公寓空调',
        buildingName: '金岸1栋',
        roomId: '629',
        roomName: '629',
        mertype: 'yk',
      ),
      slot: 0,
    );
    await service.saveSavedRoom(
      const SavedElectricityRoom(
        areaName: '东湖校区',
        buildingName: '金岸2栋',
        roomId: '630',
        roomName: '630',
        mertype: 'yk',
      ),
      slot: 1,
    );

    await tester.pumpWidget(buildTestWidget(initialSlot: 0));
    await tester.pumpAndSettle();

    // Card 1 is expanded, Card 2 is collapsed
    expect(find.textContaining('当前充值房间'), findsOneWidget);
    expect(find.textContaining('金岸公寓空调 - 金岸1栋 - 629'), findsWidgets);

    // Collapsed Card 2 shows single strip without '>'
    expect(find.textContaining('东湖校区 - 金岸2栋 - 630'), findsOneWidget);

    // Tap collapsed Card 2 to expand it
    await tester.tap(find.textContaining('东湖校区 - 金岸2栋 - 630'));
    await tester.pumpAndSettle();

    // Now Card 2 is expanded, Card 1 is collapsed
    expect(find.textContaining('当前充值房间'), findsOneWidget);
    expect(find.textContaining('金岸公寓空调 - 金岸1栋 - 629'), findsWidgets);

    await tester.pump(const Duration(seconds: 11));
  });

  testWidgets('ElectricityRechargeScreen clear button clears the active card room', (tester) async {
    final service = ProviderContainer().read(electricityServiceProvider);
    await service.saveSavedRoom(
      const SavedElectricityRoom(
        areaName: '金岸公寓空调',
        buildingName: '金岸1栋',
        roomId: '629',
        roomName: '629',
        mertype: 'yk',
      ),
      slot: 0,
    );

    await tester.pumpWidget(buildTestWidget(initialSlot: 0));
    await tester.pumpAndSettle();

    expect(find.textContaining('金岸公寓空调 - 金岸1栋 - 629'), findsWidgets);

    // Click "清空" button
    final clearButton = find.text('清空');
    expect(clearButton, findsOneWidget);
    await tester.tap(clearButton);
    await tester.pumpAndSettle();

    // After clear, room is cleared
    expect(find.text('尚未选择房间'), findsOneWidget);
    expect(await service.getSavedRoom(slot: 0), isNull);

    await tester.pump(const Duration(seconds: 11));
  });
}
