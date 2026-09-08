import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'app_menu.dart';

/// The shared visual language introduced on the Sale screen: soft green page
/// gradient, rounded translucent panels, pill controls and quiet card rows.
/// Every module screen builds from these so the app reads as one product.
const kPageTop = Color(0xfff3f8f5);
const kPageBottom = Color(0xfff8fbf6);
const kPanelBorder = Color(0xffe1ebe7);
const kAccent = Color(0xff0e8a60);
const kAccentSoft = Color(0xffe4f7ef);
const kInk = Color(0xff173f34);
const kInkStrong = Color(0xff203f36);
const kInkSoft = Color(0xff74877f);
const kMoney = Color(0xff126d50);
const kRowSurface = Color(0xfffbfdfc);
const kRowBorder = Color(0xffe6eeea);
const kField = Color(0xfff4f8f6);
const kFieldBorder = Color(0xffe1ebe6);
const kFocusBorder = Color(0xff15a675);
const kDanger = Color(0xffb42318);
const kDangerSoft = Color(0xfffdeceb);
const kWarning = Color(0xffa86100);
const kWarningSoft = Color(0xfffff1d8);
const kSoftControl = Color(0xfff0f5f2);
const kSoftControlInk = Color(0xff37695a);

/// Accent colours used to tell repeated rows apart at a glance.
const kRowAccents = [
  Color(0xff0e8a60),
  Color(0xff1686a8),
  Color(0xffd08118),
  Color(0xff7a65b5),
  Color(0xffd05b6f),
];

Color accentFor(String value) {
  final score = value.codeUnits.fold<int>(0, (total, code) => total + code);
  return kRowAccents[score % kRowAccents.length];
}

String php(num value) => 'PHP ${value.toStringAsFixed(2)}';

/// App bar with the module title over a quiet one-line subtitle.
class ModuleAppBar extends StatelessWidget implements PreferredSizeWidget {
  const ModuleAppBar(
      {super.key,
      required this.title,
      required this.subtitle,
      this.actions = const []});

  final String title;
  final String subtitle;
  final List<Widget> actions;

  @override
  Size get preferredSize => const Size.fromHeight(72);

  @override
  Widget build(BuildContext context) => AppBar(
        backgroundColor: kPageTop,
        surfaceTintColor: Colors.transparent,
        leading: AppMenu.leadingOf(context),
        title: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title),
            Text(
              subtitle,
              style: const TextStyle(
                color: Color(0xff6c827a),
                fontSize: 11.5,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        actions: actions.isEmpty
            ? null
            : [
                Padding(
                  padding: const EdgeInsets.only(right: 14),
                  child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        for (final action in actions) ...[
                          action,
                          const SizedBox(width: 8)
                        ]
                      ]..removeLast()),
                ),
              ],
      );
}

/// Page gradient plus the padding every module body shares.
class ModuleBody extends StatelessWidget {
  const ModuleBody({super.key, required this.child, this.padded = true});
  final Widget child;
  final bool padded;

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 600;
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [kPageTop, kPageBottom],
        ),
      ),
      child: padded
          ? Padding(
              padding: compact
                  ? const EdgeInsets.fromLTRB(12, 10, 12, 12)
                  : const EdgeInsets.fromLTRB(22, 14, 22, 22),
              child: child,
            )
          : child,
    );
  }
}

/// A rounded translucent card with an icon-tile heading.
class ModulePanel extends StatelessWidget {
  const ModulePanel({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.actions = const [],
    required this.child,
    this.fill = false,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final List<Widget> actions;
  final Widget child;

  /// Whether the panel should stretch to its parent's height (list panels) or
  /// hug its content (blocks inside a scroll view).
  final bool fill;

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 600;
    return Container(
      padding: EdgeInsets.fromLTRB(
          compact ? 12 : 16, 16, compact ? 12 : 16, compact ? 12 : 14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .88),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: kPanelBorder),
      ),
      child: Column(
        mainAxisSize: fill ? MainAxisSize.max : MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PanelHeading(
              icon: icon, title: title, subtitle: subtitle, actions: actions),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

class PanelHeading extends StatelessWidget {
  const PanelHeading(
      {super.key,
      required this.icon,
      required this.title,
      this.subtitle,
      this.actions = const []});

  final IconData icon;
  final String title;
  final String? subtitle;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) => Row(children: [
        Container(
          width: 42,
          height: 42,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: kAccentSoft,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(icon, size: 20, color: kAccent),
        ),
        const SizedBox(width: 11),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: kInk,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              if (subtitle != null)
                Text(
                  subtitle!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: kInkSoft, fontSize: 11.5),
                ),
            ],
          ),
        ),
        for (final action in actions) ...[const SizedBox(width: 8), action],
      ]);
}

