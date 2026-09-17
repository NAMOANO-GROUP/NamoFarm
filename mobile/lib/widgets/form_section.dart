import 'package:flutter/material.dart';

/// Small section header used inside long forms to group related fields.
class FormSection extends StatelessWidget {
  final String title;
  final IconData? icon;
  final EdgeInsetsGeometry padding;

  const FormSection(
    this.title, {
    super.key,
    this.icon,
    this.padding = const EdgeInsets.only(top: 16, bottom: 4),
  });

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    return Padding(
      padding: padding,
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(icon, size: 18, color: color),
            const SizedBox(width: 6),
          ],
          Text(
            title.toUpperCase(),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.6,
              color: color,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Divider(
              color: color.withValues(alpha: 0.25),
              height: 1,
            ),
          ),
        ],
      ),
    );
  }
}
