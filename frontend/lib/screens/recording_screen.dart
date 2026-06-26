import 'dart:async';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';

import '../services/api_service.dart';
import '../services/background_recording_service.dart';
import '../services/local_audio_storage.dart';
import '../services/offline_queue.dart';
import '../theme/app_theme.dart';
import '../utils/mom_parser.dart';
import 'processing_screen.dart';

class RecordingScreen extends StatefulWidget {
  const RecordingScreen({super.key});

  @override
  State<RecordingScreen> createState() => _RecordingScreenState();
}

class _RecordingScreenState extends State<RecordingScreen> {
  final BackgroundRecordingService _recordingService =
      BackgroundRecordingService.instance;
  final AudioPlayer _previewPlayer = AudioPlayer();
  bool _isRecording = false;
  bool _isLoading = false;
  bool _previewPlaying = false;
  Duration _elapsed = Duration.zero;
  String? _recordedPath;

  @override
  void initState() {
    super.initState();
    _recordingService.addListener(_onRecordingEvent);
  }

  @override
  void dispose() {
    _recordingService.removeListener(_onRecordingEvent);
    _previewPlayer.dispose();
    super.dispose();
  }

  void _onRecordingEvent(Map<String, dynamic> event) {
    final type = event['event'] as String?;
    if (type == 'tick' && mounted) {
      setState(() => _elapsed = event['elapsed'] as Duration? ?? _elapsed);
    } else if (type == 'stopped' && mounted) {
      _handleRecordingStopped(event['path'] as String?);
    } else if (type == 'error' && mounted) {
      setState(() {
        _isRecording = false;
        _recordedPath = null;
        _elapsed = Duration.zero;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(event['message']?.toString() ?? 'Recording error')),
      );
    } else if (type == 'started' && mounted) {
      setState(() => _isRecording = true);
    }
  }

  Future<void> _handleRecordingStopped(String? path) async {
    await Future.delayed(const Duration(milliseconds: 400));
    if (!mounted) return;
    setState(() {
      _isRecording = false;
      _recordedPath = path;
    });
    if (path != null) {
      try {
        await _previewPlayer.setFilePath(path);
      } catch (_) {}
    }
  }

  Future<bool> _hasNetwork() async {
    final results = await Connectivity().checkConnectivity();
    return results.isNotEmpty &&
        !results.every((r) => r == ConnectivityResult.none);
  }

