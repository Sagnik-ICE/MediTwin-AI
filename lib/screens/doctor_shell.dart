import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/app_state.dart';
import 'doctor_profile_screen.dart';
import 'settings_screen.dart';

class DoctorShell extends StatefulWidget {
  const DoctorShell({super.key});

  @override
  State<DoctorShell> createState() => _DoctorShellState();
}

class _DoctorShellState extends State<DoctorShell> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();

    // During logout the root app replaces this shell. Returning an empty widget
    // for this brief frame prevents stale doctor profile queries/navigation from
    // running while Firebase Auth is signing out.
    if (!appState.loggedIn || !appState.isDoctor) {
      return const SizedBox.shrink();
    }

    final screens = <Widget>[
      const DoctorProfileScreen(
        canEdit: true,
        allowBooking: false,
        showSettingsButton: false,
      ),
      const SettingsScreen(),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 900;
        final body = AnimatedSwitcher(
          duration: const Duration(milliseconds: 220),
          child: KeyedSubtree(
            key: ValueKey<int>(_currentIndex),
            child: screens[_currentIndex],
          ),
        );

        if (wide) {
          return Scaffold(
            body: Row(
              children: [
                NavigationRail(
                  selectedIndex: _currentIndex,
                  onDestinationSelected: (index) {
                    if (!mounted) return;
                    setState(() => _currentIndex = index);
                  },
                  labelType: NavigationRailLabelType.all,
                  minWidth: 84,
                  destinations: const [
                    NavigationRailDestination(
                      icon: Icon(Icons.local_hospital_rounded),
                      label: Text('Profile'),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.settings_rounded),
                      label: Text('Settings'),
                    ),
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
            onDestinationSelected: (index) {
              if (!mounted) return;
              setState(() => _currentIndex = index);
            },
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.local_hospital_rounded),
                label: 'Profile',
              ),
              NavigationDestination(
                icon: Icon(Icons.settings_rounded),
                label: 'Settings',
              ),
            ],
          ),
        );
      },
    );
  }
}
