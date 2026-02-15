import 'package:flutter/material.dart';
import '../../services/database_service.dart';
import '../../models/user_model.dart';
import '../../models/subject_model.dart';

class HodAllocateSubjectScreen extends StatefulWidget {
  const HodAllocateSubjectScreen({Key? key}) : super(key: key);

  @override
  State<HodAllocateSubjectScreen> createState() => _HodAllocateSubjectScreenState();
}

class _HodAllocateSubjectScreenState extends State<HodAllocateSubjectScreen> {
  final _formKey = GlobalKey<FormState>();
  final _codeController = TextEditingController();
  final _nameController = TextEditingController();
  final _databaseService = DatabaseService();

  List<UserModel> _teachers = [];
  UserModel? _selectedTeacher;
  String _selectedClass = 'FE';
  String _selectedSection = 'A';
  String _selectedDepartment = 'Computer';
  bool _isLoading = true;
  bool _isSaving = false;

  final List<String> _classes = ['FE', 'SE', 'TE', 'BE'];
  final List<String> _sections = ['A', 'B', 'C', 'D'];
  final List<String> _departments = ['Computer', 'IT', 'Electronics', 'Mechanical', 'Civil'];

  @override
  void initState() {
    super.initState();
    _loadTeachers();
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
        const SnackBar(content: Text('Please fill all fields')),
      );
      return;
    }

    setState(() => _isSaving = true);

    final subject = SubjectModel(
      code: _codeController.text.trim(),
      name: _nameController.text.trim(),
      teacherId: _selectedTeacher!.uid,
      teacherName: _selectedTeacher!.name,
      department: _selectedDepartment,
      class_: _selectedClass,
      section: _selectedSection,
    );

    bool success = await _databaseService.allocateSubject(subject);

    setState(() => _isSaving = false);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success ? 'Subject allocated successfully!' : 'Failed to allocate'),
          backgroundColor: success ? Colors.green : Colors.red,
        ),
      );

      if (success) {
        Navigator.pop(context);
      }
    }
  }

  @override
  void dispose() {
    _codeController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
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
              TextFormField(
                controller: _codeController,
                textCapitalization: TextCapitalization.characters,
                decoration: InputDecoration(
                  labelText: 'Subject Code',
                  hintText: 'e.g., CS101',
                  prefixIcon: const Icon(Icons.code),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter subject code';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: 'Subject Name',
                  hintText: 'e.g., Data Structures',
                  prefixIcon: const Icon(Icons.book),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter subject name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _selectedDepartment,
                decoration: InputDecoration(
                  labelText: 'Department',
                  prefixIcon: const Icon(Icons.school),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                items: _departments.map((dept) {
                  return DropdownMenuItem(value: dept, child: Text(dept));
                }).toList(),
                onChanged: (value) {
                  setState(() => _selectedDepartment = value!);
                },
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _selectedClass,
                      decoration: InputDecoration(
                        labelText: 'Class',
                        prefixIcon: const Icon(Icons.class_),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      items: _classes.map((cls) {
                        return DropdownMenuItem(value: cls, child: Text(cls));
                      }).toList(),
                      onChanged: (value) {
                        setState(() => _selectedClass = value!);
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _selectedSection,
                      decoration: InputDecoration(
                        labelText: 'Section',
                        prefixIcon: const Icon(Icons.grid_view),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      items: _sections.map((sec) {
                        return DropdownMenuItem(value: sec, child: Text(sec));
                      }).toList(),
                      onChanged: (value) {
                        setState(() => _selectedSection = value!);
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<UserModel>(
                value: _selectedTeacher,
                decoration: InputDecoration(
                  labelText: 'Assign Teacher',
                  prefixIcon: const Icon(Icons.person),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                items: _teachers.map((teacher) {
                  return DropdownMenuItem(
                    value: teacher,
                    child: Text(teacher.name),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() => _selectedTeacher = value);
                },
                validator: (value) {
                  if (value == null) {
                    return 'Please select a teacher';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 32),
              SizedBox(
                height: 56,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _allocateSubject,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.purple.shade700,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isSaving
                      ? const SizedBox(
                          height: 24,
                          width: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          'Allocate Subject',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}