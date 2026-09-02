import 'package:flutter/material.dart';

import '../core/app_theme.dart';

class PageHeader extends StatelessWidget {
  const PageHeader({required this.title, super.key, this.subtitle, this.action});
  final String title;
  final String? subtitle;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 24),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final copy = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: MediaQuery.sizeOf(context).width < 640 ? 26 : 30,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.45,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 4),
                    Text(subtitle!, style: const TextStyle(color: AppColors.muted)),
                  ],
                ],
              );
            if (constraints.maxWidth < 650 && action != null) {
              return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [copy, const SizedBox(height: 14), action!]);
            }
            return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(child: copy), if (action != null) ...[const SizedBox(width: 16), action!]]);
          },
        ),
      );
}

class SectionTitle extends StatelessWidget {
  const SectionTitle({required this.title, super.key, this.action});
  final String title;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 12, top: 4),
        child: Row(
          children: [
            Expanded(child: Text(title, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w600))),
            if (action != null) action!,
          ],
        ),
      );
}
