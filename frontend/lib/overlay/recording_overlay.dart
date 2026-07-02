import 'package:flutter/material.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';

import '../theme/app_theme.dart';

class RecordingOverlayApp extends StatelessWidget {
  const RecordingOverlayApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: const RecordingOverlayScreen(),
    );
  }
}

class RecordingOverlayScreen extends StatelessWidget {
  const RecordingOverlayScreen({super.key});

  Future<void> _stop() async {
    // main isolate listens for this and stops the recording service.
    await FlutterOverlayWindow.shareData('stop');
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: SafeArea(
        child: Center(
          child: Container(
            width: 260,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.92),
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.18),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Recording…',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Tap Stop to finish and save.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppTheme.secondaryGray),
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: _stop,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF8D6736),
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Stop'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

