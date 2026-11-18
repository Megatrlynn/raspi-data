import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';
import 'cyber_loader.dart';

class BouncingButton extends StatefulWidget {
  final Widget? child;
  final String? label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final bool isLoading;
  final Color? backgroundColor;
  final Gradient? gradient;
  final Color? textColor;
  final Color? borderColor;
  final double height;
  final double? width;
  final BorderRadius? borderRadius;
  final Duration debounceDuration;
  final bool isSecondary;

  const BouncingButton({
    super.key,
    this.child,
    this.label,
    this.icon,
    required this.onPressed,
    this.isLoading = false,
    this.backgroundColor,
    this.gradient,
    this.textColor,
    this.borderColor,
    this.height = 50,
    this.width,
    this.borderRadius,
    this.debounceDuration = const Duration(milliseconds: 500),
    this.isSecondary = false,
  });

  @override
  State<BouncingButton> createState() => _BouncingButtonState();
}

class _BouncingButtonState extends State<BouncingButton> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  int _lastClickTime = 0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
      reverseDuration: const Duration(milliseconds: 140),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.94).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOutCubic),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleTap() {
    if (widget.onPressed == null || widget.isLoading) return;

    // Debouncing mechanism: ignore if triggered within debounceDuration
    final now = DateTime.now().millisecondsSinceEpoch;
    if (now - _lastClickTime < widget.debounceDuration.inMilliseconds) {
      return;
    }
    _lastClickTime = now;

    HapticFeedback.lightImpact();
    widget.onPressed!();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final defaultBg = widget.isSecondary
        ? (isDark ? AppColors.darkSurfaceElevated : AppColors.lightSurfaceElevated)
        : AppColors.berry;
    final defaultBorder = widget.borderColor ??
        (widget.isSecondary
            ? (isDark ? AppColors.darkBorder : AppColors.lightBorder)
            : Colors.transparent);
    final effectiveTextColor = widget.textColor ??
        (widget.isSecondary
            ? (isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary)
            : Colors.white);

    return AnimatedBuilder(
      animation: _scaleAnimation,
      builder: (context, child) => Transform.scale(
        scale: _scaleAnimation.value,
        child: child,
      ),
      child: GestureDetector(
        onTapDown: (_) {
          if (!widget.isLoading && widget.onPressed != null) {
            _controller.forward();
          }
        },
        onTapUp: (_) => _controller.reverse(),
        onTapCancel: () => _controller.reverse(),
        onTap: _handleTap,
        child: Container(
          height: widget.height,
          width: widget.width,
          decoration: BoxDecoration(
            color: widget.gradient == null ? (widget.backgroundColor ?? defaultBg) : null,
            gradient: widget.gradient ?? (!widget.isSecondary && widget.backgroundColor == null ? AppColors.berryGradient : null),
            borderRadius: widget.borderRadius ?? BorderRadius.circular(14),
            border: Border.all(color: defaultBorder, width: 1.2),
            boxShadow: !widget.isSecondary && widget.onPressed != null
                ? [
                    BoxShadow(
                      color: AppColors.berryGlow.withOpacity(isDark ? 0.35 : 0.25),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 18),
          alignment: Alignment.center,
          child: widget.isLoading
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.4,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : (widget.child ??
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (widget.icon != null) ...[
                        Icon(widget.icon, size: 18, color: effectiveTextColor),
                        const SizedBox(width: 8),
                      ],
                      if (widget.label != null)
                        Text(
                          widget.label!,
                          style: TextStyle(
                            color: effectiveTextColor,
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.3,
                          ),
                        ),
                    ],
                  )),
        ),
      ),
    );
  }
}
