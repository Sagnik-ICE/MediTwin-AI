import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class AppLogo extends StatelessWidget {
  const AppLogo({super.key, this.size = 72, this.showFallbackBackground = true});

  final double size;
  final bool showFallbackBackground;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Image.asset(
        'assets/app_logo/logo.png',
        width: size,
        height: size,
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) => _FallbackLogo(
          size: size,
          showBackground: showFallbackBackground,
        ),
      ),
    );
  }
}

class _FallbackLogo extends StatelessWidget {
  const _FallbackLogo({required this.size, required this.showBackground});

  final double size;
  final bool showBackground;

  @override
  Widget build(BuildContext context) {
    final iconSize = size * 0.48;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: showBackground ? AppTheme.brandGradient : null,
        color: showBackground ? null : AppTheme.primaryTeal,
        borderRadius: BorderRadius.circular(size * 0.18),
        boxShadow: AppTheme.softShadow(opacity: 0.10),
      ),
      child: Center(
        child: Icon(
          Icons.health_and_safety_rounded,
          size: iconSize,
          color: AppTheme.onBrand,
        ),
      ),
    );
  }
}
