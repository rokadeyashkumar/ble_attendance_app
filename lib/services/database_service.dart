import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';
import '../models/subject_model.dart';
import '../models/attendance_model.dart';

class DatabaseService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Get students by class and section
  Future<List<UserModel>> getStudentsByClass(String class_, String section) async {
    try {
      QuerySnapshot snapshot = await _firestore
          .collection('users')
          .where('role', isEqualTo: 'student')
          .where('class', isEqualTo: class_)
          .where('section', isEqualTo: section)
          .get();

      return snapshot.docs
          .map((doc) => UserModel.fromMap(doc.data() as Map<String, dynamic>))
          .toList();
    } catch (e) {
      print('Error fetching students: $e');
      return [];
    }
  }

  // Get subjects allocated to teacher
  Future<List<SubjectModel>> getTeacherSubjects(String teacherId) async {
    try {
      QuerySnapshot snapshot = await _firestore
          .collection('subjects')
          .where('teacherId', isEqualTo: teacherId)
          .get();

      return snapshot.docs
          .map((doc) => SubjectModel.fromMap(doc.data() as Map<String, dynamic>))
          .toList();
    } catch (e) {
      print('Error fetching subjects: $e');
      return [];
    }
  }

  // Mark attendance
  Future<bool> markAttendance(AttendanceModel attendance) async {
    try {
      await _firestore.collection('attendance').add(attendance.toMap());
      return true;
    } catch (e) {
      print('Error marking attendance: $e');
      return false;
    }
  }

  // Get student attendance history
  Future<List<AttendanceModel>> getStudentAttendance(String rollNo) async {
    try {
      QuerySnapshot snapshot = await _firestore
          .collection('attendance')
          .where('studentRollNo', isEqualTo: rollNo)
          .orderBy('dateTime', descending: true)
          .limit(20)
          .get();

      return snapshot.docs
          .map((doc) =>
              AttendanceModel.fromMap(doc.data() as Map<String, dynamic>, doc.id))
          .toList();
    } catch (e) {
      print('Error fetching attendance: $e');
      return [];
    }
  }

  // Allocate subject to teacher (HOD function)
  Future<bool> allocateSubject(SubjectModel subject) async {
    try {
      await _firestore.collection('subjects').doc(subject.code).set(subject.toMap());
      return true;
    } catch (e) {
      print('Error allocating subject: $e');
      return false;
    }
  }

  // Get all subjects (HOD function)
  Future<List<SubjectModel>> getAllSubjects() async {
    try {
      QuerySnapshot snapshot = await _firestore.collection('subjects').get();
      return snapshot.docs
          .map((doc) => SubjectModel.fromMap(doc.data() as Map<String, dynamic>))
          .toList();
    } catch (e) {
      print('Error fetching all subjects: $e');
      return [];
    }
  }

  // Get all teachers (HOD function)
  Future<List<UserModel>> getAllTeachers() async {
    try {
      QuerySnapshot snapshot = await _firestore
          .collection('users')
          .where('role', isEqualTo: 'teacher')
          .get();

      return snapshot.docs
          .map((doc) => UserModel.fromMap(doc.data() as Map<String, dynamic>))
          .toList();
    } catch (e) {
      print('Error fetching teachers: $e');
      return [];
    }
  }
}