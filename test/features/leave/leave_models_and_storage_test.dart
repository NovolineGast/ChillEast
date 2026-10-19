import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ChillEast/features/leave/models/leave_models.dart';
import 'package:ChillEast/features/leave/services/leave_storage.dart';
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

  group('LeaveRecord Tests', () {
    test('fromJson and toJson serialize correctly', () {
      final json = {
        'ID': '12345',
        'LXMC': '事假',
        'KSSJ': '2026-10-19 08:00',
        'JSSJ': '2026-10-20 18:00',
        'TS': 2,
        'HOUR': 4,
        'QJSY': '家中有事',
        'SHZT': '0',
        'SHZTMC': '待审核',
        'SHJGMC': '通过',
        'HAS_FILE': '1',
      };

      final record = LeaveRecord.fromJson(json);
      expect(record.id, '12345');
      expect(record.typeName, '事假');
      expect(record.startTime, '2026-10-19 08:00');
      expect(record.endTime, '2026-10-20 18:00');
      expect(record.days, 2);
      expect(record.hours, 4);
      expect(record.reason, '家中有事');
      expect(record.auditStatus, '0');
      expect(record.auditStatusName, '待审核');
      expect(record.auditResultName, '通过');
      expect(record.hasFile, isTrue);
      expect(record.canDelete, isTrue);

      final outJson = record.toJson();
      expect(outJson['ID'], '12345');
      expect(outJson['TS'], 2);
      expect(outJson['HOUR'], 4);
      expect(outJson['HAS_FILE'], '1');
    });

    test('fromJson handles string TS and HOUR and null fields', () {
      final json = {
        'TS': '3',
        'HOUR': '5',
        'HAS_FILE': '0',
      };

      final record = LeaveRecord.fromJson(json);
      expect(record.days, 3);
      expect(record.hours, 5);
      expect(record.hasFile, isFalse);
      expect(record.id, '');
      expect(record.canDelete, isFalse);
    });

    test('statusLabel branches', () {
      // 1. With auditStatusName
      const r1 = LeaveRecord(
        id: '1',
        typeName: '病假',
        startTime: '',
        endTime: '',
        auditStatus: '9',
        auditStatusName: '已审核',
        auditResultName: '同意',
      );
      expect(r1.statusLabel, '已审核·同意');

      const r2 = LeaveRecord(
        id: '2',
        typeName: '病假',
        startTime: '',
        endTime: '',
        auditStatus: '8',
        auditStatusName: '审核中',
      );
      expect(r2.statusLabel, '审核中');

      // 2. Empty auditStatusName fallbacks
      const r3 = LeaveRecord(id: '3', typeName: '', startTime: '', endTime: '', auditStatus: '0');
      expect(r3.statusLabel, '待审核');

      const r4 = LeaveRecord(id: '4', typeName: '', startTime: '', endTime: '', auditStatus: '8');
      expect(r4.statusLabel, '审核中');

      const r5 = LeaveRecord(id: '5', typeName: '', startTime: '', endTime: '', auditStatus: '9', auditResultName: '通过');
      expect(r5.statusLabel, '已审核·通过');

      const r6 = LeaveRecord(id: '6', typeName: '', startTime: '', endTime: '', auditStatus: '9');
      expect(r6.statusLabel, '已审核');

      const r7 = LeaveRecord(id: '7', typeName: '', startTime: '', endTime: '', auditStatus: 'unknown');
      expect(r7.statusLabel, '状态未知');
    });

    test('durationLabel formatting', () {
      expect(const LeaveRecord(id: '1', typeName: '', startTime: '', endTime: '', days: 2, hours: 3).durationLabel, '2天3小时');
      expect(const LeaveRecord(id: '2', typeName: '', startTime: '', endTime: '', days: 2).durationLabel, '2天');
      expect(const LeaveRecord(id: '3', typeName: '', startTime: '', endTime: '', hours: 5).durationLabel, '5小时');
      expect(const LeaveRecord(id: '4', typeName: '', startTime: '', endTime: '').durationLabel, '');
    });

    test('timeRange formatting', () {
      expect(const LeaveRecord(id: '1', typeName: '', startTime: '2026-10-19', endTime: '2026-10-20').timeRange, '2026-10-19 ~ 2026-10-20');
      expect(const LeaveRecord(id: '2', typeName: '', startTime: '2026-10-19', endTime: '').timeRange, '');
      expect(const LeaveRecord(id: '3', typeName: '', startTime: '', endTime: '2026-10-20').timeRange, '');
      expect(const LeaveRecord(id: '4', typeName: '', startTime: '', endTime: '').timeRange, '');
    });

    testWidgets('LeaveRecordL10n extension produces localized text', (tester) async {
      late BuildContext ctx;
      await tester.pumpWidget(_buildLocalizedWidget((context) {
        ctx = context;
        return const SizedBox();
      }));

      const r0 = LeaveRecord(id: '0', typeName: '', startTime: '', endTime: '', auditStatus: '0');
      expect(r0.getLocalizedStatus(ctx), isNotEmpty);

      const r8 = LeaveRecord(id: '8', typeName: '', startTime: '', endTime: '', auditStatus: '8');
      expect(r8.getLocalizedStatus(ctx), isNotEmpty);

      const r9WithResult = LeaveRecord(id: '9', typeName: '', startTime: '', endTime: '', auditStatus: '9', auditResultName: '同意');
      expect(r9WithResult.getLocalizedStatus(ctx), contains('同意'));

      const r9Plain = LeaveRecord(id: '9b', typeName: '', startTime: '', endTime: '', auditStatus: '9');
      expect(r9Plain.getLocalizedStatus(ctx), isNotEmpty);

      const rNamePending = LeaveRecord(id: 'n1', typeName: '', startTime: '', endTime: '', auditStatusName: '待审核');
      expect(rNamePending.getLocalizedStatus(ctx), isNotEmpty);

      const rNameAuditing = LeaveRecord(id: 'n2', typeName: '', startTime: '', endTime: '', auditStatusName: '审核中');
      expect(rNameAuditing.getLocalizedStatus(ctx), isNotEmpty);

      const rNameAudited = LeaveRecord(id: 'n3', typeName: '', startTime: '', endTime: '', auditStatusName: '已审核', auditResultName: '通过');
      expect(rNameAudited.getLocalizedStatus(ctx), contains('通过'));

      const rNameAuditedNoResult = LeaveRecord(id: 'n4', typeName: '', startTime: '', endTime: '', auditStatusName: '已审核');
      expect(rNameAuditedNoResult.getLocalizedStatus(ctx), isNotEmpty);

      const rCustomName = LeaveRecord(id: 'c1', typeName: '', startTime: '', endTime: '', auditStatusName: '自定义状态');
      expect(rCustomName.getLocalizedStatus(ctx), '自定义状态');

      const rUnknown = LeaveRecord(id: 'u1', typeName: '', startTime: '', endTime: '');
      expect(rUnknown.getLocalizedStatus(ctx), isNotEmpty);

      const rDuration = LeaveRecord(id: 'd1', typeName: '', startTime: '', endTime: '', days: 2, hours: 3);
      expect(rDuration.getLocalizedDuration(ctx), contains('2'));
      expect(rDuration.getLocalizedDuration(ctx), contains('3'));

      const rEmptyDuration = LeaveRecord(id: 'd2', typeName: '', startTime: '', endTime: '');
      expect(rEmptyDuration.getLocalizedDuration(ctx), '');
    });
  });

  group('LeaveDictItem, RegionNode, LeaveDuration, LeaveDetail', () {
    test('LeaveDictItem fromJson', () {
      final item = LeaveDictItem.fromJson({'id': '101', 'text': '事假'});
      expect(item.id, '101');
      expect(item.name, '事假');
    });

    test('RegionNode fromJson parses nested children correctly', () {
      final json = {
        'id': '430000',
        'text': '湖南省',
        'children': [
          {
            'id': '430100',
            'text': '长沙市',
            'children': [
              {'id': '430102', 'text': '芙蓉区'}
            ]
          }
        ]
      };

      final node = RegionNode.fromJson(json);
      expect(node.id, '430000');
      expect(node.name, '湖南省');
      expect(node.children.length, 1);
      expect(node.children.first.id, '430100');
      expect(node.children.first.children.length, 1);
      expect(node.children.first.children.first.name, '芙蓉区');

      final emptyNode = RegionNode.fromJson({'id': '1', 'text': 'test', 'children': 'not-a-list'});
      expect(emptyNode.children, isEmpty);
    });

    test('LeaveDuration fromJson', () {
      final dur1 = LeaveDuration.fromJson({'day': 3, 'hour': 6});
      expect(dur1.days, 3);
      expect(dur1.hours, 6);

      final dur2 = LeaveDuration.fromJson({'day': '4', 'hour': '8'});
      expect(dur2.days, 4);
      expect(dur2.hours, 8);
    });

    test('LeaveDetail fromJson and index operator', () {
      final detail = LeaveDetail.fromJson({
        'name': '李四',
        'count': 5,
      });
      expect(detail['name'], '李四');
      expect(detail['count'], '5');
      expect(detail['non_existing'], '');
    });
  });

  group('LeaveStorage Tests', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('saveItems and getCachedItems work correctly', () async {
      expect(await LeaveStorage.getCachedItems(), isEmpty);

      final records = [
        const LeaveRecord(id: '1', typeName: '病假', startTime: '2026-10-19', endTime: '2026-10-20'),
        const LeaveRecord(id: '2', typeName: '事假', startTime: '2026-10-21', endTime: '2026-10-22'),
      ];

      await LeaveStorage.saveItems(records);
      final retrieved = await LeaveStorage.getCachedItems();
      expect(retrieved.length, 2);
      expect(retrieved[0].id, '1');
      expect(retrieved[1].id, '2');

      await LeaveStorage.clearItems();
      expect(await LeaveStorage.getCachedItems(), isEmpty);
    });

    test('getCachedItems recovers gracefully from corrupted JSON', () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('cached_leave_items', 'invalid JSON content');
      final retrieved = await LeaveStorage.getCachedItems();
      expect(retrieved, isEmpty);
    });
  });
}
