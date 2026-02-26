import 'package:flutter/material.dart';
import 'package:google_nav_bar/google_nav_bar.dart';
import '../../models/user_model.dart';
import './student_home_screen.dart';
import './student_record_screen.dart';
import './student_profile_screen.dart';

class StudentNav extends StatefulWidget {
  final UserModel user;
  const StudentNav({Key? key, required this.user}) : super(key: key);

  @override
  State<StudentNav> createState() => _StudentNavState();
}

class _StudentNavState extends State<StudentNav> {
  int _selectedIndex = 0;

  late final List<Widget> _pages = [
    StudentHomeScreen(user: widget.user),
    const StudentRecordScreen(),
    const StudentRecordScreen(),
    StudentProfileScreen(user: widget.user),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_selectedIndex],
      bottomNavigationBar: Container(
        color: Theme.of(context).colorScheme.surface,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
          child: GNav(
            selectedIndex: _selectedIndex,
            onTabChange: (index) {
              setState(() => _selectedIndex = index);
            },
            gap: 8,
            tabs: const [
              GButton(icon: Icons.home_rounded,      text: 'Home'),
              GButton(icon: Icons.bar_chart_rounded, text: 'Records'),
              GButton(icon: Icons.calendar_today,    text: 'Timetable'),
              GButton(icon: Icons.person_rounded,    text: 'Profile'),
            ],
          ),
        ),
      ),
    );
  }
}