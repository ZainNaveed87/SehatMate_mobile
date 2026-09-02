import 'package:flutter/material.dart';

import '../core/app_theme.dart';
import '../core/care_setup_flow.dart';
import '../localization/language_scope.dart';
import '../services/care_plan_service.dart';
import 'ui.dart';

class GuidedCareSetupProgress extends StatelessWidget {
  const GuidedCareSetupProgress({
    required this.currentStep,
    super.key,
    this.planId,
    this.saveState,
  });

  final int currentStep;
  final String? planId;
  final String? saveState;

  static const _labelKeys = [
    'setup_label_documents',
    'setup_label_review',
    'setup_label_schedule',
    'setup_label_reality',
    'setup_label_simulation',
    'setup_label_care_gaps',
    'setup_label_activate',
  ];

  @override
  Widget build(BuildContext context) {
    final safeStep = currentStep.clamp(1, CareSetupProgress.totalSteps).toInt();
    final label = context.tr(_labelKeys[safeStep - 1]);
    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  context.tr(
                    'setup_step_counter',
                    values: {
                      'current': safeStep,
                      'total': CareSetupProgress.totalSteps,
                      'label': label,
                    },
                  ),
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              if (saveState != null) _SaveStateLabel(value: saveState!),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: safeStep / CareSetupProgress.totalSteps,
              minHeight: 7,
              color: AppColors.primary,
              backgroundColor: AppColors.secondary,
            ),
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: List.generate(_labelKeys.length, (index) {
                final number = index + 1;
                final complete = number < safeStep;
                final current = number == safeStep;
                final canReview = complete && planId != null;
                return Padding(
                  padding: EdgeInsets.only(
                    right: index == _labelKeys.length - 1 ? 0 : 8,
                  ),
                  child: InkWell(
                    onTap: !canReview
                        ? null
                        : () {
                            final step = CareSetupFlow.stepForNumber(number);
                            if (step == null) return;
                            CareSetupFlow.openStep(
                              context,
                              planId!,
                              step,
                              replace: false,
                              returnToPrevious: true,
                            );
                          },
                    borderRadius: BorderRadius.circular(99),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        color: current
                            ? AppColors.primaryLight
                            : complete
                            ? AppColors.successSoft
                            : AppColors.secondary,
                        borderRadius: BorderRadius.circular(99),
                        border: Border.all(
                          color: current ? AppColors.primary : AppColors.border,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            complete
                                ? Icons.check_circle_outline
                                : current
                                ? Icons.radio_button_checked
                                : Icons.radio_button_unchecked,
                            size: 15,
                            color: current
                                ? AppColors.primary
                                : complete
                                ? AppColors.successForeground
                                : AppColors.muted,
                          ),
                          const SizedBox(width: 5),
                          Text(
                            context.tr(_labelKeys[index]),
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: current || complete
                                  ? FontWeight.w600
                                  : FontWeight.w400,
                              color: current ? AppColors.primary : null,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
          if (safeStep > 1) ...[
            const SizedBox(height: 10),
            Text(
              context.tr('setup_completed_steps_help'),
              style: const TextStyle(fontSize: 12, color: AppColors.muted),
            ),
          ],
        ],
      ),
    );
  }
}

class _SaveStateLabel extends StatelessWidget {
  const _SaveStateLabel({required this.value});
  final String value;

  @override
  Widget build(BuildContext context) {
    final lower = value.toLowerCase();
    final saving = lower.contains('saving');
    final failed = lower.contains('retry') || lower.contains('couldn');
    final label = switch (lower) {
      'saving…' || 'saving...' => context.tr('saving'),
      'saved' => context.tr('saved'),
      'retry needed' => context.tr('retry_needed'),
      'unsaved changes' => context.tr('unsaved_changes'),
      'choose time' => context.tr('cpd_save_state_choose_time'),
      _ => value,
    };
    final color = failed
        ? AppColors.criticalForeground
        : saving
        ? AppColors.muted
        : AppColors.successForeground;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (saving)
          const SizedBox.square(
            dimension: 13,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        else
          Icon(
            failed ? Icons.error_outline : Icons.cloud_done_outlined,
            size: 15,
            color: color,
          ),
        const SizedBox(width: 5),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      ],
    );
  }
}
