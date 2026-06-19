import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class RecordConversationIllustration extends StatelessWidget {
  const RecordConversationIllustration({super.key, this.size = 280});

  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _RecordPainter(),
      ),
    );
  }
}

class _RecordPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);

    final glowPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          AppTheme.accentBlue.withValues(alpha: 0.12),
          Colors.transparent,
        ],
      ).createShader(Rect.fromCircle(center: center, radius: size.width * 0.48));

    canvas.drawCircle(center, size.width * 0.48, glowPaint);

    final cardRect = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(center.dx, center.dy + size.height * 0.06),
        width: size.width * 0.72,
        height: size.height * 0.42,
      ),
      const Radius.circular(24),
    );

    final cardPaint = Paint()
      ..color = AppTheme.fillGray
      ..style = PaintingStyle.fill;
    canvas.drawRRect(cardRect, cardPaint);

    final cardBorder = Paint()
      ..color = AppTheme.borderGray
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    canvas.drawRRect(cardRect, cardBorder);

    _drawWaveform(canvas, size, center);

    final micCenter = Offset(center.dx, center.dy - size.height * 0.18);
    final micPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF1D1D1F), Color(0xFF3A3A3C)],
      ).createShader(Rect.fromCircle(center: micCenter, radius: 44));

    canvas.drawCircle(micCenter, 44, micPaint);

    final micBody = RRect.fromRectAndRadius(
      Rect.fromCenter(center: micCenter + const Offset(0, -4), width: 18, height: 28),
      const Radius.circular(9),
    );
    canvas.drawRRect(micBody, Paint()..color = Colors.white);
    canvas.drawArc(
      Rect.fromCenter(center: micCenter + const Offset(0, 10), width: 30, height: 22),
      0,
      3.14,
      false,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawLine(
      micCenter + const Offset(0, 20),
      micCenter + const Offset(0, 30),
      Paint()
        ..color = Colors.white
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round,
    );

    _drawBubble(
      canvas,
      Offset(center.dx - size.width * 0.28, center.dy - size.height * 0.02),
      'Hello team',
      isLeft: true,
    );
    _drawBubble(
      canvas,
      Offset(center.dx + size.width * 0.22, center.dy + size.height * 0.1),
      'Great idea!',
      isLeft: false,
    );

    final dotPaint = Paint()..color = const Color(0xFFFF3B30);
    canvas.drawCircle(
      Offset(micCenter.dx + 30, micCenter.dy - 30),
      7,
      dotPaint,
    );
  }

  void _drawWaveform(Canvas canvas, Size size, Offset center) {
    final paint = Paint()
      ..color = AppTheme.accentBlue.withValues(alpha: 0.7)
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final baseY = center.dy + size.height * 0.14;
    final path = Path();
    for (var i = 0; i <= 24; i++) {
      final x = center.dx - size.width * 0.28 + i * (size.width * 0.56 / 24);
      final height = [8.0, 14, 22, 16, 28, 20, 32, 18, 26, 12, 24, 30][i % 12];
      final y1 = baseY - height / 2;
      final y2 = baseY + height / 2;
      canvas.drawLine(Offset(x, y1), Offset(x, y2), paint);
    }
    path.close();
  }

  void _drawBubble(Canvas canvas, Offset origin, String text, {required bool isLeft}) {
    final bubblePaint = Paint()..color = Colors.white;
    final rect = RRect.fromRectAndRadius(
      Rect.fromLTWH(origin.dx, origin.dy, 88, 34),
      const Radius.circular(14),
    );
    canvas.drawRRect(rect, bubblePaint);

    final border = Paint()
      ..color = AppTheme.borderGray
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    canvas.drawRRect(rect, border);

    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: const TextStyle(
          color: AppTheme.primaryBlack,
          fontSize: 11,
          fontWeight: FontWeight.w500,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, origin + const Offset(12, 9));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class AiMeetingsIllustration extends StatelessWidget {
  const AiMeetingsIllustration({super.key, this.size = 280});

  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _MeetingsPainter(),
      ),
    );
  }
}

