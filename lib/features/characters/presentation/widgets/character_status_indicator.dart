import 'package:flutter/material.dart';

import '../../domain/character.dart';
import '../../domain/custom_status.dart';

/// Display-side value capturing how to render a status, regardless of
/// whether it's a built-in [CharacterStatus] or a user-defined
/// [CustomStatus]. Built once at the boundary by [statusDisplayFor]
/// so every dot / label / bar agrees on the rendering.
class StatusDisplay {
  const StatusDisplay({
    required this.label,
    required this.color,
    this.builtIn,
    this.customId,
  });

  final String label;
  final Color color;

  /// Set when the underlying status is a built-in enum value.
  final CharacterStatus? builtIn;

  /// Set when the underlying status is a custom row id.
  final int? customId;

  bool get isCustom => customId != null;
}

/// Resolves a (builtIn, customId) pair to a [StatusDisplay]. Falls
/// back to the built-in when a referenced custom row no longer exists
/// (e.g. the user deleted it after attaching it to an entry).
StatusDisplay statusDisplayFor({
  required CharacterStatus builtIn,
  required int? customId,
  required List<CustomStatus> customs,
}) {
  if (customId != null) {
    for (final c in customs) {
      if (c.id == customId) {
        return StatusDisplay(
          label: c.name,
          color: Color(c.colorArgb),
          customId: c.id,
        );
      }
    }
  }
  return StatusDisplay(
    label: _builtInLabel(builtIn),
    color: _builtInColor(builtIn),
    builtIn: builtIn,
  );
}

Color _builtInColor(CharacterStatus s) {
  switch (s) {
    case CharacterStatus.alive:
      return const Color(0xFF2E7D32); // green
    case CharacterStatus.dead:
      return const Color(0xFFC62828); // red
    case CharacterStatus.missing:
      return const Color(0xFFEF6C00); // orange
    case CharacterStatus.unknown:
      return const Color(0xFF757575); // grey
  }
}

String _builtInLabel(CharacterStatus s) {
  switch (s) {
    case CharacterStatus.alive:
      return 'Alive';
    case CharacterStatus.dead:
      return 'Dead';
    case CharacterStatus.missing:
      return 'Missing';
    case CharacterStatus.unknown:
      return 'Unknown';
  }
}

/// Public access to the built-in lookups for screens that don't have a
/// resolved [StatusDisplay] yet (e.g. while customs are still loading).
Color builtInStatusColor(CharacterStatus s) => _builtInColor(s);
String builtInStatusLabel(CharacterStatus s) => _builtInLabel(s);

/// Small colored dot. Accepts either an explicit [Color] or a built-in
/// [CharacterStatus]; legacy callers still pass the enum and are
/// rendered with the built-in palette.
class CharacterStatusDot extends StatelessWidget {
  const CharacterStatusDot({
    super.key,
    this.status,
    this.color,
    this.label,
    this.size = 10,
  }) : assert(status != null || color != null,
            'Provide either a status enum or an explicit color.');

  /// Built-in status — used when [color] isn't set, falling back to
  /// the built-in palette.
  final CharacterStatus? status;

  /// Explicit color override (custom statuses pass this).
  final Color? color;

  /// Tooltip override; defaults to the built-in label when [status]
  /// is set.
  final String? label;

  final double size;

  @override
  Widget build(BuildContext context) {
    final c = color ?? _builtInColor(status!);
    final l = label ?? (status != null ? _builtInLabel(status!) : '');
    return Tooltip(
      message: l,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: c,
          shape: BoxShape.circle,
          border: Border.all(
            color: Colors.black.withValues(alpha: 0.15),
            width: 0.5,
          ),
        ),
      ),
    );
  }
}
