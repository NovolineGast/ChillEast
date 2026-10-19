import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ChillEast/features/library/models/library_models.dart';
import 'package:ChillEast/features/library/services/library_storage.dart';
import 'package:ChillEast/l10n/app_localizations.dart';

Widget _buildLocalizedWidget(Widget Function(BuildContext) builder) {
  return MaterialApp(
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: AppLocalizations.supportedLocales,
    locale: const Locale('zh'),
    home: Builder(builder: builder),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ReserveStatus Tests', () {
    test('fromInt maps values properly', () {
      expect(ReserveStatus.fromInt(0), ReserveStatus.reserved);
      expect(ReserveStatus.fromInt(1), ReserveStatus.inUse);
      expect(ReserveStatus.fromInt(3), ReserveStatus.temporarilyAway);
      expect(ReserveStatus.fromInt(5), ReserveStatus.flexibleSign);
      expect(ReserveStatus.fromInt(7), ReserveStatus.completed);
      expect(ReserveStatus.fromInt(99), ReserveStatus.unknown);
      expect(ReserveStatus.fromInt(null), ReserveStatus.unknown);
    });

    test('label and canSignBack properties', () {
      expect(ReserveStatus.reserved.label, '待签到');
      expect(ReserveStatus.reserved.canSignBack, isFalse);

      expect(ReserveStatus.inUse.label, '使用中');
      expect(ReserveStatus.inUse.canSignBack, isTrue);

      expect(ReserveStatus.temporarilyAway.label, '暂离中');
      expect(ReserveStatus.temporarilyAway.canSignBack, isTrue);

      expect(ReserveStatus.flexibleSign.label, '可签到');
      expect(ReserveStatus.flexibleSign.canSignBack, isTrue);

      expect(ReserveStatus.completed.label, '已结束');
      expect(ReserveStatus.completed.canSignBack, isFalse);

      expect(ReserveStatus.cancelled.label, '已取消');
      expect(ReserveStatus.cancelled.canSignBack, isFalse);

      expect(ReserveStatus.unknown.label, '未知');
      expect(ReserveStatus.unknown.canSignBack, isFalse);
    });

    testWidgets('getLocalizedLabel returns localized strings', (tester) async {
      late BuildContext ctx;
      await tester.pumpWidget(_buildLocalizedWidget((context) {
        ctx = context;
        return const SizedBox();
      }));

      for (final s in ReserveStatus.values) {
        expect(s.getLocalizedLabel(ctx), isNotEmpty);
      }
    });
  });

  group('LibraryReserveModel Tests', () {
    test('fromJson and toJson with numeric and string fields', () {
      final now = DateTime.now();
      final json = {
        'id': '101',
        'roomId': '202',
        'deptId': '303',
        'seatNum': 'A-01',
        'startTime': now.millisecondsSinceEpoch,
        'endTime': now.add(const Duration(hours: 2)).millisecondsSinceEpoch,
        'expireTime': now.add(const Duration(minutes: 15)).millisecondsSinceEpoch,
        'inserttime': now.subtract(const Duration(minutes: 5)).millisecondsSinceEpoch,
        'status': '1',
        'firstLevelName': '逸夫楼',
        'secondLevelName': '三楼',
        'thirdLevelName': '电子阅览室',
        'today': '2026-10-19',
        'duration': '2小时',
        'uname': '张三',
        'uid': '202440800000',
      };

      final model = LibraryReserveModel.fromJson(json);
      expect(model.id, 101);
      expect(model.roomId, 202);
      expect(model.deptId, 303);
      expect(model.seatNum, 'A-01');
      expect(model.status, 1);
      expect(model.reserveStatus, ReserveStatus.inUse);
      expect(model.fullRoomName, '逸夫楼 · 三楼 · 电子阅览室');
      expect(model.uid, 202440800000);

      final out = model.toJson();
      expect(out['id'], 101);
      expect(out['seatNum'], 'A-01');
      expect(out['firstLevelName'], '逸夫楼');
    });

    test('fullRoomName filters empty parts', () {
      final model = LibraryReserveModel(
        id: 1,
        roomId: 1,
        deptId: 1,
        seatNum: '01',
        startTime: DateTime.now(),
        endTime: DateTime.now(),
        status: 0,
        firstLevelName: '图书馆',
        secondLevelName: '',
        thirdLevelName: '自习室',
        today: '',
      );
      expect(model.fullRoomName, '图书馆 · 自习室');
    });
  });

  group('LibraryRoomModel, Seat, and Grid Tests', () {
    test('LibraryRoomModel fromJson and getters', () {
      final json = {
        'id': 12,
        'firstLevelName': '逸夫馆',
        'secondLevelName': '二楼',
        'thirdLevelName': '自习区A',
        'capacity': '100',
        'reserveBeforeDay': 2,
        'reserveBeforeTime': '20:00',
        'reserveAfterDay': 0,
        'reserveAfterTime': '08:00',
        'deptId': 33430,
        'gridStyle': 1,
      };

      final room = LibraryRoomModel.fromJson(json);
      expect(room.id, 12);
      expect(room.capacity, 100);
      expect(room.displayName, '自习区A');
      expect(room.floorName, '二楼');

      final roomNoThird = LibraryRoomModel.fromJson({
        'secondLevelName': '二楼',
        'thirdLevelName': '',
      });
      expect(roomNoThird.displayName, '二楼');
    });

    test('LibrarySeatItem and LibraryGridConfigItem fromJson', () {
      final seat = LibrarySeatItem.fromJson({
        'id': '1',
        'roomId': '10',
        'seatNum': '001',
        'x': '5',
        'y': '6',
        'reserveStatus': '0',
      });
      expect(seat.id, 1);
      expect(seat.roomId, 10);
      expect(seat.seatNum, '001');
      expect(seat.x, 5);
      expect(seat.y, 6);
      expect(seat.reserveStatus, 0);

      final config = LibraryGridConfigItem.fromJson({
        'x': 2,
        'y': 3,
        'type': 1,
        'label': '柱子',
      });
      expect(config.x, 2);
      expect(config.label, '柱子');
    });

    test('LibrarySeatGridData parses coordinates and obstacles map', () {
      final json = {
        'otherDatas': {
          'roomId': 100,
          'x': 10,
          'y': 15,
          'config': jsonEncode([
            {'x': 1, 'y': 1, 'type': 9, 'label': '大门'},
            {'x': 2, 'y': 2, 'type': 8, 'label': '服务台'},
          ]),
        },
        'seatDatas': [
          {'id': 1, 'roomId': 100, 'seatNum': 'S01', 'x': 3, 'y': 3, 'reserveStatus': 0},
          {'id': 2, 'roomId': 100, 'seatNum': 'S02', 'x': 3, 'y': 4, 'reserveStatus': 1},
        ],
      };

      final grid = LibrarySeatGridData.fromJson(json);
      expect(grid.roomId, 100);
      expect(grid.cols, 10);
      expect(grid.rows, 15);
      expect(grid.seats.length, 2);
      expect(grid.obstacles.length, 2);
      expect(grid.seatMapByNum['S01']?.id, 1);
      expect(grid.seatMapByCoord['3,3']?.seatNum, 'S01');
      expect(grid.obstacleMapByCoord['1,1']?.label, '大门');
    });

    test('LibrarySeatConfig fromJson', () {
      final json = {
        'deptId': 33430,
        'preSignDuration': 20,
        'signDuration': 20,
        'reserveBeforeDay': 2,
        'reserveBeforeTime': '20:00',
        'commonTimeConfig': {
          'monStartTime': '08:00',
          'monEndTime': '22:30',
        },
        'minReserveDuration': 1.0,
        'reserveDuration': 4.0,
      };

      final cfg = LibrarySeatConfig.fromJson(json);
      expect(cfg.preSignDuration, 20);
      expect(cfg.monStartTime, '08:00');
      expect(cfg.monEndTime, '22:30');
      expect(cfg.minReserveDuration, 1.0);
      expect(cfg.maxReserveDuration, 4.0);
    });

    test('LibraryIndexData activeReservation getter', () {
      final res1 = LibraryReserveModel(
        id: 1, roomId: 1, deptId: 1, seatNum: '01',
        startTime: DateTime.now(), endTime: DateTime.now(), status: 0,
        firstLevelName: '', secondLevelName: '', thirdLevelName: '', today: '',
      );
      final indexData = LibraryIndexData(curReserves: [res1], nearReserves: []);
      expect(indexData.activeReservation?.id, 1);

      final emptyIndexData = LibraryIndexData(curReserves: [], nearReserves: []);
      expect(emptyIndexData.activeReservation, isNull);
    });

    test('LibraryMatchedSeatModel formatted getters and serialization', () {
      final start = DateTime(2026, 10, 19, 9, 30);
      final end = DateTime(2026, 10, 19, 11, 30);
      final matched = LibraryMatchedSeatModel(
        roomId: 50,
        seatNum: 'B-02',
        firstLevelName: '主楼',
        secondLevelName: '二层',
        thirdLevelName: '自习室',
        startTime: start,
        endTime: end,
        duration: '2小时',
      );

      expect(matched.fullRoomName, '主楼 · 二层 · 自习室');
      expect(matched.formattedTimeRange, '09:30 ~ 11:30');
      expect(matched.formattedDate, '2026-10-19');

      final json = matched.toJson();
      final revived = LibraryMatchedSeatModel.fromJson(json);
      expect(revived.seatNum, 'B-02');
      expect(revived.duration, '2小时');
    });
  });

  group('LibraryStorage Tests', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('saveReserves, getCachedReserves and clearReserves', () async {
      expect(await LibraryStorage.getCachedReserves(), isEmpty);

      final reserves = [
        LibraryReserveModel(
          id: 1, roomId: 1, deptId: 1, seatNum: 'S1',
          startTime: DateTime.now(), endTime: DateTime.now(), status: 1,
          firstLevelName: 'A', secondLevelName: 'B', thirdLevelName: 'C', today: '2026-10-19',
        ),
      ];

      await LibraryStorage.saveReserves(reserves);
      final cached = await LibraryStorage.getCachedReserves();
      expect(cached.length, 1);
      expect(cached.first.seatNum, 'S1');

      await LibraryStorage.clearReserves();
      expect(await LibraryStorage.getCachedReserves(), isEmpty);
    });

    test('getCachedReserves supports legacy single cached reserve', () async {
      final prefs = await SharedPreferences.getInstance();
      final legacy = {
        'id': 99,
        'roomId': 1,
        'deptId': 1,
        'seatNum': 'LEGACY_01',
        'startTime': DateTime.now().millisecondsSinceEpoch,
        'endTime': DateTime.now().millisecondsSinceEpoch,
        'status': 0,
        'firstLevelName': '旧馆',
        'secondLevelName': '一层',
        'thirdLevelName': '',
        'today': '2026-10-19',
      };
      await prefs.setString('cached_library_reserve', jsonEncode(legacy));

      final cached = await LibraryStorage.getCachedReserves();
      expect(cached.length, 1);
      expect(cached.first.seatNum, 'LEGACY_01');
    });

    test('getCachedReserves safely handles corrupted data', () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('cached_library_reserves', 'bad { json');
      final result = await LibraryStorage.getCachedReserves();
      expect(result, isEmpty);
    });
  });
}
