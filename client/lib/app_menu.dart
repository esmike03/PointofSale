import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// Exposes the mobile navigation opener to each embedded module screen so its
/// [AppBar] can show a hamburger button to the left of the title.
///
/// On desktop (where the sidebar handles navigation) no [AppMenu] is provided,
/// so [leadingOf] returns null and the AppBar falls back to its default leading
/// (e.g. an automatic back button on pushed sub-screens).
class AppMenu extends InheritedWidget {
  const AppMenu({super.key, required this.onOpen, required super.child});

  final VoidCallback? onOpen;

  static VoidCallback? of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppMenu>()?.onOpen;

  /// A leading menu button for an [AppBar], or null when there is no menu.
  static Widget? leadingOf(BuildContext context) {
    final onOpen = of(context);
    if (onOpen == null) return null;
    return IconButton(
      onPressed: onOpen,
      tooltip: 'Open navigation',
      icon: const Icon(LucideIcons.menu),
    );
  }

  @override
  bool updateShouldNotify(AppMenu oldWidget) => onOpen != oldWidget.onOpen;
}
