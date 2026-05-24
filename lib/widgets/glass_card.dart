import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class GlassCard extends StatelessWidget {
  const GlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.margin = EdgeInsets.zero,
    this.backgroundColor,
    this.borderColor,
    this.radius = AppTheme.radiusLg,
    this.elevated = true,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry margin;
  final Color? backgroundColor;
  final Color? borderColor;
  final double radius;
  final bool elevated;

  @override
  Widget build(BuildContext context) {
    final effectiveBackground = backgroundColor ?? AppTheme.surface;
    final effectiveBorder = borderColor ?? AppTheme.border;

    return Container(
      margin: margin,
      decoration: BoxDecoration(
        color: effectiveBackground,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: effectiveBorder),
        boxShadow: elevated ? AppTheme.softShadow(opacity: 0.06) : null,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: Material(
          type: MaterialType.transparency,
          child: Padding(
            padding: padding,
            child: child,
          ),
        ),
      ),
    );
  }
}