class _MeetingsPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);

    final glowPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          const Color(0xFF5856D6).withValues(alpha: 0.1),
          Colors.transparent,
        ],
      ).createShader(Rect.fromCircle(center: center, radius: size.width * 0.5));
    canvas.drawCircle(center, size.width * 0.5, glowPaint);

    final cardRect = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(center.dx, center.dy + 10),
        width: size.width * 0.78,
        height: size.height * 0.52,
      ),
      const Radius.circular(26),
    );

    canvas.drawRRect(
      cardRect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white,
            AppTheme.fillGray,
          ],
        ).createShader(cardRect.outerRect),
    );
    canvas.drawRRect(
      cardRect,
      Paint()
        ..color = AppTheme.borderGray
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2,
    );

    _drawAvatarRow(canvas, Offset(center.dx, center.dy - size.height * 0.1));

    final brainCenter = Offset(center.dx, center.dy + size.height * 0.08);
    canvas.drawCircle(
      brainCenter,
      38,
      Paint()
        ..shader = const LinearGradient(
          colors: [Color(0xFF5856D6), Color(0xFF0071E3)],
        ).createShader(Rect.fromCircle(center: brainCenter, radius: 38)),
    );

    final sparkles = [
      Offset(brainCenter.dx - 18, brainCenter.dy - 10),
      Offset(brainCenter.dx + 14, brainCenter.dy + 6),
      Offset(brainCenter.dx - 4, brainCenter.dy + 16),
    ];
    for (final point in sparkles) {
      canvas.drawCircle(point, 3, Paint()..color = Colors.white.withValues(alpha: 0.9));
    }

    _drawInsightChip(canvas, Offset(center.dx - 90, center.dy + size.height * 0.2), 'Action items');
    _drawInsightChip(canvas, Offset(center.dx + 10, center.dy + size.height * 0.28), 'Key decisions');

    final linePaint = Paint()
      ..color = AppTheme.accentBlue.withValues(alpha: 0.35)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    canvas.drawLine(
      Offset(center.dx - 50, center.dy + size.height * 0.02),
      Offset(brainCenter.dx - 20, brainCenter.dy),
      linePaint,
    );
    canvas.drawLine(
      Offset(center.dx + 50, center.dy + size.height * 0.02),
      Offset(brainCenter.dx + 20, brainCenter.dy),
      linePaint,
    );
  }

  void _drawAvatarRow(Canvas canvas, Offset center) {
    final colors = [
      const Color(0xFFFF9500),
      const Color(0xFF34C759),
      const Color(0xFF007AFF),
      const Color(0xFFFF2D55),
    ];
    for (var i = 0; i < 4; i++) {
      final x = center.dx - 54 + i * 36.0;
      canvas.drawCircle(
        Offset(x, center.dy),
        16,
        Paint()..color = colors[i],
      );
      canvas.drawCircle(
        Offset(x, center.dy),
        16,
        Paint()
          ..color = Colors.white
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5,
      );
    }
  }

  void _drawInsightChip(Canvas canvas, Offset origin, String label) {
    final rect = RRect.fromRectAndRadius(
      Rect.fromLTWH(origin.dx, origin.dy, 96, 30),
      const Radius.circular(15),
    );
    canvas.drawRRect(rect, Paint()..color = Colors.white);
    canvas.drawRRect(
      rect,
      Paint()
        ..color = AppTheme.accentBlue.withValues(alpha: 0.25)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );

    final tp = TextPainter(
      text: TextSpan(
        text: label,
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: AppTheme.accentBlue,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, origin + Offset((96 - tp.width) / 2, 8));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class SearchMemoriesIllustration extends StatelessWidget {
  const SearchMemoriesIllustration({super.key, this.size = 280});

  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _SearchPainter(),
      ),
    );
  }
}

