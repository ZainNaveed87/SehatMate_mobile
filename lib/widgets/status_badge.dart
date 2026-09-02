import 'package:flutter/material.dart';

import '../core/app_theme.dart';
import '../data/demo_data.dart';

class StatusBadge extends StatelessWidget {
  const StatusBadge({required this.status, super.key, this.label});
  final TaskStatus status;
  final String? label;

  @override
  Widget build(BuildContext context) {
    final (text, foreground, background, icon) = switch (status) {
      TaskStatus.ready => (label ?? 'Ready', AppColors.successForeground, AppColors.successSoft, Icons.check_circle_outline),
      TaskStatus.atRisk => (label ?? 'At Risk', AppColors.warningForeground, AppColors.warningSoft, Icons.warning_amber_rounded),
      TaskStatus.blocked => (label ?? 'Blocked', AppColors.criticalForeground, AppColors.criticalSoft, Icons.cancel_outlined),
      TaskStatus.unclear => (label ?? 'Unclear', AppColors.infoForeground, AppColors.infoSoft, Icons.help_outline),
      TaskStatus.resolved => (label ?? 'Resolved', AppColors.accentForeground, AppColors.primaryLight, Icons.verified_outlined),
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
      PlanStatus.active => ('Active', AppColors.successForeground, AppColors.successSoft),
      PlanStatus.needsAttention => ('Needs Attention', AppColors.warningForeground, AppColors.warningSoft),
      PlanStatus.draft => ('Draft', AppColors.muted, AppColors.secondary),
      PlanStatus.processing => ('Processing', AppColors.infoForeground, AppColors.infoSoft),
      PlanStatus.needsReview => ('Needs Review', AppColors.foreground, AppColors.secondary),
      PlanStatus.realityCheck => ('Reality Check Required', AppColors.warningForeground, AppColors.warningSoft),
      PlanStatus.completed => ('Completed', AppColors.accentForeground, AppColors.primaryLight),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(99)),
      child: Text(text, style: TextStyle(color: foreground, fontSize: 13, fontWeight: FontWeight.w500)),
    );
  }
}
