import 'package:flutter/material.dart';

import '../core/app_routes.dart';
import '../core/app_theme.dart';
import '../core/schedule_time.dart';
import '../data/demo_data.dart';
import '../services/care_plan_service.dart';
import '../services/notification_service.dart';
import '../widgets/app_shell.dart';
import '../widgets/care_setup_progress.dart';
import '../widgets/page_header.dart';
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
    title: 'Care Simulation',
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

class _SimulationViewState extends State<SimulationView> {
  CareSimulationData? data;
  String? error;
  bool loading = true;
  bool activating = false;
  DemoPlan? plan;
  String durationMode = 'prescription';
  DateTime? endDate;
  bool savingDuration = false;
  bool adaptingPlan = false;
  CareGapListData? careGaps;
  final Set<String> applyingSuggestionIds = <String>{};
  final Set<String> rejectedSuggestionKeys = <String>{};
  CareSetupProgress? setupProgress;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    if (widget.planId == null) {
      setState(() { loading = false; error = 'Open a care plan to view its real simulation.'; });
      return;
    }
    try {
      final result = await CarePlanService.instance.fetchSimulation(widget.planId!);
      final detail = await CarePlanService.instance.fetchPlanDetail(widget.planId!);
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
          plan = detail.plan;
          durationMode = detail.plan.durationMode;
          endDate = DateTime.tryParse(detail.plan.plannedEndDate) ??
              DateTime.tryParse(detail.plan.suggestedEndDate) ??
              DateTime.now().add(const Duration(days: 7));
          loading = false;
        });
      }
    } on CarePlanException catch (exception) {
      if (mounted) setState(() { loading = false; error = exception.message; });
    } catch (_) {
      if (mounted) {
        setState(() {
          loading = false;
          error = 'The simulation could not be refreshed.';
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
    if (loading) return const Padding(padding: EdgeInsets.all(48), child: Center(child: CircularProgressIndicator()));
    if (error != null || data == null) return EmptyState(icon: Icons.route_outlined, title: 'Simulation unavailable', description: error ?? 'No simulation data found.', action: FilledButton(onPressed: () => Navigator.pushReplacementNamed(context, AppRoutes.carePlans), child: const Text('Open Care Plans')));
    final value = data!;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
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
              widget.returnToPrevious ? 'Back' : 'Back to Reality Check',
            ),
          ),
        ),
      ],
      if (!widget.compact) ...[
        const PageHeader(
          title: 'Care Simulation',
          subtitle:
              'A real view built from this plan’s verified schedule and routine answers.',
        ),
      ],
      Align(
        alignment: Alignment.centerLeft,
        child: TextButton.icon(
          onPressed: () =>
              Navigator.pushNamed(context, AppRoutes.routinePreferences),
          icon: const Icon(Icons.psychology_alt_outlined, size: 17),
          label: const Text('My Routine & Preferences'),
        ),
      ),
      const SizedBox(height: 8),
      if (widget.guidedSetup && widget.planId != null) ...[
        GuidedCareSetupProgress(
          currentStep: setupProgress?.step == CareSetupStep.activate ? 7 : 5,
          planId: widget.planId!,
          saveState: applyingSuggestionIds.isNotEmpty ? 'Saving…' : 'Saved',
        ),
        const SizedBox(height: 16),
      ],
      AppCard(padding: const EdgeInsets.all(24), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        LayoutBuilder(builder: (context, constraints) {
          final score = Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            const Text('Care Feasibility Score', style: TextStyle(fontSize: 13, color: AppColors.muted)),
            Text('${value.readiness} / 100', style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w700, color: AppColors.primary)),
            StatusBadge(
              status: value.blocked > 0 || value.atRisk > 0 || value.unclear > 0 || value.unanswered > 0
                  ? TaskStatus.atRisk
                  : TaskStatus.ready,
              label: value.blocked > 0 || value.atRisk > 0 || value.unclear > 0 || value.unanswered > 0
                  ? 'Needs Attention'
                  : 'On Track',
            ),
          ]);
          const copy = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Plan-specific simulation', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600)), SizedBox(height: 4), Text('Calculated from verified tasks and your saved practical answers.', style: TextStyle(fontSize: 14, color: AppColors.muted))]);
          return constraints.maxWidth < 600 ? Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [copy, const SizedBox(height: 16), score]) : Row(crossAxisAlignment: CrossAxisAlignment.start, children: [const Expanded(child: copy), score]);
        }),
        const SizedBox(height: 20),
        LayoutBuilder(builder: (context, constraints) {
          const gap = 12.0;
          final width = (constraints.maxWidth - gap) / 2;
          final metrics = [
            ('${value.blocked}', 'Blocked', AppColors.criticalSoft, AppColors.criticalForeground),
            ('${value.atRisk}', 'At Risk', AppColors.warningSoft, AppColors.warningForeground),
            ('${value.ready}', 'Ready', AppColors.successSoft, AppColors.successForeground),
            ('${value.unclear}', 'Unclear', AppColors.infoSoft, AppColors.infoForeground),
          ];
          return Wrap(spacing: gap, runSpacing: gap, children: metrics.map((metric) => Container(width: width, padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: metric.$3, borderRadius: BorderRadius.circular(AppRadii.xl)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(metric.$1, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: metric.$4)), Text(metric.$2, style: TextStyle(color: metric.$4))]))).toList());
        }),
        const SizedBox(height: 20),
        const SafetyNote(text: 'Care Feasibility measures practical fit only. It is not a medical-risk or clinical-outcome score.'),
      ])),
      if (value.unanswered > 0) ...[
        const SizedBox(height: 16),
        SafetyNote(text: '${value.unanswered} relevant question${value.unanswered == 1 ? '' : 's'} still need an answer, so the score is provisional.'),
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
                        const Text(
                          'Adapt My Plan',
                          style: TextStyle(
                            fontSize: 19,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '${_applicableAdaptations(value).length} practical routine adjustment${_applicableAdaptations(value).length == 1 ? '' : 's'} can be reviewed together.',
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
              const Text(
                'Review all flexible reminder suggestions at once. You can accept, change, or keep each current time before anything is saved.',
                style: TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 14),
              FilledButton.icon(
                onPressed: adaptingPlan ? null : () => _openAdaptMyPlan(value),
                icon: adaptingPlan
                    ? const SizedBox.square(
                        dimension: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.tune, size: 18),
                label: Text(adaptingPlan ? 'Applying…' : 'Adapt My Plan'),
              ),
            ],
          ),
        ),
      ],
      if (value.atRisk > 0 &&
          _applicableAdaptations(value).isEmpty &&
          value.findings.isNotEmpty) ...[
        const SizedBox(height: 20),
        const SafetyNote(
          text:
              'Routine differences were found, but none can be safely moved automatically right now. Review the findings below; explicit verified timings stay protected.',
        ),
      ],
      if (value.contextInsights.isNotEmpty) ...[
  const SizedBox(height: 24),

  const Row(
    children: [
      Icon(
        Icons.auto_awesome_outlined,
        size: 21,
        color: AppColors.primary,
      ),
      SizedBox(width: 8),
      Text(
        'AI Context Insights',
        style: TextStyle(
          fontSize: 19,
          fontWeight: FontWeight.w700,
        ),
      ),
    ],
  ),

  const SizedBox(height: 6),

  const Text(
    'SehatMate has reviewed new practical information or healthcare-professional responses connected to this care plan.',
    style: TextStyle(
      fontSize: 13,
      color: AppColors.muted,
      height: 1.4,
    ),
  ),

  const SizedBox(height: 5),

  const Text(
    'These insights can guide the next practical step, but they never automatically change verified treatment instructions.',
    style: TextStyle(
      fontSize: 12,
      color: AppColors.muted,
      height: 1.4,
    ),
  ),

  const SizedBox(height: 12),

  ...value.contextInsights.map(
    _contextInsightCard,
  ),
],
      if (value.findings.isNotEmpty) ...[
        const SizedBox(height: 24),
        const Text(
          'Practical findings',
          style: TextStyle(fontSize: 19, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 6),
        const Text(
          'These are the routine answers used by the simulation. Any reason or recommendation returned by the server is shown here too.',
          style: TextStyle(fontSize: 13, color: AppColors.muted),
        ),
        const SizedBox(height: 12),
        ...value.findings.map((finding) => _findingCard(finding)),
      ],
      const SizedBox(height: 20),
      _activationBlockersCard(value),
      const SizedBox(height: 24),
      const Text('Scheduled tasks', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w600)),
      const SizedBox(height: 12),
      ...value.tasks.map((task) => Padding(padding: const EdgeInsets.only(bottom: 10), child: AppCard(padding: const EdgeInsets.all(16), child: Row(children: [
        Icon(task.icon, color: AppColors.primary), const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(task.title, style: const TextStyle(fontWeight: FontWeight.w600)), Text('${task.time}${task.note.isEmpty ? '' : ' · ${task.note}'}', maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppColors.muted))])),
        const SizedBox(width: 8), StatusBadge(status: task.status),
      ])))),
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
                    ? 'Care Gaps check is ready'
                    : '${careGaps?.summary.open ?? 0} care gap${(careGaps?.summary.open ?? 0) == 1 ? '' : 's'} need review',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 6),
              Text(
                (careGaps?.summary.open ?? 0) == 0
                    ? 'Continue through Care Gaps once so the guided setup confirms there are no required unresolved issues.'
                    : 'Continue to the plan-specific Care Gaps step. Review open practical issues and resolve required blockers, then run the final simulation before activation.',
                style: const TextStyle(fontSize: 14, color: AppColors.muted),
              ),
              const SizedBox(height: 14),
              FilledButton.icon(
                onPressed: _continueToCareGaps,
                icon: const Icon(Icons.arrow_forward, size: 17),
                label: const Text('Continue to Care Gaps'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
      ],
      if (!widget.guidedSetup ||
          setupProgress?.step == CareSetupStep.activate) ...[
        const SizedBox(height: 16),
        _durationCard(),
        const SizedBox(height: 16),
        AppCard(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                _canActivate(value) ? 'Ready to activate?' : 'Activation requirements',
                style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 6),
              Text(
                _activationMessage(value),
                style: const TextStyle(color: AppColors.muted),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: !_canActivate(value) || activating ? null : _activate,
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
                  activating ? 'Activating…' : 'Activate Care Plan',
                ),
              ),
            ],
          ),
        ),
      ],
    ]);
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error.message)),
        );
      }
    }
  }
  Widget _contextInsightCard(
  Map insight,
) {
  final signal =
      _findingValue(
        insight,
        const ['signal'],
      ) ??
      'neutral';

  final summary =
      _findingValue(
        insight,
        const ['summary'],
      ) ??
      'New care context has been recorded.';

  final nextAction =
      _findingValue(
        insight,
        const [
          'nextAction',
          'next_action',
        ],
      ) ??
      'no_change';

  final followUpQuestion =
      _findingValue(
        insight,
        const [
          'followUpQuestion',
          'follow_up_question',
        ],
      );

  final rawRequiresReview =
      insight[
          'requiresInstructionReview'] ??
      insight[
          'requires_instruction_review'];

  final requiresInstructionReview =
      rawRequiresReview == true ||
      rawRequiresReview == 1 ||
      rawRequiresReview
              ?.toString()
              .toLowerCase() ==
          'true';

  final String title;
  final IconData icon;
  final Color foreground;
  final Color background;

  if (requiresInstructionReview ||
      signal ==
          'possible_instruction_change') {
    title =
        'Professional instruction review needed';

    icon =
        Icons.medical_information_outlined;

    foreground =
        AppColors.criticalForeground;

    background =
        AppColors.criticalSoft;
  } else if (signal ==
      'practical_support') {
    title =
        'New practical support detected';

    icon =
        Icons.support_agent_outlined;

    foreground =
        AppColors.successForeground;

    background =
        AppColors.successSoft;
  } else if (signal ==
      'practical_constraint') {
    title =
        'Practical constraint detected';

    icon =
        Icons.warning_amber_rounded;

    foreground =
        AppColors.warningForeground;

    background =
        AppColors.warningSoft;
  } else if (signal ==
      'professional_guidance') {
    title =
        'Professional guidance added';

    icon =
        Icons.fact_check_outlined;

    foreground =
        AppColors.infoForeground;

    background =
        AppColors.infoSoft;
  } else {
    title =
        'New care context';

    icon =
        Icons.auto_awesome_outlined;

    foreground =
        AppColors.infoForeground;

    background =
        AppColors.infoSoft;
  }

  final String action;

  if (requiresInstructionReview ||
      nextAction ==
          'review_verified_instruction') {
    action =
        'review_instruction';
  } else if (nextAction ==
          'recheck_reality' ||
      nextAction ==
          'keep_at_risk') {
    action =
        'reality_check';
  } else {
    action = '';
  }

  return Padding(
    padding:
        const EdgeInsets.only(
      bottom: 10,
    ),
    child: AppCard(
      padding:
          const EdgeInsets.all(
        16,
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              Container(
                width: 38,
                height: 38,
                decoration:
                    BoxDecoration(
                  color: background,
                  borderRadius:
                      BorderRadius.circular(
                    12,
                  ),
                ),
                child: Icon(
                  icon,
                  size: 20,
                  color: foreground,
                ),
              ),

              const SizedBox(
                width: 11,
              ),

              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style:
                          const TextStyle(
                        fontSize: 15,
                        fontWeight:
                            FontWeight.w700,
                      ),
                    ),

                    const SizedBox(
                      height: 3,
                    ),

                    Text(
                      _contextSignalLabel(
                        signal,
                      ),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight:
                            FontWeight.w600,
                        color: foreground,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(
            height: 12,
          ),

          Text(
            summary,
            style:
                const TextStyle(
              fontSize: 14,
              height: 1.45,
            ),
          ),

          if (followUpQuestion !=
              null) ...[
            const SizedBox(
              height: 12,
            ),

            const Text(
              'What to confirm next',
              style:
                  TextStyle(
                fontSize: 12,
                fontWeight:
                    FontWeight.w700,
                color:
                    AppColors.muted,
              ),
            ),

            const SizedBox(
              height: 4,
            ),

            Text(
              followUpQuestion,
              style:
                  const TextStyle(
                fontSize: 14,
                height: 1.4,
              ),
            ),
          ],

          const SizedBox(
            height: 12,
          ),

          Container(
            width:
                double.infinity,
            padding:
                const EdgeInsets.all(
              10,
            ),
            decoration:
                BoxDecoration(
              color:
                  AppColors.infoSoft,
              borderRadius:
                  BorderRadius.circular(
                AppRadii.xl,
              ),
            ),
            child:
                const Row(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.lock_outline,
                  size: 16,
                  color: AppColors
                      .infoForeground,
                ),
                SizedBox(
                  width: 7,
                ),
                Expanded(
                  child: Text(
                    'Verified treatment instructions are protected. This insight does not automatically change dose, frequency, treatment, or an explicit verified time.',
                    style:
                        TextStyle(
                      fontSize: 12,
                      height: 1.4,
                      color: AppColors
                          .infoForeground,
                    ),
                  ),
                ),
              ],
            ),
          ),

          if (action
              .isNotEmpty) ...[
            const SizedBox(
              height: 10,
            ),

            TextButton.icon(
              onPressed: () =>
                  _openFindingAction(
                action,
              ),
              style:
                  TextButton.styleFrom(
                padding:
                    EdgeInsets.zero,
                foregroundColor:
                    foreground,
              ),
              icon:
                  const Icon(
                Icons.arrow_forward,
                size: 16,
              ),
              label: Text(
                _findingActionLabel(
                  action,
                ),
              ),
            ),
          ],
        ],
      ),
    ),
  );
}


