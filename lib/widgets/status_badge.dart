import 'package:flutter/material.dart';

import '../core/app_theme.dart';
import '../data/demo_data.dart';
import '../localization/language_scope.dart';

class StatusBadge extends StatelessWidget {
  const StatusBadge({required this.status, super.key, this.label});
  final TaskStatus status;
  final String? label;

  @override
  Widget build(BuildContext context) {
    final (text, foreground, background, icon) = switch (status) {
      TaskStatus.ready => (
          label ?? taskStatusLabel(status, context.appLanguage),
          AppColors.successForeground,
          AppColors.successSoft,
          Icons.check_circle_outline,
        ),
      TaskStatus.atRisk => (
          label ?? taskStatusLabel(status, context.appLanguage),
          AppColors.warningForeground,
          AppColors.warningSoft,
          Icons.warning_amber_rounded,
        ),
      TaskStatus.blocked => (
          label ?? taskStatusLabel(status, context.appLanguage),
          AppColors.criticalForeground,
          AppColors.criticalSoft,
          Icons.cancel_outlined,
        ),
      TaskStatus.unclear => (
          label ?? taskStatusLabel(status, context.appLanguage),
          AppColors.infoForeground,
          AppColors.infoSoft,
          Icons.help_outline,
        ),
      TaskStatus.resolved => (
          label ?? taskStatusLabel(status, context.appLanguage),
          AppColors.accentForeground,
          AppColors.primaryLight,
          Icons.verified_outlined,
        ),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(99)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: foreground),
          const SizedBox(width: 6),
          Text(text, style: TextStyle(color: foreground, fontSize: 13, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}

class PlanStatusBadge extends StatelessWidget {
  const PlanStatusBadge({required this.status, super.key});
  final PlanStatus status;

  @override
  Widget build(BuildContext context) {
    final (text, foreground, background) = switch (status) {
      PlanStatus.active => (
          planStatusLabel(status, context.appLanguage),
          AppColors.successForeground,
          AppColors.successSoft,
        ),
      PlanStatus.needsAttention => (
          planStatusLabel(status, context.appLanguage),
          AppColors.warningForeground,
          AppColors.warningSoft,
        ),
      PlanStatus.draft => (
          planStatusLabel(status, context.appLanguage),
          AppColors.muted,
          AppColors.secondary,
        ),
      PlanStatus.processing => (
          planStatusLabel(status, context.appLanguage),
          AppColors.infoForeground,
          AppColors.infoSoft,
        ),
      PlanStatus.needsReview => (
          planStatusLabel(status, context.appLanguage),
          AppColors.foreground,
          AppColors.secondary,
        ),
      PlanStatus.realityCheck => (
          planStatusLabel(status, context.appLanguage),
          AppColors.warningForeground,
          AppColors.warningSoft,
        ),
      PlanStatus.completed => (
          planStatusLabel(status, context.appLanguage),
          AppColors.accentForeground,
          AppColors.primaryLight,
        ),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(99)),
      child: Text(text, style: TextStyle(color: foreground, fontSize: 13, fontWeight: FontWeight.w500)),
    );
  }
}
