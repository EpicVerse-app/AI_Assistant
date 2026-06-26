import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'login_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _notifications = true;
  bool _autoSummarize = true;
  bool _saveTranscripts = true;

  void _logout() {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(builder: (_) => const LoginScreen()),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: ListView(
        children: [
          const SizedBox(height: 8),
          ListTile(
            leading: CircleAvatar(
              backgroundColor: AppTheme.fillGray,
              child: const Text(
                'A',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: AppTheme.primaryBlack,
                ),
              ),
            ),
            title: const Text('Alex'),
            subtitle: const Text('alex@example.com'),
            trailing: const Icon(Icons.chevron_right, size: 20),
            onTap: () {},
          ),
          const Divider(height: 32),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Text(
              'Preferences',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppTheme.secondaryGray,
              ),
            ),
          ),
          SwitchListTile(
            title: const Text('Notifications'),
            value: _notifications,
            onChanged: (v) => setState(() => _notifications = v),
          ),
          SwitchListTile(
            title: const Text('Auto-summarize recordings'),
            value: _autoSummarize,
            onChanged: (v) => setState(() => _autoSummarize = v),
          ),
          SwitchListTile(
            title: const Text('Save transcripts'),
            value: _saveTranscripts,
            onChanged: (v) => setState(() => _saveTranscripts = v),
          ),
          const Divider(height: 32),
          ListTile(
            title: const Text(
              'Logout',
              style: TextStyle(color: Color(0xFFFF3B30)),
            ),
            onTap: _logout,
          ),
        ],
      ),
    );
  }
}