/// Header for a modal bottom sheet, matching [PanelHeading].
class SheetHeader extends StatelessWidget {
  const SheetHeader(
      {super.key,
      required this.icon,
      required this.title,
      required this.onClose,
      this.subtitle});

  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) => Row(children: [
        Container(
          width: 42,
          height: 42,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: kAccentSoft,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(icon, size: 20, color: kAccent),
        ),
        const SizedBox(width: 11),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: kInk,
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                ),
              ),
              if (subtitle != null)
                Text(
                  subtitle!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: kInkSoft, fontSize: 11.5),
                ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        SoftIconButton(
            icon: LucideIcons.x, tooltip: 'Close', onPressed: onClose),
      ]);
}

class SoftIconButton extends StatelessWidget {
  const SoftIconButton(
      {super.key,
      required this.icon,
      required this.tooltip,
      required this.onPressed});
  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => Tooltip(
        message: tooltip,
        child: Material(
          color: kSoftControl,
          borderRadius: BorderRadius.circular(12),
          child: IconButton(
            onPressed: onPressed,
            icon: Icon(icon),
            color: kSoftControlInk,
            iconSize: 19,
          ),
        ),
      );
}

/// Small caps label that separates sections inside panels and sheets.
class SectionLabel extends StatelessWidget {
  const SectionLabel(this.label, {super.key});
  final String label;

  @override
  Widget build(BuildContext context) => Text(
        label,
        style: const TextStyle(
          color: Color(0xff7d918a),
          fontSize: 10,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.1,
        ),
      );
}

class FilterPill extends StatelessWidget {
  const FilterPill(
      {super.key,
      required this.label,
      required this.selected,
      required this.onTap,
      this.icon});
  final String label;
  final IconData? icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
        color: selected ? kAccent : const Color(0xfff1f6f3),
        borderRadius: BorderRadius.circular(999),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                  color: selected ? kAccent : const Color(0xffe2ece7)),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              if (icon != null) ...[
                Icon(icon,
                    size: 15,
                    color: selected ? Colors.white : const Color(0xff5c7d70)),
                const SizedBox(width: 7),
              ],
              Text(
                label,
                style: TextStyle(
                  color: selected ? Colors.white : const Color(0xff41645a),
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ]),
          ),
        ),
      );
}

/// Horizontal, scrollable row of [FilterPill]s.
class FilterPillBar extends StatelessWidget {
  const FilterPillBar({super.key, required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
            children: [
          for (final child in children) ...[child, const SizedBox(width: 8)]
        ]..removeLast()),
      );
}

InputDecoration moduleField({
  required String hint,
  IconData icon = LucideIcons.search,
  Widget? suffixIcon,
  String? label,
}) =>
    InputDecoration(
      filled: true,
      fillColor: kField,
      labelText: label,
      prefixIcon: Icon(icon, size: 20, color: const Color(0xff5f7b72)),
      hintText: hint,
      hintStyle: const TextStyle(color: Color(0xff8ca099)),
      suffixIcon: suffixIcon,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(17),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(17),
        borderSide: const BorderSide(color: kFieldBorder),
      ),
      disabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(17),
        borderSide: const BorderSide(color: Color(0xffe8eeeb)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(17),
        borderSide: const BorderSide(color: kFocusBorder, width: 1.5),
      ),
    );

/// Search field wired to a controller, with a clear button once it has text.
class ModuleSearchField extends StatelessWidget {
  const ModuleSearchField(
      {super.key,
      required this.controller,
      required this.hint,
      required this.onChanged});
  final TextEditingController controller;
  final String hint;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) => TextField(
        controller: controller,
        onChanged: onChanged,
        decoration: moduleField(
          hint: hint,
          suffixIcon: controller.text.isEmpty
              ? null
              : IconButton(
                  onPressed: () {
                    controller.clear();
                    onChanged('');
                  },
                  tooltip: 'Clear search',
                  icon: const Icon(LucideIcons.x, size: 18),
                ),
        ),
      );
}

