import 'package:flutter/material.dart';

import '../constants/app_constants.dart';

class DisclaimerBanner extends StatelessWidget {
  const DisclaimerBanner({super.key});

  @override
  Widget build(BuildContext context) {
    if (AppConstants.medicalDisclaimer.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.amber.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        AppConstants.medicalDisclaimer,
        style: Theme.of(context).textTheme.bodySmall,
      ),
    );
  }
}