String _contextSignalLabel(
  String signal,
) =>
    switch (signal) {
      'practical_support' =>
        'Practical support',

      'practical_constraint' =>
        'Practical constraint',

      'professional_guidance' =>
        'Healthcare-professional context',

      'possible_instruction_change' =>
        'Needs verified instruction review',

      _ =>
        'Care context',
    };

  Widget _findingCard(Map finding) {
    final category = _findingValue(finding, const ['category']) ?? 'Routine';
    final question = _findingValue(
          finding,
          const ['question', 'title', 'name'],
        ) ??
        'Routine finding';
    final answer = _findingValue(
      finding,
      const ['answer', 'value', 'response'],
    );
    final reason = _findingValue(
      finding,
      const ['reason', 'issue', 'explanation', 'message'],
    );
    final recommendation = _findingValue(
      finding,
      const [
        'recommendation',
        'suggestion',
        'resolution',
        'fix',
        'how_to_fix',
      ],
    );
    final action = _findingValue(finding, const ['action']) ?? '';
    final actionLabel =
        _findingValue(finding, const ['actionLabel', 'action_label']);
    final taskId = _findingValue(finding, const ['taskId', 'task_id']);
    final currentTime =
        _findingValue(finding, const ['currentTime', 'current_time']);
    final suggestedTime =
        _findingValue(finding, const ['suggestedTime', 'suggested_time']);
    final suggestedPeriod =
        _findingValue(finding, const ['suggestedPeriod', 'suggested_period']);
    final canApply = finding['canApply'] == true ||
        finding['can_apply'] == true;
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
                const Text(
                  'Routine adjustment',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.warningForeground,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              question,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            if (answer != null) ...[
              const SizedBox(height: 5),
              Text(
                'Your answer: $answer',
                style: const TextStyle(color: AppColors.muted),
              ),
            ],
            if (reason != null) ...[
              const SizedBox(height: 12),
              const Text(
                'What this means',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 3),
              Text(reason),
            ],
            if (recommendation != null) ...[
              const SizedBox(height: 10),
              const Text(
                'Suggested adjustment',
                style: TextStyle(
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
                    ? 'Reminder: ${_displayScheduleTime(currentTime)} → ${_displayScheduleTime(suggestedTime)} · $suggestedPeriod'
                    : 'Suggested reminder: ${_displayScheduleTime(suggestedTime)} · $suggestedPeriod',
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  color: AppColors.primary,
                ),
              ),
            ],
            if (why.isNotEmpty) ...[
              const SizedBox(height: 10),
              const Text(
                'Why this suggestion?',
                style: TextStyle(
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
                          ? 'Applying…'
                          : actionLabel ?? 'Apply suggestion',
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
                    label: Text(rejected ? 'Kept current' : 'Keep current'),
                  ),
                ],
              ),
            ] else if (action.isNotEmpty) ...[
              const SizedBox(height: 10),
              TextButton.icon(
                onPressed: () => _openFindingAction(action),
                icon: const Icon(Icons.arrow_forward, size: 16),
                label: Text(actionLabel ?? _findingActionLabel(action)),
              ),
            ],
          ],
        ),
      ),
    );
  }

  List<Map<String, dynamic>> _applicableAdaptations(
    CareSimulationData value,
  ) {
    final source =
        value.adaptations.isNotEmpty ? value.adaptations : value.findings;
    return source.where((finding) {
      final taskId = _findingValue(finding, const ['taskId', 'task_id']);
      final suggestedTime =
          _findingValue(finding, const ['suggestedTime', 'suggested_time']);
      final suggestedPeriod =
          _findingValue(finding, const ['suggestedPeriod', 'suggested_period']);
      final canApply = finding['canApply'] == true || finding['can_apply'] == true;
      return canApply &&
          taskId != null &&
          suggestedTime != null &&
          suggestedPeriod != null;
    }).map((finding) => Map<String, dynamic>.from(finding)).toList();
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
                ? '${applied.appliedCount} routine adjustment${applied.appliedCount == 1 ? '' : 's'} applied. Simulation and Care Gaps were re-checked.'
                : 'Current reminders kept. SehatMate saved your choices for future suggestions.',
          ),
        ),
      );
      await _refreshSimulation();
    } on CarePlanException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message)),
      );
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
            'Reminder moved to ${_displayScheduleTime(scheduleTime)}. Your Reality Check answer was kept unchanged.',
          ),
        ),
      );
      await _refreshSimulation();
    } on CarePlanException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error.message)),
        );
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
        const SnackBar(
          content: Text(
            'Current reminder kept. SehatMate will use this choice as a learning signal.',
          ),
        ),
      );
    } on CarePlanException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message)),
      );
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

