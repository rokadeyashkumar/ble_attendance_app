import 'package:cloud_firestore/cloud_firestore.dart';

class AttendanceModel {
  final String id;
  final String studentRollNo;
  final String studentName;
  final String subjectCode;
  final String subjectName;
  final String teacherId;
  final String class_; // e.g. "CSE-6B" — needed to query by class in table
  final DateTime dateTime;
  final String status; // 'present' or 'absent'
  final String markedBy; // 'bluetooth', 'manual', or 'auto_absent'

  AttendanceModel({
    required this.id,
    required this.studentRollNo,
    required this.studentName,
    required this.subjectCode,
    required this.subjectName,
    required this.teacherId,
    required this.class_,
    required this.dateTime,
    required this.status,
    required this.markedBy,
  });

  factory AttendanceModel.fromMap(Map<String, dynamic> map, String id) {
    return AttendanceModel(
      id: id,
      studentRollNo: map['studentRollNo'] ?? '',
      studentName:   map['studentName'] ?? '',
      subjectCode:   map['subjectCode'] ?? '',
      subjectName:   map['subjectName'] ?? '',
      teacherId:     map['teacherId'] ?? '',
      class_:        map['class'] ?? '',
      dateTime:      (map['dateTime'] as Timestamp).toDate(),
      status:        map['status'] ?? 'absent',
      markedBy:      map['markedBy'] ?? 'manual',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'studentRollNo': studentRollNo,
      'studentName':   studentName,
      'subjectCode':   subjectCode,
      'subjectName':   subjectName,
      'teacherId':     teacherId,
      'class':         class_,
      'dateTime':      Timestamp.fromDate(dateTime),
      'status':        status,
      'markedBy':      markedBy,
    };
  }

  // Creates a copy with updated fields
  AttendanceModel copyWith({
    String? id,
    String? status,
    String? markedBy,
  }) {
    return AttendanceModel(
      id:            id ?? this.id,
      studentRollNo: studentRollNo,
      studentName:   studentName,
      subjectCode:   subjectCode,
      subjectName:   subjectName,
      teacherId:     teacherId,
      class_:        class_,
      dateTime:      dateTime,
      status:        status ?? this.status,
      markedBy:      markedBy ?? this.markedBy,
    );
  }
}