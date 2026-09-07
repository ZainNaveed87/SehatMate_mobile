import 'package:flutter/material.dart';

import '../localization/language_scope.dart';

import '../core/app_routes.dart';
import '../core/app_theme.dart';
import '../core/schedule_time.dart';
import '../data/demo_data.dart';
import '../features/agent/agent_entry.dart';
import '../features/agent/models/agent_context.dart';
import '../services/care_plan_service.dart';
import '../services/notification_service.dart';
import 'task_outcome_screens.dart';
import '../widgets/app_shell.dart';
import '../widgets/care_setup_progress.dart';
import '../widgets/status_badge.dart';
import '../widgets/ui.dart';

class SimulationScreen extends StatelessWidget {
  const SimulationScreen({
    super.key,
    this.planId,
    this.guidedSetup = false,
    this.returnToPrevious = false,
  });

  final String? planId;
  final bool guidedSetup;
  final bool returnToPrevious;

  @override
  Widget build(BuildContext context) => AppShell(
    currentRoute: AppRoutes.simulation,
    title: context.tr('care_simulation'),
    child: SimulationView(
      planId: planId,
      guidedSetup: guidedSetup,
      returnToPrevious: returnToPrevious,
    ),
  );
}

class SimulationView extends StatefulWidget {
  const SimulationView({
    super.key,
    this.compact = false,
    this.planId,
    this.guidedSetup = false,
    this.returnToPrevious = false,
  });

  final bool compact;
  final String? planId;
  final bool guidedSetup;
  final bool returnToPrevious;

  @override
  State<SimulationView> createState() => _SimulationViewState();
}

CalendarRouteArgs? simulationCalendarArgsForFinding(
  Map finding,
  Iterable<DemoTask> tasks,
) {
  final dateKey = _simulationCalendarDateKeyForFinding(finding, tasks);
  return dateKey == null ? null : CalendarRouteArgs(initialDate: dateKey);
}

String? _simulationCalendarDateKeyForFinding(
  Map finding,
  Iterable<DemoTask> tasks,
) {
  for (final key in const [
    'date',
    'scheduleDate',
    'schedule_date',
    'occurrenceDate',
    'occurrence_date',
    'taskDate',
    'task_date',
  ]) {
    final parsed = calendarInitialDateFrom(_mapTextValue(finding, key));
    if (parsed != null) return calendarLocalDateKey(parsed);
  }

  final taskId =
      _mapTextValue(finding, 'taskId') ?? _mapTextValue(finding, 'task_id');
  if (taskId == null) return null;
  for (final task in tasks) {
    if (task.id != taskId) continue;
    final parsed = calendarInitialDateFrom(task.day);
    if (parsed != null) return calendarLocalDateKey(parsed);
  }
  return null;
}

String? _mapTextValue(Map value, String key) {
  final text = value[key]?.toString().trim();
  if (text == null || text.isEmpty || text.toLowerCase() == 'null') {
    return null;
  }
  return text;
}

/// Converts backend/AI navigation intents into a small, safe allowlist.
///
/// The backend/context classifier may decide which workflow best matches an
/// issue, but Flutter never executes arbitrary route strings. Legacy action
/// names are kept as aliases so existing care plans continue to work.
String canonicalSimulationNavigationAction(String? rawAction) {
  final action = rawAction?.trim().toLowerCase() ?? '';
  return switch (action) {
    'schedule' || 'review_schedule' => 'review_schedule',
    'recheck_reality' || 'keep_at_risk' || 'reality_check' => 'reality_check',
    'review_verified_instruction' ||
    'review_instruction' => 'review_instruction',
    'documents' => 'documents',
    'family_care' => 'family_care',
    'calendar' => 'calendar',
    'care_plan' => 'care_plan',
    'no_change' || '' => 'no_change',
    _ => 'care_plan',
  };
}

