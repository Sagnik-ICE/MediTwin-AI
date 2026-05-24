import 'package:flutter/material.dart';

import 'analytics_screen.dart';
import 'chat_screen.dart';
import 'emergency_screen.dart';
import 'home_dashboard_screen.dart';
import 'my_appointments_screen.dart';
import 'settings_screen.dart';
import 'doctor_directory_screen.dart';
import 'tracking_screen.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    final screens = [
      HomeDashboardScreen(onAddData: _openTracking),
      const ChatScreen(),
      const AnalyticsScreen(),
      const DoctorDirectoryScreen(),
      const MyAppointmentsScreen(),
      const EmergencyScreen(),
      const SettingsScreen(),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 1024;
        final body = AnimatedSwitcher(
          duration: const Duration(milliseconds: 240),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
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
                  minWidth: 88,
                  groupAlignment: -0.92,
                  destinations: const [
                    NavigationRailDestination(icon: Icon(Icons.home_rounded), label: Text('Home')),
                    NavigationRailDestination(icon: Icon(Icons.chat_bubble_rounded), label: Text('Chat')),
                    NavigationRailDestination(icon: Icon(Icons.insights_rounded), label: Text('Analytics')),
                    NavigationRailDestination(icon: Icon(Icons.local_hospital_rounded), label: Text('Doctors')),
                    NavigationRailDestination(icon: Icon(Icons.event_note_rounded), label: Text('Appointments')),
                    NavigationRailDestination(icon: Icon(Icons.warning_amber_rounded), label: Text('Emergency')),
                    NavigationRailDestination(icon: Icon(Icons.settings_rounded), label: Text('Settings')),
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
              NavigationDestination(icon: Icon(Icons.home_rounded), label: 'Home'),
              NavigationDestination(icon: Icon(Icons.chat_bubble_rounded), label: 'Chat'),
              NavigationDestination(icon: Icon(Icons.insights_rounded), label: 'Analytics'),
              NavigationDestination(icon: Icon(Icons.local_hospital_rounded), label: 'Doctors'),
              NavigationDestination(icon: Icon(Icons.event_note_rounded), label: 'Appointments'),
              NavigationDestination(icon: Icon(Icons.warning_amber_rounded), label: 'Emergency'),
              NavigationDestination(icon: Icon(Icons.settings_rounded), label: 'Settings'),
            ],
          ),
        );
      },
    );
  }

  Future<void> _openTracking() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => TrackingScreen(
          onSaved: () {
            if (mounted) {
              Navigator.of(context).pop();
            }
          },
        ),
      ),
    );
  }
}
