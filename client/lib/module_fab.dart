import 'package:flutter/material.dart';

class ModuleFab extends StatelessWidget {
  const ModuleFab({
    super.key,
    required this.onPressed,
    required this.icon,
    required this.heroTag,
    this.label,
    this.tooltip,
  });

  final VoidCallback onPressed;
  final IconData icon;
  final Object heroTag;
  final String? label;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    // The navigation menu is no longer a floating button (it now lives in the
    // AppBar), so the action FAB no longer needs to lift to clear it. Scaffold
    // already raises the FAB above any bottomNavigationBar, e.g. the Sale cart
    // bar.
    return label == null
        ? FloatingActionButton(
            onPressed: onPressed,
            heroTag: heroTag,
            tooltip: tooltip,
            child: Icon(icon),
          )
        : FloatingActionButton.extended(
            onPressed: onPressed,
            heroTag: heroTag,
            icon: Icon(icon, size: 19),
            label: Text(label!),
          );
  }
}