class _SimulationViewState extends State<SimulationView> {
  CareSimulationData? data;
  String? error;
  bool loading = true;
  bool activating = false;
  bool adaptingPlan = false;
  CareGapListData? careGaps;
  final Set<String> applyingSuggestionIds = <String>{};
  final Set<String> rejectedSuggestionKeys = <String>{};
  CareSetupProgress? setupProgress;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _load();
    });
  }

  Future<void> _load() async {
    if (widget.planId == null) {
      setState(() {
        loading = false;
        error = context.tr('sim_error_no_plan');
      });
      return;
    }
    try {
      final result = await CarePlanService.instance.fetchSimulation(
        widget.planId!,
      );

      final gapResult = widget.guidedSetup
          ? await CarePlanService.instance.fetchCareGaps(widget.planId!)
          : null;
      final progress = widget.guidedSetup
          ? await CarePlanService.instance.fetchSetupProgress(widget.planId!)
          : null;
      if (mounted) {
        setState(() {
          data = result;
          careGaps = gapResult;
          setupProgress = progress;
          loading = false;
        });
      }
    } on CarePlanException catch (exception) {
      if (mounted) {
        setState(() {
          loading = false;
          error = exception.message;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          loading = false;
          error = context.tr('sim_error_refresh_failed');
        });
      }
    }
  }

  Future<void> _refreshSimulation() async {
    if (!mounted) return;
    setState(() {
      loading = true;
      error = null;
    });
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const _SimulationPremiumLoading();
    }

    if (error != null || data == null) {
      return Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: AppCard(
            padding: const EdgeInsets.all(24),
            color: const Color(0xFFFFFBEB),
            borderColor: const Color(0xFFFDE68A),
            child: Column(
              children: [
                Container(
                  width: 54,
                  height: 54,
                  decoration: BoxDecoration(
                    color: AppColors.warningSoft,
                    borderRadius: BorderRadius.circular(AppRadii.xl),
                  ),
                  child: const Icon(
                    Icons.route_outlined,
                    size: 26,
                    color: AppColors.warningForeground,
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  context.tr('sim_unavailable'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  error ?? context.tr('sim_no_data'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.muted,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: () => Navigator.pushReplacementNamed(
                    context,
                    AppRoutes.carePlans,
                  ),
                  icon: const Icon(Icons.checklist_outlined, size: 17),
                  label: Text(context.tr('sim_open_care_plans')),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final value = data!;
    final needsAttention =
        value.blocked > 0 ||
        value.atRisk > 0 ||
        value.unclear > 0 ||
        value.unanswered > 0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.guidedSetup && widget.planId != null) ...[
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () {
                if (widget.returnToPrevious && Navigator.canPop(context)) {
                  Navigator.pop(context);
                  return;
                }
                Navigator.pushReplacementNamed(
                  context,
                  AppRoutes.realityCheck,
                  arguments: CareFlowArgs(
                    planId: widget.planId!,
                    guidedSetup: true,
                  ),
                );
              },
              icon: const Icon(Icons.arrow_back, size: 17),
              label: Text(
                widget.returnToPrevious
                    ? context.tr('back')
                    : context.tr('sim_back_to_reality_check'),
              ),
            ),
          ),
        ],
        if (!widget.compact) ...[
          FadeSlideIn(
            child: _SimulationPremiumHero(
              title: context.tr('care_simulation'),
              subtitle: context.tr('sim_header_subtitle'),
              readiness: value.readiness,
              needsAttention: needsAttention,
              ready: value.ready,
              atRisk: value.atRisk,
              blocked: value.blocked,
              statusLabel: needsAttention
                  ? context.tr('sim_status_needs_attention')
                  : context.tr('sim_status_on_track'),
            ),
          ),
          const SizedBox(height: 14),
        ],
        if (widget.planId != null) ...[
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              onPressed: () => openAgent(
                context,
                screenContext: AgentScreenContext(
                  screenId: 'simulation',
                  entity: AgentEntityContext(
                    type: 'care_plan',
                    id: widget.planId!,
                  ),
                ),
              ),
              icon: const Icon(Icons.auto_awesome_outlined, size: 17),
              label: Text(context.tr('ask_agent')),
            ),
          ),
          const SizedBox(height: 8),
        ],
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: () =>
                Navigator.pushNamed(context, AppRoutes.routinePreferences),
            icon: const Icon(Icons.psychology_alt_outlined, size: 17),
            label: Text(context.tr('sim_my_routine_preferences')),
          ),
        ),
        const SizedBox(height: 8),
        if (widget.guidedSetup && widget.planId != null) ...[
          GuidedCareSetupProgress(
            currentStep: setupProgress?.step == CareSetupStep.activate ? 7 : 5,
            planId: widget.planId!,
            saveState: applyingSuggestionIds.isNotEmpty
                ? context.tr('saving')
                : context.tr('saved'),
          ),
          const SizedBox(height: 16),
        ],
        FadeSlideIn(
          delay: const Duration(milliseconds: 70),
          child: AppCard(
            padding: const EdgeInsets.all(24),
            borderColor: AppColors.primary.withValues(alpha: .14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              LayoutBuilder(
                builder: (context, constraints) {
                  final score = Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        context.tr('sim_score_title'),
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.muted,
                        ),
                      ),
                      Text(
                        '${value.readiness} / 100',
                        style: const TextStyle(
                          fontSize: 34,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary,
                        ),
                      ),
                      StatusBadge(
                        status:
                            value.blocked > 0 ||
                                value.atRisk > 0 ||
                                value.unclear > 0 ||
                                value.unanswered > 0
                            ? TaskStatus.atRisk
                            : TaskStatus.ready,
                        label:
                            value.blocked > 0 ||
                                value.atRisk > 0 ||
                                value.unclear > 0 ||
                                value.unanswered > 0
                            ? context.tr('sim_status_needs_attention')
                            : context.tr('sim_status_on_track'),
                      ),
                    ],
                  );
                  final copy = Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        context.tr('sim_score_card_title'),
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        context.tr('sim_score_card_subtitle'),
                        style: const TextStyle(
                          fontSize: 14,
                          color: AppColors.muted,
                        ),
                      ),
                    ],
                  );
                  return constraints.maxWidth < 600
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [copy, const SizedBox(height: 16), score],
                        )
                      : Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(child: copy),
                            score,
                          ],
                        );
                },
              ),
              const SizedBox(height: 20),
              LayoutBuilder(
                builder: (context, constraints) {
                  const gap = 12.0;
                  final width = (constraints.maxWidth - gap) / 2;
                  final metrics = [
                    (
                      '${value.blocked}',
                      context.tr('sim_metric_blocked'),
                      AppColors.criticalSoft,
                      AppColors.criticalForeground,
                    ),
                    (
                      '${value.atRisk}',
                      context.tr('sim_metric_at_risk'),
                      AppColors.warningSoft,
                      AppColors.warningForeground,
                    ),
                    (
                      '${value.ready}',
                      context.tr('sim_metric_ready'),
                      AppColors.successSoft,
                      AppColors.successForeground,
                    ),
                    (
                      '${value.unclear}',
                      context.tr('sim_metric_unclear'),
                      AppColors.infoSoft,
                      AppColors.infoForeground,
                    ),
                  ];
                  return Wrap(
                    spacing: gap,
                    runSpacing: gap,
                    children: metrics
                        .map(
                          (metric) => Container(
                            width: width,
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: metric.$3,
                              borderRadius: BorderRadius.circular(AppRadii.xl),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  metric.$1,
                                  style: TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w700,
                                    color: metric.$4,
                                  ),
                                ),
                                Text(
                                  metric.$2,
                                  style: TextStyle(color: metric.$4),
                                ),
                              ],
                            ),
                          ),
                        )
                        .toList(),
                  );
                },
              ),
              const SizedBox(height: 20),
              SafetyNote(text: context.tr('sim_score_disclaimer')),
            ],
          ),
        ),
        ),
        if (value.unanswered > 0) ...[
          const SizedBox(height: 16),
          SafetyNote(
            text: context.tr(
              'sim_unanswered_provisional',
              values: {'count': value.unanswered},
            ),
          ),
        ],
        if (_applicableAdaptations(value).isNotEmpty) ...[
          const SizedBox(height: 20),
          AppCard(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    const CircleAvatar(
                      radius: 20,
                      backgroundColor: AppColors.primaryLight,
                      child: Icon(
                        Icons.auto_awesome_outlined,
                        color: AppColors.primary,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            context.tr('sim_adapt_title'),
                            style: const TextStyle(
                              fontSize: 19,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            context.tr(
                              'sim_adapt_subtitle',
                              values: {
                                'count': _applicableAdaptations(value).length,
                              },
                            ),
                            style: const TextStyle(
                              fontSize: 13,
                              color: AppColors.muted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  context.tr('sim_adapt_description'),
                  style: const TextStyle(fontSize: 14),
                ),
                const SizedBox(height: 14),
                FilledButton.icon(
                  onPressed: adaptingPlan
                      ? null
                      : () => _openAdaptMyPlan(value),
                  icon: adaptingPlan
                      ? const SizedBox.square(
                          dimension: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.tune, size: 18),
                  label: Text(
                    adaptingPlan
                        ? context.tr('sim_applying')
                        : context.tr('sim_adapt_title'),
                  ),
                ),
              ],
            ),
          ),
        ],
        if (value.atRisk > 0 &&
            _applicableAdaptations(value).isEmpty &&
            value.findings.isNotEmpty) ...[
          const SizedBox(height: 20),
          SafetyNote(text: context.tr('sim_no_auto_adapt_note')),
        ],
        if (value.contextInsights.isNotEmpty) ...[
          const SizedBox(height: 24),

          Row(
            children: [
              const Icon(
                Icons.auto_awesome_outlined,
                size: 21,
                color: AppColors.primary,
              ),
              const SizedBox(width: 8),
              Text(
                context.tr('sim_insights_title'),
                style: const TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),

          const SizedBox(height: 6),

          Text(
            context.tr('sim_insights_intro'),
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.muted,
              height: 1.4,
            ),
          ),

          const SizedBox(height: 5),

          Text(
            context.tr('sim_insights_disclaimer'),
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.muted,
              height: 1.4,
            ),
          ),

          const SizedBox(height: 12),

          ...value.contextInsights.map(_contextInsightCard),
        ],
        if (value.findings.isNotEmpty) ...[
          const SizedBox(height: 24),
          Text(
            context.tr('sim_findings_title'),
            style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 6),
          Text(
            context.tr('sim_findings_description'),
            style: const TextStyle(fontSize: 13, color: AppColors.muted),
          ),
          const SizedBox(height: 12),
          ...value.findings.map((finding) => _findingCard(finding)),
        ],
        const SizedBox(height: 20),
        _activationBlockersCard(value),
        const SizedBox(height: 24),
        Text(
          context.tr('sim_tasks_title'),
          style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 12),
        ...value.tasks.map(
          (task) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: HoverLift(
              child: AppCard(
                padding: const EdgeInsets.all(16),
                child: Row(
                children: [
                  Icon(task.icon, color: AppColors.primary),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          task.title,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        Text(
                          '${task.time}${task.note.isEmpty ? '' : ' · ${task.note}'}',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: AppColors.muted),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  StatusBadge(status: task.status),
                ],
              ),
            ),
            ),
          ),
        ),
        if (widget.guidedSetup &&
            widget.planId != null &&
            setupProgress?.step != CareSetupStep.activate) ...[
          const SizedBox(height: 6),
          AppCard(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  (careGaps?.summary.open ?? 0) == 0
                      ? context.tr('sim_care_gaps_ready')
                      : context.tr(
                          'sim_care_gaps_needs_review',
                          values: {'count': careGaps?.summary.open ?? 0},
                        ),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  (careGaps?.summary.open ?? 0) == 0
                      ? context.tr('sim_care_gaps_ready_desc')
                      : context.tr('sim_care_gaps_action_desc'),
                  style: const TextStyle(fontSize: 14, color: AppColors.muted),
                ),
                const SizedBox(height: 14),
                FilledButton.icon(
                  onPressed: _continueToCareGaps,
                  icon: const Icon(Icons.arrow_forward, size: 17),
                  label: Text(context.tr('sim_continue_to_care_gaps')),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],
        if (!widget.guidedSetup ||
            setupProgress?.step == CareSetupStep.activate) ...[
          const SizedBox(height: 16),
          AppCard(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  _canActivate(value)
                      ? context.tr('sim_activation_ready')
                      : context.tr('sim_activation_requirements'),
                  style: const TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  _activationMessage(value),
                  style: const TextStyle(color: AppColors.muted),
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: !_canActivate(value) || activating
                      ? null
                      : _activate,
                  icon: activating
                      ? const SizedBox(
                          width: 17,
                          height: 17,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(
                          Icons.notifications_active_outlined,
                          size: 18,
                        ),
                  label: Text(
                    activating
                        ? context.tr('sim_activating')
                        : context.tr('sim_activate_care_plan'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Future<void> _continueToCareGaps() async {
    final planId = widget.planId;
    if (planId == null) return;
    try {
      await CarePlanService.instance.updateSetupStep(
        planId,
        CareSetupStep.careGaps,
      );
      if (!mounted) return;
      Navigator.pushReplacementNamed(
        context,
        AppRoutes.careGaps,
        arguments: CareFlowArgs(planId: planId, guidedSetup: true),
      );
    } on CarePlanException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
    }
  }

  Widget _contextInsightCard(Map insight) {
    final signal = _findingValue(insight, const ['signal']) ?? 'neutral';

    final summary =
        _findingValue(insight, const ['summary']) ??
        context.tr('sim_insight_default_summary');

    final nextAction =
        _findingValue(insight, const ['nextAction', 'next_action']) ??
        'no_change';

    final followUpQuestion = _findingValue(insight, const [
      'followUpQuestion',
      'follow_up_question',
    ]);

    final rawRequiresReview =
        insight['requiresInstructionReview'] ??
        insight['requires_instruction_review'];

    final requiresInstructionReview =
        rawRequiresReview == true ||
        rawRequiresReview == 1 ||
        rawRequiresReview?.toString().toLowerCase() == 'true';

    final String title;
    final IconData icon;
    final Color foreground;
    final Color background;

    if (requiresInstructionReview || signal == 'possible_instruction_change') {
      title = context.tr('sim_insight_review_needed');

      icon = Icons.medical_information_outlined;

      foreground = AppColors.criticalForeground;

      background = AppColors.criticalSoft;
    } else if (signal == 'practical_support') {
      title = context.tr('sim_insight_support');

      icon = Icons.support_agent_outlined;

      foreground = AppColors.successForeground;

      background = AppColors.successSoft;
    } else if (signal == 'practical_constraint') {
      title = context.tr('sim_insight_constraint');

      icon = Icons.warning_amber_rounded;

      foreground = AppColors.warningForeground;

      background = AppColors.warningSoft;
    } else if (signal == 'professional_guidance') {
      title = context.tr('sim_insight_guidance');

      icon = Icons.fact_check_outlined;

      foreground = AppColors.infoForeground;

      background = AppColors.infoSoft;
    } else {
      title = context.tr('sim_insight_default');

      icon = Icons.auto_awesome_outlined;

      foreground = AppColors.infoForeground;

      background = AppColors.infoSoft;
    }

    final resolvedAction = requiresInstructionReview
        ? 'review_instruction'
        : canonicalSimulationNavigationAction(nextAction);
    final action = resolvedAction == 'no_change' ? '' : resolvedAction;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: AppCard(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: background,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, size: 20, color: foreground),
                ),

                const SizedBox(width: 11),

                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),

                      const SizedBox(height: 3),

                      Text(
                        _contextSignalLabel(signal),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: foreground,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            Text(summary, style: const TextStyle(fontSize: 14, height: 1.45)),

            if (followUpQuestion != null) ...[
              const SizedBox(height: 12),

              Text(
                context.tr('sim_insight_follow_up'),
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.muted,
                ),
              ),

              const SizedBox(height: 4),

              Text(
                followUpQuestion,
                style: const TextStyle(fontSize: 14, height: 1.4),
              ),
            ],

            const SizedBox(height: 12),

            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.infoSoft,
                borderRadius: BorderRadius.circular(AppRadii.xl),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.lock_outline,
                    size: 16,
                    color: AppColors.infoForeground,
                  ),
                  const SizedBox(width: 7),
                  Expanded(
                    child: Text(
                      context.tr('sim_insight_protected_note'),
                      style: const TextStyle(
                        fontSize: 12,
                        height: 1.4,
                        color: AppColors.infoForeground,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            if (action.isNotEmpty) ...[
              const SizedBox(height: 10),

              TextButton.icon(
                onPressed: () => _openFindingAction(action, finding: insight),
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  foregroundColor: foreground,
                ),
                icon: const Icon(Icons.arrow_forward, size: 16),
                label: Text(_findingActionLabel(action)),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _contextSignalLabel(String signal) => switch (signal) {
    'practical_support' => context.tr('sim_signal_support'),

    'practical_constraint' => context.tr('sim_signal_constraint'),

    'professional_guidance' => context.tr('sim_signal_professional'),

    'possible_instruction_change' => context.tr('sim_signal_needs_review'),

    _ => context.tr('sim_signal_care_context'),
  };

  Widget _findingCard(Map finding) {
    final category =
        _findingValue(finding, const ['category']) ??
        context.tr('sim_finding_default_category');
    final question =
        _findingValue(finding, const ['question', 'title', 'name']) ??
        context.tr('sim_finding_default_question');
    final answer = _findingValue(finding, const [
      'answer',
      'value',
      'response',
    ]);
    final reason = _findingValue(finding, const [
      'reason',
      'issue',
      'explanation',
      'message',
    ]);
    final recommendation = _findingValue(finding, const [
      'recommendation',
      'suggestion',
      'resolution',
      'fix',
      'how_to_fix',
    ]);
    final action = _findingValue(finding, const ['action']) ?? '';
    final actionLabel = _findingValue(finding, const [
      'actionLabel',
      'action_label',
    ]);
    final taskId = _findingValue(finding, const ['taskId', 'task_id']);
    final currentTime = _findingValue(finding, const [
      'currentTime',
      'current_time',
    ]);
    final suggestedTime = _findingValue(finding, const [
      'suggestedTime',
      'suggested_time',
    ]);
    final suggestedPeriod = _findingValue(finding, const [
      'suggestedPeriod',
      'suggested_period',
    ]);
    final canApply =
        finding['canApply'] == true || finding['can_apply'] == true;
    final why = finding['why'] is List
        ? (finding['why'] as List)
              .map((item) => item.toString().trim())
              .where((item) => item.isNotEmpty)
              .toList()
        : const <String>[];
    final suggestionKey =
        '${finding['key'] ?? taskId ?? question}:$suggestedTime';
    final rejected = rejectedSuggestionKeys.contains(suggestionKey);
    final applying = taskId != null && applyingSuggestionIds.contains(taskId);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: AppCard(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    category,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.muted,
                    ),
                  ),
                ),
                Text(
                  context.tr('sim_finding_badge'),
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.warningForeground,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(question, style: const TextStyle(fontWeight: FontWeight.w600)),
            if (answer != null) ...[
              const SizedBox(height: 5),
              Text(
                context.tr(
                  'sim_finding_your_answer',
                  values: {'answer': answer},
                ),
                style: const TextStyle(color: AppColors.muted),
              ),
            ],
            if (reason != null) ...[
              const SizedBox(height: 12),
              Text(
                context.tr('sim_finding_what_this_means'),
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 3),
              Text(reason),
            ],
            if (recommendation != null) ...[
              const SizedBox(height: 10),
              Text(
                context.tr('sim_finding_suggested_adjustment'),
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 3),
              Text(recommendation),
            ],
            if (suggestedTime != null && suggestedPeriod != null) ...[
              const SizedBox(height: 10),
              Text(
                currentTime != null && currentTime.isNotEmpty
                    ? context.tr(
                        'sim_finding_reminder_change',
                        values: {
                          'current': _displayScheduleTime(currentTime),
                          'suggested': _displayScheduleTime(suggestedTime),
                          'period': suggestedPeriod,
                        },
                      )
                    : context.tr(
                        'sim_finding_reminder_suggested',
                        values: {
                          'suggested': _displayScheduleTime(suggestedTime),
                          'period': suggestedPeriod,
                        },
                      ),
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  color: AppColors.primary,
                ),
              ),
            ],
            if (why.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                context.tr('sim_finding_why'),
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              ...why.map(
                (item) => Padding(
                  padding: const EdgeInsets.only(bottom: 3),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('• '),
                      Expanded(child: Text(item)),
                    ],
                  ),
                ),
              ),
            ],
            if (canApply &&
                taskId != null &&
                suggestedTime != null &&
                suggestedPeriod != null) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilledButton.icon(
                    onPressed: applying || rejected
                        ? null
                        : () => _applyScheduleSuggestion(
                            taskId: taskId,
                            scheduleTime: suggestedTime,
                            period: suggestedPeriod,
                          ),
                    icon: applying
                        ? const SizedBox.square(
                            dimension: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.auto_fix_high_outlined, size: 17),
                    label: Text(
                      applying
                          ? context.tr('sim_applying')
                          : actionLabel ?? context.tr('sim_finding_apply'),
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: applying || rejected
                        ? null
                        : () => _keepCurrentSuggestion(
                            suggestionKey: suggestionKey,
                            taskId: taskId,
                            scheduleTime: suggestedTime,
                            period: suggestedPeriod,
                          ),
                    icon: Icon(
                      rejected
                          ? Icons.check_circle_outline
                          : Icons.undo_outlined,
                      size: 17,
                    ),
                    label: Text(
                      rejected
                          ? context.tr('sim_finding_kept_current')
                          : context.tr('sim_finding_keep_current'),
                    ),
                  ),
                ],
              ),
            ] else if (action.isNotEmpty) ...[
              const SizedBox(height: 10),
              TextButton.icon(
                onPressed: () => _openFindingAction(action, finding: finding),
                icon: const Icon(Icons.arrow_forward, size: 16),
                label: Text(actionLabel ?? _findingActionLabel(action)),
              ),
            ],
          ],
        ),
      ),
    );
  }

  List<Map<String, dynamic>> _applicableAdaptations(CareSimulationData value) {
    final source = value.adaptations.isNotEmpty
        ? value.adaptations
        : value.findings;
    return source
        .where((finding) {
          final taskId = _findingValue(finding, const ['taskId', 'task_id']);
          final suggestedTime = _findingValue(finding, const [
            'suggestedTime',
            'suggested_time',
          ]);
          final suggestedPeriod = _findingValue(finding, const [
            'suggestedPeriod',
            'suggested_period',
          ]);
          final canApply =
              finding['canApply'] == true || finding['can_apply'] == true;
          return canApply &&
              taskId != null &&
              suggestedTime != null &&
              suggestedPeriod != null;
        })
        .map((finding) => Map<String, dynamic>.from(finding))
        .toList();
  }

  Future<void> _openAdaptMyPlan(CareSimulationData value) async {
    final planId = widget.planId;
    if (planId == null) return;
    final suggestions = _applicableAdaptations(value);
    if (suggestions.isEmpty) return;

    final result = await showModalBottomSheet<List<Map<String, String>>>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: AppColors.card,
      builder: (sheetContext) => _AdaptMyPlanSheet(
        suggestions: suggestions,
        displayTime: _displayScheduleTime,
      ),
    );
    if (result == null || result.isEmpty || !mounted) return;

    setState(() => adaptingPlan = true);
    try {
      final applied = await CarePlanService.instance.adaptPlan(planId, result);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            applied.appliedCount > 0
                ? context.tr(
                    'sim_adapt_applied_snackbar',
                    values: {'count': applied.appliedCount},
                  )
                : context.tr('sim_adapt_kept_snackbar'),
          ),
        ),
      );
      await _refreshSimulation();
    } on CarePlanException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    } finally {
      if (mounted) setState(() => adaptingPlan = false);
    }
  }

  Future<void> _applyScheduleSuggestion({
    required String taskId,
    required String scheduleTime,
    required String period,
  }) async {
    setState(() => applyingSuggestionIds.add(taskId));
    try {
      await CarePlanService.instance.confirmScheduleItem(
        taskId,
        scheduleTime: scheduleTime,
        displayTime:
            '$period · Confirmed reminder at ${_displayScheduleTime(scheduleTime)}',
        learningSource: 'ai_suggestion_accept',
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.tr(
              'sim_apply_moved_snackbar',
              values: {'time': _displayScheduleTime(scheduleTime)},
            ),
          ),
        ),
      );
      await _refreshSimulation();
    } on CarePlanException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
    } finally {
      if (mounted) {
        setState(() => applyingSuggestionIds.remove(taskId));
      }
    }
  }

  Future<void> _keepCurrentSuggestion({
    required String suggestionKey,
    required String taskId,
    required String scheduleTime,
    required String period,
  }) async {
    try {
      await CarePlanService.instance.recordRoutineSignal(
        eventType: 'suggestion_rejected',
        carePlanId: widget.planId ?? '',
        taskId: taskId,
        period: period.toLowerCase(),
        scheduleTime: scheduleTime,
        signalValue: 'Kept current reminder',
      );
      if (!mounted) return;
      setState(() => rejectedSuggestionKeys.add(suggestionKey));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr('sim_keep_current_snackbar'))),
      );
    } on CarePlanException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    }
  }

  String _displayScheduleTime(String value) {
    final parts = value.split(':');
    if (parts.length < 2) return value;
    final hour24 = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour24 == null || minute == null) return value;
    final suffix = hour24 >= 12 ? 'PM' : 'AM';
    final hour12 = hour24 % 12 == 0 ? 12 : hour24 % 12;
    return '$hour12:${minute.toString().padLeft(2, '0')} $suffix';
  }

  String _findingActionLabel(String action) =>
      switch (canonicalSimulationNavigationAction(action)) {
        'review_schedule' => context.tr('sim_action_review_schedule'),
        'family_care' => context.tr('sim_action_open_family_care'),
        'calendar' => context.tr('sim_action_open_calendar'),
        'care_plan' => context.tr('sim_action_review_care_plan'),
        'reality_check' => context.tr('sim_action_recheck_fit'),
        'review_instruction' => context.tr('sim_action_review_instruction'),
        'documents' => context.tr('documents'),
        _ => context.tr('sim_action_review_care_plan'),
      };

  Map? _findingActionTarget(Map? finding) {
    if (finding == null) return null;
    final direct = finding['target'];
    if (direct is Map) return direct;
    final action = finding['action'];
    if (action is Map && action['target'] is Map) {
      return action['target'] as Map;
    }
    return null;
  }

  int? _safeCarePlanTab(Map? finding) {
    final target = _findingActionTarget(finding);
    final raw = target?['care_plan_tab'] ?? target?['carePlanTab'];
    final parsed = raw is int ? raw : int.tryParse(raw?.toString() ?? '');
    if (parsed == null || parsed < 0 || parsed > 4) return null;
    return parsed;
  }

  void _openFindingAction(String action, {Map? finding}) {
    final planId = widget.planId;
    final resolvedAction = canonicalSimulationNavigationAction(action);

    switch (resolvedAction) {
      case 'review_schedule':
        if (planId == null) return;
        Navigator.pushNamed(
          context,
          AppRoutes.carePlan(planId),
          arguments: const CarePlanDetailArgs(
            initialTab: 1,
            returnToPrevious: true,
          ),
        );
        return;

      case 'family_care':
        Navigator.pushNamed(context, AppRoutes.family);
        return;

      case 'calendar':
        Navigator.pushNamed(
          context,
          AppRoutes.calendar,
          arguments: finding == null
              ? null
              : simulationCalendarArgsForFinding(
                  finding,
                  data?.tasks ?? const <DemoTask>[],
                ),
        );
        return;

      case 'reality_check':
        _openRealityCheck();
        return;

      case 'review_instruction':
        if (planId == null) return;
        Navigator.pushNamed(
          context,
          AppRoutes.carePlanReview,
          arguments: CarePlanReviewArgs(planId: planId, returnToPrevious: true),
        );
        return;

      case 'documents':
        if (planId == null) return;
        Navigator.pushNamed(
          context,
          AppRoutes.carePlan(planId),
          arguments: const CarePlanDetailArgs(
            initialTab: 4,
            returnToPrevious: true,
          ),
        );
        return;

      case 'care_plan':
        if (planId == null) return;
        final targetTab = _safeCarePlanTab(finding);
        Navigator.pushNamed(
          context,
          AppRoutes.carePlan(planId),
          arguments: targetTab == null
              ? null
              : CarePlanDetailArgs(
                  initialTab: targetTab,
                  returnToPrevious: true,
                ),
        );
        return;

      case 'no_change':
        return;

      default:
        // canonicalSimulationNavigationAction already fails closed to the
        // current care plan, so arbitrary AI/backend route strings are never
        // executed directly.
        _openCarePlan();
    }
  }

  String? _findingValue(Map finding, List<String> keys) {
    for (final key in keys) {
      final value = finding[key]?.toString().trim();
      if (value != null && value.isNotEmpty && value.toLowerCase() != 'null') {
        return value;
      }
    }
    return null;
  }

  Widget _activationBlockersCard(CareSimulationData value) {
    if (value.activationAllowed) {
      final hasAdjustments = value.atRisk > 0;
      return AppCard(
        padding: const EdgeInsets.all(18),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              hasAdjustments ? Icons.tune_outlined : Icons.check_circle_outline,
              color: hasAdjustments
                  ? AppColors.warningForeground
                  : AppColors.successForeground,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    hasAdjustments
                        ? context.tr('sim_activation_with_adjustments')
                        : context.tr('sim_activation_all_passed'),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    hasAdjustments
                        ? context.tr(
                            'sim_activation_adjustments_note',
                            values: {'count': value.atRisk},
                          )
                        : context.tr('sim_activation_complete_info'),
                    style: const TextStyle(color: AppColors.muted),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    final blockers = value.blockers;

    return AppCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.error_outline,
                color: AppColors.criticalForeground,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.tr('sim_blockers_title'),
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      context.tr('sim_blockers_description'),
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.muted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _blockerSummary(value),
          ...blockers.map(
            (blocker) => Padding(
              padding: const EdgeInsets.only(top: 12),
              child: _serverBlockerIssueBox(blocker),
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              OutlinedButton.icon(
                onPressed: _openCarePlan,
                icon: const Icon(Icons.edit_calendar_outlined, size: 18),
                label: Text(context.tr('sim_action_review_care_plan')),
              ),
              OutlinedButton.icon(
                onPressed: _refreshSimulation,
                icon: const Icon(Icons.refresh, size: 18),
                label: Text(context.tr('sim_refresh_check')),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _serverBlockerIssueBox(Map blocker) {
    final title =
        _findingValue(blocker, const ['title']) ??
        context.tr('sim_blocker_default_title');
    final reason =
        _findingValue(blocker, const ['reason', 'summary', 'message']) ??
        context.tr('sim_blocker_default_reason');
    final fix =
        _findingValue(blocker, const ['recommendation', 'next_step', 'fix']) ??
        context.tr('sim_blocker_default_fix');
    final action = _findingValue(blocker, const ['action']) ?? 'care_plan';
    final actionLabel = _findingValue(blocker, const [
      'actionLabel',
      'action_label',
    ]);

    return _issueBox(
      icon: Icons.block_outlined,
      title: title,
      statusText: context.tr('sim_blocker_required'),
      reason: reason,
      fix: fix,
      foreground: AppColors.criticalForeground,
      background: AppColors.criticalSoft,
      actionLabel: actionLabel ?? _findingActionLabel(action),
      onAction: () => _openFindingAction(action, finding: blocker),
    );
  }

  Widget _blockerSummary(CareSimulationData value) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.criticalSoft,
        borderRadius: BorderRadius.circular(AppRadii.xl),
      ),
      child: Text(
        context.tr(
          'sim_blocker_summary',
          values: {'count': value.hardBlockerCount},
        ),
        style: const TextStyle(
          fontWeight: FontWeight.w600,
          color: AppColors.criticalForeground,
        ),
      ),
    );
  }

  Widget _issueBox({
    required IconData icon,
    required String title,
    required String statusText,
    required String reason,
    required String fix,
    required Color foreground,
    required Color background,
    String? details,
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(AppRadii.xl),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 20, color: foreground),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: foreground,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                statusText,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: foreground,
                ),
              ),
            ],
          ),
          if (details != null) ...[
            const SizedBox(height: 7),
            Text(
              details,
              style: const TextStyle(fontSize: 12, color: AppColors.muted),
            ),
          ],
          const SizedBox(height: 10),
          Text(
            context.tr('sim_issue_why'),
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 2),
          Text(reason),
          const SizedBox(height: 9),
          Text(
            context.tr('sim_issue_how_to_fix'),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: foreground,
            ),
          ),
          const SizedBox(height: 2),
          Text(fix),
          if (onAction != null && actionLabel != null) ...[
            const SizedBox(height: 10),
            TextButton.icon(
              onPressed: onAction,
              style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                visualDensity: VisualDensity.compact,
                foregroundColor: foreground,
              ),
              icon: const Icon(Icons.arrow_forward, size: 16),
              label: Text(actionLabel),
            ),
          ],
        ],
      ),
    );
  }

  void _openCarePlan() {
    final planId = widget.planId;
    if (planId == null) return;
    Navigator.pushNamed(context, AppRoutes.carePlan(planId));
  }

  void _openRealityCheck() {
    final planId = widget.planId;
    if (planId == null) return;
    Navigator.pushNamed(
      context,
      AppRoutes.realityCheck,
      arguments: CareFlowArgs(planId: planId),
    );
  }

  String _activationMessage(CareSimulationData value) {
    if (widget.guidedSetup && setupProgress?.step != CareSetupStep.activate) {
      return context.tr('sim_activation_msg_care_gaps');
    }
    if (_canActivate(value)) {
      if (value.atRisk > 0) {
        return context.tr('sim_activation_msg_with_suggestions');
      }
      return context.tr('sim_activation_msg_ready');
    }

    return context.tr(
      'sim_activation_msg_waiting',
      values: {'count': value.hardBlockerCount},
    );
  }

  bool _canActivate(CareSimulationData value) => value.activationAllowed;

  Future<void> _activate() async {
    final planId = widget.planId;
    if (planId == null) return;

    setState(() => activating = true);

    try {
      final detail = await CarePlanService.instance.activatePlan(planId);
      final notificationResult = await NotificationService.instance
          .scheduleNextOccurrences(planId: planId, tasks: detail.tasks);
      if (!mounted) return;
      final message = !notificationResult.permissionGranted
          ? context.tr('sim_activated_no_permission')
          : !notificationResult.exactAlarmGranted
          ? context.tr('sim_activated_no_exact_alarm')
          : context.tr(
              'sim_activated_with_count',
              values: {'count': notificationResult.scheduledCount},
            );
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
      Navigator.pushNamedAndRemoveUntil(
        context,
        AppRoutes.dashboard,
        (route) => false,
      );
    } on CarePlanException catch (exception) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(exception.message)));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.tr('sim_activation_failed_snackbar'))),
        );
      }
    } finally {
      if (mounted) setState(() => activating = false);
    }
  }
}

