import 'package:flutter/material.dart';
import '../../services/auth_service.dart';
import '../../services/ble_service.dart';
import '../../services/database_service.dart';
import '../../models/user_model.dart';
import '../../models/attendance_model.dart';
import '../role_selection_screen.dart';

class StudentHomeScreen extends StatefulWidget {
  final UserModel user;
  const StudentHomeScreen({Key? key, required this.user}) : super(key: key);

  @override
  State<StudentHomeScreen> createState() => _StudentHomeScreenState();
}

class _StudentHomeScreenState extends State<StudentHomeScreen>
    with SingleTickerProviderStateMixin {
  final DatabaseService _databaseService = DatabaseService();
  final AuthService _authService = AuthService();

  List<AttendanceModel> _attendanceHistory = [];
  bool _isAdvertising = false;
  bool _isMarked = false;
  bool _isLoading = true;

  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _rotateAnimation;

  @override
  void initState() {
    super.initState();
    _loadAttendance();
    _setupAnimations();
  }

  void _setupAnimations() {
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _rotateAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.linear),
    );
  }

  Future<void> _loadAttendance() async {
    final history =
        await _databaseService.getStudentAttendance(widget.user.rollNo!);
    setState(() {
      _attendanceHistory = history;
      _isLoading = false;
    });
  }

  Future<void> _markAttendance() async {
    if (_isAdvertising) return;

    _animationController.repeat();
    setState(() {
      _isAdvertising = true;
      _isMarked = false;
    });

    bool started = await BleService.startAdvertising(widget.user.rollNo!);

    if (!started) {
      _animationController.stop();
      setState(() => _isAdvertising = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content:
                  Text('Failed to start advertising. Check permissions.')),
        );
      }
      return;
    }

    await Future.delayed(const Duration(seconds: 30));
    await BleService.stopAdvertising();
    _animationController.stop();
    _animationController.reset();

    setState(() {
      _isAdvertising = false;
      _isMarked = true;
    });

    _loadAttendance();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Attendance signal sent!'),
          backgroundColor: Colors.green,
        ),
      );
    }

    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) setState(() => _isMarked = false);
    });
  }

  void _handleLogout() async {
    await _authService.signOut();
    if (mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const RoleSelectionScreen()),
        (route) => false,
      );
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        backgroundColor: Colors.green.shade700,
        foregroundColor: Colors.white,
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _handleLogout,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Column(
                children: [
                  // Header
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.green.shade700,
                      borderRadius: const BorderRadius.only(
                        bottomLeft: Radius.circular(30),
                        bottomRight: Radius.circular(30),
                      ),
                    ),
                    child: Column(
                      children: [
                        Text(
                          'Welcome, ${widget.user.name}',
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Roll No: ${widget.user.rollNo ?? 'N/A'}',
                          style: const TextStyle(
                              fontSize: 16, color: Colors.white70),
                        ),
                        Text(
                          '${widget.user.class_} - ${widget.user.section}',
                          style: const TextStyle(
                              fontSize: 14, color: Colors.white70),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),

                  // BLE Button
                  GestureDetector(
                    onTap: _isAdvertising ? null : _markAttendance,
                    child: AnimatedBuilder(
                      animation: _animationController,
                      builder: (context, child) {
                        return Transform.scale(
                          scale: _scaleAnimation.value,
                          child: Transform.rotate(
                            angle: _rotateAnimation.value * 2 * 3.14159,
                            child: Container(
                              height: 180,
                              width: 180,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: _isMarked
                                    ? Colors.green
                                    : _isAdvertising
                                        ? Colors.blue.shade700
                                        : Colors.blue.shade100,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.blue.withOpacity(0.3),
                                    blurRadius: 20,
                                    spreadRadius: 5,
                                  ),
                                ],
                              ),
                              child: Icon(
                                _isMarked
                                    ? Icons.check_circle
                                    : Icons.bluetooth,
                                size: 80,
                                color: _isMarked
                                    ? Colors.white
                                    : _isAdvertising
                                        ? Colors.white
                                        : Colors.blue.shade700,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Status text
                  if (_isAdvertising)
                    const Text(
                      'Broadcasting attendance signal...',
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: Colors.blue),
                    ),
                  if (_isMarked)
                    const Text(
                      'Attendance Marked! ✓',
                      style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.green),
                    ),
                  if (!_isAdvertising && !_isMarked)
                    const Text(
                      'Tap to mark attendance',
                      style: TextStyle(fontSize: 16, color: Colors.grey),
                    ),
                  const SizedBox(height: 32),

                  // Attendance History
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Attendance History',
                          style: TextStyle(
                              fontSize: 20, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 16),
                        _attendanceHistory.isEmpty
                            ? const Center(
                                child: Padding(
                                  padding: EdgeInsets.all(32.0),
                                  child: Text(
                                    'No attendance records yet',
                                    style: TextStyle(color: Colors.grey),
                                  ),
                                ),
                              )
                            : ListView.builder(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: _attendanceHistory.length,
                                itemBuilder: (context, index) {
                                  final attendance =
                                      _attendanceHistory[index];
                                  return Card(
                                    margin:
                                        const EdgeInsets.only(bottom: 12),
                                    child: ListTile(
                                      leading: Icon(Icons.check_circle,
                                          color: Colors.green.shade700,
                                          size: 32),
                                      title: Text(attendance.subjectName),
                                      subtitle: Text(
                                        '${attendance.dateTime.day}/${attendance.dateTime.month}/${attendance.dateTime.year}',
                                      ),
                                      trailing: Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 12, vertical: 6),
                                        decoration: BoxDecoration(
                                          color: Colors.green.shade50,
                                          borderRadius:
                                              BorderRadius.circular(12),
                                        ),
                                        child: Text(
                                          'Present',
                                          style: TextStyle(
                                              color: Colors.green.shade700,
                                              fontWeight: FontWeight.w600),
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
    );
  }
}