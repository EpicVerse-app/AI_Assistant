import 'dart:async';

import 'package:flutter/material.dart';

import '../models/meeting.dart';
import '../services/api_service.dart';
import '../services/folder_service.dart';
import '../theme/app_theme.dart';
import 'mom_result_screen.dart';

enum _Step { transcribing, translating, generating, done, failed }

class ProcessingScreen extends StatefulWidget {
  const ProcessingScreen({super.key, required this.meetingId, this.folderId});

  final String meetingId;
  final String? folderId;

  @override
  State<ProcessingScreen> createState() => _ProcessingScreenState();
}

class _ProcessingScreenState extends State<ProcessingScreen> {
  _Step _step = _Step.transcribing;
  String? _errorMessage;
  Meeting? _meeting;

  @override
  void initState() {
    super.initState();
    _runPipeline();
  }

  Future<void> _runPipeline() async {
    try {
      setState(() => _step = _Step.transcribing);
      final meeting = await ApiService.pollTranscription(widget.meetingId);

      if (meeting.isFailed) {
        setState(() {
          _step = _Step.failed;
          _errorMessage = meeting.errorMessage ??
              'Processing failed. No speech was detected or the server could not finish.';
        });
        return;
      }

      // Backend pipeline already created transcript, translation, and MoM in folder.
      setState(() => _step = _Step.translating);
      final fullMeeting = await ApiService.getMeetingDetail(widget.meetingId);

      setState(() => _step = _Step.generating);
      await Future<void>.delayed(const Duration(milliseconds: 400));

      setState(() {
        _step = _Step.done;
        _meeting = fullMeeting;
      });

      // Auto-save to folder if recording was started from inside a folder
      if (widget.folderId != null) {
        await FolderService.instance
            .addMeeting(widget.folderId!, widget.meetingId);
      }

      if (mounted) {
        await Future<void>.delayed(const Duration(milliseconds: 600));
        Navigator.of(context).pushReplacement(
          MaterialPageRoute<void>(
            builder: (_) => MomResultScreen(meeting: fullMeeting),
          ),
        );
      }
    } catch (e) {
      setState(() {
        _step = _Step.failed;
        _errorMessage = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('Processing'),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: _step == _Step.failed
              ? Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline,
                        size: 56, color: Color(0xFFFF3B30)),
                    const SizedBox(height: 16),
                    const Text(
                      'Something went wrong',
                      style: TextStyle(
                          fontSize: 18, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _errorMessage ?? 'Unknown error',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          color: AppTheme.secondaryGray, fontSize: 14),
                    ),
                    const SizedBox(height: 32),
                    FilledButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Go Back'),
                    ),
                  ],
                )
              : Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(
                      width: 56,
                      height: 56,
                      child: CircularProgressIndicator(strokeWidth: 3),
                    ),
                    const SizedBox(height: 32),
                    _StepRow(
                      label: 'Transcribing audio',
                      state: _stepState(_Step.transcribing),
                    ),
                    _StepRow(
                      label: 'Translating to English',
                      state: _stepState(_Step.translating),
                    ),
                    _StepRow(
                      label: 'Generating meeting minutes',
                      state: _stepState(_Step.generating),
                    ),
                    _StepRow(
                      label: 'Done',
                      state: _stepState(_Step.done),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  _StepState _stepState(_Step step) {
    final current = _step.index;
    final target = step.index;
    if (current > target) return _StepState.done;
    if (current == target) return _StepState.active;
    return _StepState.pending;
  }
}

enum _StepState { pending, active, done }

class _StepRow extends StatelessWidget {
  const _StepRow({required this.label, required this.state});

  final String label;
  final _StepState state;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          SizedBox(
            width: 24,
            height: 24,
            child: switch (state) {
              _StepState.done => const Icon(Icons.check_circle_rounded,
                  color: Color(0xFF34C759), size: 24),
              _StepState.active => const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2.5),
                ),
              _StepState.pending => const Icon(Icons.radio_button_unchecked,
                  color: AppTheme.borderGray, size: 24),
            },
          ),
          const SizedBox(width: 12),
          Text(
            label,
            style: TextStyle(
              fontSize: 16,
              color: state == _StepState.pending
                  ? AppTheme.secondaryGray
                  : AppTheme.primaryBlack,
              fontWeight: state == _StepState.active
                  ? FontWeight.w600
                  : FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }
}