class _AdaptDraft {
  _AdaptDraft({
    required this.taskId,
    required this.title,
    required this.currentTime,
    required this.suggestedTime,
    required this.period,
    required this.why,
  });

  final String taskId;
  final String title;
  final String currentTime;
  String suggestedTime;
  final String period;
  final List<String> why;
  bool apply = true;
  bool explicitlyKept = false;
}

class _AdaptMyPlanSheet extends StatefulWidget {
  const _AdaptMyPlanSheet({
    required this.suggestions,
    required this.displayTime,
  });

  final List<Map<String, dynamic>> suggestions;
  final String Function(String value) displayTime;

  @override
  State<_AdaptMyPlanSheet> createState() => _AdaptMyPlanSheetState();
}

class _AdaptMyPlanSheetState extends State<_AdaptMyPlanSheet> {
  late final List<_AdaptDraft> drafts;

  @override
  void initState() {
    super.initState();
    drafts = widget.suggestions.map((finding) {
      String read(List<String> keys) {
        for (final key in keys) {
          final value = finding[key]?.toString().trim() ?? '';
          if (value.isNotEmpty) return value;
        }
        return '';
      }

      final why = finding['why'] is List
          ? (finding['why'] as List)
                .map((item) => item.toString().trim())
                .where((item) => item.isNotEmpty)
                .toList()
          : <String>[];
      return _AdaptDraft(
        taskId: read(const ['taskId', 'task_id']),
        title: read(const ['question', 'title', 'name']),
        currentTime: read(const ['currentTime', 'current_time']),
        suggestedTime: read(const ['suggestedTime', 'suggested_time']),
        period: read(const ['suggestedPeriod', 'suggested_period']),
        why: why,
      );
    }).toList();
  }

