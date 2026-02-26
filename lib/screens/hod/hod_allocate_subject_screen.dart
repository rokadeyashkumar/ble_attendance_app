import 'package:flutter/material.dart';
import '../../services/database_service.dart';
import '../../models/user_model.dart';
import '../../models/subject_model.dart';

class HodAllocateSubjectScreen extends StatefulWidget {
  const HodAllocateSubjectScreen({Key? key}) : super(key: key);

  @override
  State<HodAllocateSubjectScreen> createState() =>
      _HodAllocateSubjectScreenState();
}

class _HodAllocateSubjectScreenState
    extends State<HodAllocateSubjectScreen> {
  final _formKey = GlobalKey<FormState>();
  final _codeController = TextEditingController();
  final _nameController = TextEditingController();
  final _databaseService = DatabaseService();

  List<UserModel> _teachers = [];
  UserModel? _selectedTeacher;
  bool _isLoading = true;
  bool _isSaving = false;

  // Department abbreviation → full name (must match Firestore)
  final Map<String, String> _departmentMap = {
    'CSE': 'Computer Science And Engineering',
    'IT':  'Information Technology',
    'CIVIL': 'Civil Engineering',
    'ELECTRICAL': 'Electrical Engineering',
    'ME': 'Mechanical Engineering',
  };

  // Semester options (matches your 6th sem data, extend as needed)
  final List<String> _semesters = ['1', '2', '3', '4', '5', '6', '7', '8'];
  final List<String> _sections  = ['A', 'B', 'C', 'D'];

  String _selectedDeptCode = 'CSE';
  String _selectedSemester = '6';
  String _selectedSection  = 'A';

  // Computed class label e.g. "CSE-6A"
  String get _classLabel =>
      '$_selectedDeptCode-$_selectedSemester$_selectedSection';

  @override
  void initState() {
    super.initState();
    _loadTeachers();
  }

  @override
  void dispose() {
    _codeController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _loadTeachers() async {
    final teachers = await _databaseService.getAllTeachers();
    setState(() {
      _teachers = teachers;
      _isLoading = false;
    });
  }

  Future<void> _allocateSubject() async {
    if (!_formKey.currentState!.validate() || _selectedTeacher == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill all fields and select a teacher')),
      );
      return;
    }

    setState(() => _isSaving = true);

    final subject = SubjectModel(
      code: _codeController.text.trim().toUpperCase(),
      name: _nameController.text.trim(),
      teacherId: _selectedTeacher!.uid,
      teacherName: _selectedTeacher!.name,
      department: _departmentMap[_selectedDeptCode]!,
      class_: _classLabel,       // e.g. "CSE-6A"
      section: _selectedSection, // e.g. "A"
    );

    bool success = await _databaseService.allocateSubject(subject);

    setState(() => _isSaving = false);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success
              ? 'Subject allocated to $_classLabel successfully!'
              : 'Failed to allocate subject'),
          backgroundColor: success ? Colors.green : Colors.red,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      if (success) Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Allocate Subject'),
        backgroundColor: Colors.purple.shade700,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [

              // Live preview of class label
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.purple.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.purple.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.label_outline, color: Colors.purple.shade700),
                    const SizedBox(width: 12),
                    Text(
                      'Class Label: ',
                      style: TextStyle(color: Colors.purple.shade700),
                    ),
                    Text(
                      _classLabel,
                      style: TextStyle(
                        color: Colors.purple.shade700,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Subject Code
              TextFormField(
                controller: _codeController,
                textCapitalization: TextCapitalization.characters,
                decoration: _inputDecoration('Subject Code', 'e.g. CSE601', Icons.code),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Enter subject code' : null,
              ),
              const SizedBox(height: 16),

              // Subject Name
              TextFormField(
                controller: _nameController,
                decoration: _inputDecoration('Subject Name', 'e.g. Machine Learning', Icons.book),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Enter subject name' : null,
              ),
              const SizedBox(height: 16),

              // Department
              DropdownButtonFormField<String>(
                value: _selectedDeptCode,
                decoration: _inputDecoration('Department', '', Icons.school),
                items: _departmentMap.keys.map((code) {
                  return DropdownMenuItem(
                    value: code,
                    child: Text('$code — ${_departmentMap[code]}'),
                  );
                }).toList(),
                onChanged: (v) => setState(() => _selectedDeptCode = v!),
              ),
              const SizedBox(height: 16),

              // Semester + Section (side by side)
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _selectedSemester,
                      decoration: _inputDecoration('Semester', '', Icons.format_list_numbered),
                      items: _semesters
                          .map((s) => DropdownMenuItem(value: s, child: Text('Sem $s')))
                          .toList(),
                      onChanged: (v) => setState(() => _selectedSemester = v!),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _selectedSection,
                      decoration: _inputDecoration('Section', '', Icons.grid_view),
                      items: _sections
                          .map((s) => DropdownMenuItem(value: s, child: Text('Section $s')))
                          .toList(),
                      onChanged: (v) => setState(() => _selectedSection = v!),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Teacher
              DropdownButtonFormField<UserModel>(
                value: _selectedTeacher,
                decoration: _inputDecoration('Assign Teacher', '', Icons.person),
                isExpanded: true,
                items: _teachers.map((teacher) {
                  return DropdownMenuItem(
                    value: teacher,
                    child: Text(
                      '${teacher.name} (${teacher.employeeId ?? teacher.department ?? ''})',
                      overflow: TextOverflow.ellipsis,
                    ),
                  );
                }).toList(),
                onChanged: (v) => setState(() => _selectedTeacher = v),
                validator: (v) => v == null ? 'Please select a teacher' : null,
              ),
              const SizedBox(height: 32),

              // Allocate button
              SizedBox(
                height: 56,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _allocateSubject,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.purple.shade700,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _isSaving
                      ? const SizedBox(
                          height: 24,
                          width: 24,
                          child: CircularProgressIndicator(
                              strokeWidth: 2.5, color: Colors.white),
                        )
                      : const Text(
                          'Allocate Subject',
                          style: TextStyle(
                              fontSize: 18, fontWeight: FontWeight.w600),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String label, String hint, IconData icon) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: Icon(icon),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.purple.shade700, width: 2),
      ),
    );
  }
}