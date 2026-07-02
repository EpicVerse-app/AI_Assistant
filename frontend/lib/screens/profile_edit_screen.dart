import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../theme/app_theme.dart';

class ProfileEditScreen extends StatefulWidget {
  const ProfileEditScreen({super.key, this.initialImagePath});

  final String? initialImagePath;

  @override
  State<ProfileEditScreen> createState() => _ProfileEditScreenState();
}

class _ProfileEditScreenState extends State<ProfileEditScreen> {
  static const _profileImageKey = 'profile_image_path';

  String? _path;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _path = widget.initialImagePath;
  }

  Future<void> _pickImage() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['png', 'jpg', 'jpeg', 'webp'],
      allowMultiple: false,
      withData: false,
    );
    if (result == null || result.files.isEmpty) return;
    final path = result.files.single.path;
    if (path == null || path.isEmpty) return;
    if (!File(path).existsSync()) return;
    setState(() => _path = path);
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final path = _path;
      if (path == null || path.isEmpty) {
        await prefs.remove(_profileImageKey);
      } else {
        await prefs.setString(_profileImageKey, path);
      }
      if (!mounted) return;
      Navigator.of(context).pop<String?>(_path);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final path = _path;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('Edit profile'),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Save'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Center(
            child: CircleAvatar(
              radius: 44,
              backgroundColor: AppTheme.fillGray,
              backgroundImage: path != null ? FileImage(File(path)) : null,
              child: path == null
                  ? const Icon(Icons.person, size: 44, color: AppTheme.secondaryGray)
                  : null,
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _pickImage,
            icon: const Icon(Icons.image),
            label: const Text('Choose photo'),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: path == null ? null : () => setState(() => _path = null),
            icon: const Icon(Icons.delete_outline),
            label: const Text('Remove photo'),
          ),
          const SizedBox(height: 8),
          const Text(
            'This photo is stored locally on the device.',
            style: TextStyle(color: AppTheme.secondaryGray),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

