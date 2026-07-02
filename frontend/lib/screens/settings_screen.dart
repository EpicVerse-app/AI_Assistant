import 'dart:io';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import 'auth_gate.dart';
import 'profile_edit_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _notifications = true;
  bool _autoSummarize = true;
  bool _saveTranscripts = true;
  String? _profileImagePath;

  static const _profileImageKey = 'profile_image_path';

  @override
  void initState() {
    super.initState();
    _loadProfileImage();
  }

  Future<void> _loadProfileImage() async {
    final prefs = await SharedPreferences.getInstance();
    final path = prefs.getString(_profileImageKey);
    if (path != null && File(path).existsSync()) {
      if (mounted) setState(() => _profileImagePath = path);
    }
  }

  Future<void> _openProfileEdit() async {
    final result = await Navigator.of(context).push<String?>(
      MaterialPageRoute<String?>(
        builder: (_) =>
            ProfileEditScreen(initialImagePath: _profileImagePath),
      ),
    );
    // result is the (possibly updated) profile image path
    if (result != null && mounted) {
      setState(() => _profileImagePath = result);
    } else {
      // Refresh in case name/email changed
      setState(() {});
    }
  }

  Future<void> _logout() async {
    await AuthService.instance.logout();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(builder: (_) => const AuthGate()),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = AuthService.instance.user;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: ListView(
        children: [
          const SizedBox(height: 8),
          ListTile(
            leading: GestureDetector(
              onTap: _openProfileEdit,
              child: Stack(
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: AppTheme.fillGray,
                    backgroundImage: _profileImagePath != null
                        ? FileImage(File(_profileImagePath!))
                        : null,
                    child: _profileImagePath == null
                        ? Text(
                            user?.initials ?? '?',
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              color: AppTheme.primaryBlack,
                            ),
                          )
                        : null,
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      width: 16,
                      height: 16,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: const LinearGradient(
                          colors: [Color(0xFF8D6736), Color(0xFFB18850)],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                        border: Border.all(
                          color: Theme.of(context).scaffoldBackgroundColor,
                          width: 1.5,
                        ),
                      ),
                      child: const Icon(Icons.edit, size: 9, color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
            title: Text(user?.displayName ?? 'Guest'),
            subtitle: Text(user?.email ?? ''),
            trailing: const Icon(Icons.chevron_right, size: 20),
            onTap: _openProfileEdit,
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
