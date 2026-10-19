import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ChillEast/features/home/screens/home_screen.dart';
import 'package:ChillEast/features/homework/models/homework_model.dart';
import 'package:ChillEast/features/homework/providers/homework_provider.dart';
import 'package:ChillEast/features/homework/services/homework_storage.dart';
import 'package:ChillEast/l10n/app_localizations.dart';

class FakeHomeworkStorage extends HomeworkStorage {
  final List<HomeworkModel> stored;
  FakeHomeworkStorage(this.stored);

  @override
  Future<List<HomeworkModel>> readHomeworkList() async => List.from(stored);

  @override
  Future<void> saveHomeworkList(List<HomeworkModel> homeworks) async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('HomeScreen displays only the 3 most recent homework items', (tester) async {
    final now = DateTime(2026, 10, 19, 12, 0);
    final homeworks = [
      HomeworkModel(id: '1', title: '作业1', courseName: '语文', studentId: 'stu1', endTime: now.add(const Duration(hours: 1)), status: HomeworkStatus.pending),
      HomeworkModel(id: '2', title: '作业2', courseName: '数学', studentId: 'stu1', endTime: now.add(const Duration(hours: 2)), status: HomeworkStatus.pending),
      HomeworkModel(id: '3', title: '作业3', courseName: '英语', studentId: 'stu1', endTime: now.add(const Duration(hours: 3)), status: HomeworkStatus.pending),
      HomeworkModel(id: '4', title: '作业4', courseName: '物理', studentId: 'stu1', endTime: now.add(const Duration(hours: 4)), status: HomeworkStatus.pending),
      HomeworkModel(id: '5', title: '作业5', courseName: '化学', studentId: 'stu1', endTime: now.add(const Duration(hours: 5)), status: HomeworkStatus.pending),
    ];

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          homeworkStorageProvider.overrideWithValue(FakeHomeworkStorage(homeworks)),
        ],
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: Locale('zh'),
          home: Scaffold(
            body: HomeScreen(),
          ),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    // Verify only the first 3 homework items are displayed
    expect(find.text('作业1'), findsOneWidget);
    expect(find.text('作业2'), findsOneWidget);
    expect(find.text('作业3'), findsOneWidget);
    expect(find.text('作业4'), findsNothing);
    expect(find.text('作业5'), findsNothing);
  });

  testWidgets('HomeScreen ignores completed homework and displays nearest 3 pending items', (tester) async {
    final now = DateTime(2026, 10, 19, 12, 0);
    final homeworks = [
      HomeworkModel(id: '1', title: '已完成作业', courseName: '语文', studentId: 'stu1', endTime: now.add(const Duration(hours: 1)), status: HomeworkStatus.completed),
      HomeworkModel(id: '2', title: '作业最紧急', courseName: '数学', studentId: 'stu1', endTime: now.add(const Duration(hours: 2)), status: HomeworkStatus.pending),
      HomeworkModel(id: '3', title: '作业较紧急', courseName: '英语', studentId: 'stu1', endTime: now.add(const Duration(hours: 3)), status: HomeworkStatus.pending),
      HomeworkModel(id: '4', title: '作业次紧急', courseName: '物理', studentId: 'stu1', endTime: now.add(const Duration(hours: 4)), status: HomeworkStatus.pending),
      HomeworkModel(id: '5', title: '作业稍后', courseName: '化学', studentId: 'stu1', endTime: now.add(const Duration(hours: 5)), status: HomeworkStatus.pending),
    ];

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          homeworkStorageProvider.overrideWithValue(FakeHomeworkStorage(homeworks)),
        ],
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: Locale('zh'),
          home: Scaffold(
            body: HomeScreen(),
          ),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('已完成作业'), findsNothing);
    expect(find.text('作业最紧急'), findsOneWidget);
    expect(find.text('作业较紧急'), findsOneWidget);
    expect(find.text('作业次紧急'), findsOneWidget);
    expect(find.text('作业稍后'), findsNothing);
  });
}
