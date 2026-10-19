import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../cloudisk/services/cloud_backup_manager.dart';

/// 描述 Material UI 调色板中的单个颜色项
class MaterialColorItem {
  final String family;
  final String shade;
  final Color color;

  const MaterialColorItem({
    required this.family,
    required this.shade,
    required this.color,
  });
}

/// 课程配色工具类
/// 
/// 遵循 https://materialui.co/colors 规范，严格限定在 Material UI 19 种色彩的 700 色阶：
/// Red, Pink, Purple, Deep Purple, Indigo, Blue, Light Blue, Cyan, Teal, Green,
/// Light Green, Lime, Yellow, Amber, Orange, Deep Orange, Brown, Grey, Blue Grey.
/// 
/// 并始终保证同一个课表中各门课程的颜色互不相同（唯一分配 + 换色对调机制）。
class CourseColorUtils {
  static const String _prefsKey = 'custom_course_colors';
  static final Map<String, Color> _assignedColors = {};
  static bool _initialized = false;
  static Future<void>? _initFuture;

  /// 来自 https://materialui.co/colors 的 19 种颜色的 700 色阶
  static const List<MaterialColorItem> materialColorItems = [
    MaterialColorItem(family: 'Red', shade: '700', color: Color(0xFFD32F2F)),
    MaterialColorItem(family: 'Pink', shade: '700', color: Color(0xFFC2185B)),
    MaterialColorItem(family: 'Purple', shade: '700', color: Color(0xFF7B1FA2)),
    MaterialColorItem(family: 'Deep Purple', shade: '700', color: Color(0xFF512DA8)),
    MaterialColorItem(family: 'Indigo', shade: '700', color: Color(0xFF303F9F)),
    MaterialColorItem(family: 'Blue', shade: '700', color: Color(0xFF1976D2)),
    MaterialColorItem(family: 'Light Blue', shade: '700', color: Color(0xFF0288D1)),
    MaterialColorItem(family: 'Cyan', shade: '700', color: Color(0xFF0097A7)),
    MaterialColorItem(family: 'Teal', shade: '700', color: Color(0xFF00796B)),
    MaterialColorItem(family: 'Green', shade: '700', color: Color(0xFF388E3C)),
    MaterialColorItem(family: 'Light Green', shade: '700', color: Color(0xFF689F38)),
    MaterialColorItem(family: 'Lime', shade: '700', color: Color(0xFFAFB42B)),
    MaterialColorItem(family: 'Yellow', shade: '700', color: Color(0xFFFBC02D)),
    MaterialColorItem(family: 'Amber', shade: '700', color: Color(0xFFFFA000)),
    MaterialColorItem(family: 'Orange', shade: '700', color: Color(0xFFF57C00)),
    MaterialColorItem(family: 'Deep Orange', shade: '700', color: Color(0xFFE64A19)),
    MaterialColorItem(family: 'Brown', shade: '700', color: Color(0xFF5D4037)),
    MaterialColorItem(family: 'Grey', shade: '700', color: Color(0xFF616161)),
    MaterialColorItem(family: 'Blue Grey', shade: '700', color: Color(0xFF455A64)),
  ];

  /// 供选取的全部颜色列表（严格限定为 19 个 700 色阶）
  static List<Color> get selectablePalette =>
      materialColorItems.map((item) => item.color).toList();

  /// 默认推荐分配顺序：冷暖与明暗交替轮换，确保相邻课程视觉反差鲜明
  static const List<Color> defaultPaletteOrder = [
    Color(0xFF303F9F), // Indigo 700
    Color(0xFFE64A19), // Deep Orange 700
    Color(0xFF00796B), // Teal 700
    Color(0xFFC2185B), // Pink 700
    Color(0xFF1976D2), // Blue 700
    Color(0xFFFFA000), // Amber 700
    Color(0xFF7B1FA2), // Purple 700
    Color(0xFF388E3C), // Green 700
    Color(0xFFD32F2F), // Red 700
    Color(0xFF0097A7), // Cyan 700
    Color(0xFFF57C00), // Orange 700
    Color(0xFF512DA8), // Deep Purple 700
    Color(0xFF689F38), // Light Green 700
    Color(0xFF0288D1), // Light Blue 700
    Color(0xFF5D4037), // Brown 700
    Color(0xFFAFB42B), // Lime 700
    Color(0xFF455A64), // Blue Grey 700
    Color(0xFFFBC02D), // Yellow 700
    Color(0xFF616161), // Grey 700
  ];

  /// 初始化从 SharedPreferences 读取已保存的课程颜色配置
  static Future<void> init() async {
    if (_initialized) return;
    if (_initFuture != null) return _initFuture;
    _initFuture = _doInit();
    await _initFuture;
  }

