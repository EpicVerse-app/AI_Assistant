import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class LiveWaveform extends StatefulWidget {
  const LiveWaveform({
    super.key,
    required this.isAnimating,
    this.barCount = 48,
    this.height = 120,
    this.color = AppTheme.primaryBlack,
  });

  final bool isAnimating;
  final int barCount;
  final double height;
  final Color color;

  @override
  State<LiveWaveform> createState() => _LiveWaveformState();
}

class _LiveWaveformState extends State<LiveWaveform>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final math.Random _random;
  late List<double> _amplitudes;

  @override
  void initState() {
    super.initState();
    _random = math.Random();
    _amplitudes = List<double>.generate(
      widget.barCount,
      (_) => 0.08 + _random.nextDouble() * 0.06,
    );
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..addListener(_tick);
    if (widget.isAnimating) _controller.repeat();
  }

  @override
  void didUpdateWidget(LiveWaveform oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isAnimating && !_controller.isAnimating) {
      _controller.repeat();
    } else if (!widget.isAnimating && _controller.isAnimating) {
      _controller.stop();
    }
  }

  void _tick() {
    if (!widget.isAnimating) return;
    setState(() {
      _amplitudes.removeAt(0);
      final previous = _amplitudes.last;
      final next = (previous + (_random.nextDouble() - 0.5) * 0.35)
          .clamp(0.06, 1.0);
      _amplitudes.add(next);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: widget.height,
      width: double.infinity,
      child: CustomPaint(
        painter: _WaveformPainter(
          amplitudes: _amplitudes,
          color: widget.color,
          phase: _controller.value,
          isAnimating: widget.isAnimating,
        ),
      ),
    );
  }
}

class _WaveformPainter extends CustomPainter {
  _WaveformPainter({
    required this.amplitudes,
    required this.color,
    required this.phase,
    required this.isAnimating,
  });

  final List<double> amplitudes;
  final Color color;
  final double phase;
  final bool isAnimating;

  @override
  void paint(Canvas canvas, Size size) {
    final barWidth = size.width / amplitudes.length;
    final gap = barWidth * 0.28;
    final paint = Paint()
      ..color = color
      ..strokeCap = StrokeCap.round
      ..strokeWidth = barWidth - gap;

    for (var i = 0; i < amplitudes.length; i++) {
      final amp = amplitudes[i];
      final pulse = isAnimating
          ? 0.85 + math.sin((i * 0.35) + phase * math.pi * 2) * 0.15
          : 0.7;
      final barHeight = (amp * pulse * size.height).clamp(4.0, size.height);
      final x = i * barWidth + barWidth / 2;
      final y1 = (size.height - barHeight) / 2;
      final y2 = y1 + barHeight;
      canvas.drawLine(Offset(x, y1), Offset(x, y2), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _WaveformPainter oldDelegate) {
    return oldDelegate.amplitudes != amplitudes ||
        oldDelegate.phase != phase ||
        oldDelegate.isAnimating != isAnimating;
  }
}
