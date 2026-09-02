import 'package:flutter/material.dart';

import '../localization/app_language.dart';
import '../localization/language_scope.dart';

class LanguageSwitcher extends StatelessWidget {
  const LanguageSwitcher({
    this.compact = false,
    super.key,
  });

  final bool compact;

  @override
  Widget build(BuildContext context) {
    final controller = LanguageScope.watch(context);
    final selected = controller.language;

    if (compact) {
      return PopupMenuButton<AppLanguage>(
        tooltip: context.tr('choose_language'),
        initialValue: selected,
        onSelected: controller.setLanguage,
        itemBuilder: (context) => AppLanguage.values
            .map(
              (language) => PopupMenuItem(
                value: language,
                child: Row(
                  children: [
                    if (selected == language) ...[
                      const Icon(Icons.check, size: 18),
                      const SizedBox(width: 8),
                    ],
                    Text(language.displayName),
                  ],
                ),
              ),
            )
            .toList(),
        child: Semantics(
          button: true,
          label: context.tr('choose_language'),
          child: Chip(
            avatar: const Icon(Icons.language, size: 18),
            label: Text(selected.shortLabel),
          ),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(Icons.language_outlined),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    context.tr('choose_language'),
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              context.tr('language_description'),
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: AppLanguage.values
                  .map(
                    (language) => ChoiceChip(
                      selected: selected == language,
                      label: Text(language.displayName),
                      onSelected: (_) async {
                        await controller.setLanguage(language);
                        if (!context.mounted) return;

                        ScaffoldMessenger.of(context)
                          ..clearSnackBars()
                          ..showSnackBar(
                            SnackBar(
                              content: Text(context.tr('language_changed')),
                            ),
                          );
                      },
                    ),
                  )
                  .toList(),
            ),
          ],
        ),
      ),
    );
  }
}
