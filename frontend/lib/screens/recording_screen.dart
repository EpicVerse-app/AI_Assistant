import 'dart:async';
import 'dart:io';
import 'dart:math';

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
  const RecordingScreen({super.key, this.folderId});

  final String? folderId;

  @override
  State<RecordingScreen> createState() => _RecordingScreenState();
}

class _RecordingScreenState extends State<RecordingScreen> {
  final BackgroundRecordingService _recordingService =
      BackgroundRecordingService.instance;
  final AudioPlayer _previewPlayer = AudioPlayer();
  bool _isRecording = false;
  bool _isPaused = false;
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
        _isPaused = false;
        _recordedPath = null;
        _elapsed = Duration.zero;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(event['message']?.toString() ?? 'Recording error')),
      );
    } else if (type == 'started' && mounted) {
      setState(() {
        _isRecording = true;
        _isPaused = false;
      });
    } else if (type == 'paused' && mounted) {
      setState(() => _isPaused = true);
    } else if (type == 'resumed' && mounted) {
      setState(() => _isPaused = false);
    }
  }

  Future<void> _handleRecordingStopped(String? path) async {
    await Future.delayed(const Duration(milliseconds: 400));
    if (!mounted) return;
    setState(() {
      _isRecording = false;
      _isPaused = false;
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
      _isPaused = false;
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

  Future<void> _togglePause() async {
    try {
      if (_isPaused) {
        await _recordingService.resume();
      } else {
        await _recordingService.pause();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not update recording: $e')),
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
            builder: (_) => ProcessingScreen(meetingId: meetingId, folderId: widget.folderId),
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
            builder: (_) => ProcessingScreen(meetingId: meetingId, folderId: widget.folderId),
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
                                        ? (_isPaused ? 'Paused' : 'Recording...')
                                        : 'Ready to record',
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      fontSize: 15,
                                      color: AppTheme.secondaryGray,
                                    ),
                                  ),
                                  if (_isRecording) ...[
                                    const SizedBox(height: 24),
                                    _RecordingWaveform(isActive: !_isPaused),
                                  ],
                                  const SizedBox(height: 56),
                                  if (_isRecording)
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        _RoundIconButton(
                                          onTap: _togglePause,
                                          icon: _isPaused
                                              ? Icons.play_arrow_rounded
                                              : Icons.pause_rounded,
                                          label: _isPaused ? 'Resume' : 'Pause',
                                        ),
                                        const SizedBox(width: 40),
                                        _RoundIconButton(
                                          onTap: _stopRecording,
                                          icon: Icons.stop_rounded,
                                          label: 'Stop',
                                        ),
                                      ],
                                    )
                                  else
                                    _RoundIconButton(
                                      onTap: _recordedPath == null
                                          ? _startRecording
                                          : null,
                                      icon: Icons.mic_rounded,
                                      label: _recordedPath != null
                                          ? 'Review your recording below'
                                          : 'Tap the mic to start recording',
                                    ),
                                ],
                              ),
                            ),
                            if (_recordedPath != null && !_isRecording) ...[
                        const SizedBox(height: 32),
                        _SlideUpFadeIn(
                          key: ValueKey(_recordedPath),
                          child: Container(
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
                                      gradient: AppTheme.addButtonGradient,
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
                                GestureDetector(
                                  onTap: _uploadAndProcess,
                                  child: Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 14),
                                    decoration: BoxDecoration(
                                      gradient: AppTheme.addButtonGradient,
                                      borderRadius: BorderRadius.circular(14),
                                      boxShadow: [
                                        BoxShadow(
                                          color: AppTheme.addButtonStart
                                              .withValues(alpha: 0.4),
                                          blurRadius: 8,
                                          offset: const Offset(0, 3),
                                        ),
                                      ],
                                    ),
                                    child: const Text(
                                      'Upload & Generate MoM',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontSize: 17,
                                        fontWeight: FontWeight.w600,
                                        letterSpacing: -0.2,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                TextButton(
                                  onPressed: _discardRecording,
                                  style: TextButton.styleFrom(
                                    foregroundColor: AppTheme.addButtonStart,
                                  ),
                                  child: const Text('Discard & re-record'),
                                ),
                              ],
                            ),
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

/// Slides its child up from below while fading it in — used to animate the
/// "Recording saved" card into view once a recording is ready for review.
class _SlideUpFadeIn extends StatefulWidget {
  const _SlideUpFadeIn({super.key, required this.child});

  final Widget child;

  @override
  State<_SlideUpFadeIn> createState() => _SlideUpFadeInState();
}

class _SlideUpFadeInState extends State<_SlideUpFadeIn>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<Offset> _offset;
  late final Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 520),
    );
    _offset = Tween<Offset>(
      begin: const Offset(0, 0.55),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutBack));
    _fade = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
    );
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SlideTransition(
      position: _offset,
      child: FadeTransition(opacity: _fade, child: widget.child),
    );
  }
}

/// A dark circular icon button with a small caption beneath it, matching
/// the mic / pause / stop controls on the recording screen.
class _RoundIconButton extends StatelessWidget {
  const _RoundIconButton({
    required this.onTap,
    required this.icon,
    required this.label,
  });

  final VoidCallback? onTap;
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 76,
            height: 76,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: AppTheme.gradientBottom,
            ),
            child: Icon(icon, color: Colors.white, size: 34),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          label,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 14,
            color: AppTheme.secondaryGray,
          ),
        ),
      ],
    );
  }
}

/// Animated bar waveform shown while a recording is in progress.
/// Freezes (and dims) when [isActive] is false, e.g. while paused.
class _RecordingWaveform extends StatefulWidget {
  const _RecordingWaveform({required this.isActive});

  final bool isActive;

  @override
  State<_RecordingWaveform> createState() => _RecordingWaveformState();
}

class _RecordingWaveformState extends State<_RecordingWaveform>
    with SingleTickerProviderStateMixin {
  static const _barCount = 27;

  late final AnimationController _controller;
  late final List<double> _phases;
  late final List<double> _speeds;

  @override
  void initState() {
    super.initState();
    final random = Random();
    _phases = List.generate(_barCount, (_) => random.nextDouble() * 2 * pi);
    _speeds = List.generate(_barCount, (_) => 0.7 + random.nextDouble() * 0.9);
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    );
    if (widget.isActive) _controller.repeat();
  }

  @override
  void didUpdateWidget(covariant _RecordingWaveform oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive && !_controller.isAnimating) {
      _controller.repeat();
    } else if (!widget.isActive && _controller.isAnimating) {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const height = 48.0;
    return SizedBox(
      height: height,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final t = _controller.value * 2 * pi;
          return Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: List.generate(_barCount, (i) {
              final wave = widget.isActive
                  ? (sin(t * _speeds[i] + _phases[i]) + 1) / 2
                  : 0.0;
              final heightFactor = widget.isActive ? 0.18 + 0.82 * wave : 0.12;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                width: 3,
                height: (height * heightFactor).clamp(4.0, height),
                margin: const EdgeInsets.symmetric(horizontal: 2.5),
                decoration: BoxDecoration(
                  color: AppTheme.addButtonStart
                      .withValues(alpha: widget.isActive ? 0.9 : 0.3),
                  borderRadius: BorderRadius.circular(4),
                ),
              );
            }),
          );
        },
      ),
    );
  }
}
