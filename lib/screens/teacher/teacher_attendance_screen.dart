import 'package:flutter/material.dart';
import '../../models/subject_model.dart';
import '../../models/user_model.dart';
import '../../models/attendance_model.dart';
import '../../services/ble_service.dart';
import '../../services/database_service.dart';
import '../../services/auth_service.dart';

class TeacherAttendanceScreen extends StatefulWidget {
  final SubjectModel subject;

  const TeacherAttendanceScreen({Key? key, required this.subject})
      : super(key: key);

  @override
  State<TeacherAttendanceScreen> createState() =>
      _TeacherAttendanceScreenState();
}

class _TeacherAttendanceScreenState extends State<TeacherAttendanceScreen> {
  final DatabaseService _databaseService = DatabaseService();
  final AuthService _authService = AuthService();

  List<UserModel> _students = [];
  Set<String> _presentStudents = {};
  Map<String, bool> _manualAttendance = {};

  bool _isScanning  = false;
  bool _isLoading   = true;
  bool _isSaving    = false;
  bool _isCheckingDuplicate = false;

  String? _currentTeacherId;

  // ── Selected date (default = today) ───────────────────────────────
  DateTime _selectedDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _loadStudents();
  }

  // ── Helpers ────────────────────────────────────────────────────────

  String _dateKey(DateTime dt) =>
      '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';

  String _formatDate(DateTime dt) {
    const months = [
      '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    const days = ['', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return '${days[dt.weekday]}, ${dt.day} ${months[dt.month]} ${dt.year}';
  }

  bool _isToday(DateTime dt) {
    final now = DateTime.now();
    return dt.year == now.year && dt.month == now.month && dt.day == now.day;
  }

  // ── Load students ──────────────────────────────────────────────────

  Future<void> _loadStudents() async {
    final user = await _authService.getCurrentUserData();
    final students = await _databaseService.getStudentsByClass(
      widget.subject.class_,
      widget.subject.section,
    );

    // Sort by roll number
    students.sort((a, b) => (a.rollNo ?? '').compareTo(b.rollNo ?? ''));

    setState(() {
      _currentTeacherId = user?.uid;
      _students = students;
      _isLoading = false;
      for (var s in students) {
        _manualAttendance[s.rollNo!] = false;
      }
    });
  }

  // ── Date picker ────────────────────────────────────────────────────

  Future<void> _pickDate() async {
    // Don't allow date change while scanning
    if (_isScanning) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Stop scanning before changing the date.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2026, 2, 23), // Session start
      lastDate: DateTime(2026, 5, 10),  // Session end
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: Colors.orange.shade700,
              onPrimary: Colors.white,
              surface: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked == null) return;

    // If date changed and something was already marked — warn user
    final dateChanged = _dateKey(picked) != _dateKey(_selectedDate);
    final hasMarked = _presentStudents.isNotEmpty ||
        _manualAttendance.values.any((v) => v);

    if (dateChanged && hasMarked) {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Change Date?'),
          content: const Text(
              'You have already marked some students. Changing the date will reset all marks. Continue?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange.shade700,
                  foregroundColor: Colors.white),
              child: const Text('Yes, Change'),
            ),
          ],
        ),
      );
      if (confirm != true) return;

      // Reset marks
      setState(() {
        _presentStudents.clear();
        _manualAttendance.updateAll((_, __) => false);
      });
    }

    setState(() => _selectedDate = picked);

    // Check if attendance already exists for this date
    if (dateChanged) {
      await _checkDuplicateAttendance();
    }
  }

  // Check if attendance already exists for selected date — warn teacher
  Future<void> _checkDuplicateAttendance() async {
    setState(() => _isCheckingDuplicate = true);

    final records = await _databaseService.getAttendanceForSubjectClass(
      widget.subject.code,
      widget.subject.class_,
    );

    final dk = _dateKey(_selectedDate);
    bool alreadyExists = false;
    for (final studentRecords in records.values) {
      if (studentRecords.containsKey(dk)) {
        alreadyExists = true;
        break;
      }
    }

    setState(() => _isCheckingDuplicate = false);

    if (alreadyExists && mounted) {
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Icon(Icons.warning_amber_rounded,
                  color: Colors.orange.shade700),
              const SizedBox(width: 8),
              const Text('Already Taken'),
            ],
          ),
          content: Text(
            'Attendance for ${_formatDate(_selectedDate)} already exists.\n\nIf you save again, it will overwrite the existing records for this date.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Got it'),
            ),
          ],
        ),
      );
    }
  }

  // ── BLE Scanning ───────────────────────────────────────────────────

  Future<void> _startBLEScanning() async {
    setState(() {
      _isScanning = true;
      _presentStudents.clear();
    });

    bool started = await BleService.startScanning((rollNo) {
      if (mounted) {
        setState(() => _presentStudents.add(rollNo));
      }
    });

    if (!started && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Failed to start scanning. Check permissions.')),
      );
      setState(() => _isScanning = false);
      return;
    }

    // Auto-stop after 60 seconds
    Future.delayed(const Duration(seconds: 60), () async {
      if (_isScanning) {
        await BleService.stopScanning();
        if (mounted) setState(() => _isScanning = false);
      }
    });
  }

  Future<void> _stopScanning() async {
    await BleService.stopScanning();
    setState(() => _isScanning = false);
  }

  // ── Save attendance ────────────────────────────────────────────────

  Future<void> _saveAttendance() async {
    if (_currentTeacherId == null) return;

    // Confirm save
    final totalPresent = _presentStudents.length +
        _manualAttendance.values.where((v) => v).length;
    final totalAbsent = _students.length - totalPresent;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Confirm Save'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Date: ${_formatDate(_selectedDate)}',
                style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.check_circle_rounded,
                    color: Colors.green.shade600, size: 18),
                const SizedBox(width: 8),
                Text('Present: $totalPresent students'),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Icon(Icons.cancel_rounded,
                    color: Colors.red.shade600, size: 18),
                const SizedBox(width: 8),
                Text('Absent: $totalAbsent students'),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'All $totalAbsent unmarked students will be saved as absent.',
              style: TextStyle(
                  fontSize: 12, color: Colors.grey.shade600),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green.shade700,
                foregroundColor: Colors.white),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isSaving = true);

    // Determine final status for each student
    // Present = BLE detected OR manually checked
    // Absent  = everyone else
    final List<AttendanceModel> toSave = [];
    final selectedDateNoon = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
      9, 0,
    );

    for (final student in _students) {
      final rollNo     = student.rollNo!;
      final isBLE      = _presentStudents.contains(rollNo);
      final isManual   = _manualAttendance[rollNo] ?? false;
      final isPresent  = isBLE || isManual;

      String markedBy;
      if (isBLE) {
        markedBy = 'bluetooth';
      } else if (isManual) {
        markedBy = 'manual';
      } else {
        markedBy = 'auto_absent';
      }

      toSave.add(AttendanceModel(
        id:            '',
        studentRollNo: rollNo,
        studentName:   student.name,
        subjectCode:   widget.subject.code,
        subjectName:   widget.subject.name,
        teacherId:     _currentTeacherId!,
        class_:        widget.subject.class_,
        dateTime:      selectedDateNoon, // ✅ uses selected date, not DateTime.now()
        status:        isPresent ? 'present' : 'absent',
        markedBy:      markedBy,
      ));
    }

    // Delete existing records for this date (overwrite)
    final existingRecords = await _databaseService.getAttendanceForSubjectClass(
      widget.subject.code,
      widget.subject.class_,
    );
    final dk = _dateKey(_selectedDate);
    for (final studentRecords in existingRecords.values) {
      final existing = studentRecords[dk];
      if (existing != null && existing.id.isNotEmpty) {
        await _databaseService.deleteAttendance(existing.id);
      }
    }

    // Save all fresh records in one batch
    final success = await _databaseService.saveAttendanceBatch(toSave);

    setState(() => _isSaving = false);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success
              ? '✅ Attendance saved for ${_formatDate(_selectedDate)} — $totalPresent present, $totalAbsent absent'
              : '❌ Failed to save. Try again.'),
          backgroundColor:
              success ? Colors.green.shade700 : Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );

      if (success) {
        setState(() {
          _presentStudents.clear();
          _manualAttendance.updateAll((_, __) => false);
        });
      }
    }
  }

  // ── Build ──────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
          body: Center(child: CircularProgressIndicator()));
    }

    final totalPresent = _presentStudents.length +
        _manualAttendance.values.where((v) => v).length;
    final totalAbsent = _students.length - totalPresent;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.subject.name),
        backgroundColor: Colors.orange.shade700,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [

          // ── Subject + Date Info Card ─────────────────────────────
          Container(
            margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            decoration: BoxDecoration(
              color: Colors.orange.shade50,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.orange.shade200),
            ),
            child: Column(
              children: [
                // Top row: class info + present count
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${widget.subject.class_}  •  Section ${widget.subject.section}',
                              style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Total Students: ${_students.length}',
                              style: TextStyle(
                                  color: Colors.grey.shade600,
                                  fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                      // Present / Absent counters
                      Column(
                        children: [
                          Row(
                            children: [
                              _statBadge('$totalPresent', 'Present',
                                  Colors.green.shade700),
                              const SizedBox(width: 12),
                              _statBadge(
                                  '$totalAbsent', 'Absent', Colors.red.shade600),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const Divider(height: 1),

                // Date picker row
                InkWell(
                  onTap: _pickDate,
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(16),
                    bottomRight: Radius.circular(16),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
                    child: Row(
                      children: [
                        Icon(Icons.calendar_today_rounded,
                            color: Colors.orange.shade700, size: 18),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Attendance Date',
                                style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey.shade500),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                _formatDate(_selectedDate),
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.orange.shade900,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (_isCheckingDuplicate)
                          const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        else ...[
                          if (_isToday(_selectedDate))
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: Colors.green.shade100,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text('Today',
                                  style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.green.shade700,
                                      fontWeight: FontWeight.bold)),
                            ),
                          const SizedBox(width: 8),
                          Icon(Icons.edit_calendar_rounded,
                              color: Colors.orange.shade600, size: 18),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // ── BLE Scan / Save Buttons ──────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed:
                        _isScanning ? _stopScanning : _startBLEScanning,
                    icon: Icon(_isScanning
                        ? Icons.stop_rounded
                        : Icons.bluetooth_searching_rounded),
                    label: Text(_isScanning
                        ? 'Stop Scanning'
                        : 'Start BLE Scan'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _isScanning
                          ? Colors.red.shade600
                          : Colors.orange.shade700,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // Save button — always visible once students loaded
                ElevatedButton.icon(
                  onPressed: _isSaving ? null : _saveAttendance,
                  icon: _isSaving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.save_rounded),
                  label:
                      Text(_isSaving ? 'Saving...' : 'Save'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green.shade700,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        vertical: 14, horizontal: 20),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ],
            ),
          ),

          // ── Scanning indicator ───────────────────────────────────
          if (_isScanning)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  const SizedBox(width: 10),
                  Text('Scanning for student devices...',
                      style:
                          TextStyle(color: Colors.grey.shade600)),
                ],
              ),
            )
          else
            const SizedBox(height: 8),

          // ── Students list ────────────────────────────────────────
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _students.length,
              itemBuilder: (context, index) {
                final student    = _students[index];
                final rollNo     = student.rollNo!;
                final isBLE      = _presentStudents.contains(rollNo);
                final isManual   = _manualAttendance[rollNo] ?? false;
                final isPresent  = isBLE || isManual;

                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isPresent
                          ? Colors.green.shade200
                          : Colors.grey.shade200,
                      width: isPresent ? 1.5 : 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.04),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 4),
                    leading: CircleAvatar(
                      backgroundColor: isPresent
                          ? Colors.green.shade100
                          : Colors.grey.shade100,
                      child: Text(
                        rollNo.replaceAll(RegExp(r'[^0-9]'), '').isEmpty
                            ? student.name[0]
                            : rollNo.replaceAll(RegExp(r'[^0-9]'), ''),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: isPresent
                              ? Colors.green.shade700
                              : Colors.grey.shade600,
                        ),
                      ),
                    ),
                    title: Text(
                      student.name,
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 14),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Roll No: $rollNo',
                            style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade500)),
                        if (isBLE)
                          Row(
                            children: [
                              Icon(Icons.bluetooth_rounded,
                                  size: 12,
                                  color: Colors.blue.shade600),
                              const SizedBox(width: 4),
                              Text('Detected via Bluetooth',
                                  style: TextStyle(
                                      color: Colors.blue.shade600,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w500)),
                            ],
                          ),
                      ],
                    ),
                    trailing: isBLE
                        // BLE detected — show locked green tick
                        ? Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: Colors.green.shade100,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(Icons.check_rounded,
                                color: Colors.green.shade700, size: 20),
                          )
                        // Manual checkbox
                        : Checkbox(
                            value: isManual,
                            onChanged: (value) {
                              setState(() {
                                _manualAttendance[rollNo] =
                                    value ?? false;
                              });
                            },
                            activeColor: Colors.green.shade700,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(4)),
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

  Widget _statBadge(String count, String label, Color color) {
    return Column(
      children: [
        Text(count,
            style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.bold,
                color: color)),
        Text(label,
            style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
      ],
    );
  }

  @override
  void dispose() {
    if (_isScanning) BleService.stopScanning();
    super.dispose();
  }
}