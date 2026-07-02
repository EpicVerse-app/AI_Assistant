import 'package:flutter/material.dart';

import '../services/meeting_audio_controller.dart';
import '../theme/app_theme.dart';
import '../utils/mom_parser.dart';

class MeetingAudioPanel extends StatelessWidget {
  const MeetingAudioPanel({
    super.key,
    required this.controller,
    this.compact = false,
  });

  final MeetingAudioController controller;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        if (controller.loading) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!controller.available) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.audio_file_outlined,
                      size: 48, color: AppTheme.secondaryGray),
                  const SizedBox(height: 12),
                  Text(
                    controller.error ?? 'Audio not available',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: AppTheme.secondaryGray),
                  ),
                ],
              ),
            ),
          );
        }

        if (compact) {
          return MeetingAudioMiniBar(controller: controller);
        }

        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Expanded(child: _AudioCard(controller: controller)),
            ],
          ),
        );
      },
    );
  }
}

class MeetingAudioMiniBar extends StatelessWidget {
  const MeetingAudioMiniBar({super.key, required this.controller});

  final MeetingAudioController controller;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        return Container(
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: AppTheme.surfaceWhite,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppTheme.borderGray),
            boxShadow: const [
              BoxShadow(
                color: AppTheme.cardShadow,
                blurRadius: 8,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              GestureDetector(
                onTap: controller.togglePlayPause,
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: const BoxDecoration(
                    color: AppTheme.primaryPurple,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    controller.isPlaying ? Icons.pause : Icons.play_arrow,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _PlaybackControls(controller: controller, dense: true),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _AudioCard extends StatelessWidget {
  const _AudioCard({required this.controller});

  final MeetingAudioController controller;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: AppTheme.cardDecoration,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          GestureDetector(
            onTap: controller.togglePlayPause,
            child: Container(
              width: 72,
              height: 72,
              decoration: const BoxDecoration(
                color: AppTheme.primaryPurple,
                shape: BoxShape.circle,
              ),
              child: Icon(
                controller.isPlaying ? Icons.pause : Icons.play_arrow,
                color: Colors.white,
                size: 36,
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Meeting Audio',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
          ),
          if (controller.isLocal) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppTheme.primaryPurpleLight,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.phone_iphone,
                      size: 14, color: AppTheme.primaryPurple),
                  SizedBox(width: 4),
                  Text(
                    'Saved on this device',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.primaryPurple,
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 20),
          _PlaybackControls(controller: controller),
          const SizedBox(height: 12),
          _SpeedSelector(controller: controller),
          const SizedBox(height: 12),
          const _WaveformBars(),
        ],
      ),
    );
  }
}

class _PlaybackControls extends StatelessWidget {
  const _PlaybackControls({required this.controller, this.dense = false});

  final MeetingAudioController controller;
  final bool dense;

  String _fmt(Duration d) => MomParser.formatDuration(d.inSeconds);

  @override
  Widget build(BuildContext context) {
    final total = controller.duration.inSeconds > 0
        ? controller.duration
        : Duration.zero;
    final maxMs =
        total.inMilliseconds > 0 ? total.inMilliseconds.toDouble() : 1.0;
    final value = controller.position.inMilliseconds
        .clamp(0, maxMs.toInt())
        .toDouble();

    return Column(
      children: [
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: dense ? 2 : 3,
            thumbShape: RoundSliderThumbShape(
              enabledThumbRadius: dense ? 6 : 8,
            ),
            overlayShape: SliderComponentShape.noOverlay,
          ),
          child: Slider(
            value: value,
            max: maxMs,
            activeColor: AppTheme.primaryPurple,
            inactiveColor: AppTheme.borderGray,
            onChanged: total.inSeconds > 0
                ? (v) => controller.seek(Duration(milliseconds: v.toInt()))
                : null,
          ),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              _fmt(controller.position),
              style: TextStyle(
                fontSize: dense ? 11 : 13,
                color: AppTheme.secondaryGray,
              ),
            ),
            if (!dense)
              IconButton(
                onPressed: controller.togglePlayPause,
                icon: Icon(
                  controller.isPlaying ? Icons.pause_circle : Icons.play_circle,
                  color: AppTheme.primaryPurple,
                  size: 32,
                ),
              ),
            Text(
              _fmt(total),
              style: TextStyle(
                fontSize: dense ? 11 : 13,
                color: AppTheme.secondaryGray,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _SpeedSelector extends StatelessWidget {
  const _SpeedSelector({required this.controller});

  final MeetingAudioController controller;

  static const _speeds = [1.0, 1.25, 1.5, 1.75, 2.0];

  String _label(double s) => s == s.truncateToDouble() ? '${s.toInt()}x' : '${s}x';

  @override
  Widget build(BuildContext context) {
    final current = controller.speed;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text(
          'Speed',
          style: TextStyle(fontSize: 12, color: AppTheme.secondaryGray),
        ),
        const SizedBox(width: 10),
        ..._speeds.map((s) {
          final selected = (current - s).abs() < 0.01;
          return GestureDetector(
            onTap: () => controller.setSpeed(s),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              margin: const EdgeInsets.symmetric(horizontal: 3),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                gradient: selected
                    ? const LinearGradient(
                        colors: [Color(0xFF8D6736), Color(0xFFB18850)],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      )
                    : null,
                color: selected ? null : AppTheme.fillGray,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: selected
                      ? const Color(0xFF8D6736)
                      : AppTheme.borderGray,
                ),
              ),
              child: Text(
                _label(s),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: selected ? Colors.white : AppTheme.secondaryGray,
                ),
              ),
            ),
          );
        }),
      ],
    );
  }
}

class _WaveformBars extends StatelessWidget {
  const _WaveformBars();

  static const _heights = [
    0.4, 0.7, 0.5, 0.9, 0.6, 0.8, 0.4, 0.7, 0.5, 0.9,
    0.6, 0.5, 0.8, 0.4, 0.7, 0.6, 0.9, 0.5, 0.7, 0.4,
  ];

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 28,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (final h in _heights)
            Container(
              width: 3,
              height: 28 * h,
              margin: const EdgeInsets.symmetric(horizontal: 1),
              decoration: BoxDecoration(
                color: AppTheme.accentBlue.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
        ],
      ),
    );
  }
}
