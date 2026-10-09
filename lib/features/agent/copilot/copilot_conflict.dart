import 'dart:convert';
import 'package:flutter/material.dart';
import '../models/agent_navigation.dart';
import '../navigation/agent_navigation_handler.dart';
import 'copilot.dart';
import 'copilot_strings.dart';

class CopilotConflict {
  const CopilotConflict({
    required this.id,
    required this.type,
    required this.affectedTargets,
    required this.allowedResolutions,
    required this.facts,
    required this.professionalReview,
  });
  final String id, type;
  final List<String> affectedTargets, allowedResolutions;
  final Map<String, dynamic> facts;
  final bool professionalReview;
  static const types = {
    'timing_availability',
    'overlapping_schedule',
    'repeated_missed_tasks',
    'unresolved_care_gap',
    'incomplete_reality_check',
    'caregiver_preference_unmet',
    'overdue_follow_up',
  };
  static const resolutions = {
    'review_routine',
    'keep_current_setup',
    'review_caregiver',
    'review_reminders',
    'open_care_gap',
    'open_reality_check',
    'professional_review',
  };
  static List<CopilotConflict> parse(Object? raw) {
    if (raw is! List) return const [];
    final result = <CopilotConflict>[];
    for (final item in raw.take(8)) {
      if (item is! Map ||
          item['id'] is! String ||
          !types.contains(item['type']) ||
          item['evidenceRefs'] is! List ||
          (item['evidenceRefs'] as List).isEmpty ||
          item['explainableFacts'] is! Map ||
          utf8.encode(jsonEncode(item)).length > 4096) {
        continue;
      }
      result.add(
        CopilotConflict(
          id: item['id'],
          type: item['type'],
          affectedTargets: item['affectedTargets'] is List
              ? (item['affectedTargets'] as List)
                    .whereType<String>()
                    .take(8)
                    .toList()
              : [],
          allowedResolutions: item['allowedResolutions'] is List
              ? (item['allowedResolutions'] as List)
                    .whereType<String>()
                    .where(resolutions.contains)
                    .take(7)
                    .toList()
              : [],
          facts: Map<String, dynamic>.from(item['explainableFacts']),
          professionalReview: item['requiresProfessionalReview'] == true,
        ),
      );
    }
    return List.unmodifiable(result);
  }
}

class CopilotConflictCard extends StatelessWidget {
  const CopilotConflictCard({
    super.key,
    required this.conflict,
    required this.navigationHandler,
  });
  final CopilotConflict conflict;
  final AgentNavigationHandler navigationHandler;
  @override
  Widget build(BuildContext context) {
    final registry = CopilotScope.maybeOf(context)?.registry;
    final conflictPlanId = conflict.facts['planId']?.toString();
    final currentEntity = registry?.snapshot?.entity;
    final samePlan =
        conflictPlanId == null ||
        (currentEntity?.type == 'care_plan' &&
            currentEntity?.id == conflictPlanId);
    final target = (samePlan ? conflict.affectedTargets : const <String>[])
        .where(
          (id) => registry?.snapshot?.targets.any((t) => t.id == id) == true,
        )
        .firstOrNull;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              copilotText(context, conflict.type),
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            if (conflict.professionalReview)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(copilotText(context, 'professional_review')),
              ),
            Wrap(
              spacing: 8,
              children: [
                if (target != null)
                  TextButton(
                    onPressed: () => registry!.reveal(target, 'highlight'),
                    child: Text(copilotText(context, 'show_issue')),
                  ),
                for (final resolution in conflict.allowedResolutions.where(
                  (r) =>
                      r != 'professional_review' && r != 'keep_current_setup',
                ))
                  TextButton(
                    onPressed: () {
                      final navigation = switch (resolution) {
                        'review_routine' || 'review_reminders' =>
                          const AgentNavigation(target: 'routine_settings'),
                        'review_caregiver' => const AgentNavigation(
                          target: 'family_care',
                        ),
                        'open_care_gap' => AgentNavigation(
                          target: 'care_gap_detail',
                          params: {
                            'careGapId':
                                conflict.facts['gapId']?.toString() ?? '',
                          },
                        ),
                        'open_reality_check' => AgentNavigation(
                          target: 'reality_check',
                          params: {
                            'carePlanId':
                                conflict.facts['planId']?.toString() ?? '',
                          },
                        ),
                        _ => null,
                      };
                      if (resolution == 'open_reality_check' &&
                          !RegExp(r'^[1-9][0-9]{0,19}$').hasMatch(
                            conflict.facts['planId']?.toString() ?? '',
                          )) {
                        return;
                      }
                      if (navigation != null &&
                          navigationHandler.canNavigate(navigation)) {
                        navigationHandler.dispatch(context, navigation);
                      }
                    },
                    child: Text(copilotText(context, resolution)),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
