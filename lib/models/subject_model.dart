class SubjectModel {
  final String code;
  final String name;
  final String teacherId;
  final String teacherName;
  final String department;
  final String class_;
  final String section;

  SubjectModel({
    required this.code,
    required this.name,
    required this.teacherId,
    required this.teacherName,
    required this.department,
    required this.class_,
    required this.section,
  });

  factory SubjectModel.fromMap(Map<String, dynamic> map) {
    return SubjectModel(
      code: map['code'] ?? '',
      name: map['name'] ?? '',
      teacherId: map['teacherId'] ?? '',
      teacherName: map['teacherName'] ?? '',
      department: map['department'] ?? '',
      class_: map['class'] ?? '',
      section: map['section'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'code': code,
      'name': name,
      'teacherId': teacherId,
      'teacherName': teacherName,
      'department': department,
      'class': class_,
      'section': section,
    };
  }
}