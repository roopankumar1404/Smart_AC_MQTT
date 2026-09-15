import 'package:flutter/material.dart';
import '../../core/colors.dart';

class GlassCard extends StatelessWidget {
  final Widget child;
  final Color? glowColor;
  final EdgeInsetsGeometry padding;

  const GlassCard({
    super.key,
    required this.child,
    this.glowColor,
    this.padding = const EdgeInsets.all(20),
  });

  @override
  Widget build(BuildContext context) {
    final activeGlow = glowColor ?? AppColors.primary;
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: AppColors.glassSurface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: AppColors.isLight
              ? activeGlow.withValues(alpha: 0.3)
              : activeGlow.withValues(alpha: 0.18),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: activeGlow.withValues(alpha: AppColors.isLight ? 0.10 : 0.15),
            blurRadius: 20,
            spreadRadius: 1,
          ),
        ],
      ),
      child: child,
    );
  }
}