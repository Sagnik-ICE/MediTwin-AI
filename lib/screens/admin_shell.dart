import 'package:flutter/material.dart';

import 'admin_dashboard_screen.dart';
import 'admin_management_screen.dart';
import 'doctor_directory_screen.dart';
import 'emergency_screen.dart';
import 'profile_screen.dart';

class AdminShell extends StatefulWidget {
  const AdminShell({super.key});

  @override
  State<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends State<AdminShell> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    final screens = [
      const AdminDashboardScreen(),
      const DoctorDirectoryScreen(),
      const EmergencyScreen(),
      const AdminManagementScreen(),
      const ProfileScreen(),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 1024;
        final body = AnimatedSwitcher(
          duration: const Duration(milliseconds: 260),
          child: KeyedSubtree(key: ValueKey(_currentIndex), child: screens[_currentIndex]),
        );

        if (wide) {
          return Scaffold(
            body: Row(
              children: [
                NavigationRail(
                  selectedIndex: _currentIndex,
                  onDestinationSelected: (index) => setState(() => _currentIndex = index),
                  labelType: NavigationRailLabelType.all,
                  minWidth: 84,
                  destinations: const [
                    NavigationRailDestination(icon: Icon(Icons.dashboard_rounded), label: Text('Overview')),
                    NavigationRailDestination(icon: Icon(Icons.local_hospital_rounded), label: Text('Doctors')),
                    NavigationRailDestination(icon: Icon(Icons.warning_amber_rounded), label: Text('Emergency')),
                    NavigationRailDestination(icon: Icon(Icons.admin_panel_settings_rounded), label: Text('Admins')),
                    NavigationRailDestination(icon: Icon(Icons.person_rounded), label: Text('Profile')),
                  ],
                ),
                const VerticalDivider(width: 1),
                Expanded(child: body),
              ],
            ),
          );
        }

        return Scaffold(
          body: body,
          bottomNavigationBar: NavigationBar(
            selectedIndex: _currentIndex,
            onDestinationSelected: (index) => setState(() => _currentIndex = index),
            labelBehavior: NavigationDestinationLabelBehavior.alwaysHide,
            destinations: const [
              NavigationDestination(icon: Icon(Icons.dashboard_rounded), label: 'Overview'),
              NavigationDestination(icon: Icon(Icons.local_hospital_rounded), label: 'Doctors'),
              NavigationDestination(icon: Icon(Icons.warning_amber_rounded), label: 'Emergency'),
              NavigationDestination(icon: Icon(Icons.admin_panel_settings_rounded), label: 'Admins'),
              NavigationDestination(icon: Icon(Icons.person_rounded), label: 'Profile'),
            ],
          ),
        );
      },
    );
  }
}
