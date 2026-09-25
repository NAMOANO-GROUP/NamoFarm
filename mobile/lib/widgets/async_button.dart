import 'package:flutter/material.dart';

/// Bouton dont l'action asynchrone ne peut être déclenchée qu'une seule fois à
/// la fois : pendant l'exécution il se désactive et affiche un indicateur,
/// ce qui empêche les double-clics (et donc les enregistrements en double).
class AsyncButton extends StatefulWidget {
  final Future<void> Function() onPressed;
  final Widget label;
  final IconData? icon;
  final bool outlined;
  final ButtonStyle? style;

  const AsyncButton({
    super.key,
    required this.onPressed,
    required this.label,
    this.icon,
    this.outlined = false,
    this.style,
  });

  @override
  State<AsyncButton> createState() => _AsyncButtonState();
}

class _AsyncButtonState extends State<AsyncButton> {
  bool _busy = false;

  Future<void> _run() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await widget.onPressed();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final onPressed = _busy ? null : _run;
    final spinner = const SizedBox(
      width: 18,
      height: 18,
      child: CircularProgressIndicator(strokeWidth: 2),
    );

    if (widget.icon != null) {
      final iconWidget = _busy ? spinner : Icon(widget.icon);
      return widget.outlined
          ? OutlinedButton.icon(onPressed: onPressed, style: widget.style, icon: iconWidget, label: widget.label)
          : ElevatedButton.icon(onPressed: onPressed, style: widget.style, icon: iconWidget, label: widget.label);
    }

    final child = _busy ? spinner : widget.label;
    return widget.outlined
        ? OutlinedButton(onPressed: onPressed, style: widget.style, child: child)
        : ElevatedButton(onPressed: onPressed, style: widget.style, child: child);
  }
}
