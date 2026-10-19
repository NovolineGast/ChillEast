import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/score_provider.dart';
import '../models/score_model.dart';
import '../../../core/utils/l10n_extension.dart';

class ScoreScreen extends ConsumerWidget {
  const ScoreScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(scoreProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(context.l10n.scoreQuery),
        elevation: 0,
        backgroundColor: theme.scaffoldBackgroundColor,
        surfaceTintColor: theme.scaffoldBackgroundColor,
        foregroundColor: isDark ? Colors.white : Colors.black87,
        actions: [
          IconButton(
            tooltip: context.l10n.refresh,
            icon: const Icon(Icons.refresh_rounded, size: 22),
            onPressed: () => ref.read(scoreProvider.notifier).refresh(),
          ),
        ],
      ),
      body: Column(
        children: [
          // 1. 学期选择栏 (扁平化设计)
          _buildSemesterPicker(context, ref, state, isDark),
          
          Divider(
            height: 1,
            thickness: 0.5,
            color: isDark
                ? Colors.white.withValues(alpha: 0.12)
                : const Color(0xFFE0E0E0),
          ),
          
          // 2. 成绩列表
          Expanded(
            child: _buildScoreList(context, ref, state, isDark),
          ),
        ],
      ),
    );
  }

  Widget _buildSemesterPicker(
      BuildContext context, WidgetRef ref, ScoreState state, bool isDark) {
    if (state.semesters.isEmpty && !state.isLoading) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          Text(
            context.l10n.currentSemester,
            style: TextStyle(
              fontSize: 14, 
              fontWeight: FontWeight.w600, 
              color: isDark ? Colors.white70 : Colors.grey[800],
              letterSpacing: 0.1,
            ),
          ),
          const SizedBox(width: 12),
          if (state.isLoading && state.semesters.isEmpty)
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Color(0xFF09C489),
              ),
            )
          else
            Expanded(
              child: Align(
                alignment: Alignment.centerLeft,
                child: DropdownButton<SemesterModel>(
                  value: state.selectedSemester,
                  underline: const SizedBox(),
                  icon: Icon(Icons.arrow_drop_down_rounded, color: Colors.grey[600]),
                  style: const TextStyle(
                    color: Color(0xFF09C489),
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                  isExpanded: true,
                  items: state.semesters.map((s) {
                    return DropdownMenuItem(
                      value: s,
                      child: Text(s.name, overflow: TextOverflow.ellipsis),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) {
                      ref.read(scoreProvider.notifier).changeSemester(val);
                    }
                  },
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildScoreList(
      BuildContext context, WidgetRef ref, ScoreState state, bool isDark) {
    if (state.isLoading && state.scores.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF09C489)),
      );
    }

    if (state.errorMessage != null && state.scores.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline_rounded, size: 48, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text(state.errorMessage!, style: TextStyle(color: Colors.grey[600])),
            const SizedBox(height: 24),
            OutlinedButton(
              onPressed: () => ref.read(scoreProvider.notifier).refresh(),
              style: OutlinedButton.styleFrom(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
              ),
              child: Text(context.l10n.retry),
            ),
          ],
        ),
      );
    }

    if (state.scores.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.assignment_turned_in_outlined,
                size: 64, color: isDark ? Colors.white24 : Colors.grey[300]),
            const SizedBox(height: 16),
            Text(
              context.l10n.noScoreData,
              style: TextStyle(
                fontSize: 14,
                color: isDark ? Colors.white38 : Colors.grey,
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      color: const Color(0xFF09C489),
      onRefresh: () => ref.read(scoreProvider.notifier).refresh(),
      child: Stack(
        children: [
          ListView.builder(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
            itemCount: state.scores.length,
            itemBuilder: (context, index) {
              final score = state.scores[index];
              return _buildScoreCard(context, score, isDark);
            },
          ),
          if (state.isLoading)
            const Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: LinearProgressIndicator(
                minHeight: 2,
                color: Color(0xFF09C489),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildScoreCard(BuildContext context, ScoreModel score, bool isDark) {
    final primaryTextColor = isDark ? Colors.white : const Color(0xFF222222);

    final courseNatureParts = [
      if (score.courseNature != null && score.courseNature!.trim().isNotEmpty)
        score.courseNature!.trim(),
      if (score.courseCode != null && score.courseCode!.trim().isNotEmpty)
        score.courseCode!.trim(),
    ];
    final bool hasCourseNature = courseNatureParts.isNotEmpty;
    final String secondaryText = hasCourseNature
        ? courseNatureParts.join(' · ')
        : (score.credit != null && score.credit!.trim().isNotEmpty
            ? context.l10n.scoreCredit(score.credit!.trim())
            : '');
    final bool showCreditInWrap = hasCourseNature;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.12)
              : const Color(0xFFE0E0E0),
          width: 1,
        ),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  score.courseName,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: primaryTextColor,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                score.score,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: primaryTextColor,
                  fontFamily: 'monospace',
                ),
              ),
            ],
          ),
          if (secondaryText.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              secondaryText,
              style: TextStyle(
                fontSize: 13,
                color: isDark ? Colors.white60 : Colors.black54,
              ),
            ),
          ],
          const SizedBox(height: 8),
          Wrap(
            spacing: 12,
            runSpacing: 4,
            children: [
              if (showCreditInWrap &&
                  score.credit != null &&
                  score.credit!.trim().isNotEmpty)
                Text(
                  context.l10n.scoreCredit(score.credit!.trim()),
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.white38 : Colors.grey[600],
                  ),
                ),
              Text(
                score.examType ?? context.l10n.normalExam,
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? Colors.white38 : Colors.grey[600],
                ),
              ),
              if (score.dailyScore != null &&
                  score.dailyScore!.trim().isNotEmpty)
                Text(
                  '平时: ${score.dailyScore!.trim()}',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.white38 : Colors.grey[600],
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}


