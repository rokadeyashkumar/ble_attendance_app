class TimetableEntry {
  final String id;
  final String subjectCode;
  final String subjectName;
  final String teacherId;
  final String teacherName;
  final String class_;
  final String section;
  final String department;
  final String day; // Mon, Tue, Wed, Thu, Fri
  final String startTime;
  final String endTime;
  final String room;

  TimetableEntry({
    required this.id,
    required this.subjectCode,
    required this.subjectName,
    required this.teacherId,
    required this.teacherName,
    required this.class_,
    required this.section,
    required this.department,
    required this.day,
    required this.startTime,
    required this.endTime,
    required this.room,
  });

  factory TimetableEntry.fromMap(Map<String, dynamic> map, String id) {
    return TimetableEntry(
      id: id,
      subjectCode: map['subjectCode'] ?? '',
      subjectName: map['subjectName'] ?? '',
      teacherId: map['teacherId'] ?? '',
      teacherName: map['teacherName'] ?? '',
      class_: map['class'] ?? '',
      section: map['section'] ?? '',
      department: map['department'] ?? '',
      day: map['day'] ?? 'Mon',
      startTime: map['startTime'] ?? '9:00 AM',
      endTime: map['endTime'] ?? '10:00 AM',
      room: map['room'] ?? 'Room 101',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'subjectCode': subjectCode,
      'subjectName': subjectName,
      'teacherId': teacherId,
      'teacherName': teacherName,
      'class': class_,
      'section': section,
      'department': department,
      'day': day,
      'startTime': startTime,
      'endTime': endTime,
      'room': room,
    };
  }
}