import 'package:flutter/material.dart';

/// Small colored status badge (pill) with automatic light/dark contrast.
/// Use this instead of a plain [Chip] with a manual `backgroundColor` —
/// a bare Chip inherits the theme's default (light or dark) label color,
/// which becomes unreadable once combined with a fixed light background
/// such as `Colors.green.shade100` in dark mode.
class StatusPill extends StatelessWidget {
  final String label;
  final MaterialColor color;
  final IconData? icon;

  const StatusPill({super.key, required this.label, required this.color, this.icon});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final background = isDark ? color.shade900.withValues(alpha: 0.45) : color.shade50;
    final foreground = isDark ? color.shade100 : color.shade800;
    final border = isDark ? color.shade400 : color.shade300;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: border, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 13, color: foreground),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(color: foreground, fontSize: 12, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}
