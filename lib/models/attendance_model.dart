import 'package:cloud_firestore/cloud_firestore.dart';

class AttendanceModel {
  final String id;
  final String studentRollNo;
  final String studentName;
  final String subjectCode;
  final String subjectName;
  final String teacherId;
  final DateTime dateTime;
  final String status; // 'present', 'absent', 'late'
  final String markedBy; // 'bluetooth' or 'manual'

  AttendanceModel({
    required this.id,
    required this.studentRollNo,
    required this.studentName,
    required this.subjectCode,
    required this.subjectName,
    required this.teacherId,
    required this.dateTime,
    required this.status,
    required this.markedBy,
  });

  factory AttendanceModel.fromMap(Map<String, dynamic> map, String id) {
    return AttendanceModel(
      id: id,
      studentRollNo: map['studentRollNo'] ?? '',
      studentName: map['studentName'] ?? '',
      subjectCode: map['subjectCode'] ?? '',
      subjectName: map['subjectName'] ?? '',
      teacherId: map['teacherId'] ?? '',
      dateTime: (map['dateTime'] as Timestamp).toDate(),
      status: map['status'] ?? 'absent',
      markedBy: map['markedBy'] ?? 'manual',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'studentRollNo': studentRollNo,
      'studentName': studentName,
      'subjectCode': subjectCode,
      'subjectName': subjectName,
      'teacherId': teacherId,
      'dateTime': Timestamp.fromDate(dateTime),
      'status': status,
      'markedBy': markedBy,
    };
  }
}