/// Tappable card row used for lists of products, receipts, movements, etc.
class ModuleRow extends StatelessWidget {
  const ModuleRow({super.key, required this.child, this.onTap});
  final Widget child;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final content = Padding(padding: const EdgeInsets.all(12), child: child);
    return Material(
      color: kRowSurface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: kRowBorder),
      ),
      clipBehavior: Clip.antiAlias,
      child: onTap == null ? content : InkWell(onTap: onTap, child: content),
    );
  }
}

/// Rounded tile holding a leading icon inside [ModuleRow].
class RowIcon extends StatelessWidget {
  const RowIcon(
      {super.key, required this.icon, required this.color, this.size = 46});
  final IconData icon;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: color.withValues(alpha: .11),
          borderRadius: BorderRadius.circular(size / 3),
        ),
        child: Icon(icon, size: size * .45, color: color),
      );
}

class StatusBadge extends StatelessWidget {
  const StatusBadge(
      {super.key,
      required this.label,
      required this.color,
      required this.background});
  final String label;
  final Color color;
  final Color background;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
            color: background, borderRadius: BorderRadius.circular(999)),
        child: Text(label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
                fontSize: 9.5, fontWeight: FontWeight.w800, color: color)),
      );
}

/// The dark headline card that carries the most important number on a screen.
class HighlightCard extends StatelessWidget {
  const HighlightCard(
      {super.key,
      required this.label,
      required this.value,
      this.caption,
      this.footer});
  final String label;
  final String value;
  final String? caption;
  final Widget? footer;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xff173f38), Color(0xff0d7457)],
          ),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      color: Color(0xffb8ded0),
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.1,
                    ),
                  ),
                  if (caption != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      caption!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          color: Color(0xffd2e9e0), fontSize: 10.5),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 10),
            Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w800,
                letterSpacing: -.5,
              ),
            ),
          ]),
          if (footer != null) ...[const SizedBox(height: 12), footer!],
        ]),
      );
}

/// Compact metric card for the summary strips at the top of a module.
class StatTile extends StatelessWidget {
  const StatTile({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    this.tone,
    this.width,
  });
  final IconData icon;
  final String label;
  final String value;
  final Color? tone;
  final double? width;

  @override
  Widget build(BuildContext context) {
    final accent = tone ?? kAccent;
    return SizedBox(
      width: width,
      child: Container(
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: kRowSurface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: kRowBorder),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            RowIcon(icon: icon, color: accent, size: 32),
            const SizedBox(width: 9),
            Expanded(
              child: Text(
                label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: kInkSoft,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  height: 1.15,
                ),
              ),
            ),
          ]),
          const SizedBox(height: 9),
          FittedBox(
            alignment: Alignment.centerLeft,
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              maxLines: 1,
              style: TextStyle(
                color: accent == kAccent ? kInk : accent,
                fontSize: 17,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ]),
      ),
    );
  }
}

/// Lays [tiles] out in as many columns as the width allows.
class StatTileGrid extends StatelessWidget {
  const StatTileGrid({super.key, required this.tiles, this.minTileWidth = 168});
  final List<Widget Function(double width)> tiles;
  final double minTileWidth;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, constraints) {
          const spacing = 10.0;
          final columns =
              (constraints.maxWidth / minTileWidth).floor().clamp(2, 5);
          final width =
              (constraints.maxWidth - spacing * (columns - 1)) / columns;
          return Wrap(
            spacing: spacing,
            runSpacing: spacing,
            children: [for (final tile in tiles) tile(width)],
          );
        },
      );
}

class ModuleEmpty extends StatelessWidget {
  const ModuleEmpty(
      {super.key,
      required this.icon,
      required this.title,
      required this.message});
  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 62,
              height: 62,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: const Color(0xfff0f6f3),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(icon, color: const Color(0xff6e867e), size: 26),
            ),
            const SizedBox(height: 14),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xff274b41),
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xff7b8f88), fontSize: 12),
            ),
          ]),
        ),
      );
}

/// Primary sheet/page action button.
ButtonStyle accentButton({Color? background}) => FilledButton.styleFrom(
      backgroundColor: background ?? kAccent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
    );

/// Quiet secondary action button.
ButtonStyle softButton() => OutlinedButton.styleFrom(
      foregroundColor: const Color(0xff426e61),
      side: const BorderSide(color: Color(0xffd4e4dd)),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      padding: const EdgeInsets.symmetric(vertical: 13),
    );
