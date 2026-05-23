import 'dart:convert';
import 'dart:typed_data';

import 'package:characters/characters.dart';
import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class DoctorPhoto extends StatelessWidget {
  const DoctorPhoto({
    super.key,
    required this.name,
    required this.imageUrl,
    this.size = 72,
    this.radius = 22,
  });

  final String name;
  final String imageUrl;
  final double size;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final fallback = _fallback();
    final source = imageUrl.trim();

    return SizedBox(
      width: size,
      height: size,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: source.isEmpty
            ? fallback
            : _isDataImage(source)
                ? _memoryImage(source, fallback)
                : Image.network(
                    source,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => fallback,
                  ),
      ),
    );
  }

  bool _isDataImage(String value) => value.startsWith('data:image/');

  Widget _memoryImage(String value, Widget fallback) {
    try {
      final commaIndex = value.indexOf(',');
      if (commaIndex == -1) return fallback;
      final bytes = base64Decode(value.substring(commaIndex + 1));
      return Image.memory(
        Uint8List.fromList(bytes),
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => fallback,
      );
    } catch (_) {
      return fallback;
    }
  }

  Widget _fallback() {
    final initials = _initials(name);
    return Container(
      alignment: Alignment.center,
      decoration: BoxDecoration(
        gradient: AppTheme.softBrandGradient,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: AppTheme.border),
      ),
      child: Text(
        initials,
        style: TextStyle(
          color: AppTheme.primaryBlue,
          fontWeight: FontWeight.w900,
          fontSize: size >= 80 ? 24 : 19,
        ),
      ),
    );
  }

  String _initials(String value) {
    final parts = value.trim().split(RegExp(r'\s+')).where((part) => part.isNotEmpty).take(2).toList();
    if (parts.isEmpty) return 'DR';
    return parts.map((part) => part.characters.first.toUpperCase()).join();
  }
}