  Future<void> _startRecording() async {
    await _previewPlayer.stop();
    setState(() {
      _previewPlaying = false;
      _recordedPath = null;
      _elapsed = Duration.zero;
    });

    try {
      final dir = await getApplicationDocumentsDirectory();
      final path =
          '${dir.path}/recording_${DateTime.now().millisecondsSinceEpoch}.wav';

      await _recordingService.start(path);

      if (mounted) {
        setState(() => _recordedPath = path);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not start recording: $e')),
        );
      }
    }
  }

  Future<void> _stopRecording() async {
    try {
      final path = await _recordingService.stop();
      if (path != null) {
        await _handleRecordingStopped(path);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not stop recording: $e')),
        );
      }
    }
  }

  Future<void> _togglePreview() async {
    if (_recordedPath == null) return;
    if (_previewPlayer.playing) {
      await _previewPlayer.pause();
    } else {
      await _previewPlayer.play();
    }
    if (mounted) setState(() => _previewPlaying = _previewPlayer.playing);
  }

  Future<void> _discardRecording() async {
    await _previewPlayer.stop();
    setState(() {
      _recordedPath = null;
      _previewPlaying = false;
      _elapsed = Duration.zero;
    });
  }

  Future<void> _uploadAndProcess() async {
    final path = _recordedPath;
    if (path == null) return;

    await _previewPlayer.stop();
    setState(() {
      _previewPlaying = false;
      _isLoading = true;
    });

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
    final isOnline = await _hasNetwork() && await ApiService.isReachable();

    if (!isOnline) {
      await OfflineQueue.add(path);
      setState(() => _isLoading = false);
      if (mounted) {
        showDialog<void>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Saved for later'),
            content: const Text(
              'Could not reach the server (it may be waking up on Render — try again in a minute). '
              'Your recording is saved and will upload when you tap Sync on the home screen.',
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
      await LocalAudioStorage.saveForMeeting(
        meetingId,
        path,
        durationSeconds: _elapsed.inSeconds,
      );
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
      allowedExtensions: [
        'mp3', 'm4a', 'wav', 'aac', 'ogg', 'flac', 'opus', 'webm', 'mp4'
      ],
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

    final isOnline = await _hasNetwork() && await ApiService.isReachable();

    if (!isOnline) {
      await OfflineQueue.add(pickedFile.path);
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Could not reach the server — file saved. Tap Sync on the home screen to retry.',
            ),
          ),
        );
      }
      return;
    }

    try {
      final meetingId = await ApiService.uploadAudio(pickedFile);
      await LocalAudioStorage.saveForMeeting(meetingId, pickedFile.path);
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
    final content = Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(title: const Text('Record Meeting')),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics(),
              ),
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
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
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            SizedBox(
                              width: double.infinity,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  Text(
                                    _format(_elapsed),
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      fontSize: 56,
                                      fontWeight: FontWeight.w200,
                                      color: AppTheme.primaryBlack,
                                      fontFeatures: [
                                        FontFeature.tabularFigures(),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    _isRecording
                                        ? 'Recording...'
                                        : 'Ready to record',
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      fontSize: 15,
                                      color: AppTheme.secondaryGray,
                                    ),
                                  ),
                                  if (_isRecording) ...[
                                    const SizedBox(height: 4),
                                    const Text(
                                      'You can lock the screen — recording continues',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: AppTheme.secondaryGray,
                                      ),
                                    ),
                                  ],
                                  const SizedBox(height: 56),
                                  GestureDetector(
                                    onTap: _isRecording
                                        ? _stopRecording
                                        : (_recordedPath == null
                                            ? _startRecording
                                            : null),
                                    child: AnimatedContainer(
                                      duration:
                                          const Duration(milliseconds: 200),
                                      width: 88,
                                      height: 88,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: _isRecording
                                            ? const Color(0xFFFF3B30)
                                            : AppTheme.gradientBottom,
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
                                    _isRecording
                                        ? 'Tap to stop'
                                        : (_recordedPath != null
                                            ? 'Review your recording below'
                                            : 'Tap to start'),
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      fontSize: 14,
                                      color: AppTheme.secondaryGray,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (_recordedPath != null && !_isRecording) ...[
                        const SizedBox(height: 32),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(20),
                          decoration: AppTheme.cardDecoration,
                          child: Column(
                            children: [
                              GestureDetector(
                                onTap: _togglePreview,
                                child: Container(
                                  width: 56,
                                  height: 56,
                                  decoration: const BoxDecoration(
                                    color: AppTheme.primaryPurple,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    _previewPlaying
                                        ? Icons.pause
                                        : Icons.play_arrow,
                                    color: Colors.white,
                                    size: 28,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                              const Text(
                                'Recording saved',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Duration: ${MomParser.formatDuration(_elapsed.inSeconds)}',
                                style: const TextStyle(
                                  color: AppTheme.secondaryGray,
                                ),
                              ),
                              const SizedBox(height: 20),
                              FilledButton(
                                onPressed: _uploadAndProcess,
                                style: FilledButton.styleFrom(
                                  minimumSize: const Size(double.infinity, 48),
                                  backgroundColor: AppTheme.primaryPurple,
                                ),
                                child: const Text('Upload & Generate MoM'),
                              ),
                              const SizedBox(height: 8),
                              TextButton(
                                onPressed: _discardRecording,
                                child: const Text('Discard & re-record'),
                              ),
                            ],
                          ),
                        ),
                      ],
                      if (!_isRecording && _recordedPath == null) ...[
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
              );
            },
          ),
        ),
    );
    if (Platform.isAndroid) {
      return WithForegroundTask(child: content);
    }
    return content;
  }
}
