import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';
import '../models/subject_model.dart';
import '../models/attendance_model.dart';

class DatabaseService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // ── Students ────────────────────────────────────────────────────────

  // Get students by class (class already contains section e.g. "CSE-6B")
  // Only filter by 'class' — avoids needing a composite index
  Future<List<UserModel>> getStudentsByClass(String class_, String section) async {
    try {
      print('🔍 Fetching students for class: $class_');

      QuerySnapshot snapshot = await _firestore
          .collection('users')
          .where('role', isEqualTo: 'student')
          .where('class', isEqualTo: class_) // e.g. "CSE-6B" — section is already encoded
          .get();

      final students = snapshot.docs
          .map((doc) => UserModel.fromMap(doc.data() as Map<String, dynamic>))
          .toList();

      print('✅ Found ${students.length} students for $class_');
      return students;
    } catch (e) {
      print('❌ Error fetching students: $e');
      return [];
    }
  }

  // ── Subjects ─────────────────────────────────────────────────────────

  // Get subjects allocated to a teacher
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
      print('❌ Error fetching subjects: $e');
      return [];
    }
  }

  // Allocate subject — doc ID includes class so same code for 6A and 6B don't overwrite each other
  Future<bool> allocateSubject(SubjectModel subject) async {
    try {
      // e.g. "CSE601-CSE-6B" — unique per subject per class
      final docId = '${subject.code}-${subject.class_}';
      await _firestore.collection('subjects').doc(docId).set(subject.toMap());
      print('✅ Subject allocated: $docId');
      return true;
    } catch (e) {
      print('❌ Error allocating subject: $e');
      return false;
    }
  }

  // Get all subjects (HOD view)
  Future<List<SubjectModel>> getAllSubjects() async {
    try {
      QuerySnapshot snapshot = await _firestore.collection('subjects').get();
      return snapshot.docs
          .map((doc) => SubjectModel.fromMap(doc.data() as Map<String, dynamic>))
          .toList();
    } catch (e) {
      print('❌ Error fetching all subjects: $e');
      return [];
    }
  }

  // ── Attendance ────────────────────────────────────────────────────────

  // Mark attendance for a student
  Future<bool> markAttendance(AttendanceModel attendance) async {
    try {
      await _firestore.collection('attendance').add(attendance.toMap());
      return true;
    } catch (e) {
      print('❌ Error marking attendance: $e');
      return false;
    }
  }

  // Get attendance history for a student
  Future<List<AttendanceModel>> getStudentAttendance(String rollNo) async {
    try {
      QuerySnapshot snapshot = await _firestore
          .collection('attendance')
          .where('studentRollNo', isEqualTo: rollNo)
          .orderBy('dateTime', descending: true)
          .limit(20)
          .get();

      return snapshot.docs
          .map((doc) => AttendanceModel.fromMap(
              doc.data() as Map<String, dynamic>, doc.id))
          .toList();
    } catch (e) {
      print('❌ Error fetching attendance: $e');
      return [];
    }
  }

  // ── Teachers / HOD ────────────────────────────────────────────────────

  // Get all teachers
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
      print('❌ Error fetching teachers: $e');
      return [];
    }
  }
}