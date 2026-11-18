import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class StatusPill extends StatefulWidget {
  final bool isOnline;
  final String label;
  final bool isTailscale;
  final VoidCallback? onTap;

  const StatusPill({
    super.key,
    required this.isOnline,
    required this.label,
    this.isTailscale = false,
    this.onTap,
  });

  @override
  State<StatusPill> createState() => _StatusPillState();
}

class _StatusPillState extends State<StatusPill> with SingleTickerProviderStateMixin {
  late AnimationController _pulseCtrl;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final activeColor = widget.isOnline
        ? (widget.isTailscale ? AppColors.cyan : AppColors.emerald)
        : const Color(0xFFEF4444);

    return InkWell(
      onTap: widget.onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: activeColor.withOpacity(isDark ? 0.12 : 0.08),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: activeColor.withOpacity(isDark ? 0.35 : 0.25),
            width: 1.0,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Breathing Pulsing Dot
            AnimatedBuilder(
              animation: _pulseCtrl,
              builder: (context, child) {
                final scale = widget.isOnline ? 0.8 + 0.35 * _pulseCtrl.value : 1.0;
                final glowOpacity = widget.isOnline ? 0.4 + 0.5 * _pulseCtrl.value : 0.2;

                return Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: activeColor,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: activeColor.withOpacity(glowOpacity),
                        blurRadius: 6 * scale,
                        spreadRadius: 1.5 * scale,
                      ),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(width: 7),
            Text(
              widget.label,
              style: TextStyle(
                color: activeColor,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
