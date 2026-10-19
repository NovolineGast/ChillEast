import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/score_service.dart';
import '../models/score_model.dart';
import '../../../core/utils/app_logger.dart';

class ScoreState {
  final bool isLoading;
  final List<ScoreModel> scores;
  final List<SemesterModel> semesters;
  final SemesterModel? selectedSemester;
  final String? errorMessage;

  ScoreState({
    required this.isLoading,
    required this.scores,
    required this.semesters,
    this.selectedSemester,
    this.errorMessage,
  });

  ScoreState.initial()
      : isLoading = true,
        scores = [],
        semesters = [],
        selectedSemester = null,
        errorMessage = null;

  ScoreState copyWith({
    bool? isLoading,
    List<ScoreModel>? scores,
    List<SemesterModel>? semesters,
    SemesterModel? selectedSemester,
    String? errorMessage,
  }) {
    return ScoreState(
      isLoading: isLoading ?? this.isLoading,
      scores: scores ?? this.scores,
      semesters: semesters ?? this.semesters,
      selectedSemester: selectedSemester ?? this.selectedSemester,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

final scoreProvider = StateNotifierProvider.autoDispose<ScoreNotifier, ScoreState>((ref) {
  return ScoreNotifier();
});

class ScoreNotifier extends StateNotifier<ScoreState> {
  final _service = ScoreService();
  final _logger = AppLogger.instance;

  ScoreNotifier() : super(ScoreState.initial()) {
    fetchInitialData();
  }

  Future<void> fetchInitialData() async {
    try {
      state = state.copyWith(isLoading: true, errorMessage: null);
      
      final semesters = await _service.fetchSemesterList();
      if (semesters.isEmpty) {
        state = state.copyWith(
          isLoading: false,
          scores: [],
          semesters: [],
          selectedSemester: null,
        );
        return;
      }

      // 找到当前活跃学期，默认选择第一个
      final SemesterModel active = semesters.firstWhere(
        (s) => s.isActive,
        orElse: () => semesters.first,
      );

      final scores = await _service.fetchScores(semester: active.id);

      state = state.copyWith(
        isLoading: false,
        scores: scores,
        semesters: semesters,
        selectedSemester: active,
      );
    } catch (e) {
      _logger.e('Error fetching initial score data: $e');
      if (kDebugMode) {
        state = state.copyWith(
          isLoading: false,
          errorMessage: null,
          semesters: [
            SemesterModel(id: '2025-2026-2', name: '2025-2026-2', isActive: true),
            SemesterModel(id: '2025-2026-1', name: '2025-2026-1'),
          ],
          selectedSemester: SemesterModel(id: '2025-2026-2', name: '2025-2026-2', isActive: true),
          scores: [
            ScoreModel(
              courseName: '毛泽东思想和中国特色社会主义理论体系概论',
              score: '93',
              credit: '3.0',
              examType: '正常考试',
              curriculumAttributes: '必修',
              courseNature: '公共必修课',
              courseCode: 'B621L10002',
            ),
            ScoreModel(
              courseName: '材料力学',
              score: '78',
              credit: '3.0',
              examType: '正常考试',
              curriculumAttributes: '必修',
              courseNature: '专业必修课',
              courseCode: 'B332L18300',
            ),
            ScoreModel(
              courseName: '大学英语(3)',
              score: '优秀',
              credit: '3.5',
              examType: '正常考试',
              curriculumAttributes: '必修',
              courseNature: '通识必修课',
              courseCode: 'ENG2003',
            ),
            ScoreModel(
              courseName: '高等数学A(1)',
              score: '58',
              credit: '5.0',
              examType: '正常考试',
              curriculumAttributes: '必修',
              courseNature: '通识必修课',
              courseCode: 'MATH1001',
              dailyScore: '62',
            ),
          ],
        );
        return;
      }
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
    }
  }

  Future<void> changeSemester(SemesterModel semester) async {
    if (semester == state.selectedSemester) return;

    try {
      state = state.copyWith(isLoading: true, selectedSemester: semester, errorMessage: null);
      final scores = await _service.fetchScores(semester: semester.id);

      state = state.copyWith(
        isLoading: false,
        scores: scores,
      );
    } catch (e) {
      _logger.e('Error changing semester to ${semester.id}: $e');
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
    }
  }

  Future<void> refresh() async {
    final sem = state.selectedSemester;
    if (sem == null) {
      await fetchInitialData();
      return;
    }

    try {
      state = state.copyWith(isLoading: true, errorMessage: null);
      final scores = await _service.fetchScores(semester: sem.id);

      state = state.copyWith(
        isLoading: false,
        scores: scores,
      );
    } catch (e) {
      _logger.e('Error refreshing score data: $e');
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
    }
  }
}