  static Future<void> _doInit() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = prefs.getString(_prefsKey);
      if (jsonStr != null && jsonStr.isNotEmpty) {
        final Map<String, dynamic> decoded = jsonDecode(jsonStr);
        final validARGBs = selectablePalette.map((c) => c.toARGB32()).toSet();
        for (final entry in decoded.entries) {
          if (entry.value is int) {
            final val = entry.value as int;
            // 仅载入属于 19 种 700 颜色的配置，历史非 700 配置将在 syncCourses 时统一重分配
            if (validARGBs.contains(val)) {
              _assignedColors[entry.key] = Color(val);
            }
          }
        }
      }
    } catch (_) {
      // 容错读取
    } finally {
      _initialized = true;
    }
  }

  static Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final data = <String, int>{};
      for (final entry in _assignedColors.entries) {
        data[entry.key] = entry.value.toARGB32();
      }
      await prefs.setString(_prefsKey, jsonEncode(data));
    } catch (_) {}
  }

  /// 同步规范化全量课程列表，保证当前所有课程颜色各自唯一，不产生重复冲突
  static void syncCourses(Iterable<String> courseNames) {
    final validNames = courseNames
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toSet()
        .toList();
    if (validNames.isEmpty) return;

    final validARGBs = selectablePalette.map((c) => c.toARGB32()).toSet();
    final usedColors = <int>{};
    final coursesNeedingAssignment = <String>[];

    // 1. 保留已有且属于 700 色板且互不重复的颜色
    for (final name in validNames) {
      final existingColor = _assignedColors[name];
      if (existingColor != null &&
          validARGBs.contains(existingColor.toARGB32()) &&
          !usedColors.contains(existingColor.toARGB32())) {
        usedColors.add(existingColor.toARGB32());
      } else {
        coursesNeedingAssignment.add(name);
      }
    }

    // 2. 为未分配或冲突的课程逐个分配未使用的颜色
    int searchIndex = 0;
    for (final name in coursesNeedingAssignment) {
      while (searchIndex < defaultPaletteOrder.length &&
          usedColors.contains(defaultPaletteOrder[searchIndex].toARGB32())) {
        searchIndex++;
      }

      Color picked;
      if (searchIndex < defaultPaletteOrder.length) {
        picked = defaultPaletteOrder[searchIndex];
        searchIndex++;
      } else {
        // 极端兜底（课程数超过 19 门）
        final hash = name.hashCode.abs();
        picked = defaultPaletteOrder[hash % defaultPaletteOrder.length];
      }

      _assignedColors[name] = picked;
      usedColors.add(picked.toARGB32());
    }

    _persist();
  }

  /// 获取课程对应颜色（若未分配则分配并保证与其他课程互不冲突）
  static Color getColorForCourse(String courseName) {
    final trimmed = courseName.trim();
    if (trimmed.isEmpty) return defaultPaletteOrder[0];

    final existing = _assignedColors[trimmed];
    if (existing != null &&
        selectablePalette.any((c) => c.toARGB32() == existing.toARGB32())) {
      return existing;
    }

    // 查找当前未被占用的颜色
    final usedColors = _assignedColors.values.map((c) => c.toARGB32()).toSet();
    for (final color in defaultPaletteOrder) {
      if (!usedColors.contains(color.toARGB32())) {
        _assignedColors[trimmed] = color;
        _persist();
        return color;
      }
    }

    final fallback =
        defaultPaletteOrder[trimmed.hashCode.abs() % defaultPaletteOrder.length];
    _assignedColors[trimmed] = fallback;
    _persist();
    return fallback;
  }

  /// 为指定课程手动设置新颜色（严格限定在 Material UI 19 种颜色的 700 色阶）
  /// 
  /// 如果新颜色已被其他课程占用，两者自动对调（swap），始终保证无课程颜色重复。
  static Future<void> setCourseColor(String courseName, Color newColor) async {
    final trimmed = courseName.trim();
    if (trimmed.isEmpty) return;

    final targetARGB = newColor.toARGB32();

    // 校验新颜色是否属于允许的 700 色阶色板
    final isValidColor = selectablePalette.any((c) => c.toARGB32() == targetARGB);
    if (!isValidColor) {
      throw ArgumentError('所选颜色不在 Material UI 700 候选色板中');
    }

    // 检测是否有其他课程占用了目标颜色
    String? conflictCourse;
    for (final entry in _assignedColors.entries) {
      if (entry.key != trimmed && entry.value.toARGB32() == targetARGB) {
        conflictCourse = entry.key;
        break;
      }
    }

    final oldColor = _assignedColors[trimmed] ?? getColorForCourse(trimmed);

    _assignedColors[trimmed] = newColor;

    if (conflictCourse != null) {
      // 对调：让冲突课程接管当前课程的原颜色
      _assignedColors[conflictCourse] = oldColor;
    }

    await _persist();
    CloudBackupManager.instance.markDirty();
  }

  /// 重新从 SharedPreferences 加载颜色配置（备份恢复或外部变更后调用）
  static Future<void> reload() async {
    _assignedColors.clear();
    _initialized = false;
    _initFuture = null;
    await init();
  }

  /// 查找当前正在使用指定颜色的课程名称（若有）
  static String? getCourseUsingColor(Color color, {String? excludeCourse}) {
    final targetARGB = color.toARGB32();
    final excludeTrimmed = excludeCourse?.trim();
    for (final entry in _assignedColors.entries) {
      if (excludeTrimmed != null && entry.key == excludeTrimmed) continue;
      if (entry.value.toARGB32() == targetARGB) {
        return entry.key;
      }
    }
    return null;
  }

  /// 仅供测试时清理状态
  @visibleForTesting
  static void resetForTesting() {
    _assignedColors.clear();
    _initialized = false;
    _initFuture = null;
  }
}
