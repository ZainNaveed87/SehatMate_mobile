import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/app_routes.dart';
import '../core/app_theme.dart';
import '../data/demo_data.dart';
import '../localization/language_scope.dart';
import '../services/auth_service.dart';
import '../services/care_plan_service.dart';
import '../widgets/app_shell.dart';
import '../widgets/care_setup_progress.dart';
import '../widgets/page_header.dart';
import '../widgets/status_badge.dart';
import '../widgets/ui.dart';
import 'reality_check_screen.dart';

String _realityQuestionKeyForGap(CareGapItemData gap) {
  final sourceKind = gap.sourceKind.trim().toLowerCase();

  final sourceId = gap.sourceId.trim();

  if (sourceKind == 'reality_check' && sourceId.isNotEmpty) {
    return sourceId;
  }

  return '';
}

String _realityReviewContextLabel(CareGapItemData gap) {
  var title = gap.title.trim();

  const suffix = ' has a practical routine conflict';

  if (title.toLowerCase().endsWith(suffix)) {
    title = title.substring(0, title.length - suffix.length);
  }

  title = title.trim();

  final when = gap.whenText.trim();

  if (title.isEmpty) {
    return when;
  }

  if (when.isEmpty) {
    return title;
  }

  return '$title · $when';
}

Future<void> _navigateToGapAction(
  BuildContext context,
  CareGapItemData gap,
) async {
  final planId = gap.targetCarePlanId.isNotEmpty
      ? gap.targetCarePlanId
      : gap.carePlanId;

  switch (gap.actionType) {
    case 'review_instruction':
      await Navigator.pushNamed(
        context,
        AppRoutes.carePlanReview,
        arguments: CarePlanReviewArgs(planId: planId, returnToPrevious: true),
      );
      return;

    case 'review_schedule':
      await Navigator.pushNamed(
        context,
        AppRoutes.carePlan(planId),
        arguments: CarePlanDetailArgs(
          initialTab: gap.targetCarePlanTab ?? 1,
          returnToPrevious: true,
        ),
      );
      return;

    case 'reality_check':
      final questionKey = _realityQuestionKeyForGap(gap);

      if (questionKey.isNotEmpty) {
        await Navigator.pushNamed(
          context,
          AppRoutes.realityCheck,
          arguments: FocusedRealityCheckArgs(
            planId: planId,
            questionKey: questionKey,
            reviewContextLabel: _realityReviewContextLabel(gap),
          ),
        );
      } else {
        // Safe fallback for old or non-specific
        // Reality Check care gaps.
        await Navigator.pushNamed(
          context,
          AppRoutes.realityCheck,
          arguments: CareFlowArgs(planId: planId, returnToPrevious: true),
        );
      }

      return;

    case 'documents':
      await Navigator.pushNamed(
        context,
        AppRoutes.carePlanUpload,
        arguments: CarePlanUploadArgs(
          planId: planId,
          documentTypes: const [],
          returnToPrevious: true,
        ),
      );
      return;

    case 'family_care':
      await Navigator.pushNamed(context, AppRoutes.family);
      return;

    case 'calendar':
      await Navigator.pushNamed(context, AppRoutes.calendar);
      return;

    case 'care_plan':
    default:
      await Navigator.pushNamed(
        context,
        AppRoutes.carePlan(planId),
        arguments: CarePlanDetailArgs(
          initialTab: gap.targetCarePlanTab ?? 0,
          returnToPrevious: true,
        ),
      );
  }
}

/// Maps internal severity values to localized display text.
/// Internal values remain unchanged for logic comparisons.
String _localizedSeverityLabel(BuildContext context, String raw) =>
    switch (raw) {
      'Blocking' => context.tr('gap_severity_blocking'),
      'Needs attention' => context.tr('gap_severity_needs_attention'),
      'Previously blocking' => context.tr('gap_severity_previously_blocking'),
      _ => raw,
    };

/// Maps internal lifecycle values to localized display text.
String _localizedLifecycleLabel(BuildContext context, String raw) =>
    switch (raw) {
      'In progress' => context.tr('gap_lifecycle_in_progress'),
      'Resolved' => context.tr('gap_lifecycle_resolved'),
      'Open' => context.tr('gap_lifecycle_open'),
      _ => raw,
    };

/// Maps internal gap-type values to localized display text.
String _localizedTypeLabel(BuildContext context, String raw) => switch (raw) {
  'Missing information' => context.tr('gap_type_missing_information'),
  'Schedule gap' => context.tr('gap_type_schedule_gap'),
  'Overdue' => context.tr('gap_type_overdue'),
  'Verification' => context.tr('gap_type_verification'),
  'Document gap' => context.tr('gap_type_document_gap'),
  'Care coordination' => context.tr('gap_type_care_coordination'),
  'Care gap' => context.tr('gap_type_care_gap'),
  _ => raw,
};

/// Maps internal actionType to a localized display label.
/// Falls back to the raw actionLabel for unknown/unmapped types.
String _localizedActionLabel(BuildContext context, CareGapItemData gap) =>
    switch (gap.actionType) {
      'review_instruction' => context.tr('gap_action_review_instruction'),
      'review_schedule' => context.tr('gap_action_review_schedule'),
      'reality_check' => context.tr('gap_action_reality_check'),
      'documents' => context.tr('gap_action_upload_documents'),
      'family_care' => context.tr('gap_action_family_care'),
      'calendar' => context.tr('gap_action_calendar'),
      'care_plan' => context.tr('gap_action_review_care_plan'),
      _ => gap.actionLabel,
    };

class CareGapsScreen extends StatefulWidget {
  const CareGapsScreen({
    super.key,
    this.planId,
    this.guidedSetup = false,
    this.returnToPrevious = false,
  });

  final String? planId;
  final bool guidedSetup;
  final bool returnToPrevious;

  @override
  State<CareGapsScreen> createState() => _CareGapsScreenState();
}

