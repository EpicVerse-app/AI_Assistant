import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../widgets/app_logo.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({
    super.key,
    this.onSearchTap,
    this.onNewMeetingTap,
  });

  final VoidCallback? onSearchTap;
  final VoidCallback? onNewMeetingTap;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.surfaceWhite,
      appBar: AppBar(
        title: const Row(
          children: [
            AppLogo(size: 32),
            SizedBox(width: 12),
            Text('AI Memory Assistant'),
          ],
        ),
        centerTitle: false,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              readOnly: true,
              onTap: onSearchTap,
              decoration: const InputDecoration(
                hintText: 'Search memories',
                prefixIcon: Icon(Icons.search),
                isDense: true,
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onNewMeetingTap,
              icon: const Icon(Icons.add),
              label: const Text('New Meeting'),
            ),
          ],
        ),
      ),
    );
  }
}
