import 'package:flutter/material.dart';

class AnimatedCounterText extends StatelessWidget {
  final double value;
  final String suffix;
  final String prefix;
  final TextStyle? style;
  final int fractionDigits;

  const AnimatedCounterText({
    super.key,
    required this.value,
    this.suffix = '',
    this.prefix = '',
    this.style,
    this.fractionDigits = 1,
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: value, end: value),
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeOutCubic,
      builder: (context, animatedValue, child) {
        return Text(
          '$prefix${animatedValue.toStringAsFixed(fractionDigits)}$suffix',
          style: style,
        );
      },
    );
  }
}