class _CareGapsScreenState extends State<CareGapsScreen> {
  String filter = 'All';

  static const filters = ['All', 'Blocking', 'Needs attention', 'In Progress'];

  bool loading = true;

  String? error;

  List<CareGapItemData> gaps = const [];

  Map<String, String> planTitles = const {};

  @override
  void initState() {
    super.initState();

    if (AuthSession.instance.isGuest) {
      loading = false;
    } else {
      _load();
    }
  }

  Future<void> _load({bool forceRefresh = false}) async {
    if (AuthSession.instance.isGuest) {
      return;
    }

    if (mounted) {
      setState(() {
        loading = true;
        error = null;
      });
    }

    try {
      final plans = await CarePlanService.instance.fetchPlans();

      final scopedPlans = widget.planId == null
          ? plans
          : plans.where((plan) => plan.id == widget.planId).toList();

      final results = await Future.wait(
        scopedPlans.map(
          (plan) => forceRefresh
              ? CarePlanService.instance.refreshCareGaps(plan.id)
              : CarePlanService.instance.fetchCareGaps(plan.id),
        ),
      );

      if (!mounted) return;

      setState(() {
        planTitles = {for (final plan in scopedPlans) plan.id: plan.title};

        gaps = results.expand((result) => result.gaps).toList()
          ..sort((a, b) {
            if (a.isResolved != b.isResolved) {
              return a.isResolved ? 1 : -1;
            }

            if (a.blocking != b.blocking) {
              return a.blocking ? -1 : 1;
            }

            return a.title.toLowerCase().compareTo(b.title.toLowerCase());
          });

        loading = false;
      });
    } on CarePlanException catch (exception) {
      if (!mounted) return;

      setState(() {
        loading = false;
        error = exception.message;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        loading = false;
        error = context.tr('care_gaps_load_failed');
      });
    }
  }

  List<CareGapItemData> get visibleGaps => switch (filter) {
    'Blocking' => gaps.where((gap) => gap.blocking && !gap.isResolved).toList(),
    'Needs attention' =>
      gaps
          .where(
            (gap) =>
                !gap.isResolved &&
                gap.severity == 'attention' &&
                !gap.isInProgress,
          )
          .toList(),
    'In Progress' => gaps.where((gap) => gap.isInProgress).toList(),
    _ => gaps.where((gap) => !gap.isResolved).toList(),
  };

