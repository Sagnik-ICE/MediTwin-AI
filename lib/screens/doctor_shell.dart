import 'package:flutter/material.dart';

import 'doctor_profile_screen.dart';

class DoctorShell extends StatelessWidget {
  const DoctorShell({super.key});

  @override
  Widget build(BuildContext context) {
    return const DoctorProfileScreen(canEdit: true, allowBooking: false);
  }
}