class _SearchPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);

    final glowPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          const Color(0xFF34C759).withValues(alpha: 0.1),
          Colors.transparent,
        ],
      ).createShader(Rect.fromCircle(center: center, radius: size.width * 0.5));
    canvas.drawCircle(center, size.width * 0.5, glowPaint);

    final cards = [
      _MemoryCardData(
        offset: Offset(center.dx - 70, center.dy - 30),
        width: 130,
        height: 72,
        title: 'Q3 Planning',
        subtitle: 'Mar 12 · 45 min',
        color: const Color(0xFFE8F1FF),
      ),
      _MemoryCardData(
        offset: Offset(center.dx + 10, center.dy - 10),
        width: 130,
        height: 72,
        title: 'Product Review',
        subtitle: 'Mar 8 · 32 min',
        color: const Color(0xFFF2ECFF),
      ),
      _MemoryCardData(
        offset: Offset(center.dx - 40, center.dy + 58),
        width: 130,
        height: 72,
        title: 'Client Call',
        subtitle: 'Mar 5 · 28 min',
        color: const Color(0xFFE9F9EE),
        highlighted: true,
      ),
    ];

    for (final card in cards) {
      _drawMemoryCard(canvas, card);
    }

    final lensCenter = Offset(center.dx + 72, center.dy + 18);
    canvas.drawCircle(
      lensCenter,
      34,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.fill,
    );
    canvas.drawCircle(
      lensCenter,
      34,
      Paint()
        ..color = AppTheme.primaryBlack
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );
    canvas.drawCircle(
      lensCenter,
      24,
      Paint()
        ..color = AppTheme.accentBlue.withValues(alpha: 0.15)
        ..style = PaintingStyle.fill,
    );

    final handlePaint = Paint()
      ..color = AppTheme.primaryBlack
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      lensCenter + const Offset(22, 22),
      lensCenter + const Offset(42, 42),
      handlePaint,
    );

    _drawSearchBar(canvas, Offset(center.dx - size.width * 0.34, center.dy - size.height * 0.34));
  }

  void _drawMemoryCard(Canvas canvas, _MemoryCardData card) {
    final rect = RRect.fromRectAndRadius(
      Rect.fromLTWH(card.offset.dx, card.offset.dy, card.width, card.height),
      const Radius.circular(16),
    );

    canvas.drawRRect(rect, Paint()..color = card.color);
    if (card.highlighted) {
      canvas.drawRRect(
        rect,
        Paint()
          ..color = const Color(0xFF34C759)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
    } else {
      canvas.drawRRect(
        rect,
        Paint()
          ..color = AppTheme.borderGray
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1,
      );
    }

    final titlePainter = TextPainter(
      text: TextSpan(
        text: card.title,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: AppTheme.primaryBlack.withValues(alpha: card.highlighted ? 1 : 0.85),
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: card.width - 20);
    titlePainter.paint(canvas, card.offset + const Offset(12, 14));

    final subPainter = TextPainter(
      text: TextSpan(
        text: card.subtitle,
        style: const TextStyle(
          fontSize: 10,
          color: AppTheme.secondaryGray,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    subPainter.paint(canvas, card.offset + const Offset(12, 36));
  }

  void _drawSearchBar(Canvas canvas, Offset origin) {
    final rect = RRect.fromRectAndRadius(
      Rect.fromLTWH(origin.dx, origin.dy, 200, 40),
      const Radius.circular(20),
    );
    canvas.drawRRect(rect, Paint()..color = Colors.white);
    canvas.drawRRect(
      rect,
      Paint()
        ..color = AppTheme.borderGray
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2,
    );

    final tp = TextPainter(
      text: const TextSpan(
        text: 'Search memories...',
        style: TextStyle(
          fontSize: 12,
          color: AppTheme.secondaryGray,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, origin + const Offset(16, 11));

    canvas.drawCircle(
      origin + const Offset(176, 20),
      6,
      Paint()..color = AppTheme.accentBlue.withValues(alpha: 0.5),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _MemoryCardData {
  _MemoryCardData({
    required this.offset,
    required this.width,
    required this.height,
    required this.title,
    required this.subtitle,
    required this.color,
    this.highlighted = false,
  });

  final Offset offset;
  final double width;
  final double height;
  final String title;
  final String subtitle;
  final Color color;
  final bool highlighted;
}
