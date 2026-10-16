import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
/// 遵循 https://materialui.co/colors 规范，精选高对比度颜色（在白色文字下清晰可见），
/// 并始终保证同一个课表中各门课程的颜色互不相同。
class CourseColorUtils {
  static const String _prefsKey = 'custom_course_colors';
  static final Map<String, Color> _assignedColors = {};
  static bool _initialized = false;
  static Future<void>? _initFuture;

  /// 来自 https://materialui.co/colors 中在白色文字下对比度清晰（CR >= 3.5）的颜色项
  static const List<MaterialColorItem> materialColorItems = [
    // --- Red ---
    MaterialColorItem(family: 'Red', shade: '500', color: Color(0xFFF44336)),
    MaterialColorItem(family: 'Red', shade: '600', color: Color(0xFFE53935)),
    MaterialColorItem(family: 'Red', shade: '700', color: Color(0xFFD32F2F)),
    MaterialColorItem(family: 'Red', shade: '800', color: Color(0xFFC62828)),
    MaterialColorItem(family: 'Red', shade: '900', color: Color(0xFFB71C1C)),
    MaterialColorItem(family: 'Red', shade: 'A400', color: Color(0xFFFF1744)),
    MaterialColorItem(family: 'Red', shade: 'A700', color: Color(0xFFD50000)),

    // --- Pink ---
    MaterialColorItem(family: 'Pink', shade: '500', color: Color(0xFFE91E63)),
    MaterialColorItem(family: 'Pink', shade: '600', color: Color(0xFFD81B60)),
    MaterialColorItem(family: 'Pink', shade: '700', color: Color(0xFFC2185B)),
    MaterialColorItem(family: 'Pink', shade: '800', color: Color(0xFFAD1457)),
    MaterialColorItem(family: 'Pink', shade: '900', color: Color(0xFF880E4F)),
    MaterialColorItem(family: 'Pink', shade: 'A400', color: Color(0xFFF50057)),
    MaterialColorItem(family: 'Pink', shade: 'A700', color: Color(0xFFC51162)),

    // --- Purple ---
    MaterialColorItem(family: 'Purple', shade: '500', color: Color(0xFF9C27B0)),
    MaterialColorItem(family: 'Purple', shade: '600', color: Color(0xFF8E24AA)),
    MaterialColorItem(family: 'Purple', shade: '700', color: Color(0xFF7B1FA2)),
    MaterialColorItem(family: 'Purple', shade: '800', color: Color(0xFF6A1B9A)),
    MaterialColorItem(family: 'Purple', shade: '900', color: Color(0xFF4A148C)),
    MaterialColorItem(family: 'Purple', shade: 'A400', color: Color(0xFFD500F9)),
    MaterialColorItem(family: 'Purple', shade: 'A700', color: Color(0xFFAA00FF)),

    // --- Deep Purple ---
    MaterialColorItem(family: 'Deep Purple', shade: '500', color: Color(0xFF673AB7)),
    MaterialColorItem(family: 'Deep Purple', shade: '600', color: Color(0xFF5E35B1)),
    MaterialColorItem(family: 'Deep Purple', shade: '700', color: Color(0xFF512DA8)),
    MaterialColorItem(family: 'Deep Purple', shade: '800', color: Color(0xFF4527A0)),
    MaterialColorItem(family: 'Deep Purple', shade: '900', color: Color(0xFF311B92)),
    MaterialColorItem(family: 'Deep Purple', shade: 'A200', color: Color(0xFF7C4DFF)),
    MaterialColorItem(family: 'Deep Purple', shade: 'A400', color: Color(0xFF651FFF)),
    MaterialColorItem(family: 'Deep Purple', shade: 'A700', color: Color(0xFF6200EA)),

    // --- Indigo ---
    MaterialColorItem(family: 'Indigo', shade: '500', color: Color(0xFF3F51B5)),
    MaterialColorItem(family: 'Indigo', shade: '600', color: Color(0xFF3949AB)),
    MaterialColorItem(family: 'Indigo', shade: '700', color: Color(0xFF303F9F)),
    MaterialColorItem(family: 'Indigo', shade: '800', color: Color(0xFF283593)),
    MaterialColorItem(family: 'Indigo', shade: '900', color: Color(0xFF1A237E)),
    MaterialColorItem(family: 'Indigo', shade: 'A400', color: Color(0xFF3D5AFE)),
    MaterialColorItem(family: 'Indigo', shade: 'A700', color: Color(0xFF304FFE)),

    // --- Blue ---
    MaterialColorItem(family: 'Blue', shade: '600', color: Color(0xFF1E88E5)),
    MaterialColorItem(family: 'Blue', shade: '700', color: Color(0xFF1976D2)),
    MaterialColorItem(family: 'Blue', shade: '800', color: Color(0xFF1565C0)),
    MaterialColorItem(family: 'Blue', shade: '900', color: Color(0xFF0D47A1)),
    MaterialColorItem(family: 'Blue', shade: 'A400', color: Color(0xFF2979FF)),
    MaterialColorItem(family: 'Blue', shade: 'A700', color: Color(0xFF2962FF)),

    // --- Light Blue ---
    MaterialColorItem(family: 'Light Blue', shade: '700', color: Color(0xFF0288D1)),
    MaterialColorItem(family: 'Light Blue', shade: '800', color: Color(0xFF0277BD)),
    MaterialColorItem(family: 'Light Blue', shade: '900', color: Color(0xFF01579B)),
    MaterialColorItem(family: 'Light Blue', shade: 'A700', color: Color(0xFF0091EA)),

    // --- Cyan ---
    MaterialColorItem(family: 'Cyan', shade: '700', color: Color(0xFF0097A7)),
    MaterialColorItem(family: 'Cyan', shade: '800', color: Color(0xFF00838F)),
    MaterialColorItem(family: 'Cyan', shade: '900', color: Color(0xFF006064)),

    // --- Teal ---
    MaterialColorItem(family: 'Teal', shade: '500', color: Color(0xFF009688)),
    MaterialColorItem(family: 'Teal', shade: '600', color: Color(0xFF00897B)),
    MaterialColorItem(family: 'Teal', shade: '700', color: Color(0xFF00796B)),
    MaterialColorItem(family: 'Teal', shade: '800', color: Color(0xFF00695C)),
    MaterialColorItem(family: 'Teal', shade: '900', color: Color(0xFF004D40)),

    // --- Green ---
    MaterialColorItem(family: 'Green', shade: '700', color: Color(0xFF388E3C)),
    MaterialColorItem(family: 'Green', shade: '800', color: Color(0xFF2E7D32)),
    MaterialColorItem(family: 'Green', shade: '900', color: Color(0xFF1B5E20)),

    // --- Light Green ---
    MaterialColorItem(family: 'Light Green', shade: '800', color: Color(0xFF558B2F)),
    MaterialColorItem(family: 'Light Green', shade: '900', color: Color(0xFF33691E)),

    // --- Lime ---
    MaterialColorItem(family: 'Lime', shade: '900', color: Color(0xFF827717)),

    // --- Orange ---
    MaterialColorItem(family: 'Orange', shade: '900', color: Color(0xFFE65100)),

    // --- Deep Orange ---
    MaterialColorItem(family: 'Deep Orange', shade: '600', color: Color(0xFFF4511E)),
    MaterialColorItem(family: 'Deep Orange', shade: '700', color: Color(0xFFE64A19)),
    MaterialColorItem(family: 'Deep Orange', shade: '800', color: Color(0xFFD84315)),
    MaterialColorItem(family: 'Deep Orange', shade: '900', color: Color(0xFFBF360C)),
    MaterialColorItem(family: 'Deep Orange', shade: 'A700', color: Color(0xFFDD2C00)),

    // --- Brown ---
    MaterialColorItem(family: 'Brown', shade: '500', color: Color(0xFF795548)),
    MaterialColorItem(family: 'Brown', shade: '600', color: Color(0xFF6D4C41)),
    MaterialColorItem(family: 'Brown', shade: '700', color: Color(0xFF5D4037)),
    MaterialColorItem(family: 'Brown', shade: '800', color: Color(0xFF4E342E)),
    MaterialColorItem(family: 'Brown', shade: '900', color: Color(0xFF3E2723)),

    // --- Grey ---
    MaterialColorItem(family: 'Grey', shade: '600', color: Color(0xFF757575)),
    MaterialColorItem(family: 'Grey', shade: '700', color: Color(0xFF616161)),
    MaterialColorItem(family: 'Grey', shade: '800', color: Color(0xFF424242)),
    MaterialColorItem(family: 'Grey', shade: '900', color: Color(0xFF212121)),

    // --- Blue Grey ---
    MaterialColorItem(family: 'Blue Grey', shade: '500', color: Color(0xFF607D8B)),
    MaterialColorItem(family: 'Blue Grey', shade: '600', color: Color(0xFF546E7A)),
    MaterialColorItem(family: 'Blue Grey', shade: '700', color: Color(0xFF455A64)),
    MaterialColorItem(family: 'Blue Grey', shade: '800', color: Color(0xFF37474F)),
    MaterialColorItem(family: 'Blue Grey', shade: '900', color: Color(0xFF263238)),
  ];