String _findingActionLabel(
  String action,
) =>
    switch (action) {
      'schedule' =>
        'Review schedule',

      'family_care' =>
        'Open Family Care',

      'calendar' =>
        'Open Calendar',

      'care_plan' =>
        'Review care plan',

      'reality_check' =>
        'Re-check practical fit',

      'review_instruction' =>
        'Review verified instruction',

      _ =>
        'Review',
    };

 void _openFindingAction(
  String action,
) {
  final planId =
      widget.planId;

  switch (action) {
    case 'schedule':
      if (planId == null) {
        return;
      }

      Navigator.pushNamed(
        context,
        AppRoutes.carePlan(
          planId,
        ),
        arguments:
            const CarePlanDetailArgs(
          initialTab: 1,
          returnToPrevious:
              true,
        ),
      );

      return;

    case 'family_care':
      Navigator.pushNamed(
        context,
        AppRoutes.family,
      );

      return;

    case 'calendar':
      Navigator.pushNamed(
        context,
        AppRoutes.calendar,
      );

      return;

    case 'care_plan':
      if (planId != null) {
        Navigator.pushNamed(
          context,
          AppRoutes.carePlan(
            planId,
          ),
        );
      }

      return;

    // NEW
    case 'reality_check':
      _openRealityCheck();
      return;

    // NEW
    case 'review_instruction':
      if (planId == null) {
        return;
      }

      Navigator.pushNamed(
        context,
        AppRoutes
            .carePlanReview,
        arguments:
            CarePlanReviewArgs(
          planId: planId,
          returnToPrevious:
              true,
        ),
      );

      return;

    default:
      _openRealityCheck();
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
              hasAdjustments
                  ? Icons.tune_outlined
                  : Icons.check_circle_outline,
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
                        ? 'Plan can activate with routine adjustments'
                        : 'All required activation checks passed',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    hasAdjustments
                        ? '${value.atRisk} practical suggestion${value.atRisk == 1 ? '' : 's'} ${value.atRisk == 1 ? 'is' : 'are'} shown above. They are recommendations, not blockers. Keep your honest Reality Check answers and apply only the adjustments that fit your routine.'
                        : 'The required instruction, schedule, and Reality Check information is complete.',
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
          const Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.error_outline,
                color: AppColors.criticalForeground,
              ),
              SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Required items before activation',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(height: 3),
                    Text(
                      'Only required missing or unverified items block activation. Routine mismatches are shown separately as suggestions.',
                      style: TextStyle(
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
                label: const Text('Review care plan'),
              ),
              OutlinedButton.icon(
                onPressed: _refreshSimulation,
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('Refresh check'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _serverBlockerIssueBox(Map blocker) {
    final title =
        _findingValue(blocker, const ['title']) ?? 'Required care-plan item';
    final reason = _findingValue(
          blocker,
          const ['reason', 'summary', 'message'],
        ) ??
        'This required item is not complete yet.';
    final fix = _findingValue(
          blocker,
          const ['recommendation', 'next_step', 'fix'],
        ) ??
        'Review this item and complete the required information.';
    final action = _findingValue(blocker, const ['action']) ?? 'care_plan';

    return _issueBox(
      icon: Icons.block_outlined,
      title: title,
      statusText: 'Required',
      reason: reason,
      fix: fix,
      foreground: AppColors.criticalForeground,
      background: AppColors.criticalSoft,
      actionLabel: _findingActionLabel(action),
      onAction: () => _openFindingAction(action),
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
        '${value.hardBlockerCount} required item${value.hardBlockerCount == 1 ? '' : 's'} must be completed before activation.',
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
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.muted,
              ),
            ),
          ],
          const SizedBox(height: 10),
          const Text(
            'Why',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 2),
          Text(reason),
          const SizedBox(height: 9),
          Text(
            'How to fix',
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
      return 'Continue to Care Gaps before activation. After that step, SehatMate will bring you back here for the final simulation.';
    }
    if (_canActivate(value)) {
      if (value.atRisk > 0) {
        return 'The required checks are complete. You can activate now and keep the current routine, or apply any practical suggestions above first.';
      }
      return 'All required activation checks passed. Confirmed exact times will be used for reminders on this device.';
    }

    return 'Activation is waiting for ${value.hardBlockerCount} required item${value.hardBlockerCount == 1 ? '' : 's'}. Routine suggestions do not block activation.';
  }

  bool _canActivate(CareSimulationData value) => value.activationAllowed;

  Widget _durationCard() => AppCard(
    padding: const EdgeInsets.all(20),
    child: RadioGroup<String>(
      groupValue: durationMode,
      onChanged: (value) {
        if (value == null) return;
        setState(() => durationMode = value);
        if (value == 'custom') {
          _pickEndDate();
        }
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Plan duration',
            style: TextStyle(fontSize: 19, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 6),
          const Text(
            'Medicine-specific durations remain unchanged.',
            style: TextStyle(color: AppColors.muted),
          ),
          const SizedBox(height: 12),
          RadioListTile<String>(
            contentPadding: EdgeInsets.zero,
            value: 'prescription',
            title: const Text('Use prescription duration'),
            subtitle: Text(
              plan?.suggestedEndDate.isNotEmpty == true
                  ? 'Suggested end: ${plan!.suggestedEndDate}'
                  : 'Uses the latest verified instruction end date',
            ),
          ),
          RadioListTile<String>(
            contentPadding: EdgeInsets.zero,
            value: 'custom',
            title: const Text('Choose end date'),
            subtitle: Text(
              endDate == null
                  ? 'No date selected'
                  : '${endDate!.year}-${endDate!.month.toString().padLeft(2, '0')}-${endDate!.day.toString().padLeft(2, '0')}',
            ),
          ),
          const RadioListTile<String>(
            contentPadding: EdgeInsets.zero,
            value: 'ongoing',
            title: Text('Ongoing plan'),
            subtitle: Text(
              'The plan stays active; fixed medicine durations still stop as prescribed.',
            ),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: savingDuration ? null : _saveDuration,
            icon: savingDuration
                ? const SizedBox.square(
                    dimension: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.event_available_outlined),
            label: const Text('Save duration'),
          ),
        ],
      ),
    ),
  );

  Future<void> _pickEndDate() async {
    final selected = await showDatePicker(context: context, initialDate: endDate ?? DateTime.now().add(const Duration(days: 7)), firstDate: DateTime.now(), lastDate: DateTime.now().add(const Duration(days: 3650)));
    if (selected != null && mounted) setState(() => endDate = selected);
  }

  String? get _endDateText => durationMode == 'ongoing' ? null : endDate == null ? null : '${endDate!.year}-${endDate!.month.toString().padLeft(2, '0')}-${endDate!.day.toString().padLeft(2, '0')}';

  Future<void> _saveDuration() async {
    if (durationMode != 'ongoing' && endDate == null) { await _pickEndDate(); if (endDate == null) return; }
    setState(() => savingDuration = true);
    try {
      await CarePlanService.instance.savePlanDuration(widget.planId!, mode: durationMode, endDate: _endDateText);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Plan duration saved.')));
    } on CarePlanException catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.message)));
    } finally { if (mounted) setState(() => savingDuration = false); }
  }

  Future<void> _activate() async {
    final planId = widget.planId;
    if (planId == null) return;
    setState(() => activating = true);
    try {
      await CarePlanService.instance.savePlanDuration(planId, mode: durationMode, endDate: _endDateText);
      final detail = await CarePlanService.instance.activatePlan(planId);
      final notificationResult = await NotificationService.instance.scheduleNextOccurrences(
        planId: planId,
        tasks: detail.tasks,
      );
      if (!mounted) return;
      final message = !notificationResult.permissionGranted
          ? 'Care plan activated, but notification permission was not granted.'
          : !notificationResult.exactAlarmGranted
              ? 'Care plan activated. Allow exact alarms in Android settings to enable reminders.'
              : 'Care plan activated. ${notificationResult.scheduledCount} reminder${notificationResult.scheduledCount == 1 ? '' : 's'} scheduled.';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
      Navigator.pushNamedAndRemoveUntil(context, AppRoutes.dashboard, (route) => false);
    } on CarePlanException catch (exception) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(exception.message)));
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('The care plan could not be activated on this device.')),
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
        title: read(const ['question', 'title', 'name']).isEmpty
            ? 'Routine reminder'
            : read(const ['question', 'title', 'name']),
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
    final initial = _parse24Hour(draft.suggestedTime) ?? const TimeOfDay(hour: 9, minute: 30);
    final chosen = await showTimePicker(
      context: context,
      initialTime: initial,
      helpText: 'Choose another ${draft.period} reminder',
    );
    if (chosen == null || !mounted) return;
    if (!isTimeInCarePeriod(draft.period, chosen)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Choose a time inside the ${carePeriodAllowedWindow(draft.period)} ${draft.period} period.',
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
        const SnackBar(
          content: Text('Select at least one adjustment or choose Keep current.'),
        ),
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
                  const Expanded(
                    child: Text(
                      'Adapt My Plan',
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                    tooltip: 'Close',
                  ),
                ],
              ),
              const Text(
                'Review flexible reminder changes together. Medical instructions are not changed.',
                style: TextStyle(color: AppColors.muted),
              ),
              const SizedBox(height: 14),
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      for (final draft in drafts) _draftCard(draft),
                      const SafetyNote(
                        text:
                            'SehatMate only applies flexible reminder changes shown here. Explicit clinician-specified times cannot be moved automatically.',
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                '$applyCount selected to apply${keepCount > 0 ? ' · $keepCount keep current' : ''}',
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.muted,
                ),
              ),
              const SizedBox(height: 8),
              FilledButton.icon(
                onPressed: _submit,
                icon: const Icon(Icons.auto_fix_high_outlined, size: 18),
                label: Text(
                  applyCount > 0
                      ? 'Apply $applyCount selected adjustment${applyCount == 1 ? '' : 's'}'
                      : 'Save Keep current choices',
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
                        draft.title,
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
              ...draft.why.take(3).map(
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
                  label: const Text('Change'),
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
                    draft.explicitlyKept ? 'Keeping current' : 'Keep current',
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