  @override
  Widget build(BuildContext context) {
    if (AuthSession.instance.isGuest) {
      return _guestScreen();
    }

    final openCount = gaps.where((gap) => !gap.isResolved).length;

    final blockingCount = gaps
        .where((gap) => gap.blocking && !gap.isResolved)
        .length;

    return AppShell(
      currentRoute: AppRoutes.careGaps,
      title: context.tr('care_gaps'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.guidedSetup && widget.planId != null)
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
                    AppRoutes.simulation,
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
                      : context.tr('back_to_simulation'),
                ),
              ),
            ),

          PageHeader(
            title: context.tr('care_gaps'),
            subtitle: loading
                ? context.tr('care_gaps_checking')
                : context.tr(
                    'care_gaps_counts',
                    values: {'open': openCount, 'blocking': blockingCount},
                  ),
            action: OutlinedButton.icon(
              onPressed: loading ? null : () => _load(forceRefresh: true),
              icon: const Icon(Icons.refresh, size: 17),
              label: Text(context.tr('refresh')),
            ),
          ),

          if (widget.guidedSetup && widget.planId != null) ...[
            GuidedCareSetupProgress(
              currentStep: 6,
              planId: widget.planId!,
              saveState: loading ? context.tr('saving') : context.tr('saved'),
            ),
            const SizedBox(height: 16),
          ],

          if (error != null) ...[
            SafetyNote(text: error!),
            const SizedBox(height: 16),
          ],

          _filterBar(),

          if (!loading && visibleGaps.isNotEmpty) ...[
            const SizedBox(height: 16),
            _groupedSummaryCard(),
          ],

          const SizedBox(height: 20),

          if (loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 48),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (visibleGaps.isEmpty)
            EmptyState(
              icon: Icons.shield_outlined,
              title: context.tr('care_gaps_ready_title'),
              description: context.tr('care_gaps_empty_filter'),
            )
          else
            ..._groupedGapSections(),

          if (widget.guidedSetup &&
              !widget.returnToPrevious &&
              widget.planId != null) ...[
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: blockingCount > 0
                    ? null
                    : _continueToFinalSimulation,
                icon: const Icon(Icons.refresh, size: 17),
                label: Text(
                  blockingCount > 0
                      ? context.tr('resolve_blockers_first')
                      : context.tr('run_final_simulation'),
                ),
              ),
            ),
          ],

          const SizedBox(height: 12),

          SafetyNote(text: context.tr('care_gaps_safety_note')),
        ],
      ),
    );
  }

  Future<void> _continueToFinalSimulation() async {
    final planId = widget.planId;

    if (planId == null) return;

    try {
      await CarePlanService.instance.updateSetupStep(
        planId,
        CareSetupStep.activate,
      );

      if (!mounted) return;

      Navigator.pushReplacementNamed(
        context,
        AppRoutes.simulation,
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

  String _groupKey(CareGapItemData gap) => switch (gap.gapType) {
    'schedule_gap' => 'schedule_issues',

    'missing_information' => 'missing_information',

    'document_gap' => 'document_issues',

    'verification' => 'verification',

    'overdue' => 'overdue',

    'care_coordination' => 'care_coordination',

    _ => gap.typeLabel,
  };

  Map<String, List<CareGapItemData>> get _visibleGroups {
    final grouped = <String, List<CareGapItemData>>{};

    for (final gap in visibleGaps) {
      grouped.putIfAbsent(_groupKey(gap), () => []).add(gap);
    }

    return grouped;
  }

  Widget _groupedSummaryCard() {
    final groups = _visibleGroups;

    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            context.tr('current_issues_by_type'),
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
          ),

          const SizedBox(height: 4),

          Text(
            context.tr('care_gap_group_help'),
            style: const TextStyle(fontSize: 13, color: AppColors.muted),
          ),

          const SizedBox(height: 12),

          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: groups.entries.map((entry) {
              final blocking = entry.value.where((gap) => gap.blocking).length;

              final groupLabel = context.tr(entry.key);

              return Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 9,
                ),
                decoration: BoxDecoration(
                  color: blocking > 0
                      ? AppColors.criticalSoft
                      : AppColors.warningSoft,
                  borderRadius: BorderRadius.circular(99),
                ),
                child: Text(
                  blocking > 0
                      ? context.tr(
                          'care_gap_group_chip_blocking',
                          values: {
                            'count': entry.value.length,
                            'type': groupLabel,
                            'blocking': blocking,
                          },
                        )
                      : context.tr(
                          'care_gap_group_chip',
                          values: {
                            'count': entry.value.length,
                            'type': groupLabel,
                          },
                        ),
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: blocking > 0
                        ? AppColors.criticalForeground
                        : AppColors.warningForeground,
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  List<Widget> _groupedGapSections() {
    final groups = _visibleGroups;

    final widgets = <Widget>[];

    for (final entry in groups.entries) {
      if (entry.value.length == 1) {
        widgets.add(_gapCard(entry.value.first));
        continue;
      }

      final blocking = entry.value.where((gap) => gap.blocking).length;

      widgets.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: AppCard(
            padding: EdgeInsets.zero,
            child: ExpansionTile(
              tilePadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 5,
              ),
              childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 4),
              leading: CircleAvatar(
                radius: 18,
                backgroundColor: blocking > 0
                    ? AppColors.criticalSoft
                    : AppColors.warningSoft,
                child: Text(
                  '${entry.value.length}',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: blocking > 0
                        ? AppColors.criticalForeground
                        : AppColors.warningForeground,
                  ),
                ),
              ),
              title: Text(
                context.tr(entry.key),
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              subtitle: Text(
                blocking > 0
                    ? context.tr(
                        'care_gap_group_blocking_attention',
                        values: {
                          'blocking': blocking,
                          'attention': entry.value.length - blocking,
                        },
                      )
                    : context.tr(
                        'care_gap_current_issues_count',
                        values: {'count': entry.value.length},
                      ),
              ),
              children: entry.value.map(_gapCard).toList(),
            ),
          ),
        ),
      );
    }

    return widgets;
  }

  String _filterLabel(BuildContext context, String value) {
    return switch (value) {
      'All' => context.tr('care_gap_all'),

      'Blocking' => context.tr('care_gap_blocking'),

      'Needs attention' => context.tr('care_gap_needs_attention'),

      'In Progress' => context.tr('care_gap_in_progress'),

      _ => value,
    };
  }

  Widget _filterBar() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: filters.map((value) {
        final active = value == filter;

        return InkWell(
          onTap: () {
            setState(() {
              filter = value;
            });
          },
          borderRadius: BorderRadius.circular(99),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: active ? AppColors.primaryLight : AppColors.card,
              border: Border.all(
                color: active ? AppColors.primary : AppColors.border,
              ),
              borderRadius: BorderRadius.circular(99),
            ),
            child: Text(
              _filterLabel(context, value),
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: active ? AppColors.accentForeground : AppColors.muted,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _gapCard(CareGapItemData gap) {
    final planTitle = planTitles[gap.carePlanId] ?? context.tr('care_plan');

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: FadeSlideIn(
        child: AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  StatusBadge(status: gap.badgeStatus),
                  _smallBadge(
                    _localizedSeverityLabel(context, gap.severityLabel),
                    gap.severityWasBlocking
                        ? AppColors.criticalSoft
                        : AppColors.warningSoft,
                    gap.severityWasBlocking
                        ? AppColors.criticalForeground
                        : AppColors.warningForeground,
                  ),
                  if (!gap.isResolved)
                    _smallBadge(
                      _localizedLifecycleLabel(context, gap.lifecycleLabel),
                      AppColors.infoSoft,
                      AppColors.infoForeground,
                    ),
                ],
              ),

              const SizedBox(height: 10),

              Text(
                gap.title,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                ),
              ),

              const SizedBox(height: 3),

              Text(
                '${_localizedTypeLabel(context, gap.typeLabel)} · $planTitle',
                style: const TextStyle(fontSize: 13, color: AppColors.muted),
              ),

              if (gap.whenText.isNotEmpty) ...[
                const SizedBox(height: 3),
                Text(
                  gap.whenText,
                  style: const TextStyle(fontSize: 13, color: AppColors.muted),
                ),
              ],

              const SizedBox(height: 9),

              Text(
                gap.summary,
                style: const TextStyle(fontSize: 14, color: AppColors.muted),
              ),

              if (gap.reason.isNotEmpty) ...[
                const SizedBox(height: 10),
                Text(
                  '${context.tr('why')}: ${gap.reason}',
                  style: const TextStyle(fontSize: 14),
                ),
              ],

              if (!gap.isResolved && gap.nextStep.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  '${context.tr('care_gap_next_step_label')}: ${gap.nextStep}',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.accentForeground,
                  ),
                ),
              ],

              const SizedBox(height: 15),

              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilledButton(
                    onPressed: () async {
                      await Navigator.pushNamed(
                        context,
                        AppRoutes.careGap(gap.id),
                      );

                      if (mounted) {
                        await _load();
                      }
                    },
                    child: Text(context.tr('open')),
                  ),

                  if (!gap.isResolved)
                    OutlinedButton.icon(
                      onPressed: () => _openAction(gap),
                      icon: const Icon(Icons.arrow_forward, size: 17),
                      label: Text(_localizedActionLabel(context, gap)),
                    )
                  else if (gap.actionLabel.isNotEmpty)
                    OutlinedButton.icon(
                      onPressed: () => _openAction(gap),
                      icon: const Icon(Icons.open_in_new, size: 17),
                      label: Text(_localizedActionLabel(context, gap)),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _smallBadge(String label, Color background, Color foreground) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: foreground,
        ),
      ),
    );
  }

  Future<void> _openAction(CareGapItemData gap) async {
    await _navigateToGapAction(context, gap);

    if (!mounted) return;

    try {
      await CarePlanService.instance.refreshCareGaps(gap.carePlanId);
    } on CarePlanException catch (exception) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(exception.message)));
      }
    }

    if (mounted) {
      await _load();
    }
  }

  Widget _guestScreen() {
    final state = CareDemoState.instance;

    return AnimatedBuilder(
      animation: state,
      builder: (context, _) {
        final visible = filter == 'All'
            ? state.gaps
                  .where((gap) => gap.status != TaskStatus.resolved)
                  .toList()
            : state.gaps
                  .where(
                    (gap) =>
                        gap.status != TaskStatus.resolved &&
                        taskStatusLabel(gap.status) == filter,
                  )
                  .toList();

        return AppShell(
          currentRoute: AppRoutes.careGaps,

          title: context.tr('care_gaps'),

          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              PageHeader(
                title: context.tr('care_gaps'),
                subtitle: context.tr('demo_care_gaps'),
                action: OutlinedButton(
                  onPressed: () => Navigator.pushReplacementNamed(
                    context,
                    AppRoutes.simulation,
                  ),
                  child: Text(context.tr('back_to_simulation')),
                ),
              ),

              if (visible.isEmpty)
                EmptyState(
                  icon: Icons.shield_outlined,
                  title: context.tr('care_gaps_ready_title'),
                  description: context.tr('care_gaps_empty_filter'),
                )
              else
                ...visible.map(
                  (gap) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: AppCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          StatusBadge(status: gap.status),

                          const SizedBox(height: 9),

                          Text(
                            gap.title,
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w600,
                            ),
                          ),

                          Text(
                            '${gap.category} · ${gap.when}',
                            style: const TextStyle(
                              fontSize: 13,
                              color: AppColors.muted,
                            ),
                          ),

                          const SizedBox(height: 8),

                          Text(
                            gap.summary,
                            style: const TextStyle(
                              fontSize: 14,
                              color: AppColors.muted,
                            ),
                          ),

                          const SizedBox(height: 15),

                          FilledButton(
                            onPressed: () => Navigator.pushNamed(
                              context,
                              AppRoutes.careGap(gap.id),
                            ),
                            child: Text(context.tr('open')),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class CareGapDetailScreen extends StatefulWidget {
  const CareGapDetailScreen({required this.gapId, super.key});

  final String gapId;

  @override
  State<CareGapDetailScreen> createState() => _CareGapDetailScreenState();
}

class _CareGapDetailScreenState extends State<CareGapDetailScreen> {
  final info = TextEditingController();

  final doctorAnswerControllers = <String, TextEditingController>{};

  bool loading = true;
  bool saving = false;

  String? error;

  CareGapDetailData? data;
  String _savedResolutionNote = '';
  bool _noteDirty = false;

  @override
  void initState() {
    super.initState();

    if (AuthSession.instance.isGuest) {
      loading = false;
    } else {
      _load();
    }
  }

  TextEditingController _doctorAnswerController(String questionId) {
    return doctorAnswerControllers.putIfAbsent(
      questionId,
      TextEditingController.new,
    );
  }

  @override
  void dispose() {
    info.dispose();

    for (final controller in doctorAnswerControllers.values) {
      controller.dispose();
    }

    doctorAnswerControllers.clear();

    super.dispose();
  }

  Future<void> _load() async {
    if (AuthSession.instance.isGuest) {
      return;
    }

    if (mounted) {
      setState(() {
        loading = true;
        error = null;
      });
    }

    try {
      final result = await CarePlanService.instance.fetchCareGap(widget.gapId);

      if (!mounted) return;

      final savedNote = result.gap.resolutionNote.trim();

      if (!_noteDirty) {
        info.value = TextEditingValue(
          text: savedNote,
          selection: TextSelection.collapsed(offset: savedNote.length),
        );
      }

      setState(() {
        data = result;
        _savedResolutionNote = savedNote;
        _noteDirty = false;
        loading = false;
      });
    } on CarePlanException catch (exception) {
      if (!mounted) return;

      setState(() {
        loading = false;
        error = exception.message;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        loading = false;
        error = context.tr('gap_load_failed');
      });
    }
  }

  List<CareGapDoctorQuestionData> _deduplicatedDoctorQuestions(
    List<CareGapDoctorQuestionData> questions,
  ) {
    final result = <CareGapDoctorQuestionData>[];

    // Only one pending question should exist for one Care Gap.
    //
    // Answered questions are history and are always preserved.
    // If an older backend returned multiple pending questions,
    // show only the first one until the backend cleanup runs.
    var pendingAdded = false;

    for (final question in questions) {
      if (question.answered) {
        result.add(question);
        continue;
      }

      if (!pendingAdded) {
        result.add(question);
        pendingAdded = true;
      }
    }

    return result;
  }

  String _doctorQuestionSubject(CareGapItemData gap) {
    var value = gap.title.trim();

    const suffix = ' has a practical routine conflict';

    if (value.toLowerCase().endsWith(suffix)) {
      value = value.substring(0, value.length - suffix.length);
    }

    value = value.trim();

    return value.isEmpty ? context.tr('gap_care_instruction_fallback') : value;
  }

  String _friendlyClockTime(String value) {
    final match = RegExp(r'^(\d{1,2}):(\d{2})').firstMatch(value.trim());

    if (match == null) {
      return value.trim();
    }

    final hour = int.tryParse(match.group(1) ?? '') ?? 0;

    final minute = match.group(2) ?? '00';

    if (hour < 0 || hour > 23) {
      return value.trim();
    }

    final suffix = hour >= 12 ? 'PM' : 'AM';

    var displayHour = hour % 12;

    if (displayHour == 0) {
      displayHour = 12;
    }

    return '$displayHour:$minute $suffix';
  }

  String _doctorQuestionText(CareGapItemData gap) {
    final subject = _doctorQuestionSubject(gap);

    final when = gap.whenText.trim();

    final patientReality = gap.patientReality.trim();

    if (when.isNotEmpty && patientReality.isNotEmpty) {
      return context.tr(
        'gap_doctor_q_when_and_reality',
        values: {
          'subject': subject,
          'time': _friendlyClockTime(when),
          'reality': patientReality,
        },
      );
    }

    if (patientReality.isNotEmpty) {
      return context.tr(
        'gap_doctor_q_reality_only',
        values: {'subject': subject, 'reality': patientReality},
      );
    }

    if (when.isNotEmpty) {
      return context.tr(
        'gap_doctor_q_when_only',
        values: {'subject': subject, 'time': _friendlyClockTime(when)},
      );
    }

    return context.tr('gap_doctor_q_generic', values: {'subject': subject});
  }

  @override
  Widget build(BuildContext context) {
    if (AuthSession.instance.isGuest) {
      return _guestDetail();
    }

    if (loading) {
      return AppShell(
        currentRoute: AppRoutes.careGaps,
        title: context.tr('gap_detail_title'),
        child: const Center(child: CircularProgressIndicator()),
      );
    }

    final detail = data;

    if (detail == null) {
      return AppShell(
        currentRoute: AppRoutes.careGaps,
        title: context.tr('gap_detail_title'),
        child: EmptyState(
          title: context.tr('gap_unavailable'),
          description: error ?? context.tr('gap_unavailable_desc'),
          action: FilledButton(
            onPressed: _load,
            child: Text(context.tr('retry')),
          ),
        ),
      );
    }

    final gap = detail.gap;

    final doctorQuestions = _deduplicatedDoctorQuestions(
      detail.doctorQuestions,
    );

    final hasPendingDoctorQuestion = doctorQuestions.any(
      (question) => !question.answered,
    );

    final main = Column(
      children: [
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  StatusBadge(status: gap.badgeStatus),
                  _detailBadge(
                    _localizedSeverityLabel(context, gap.severityLabel),
                    gap.severityWasBlocking
                        ? AppColors.criticalSoft
                        : AppColors.warningSoft,
                    gap.severityWasBlocking
                        ? AppColors.criticalForeground
                        : AppColors.warningForeground,
                  ),
                  if (!gap.isResolved)
                    _detailBadge(
                      _localizedLifecycleLabel(context, gap.lifecycleLabel),
                      AppColors.infoSoft,
                      AppColors.infoForeground,
                    ),
                ],
              ),

              const SizedBox(height: 16),

              _detail(context.tr('gap_problem_label'), gap.summary),

              _detailIfPresent(
                context.tr('gap_related_instruction_label'),
                gap.instructionSnapshot,
              ),

              _detailIfPresent(context.tr('gap_why_flagged_label'), gap.reason),

              _detailIfPresent(
                context.tr('gap_patient_reality_label'),
                gap.patientReality,
              ),

              _detailIfPresent(context.tr('gap_next_step_label'), gap.nextStep),

              _detailIfPresent(context.tr('gap_when_due_label'), _dueText(gap)),

              _detail(
                context.tr('gap_type_label'),
                _localizedTypeLabel(context, gap.typeLabel),
                bottom: gap.resolutionNote.isEmpty,
              ),

              if (gap.resolutionNote.isNotEmpty)
                _detail(
                  context.tr('gap_resolution_note_label'),
                  gap.resolutionNote,
                  bottom: false,
                ),
            ],
          ),
        ),

        if (!gap.isResolved && gap.resolutionSteps.isNotEmpty) ...[
          const SizedBox(height: 16),

          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  gap.resolutionTitle,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                  ),
                ),

                const SizedBox(height: 12),

                ...List.generate(
                  gap.resolutionSteps.length,
                  (index) => Padding(
                    padding: EdgeInsets.only(
                      bottom: index == gap.resolutionSteps.length - 1 ? 0 : 10,
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 24,
                          height: 24,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: AppColors.primaryLight,
                            borderRadius: BorderRadius.circular(99),
                          ),
                          child: Text(
                            '${index + 1}',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: AppColors.accentForeground,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            gap.resolutionSteps[index],
                            style: const TextStyle(fontSize: 14, height: 1.35),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                if (gap.autoRecheck) ...[
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.infoSoft,
                      borderRadius: BorderRadius.circular(AppRadii.xl),
                    ),
                    child: Text(
                      context.tr('gap_auto_recheck_note'),
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.infoForeground,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],

        const SizedBox(height: 16),

        if (!gap.isResolved)
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _savedResolutionNote.isEmpty
                      ? context.tr('gap_add_information')
                      : context.tr('gap_update_information'),
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                  ),
                ),

                const SizedBox(height: 4),

                Text(
                  gap.autoManaged
                      ? context.tr('gap_note_auto_managed_hint')
                      : context.tr('gap_add_information_hint'),
                  style: const TextStyle(fontSize: 14, color: AppColors.muted),
                ),

                const SizedBox(height: 12),

                TextField(
                  controller: info,
                  minLines: 3,
                  maxLines: 4,
                  onChanged: (_) {
                    setState(() {
                      _noteDirty =
                          info.text.trim() != _savedResolutionNote.trim();
                    });
                  },
                  decoration: InputDecoration(
                    hintText: context.tr('gap_resolution_note_hint'),
                  ),
                ),

                const SizedBox(height: 12),

                OutlinedButton(
                  onPressed:
                      saving ||
                          !_noteDirty ||
                          (info.text.trim().isEmpty &&
                              _savedResolutionNote.isEmpty)
                      ? null
                      : () => _saveProgress(gap),
                  child: Text(
                    saving
                        ? context.tr('saving')
                        : _savedResolutionNote.isEmpty
                        ? context.tr('gap_save_information')
                        : context.tr('gap_save_changes'),
                  ),
                ),
              ],
            ),
          ),

        if (doctorQuestions.isNotEmpty) ...[
          const SizedBox(height: 16),

          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.tr('gap_doctor_questions_title'),
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                  ),
                ),

                const SizedBox(height: 4),

                Text(
                  context.tr('gap_doctor_questions_subtitle'),
                  style: const TextStyle(fontSize: 13, color: AppColors.muted),
                ),

                const SizedBox(height: 12),

                ...doctorQuestions.map(
                  (question) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.secondary,
                        borderRadius: BorderRadius.circular(AppRadii.xl),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Text(
                                  question.title,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: question.answered
                                      ? AppColors.successSoft
                                      : AppColors.warningSoft,
                                  borderRadius: BorderRadius.circular(99),
                                ),
                                child: Text(
                                  question.answered
                                      ? context.tr('gap_answered')
                                      : context.tr('gap_waiting_for_answer'),
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: question.answered
                                        ? AppColors.successForeground
                                        : AppColors.warningForeground,
                                  ),
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 6),

                          Text(
                            question.question,
                            style: const TextStyle(fontSize: 15, height: 1.4),
                          ),

                          if (!question.answered) ...[
                            const SizedBox(height: 14),

                            Text(
                              context.tr('gap_doctor_response_label'),
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: AppColors.muted,
                              ),
                            ),

                            const SizedBox(height: 7),

                            TextField(
                              controller: _doctorAnswerController(question.id),
                              minLines: 2,
                              maxLines: 5,
                              onChanged: (_) {
                                setState(() {});
                              },
                              decoration: InputDecoration(
                                hintText: context.tr('gap_doctor_answer_hint'),
                              ),
                            ),

                            const SizedBox(height: 8),

                            Text(
                              context.tr('gap_doctor_answer_disclaimer'),
                              style: const TextStyle(
                                fontSize: 12,
                                height: 1.35,
                                color: AppColors.muted,
                              ),
                            ),

                            const SizedBox(height: 12),

                            SizedBox(
                              width: double.infinity,
                              child: FilledButton.icon(
                                onPressed:
                                    saving ||
                                        _doctorAnswerController(
                                          question.id,
                                        ).text.trim().isEmpty
                                    ? null
                                    : () => _saveDoctorQuestionAnswer(question),
                                icon: const Icon(
                                  Icons.check_circle_outline,
                                  size: 17,
                                ),
                                label: Text(
                                  saving
                                      ? context.tr('saving')
                                      : context.tr('gap_mark_answered'),
                                ),
                              ),
                            ),
                          ],

                          if (question.answered &&
                              question.answer.isNotEmpty) ...[
                            const SizedBox(height: 12),

                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: AppColors.successSoft,
                                borderRadius: BorderRadius.circular(
                                  AppRadii.xl,
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    context.tr('gap_verified_response'),
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.successForeground,
                                    ),
                                  ),

                                  const SizedBox(height: 4),

                                  Text(
                                    question.answer,
                                    style: const TextStyle(
                                      fontSize: 14,
                                      height: 1.4,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );

    final aside = Column(
      children: [
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                context.tr('gap_resolution_options'),
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                ),
              ),

              const SizedBox(height: 12),

              if (!gap.isResolved) ...[
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: saving ? null : () => _openAction(gap),
                    icon: const Icon(Icons.arrow_forward, size: 17),
                    label: Text(_localizedActionLabel(context, gap)),
                  ),
                ),

                const SizedBox(height: 10),

                if (gap.canMarkResolved)
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: saving ? null : () => _markResolved(gap),
                      icon: const Icon(Icons.check_circle_outline, size: 17),
                      label: Text(context.tr('gap_mark_resolved')),
                    ),
                  )
                else
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.infoSoft,
                      borderRadius: BorderRadius.circular(AppRadii.xl),
                    ),
                    child: Text(
                      context.tr('gap_auto_managed_note'),
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.infoForeground,
                      ),
                    ),
                  ),

                const SizedBox(height: 10),

                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: saving || hasPendingDoctorQuestion
                        ? null
                        : () => _createDoctorQuestion(gap),
                    icon: Icon(
                      hasPendingDoctorQuestion
                          ? Icons.check_circle_outline
                          : Icons.help_outline,
                      size: 17,
                    ),
                    label: Text(
                      hasPendingDoctorQuestion
                          ? context.tr('gap_question_already_created')
                          : context.tr('gap_create_doctor_question'),
                    ),
                  ),
                ),

                if (hasPendingDoctorQuestion) ...[
                  const SizedBox(height: 7),
                  Text(
                    context.tr('gap_question_pending_hint'),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.muted,
                      height: 1.35,
                    ),
                  ),
                ],
              ] else ...[
                Text(
                  context.tr('gap_resolved_message'),
                  style: const TextStyle(color: AppColors.successForeground),
                ),

                if (gap.actionLabel.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: saving ? null : () => _openAction(gap),
                      icon: const Icon(Icons.open_in_new, size: 17),
                      label: Text(_localizedActionLabel(context, gap)),
                    ),
                  ),
                ],
              ],

              const SizedBox(height: 10),

              SizedBox(
                width: double.infinity,
                child: TextButton.icon(
                  onPressed: saving ? null : _load,
                  icon: const Icon(Icons.refresh, size: 17),
                  label: Text(context.tr('gap_refresh_status')),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        SafetyNote(text: context.tr('gap_detail_safety_note')),
      ],
    );

    return AppShell(
      currentRoute: AppRoutes.careGap(widget.gapId),
      title: context.tr('gap_detail_title'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextButton.icon(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back, size: 18),
            label: Text(context.tr('care_gaps')),
          ),

          PageHeader(
            title: gap.title,
            subtitle: [
              _localizedTypeLabel(context, gap.typeLabel),
              gap.whenText,
            ].where((value) => value.isNotEmpty).join(' · '),
          ),

          LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth >= 880) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 7, child: main),
                    const SizedBox(width: 24),
                    Expanded(flex: 5, child: aside),
                  ],
                );
              }

              return Column(
                children: [main, const SizedBox(height: 16), aside],
              );
            },
          ),
        ],
      ),
    );
  }

  Future<void> _saveProgress(CareGapItemData gap) async {
    setState(() {
      saving = true;
    });

    try {
      final updatedNote = info.text.trim();

      await CarePlanService.instance.updateCareGap(
        gap.id,
        lifecycleStatus: 'in_progress',
        resolutionNote: updatedNote,
      );

      if (mounted) {
        setState(() {
          _savedResolutionNote = updatedNote;
          _noteDirty = false;
        });
      }

      await _load();

      if (mounted) {
        showDemoMessage(context, context.tr('gap_progress_saved'));
      }
    } on CarePlanException catch (exception) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(exception.message)));
      }
    } finally {
      if (mounted) {
        setState(() {
          saving = false;
        });
      }
    }
  }

  Future<void> _markResolved(CareGapItemData gap) async {
    setState(() {
      saving = true;
    });

    try {
      await CarePlanService.instance.updateCareGap(
        gap.id,
        lifecycleStatus: 'resolved',
        resolutionNote: info.text.trim().isEmpty
            ? context.tr('gap_resolved_default_note')
            : info.text.trim(),
      );

      info.clear();

      await _load();

      if (mounted) {
        showDemoMessage(context, context.tr('gap_resolved_snackbar'));
      }
    } on CarePlanException catch (exception) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(exception.message)));
      }
    } finally {
      if (mounted) {
        setState(() {
          saving = false;
        });
      }
    }
  }

  Future<void> _createDoctorQuestion(CareGapItemData gap) async {
    final currentDetail = data;

    // Flutter-side duplicate protection.
    //
    // Backend also protects this, but checking here gives
    // immediate feedback and avoids an unnecessary API request.
    if (currentDetail != null &&
        currentDetail.doctorQuestions.any((question) => !question.answered)) {
      if (mounted) {
        showDemoMessage(context, context.tr('gap_question_already_exists'));
      }

      return;
    }

    setState(() {
      saving = true;
    });

    try {
      final subject = _doctorQuestionSubject(gap);

      await CarePlanService.instance.createCareGapDoctorQuestion(
        gap.id,
        groupName: 'Care Instructions',
        title: context.tr('gap_doctor_q_title', values: {'subject': subject}),
        question: _doctorQuestionText(gap),
      );

      await _load();

      if (mounted) {
        showDemoMessage(context, context.tr('gap_question_saved'));
      }
    } on CarePlanException catch (exception) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(exception.message)));
      }
    } finally {
      if (mounted) {
        setState(() {
          saving = false;
        });
      }
    }
  }

  Future<void> _saveDoctorQuestionAnswer(
    CareGapDoctorQuestionData question,
  ) async {
    final controller = _doctorAnswerController(question.id);

    final answer = controller.text.trim();

    if (answer.isEmpty) {
      return;
    }

    setState(() {
      saving = true;
    });

    try {
      await CarePlanService.instance.answerCareGapDoctorQuestion(
        question.id,
        answer: answer,
      );

      controller.clear();

      await _load();

      if (mounted) {
        showDemoMessage(context, context.tr('gap_answer_saved'));
      }
    } on CarePlanException catch (exception) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(exception.message)));
      }
    } finally {
      if (mounted) {
        setState(() {
          saving = false;
        });
      }
    }
  }

  Future<void> _openAction(CareGapItemData gap) async {
    await _navigateToGapAction(context, gap);

    if (!mounted) return;

    try {
      await CarePlanService.instance.refreshCareGaps(gap.carePlanId);

      await _load();
    } on CarePlanException catch (exception) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(exception.message)));
      }
    }
  }

  String _dueText(CareGapItemData gap) {
    if (gap.dueAt.isNotEmpty) {
      return gap.dueAt
          .replaceFirst('T', ' ')
          .replaceFirst(RegExp(r'\.000Z$'), '');
    }

    return gap.whenText;
  }

  Widget _detailIfPresent(String label, String value) {
    if (value.trim().isEmpty) {
      return const SizedBox.shrink();
    }

    return _detail(label, value);
  }

  Widget _detail(String label, String value, {bool bottom = true}) {
    return Padding(
      padding: EdgeInsets.only(bottom: bottom ? 16 : 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppColors.muted,
              letterSpacing: .5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value.trim().isEmpty ? context.tr('gap_not_provided') : value,
            style: const TextStyle(fontSize: 15),
          ),
        ],
      ),
    );
  }

  Widget _detailBadge(String label, Color background, Color foreground) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: foreground,
        ),
      ),
    );
  }

  Widget _guestDetail() {
    final state = CareDemoState.instance;

    return AnimatedBuilder(
      animation: state,
      builder: (context, _) {
        DemoGap? gap;

        for (final item in state.gaps) {
          if (item.id == widget.gapId) {
            gap = item;
            break;
          }
        }

        if (gap == null) {
          return AppShell(
            currentRoute: AppRoutes.careGaps,
            title: context.tr('gap_detail_title'),
            child: EmptyState(
              title: context.tr('gap_not_found_title'),
              description: context.tr('gap_not_found_desc'),
              action: FilledButton(
                onPressed: () =>
                    Navigator.pushReplacementNamed(context, AppRoutes.careGaps),
                child: Text(context.tr('gap_back_to_care_gaps')),
              ),
            ),
          );
        }

        return AppShell(
          currentRoute: AppRoutes.careGap(widget.gapId),
          title: context.tr('gap_detail_title'),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextButton.icon(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.arrow_back, size: 18),
                label: Text(context.tr('care_gaps')),
              ),

              PageHeader(
                title: gap.title,
                subtitle: '${gap.category} · ${gap.when}',
              ),

              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    StatusBadge(status: gap.status),
                    const SizedBox(height: 16),
                    _detail(context.tr('gap_problem_label'), gap.summary),
                    _detail(
                      context.tr('gap_related_instruction_label'),
                      gap.instruction,
                    ),
                    _detail(context.tr('gap_why_flagged_label'), gap.reason),
                    _detail(
                      context.tr('gap_patient_reality_label'),
                      gap.reality,
                    ),
                    _detail(
                      context.tr('gap_suggested_next_step'),
                      gap.nextStep,
                      bottom: false,
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class DoctorQuestionsScreen extends StatefulWidget {
  const DoctorQuestionsScreen({super.key});

  @override
  State<DoctorQuestionsScreen> createState() => _DoctorQuestionsScreenState();
}

class _DoctorQuestionsScreenState extends State<DoctorQuestionsScreen> {
  final drafts = <String, TextEditingController>{};

  TextEditingController _controller(String id) {
    return drafts.putIfAbsent(id, TextEditingController.new);
  }

  // Group names are internal demo-data values; only their
  // display is localized here.
  String _groupLabel(BuildContext context, String group) {
    return switch (group) {
      'Medicines' => context.tr('gap_group_medicines'),
      'Follow-Up' => context.tr('gap_group_follow_up'),
      'Tests' => context.tr('gap_group_tests'),
      'Care Instructions' => context.tr('gap_group_care_instructions'),
      _ => group,
    };
  }

  @override
  void dispose() {
    for (final controller in drafts.values) {
      controller.dispose();
    }

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = CareDemoState.instance;

    return AnimatedBuilder(
      animation: state,
      builder: (context, _) {
        return AppShell(
          currentRoute: AppRoutes.doctorQuestions,
          title: context.tr('gap_doctor_questions_screen_title'),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              PageHeader(
                title: context.tr('gap_doctor_questions_header'),
                subtitle: context.tr('gap_doctor_questions_header_sub'),
              ),

              for (final group in const [
                'Medicines',
                'Follow-Up',
                'Tests',
                'Care Instructions',
              ]) ...[
                if (state.questions.any(
                  (question) => question.group == group,
                )) ...[
                  Text(
                    _groupLabel(context, group),
                    style: const TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.w600,
                    ),
                  ),

                  const SizedBox(height: 12),

                  ...state.questions
                      .where((question) => question.group == group)
                      .map(
                        (question) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: AppCard(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            question.title,
                                            style: const TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            question.question,
                                            style: const TextStyle(
                                              fontSize: 15,
                                              color: AppColors.muted,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    if (question.answered)
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 5,
                                        ),
                                        decoration: BoxDecoration(
                                          color: AppColors.successSoft,
                                          borderRadius: BorderRadius.circular(
                                            99,
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Icon(
                                              Icons.check,
                                              size: 14,
                                              color:
                                                  AppColors.successForeground,
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              context.tr('gap_answered'),
                                              style: const TextStyle(
                                                fontSize: 13,
                                                fontWeight: FontWeight.w600,
                                                color:
                                                    AppColors.successForeground,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                  ],
                                ),

                                const SizedBox(height: 14),

                                if (question.answered &&
                                    question.answer != null)
                                  Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.all(14),
                                    decoration: BoxDecoration(
                                      color: AppColors.successSoft,
                                      borderRadius: BorderRadius.circular(
                                        AppRadii.xl,
                                      ),
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          context.tr('gap_verified_response'),
                                          style: const TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                            color: AppColors.successForeground,
                                          ),
                                        ),
                                        Text(
                                          question.answer!,
                                          style: const TextStyle(fontSize: 15),
                                        ),
                                      ],
                                    ),
                                  )
                                else
                                  LayoutBuilder(
                                    builder: (context, constraints) {
                                      final input = TextField(
                                        controller: _controller(question.id),
                                        onChanged: (_) {
                                          setState(() {});
                                        },
                                        decoration: InputDecoration(
                                          hintText: context.tr(
                                            'gap_add_answer_hint',
                                          ),
                                        ),
                                      );

                                      final button = FilledButton(
                                        onPressed:
                                            _controller(
                                              question.id,
                                            ).text.trim().isEmpty
                                            ? null
                                            : () {
                                                state.answerQuestion(
                                                  question.id,
                                                  _controller(
                                                    question.id,
                                                  ).text.trim(),
                                                );

                                                showDemoMessage(
                                                  context,
                                                  context.tr(
                                                    'gap_answer_saved_simulation',
                                                  ),
                                                );
                                              },
                                        child: Text(
                                          context.tr('gap_mark_answered'),
                                        ),
                                      );

                                      if (constraints.maxWidth >= 600) {
                                        return Row(
                                          children: [
                                            Expanded(child: input),
                                            const SizedBox(width: 8),
                                            button,
                                          ],
                                        );
                                      }

                                      return Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.stretch,
                                        children: [
                                          input,
                                          const SizedBox(height: 8),
                                          button,
                                        ],
                                      );
                                    },
                                  ),

                                const SizedBox(height: 10),

                                TextButton.icon(
                                  onPressed: () {
                                    Clipboard.setData(
                                      ClipboardData(text: question.question),
                                    );

                                    showDemoMessage(
                                      context,
                                      context.tr('gap_question_copied'),
                                    );
                                  },
                                  icon: const Icon(
                                    Icons.copy_outlined,
                                    size: 17,
                                  ),
                                  label: Text(context.tr('gap_copy')),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),

                  const SizedBox(height: 18),
                ],
              ],

              SafetyNote(text: context.tr('gap_doctor_questions_safety')),
            ],
          ),
        );
      },
    );
  }
}
