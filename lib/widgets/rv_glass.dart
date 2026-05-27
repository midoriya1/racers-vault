import 'package:flutter/material.dart';

import '../design/rv_colors.dart';

class RvGlass extends StatelessWidget {
  const RvGlass({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.borderColor,
    this.glowColor,
    this.radius = 22,
    this.clipBehavior = Clip.none,
    this.width,
    this.height,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? borderColor;
  final Color? glowColor;
  final double radius;
  final Clip clipBehavior;
  final double? width;
  final double? height;

  @override
  Widget build(BuildContext context) {
    final glow = glowColor;
    return Container(
      width: width,
      height: height,
      padding: padding,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0x1FFFFFFF), Color(0x08FFFFFF)],
        ),
        border: Border.all(color: borderColor ?? RvColors.border),
        boxShadow: [
          const BoxShadow(
            color: Color(0x99000000),
            blurRadius: 28,
            offset: Offset(0, 16),
          ),
          if (glow != null)
            BoxShadow(
              color: glow.withValues(alpha: 0.22),
              blurRadius: 34,
              spreadRadius: -8,
            ),
        ],
      ),
      clipBehavior: clipBehavior,
      child: child,
    );
  }
}