  /// 供选取的全部颜色列表
  static List<Color> get selectablePalette =>
      materialColorItems.map((item) => item.color).toList();

  /// 默认按不同色系交替轮换的推荐排序（确保相邻课程视觉反差鲜明）
  static final List<Color> defaultPaletteOrder = _buildDefaultOrder();

  static List<Color> _buildDefaultOrder() {
    // 优先从不同色系中各选出 1~2 个最经典的大节高饱和度色
    const priorityColors = [
      Color(0xFF3949AB), // Indigo 600
      Color(0xFF00897B), // Teal 600
      Color(0xFFF4511E), // Deep Orange 600
      Color(0xFF8E24AA), // Purple 600
      Color(0xFF1976D2), // Blue 700
      Color(0xFF388E3C), // Green 700
      Color(0xFFD81B60), // Pink 600
      Color(0xFF5E35B1), // Deep Purple 600
      Color(0xFF0097A7), // Cyan 700
      Color(0xFFE53935), // Red 600
      Color(0xFF0288D1), // Light Blue 700
      Color(0xFF546E7A), // Blue Grey 600
      Color(0xFF6D4C41), // Brown 600
      Color(0xFF558B2F), // Light Green 800
      Color(0xFFE65100), // Orange 900
      Color(0xFF827717), // Lime 900
      Color(0xFF616161), // Grey 700
      Color(0xFF283593), // Indigo 800
      Color(0xFF00695C), // Teal 800
      Color(0xFFD84315), // Deep Orange 800
      Color(0xFF6A1B9A), // Purple 800
      Color(0xFF1565C0), // Blue 800
      Color(0xFF2E7D32), // Green 800
      Color(0xFFC2185B), // Pink 700
      Color(0xFF512DA8), // Deep Purple 700
      Color(0xFF00838F), // Cyan 800
      Color(0xFFD32F2F), // Red 700
      Color(0xFF0277BD), // Light Blue 800
      Color(0xFF455A64), // Blue Grey 700
      Color(0xFF5D4037), // Brown 700
    ];

    final result = <Color>[...priorityColors];
    final addedValues = priorityColors.map((c) => c.toARGB32()).toSet();

    for (final item in materialColorItems) {
      if (!addedValues.contains(item.color.toARGB32())) {
        result.add(item.color);
        addedValues.add(item.color.toARGB32());
      }
    }
    return result;
  }

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
        for (final entry in decoded.entries) {
          if (entry.value is int) {
            _assignedColors[entry.key] = Color(entry.value as int);
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

    final usedColors = <int>{};
    final coursesNeedingAssignment = <String>[];

    // 1. 保留已有且互不重复的颜色
    for (final name in validNames) {
      final existingColor = _assignedColors[name];
      if (existingColor != null &&
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
        // 极端兜底（课程数超过 70 门）
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
    if (existing != null) return existing;

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

  /// 为指定课程手动设置新颜色（严格限定在 Material UI 允许的色板中）
  /// 
  /// 如果新颜色已被其他课程占用，两者自动对调（swap），始终保证无课程颜色重复。
  static Future<void> setCourseColor(String courseName, Color newColor) async {
    final trimmed = courseName.trim();
    if (trimmed.isEmpty) return;

    final targetARGB = newColor.toARGB32();

    // 校验新颜色是否属于允许的色板
    final isValidColor = selectablePalette.any((c) => c.toARGB32() == targetARGB);
    if (!isValidColor) {
      throw ArgumentError('所选颜色不在 Material UI 规定候选色板中');
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
