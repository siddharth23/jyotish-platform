import 'package:flutter/material.dart';

import '../theme/app_theme_extension.dart';
import '../tokens/app_typography.dart';

/// A circular identity mark.
///
/// Falls back to initials when there is no image, which is the normal case for
/// astrologers who have not uploaded a photo. Initials are derived from the name
/// rather than stored, and the full name is what gets announced — "SK" is not
/// useful to a screen reader.
class AppAvatar extends StatelessWidget {
  const AppAvatar({
    required this.name,
    this.imageUrl,
    this.size = 40,
    super.key,
  });

  final String name;
  final String? imageUrl;
  final double size;

  /// First letters of the first and last name parts, upper-cased.
  static String initialsOf(String name) {
    final parts =
        name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.characters.first.toUpperCase();
    return (parts.first.characters.first + parts.last.characters.first)
        .toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Semantics(
      label: name,
      image: imageUrl != null,
      excludeSemantics: true,
      child: Container(
        width: size,
        height: size,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: colors.primaryContainer,
          shape: BoxShape.circle,
        ),
        child: imageUrl != null
            ? Image.network(
                imageUrl!,
                fit: BoxFit.cover,
                // A broken avatar should degrade to initials, not a broken-image
                // glyph next to someone's name.
                errorBuilder: (context, error, stack) => _Initials(
                  name: name,
                  size: size,
                  color: colors.onPrimaryContainer,
                ),
              )
            : _Initials(
                name: name,
                size: size,
                color: colors.onPrimaryContainer,
              ),
      ),
    );
  }
}

class _Initials extends StatelessWidget {
  const _Initials(
      {required this.name, required this.size, required this.color});

  final String name;
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) => Center(
        child: Text(
          AppAvatar.initialsOf(name),
          style: AppTypography.labelSmall.copyWith(
            color: color,
            fontSize: size * 0.36,
          ),
        ),
      );
}
