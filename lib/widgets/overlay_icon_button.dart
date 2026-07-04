import 'package:flutter/material.dart';

/// Small circular translucent icon button meant to float directly over the
/// player card (a `Stack` sibling of the capture `RepaintBoundary`). Replaces
/// what used to be `AppBar` actions — it reserves no layout space of its own,
/// it only overlays.
class OverlayIconButton extends StatelessWidget {
  const OverlayIconButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withValues(alpha: 0.35),
      shape: const CircleBorder(),
      child: IconButton(
        icon: Icon(icon, color: Colors.white),
        tooltip: tooltip,
        onPressed: onPressed,
      ),
    );
  }
}
