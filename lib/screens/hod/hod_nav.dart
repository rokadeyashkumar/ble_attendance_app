import 'package:flutter/material.dart';
import 'package:google_nav_bar/google_nav_bar.dart';
import '../../models/user_model.dart';
import './hod_home_screen.dart';
import './hod_reports_screen.dart';
import './hod_timetable_screen.dart';
import './hod_profile_screen.dart';

class HodNav extends StatefulWidget {
  final UserModel user;
  const HodNav({Key? key, required this.user}) : super(key: key);

  @override
  State<HodNav> createState() => _HodNavState();
}

class _HodNavState extends State<HodNav> {
  int _selectedIndex = 0;

  late final List<Widget> _pages = [
    HodHomeScreen(user: widget.user),
    const HodReportsScreen(),
    const HodTimetableScreen(),
    HodProfileScreen(user: widget.user),
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
              GButton(icon: Icons.bar_chart_rounded, text: 'Reports'),
              GButton(icon: Icons.calendar_today,    text: 'Timetable'),
              GButton(icon: Icons.person_rounded,    text: 'Profile'),
            ],
          ),
        ),
      ),
    );
  }
}