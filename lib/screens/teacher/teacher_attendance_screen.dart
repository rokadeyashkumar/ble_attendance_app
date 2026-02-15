import 'package:flutter/material.dart';
import '../../models/subject_model.dart';
import '../../models/user_model.dart';
import '../../models/attendance_model.dart';
import '../../services/ble_service.dart';
import '../../services/database_service.dart';
import '../../services/auth_service.dart';

class TeacherAttendanceScreen extends StatefulWidget {
  final SubjectModel subject;

  const TeacherAttendanceScreen({Key? key, required this.subject}) : super(key: key);

  @override
  State<TeacherAttendanceScreen> createState() => _TeacherAttendanceScreenState();
}

class _TeacherAttendanceScreenState extends State<TeacherAttendanceScreen> {
  final DatabaseService _databaseService = DatabaseService();
  final AuthService _authService = AuthService();
  
  List<UserModel> _students = [];
  Set<String> _presentStudents = {};
  Map<String, bool> _manualAttendance = {};
  bool _isScanning = false;
  bool _isLoading = true;
  String? _currentTeacherId;

  @override
  void initState() {
    super.initState();
    _loadStudents();
  }

  Future<void> _loadStudents() async {
    final user = await _authService.getCurrentUserData();
    final students = await _databaseService.getStudentsByClass(
      widget.subject.class_,
      widget.subject.section,
    );
    
    setState(() {
      _currentTeacherId = user?.uid;
      _students = students;
      _isLoading = false;
      // Initialize manual attendance map
      for (var student in students) {
        _manualAttendance[student.rollNo!] = false;
      }
    });
  }

  Future<void> _startBLEScanning() async {
    setState(() {
      _isScanning = true;
      _presentStudents.clear();
    });

    bool started = await BleService.startScanning((rollNo) {
      if (mounted) {
        setState(() {
          _presentStudents.add(rollNo);
        });
      }
    });

    if (!started && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to start scanning. Check permissions.')),
      );
      setState(() => _isScanning = false);
    }

    // Auto stop after 60 seconds
    Future.delayed(const Duration(seconds: 60), () async {
      if (_isScanning) {
        await BleService.stopScanning();
        if (mounted) {
          setState(() => _isScanning = false);
        }
      }
    });
  }

  Future<void> _stopScanning() async {
    await BleService.stopScanning();
    setState(() => _isScanning = false);
  }

  Future<void> _saveAttendance() async {
    if (_currentTeacherId == null) return;

    int savedCount = 0;
    
    // Save BLE detected attendance
    for (var student in _students) {
      if (_presentStudents.contains(student.rollNo)) {
        final attendance = AttendanceModel(
          id: '',
          studentRollNo: student.rollNo!,
          studentName: student.name,
          subjectCode: widget.subject.code,
          subjectName: widget.subject.name,
          teacherId: _currentTeacherId!,
          dateTime: DateTime.now(),
          status: 'present',
          markedBy: 'bluetooth',
        );
        
        bool success = await _databaseService.markAttendance(attendance);
        if (success) savedCount++;
      }
    }

    // Save manual attendance
    for (var entry in _manualAttendance.entries) {
      if (entry.value && !_presentStudents.contains(entry.key)) {
        final student = _students.firstWhere((s) => s.rollNo == entry.key);
        final attendance = AttendanceModel(
          id: '',
          studentRollNo: student.rollNo!,
          studentName: student.name,
          subjectCode: widget.subject.code,
          subjectName: widget.subject.name,
          teacherId: _currentTeacherId!,
          dateTime: DateTime.now(),
          status: 'present',
          markedBy: 'manual',
        );
        
        bool success = await _databaseService.markAttendance(attendance);
        if (success) savedCount++;
      }
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Attendance saved for $savedCount students'),
          backgroundColor: Colors.green,
        ),
      );
      
      // Reset
      setState(() {
        _presentStudents.clear();
        _manualAttendance.updateAll((key, value) => false);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    int totalPresent = _presentStudents.length + 
        _manualAttendance.values.where((v) => v).length;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.subject.name),
        backgroundColor: Colors.orange.shade700,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // Subject Info Card
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.orange.shade50,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${widget.subject.class_} - ${widget.subject.section}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Total Students: ${_students.length}',
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                  ],
                ),
                Column(
                  children: [
                    Text(
                      '$totalPresent',
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: Colors.green.shade700,
                      ),
                    ),
                    const Text('Present'),
                  ],
                ),
              ],
            ),
          ),

          // Control Buttons
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isScanning ? _stopScanning : _startBLEScanning,
                    icon: Icon(_isScanning ? Icons.stop : Icons.bluetooth_searching),
                    label: Text(_isScanning ? 'Stop Scanning' : 'Take Attendance'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _isScanning ? Colors.red : Colors.orange.shade700,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                if (totalPresent > 0) ...[
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: _saveAttendance,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green.shade700,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Icon(Icons.save),
                  ),
                ],
              ],
            ),
          ),

          if (_isScanning)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Scanning for students...',
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),

          const SizedBox(height: 8),

          // Students List
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _students.length,
              itemBuilder: (context, index) {
                final student = _students[index];
                final rollNo = student.rollNo!;
                final isBLEPresent = _presentStudents.contains(rollNo);
                final isManualPresent = _manualAttendance[rollNo] ?? false;
                final isPresent = isBLEPresent || isManualPresent;

                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: isPresent
                          ? Colors.green.shade100
                          : Colors.grey.shade100,
                      child: Icon(
                        Icons.person,
                        color: isPresent ? Colors.green.shade700 : Colors.grey,
                      ),
                    ),
                    title: Text(
                      student.name,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Roll No: $rollNo'),
                        if (isBLEPresent)
                          Text(
                            'Marked via Bluetooth',
                            style: TextStyle(
                              color: Colors.green.shade700,
                              fontSize: 12,
                            ),
                          ),
                      ],
                    ),
                    trailing: Checkbox(
                      value: isManualPresent,
                      onChanged: isBLEPresent
                          ? null
                          : (value) {
                              setState(() {
                                _manualAttendance[rollNo] = value ?? false;
                              });
                            },
                      activeColor: Colors.green.shade700,
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    if (_isScanning) {
      BleService.stopScanning();
    }
    super.dispose();
  }
}