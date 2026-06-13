import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class SmoothPageIndicator extends StatelessWidget {
  const SmoothPageIndicator({
    super.key,
    required this.count,
    required this.currentPage,
    this.activeWidth = 28,
    this.dotSize = 8,
    this.spacing = 8,
  });

  final int count;
  final double currentPage;
  final double activeWidth;
  final double dotSize;
  final double spacing;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(count, (index) {
        final distance = (currentPage - index).abs().clamp(0.0, 1.0);
        final width = dotSize + (activeWidth - dotSize) * (1 - distance);
        final color = Color.lerp(
          AppTheme.borderGray,
          AppTheme.primaryBlack,
          1 - distance,
        )!;

        return AnimatedContainer(
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOutCubic,
          margin: EdgeInsets.symmetric(horizontal: spacing / 2),
          width: width,
          height: dotSize,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(dotSize / 2),
          ),
        );
      }),
    );
  }
}
