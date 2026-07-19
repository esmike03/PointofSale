import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

class PaginationControls extends StatelessWidget {
  const PaginationControls(
      {super.key,
      required this.page,
      required this.hasNext,
      required this.onPrevious,
      required this.onNext});
  final int page;
  final bool hasNext;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 10),
        child: Row(children: [
          IconButton(
              onPressed: onPrevious,
              tooltip: 'Previous page',
              icon: const Icon(LucideIcons.chevronLeft)),
          const SizedBox(width: 4),
          Text('Page ${page + 1}',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(width: 4),
          IconButton(
              onPressed: hasNext ? onNext : null,
              tooltip: 'Next page',
              icon: const Icon(LucideIcons.chevronRight)),
        ]),
      );
}
