import 'dart:async';

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class RecordingScreen extends StatefulWidget {
  const RecordingScreen({super.key});

  @override
  State<RecordingScreen> createState() => _RecordingScreenState();
}

class _RecordingScreenState extends State<RecordingScreen> {
  bool _isRecording = false;
  final Stopwatch _stopwatch = Stopwatch();
  Timer? _timer;
  Duration _elapsed = Duration.zero;

  @override
  void dispose() {
    _timer?.cancel();
    _stopwatch.stop();
    super.dispose();
  }

  void _toggleRecording() {
    setState(() {
      if (_isRecording) {
        _stopwatch.stop();
        _timer?.cancel();
        _isRecording = false;
      } else {
        _stopwatch.start();
        _timer = Timer.periodic(const Duration(seconds: 1), (_) {
          if (mounted) setState(() => _elapsed = _stopwatch.elapsed);
        });
        _isRecording = true;
      }
    });
  }

  String _format(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.surfaceWhite,
      appBar: AppBar(
        title: const Text('Record'),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                _format(_elapsed),
                style: const TextStyle(
                  fontSize: 48,
                  fontWeight: FontWeight.w300,
                  color: AppTheme.primaryBlack,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _isRecording ? 'Recording...' : 'Ready to record',
                style: const TextStyle(
                  fontSize: 15,
                  color: AppTheme.secondaryGray,
                ),
              ),
              const SizedBox(height: 48),
              GestureDetector(
                onTap: _toggleRecording,
                child: Container(
                  width: 88,
                  height: 88,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _isRecording
                        ? const Color(0xFFFF3B30)
                        : AppTheme.primaryBlack,
                  ),
                  child: Icon(
                    _isRecording ? Icons.stop_rounded : Icons.mic_rounded,
                    color: Colors.white,
                    size: 40,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                _isRecording ? 'Tap to stop' : 'Tap to start',
                style: const TextStyle(
                  fontSize: 14,
                  color: AppTheme.secondaryGray,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
