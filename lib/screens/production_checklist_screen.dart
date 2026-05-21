import 'package:flutter/material.dart';

class ProductionChecklistScreen extends StatelessWidget {
  const ProductionChecklistScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final items = [
      'Confirm Firestore rules are published and locked to authenticated owners only.',
      'Verify AI endpoint setup flow on the intended release platform.',
      'Test password reset email delivery in the production Firebase project.',
      'Validate delete-account works after reauthentication.',
      'Confirm Crashlytics reports from a real device build.',
      'Run smoke tests after any Firebase config change.',
      'Review privacy policy and medical disclaimer with legal or product owners.',
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Production Checklist'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            'Release readiness checklist',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Text(
            'Use this before shipping a build or handing off to testers.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 20),
          ...items.map(
            (item) => Card(
              child: ListTile(
                leading: const Icon(Icons.check_circle_outline_rounded),
                title: Text(item),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
