import 'dart:async';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import '../services/api_service.dart';
import '../services/offline_queue.dart';
import '../theme/app_theme.dart';
import 'processing_screen.dart';

class RecordingScreen extends StatefulWidget {
  const RecordingScreen({super.key});

  @override
  State<RecordingScreen> createState() => _RecordingScreenState();
}

class _RecordingScreenState extends State<RecordingScreen> {
  final AudioRecorder _recorder = AudioRecorder();
  bool _isRecording = false;
  bool _isLoading = false;
  final Stopwatch _stopwatch = Stopwatch();
  Timer? _timer;
  Duration _elapsed = Duration.zero;
  String? _recordedPath;

  @override
  void dispose() {
    _timer?.cancel();
    _stopwatch.stop();
    _recorder.dispose();
    super.dispose();
  }

  Future<void> _startRecording() async {
    final hasPermission = await _recorder.hasPermission();
    if (!hasPermission) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Microphone permission denied.')),
        );
      }
      return;
    }

    final dir = await getApplicationDocumentsDirectory();
    final path =
        '${dir.path}/recording_${DateTime.now().millisecondsSinceEpoch}.wav';

    await _recorder.start(
      const RecordConfig(encoder: AudioEncoder.wav, sampleRate: 16000),
      path: path,
    );

    _stopwatch
      ..reset()
      ..start();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _elapsed = _stopwatch.elapsed);
    });

    setState(() {
      _isRecording = true;
      _recordedPath = path;
    });
  }

  Future<void> _stopAndProcess() async {
    _stopwatch.stop();
    _timer?.cancel();

    final path = await _recorder.stop();

    // Give the OS a moment to finish flushing the file to disk.
    await Future.delayed(const Duration(milliseconds: 400));

    setState(() {
      _isRecording = false;
      _isLoading = true;
    });

    if (path == null) {
      setState(() => _isLoading = false);
      return;
    }

    final audioFile = File(path);
    if (!audioFile.existsSync() || audioFile.lengthSync() == 0) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Recording is empty. Please try again.')),
        );
      }
      return;
    }
    final connectivityResult = await Connectivity().checkConnectivity();
    final isOnline = connectivityResult != ConnectivityResult.none &&
        await ApiService.isReachable();

    if (!isOnline) {
      await OfflineQueue.add(path);
      setState(() => _isLoading = false);
      if (mounted) {
        showDialog<void>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Saved for later'),
            content: const Text(
              'You are offline. The recording has been saved and will be processed automatically when you reconnect.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
      return;
    }

    try {
      final meetingId = await ApiService.uploadAudio(audioFile);
      if (mounted) {
        setState(() => _isLoading = false);
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => ProcessingScreen(meetingId: meetingId),
          ),
        );
      }
    } catch (e) {
      await OfflineQueue.add(path);
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Upload failed. Saved offline: $e')),
        );
      }
    }
  }

  Future<void> _pickAndUpload() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['mp3', 'm4a', 'wav', 'aac', 'ogg', 'flac', 'opus', 'webm', 'mp4'],
      allowMultiple: false,
    );

    if (result == null || result.files.isEmpty) return;

    final pickedFile = File(result.files.single.path!);
    if (!pickedFile.existsSync() || pickedFile.lengthSync() == 0) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Selected file is empty or unreadable.')),
        );
      }
      return;
    }

    setState(() => _isLoading = true);

    final connectivityResult = await Connectivity().checkConnectivity();
    final isOnline = connectivityResult != ConnectivityResult.none &&
        await ApiService.isReachable();

    if (!isOnline) {
      await OfflineQueue.add(pickedFile.path);
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Offline — file saved and will upload when reconnected.')),
        );
      }
      return;
    }

    try {
      final meetingId = await ApiService.uploadAudio(pickedFile);
      if (mounted) {
        setState(() => _isLoading = false);
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => ProcessingScreen(meetingId: meetingId),
          ),
        );
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Upload failed: $e')),
        );
      }
    }
  }

  String _format(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    if (h > 0) return '$h:$m:$s';
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.surfaceWhite,
      appBar: AppBar(title: const Text('Record Meeting')),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          padding: const EdgeInsets.all(24),
          child: _isLoading
              ? const SizedBox(
                  height: 400,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 16),
                      Text('Uploading & processing audio...'),
                    ],
                  ),
                )
              : Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      _format(_elapsed),
                      style: const TextStyle(
                        fontSize: 56,
                        fontWeight: FontWeight.w200,
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
                    if (_isRecording) ...[
                      const SizedBox(height: 4),
                      const Text(
                        'Speak clearly — all languages supported',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppTheme.secondaryGray,
                        ),
                      ),
                    ],
                    const SizedBox(height: 56),
                    GestureDetector(
                      onTap: _isRecording ? _stopAndProcess : _startRecording,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: 88,
                        height: 88,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _isRecording
                              ? const Color(0xFFFF3B30)
                              : AppTheme.primaryBlack,
                        ),
                        child: Icon(
                          _isRecording
                              ? Icons.stop_rounded
                              : Icons.mic_rounded,
                          color: Colors.white,
                          size: 40,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _isRecording ? 'Tap to stop & process' : 'Tap to start',
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppTheme.secondaryGray,
                      ),
                    ),

                    if (!_isRecording) ...[
                      const SizedBox(height: 40),
                      const Row(
                        children: [
                          Expanded(child: Divider()),
                          Padding(
                            padding: EdgeInsets.symmetric(horizontal: 12),
                            child: Text(
                              'or',
                              style: TextStyle(
                                fontSize: 13,
                                color: AppTheme.secondaryGray,
                              ),
                            ),
                          ),
                          Expanded(child: Divider()),
                        ],
                      ),
                      const SizedBox(height: 24),
                      OutlinedButton.icon(
                        onPressed: _pickAndUpload,
                        icon: const Icon(Icons.upload_file_outlined, size: 20),
                        label: const Text('Upload Audio File'),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(double.infinity, 52),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'mp3 · m4a · wav · aac · ogg · flac',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppTheme.secondaryGray,
                        ),
                      ),
                    ],
                  ],
                ),
        ),
      ),
    );
  }
}
