import 'package:flutter/material.dart';
import '../../models/subject_model.dart';
import '../../models/user_model.dart';
import '../../services/auth_service.dart';
import '../../services/database_service.dart';
import 'teacher_attendance_table_screen.dart';

class TeacherRecordScreen extends StatefulWidget {
  const TeacherRecordScreen({Key? key}) : super(key: key);

  @override
  State<TeacherRecordScreen> createState() => _TeacherRecordScreenState();
}

class _TeacherRecordScreenState extends State<TeacherRecordScreen> {
  final _authService = AuthService();
  final _dbService = DatabaseService();

  List<SubjectModel> _subjects = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSubjects();
  }

  Future<void> _loadSubjects() async {
    final UserModel? user = await _authService.getCurrentUserData();
    if (user == null) return;

    final subjects = await _dbService.getTeacherSubjects(user.uid);
    setState(() {
      _subjects = subjects;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Attendance Records'),
        backgroundColor: Colors.orange.shade700,
        foregroundColor: Colors.white,
        automaticallyImplyLeading: false,
      ),
      backgroundColor: Colors.grey.shade100,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _subjects.isEmpty
              ? _buildEmpty()
              : _buildSubjectList(),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.book_outlined, size: 72, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          Text(
            'No subjects allocated yet',
            style: TextStyle(fontSize: 18, color: Colors.grey.shade500),
          ),
          const SizedBox(height: 8),
          Text(
            'Contact your HOD to allocate subjects',
            style: TextStyle(fontSize: 14, color: Colors.grey.shade400),
          ),
        ],
      ),
    );
  }

  Widget _buildSubjectList() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _subjects.length,
      itemBuilder: (context, index) {
        final subject = _subjects[index];
        return _SubjectCard(
          subject: subject,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => TeacherAttendanceTableScreen(subject: subject),
              ),
            );
          },
        );
      },
    );
  }
}

class _SubjectCard extends StatelessWidget {
  final SubjectModel subject;
  final VoidCallback onTap;

  const _SubjectCard({required this.subject, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            // Left accent bar
            Container(
              width: 6,
              height: 90,
              decoration: BoxDecoration(
                color: Colors.orange.shade700,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  bottomLeft: Radius.circular(16),
                ),
              ),
            ),
            // Icon
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.menu_book_rounded,
                    color: Colors.orange.shade700, size: 26),
              ),
            ),
            // Text
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      subject.name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        _Chip(label: subject.code, color: Colors.orange.shade700),
                        const SizedBox(width: 8),
                        _Chip(label: subject.class_, color: Colors.blue.shade700),
                        const SizedBox(width: 8),
                        _Chip(
                            label: 'Sec ${subject.section}',
                            color: Colors.green.shade700),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Icon(Icons.arrow_forward_ios_rounded,
                  size: 16, color: Colors.grey.shade400),
            ),
          ],
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final Color color;

  const _Chip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}