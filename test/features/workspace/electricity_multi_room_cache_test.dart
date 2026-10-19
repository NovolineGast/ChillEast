import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ChillEast/core/state/auth_state.dart';
import 'package:ChillEast/features/workspace/models/electricity_model.dart';
import 'package:ChillEast/features/workspace/providers/electricity_cache_provider.dart';
import 'package:ChillEast/features/workspace/services/electricity_service.dart';

class FakeElectricityService extends ElectricityService {
  final Map<String, String> balancesByRoomId;

  FakeElectricityService(
    super.ref, {
    this.balancesByRoomId = const {
      'room_101': '15.50',
      'room_202': '88.00',
    },
  });

  @override
  Future<ElectricityBalanceInfo> getBalance({
    required String areaName,
    required String buildingName,
    required String roomId,
    required String mertype,
    int? slot,
  }) async {
    final balance = balancesByRoomId[roomId] ?? '0.00';
    final info = ElectricityBalanceInfo(
      balance: balance,
      detail: '正常',
      accname: '$buildingName-$roomId',
    );
    if (slot != null) {
      await saveSavedBalance(info, slot: slot);
    }
    return info;
  }
}

class FakeAuthNotifier extends StateNotifier<AuthState> implements AuthNotifier {
  FakeAuthNotifier(super.state);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Electricity Multi-Room Cache & Slot Isolation', () {
    test('getBalance for slot 1 does not overwrite slot 0 saved balance', () async {
      late ElectricityService fakeService;
      final container = ProviderContainer(
        overrides: [
          electricityServiceProvider.overrideWith((ref) {
            fakeService = FakeElectricityService(ref);
            return fakeService;
          }),
        ],
      );

      final service = container.read(electricityServiceProvider);

      // Save initial balances to slot 0 and slot 1
      await service.saveSavedBalance(
        ElectricityBalanceInfo(balance: '12.34', accname: '1栋-101'),
        slot: 0,
      );
      await service.saveSavedBalance(
        ElectricityBalanceInfo(balance: '56.78', accname: '2栋-202'),
        slot: 1,
      );

      // Verify initial storage
      final b0Before = await service.getSavedBalance(slot: 0);
      final b1Before = await service.getSavedBalance(slot: 1);
      expect(b0Before?.balance, equals('12.34'));
      expect(b1Before?.balance, equals('56.78'));

      // Now query slot 1 via FakeElectricityService with slot: 1
      await fakeService.getBalance(
        areaName: '校区A',
        buildingName: '2栋',
        roomId: 'room_202',
        mertype: 'yk',
        slot: 1,
      );

      // Verify slot 0 balance is STILL intact and NOT overwritten!
      final b0After = await service.getSavedBalance(slot: 0);
      final b1After = await service.getSavedBalance(slot: 1);
      expect(b0After?.balance, equals('12.34'), reason: 'Slot 0 balance should not be affected by slot 1 query');
      expect(b1After?.balance, equals('88.00'), reason: 'Slot 1 balance should be updated with new balance');
    });

    test('getBalance without slot does not overwrite slot 0 balance', () async {
      late ElectricityService fakeService;
      final container = ProviderContainer(
        overrides: [
          electricityServiceProvider.overrideWith((ref) {
            fakeService = FakeElectricityService(ref);
            return fakeService;
          }),
        ],
      );
      final service = container.read(electricityServiceProvider);

      await service.saveSavedBalance(
        ElectricityBalanceInfo(balance: '12.34', accname: '1栋-101'),
        slot: 0,
      );

      // Query without specifying slot (e.g. MCP tool query)
      await fakeService.getBalance(
        areaName: '校区A',
        buildingName: '2栋',
        roomId: 'room_202',
        mertype: 'yk',
      );

      final b0 = await service.getSavedBalance(slot: 0);
      expect(b0?.balance, equals('12.34'), reason: 'Unspecified slot query should not overwrite slot 0');
    });

    test('ElectricityCacheNotifier self-heals when slot 0 cache was polluted by slot 1', () async {
      // Simulate historical bug in SharedPreferences:
      // Both slot 0 and slot 1 had room_202's balance '88.00' and accname '2栋-room_202'
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        'saved_electricity_room',
        jsonEncode({
          'areaName': '校区A',
          'buildingName': '1栋',
          'roomId': 'room_101',
          'roomName': '101',
          'mertype': 'yk',
        }),
      );
      await prefs.setString(
        'saved_electricity_room_2',
        jsonEncode({
          'areaName': '校区B',
          'buildingName': '2栋',
          'roomId': 'room_202',
          'roomName': '202',
          'mertype': 'yk',
        }),
      );
      // Corrupted: slot 0 balance has slot 1's balance and accname
      await prefs.setString(
        'saved_electricity_balance_info',
        jsonEncode({
          'balance': '88.00',
          'accname': '2栋-room_202',
        }),
      );
      await prefs.setString(
        'saved_electricity_balance_info_2',
        jsonEncode({
          'balance': '88.00',
          'accname': '2栋-room_202',
        }),
      );

      final container = ProviderContainer(
        overrides: [
          electricityServiceProvider.overrideWith((ref) => FakeElectricityService(ref)),
          // Set unauthenticated so silentRefresh does not run automatically during test
          authStateProvider.overrideWith((ref) => FakeAuthNotifier(const AuthState.initial())),
        ],
      );

      final notifier = container.read(electricityCacheProvider.notifier);
      // Wait for _init to process
      await Future.delayed(const Duration(milliseconds: 50));

      final state = container.read(electricityCacheProvider);
      // Notice: corrupted slot 0 balance was detected and cleared, avoiding displaying 88.00 for both!
      expect(state.rooms[0]?.roomId, equals('room_101'));
      expect(state.rooms[1]?.roomId, equals('room_202'));
      expect(state.balances[0], isNull, reason: 'Corrupted slot 0 balance should be reset');
      expect(state.balances[1]?.balance, equals('88.00'));

      // Now run refresh: both rooms should be refreshed with their distinct actual balances
      await notifier.refresh();

      final refreshedState = container.read(electricityCacheProvider);
      expect(refreshedState.balances[0]?.balance, equals('15.50'), reason: 'Room 101 balance');
      expect(refreshedState.balances[1]?.balance, equals('88.00'), reason: 'Room 202 balance');

      // Verify SharedPreferences now stores distinct balances for both slots
      final service = container.read(electricityServiceProvider);
      final savedB0 = await service.getSavedBalance(slot: 0);
      final savedB1 = await service.getSavedBalance(slot: 1);
      expect(savedB0?.balance, equals('15.50'));
      expect(savedB1?.balance, equals('88.00'));
    });
  });
}
