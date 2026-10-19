class CourseModel {
  final String id;
  final String name;
  final String teacher;
  final String classroom;
  final String weeks;        // 例如: "1-16(周)"
  final String periods;      // 例如: "01-02"
  final int dayOfWeek;       // 1-7 (周一到周日)
  final int startPeriod;     // 起始节次
  final int endPeriod;       // 结束节次
  final bool _isCustom;

  /// 是否为自定义课程（手动添加课程）
  bool get isCustom => _isCustom || id.startsWith('custom_');
  
  const CourseModel({
    required this.id,
    required this.name,
    required this.teacher,
    required this.classroom,
    required this.weeks,
    required this.periods,
    required this.dayOfWeek,
    required this.startPeriod,
    required this.endPeriod,
    bool isCustom = false,
  }) : _isCustom = isCustom;
  
  factory CourseModel.fromJson(Map<String, dynamic> json) {
    final id = json['id'] as String;
    return CourseModel(
      id: id,
      name: json['name'] as String,
      teacher: json['teacher'] as String,
      classroom: json['classroom'] as String,
      weeks: json['weeks'] as String,
      periods: json['periods'] as String,
      dayOfWeek: json['dayOfWeek'] as int,
      startPeriod: json['startPeriod'] as int,
      endPeriod: json['endPeriod'] as int,
      isCustom: (json['isCustom'] as bool?) ?? id.startsWith('custom_'),
    );
  }
  
  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'teacher': teacher,
    'classroom': classroom,
    'weeks': weeks,
    'periods': periods,
    'dayOfWeek': dayOfWeek,
    'startPeriod': startPeriod,
    'endPeriod': endPeriod,
    'isCustom': isCustom,
  };
  
  CourseModel copyWith({
    String? id,
    String? name,
    String? teacher,
    String? classroom,
    String? weeks,
    String? periods,
    int? dayOfWeek,
    int? startPeriod,
    int? endPeriod,
    bool? isCustom,
  }) {
    return CourseModel(
      id: id ?? this.id,
      name: name ?? this.name,
      teacher: teacher ?? this.teacher,
      classroom: classroom ?? this.classroom,
      weeks: weeks ?? this.weeks,
      periods: periods ?? this.periods,
      dayOfWeek: dayOfWeek ?? this.dayOfWeek,
      startPeriod: startPeriod ?? this.startPeriod,
      endPeriod: endPeriod ?? this.endPeriod,
      isCustom: isCustom ?? this.isCustom,
    );
  }

  @override
  String toString() {
    return 'CourseModel(name: $name, teacher: $teacher, classroom: $classroom, '
        'day: $dayOfWeek, periods: $startPeriod-$endPeriod, weeks: $weeks)';
  }
}
