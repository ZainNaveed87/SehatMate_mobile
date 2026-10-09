import 'package:flutter/material.dart';

import '../../../core/app_theme.dart';
import '../../../localization/app_language.dart';
import '../../../localization/language_scope.dart';

/// One app preference, shared by typing and realtime Agent presentations.
class AgentLanguageSelector extends StatefulWidget {
  const AgentLanguageSelector({
    super.key,
    this.waitForLanguageChange,
    this.enabled = true,
    this.compact = false,
  });

  final Future<void> Function()? waitForLanguageChange;
  final bool enabled;
  final bool compact;

  @override
  State<AgentLanguageSelector> createState() => _AgentLanguageSelectorState();
}

class _AgentLanguageSelectorState extends State<AgentLanguageSelector> {
  bool _saving = false;
  bool _failed = false;

  Future<void> _select(AppLanguage language) async {
    final controller = LanguageScope.read(context);
    if (_saving || !widget.enabled || language == controller.language) return;
    setState(() {
      _saving = true;
      _failed = false;
    });
    try {
      await controller.setLanguage(language, persistBeforeNotify: true);
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    } finally {
      // The existing voice controller owns fencing, rebind and transport errors.
      // Await it only; this component never starts/stops a voice session.
      if (!_failed) {
        try {
          await widget.waitForLanguageChange?.call();
        } catch (_) {
          // Voice recovery remains owned by the existing voice controller.
        }
      }
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final selected = LanguageScope.watch(context).language;
    final label = context.tr('agent_language_label');
    return Directionality(
      textDirection: selected.textDirection,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          MenuAnchor(
            style: MenuStyle(
              backgroundColor: const WidgetStatePropertyAll(AppColors.card),
              shape: WidgetStatePropertyAll(
                RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadii.lg),
                ),
              ),
            ),
            menuChildren: AppLanguage.values
                .map(
                  (language) => MenuItemButton(
                    key: ValueKey(
                      'agent_language_option_${language.storageValue}',
                    ),
                    onPressed: () => _select(language),
                    style: const ButtonStyle(
                      minimumSize: WidgetStatePropertyAll(Size(180, 48)),
                    ),
                    trailingIcon: selected == language
                        ? const Icon(
                            Icons.check_rounded,
                            color: AppColors.primary,
                            size: 20,
                          )
                        : null,
                    child: Directionality(
                      textDirection: language.textDirection,
                      child: Text(language.displayName),
                    ),
                  ),
                )
                .toList(),
            builder: (context, menu, child) => TextButton(
              key: const ValueKey('agent_language_selector'),
              onPressed: widget.enabled && !_saving
                  ? () => menu.isOpen ? menu.close() : menu.open()
                  : null,
              style: TextButton.styleFrom(
                textStyle: TextStyle(fontSize: widget.compact ? 13 : 14),
                minimumSize: const Size(48, 48),
                padding: EdgeInsets.symmetric(
                  horizontal: widget.compact ? 8 : 12,
                  vertical: 8,
                ),
                backgroundColor: AppColors.primaryLight,
                side: const BorderSide(color: Color(0xFFDCE8E6)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadii.lg),
                ),
              ),
              child: Semantics(
                excludeSemantics: true,
                label: context.tr(
                  'agent_language_current',
                  values: {'language': selected.displayName},
                ),
                child: Wrap(
                  spacing: widget.compact ? 6 : 8,
                  runSpacing: 2,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    if(!widget.compact) Text(
                      '$label:',
                      style: const TextStyle(
                        color: AppColors.muted,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(child:Text(
                          selected.displayName,maxLines:1,overflow:TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppColors.foreground,
                            fontWeight: FontWeight.w700,
                          ),
                        )),
                        const SizedBox(width: 4),
                        if (_saving)
                          const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        else
                          const Icon(
                            Icons.keyboard_arrow_down_rounded,
                            color: AppColors.primary,
                            size: 20,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (_failed)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Semantics(
                liveRegion: true,
                child: Text(
                  context.tr('settings_language_update_failed'),
                  style: const TextStyle(
                    color: AppColors.critical,
                    fontSize: 12,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
