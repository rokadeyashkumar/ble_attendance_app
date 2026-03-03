import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';
import '../models/subject_model.dart';
import '../models/attendance_model.dart';

class DatabaseService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // ── Students ────────────────────────────────────────────────────────

  Future<List<UserModel>> getStudentsByClass(String class_, String section) async {
    try {
      print('🔍 Fetching students for class: $class_');
      QuerySnapshot snapshot = await _firestore
          .collection('users')
          .where('role', isEqualTo: 'student')
          .where('class', isEqualTo: class_)
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

  // ── Subjects ──────────────────────────────────────────────────────────

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

  Future<bool> allocateSubject(SubjectModel subject) async {
    try {
      final docId = '${subject.code}-${subject.class_}';
      await _firestore.collection('subjects').doc(docId).set(subject.toMap());
      print('✅ Subject allocated: $docId');
      return true;
    } catch (e) {
      print('❌ Error allocating subject: $e');
      return false;
    }
  }

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

  Future<bool> markAttendance(AttendanceModel attendance) async {
    try {
      await _firestore.collection('attendance').add(attendance.toMap());
      return true;
    } catch (e) {
      print('❌ Error marking attendance: $e');
      return false;
    }
  }

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
      print('❌ Error fetching attendance: $e');
      return [];
    }
  }

  // Get all attendance records for a subject + class (for the table view)
  // Returns Map<studentRollNo, Map<dateKey, AttendanceModel>>
  // dateKey format: "yyyy-MM-dd"
  Future<Map<String, Map<String, AttendanceModel>>> getAttendanceForSubjectClass(
    String subjectCode,
    String class_,
  ) async {
    try {
      print('🔍 Fetching attendance for $subjectCode / $class_');

      QuerySnapshot snapshot = await _firestore
          .collection('attendance')
          .where('subjectCode', isEqualTo: subjectCode)
          .where('class', isEqualTo: class_)
          .get();

      // Build nested map: rollNo → { "2025-02-23" → AttendanceModel }
      final Map<String, Map<String, AttendanceModel>> result = {};

      for (final doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final model = AttendanceModel.fromMap(data, doc.id);
        final rollNo = model.studentRollNo;
        final dateKey = _dateKey(model.dateTime);

        result.putIfAbsent(rollNo, () => {});
        result[rollNo]![dateKey] = model;
      }

      print('✅ Attendance records loaded: ${snapshot.docs.length}');
      return result;
    } catch (e) {
      print('❌ Error fetching attendance table: $e');
      return {};
    }
  }

  // Batch save attendance — used by the table Save button
  // Deletes existing records for given rollNo+subjectCode+date and writes fresh ones
  Future<bool> saveAttendanceBatch(List<AttendanceModel> records) async {
    try {
      final WriteBatch batch = _firestore.batch();

      for (final record in records) {
        if (record.id.isNotEmpty) {
          // Update existing doc
          final ref = _firestore.collection('attendance').doc(record.id);
          batch.set(ref, record.toMap());
        } else {
          // New doc
          final ref = _firestore.collection('attendance').doc();
          batch.set(ref, record.toMap());
        }
      }

      await batch.commit();
      print('✅ Batch saved ${records.length} attendance records');
      return true;
    } catch (e) {
      print('❌ Error batch saving attendance: $e');
      return false;
    }
  }

  // Delete a specific attendance record by ID
  Future<bool> deleteAttendance(String docId) async {
    try {
      await _firestore.collection('attendance').doc(docId).delete();
      return true;
    } catch (e) {
      print('❌ Error deleting attendance: $e');
      return false;
    }
  }

  // ── Teachers / HOD ─────────────────────────────────────────────────────

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

  // ── Helpers ────────────────────────────────────────────────────────────

  String _dateKey(DateTime dt) =>
      '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
}