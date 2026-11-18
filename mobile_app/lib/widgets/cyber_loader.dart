import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class CyberOrbitalLoader extends StatefulWidget {
  final double size;
  final Color primaryColor;
  final Color secondaryColor;
  final String? label;

  const CyberOrbitalLoader({
    super.key,
    this.size = 56.0,
    this.primaryColor = AppColors.berry,
    this.secondaryColor = AppColors.cyan,
    this.label,
  });

  @override
  State<CyberOrbitalLoader> createState() => _CyberOrbitalLoaderState();
}

class _CyberOrbitalLoaderState extends State<CyberOrbitalLoader> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return CustomPaint(
              size: Size(widget.size, widget.size),
              painter: _OrbitalPainter(
                progress: _controller.value,
                primaryColor: widget.primaryColor,
                secondaryColor: widget.secondaryColor,
              ),
            );
          },
        ),
        if (widget.label != null) ...[
          const SizedBox(height: 16),
          Text(
            widget.label!,
            style: TextStyle(
              color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
              fontSize: 13,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ],
    );
  }
}

class _OrbitalPainter extends CustomPainter {
  final double progress;
  final Color primaryColor;
  final Color secondaryColor;

  _OrbitalPainter({
    required this.progress,
    required this.primaryColor,
    required this.secondaryColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final outerRadius = size.width / 2;
    final innerRadius = size.width / 3.2;

    // Outer Arc (Clockwise)
    final outerPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0
      ..strokeCap = StrokeCap.round
      ..shader = SweepGradient(
        colors: [Colors.transparent, primaryColor],
        stops: const [0.2, 1.0],
        transform: GradientRotation(progress * 2 * math.pi),
      ).createShader(Rect.fromCircle(center: center, radius: outerRadius));

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: outerRadius),
      progress * 2 * math.pi,
      math.pi * 1.5,
      false,
      outerPaint,
    );

    // Inner Arc (Counter-Clockwise)
    final innerPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4
      ..strokeCap = StrokeCap.round
      ..shader = SweepGradient(
        colors: [Colors.transparent, secondaryColor],
        stops: const [0.3, 1.0],
        transform: GradientRotation(-progress * 2 * math.pi),
      ).createShader(Rect.fromCircle(center: center, radius: innerRadius));

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: innerRadius),
      -progress * 2 * math.pi,
      math.pi * 1.3,
      false,
      innerPaint,
    );

    // Center Pulsing Core
    final pulseScale = 0.8 + 0.3 * math.sin(progress * 2 * math.pi);
    final corePaint = Paint()
      ..color = primaryColor.withOpacity(0.85)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, 3.5 * pulseScale, corePaint);
  }

  @override
  bool shouldRepaint(covariant _OrbitalPainter oldDelegate) => true;
}

/// Cyber Shimmer Skeleton Loader
class CyberShimmer extends StatefulWidget {
  final double width;
  final double height;
  final BorderRadius? borderRadius;

  const CyberShimmer({
    super.key,
    required this.width,
    required this.height,
    this.borderRadius,
  });

  @override
  State<CyberShimmer> createState() => _CyberShimmerState();
}

class _CyberShimmerState extends State<CyberShimmer> with SingleTickerProviderStateMixin {
  late AnimationController _shimmerController;

  @override
  void initState() {
    super.initState();
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
  }

  @override
  void dispose() {
    _shimmerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final baseColor = isDark ? const Color(0xFF141926) : const Color(0xFFE2E8F0);
    final highlightColor = isDark ? const Color(0xFF222B3F) : const Color(0xFFF1F5F9);

    return AnimatedBuilder(
      animation: _shimmerController,
      builder: (context, child) {
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: widget.borderRadius ?? BorderRadius.circular(10),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [baseColor, highlightColor, baseColor],
              stops: [
                math.max(0.0, _shimmerController.value - 0.3),
                _shimmerController.value,
                math.min(1.0, _shimmerController.value + 0.3),
              ],
            ),
          ),
        );
      },
    );
  }
}