  int get applyCount => drafts.where((item) => item.apply).length;
  int get keepCount => drafts.where((item) => item.explicitlyKept).length;

  Future<void> _changeTime(_AdaptDraft draft) async {
    final initial =
        _parse24Hour(draft.suggestedTime) ??
        const TimeOfDay(hour: 9, minute: 30);
    final chosen = await showTimePicker(
      context: context,
      initialTime: initial,
      helpText: context.tr(
        'sim_sheet_time_picker_help',
        values: {'period': draft.period},
      ),
    );
    if (chosen == null || !mounted) return;
    if (!isTimeInCarePeriod(draft.period, chosen)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.tr(
              'sim_sheet_invalid_time',
              values: {
                'window': carePeriodAllowedWindow(draft.period),
                'period': draft.period,
              },
            ),
          ),
        ),
      );
      return;
    }
    setState(() {
      draft.suggestedTime =
          '${chosen.hour.toString().padLeft(2, '0')}:${chosen.minute.toString().padLeft(2, '0')}';
      draft.apply = true;
      draft.explicitlyKept = false;
    });
  }

  TimeOfDay? _parse24Hour(String value) {
    final parts = value.split(':');
    if (parts.length < 2) return null;
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null || hour > 23 || minute > 59) return null;
    return TimeOfDay(hour: hour, minute: minute);
  }

  void _submit() {
    final decisions = <Map<String, String>>[];
    for (final draft in drafts) {
      if (draft.apply) {
        decisions.add({
          'taskId': draft.taskId,
          'decision': 'apply',
          'scheduleTime': draft.suggestedTime,
          'period': draft.period.toLowerCase(),
        });
      } else if (draft.explicitlyKept) {
        decisions.add({
          'taskId': draft.taskId,
          'decision': 'keep_current',
          'scheduleTime': draft.suggestedTime,
          'period': draft.period.toLowerCase(),
        });
      }
    }
    if (decisions.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr('sim_sheet_select_at_least_one'))),
      );
      return;
    }
    Navigator.pop(context, decisions);
  }

  @override
  Widget build(BuildContext context) {
    final keyboard = MediaQuery.viewInsetsOf(context).bottom;
    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, 10, 16, 16 + keyboard),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.88,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      context.tr('sim_adapt_title'),
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                    tooltip: context.tr('sim_sheet_close_tooltip'),
                  ),
                ],
              ),
              Text(
                context.tr('sim_sheet_description'),
                style: const TextStyle(color: AppColors.muted),
              ),
              const SizedBox(height: 14),
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      for (final draft in drafts) _draftCard(draft),
                      SafetyNote(text: context.tr('sim_sheet_safety_note')),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                '${context.tr('sim_sheet_selected_to_apply', values: {'count': applyCount})}${keepCount > 0 ? context.tr('sim_sheet_keep_current_count', values: {'count': keepCount}) : ''}',
                style: const TextStyle(fontSize: 13, color: AppColors.muted),
              ),
              const SizedBox(height: 8),
              FilledButton.icon(
                onPressed: _submit,
                icon: const Icon(Icons.auto_fix_high_outlined, size: 18),
                label: Text(
                  applyCount > 0
                      ? context.tr(
                          'sim_sheet_apply_button',
                          values: {'count': applyCount},
                        )
                      : context.tr('sim_sheet_save_keep_choices'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _draftCard(_AdaptDraft draft) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.secondary,
          borderRadius: BorderRadius.circular(AppRadii.xl),
          border: Border.all(
            color: draft.apply ? AppColors.primary : AppColors.border,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Checkbox(
                  value: draft.apply,
                  onChanged: (value) {
                    setState(() {
                      draft.apply = value == true;
                      if (draft.apply) draft.explicitlyKept = false;
                    });
                  },
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        draft.title.isEmpty
                            ? context.tr('sim_sheet_default_title')
                            : draft.title,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        draft.currentTime.isEmpty
                            ? '${widget.displayTime(draft.suggestedTime)} · ${draft.period}'
                            : '${widget.displayTime(draft.currentTime)} → ${widget.displayTime(draft.suggestedTime)} · ${draft.period}',
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (draft.why.isNotEmpty) ...[
              const SizedBox(height: 8),
              ...draft.why
                  .take(3)
                  .map(
                    (item) => Padding(
                      padding: const EdgeInsets.only(bottom: 3),
                      child: Text(
                        '• $item',
                        style: const TextStyle(fontSize: 13),
                      ),
                    ),
                  ),
            ],
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: () => _changeTime(draft),
                  icon: const Icon(Icons.schedule, size: 17),
                  label: Text(context.tr('sim_sheet_change')),
                ),
                TextButton.icon(
                  onPressed: () {
                    setState(() {
                      draft.apply = false;
                      draft.explicitlyKept = true;
                    });
                  },
                  icon: Icon(
                    draft.explicitlyKept
                        ? Icons.check_circle_outline
                        : Icons.undo_outlined,
                    size: 17,
                  ),
                  label: Text(
                    draft.explicitlyKept
                        ? context.tr('sim_sheet_keeping_current')
                        : context.tr('sim_sheet_keep_current'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}


class _SimulationPremiumHero extends StatelessWidget {
  const _SimulationPremiumHero({
    required this.title,
    required this.subtitle,
    required this.readiness,
    required this.needsAttention,
    required this.ready,
    required this.atRisk,
    required this.blocked,
    required this.statusLabel,
  });

  final String title;
  final String subtitle;
  final int readiness;
  final bool needsAttention;
  final int ready;
  final int atRisk;
  final int blocked;
  final String statusLabel;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF0F766E),
              Color(0xFF0D9488),
              Color(0xFF14B8A6),
            ],
          ),
          borderRadius: BorderRadius.circular(28),
          boxShadow: const [
            BoxShadow(
              color: Color(0x240F766E),
              blurRadius: 30,
              spreadRadius: -12,
              offset: Offset(0, 16),
            ),
          ],
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 560;
            final copy = Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0x20FFFFFF),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.route_outlined,
                        size: 14,
                        color: Colors.white,
                      ),
                      SizedBox(width: 6),
                      Text(
                        'Care readiness simulation',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 27,
                    height: 1.1,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -.35,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: Color(0xE6FFFFFF),
                    fontSize: 12,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 13),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _SimulationHeroChip(
                      icon: Icons.check_circle_outline_rounded,
                      label: '$ready ready',
                    ),
                    _SimulationHeroChip(
                      icon: Icons.warning_amber_rounded,
                      label: '$atRisk at risk',
                    ),
                    _SimulationHeroChip(
                      icon: Icons.block_outlined,
                      label: '$blocked blocked',
                    ),
                  ],
                ),
              ],
            );

            final score = Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0x18FFFFFF),
                borderRadius: BorderRadius.circular(AppRadii.xxl),
                border: Border.all(
                  color: const Color(0x2AFFFFFF),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Readiness',
                    style: TextStyle(
                      color: Color(0xDFFFFFFF),
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '$readiness',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 34,
                      height: 1,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    statusLabel,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            );

            if (compact) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  copy,
                  const SizedBox(height: 14),
                  score,
                ],
              );
            }

            return Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(child: copy),
                const SizedBox(width: 18),
                SizedBox(width: 150, child: score),
              ],
            );
          },
        ),
      );
}

class _SimulationHeroChip extends StatelessWidget {
  const _SimulationHeroChip({
    required this.icon,
    required this.label,
  });

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(
          horizontal: 9,
          vertical: 6,
        ),
        decoration: BoxDecoration(
          color: const Color(0x1FFFFFFF),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: Colors.white),
            const SizedBox(width: 5),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      );
}

class _SimulationPremiumLoading extends StatelessWidget {
  const _SimulationPremiumLoading();

  @override
  Widget build(BuildContext context) => Column(
        children: [
          Container(
            height: 180,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [
                  Color(0xFFE4F4F1),
                  Color(0xFFF4F8F7),
                ],
              ),
              borderRadius: BorderRadius.circular(28),
            ),
          ),
          const SizedBox(height: 14),
          AppCard(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Container(
                  width: 170,
                  height: 14,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8EEF2),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  height: 10,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8EEF2),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                const SizedBox(height: 18),
                const CircularProgressIndicator(),
              ],
            ),
          ),
        ],
      );
}

