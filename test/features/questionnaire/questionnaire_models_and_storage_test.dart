import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ChillEast/features/questionnaire/models/questionnaire_models.dart';
import 'package:ChillEast/features/questionnaire/services/questionnaire_storage.dart';
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

  group('QuestionnaireItem Tests', () {
    test('fromJson and toJson round-trip correctly', () {
      final json = {
        'DM': 'Q1001',
        'MC': '学生心理健康调研',
        'KSSJ': '2026-10-01 00:00:00',
        'JSSJ': '2026-10-31 23:59:59',
        'TASK_TIME_M': '20261001',
        'DONE_IND': '0',
        'FLAG': '1',
        'ZT': '0',
        'SHZT': '0',
      };

      final item = QuestionnaireItem.fromJson(json);
      expect(item.dm, 'Q1001');
      expect(item.title, '学生心理健康调研');
      expect(item.startTime, '2026-10-01 00:00:00');
      expect(item.endTime, '2026-10-31 23:59:59');
      expect(item.taskTimeM, '20261001');
      expect(item.doneInd, '0');
      expect(item.isSubmitted, isFalse);

      final outJson = item.toJson();
      expect(outJson['DM'], 'Q1001');
      expect(outJson['MC'], '学生心理健康调研');
    });

    test('isSubmitted returns true if any completion flag is 1', () {
      const i1 = QuestionnaireItem(dm: '1', title: '', startTime: '', endTime: '', taskTimeM: '', zt: '1');
      expect(i1.isSubmitted, isTrue);

      const i2 = QuestionnaireItem(dm: '2', title: '', startTime: '', endTime: '', taskTimeM: '', shzt: '1');
      expect(i2.isSubmitted, isTrue);

      const i3 = QuestionnaireItem(dm: '3', title: '', startTime: '', endTime: '', taskTimeM: '', doneInd: '1');
      expect(i3.isSubmitted, isTrue);

      const i4 = QuestionnaireItem(dm: '4', title: '', startTime: '', endTime: '', taskTimeM: '');
      expect(i4.isSubmitted, isFalse);
    });

    test('isExpired logic for future, past, empty, and invalid dates', () {
      const emptyEnd = QuestionnaireItem(dm: '1', title: '', startTime: '', endTime: '', taskTimeM: '');
      expect(emptyEnd.isExpired, isFalse);

      const invalidEnd = QuestionnaireItem(dm: '2', title: '', startTime: '', endTime: 'not-a-date', taskTimeM: '');
      expect(invalidEnd.isExpired, isFalse);

      final pastDate = DateTime.now().subtract(const Duration(days: 2)).toIso8601String();
      final expiredItem = QuestionnaireItem(dm: '3', title: '', startTime: '', endTime: pastDate, taskTimeM: '');
      expect(expiredItem.isExpired, isTrue);

      final futureDate = DateTime.now().add(const Duration(days: 2)).toIso8601String();
      final activeItem = QuestionnaireItem(dm: '4', title: '', startTime: '', endTime: futureDate, taskTimeM: '');
      expect(activeItem.isExpired, isFalse);
    });

    test('statusLabel branches', () {
      const submitted = QuestionnaireItem(dm: '1', title: '', startTime: '', endTime: '', taskTimeM: '', zt: '1');
      expect(submitted.statusLabel, '已提交');

      final pastDate = DateTime.now().subtract(const Duration(days: 2)).toIso8601String();
      final expired = QuestionnaireItem(dm: '2', title: '', startTime: '', endTime: pastDate, taskTimeM: '');
      expect(expired.statusLabel, '已截止');

      final futureDate = DateTime.now().add(const Duration(days: 2)).toIso8601String();
      final pending = QuestionnaireItem(dm: '3', title: '', startTime: '', endTime: futureDate, taskTimeM: '');
      expect(pending.statusLabel, '待填写');
    });

    test('timeRange formatting', () {
      const r1 = QuestionnaireItem(
        dm: '1',
        title: '',
        startTime: '2026-10-01 09:00',
        endTime: '2026-10-15 18:00',
        taskTimeM: '',
      );
      expect(r1.timeRange, '2026-10-01 ~ 2026-10-15');

      const rEmpty = QuestionnaireItem(dm: '2', title: '', startTime: '', endTime: '', taskTimeM: '');
      expect(rEmpty.timeRange, '');
    });

    testWidgets('QuestionnaireItemL10n returns localized status', (tester) async {
      late BuildContext ctx;
      await tester.pumpWidget(_buildLocalizedWidget((context) {
        ctx = context;
        return const SizedBox();
      }));

      const submitted = QuestionnaireItem(dm: '1', title: '', startTime: '', endTime: '', taskTimeM: '', zt: '1');
      expect(submitted.getLocalizedStatus(ctx), isNotEmpty);

      final pastDate = DateTime.now().subtract(const Duration(days: 2)).toIso8601String();
      final expired = QuestionnaireItem(dm: '2', title: '', startTime: '', endTime: pastDate, taskTimeM: '');
      expect(expired.getLocalizedStatus(ctx), isNotEmpty);

      final futureDate = DateTime.now().add(const Duration(days: 2)).toIso8601String();
      final pending = QuestionnaireItem(dm: '3', title: '', startTime: '', endTime: futureDate, taskTimeM: '');
      expect(pending.getLocalizedStatus(ctx), isNotEmpty);
    });
  });

  group('QuestionnaireOption, Question, and Detail', () {
    test('QuestionnaireOption fromJson', () {
      final opt = QuestionnaireOption.fromJson({'dm': '1', 'mc': '非常好'});
      expect(opt.dm, '1');
      expect(opt.name, '非常好');
    });

    test('QuestionnaireQuestion fromJson and type getters', () {
      final json = {
        'dm': 'st01',
        'stmc': '您的年级？',
        'stsm': '请如实填写',
        'stType': '1',
        'txType': '',
        'btInd': '1',
        'jg': '大一',
        'stxxList': [
          {'dm': '1', 'mc': '大一'},
          {'dm': '2', 'mc': '大二'},
        ],
      };

      final q = QuestionnaireQuestion.fromJson(json);
      expect(q.dm, 'st01');
      expect(q.title, '您的年级？');
      expect(q.desc, '请如实填写');
      expect(q.required, isTrue);
      expect(q.answer, '大一');
      expect(q.options.length, 2);
      expect(q.isChoice, isTrue);
      expect(q.isMultiChoice, isFalse);
      expect(q.isDate, isFalse);
      expect(q.isPhone, isFalse);

      final qMulti = QuestionnaireQuestion.fromJson({'dm': 'm1', 'stmc': '', 'stType': '2'});
      expect(qMulti.isMultiChoice, isTrue);
      expect(qMulti.isChoice, isTrue);

      final qDate = QuestionnaireQuestion.fromJson({'dm': 'd1', 'stmc': '', 'stType': '4', 'txType': '3'});
      expect(qDate.isDate, isTrue);
      final qDate4 = QuestionnaireQuestion.fromJson({'dm': 'd2', 'stmc': '', 'stType': '4', 'txType': '4'});
      expect(qDate4.isDate, isTrue);

      final qPhone = QuestionnaireQuestion.fromJson({'dm': 'p1', 'stmc': '', 'stType': '4', 'txType': '2'});
      expect(qPhone.isPhone, isTrue);

      final qInvalidList = QuestionnaireQuestion.fromJson({'dm': 'x', 'stmc': '', 'stxxList': 'not-a-list'});
      expect(qInvalidList.options, isEmpty);
    });

    test('QuestionnaireDetail fromJson handles titles, desc and questions', () {
      final json = {
        'dm': 'detail01',
        'mc': '学工问卷标题',
        'sm': '说明文案',
        'jgM': 'JGM123',
        'canSubmit': '1',
        'stList': [
          {'dm': 'q1', 'stmc': '题目一'}
        ]
      };

      final detail = QuestionnaireDetail.fromJson(json);
      expect(detail.dm, 'detail01');
      expect(detail.title, '学工问卷标题');
      expect(detail.desc, '说明文案');
      expect(detail.jgM, 'JGM123');
      expect(detail.canSubmit, isTrue);
      expect(detail.questions.length, 1);

      // Fallbacks
      final fallbackJson = {
        'dm': 'detail02',
        'sm': '仅有说明',
        'bz': '备注备用',
        'jgM': '',
        'canSubmit': '0',
      };
      final detail2 = QuestionnaireDetail.fromJson(fallbackJson);
      expect(detail2.title, '仅有说明');
      expect(detail2.canSubmit, isFalse);
      expect(detail2.questions, isEmpty);
    });
  });

  group('QuestionnaireStorage Tests', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('saveItems, getCachedItems, and clearItems work as expected', () async {
      expect(await QuestionnaireStorage.getCachedItems(), isEmpty);

      final items = [
        const QuestionnaireItem(dm: 'q1', title: '问卷1', startTime: '', endTime: '', taskTimeM: ''),
        const QuestionnaireItem(dm: 'q2', title: '问卷2', startTime: '', endTime: '', taskTimeM: ''),
      ];

      await QuestionnaireStorage.saveItems(items);
      final cached = await QuestionnaireStorage.getCachedItems();
      expect(cached.length, 2);
      expect(cached[0].dm, 'q1');
      expect(cached[1].dm, 'q2');

      await QuestionnaireStorage.clearItems();
      expect(await QuestionnaireStorage.getCachedItems(), isEmpty);
    });

    test('recovers safely from invalid JSON in SharedPreferences', () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('cached_questionnaire_items', '{{{ corrupted');
      final result = await QuestionnaireStorage.getCachedItems();
      expect(result, isEmpty);
    });
  });
}
