import 'package:flutter/material.dart';
import '../../../core/app_theme.dart';
import '../../../widgets/assistant_launcher.dart';
import '../../../localization/language_scope.dart';
import 'agent_language_selector.dart';

class AgentHeader extends StatelessWidget {
  const AgentHeader({
    super.key,
    required this.title,
    required this.subtitle,
    this.showBack = true,
    this.compact = false,
    this.waitForLanguageChange,
    this.languageEnabled = true,
  });
  final bool showBack;
  final bool compact;
  final String title;
  final String subtitle;
  final Future<void> Function()? waitForLanguageChange;
  final bool languageEnabled;

  Widget _trustLine() => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Padding(
        padding: EdgeInsets.only(top: 2),
        child: Icon(Icons.shield_outlined, color: AppColors.primary, size: 14),
      ),
      const SizedBox(width: 6),
      Expanded(
        child: Text(
          subtitle,
          style: const TextStyle(
            color: AppColors.muted,
            fontSize: 12,
            height: 1.35,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    ],
  );

  @override
  Widget build(BuildContext context) {
    final largeText = MediaQuery.textScalerOf(context).scale(14) > 19;
    final mark = Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primary, Color(0xFF14B8A6)],
        ),
        borderRadius: BorderRadius.circular(AppRadii.lg),
        boxShadow: const [
          BoxShadow(
            color: Color(0x260F766E),
            blurRadius: 14,
            spreadRadius: -6,
            offset: Offset(0, 7),
          ),
        ],
      ),
      child: const Icon(
        Icons.auto_awesome_rounded,
        color: Colors.white,
        size: 20,
      ),
    );
    return Container(
      margin: EdgeInsets.fromLTRB(12, compact ? 4 : 10, 12, compact ? 2 : 4),
      padding: EdgeInsets.fromLTRB(8, compact ? 4 : 10, 12, compact ? 4 : 10),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppRadii.xl),
        border: Border.all(color: const Color(0xFFDCE8E6)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x120F172A),
            blurRadius: 18,
            spreadRadius: -8,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              if (showBack)
                IconButton(
                  tooltip: context.tr('back'),
                  style: IconButton.styleFrom(minimumSize: const Size(48, 48)),
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.arrow_back_rounded),
                ),
              const SizedBox(width: 4),
              if (!compact) ...[
                if (showBack)
                  Hero(tag: assistantHeroTag, child: mark)
                else
                  mark,
                const SizedBox(width: 12),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -.2,
                      ),
                    ),
                    if (!largeText && !compact) ...[
                      const SizedBox(height: 4),
                      _trustLine(),
                    ],
                  ],
                ),
              ),
            ],
          ),
          if (largeText && !compact)
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 0, 0),
              child: _trustLine(),
            ),
          Padding(
            key: const ValueKey('agent_language_control'),
            padding: EdgeInsetsDirectional.only(start: 8, top: compact ? 4 : 8),
            child: Align(
              alignment: AlignmentDirectional.centerStart,
              child: AgentLanguageSelector(
                compact: compact,
                enabled: languageEnabled,
                waitForLanguageChange: waitForLanguageChange,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
