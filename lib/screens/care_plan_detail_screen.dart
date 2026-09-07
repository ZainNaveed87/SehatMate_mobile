import 'package:flutter/material.dart';

import '../core/app_routes.dart';
import '../core/app_theme.dart';
import '../data/demo_data.dart';
import '../features/agent/agent_entry.dart';
import '../features/agent/models/agent_context.dart';
import '../localization/language_scope.dart';
import '../localization/localized_errors.dart';
import '../services/auth_service.dart';
import '../services/care_plan_service.dart';
import '../services/care_reliability_service.dart';
import '../services/notification_service.dart';
import '../widgets/app_shell.dart';
import '../widgets/care_setup_progress.dart';
import '../widgets/status_badge.dart';
import '../widgets/ui.dart';
import 'simulation_screen.dart';

String _localizedPeriod(BuildContext context, String value) {
  return switch (value.trim().toLowerCase()) {
    'morning' => context.tr('morning'),
    'afternoon' => context.tr('afternoon'),
    'evening' => context.tr('evening'),
    'night' => context.tr('night'),
    _ => value,
  };
}

class _MedicineRecurrenceSelection {
  const _MedicineRecurrenceSelection({
    required this.mode,
    this.weekdays = const <int>[],
    this.intervalDays,
    this.monthDays = const <int>[],
  });

  final String mode;
  final List<int> weekdays;
  final int? intervalDays;
  final List<int> monthDays;
}

class CarePlanDetailScreen extends StatefulWidget {
  const CarePlanDetailScreen({
    required this.planId,
    this.initialTab = 0,
    this.guidedSetup = false,
    this.returnToPrevious = false,
    this.carePlanService,
    super.key,
  });

  final String planId;
  final int initialTab;
  final bool guidedSetup;
  final bool returnToPrevious;
  final CarePlanService? carePlanService;

  @override
  State<CarePlanDetailScreen> createState() => _CarePlanDetailScreenState();
}

class _CarePlanDetailScreenState extends State<CarePlanDetailScreen> {
  late int tab;
  CarePlanDetailData? _detail;
  bool _loading = true;
  bool _generatingSchedule = false;
  String? _error;
  final Map<String, String> _periodOverrides = {};
  final Map<String, String> _timeOverrides = {};
  final Set<String> _unsavedPeriodChanges = {};
  String _scheduleSaveState = 'Saved';
  List<CareTaskOccurrence> _todayOccurrences = const [];
  CareTaskDaySummary? _todaySummary;
  final Set<String> _outcomeSavingIds = {};
  bool _lifecycleSaving = false;
  DateTime? _planEndDate;
  bool _savingPlanDuration = false;
  final Set<String> _medicineDurationSavingKeys = <String>{};
  final Set<String> _medicineRecurrenceSavingKeys = <String>{};

  CarePlanService get _carePlanService =>
      widget.carePlanService ?? CarePlanService.instance;
  @override
  void initState() {
    super.initState();
    tab = widget.initialTab.clamp(0, 4);
    _loadPlan();
  }

  Future<void> _loadPlan() async {
    if (AuthSession.instance.isGuest) {
      final matching = demoPlans.where((plan) => plan.id == widget.planId);
      if (matching.isEmpty) {
        setState(() => _loading = false);
        return;
      }
      final plan = matching.first;
      setState(() {
        _detail = CarePlanDetailData(
          plan: plan,
          instructions: CareDemoState.instance.tasks.take(6).toList(),
          tasks: CareDemoState.instance.tasks,
          gaps: CareDemoState.instance.gaps,
          documents: CareDemoState.instance.documents
              .where((document) => plan.documents.contains(document.id))
              .toList(),
        );
        _loading = false;
      });
      return;
    }

    try {
      final detail = await _carePlanService.fetchPlanDetail(widget.planId);
      var occurrences = const <CareTaskOccurrence>[];
      CareTaskDaySummary? daySummary;
      if (detail.plan.status == PlanStatus.active ||
          detail.plan.status == PlanStatus.completed) {
        try {
          final day = await _carePlanService.fetchTaskOccurrences(
            widget.planId,
          );
          occurrences = day.occurrences;
          daySummary = day.summary;
        } on CarePlanException {
          // Keep the plan usable even if task outcomes cannot refresh yet.
        }
      }
      if (!mounted) return;
      setState(() {
        _detail = detail;
        _todayOccurrences = occurrences;
        _todaySummary = daySummary;

        final plannedEndDate = detail.plan.plannedEndDate.trim();

        _planEndDate = plannedEndDate.isEmpty
            ? null
            : DateTime.tryParse(plannedEndDate);

        _loading = false;
      });
    } on CarePlanException catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = localizedCarePlanExceptionMessage(error, context.appLanguage);
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = context.tr('care_plan_load_failed');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return _loadingView();

    final detail = _detail;
    if (detail == null) return _notFound(_error);

    final plan = detail.plan;
    final openGaps = detail.gaps
        .where((gap) => gap.status != TaskStatus.resolved)
        .length;

    return AnimatedBuilder(
      animation: CareDemoState.instance,
      builder: (context, _) => AppShell(
        currentRoute: AppRoutes.carePlan(plan.id),
        title: context.tr('care_plan'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: TextButton.icon(
                onPressed: () {
                  if (widget.returnToPrevious && Navigator.canPop(context)) {
                    Navigator.pop(context);
                    return;
                  }

                  if (widget.guidedSetup && tab == 1) {
                    Navigator.pushReplacementNamed(
                      context,
                      AppRoutes.carePlanReview,
                      arguments: CarePlanReviewArgs(
                        planId: widget.planId,
                        guidedSetup: true,
                      ),
                    );
                    return;
                  }

                  Navigator.pushReplacementNamed(context, AppRoutes.carePlans);
                },
                icon: const Icon(Icons.arrow_back_rounded, size: 17),
                label: Text(
                  widget.guidedSetup && tab == 1
                      ? context.tr('back_to_review')
                      : widget.returnToPrevious
                      ? context.tr('back')
                      : context.tr('care_plans'),
                ),
              ),
            ),
            const SizedBox(height: 6),

            FadeSlideIn(child: _premiumPlanHero(detail, openGaps)),

            if (!widget.guidedSetup &&
                !AuthSession.instance.isGuest &&
                (plan.status == PlanStatus.active ||
                    plan.status == PlanStatus.completed)) ...[
              const SizedBox(height: 16),
              FadeSlideIn(
                delay: const Duration(milliseconds: 50),
                child: _planLifecycleActions(plan),
              ),
            ],

            if (widget.guidedSetup) ...[
              const SizedBox(height: 16),
              FadeSlideIn(
                delay: const Duration(milliseconds: 60),
                child: GuidedCareSetupProgress(
                  currentStep: 3,
                  planId: widget.planId,
                  saveState: _scheduleSaveState,
                ),
              ),
            ],

            const SizedBox(height: 18),

            FadeSlideIn(
              delay: const Duration(milliseconds: 80),
              child: _planOverviewMetrics(detail, openGaps),
            ),

            if (!widget.guidedSetup) ...[
              const SizedBox(height: 20),
              FadeSlideIn(
                delay: const Duration(milliseconds: 100),
                child: _premiumTabBar(),
              ),
            ],

            const SizedBox(height: 18),

            AnimatedSwitcher(
              duration: const Duration(milliseconds: 260),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeInCubic,
              transitionBuilder: (child, animation) {
                final slide = Tween<Offset>(
                  begin: const Offset(0, .025),
                  end: Offset.zero,
                ).animate(animation);

                return FadeTransition(
                  opacity: animation,
                  child: SlideTransition(position: slide, child: child),
                );
              },
              child: KeyedSubtree(
                key: ValueKey('care-plan-tab-$tab'),
                child: _tabContent(detail),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _premiumPlanHero(CarePlanDetailData detail, int openGaps) {
    final plan = detail.plan;

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 650;

        return Container(
          padding: EdgeInsets.all(compact ? 20 : 26),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF0F766E), Color(0xFF0D9488), Color(0xFF14B8A6)],
            ),
            borderRadius: BorderRadius.circular(AppRadii.xxxl),
            boxShadow: const [
              BoxShadow(
                color: Color(0x260F766E),
                blurRadius: 32,
                spreadRadius: -12,
                offset: Offset(0, 16),
              ),
            ],
          ),
          child: Stack(
            children: [
              PositionedDirectional(
                top: -72,
                end: -54,
                child: Container(
                  width: 190,
                  height: 190,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Color(0x16FFFFFF),
                  ),
                ),
              ),
              PositionedDirectional(
                bottom: -92,
                start: -62,
                child: Container(
                  width: 200,
                  height: 200,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Color(0x0FFFFFFF),
                  ),
                ),
              ),
              if (compact)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _heroPlanContent(plan, openGaps),
                    const SizedBox(height: 18),
                    _heroReadiness(plan.readiness, wide: true),
                  ],
                )
              else
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(child: _heroPlanContent(plan, openGaps)),
                    const SizedBox(width: 24),
                    _heroReadiness(plan.readiness),
                  ],
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _heroPlanContent(DemoPlan plan, int openGaps) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0x20FFFFFF),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: const Color(0x30FFFFFF)),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.verified_user_outlined, size: 15, color: Colors.white),
              SizedBox(width: 6),
              Text(
                'Verified care plan',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Text(
          demoPlanTitle(plan, context.appLanguage),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 29,
            height: 1.08,
            fontWeight: FontWeight.w800,
            letterSpacing: -.45,
          ),
        ),
        const SizedBox(height: 9),
        Text(
          context.tr(
            'care_plan_header_subtitle',
            values: {
              'date': displayPlanStartDate(plan.startDate, context.appLanguage),
              'next': demoPlanNextTask(plan, context.appLanguage),
            },
          ),
          style: const TextStyle(
            color: Color(0xE6FFFFFF),
            fontSize: 13,
            height: 1.45,
          ),
        ),
        const SizedBox(height: 14),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            PlanStatusBadge(status: plan.status),
            _heroInfoChip(
              icon: Icons.health_and_safety_outlined,
              label: '$openGaps ${context.tr('care_gaps')}',
            ),
          ],
        ),
        const SizedBox(height: 14),
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.white,
            side: const BorderSide(color: Color(0x48FFFFFF)),
            backgroundColor: const Color(0x12FFFFFF),
          ),
          onPressed: () => openAgent(
            context,
            screenContext: AgentScreenContext(
              screenId: 'care_plan_detail',
              entity: AgentEntityContext(type: 'care_plan', id: widget.planId),
            ),
          ),
          icon: const Icon(Icons.auto_awesome_outlined, size: 17),
          label: Text(context.tr('ask_agent')),
        ),
      ],
    );
  }

  Widget _heroInfoChip({required IconData icon, required String label}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0x1BFFFFFF),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0x26FFFFFF)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.white),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: Color(0xE8FFFFFF),
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _heroReadiness(int readiness, {bool wide = false}) {
    final safe = readiness.clamp(0, 100);

    return Container(
      width: wide ? double.infinity : 176,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0x1FFFFFFF),
        borderRadius: BorderRadius.circular(AppRadii.xxl),
        border: Border.all(color: const Color(0x30FFFFFF)),
      ),
      child: wide
          ? Row(
              children: [
                _readinessCircle(safe),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        context.tr('care_readiness'),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Plan readiness for practical day-to-day care.',
                        style: TextStyle(
                          color: Color(0xD5FFFFFF),
                          fontSize: 11,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            )
          : Column(
              children: [
                _readinessCircle(safe),
                const SizedBox(height: 10),
                Text(
                  context.tr('care_readiness'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
    );
  }

  Widget _readinessCircle(int readiness) {
    return SizedBox(
      width: 70,
      height: 70,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: 70,
            height: 70,
            child: CircularProgressIndicator(
              value: readiness / 100,
              strokeWidth: 6,
              strokeCap: StrokeCap.round,
              backgroundColor: const Color(0x2AFFFFFF),
              color: Colors.white,
            ),
          ),
          Text(
            '$readiness%',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 17,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _planOverviewMetrics(CarePlanDetailData detail, int openGaps) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 760 ? 4 : 2;
        const gap = 10.0;
        final width = (constraints.maxWidth - ((columns - 1) * gap)) / columns;

        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            _overviewMetric(
              width: width,
              value: detail.instructions.length,
              label: context.tr('instructions'),
              icon: Icons.fact_check_outlined,
              background: AppColors.primaryLight,
              foreground: AppColors.primary,
              onTap: widget.guidedSetup ? null : () => _changeTab(0),
            ),
            _overviewMetric(
              width: width,
              value: detail.tasks.length,
              label: context.tr('schedule'),
              icon: Icons.calendar_month_outlined,
              background: AppColors.infoSoft,
              foreground: AppColors.infoForeground,
              onTap: widget.guidedSetup ? null : () => _changeTab(1),
            ),
            _overviewMetric(
              width: width,
              value: openGaps,
              label: context.tr('care_gaps'),
              icon: Icons.health_and_safety_outlined,
              background: openGaps > 0
                  ? AppColors.warningSoft
                  : AppColors.successSoft,
              foreground: openGaps > 0
                  ? AppColors.warningForeground
                  : AppColors.successForeground,
              onTap: widget.guidedSetup ? null : () => _changeTab(3),
            ),
            _overviewMetric(
              width: width,
              value: detail.documents.length,
              label: context.tr('documents'),
              icon: Icons.description_outlined,
              background: const Color(0xFFF1F5F9),
              foreground: AppColors.muted,
              onTap: widget.guidedSetup ? null : () => _changeTab(4),
            ),
          ],
        );
      },
    );
  }

  Widget _overviewMetric({
    required double width,
    required int value,
    required String label,
    required IconData icon,
    required Color background,
    required Color foreground,
    VoidCallback? onTap,
  }) {
    final card = AppCard(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: background,
              borderRadius: BorderRadius.circular(AppRadii.lg),
            ),
            child: Icon(icon, size: 18, color: foreground),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 220),
                  child: Text(
                    '$value',
                    key: ValueKey('$label-$value'),
                    style: const TextStyle(
                      fontSize: 20,
                      height: 1,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.muted,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          if (onTap != null)
            const Icon(
              Icons.chevron_right_rounded,
              size: 18,
              color: AppColors.subtle,
            ),
        ],
      ),
    );

    return SizedBox(
      width: width,
      child: onTap == null
          ? card
          : HoverLift(
              cursor: SystemMouseCursors.click,
              child: InkWell(
                onTap: onTap,
                borderRadius: BorderRadius.circular(AppRadii.xxl),
                child: card,
              ),
            ),
    );
  }

  void _changeTab(int value) {
    if (tab == value) return;
    setState(() => tab = value);
  }

  Widget _premiumTabBar() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F5F4),
        borderRadius: BorderRadius.circular(AppRadii.xl),
        border: Border.all(color: const Color(0xFFE1ECE9)),
      ),
      child: Wrap(
        spacing: 4,
        runSpacing: 4,
        children: [
          _premiumTab(0, context.tr('instructions'), Icons.fact_check_outlined),
          _premiumTab(1, context.tr('schedule'), Icons.calendar_month_outlined),
          _premiumTab(2, context.tr('simulation'), Icons.auto_graph_outlined),
          _premiumTab(
            3,
            context.tr('care_gaps'),
            Icons.health_and_safety_outlined,
          ),
          _premiumTab(4, context.tr('documents'), Icons.description_outlined),
        ],
      ),
    );
  }

  Widget _premiumTab(int value, String label, IconData icon) {
    final active = tab == value;

    return InkWell(
      onTap: () => _changeTab(value),
      borderRadius: BorderRadius.circular(AppRadii.lg),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
        decoration: BoxDecoration(
          color: active ? AppColors.card : Colors.transparent,
          borderRadius: BorderRadius.circular(AppRadii.lg),
          boxShadow: active
              ? const [
                  BoxShadow(
                    color: Color(0x140F172A),
                    blurRadius: 12,
                    spreadRadius: -6,
                    offset: Offset(0, 5),
                  ),
                ]
              : const [],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: active ? AppColors.primary : AppColors.muted,
            ),
            const SizedBox(width: 7),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: active ? FontWeight.w700 : FontWeight.w600,
                color: active ? AppColors.foreground : AppColors.muted,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _planLifecycleActions(DemoPlan plan) {
    final completed = plan.status == PlanStatus.completed;
    final explanation = completed
        ? context.tr('completed_plan_reactivate_explanation')
        : context.tr('active_plan_complete_explanation');

    return AppCard(
      padding: const EdgeInsets.all(16),
      color: completed ? const Color(0xFFF8FAFC) : const Color(0xFFF0FDFA),
      borderColor: completed ? AppColors.border : const Color(0xFFCCFBF1),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final content = Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: completed
                      ? const Color(0xFFF1F5F9)
                      : AppColors.primaryLight,
                  borderRadius: BorderRadius.circular(AppRadii.xl),
                ),
                child: Icon(
                  completed
                      ? Icons.restart_alt_rounded
                      : Icons.check_circle_outline_rounded,
                  color: completed ? AppColors.muted : AppColors.primary,
                  size: 21,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      completed
                          ? context.tr('plan_completed')
                          : context.tr('plan_actions'),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      explanation,
                      style: const TextStyle(
                        fontSize: 13,
                        height: 1.4,
                        color: AppColors.muted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );

          final action = completed
              ? FilledButton.icon(
                  onPressed: _lifecycleSaving
                      ? null
                      : () => _reactivatePlan(plan),
                  icon: _lifecycleSaving
                      ? const SizedBox(
                          width: 17,
                          height: 17,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.restart_alt_outlined, size: 18),
                  label: Text(
                    _lifecycleSaving
                        ? context.tr('reactivating')
                        : context.tr('reactivate_plan'),
                  ),
                )
              : OutlinedButton.icon(
                  onPressed: _lifecycleSaving
                      ? null
                      : () => _completePlanFromDetail(plan),
                  icon: _lifecycleSaving
                      ? const SizedBox(
                          width: 17,
                          height: 17,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.check_circle_outline, size: 18),
                  label: Text(
                    _lifecycleSaving
                        ? context.tr('completing')
                        : context.tr('complete_plan'),
                  ),
                );

          if (constraints.maxWidth < 560) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [content, const SizedBox(height: 14), action],
            );
          }

          return Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(child: content),
              const SizedBox(width: 18),
              action,
            ],
          );
        },
      ),
    );
  }

  Future<void> _completePlanFromDetail(DemoPlan plan) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(context.tr('complete_this_care_plan_question')),
        content: Text(context.tr('complete_this_care_plan_body')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(context.tr('cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(context.tr('complete_plan')),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _lifecycleSaving = true);
    try {
      await _carePlanService.completePlan(plan.id);

      try {
        await NotificationService.instance.cancelPlan(plan.id);
      } catch (_) {
        // The server status is authoritative. A later plan refresh also
        // retries completed-plan reminder cleanup.
      }

      await _loadPlan();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.tr('care_plan_completed_reminders_stopped')),
        ),
      );
    } on CarePlanException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              localizedCarePlanExceptionMessage(error, context.appLanguage),
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _lifecycleSaving = false);
    }
  }

  Future<void> _reactivatePlan(DemoPlan plan) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(context.tr('reactivate_this_care_plan_question')),
        content: Text(context.tr('reactivate_this_care_plan_body')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(context.tr('cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(context.tr('reactivate_plan')),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _lifecycleSaving = true);
    try {
      final reactivated = await _carePlanService.reactivatePlan(plan.id);

      final notificationResult = await NotificationService.instance
          .scheduleNextOccurrences(planId: plan.id, tasks: reactivated.tasks);

      await _loadPlan();
      if (!mounted) return;

      final message = !notificationResult.permissionGranted
          ? context.tr('care_plan_reactivated_no_notification_permission')
          : !notificationResult.exactAlarmGranted
          ? context.tr('care_plan_reactivated_exact_alarm_missing')
          : context.tr(
              'care_plan_reactivated_reminders_restored',
              values: {'count': notificationResult.scheduledCount},
            );

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    } on CarePlanException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              localizedCarePlanExceptionMessage(error, context.appLanguage),
            ),
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.tr('plan_reactivation_device_failed')),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _lifecycleSaving = false);
    }
  }

  String _dateKey(DateTime value) {
    return '${value.year.toString().padLeft(4, '0')}-'
        '${value.month.toString().padLeft(2, '0')}-'
        '${value.day.toString().padLeft(2, '0')}';
  }

  String _displayPlanEndDate(DateTime value) {
    return MaterialLocalizations.of(
      context,
    ).formatMediumDate(DateUtils.dateOnly(value));
  }

  Future<void> _pickPlanEndDate() async {
    final today = DateUtils.dateOnly(DateTime.now());

    final initial =
        _planEndDate == null ||
            DateUtils.dateOnly(_planEndDate!).isBefore(today)
        ? today
        : DateUtils.dateOnly(_planEndDate!);

    final selected = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: today,
      lastDate: today.add(const Duration(days: 3650)),
    );

    if (selected == null || !mounted) return;

    setState(() {
      _planEndDate = DateUtils.dateOnly(selected);
    });
  }

  Future<void> _savePlanEndDate() async {
    if (_planEndDate == null) {
      await _pickPlanEndDate();

      if (_planEndDate == null || !mounted) {
        return;
      }
    }

    setState(() {
      _savingPlanDuration = true;
      _scheduleSaveState = 'Saving…';
    });

    try {
      await _carePlanService.savePlanDuration(
        widget.planId,
        mode: 'custom',
        endDate: _dateKey(_planEndDate!),
      );

      await _loadPlan();

      if (!mounted) return;

      setState(() {
        _scheduleSaveState = 'Saved';
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Care plan end date saved.')));
    } on CarePlanException catch (error) {
      if (!mounted) return;

      setState(() {
        _scheduleSaveState = 'Retry needed';
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    } finally {
      if (mounted) {
        setState(() {
          _savingPlanDuration = false;
        });
      }
    }
  }

  Widget _planEndDateCard(DemoPlan plan) {
    final selectedDate = _planEndDate;
    final suggestedDate = DateTime.tryParse(plan.suggestedEndDate);
    final showSuggestion =
        suggestedDate != null &&
        (selectedDate == null ||
            !DateUtils.isSameDay(selectedDate, suggestedDate));

    return AppCard(
      padding: const EdgeInsets.all(16),
      color: const Color(0xFFFAFCFD),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 560;

          final header = Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.infoSoft,
                  borderRadius: BorderRadius.circular(AppRadii.xl),
                ),
                alignment: Alignment.center,
                child: const Icon(
                  Icons.event_outlined,
                  size: 21,
                  color: AppColors.info,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Care plan end date',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(height: 3),
                    Text(
                      'Overall plan boundary',
                      style: TextStyle(fontSize: 12, color: AppColors.muted),
                    ),
                  ],
                ),
              ),
            ],
          );

          final dateBox = Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(AppRadii.xl),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Ends',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.muted,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        selectedDate == null
                            ? 'Not selected'
                            : _displayPlanEndDate(selectedDate),
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
                if (!compact) ...[
                  OutlinedButton.icon(
                    onPressed: _savingPlanDuration ? null : _pickPlanEndDate,
                    icon: const Icon(Icons.edit_calendar_outlined, size: 17),
                    label: const Text('Change'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: _savingPlanDuration || selectedDate == null
                        ? null
                        : _savePlanEndDate,
                    child: _savingPlanDuration
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text('Save'),
                  ),
                ],
              ],
            ),
          );

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              header,
              const SizedBox(height: 14),
              dateBox,
              if (compact) ...[
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _savingPlanDuration
                            ? null
                            : _pickPlanEndDate,
                        icon: const Icon(
                          Icons.edit_calendar_outlined,
                          size: 17,
                        ),
                        label: const Text('Change'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: FilledButton(
                        onPressed: _savingPlanDuration || selectedDate == null
                            ? null
                            : _savePlanEndDate,
                        child: _savingPlanDuration
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text('Save'),
                      ),
                    ),
                  ],
                ),
              ],
              if (showSuggestion) ...[
                const SizedBox(height: 9),
                Row(
                  children: [
                    const Icon(
                      Icons.lightbulb_outline_rounded,
                      size: 15,
                      color: AppColors.muted,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Suggested: ${_displayPlanEndDate(suggestedDate)}',
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.muted,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 9),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.primaryLight,
                  borderRadius: BorderRadius.circular(AppRadii.lg),
                ),
                child: const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.shield_outlined,
                      size: 15,
                      color: AppColors.primary,
                    ),
                    SizedBox(width: 7),
                    Expanded(
                      child: Text(
                        'This caps the care plan. It never extends a verified medicine course.',
                        style: TextStyle(
                          fontSize: 11,
                          height: 1.35,
                          color: AppColors.accentForeground,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Map<String, List<DemoTask>> _medicineScheduleGroups(
    CarePlanDetailData detail,
  ) {
    final groups = <String, List<DemoTask>>{};

    for (final task in detail.tasks) {
      final meta = detail.metaForTask(task.id);

      final isMedicine = meta?.isMedicine ?? task.kind == TaskKind.medicine;

      if (!isMedicine) continue;

      final key = meta?.medicineGroupKey ?? task.id;

      groups.putIfAbsent(key, () => <DemoTask>[]).add(task);
    }

    return groups;
  }

  bool _scheduleTaskIsMedicine(CarePlanDetailData detail, DemoTask task) {
    final meta = detail.metaForTask(task.id);
    return meta?.isMedicine ?? task.kind == TaskKind.medicine;
  }

  String? _canonicalClockTime(String value) {
    final match = RegExp(
      r'(\d{1,2}):(\d{2})(?::\d{2})?\s*(AM|PM)?',
      caseSensitive: false,
    ).firstMatch(value.trim());

    if (match == null) return null;

    var hour = int.tryParse(match.group(1)!);
    final minute = int.tryParse(match.group(2)!);
    final suffix = match.group(3)?.toUpperCase();

    if (hour == null || minute == null || minute > 59) return null;

    if (suffix != null) {
      if (hour < 1 || hour > 12) return null;
      if (suffix == 'PM' && hour != 12) {
        hour += 12;
      } else if (suffix == 'AM' && hour == 12) {
        hour = 0;
      }
    } else if (hour > 23) {
      return null;
    }

    return '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
  }

  String _displayClockTime(String value) {
    final canonical = _canonicalClockTime(value);
    if (canonical == null) return value.trim();

    final parts = canonical.split(':');
    final hour = int.parse(parts[0]);
    final minute = parts[1];
    final suffix = hour >= 12 ? 'PM' : 'AM';
    final displayHour = hour % 12 == 0 ? 12 : hour % 12;
    return '$displayHour:$minute $suffix';
  }

  String _scheduleDisplaySlotKey(DemoTask task) {
    final displayTime = (_timeOverrides[task.id] ?? task.time).trim();
    final canonicalTime = _canonicalClockTime(displayTime);

    if (canonicalTime != null) {
      return 'time|$canonicalTime';
    }

    final period =
        (_periodOverrides[task.id] ?? _periodFrom('${task.time} ${task.note}'))
            .trim()
            .toLowerCase();
    return 'period|$period|${displayTime.toLowerCase()}';
  }

  List<DemoTask> _medicineReminderTasksForDisplay(List<DemoTask> tasks) {
    final rows = <DemoTask>[];
    final seenSlots = <String>{};

    for (final task in tasks) {
      if (seenSlots.add(_scheduleDisplaySlotKey(task))) {
        rows.add(task);
      }
    }

    return rows;
  }

  List<DemoTask> _nonMedicineScheduleRows(CarePlanDetailData detail) {
    return detail.tasks
        .where((task) => !_scheduleTaskIsMedicine(detail, task))
        .toList();
  }

  ScheduleTaskMeta? _medicineMetaForGroup(
    CarePlanDetailData detail,
    List<DemoTask> tasks,
  ) {
    ScheduleTaskMeta? fallback;

    for (final task in tasks) {
      final meta = detail.metaForTask(task.id);

      if (meta == null) continue;

      fallback ??= meta;

      if (meta.verifiedDuration || meta.verifiedRecurrence) {
        return meta;
      }
    }

    for (final task in tasks) {
      final meta = detail.metaForTask(task.id);

      if (meta == null) continue;

      if (meta.userDuration || meta.followsPlanEnd || meta.userRecurrence) {
        return meta;
      }
    }

    return fallback;
  }

  bool _medicineGroupDurationResolved(
    CarePlanDetailData detail,
    List<DemoTask> tasks,
  ) {
    if (tasks.isEmpty) return true;

    return tasks.every((task) {
      final meta = detail.metaForTask(task.id);

      if (meta == null) {
        return false;
      }

      if (meta.followsPlanEnd) {
        return detail.plan.plannedEndDate.trim().isNotEmpty;
      }

      return meta.durationResolved;
    });
  }

  bool _medicineGroupRecurrenceResolved(
    CarePlanDetailData detail,
    List<DemoTask> tasks,
  ) {
    if (tasks.isEmpty) return true;

    return tasks.every((task) {
      final meta = detail.metaForTask(task.id);
      return meta != null && meta.recurrenceResolved;
    });
  }

  bool _hasUnresolvedMedicineRecurrences(CarePlanDetailData detail) {
    if (AuthSession.instance.isGuest) {
      return false;
    }

    final groups = _medicineScheduleGroups(detail);

    return groups.values.any(
      (tasks) => !_medicineGroupRecurrenceResolved(detail, tasks),
    );
  }

  bool _hasUnresolvedMedicineDurations(CarePlanDetailData detail) {
    if (AuthSession.instance.isGuest) {
      return false;
    }

    final groups = _medicineScheduleGroups(detail);

    return groups.values.any(
      (tasks) => !_medicineGroupDurationResolved(detail, tasks),
    );
  }

  String _medicineDurationKey(DemoTask task, ScheduleTaskMeta? meta) {
    return meta?.medicineGroupKey ?? task.id;
  }

  String _medicineDurationLabel(ScheduleTaskMeta? meta, bool resolved) {
    if (!resolved || meta == null) {
      return 'Course duration not set';
    }

    if (meta.verifiedDuration) {
      final days = meta.durationDays!;

      return '$days ${days == 1 ? 'day' : 'days'} · Verified instruction';
    }

    if (meta.userDuration) {
      final days = meta.durationDays!;

      return '$days ${days == 1 ? 'day' : 'days'} · User provided';
    }

    if (meta.followsPlanEnd) {
      return 'Until care-plan end date · User provided';
    }

    return 'Course duration not set';
  }

  static const List<String> _weekdayNames = [
    '',
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];

  String _weekdaySummary(List<int> days) {
    final labels = days
        .where((day) => day >= 1 && day <= 7)
        .map((day) => _weekdayNames[day])
        .toList();
    return labels.isEmpty ? 'Selected weekdays' : labels.join(', ');
  }

  String _monthDayLabel(int day) {
    final modHundred = day % 100;
    final suffix = modHundred >= 11 && modHundred <= 13
        ? 'th'
        : switch (day % 10) {
            1 => 'st',
            2 => 'nd',
            3 => 'rd',
            _ => 'th',
          };
    return '$day$suffix';
  }

  String _monthDaySummary(List<int> days) {
    final labels = days
        .where((day) => day >= 1 && day <= 31)
        .map(_monthDayLabel)
        .toList();
    if (labels.isEmpty) return 'Selected month days';
    if (labels.length == 1) return labels.single;
    return '${labels.take(labels.length - 1).join(', ')} and ${labels.last}';
  }

  String _medicineRecurrenceLabel(ScheduleTaskMeta? meta, bool resolved) {
    if (!resolved || meta == null) {
      return 'Repeat pattern not set';
    }

    final label = switch (meta.recurrenceMode) {
      'daily' => 'Every day',
      'weekdays' => _weekdaySummary(meta.recurrenceWeekdays),
      'interval_days' =>
        meta.recurrenceIntervalDays == 1
            ? 'Every day'
            : 'Every ${meta.recurrenceIntervalDays} days',
      'month_days' => _monthDaySummary(meta.recurrenceMonthDays),
      'one_off' => 'Once on ${meta.scheduleDate}',
      _ => 'Repeat pattern not set',
    };

    if (meta.verifiedRecurrence) {
      return '$label · Verified instruction';
    }
    if (meta.userRecurrence) {
      return '$label · User provided';
    }
    return label;
  }

  Future<_MedicineRecurrenceSelection?> _showMedicineRepeatPatternDialog(
    DemoTask task,
    ScheduleTaskMeta? meta,
  ) async {
    const modes = <String>{'daily', 'weekdays', 'interval_days', 'month_days'};

    var mode = modes.contains(meta?.recurrenceMode)
        ? meta!.recurrenceMode
        : 'daily';

    final weekdays = <int>{
      if (meta != null && meta.recurrenceWeekdays.isNotEmpty)
        ...meta.recurrenceWeekdays
      else
        DateTime.now().weekday,
    };

    final monthDays = <int>{
      if (meta != null && meta.recurrenceMonthDays.isNotEmpty)
        ...meta.recurrenceMonthDays
      else
        DateTime.now().day.clamp(1, 31).toInt(),
    };

    var intervalText = (meta?.recurrenceIntervalDays ?? 2).toString();
    String? validationMessage;

    return showDialog<_MedicineRecurrenceSelection>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (innerContext, setDialogState) {
          Widget repeatOption(String value, String label) {
            final selected = mode == value;

            return ListTile(
              contentPadding: EdgeInsets.zero,
              minLeadingWidth: 28,
              leading: Icon(
                selected
                    ? Icons.radio_button_checked
                    : Icons.radio_button_unchecked,
                color: selected ? AppColors.primary : AppColors.muted,
              ),
              title: Text(label),
              onTap: () {
                setDialogState(() {
                  mode = value;
                  validationMessage = null;
                });
              },
            );
          }

          return AlertDialog(
            title: Text('Repeat pattern for ${task.title}'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Enter only the repeat pattern stated in the healthcare professional instructions.',
                  ),
                  const SizedBox(height: 12),
                  repeatOption('daily', 'Daily'),
                  repeatOption('weekdays', 'Selected weekdays'),
                  if (mode == 'weekdays') ...[
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: List<Widget>.generate(7, (index) {
                        final day = index + 1;

                        return FilterChip(
                          selected: weekdays.contains(day),
                          label: Text(_weekdayNames[day].substring(0, 3)),
                          onSelected: (selected) {
                            setDialogState(() {
                              if (selected) {
                                weekdays.add(day);
                              } else {
                                weekdays.remove(day);
                              }
                              validationMessage = null;
                            });
                          },
                        );
                      }),
                    ),
                  ],
                  repeatOption('interval_days', 'Every N days'),
                  if (mode == 'interval_days') ...[
                    const SizedBox(height: 4),
                    TextFormField(
                      initialValue: intervalText,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'Interval in days',
                        hintText: 'Example: 3',
                        errorText: validationMessage,
                      ),
                      onChanged: (value) {
                        intervalText = value;

                        if (validationMessage != null) {
                          setDialogState(() {
                            validationMessage = null;
                          });
                        }
                      },
                    ),
                  ],
                  repeatOption('month_days', 'Selected days of the month'),
                  if (mode == 'month_days') ...[
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: List<Widget>.generate(31, (index) {
                        final day = index + 1;

                        return FilterChip(
                          selected: monthDays.contains(day),
                          label: Text('$day'),
                          onSelected: (selected) {
                            setDialogState(() {
                              if (selected) {
                                monthDays.add(day);
                              } else {
                                monthDays.remove(day);
                              }
                              validationMessage = null;
                            });
                          },
                        );
                      }),
                    ),
                  ],
                  if (validationMessage != null && mode != 'interval_days') ...[
                    const SizedBox(height: 10),
                    Text(
                      validationMessage!,
                      style: const TextStyle(
                        color: AppColors.criticalForeground,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: Text(context.tr('cancel')),
              ),
              FilledButton(
                onPressed: () {
                  final selectedWeekdays = weekdays.toList()..sort();
                  final selectedMonthDays = monthDays.toList()..sort();
                  final intervalDays = int.tryParse(intervalText.trim());

                  if (mode == 'weekdays' && selectedWeekdays.isEmpty) {
                    setDialogState(() {
                      validationMessage = 'Choose at least one weekday.';
                    });
                    return;
                  }

                  if (mode == 'interval_days' &&
                      (intervalDays == null ||
                          intervalDays < 1 ||
                          intervalDays > 3650)) {
                    setDialogState(() {
                      validationMessage =
                          'Enter an interval from 1 to 3650 days.';
                    });
                    return;
                  }

                  if (mode == 'month_days' && selectedMonthDays.isEmpty) {
                    setDialogState(() {
                      validationMessage = 'Choose at least one day.';
                    });
                    return;
                  }

                  Navigator.of(dialogContext).pop(
                    _MedicineRecurrenceSelection(
                      mode: mode,
                      weekdays: mode == 'weekdays'
                          ? selectedWeekdays
                          : const <int>[],
                      intervalDays: mode == 'interval_days'
                          ? intervalDays
                          : null,
                      monthDays: mode == 'month_days'
                          ? selectedMonthDays
                          : const <int>[],
                    ),
                  );
                },
                child: const Text('Save repeat pattern'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _setMedicineRepeatPattern(
    DemoTask task,
    ScheduleTaskMeta? meta,
  ) async {
    final selection = await _showMedicineRepeatPatternDialog(task, meta);

    if (selection == null || !mounted) {
      return;
    }

    final key = _medicineDurationKey(task, meta);

    if (_medicineRecurrenceSavingKeys.contains(key)) {
      return;
    }

    setState(() {
      _medicineRecurrenceSavingKeys.add(key);
      _scheduleSaveState = 'Saving...';
    });

    try {
      await _carePlanService.saveMedicineRecurrence(
        task.id,
        mode: selection.mode,
        weekdays: selection.weekdays,
        intervalDays: selection.intervalDays,
        monthDays: selection.monthDays,
      );

      await _loadPlan();

      if (!mounted) return;

      setState(() {
        _scheduleSaveState = 'Saved';
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Repeat pattern saved for ${task.title}.')),
      );
    } on CarePlanException catch (error) {
      if (!mounted) return;

      setState(() {
        _scheduleSaveState = 'Retry needed';
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    } finally {
      if (mounted) {
        setState(() {
          _medicineRecurrenceSavingKeys.remove(key);
        });
      }
    }
  }

  Future<void> _setMedicineDuration(
    DemoTask task,
    ScheduleTaskMeta? meta,
  ) async {
    var durationText = meta?.userDuration == true
        ? meta!.durationDays.toString()
        : '';
    String? validationMessage;

    final selectedDays = await showDialog<int>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (innerContext, setDialogState) => AlertDialog(
          title: Text('Set course duration for ${task.title}'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Enter the number of days you were told to use this medicine.',
                ),
                const SizedBox(height: 14),
                TextFormField(
                  initialValue: durationText,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'Course duration',
                    hintText: 'Example: 5',
                    errorText: validationMessage,
                  ),
                  onChanged: (value) {
                    durationText = value;

                    if (validationMessage != null) {
                      setDialogState(() {
                        validationMessage = null;
                      });
                    }
                  },
                ),
                const SizedBox(height: 12),
                const SafetyNote(
                  text:
                      'This is recorded as user-provided information. It does not change the verified prescription.',
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final days = int.tryParse(durationText.trim());

                if (days == null || days < 1 || days > 3650) {
                  setDialogState(() {
                    validationMessage = 'Enter a value from 1 to 3650 days.';
                  });
                  return;
                }

                Navigator.of(dialogContext).pop(days);
              },
              child: const Text('Save duration'),
            ),
          ],
        ),
      ),
    );

    if (selectedDays == null || !mounted) {
      return;
    }

    final key = _medicineDurationKey(task, meta);

    if (_medicineDurationSavingKeys.contains(key)) {
      return;
    }

    setState(() {
      _medicineDurationSavingKeys.add(key);
      _scheduleSaveState = 'Saving…';
    });

    try {
      await _carePlanService.saveMedicineDuration(
        task.id,
        mode: 'days',
        durationDays: selectedDays,
      );

      await _loadPlan();

      if (!mounted) return;

      setState(() {
        _scheduleSaveState = 'Saved';
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Course duration saved for ${task.title}.')),
      );
    } on CarePlanException catch (error) {
      if (!mounted) return;

      setState(() {
        _scheduleSaveState = 'Retry needed';
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    } finally {
      if (mounted) {
        setState(() {
          _medicineDurationSavingKeys.remove(key);
        });
      }
    }
  }

  Future<void> _setMedicineUntilPlanEnd(
    DemoTask task,
    ScheduleTaskMeta? meta,
  ) async {
    final detail = _detail;

    if (detail == null || detail.plan.plannedEndDate.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Save the care-plan end date first.')),
      );
      return;
    }

    final key = _medicineDurationKey(task, meta);

    if (_medicineDurationSavingKeys.contains(key)) {
      return;
    }

    setState(() {
      _medicineDurationSavingKeys.add(key);
      _scheduleSaveState = 'Saving…';
    });

    try {
      await _carePlanService.saveMedicineDuration(task.id, mode: 'plan_end');

      await _loadPlan();

      if (!mounted) return;

      setState(() {
        _scheduleSaveState = 'Saved';
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${task.title} will follow the care-plan end date.'),
        ),
      );
    } on CarePlanException catch (error) {
      if (!mounted) return;

      setState(() {
        _scheduleSaveState = 'Retry needed';
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    } finally {
      if (mounted) {
        setState(() {
          _medicineDurationSavingKeys.remove(key);
        });
      }
    }
  }

  Widget _medicineSettingRow({
    required String title,
    required String label,
    required bool resolved,
    required bool verified,
    required bool saving,
    Widget? action,
  }) {
    final icon = saving
        ? null
        : verified
        ? Icons.lock_outline
        : resolved
        ? Icons.check_circle_outline
        : Icons.warning_amber_rounded;

    final iconColor = verified
        ? AppColors.successForeground
        : resolved
        ? AppColors.primary
        : AppColors.warningForeground;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final content = Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: verified
                      ? AppColors.successSoft
                      : resolved
                      ? AppColors.primaryLight
                      : AppColors.warningSoft,
                  borderRadius: BorderRadius.circular(AppRadii.lg),
                ),
                alignment: Alignment.center,
                child: saving
                    ? SizedBox(
                        width: 15,
                        height: 15,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: iconColor,
                        ),
                      )
                    : Icon(icon, size: 17, color: iconColor),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppColors.muted,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      label,
                      style: const TextStyle(
                        fontSize: 13,
                        height: 1.3,
                        fontWeight: FontWeight.w700,
                        color: AppColors.foreground,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );

          if (action == null) return content;

          if (constraints.maxWidth < 440) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                content,
                const SizedBox(height: 8),
                Align(alignment: AlignmentDirectional.centerEnd, child: action),
              ],
            );
          }

          return Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(child: content),
              const SizedBox(width: 8),
              action,
            ],
          );
        },
      ),
    );
  }

  bool _medicineReminderIsLocked(DemoTask task) {
    final note = task.note.toLowerCase();
    final hasVerifiedExactReason =
        note.contains('exact clock time') &&
        note.contains('verified instruction');
    return _canonicalClockTime(_timeOverrides[task.id] ?? task.time) != null &&
        (task.timeLocked ||
            task.grounding.trim().toLowerCase() == 'explicit' ||
            hasVerifiedExactReason);
  }

  Widget _medicineReminderRow(DemoTask task) {
    final period =
        _periodOverrides[task.id] ?? _periodFrom('${task.time} ${task.note}');
    final displayTime = _timeOverrides[task.id] ?? task.time;
    final formattedTime = _displayClockTime(displayTime);
    final locked = _medicineReminderIsLocked(task);
    final periodChanged = _unsavedPeriodChanges.contains(task.id);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          const SizedBox(
            width: 28,
            child: Icon(
              Icons.alarm_outlined,
              size: 18,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '${_localizedPeriod(context, period)} · $formattedTime',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
            ),
          ),
          if (locked)
            const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.lock_outline, size: 14, color: AppColors.muted),
                SizedBox(width: 4),
                Text(
                  'Verified',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.muted,
                  ),
                ),
              ],
            )
          else
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  tooltip: 'Edit period',
                  visualDensity: VisualDensity.compact,
                  onPressed: () => _editSchedulePeriod(task),
                  icon: const Icon(Icons.wb_sunny_outlined, size: 18),
                ),
                IconButton(
                  tooltip: 'Set time',
                  visualDensity: VisualDensity.compact,
                  onPressed: () => _confirmScheduleItem(task),
                  icon: const Icon(Icons.schedule_outlined, size: 18),
                ),
              ],
            ),
          if (periodChanged) ...[
            const SizedBox(width: 5),
            const Icon(
              Icons.info_outline,
              size: 15,
              color: AppColors.warningForeground,
            ),
          ],
        ],
      ),
    );
  }

  Widget _medicineDurationCard(
    CarePlanDetailData detail,
    List<DemoTask> tasks,
  ) {
    final task = tasks.first;
    final meta = _medicineMetaForGroup(detail, tasks);
    final durationResolved = _medicineGroupDurationResolved(detail, tasks);
    final durationVerified = durationResolved && meta?.verifiedDuration == true;
    final recurrenceResolved = _medicineGroupRecurrenceResolved(detail, tasks);
    final recurrenceVerified =
        recurrenceResolved && meta?.verifiedRecurrence == true;
    final key = _medicineDurationKey(task, meta);
    final durationSaving = _medicineDurationSavingKeys.contains(key);
    final recurrenceSaving = _medicineRecurrenceSavingKeys.contains(key);
    final planEndAvailable = detail.plan.plannedEndDate.trim().isNotEmpty;
    final durationLabel = _medicineDurationLabel(meta, durationResolved);
    final recurrenceLabel = _medicineRecurrenceLabel(meta, recurrenceResolved);
    final reminderTasks = _medicineReminderTasksForDisplay(tasks);
    final reminderTimeCount = reminderTasks.length;

    Widget? recurrenceAction;
    if (!recurrenceVerified) {
      recurrenceAction = TextButton.icon(
        onPressed: recurrenceSaving
            ? null
            : () => _setMedicineRepeatPattern(task, meta),
        icon: const Icon(Icons.repeat_rounded, size: 16),
        label: Text(
          meta?.userRecurrence == true ? 'Change' : 'Set repeat pattern',
        ),
      );
    }

    Widget? durationAction;
    if (!durationVerified) {
      durationAction = PopupMenuButton<String>(
        tooltip: 'Course duration options',
        onSelected: (value) {
          if (value == 'days') {
            _setMedicineDuration(task, meta);
          } else if (value == 'plan_end') {
            _setMedicineUntilPlanEnd(task, meta);
          }
        },
        itemBuilder: (context) => [
          PopupMenuItem<String>(
            value: 'days',
            child: Text(
              meta?.userDuration == true ? 'Change duration' : 'Set duration',
            ),
          ),
          if (planEndAvailable)
            const PopupMenuItem<String>(
              value: 'plan_end',
              child: Text('Use care-plan end date'),
            ),
        ],
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
          decoration: BoxDecoration(
            color: AppColors.primaryLight,
            borderRadius: BorderRadius.circular(AppRadii.lg),
          ),
          child: const Icon(
            Icons.more_horiz_rounded,
            size: 20,
            color: AppColors.primary,
          ),
        ),
      );
    }

    final needsAttention = !durationResolved || !recurrenceResolved;

    return HoverLift(
      child: AppCard(
        padding: EdgeInsets.zero,
        borderColor: needsAttention
            ? AppColors.warning.withValues(alpha: .22)
            : const Color(0xFFCCFBF1),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              height: 4,
              decoration: BoxDecoration(
                color: needsAttention ? AppColors.warning : AppColors.primary,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(AppRadii.xxl),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: needsAttention
                                ? const [Color(0xFFFFF7ED), Color(0xFFFFFBEB)]
                                : const [Color(0xFFCCFBF1), Color(0xFFF0FDFA)],
                          ),
                          borderRadius: BorderRadius.circular(AppRadii.xl),
                        ),
                        alignment: Alignment.center,
                        child: Icon(
                          Icons.medication_outlined,
                          size: 22,
                          color: needsAttention
                              ? AppColors.warningForeground
                              : AppColors.primary,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              task.title,
                              style: const TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 5),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 9,
                                vertical: 5,
                              ),
                              decoration: BoxDecoration(
                                color: needsAttention
                                    ? AppColors.warningSoft
                                    : AppColors.primaryLight,
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                needsAttention
                                    ? 'Needs schedule details'
                                    : 'Schedule ready',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: needsAttention
                                      ? AppColors.warningForeground
                                      : AppColors.accentForeground,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 9,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Text(
                          '$reminderTimeCount ${reminderTimeCount == 1 ? 'time' : 'times'}',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: AppColors.muted,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Container(height: 1, color: AppColors.border),
                  _medicineSettingRow(
                    title: 'Repeat pattern',
                    label: recurrenceLabel,
                    resolved: recurrenceResolved,
                    verified: recurrenceVerified,
                    saving: recurrenceSaving,
                    action: recurrenceAction,
                  ),
                  Container(height: 1, color: AppColors.border),
                  _medicineSettingRow(
                    title: 'Course duration',
                    label: durationLabel,
                    resolved: durationResolved,
                    verified: durationVerified,
                    saving: durationSaving,
                    action: durationAction,
                  ),
                  Container(height: 1, color: AppColors.border),
                  Padding(
                    padding: const EdgeInsets.only(top: 11, bottom: 2),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.alarm_outlined,
                          size: 16,
                          color: AppColors.primary,
                        ),
                        const SizedBox(width: 7),
                        Text(
                          reminderTimeCount == 1
                              ? 'Reminder time'
                              : 'Reminder times ($reminderTimeCount)',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: AppColors.foreground,
                          ),
                        ),
                      ],
                    ),
                  ),
                  ...reminderTasks.map(_medicineReminderRow),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _medicineDurationsSection(CarePlanDetailData detail) {
    final groups = _medicineScheduleGroups(detail);

    if (groups.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: AppColors.primaryLight,
                borderRadius: BorderRadius.circular(AppRadii.lg),
              ),
              child: const Icon(
                Icons.medication_liquid_outlined,
                size: 19,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(width: 10),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Medicines',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Repeat pattern, duration and reminder times',
                    style: TextStyle(fontSize: 12, color: AppColors.muted),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
              decoration: BoxDecoration(
                color: AppColors.primaryLight,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                '${groups.length}',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: AppColors.accentForeground,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ...groups.values.toList().asMap().entries.map(
          (entry) => FadeSlideIn(
            delay: Duration(milliseconds: 35 * entry.key.clamp(0, 5)),
            child: Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _medicineDurationCard(detail, entry.value),
            ),
          ),
        ),
      ],
    );
  }

  Widget _tabContent(CarePlanDetailData detail) {
    switch (tab) {
      case 0:
        if (detail.instructions.isEmpty) {
          return EmptyState(
            icon: Icons.fact_check_outlined,
            title: context.tr('no_instructions_yet'),
            description: context.tr('upload_documents_to_extract_instructions'),
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: OutlinedButton.icon(
                onPressed: () async {
                  await Navigator.pushNamed(
                    context,
                    AppRoutes.carePlanReview,
                    arguments: CarePlanReviewArgs(
                      planId: widget.planId,
                      returnToPrevious: true,
                    ),
                  );
                  if (mounted) await _loadPlan();
                },
                icon: const Icon(Icons.edit_outlined, size: 17),
                label: Text(context.tr('edit_instructions')),
              ),
            ),
            const SizedBox(height: 12),
            ...detail.instructions.asMap().entries.map(
              (entry) => FadeSlideIn(
                delay: Duration(milliseconds: 35 * entry.key.clamp(0, 5)),
                child: _InstructionRow(
                  task: entry.value,
                  onRemove: entry.value.kind == TaskKind.medicine
                      ? () => _removeMedicineInstruction(entry.value)
                      : null,
                ),
              ),
            ),
          ],
        );

      case 1:
        if (detail.tasks.isEmpty) {
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 34),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFFF0FDFA), Color(0xFFF8FAFC)],
              ),
              borderRadius: BorderRadius.circular(AppRadii.xxxl),
              border: Border.all(color: const Color(0xFFCCFBF1)),
            ),
            child: Column(
              children: [
                Container(
                  width: 54,
                  height: 54,
                  decoration: BoxDecoration(
                    color: AppColors.primaryLight,
                    borderRadius: BorderRadius.circular(AppRadii.xl),
                  ),
                  child: const Icon(
                    Icons.calendar_month_outlined,
                    color: AppColors.primary,
                    size: 26,
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  context.tr('no_scheduled_tasks_yet'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  context.tr('generate_schedule_from_verified_instructions'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppColors.muted,
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 18),
                FilledButton.icon(
                  onPressed: _generatingSchedule ? null : _generateSchedule,
                  icon: _generatingSchedule
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.auto_awesome_rounded, size: 18),
                  label: Text(
                    _generatingSchedule
                        ? context.tr('generating')
                        : context.tr('generate_schedule'),
                  ),
                ),
              ],
            ),
          );
        }

        final hasUnresolvedMedicineDurations = _hasUnresolvedMedicineDurations(
          detail,
        );
        final hasUnresolvedMedicineRecurrences =
            _hasUnresolvedMedicineRecurrences(detail);
        final scheduleRows = _nonMedicineScheduleRows(detail);
        final scheduleBlocked =
            detail.tasks.any((task) => task.status == TaskStatus.atRisk) ||
            _unsavedPeriodChanges.isNotEmpty ||
            hasUnresolvedMedicineRecurrences ||
            hasUnresolvedMedicineDurations;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            FadeSlideIn(child: _planEndDateCard(detail.plan)),
            const SizedBox(height: 22),

            if (!AuthSession.instance.isGuest) ...[
              _medicineDurationsSection(detail),
              const SizedBox(height: 22),
            ],

            if (detail.plan.status == PlanStatus.active ||
                detail.plan.status == PlanStatus.completed) ...[
              FadeSlideIn(
                delay: const Duration(milliseconds: 80),
                child: _todayTaskOutcomesSection(detail.plan),
              ),
              const SizedBox(height: 22),
            ],

            if (scheduleRows.isNotEmpty) ...[
              Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: AppColors.infoSoft,
                      borderRadius: BorderRadius.circular(AppRadii.lg),
                    ),
                    child: const Icon(
                      Icons.event_note_outlined,
                      size: 18,
                      color: AppColors.info,
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'Other schedule items',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ...scheduleRows.asMap().entries.map(
                (entry) => FadeSlideIn(
                  delay: Duration(milliseconds: 35 * entry.key.clamp(0, 5)),
                  child: _ScheduleRow(
                    task: entry.value,
                    period:
                        _periodOverrides[entry.value.id] ??
                        _periodFrom('${entry.value.time} ${entry.value.note}'),
                    displayTime:
                        _timeOverrides[entry.value.id] ?? entry.value.time,
                    periodChanged: _unsavedPeriodChanges.contains(
                      entry.value.id,
                    ),
                    onEditPeriod: () => _editSchedulePeriod(entry.value),
                    onSetTime: () => _confirmScheduleItem(entry.value),
                  ),
                ),
              ),
              const SizedBox(height: 4),
            ],

            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: TextButton.icon(
                onPressed: _generatingSchedule ? null : _generateSchedule,
                icon: _generatingSchedule
                    ? const SizedBox(
                        width: 15,
                        height: 15,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.refresh_rounded, size: 16),
                label: Text(context.tr('regenerate')),
              ),
            ),
            const SizedBox(height: 8),

            AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: scheduleBlocked
                    ? AppColors.warningSoft
                    : AppColors.successSoft,
                borderRadius: BorderRadius.circular(AppRadii.xxl),
                border: Border.all(
                  color:
                      (scheduleBlocked ? AppColors.warning : AppColors.success)
                          .withValues(alpha: .18),
                ),
              ),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: scheduleBlocked ? null : _continueFromSchedule,
                  icon: Icon(
                    scheduleBlocked
                        ? Icons.lock_outline_rounded
                        : widget.returnToPrevious
                        ? Icons.check_rounded
                        : Icons.arrow_forward_rounded,
                    size: 18,
                  ),
                  label: Text(
                    hasUnresolvedMedicineRecurrences
                        ? 'Set medicine repeat patterns first'
                        : hasUnresolvedMedicineDurations
                        ? 'Set medicine course durations first'
                        : detail.tasks.any(
                                (task) => task.status == TaskStatus.atRisk,
                              ) ||
                              _unsavedPeriodChanges.isNotEmpty
                        ? context.tr('confirm_schedule_items_first')
                        : widget.returnToPrevious
                        ? context.tr('done')
                        : context.tr('continue_to_reality_check'),
                  ),
                ),
              ),
            ),
          ],
        );

      case 2:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: OutlinedButton.icon(
                onPressed: () async {
                  await Navigator.pushNamed(
                    context,
                    AppRoutes.realityCheck,
                    arguments: CareFlowArgs(
                      planId: widget.planId,
                      returnToPrevious: true,
                    ),
                  );
                  if (mounted) await _loadPlan();
                },
                icon: const Icon(Icons.edit_note_outlined, size: 17),
                label: Text(context.tr('edit_reality_check')),
              ),
            ),
            const SizedBox(height: 12),
            FadeSlideIn(
              child: AppCard(
                padding: const EdgeInsets.all(10),
                child: SimulationView(compact: true, planId: widget.planId),
              ),
            ),
          ],
        );

      case 3:
        final openGaps = detail.gaps
            .where((gap) => gap.status != TaskStatus.resolved)
            .toList();

        if (openGaps.isEmpty) {
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 34),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFFF0FDFA), Color(0xFFF8FAFC)],
              ),
              borderRadius: BorderRadius.circular(AppRadii.xxxl),
              border: Border.all(color: const Color(0xFFCCFBF1)),
            ),
            child: Column(
              children: [
                Container(
                  width: 54,
                  height: 54,
                  decoration: BoxDecoration(
                    color: AppColors.successSoft,
                    borderRadius: BorderRadius.circular(AppRadii.xl),
                  ),
                  child: const Icon(
                    Icons.verified_user_outlined,
                    color: AppColors.successForeground,
                    size: 27,
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  context.tr('no_open_care_gaps'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  context.tr('no_unresolved_care_plan_issues'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.muted,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          );
        }

        return Column(
          children: openGaps
              .asMap()
              .entries
              .map(
                (entry) => FadeSlideIn(
                  delay: Duration(milliseconds: 35 * entry.key.clamp(0, 5)),
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: HoverLift(
                      cursor: SystemMouseCursors.click,
                      child: InkWell(
                        onTap: () async {
                          await Navigator.pushNamed(
                            context,
                            AppRoutes.careGap(entry.value.id),
                          );
                          if (mounted) await _loadPlan();
                        },
                        borderRadius: BorderRadius.circular(AppRadii.xxl),
                        child: AppCard(
                          borderColor: AppColors.warning.withValues(alpha: .18),
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 42,
                                height: 42,
                                decoration: BoxDecoration(
                                  color: AppColors.warningSoft,
                                  borderRadius: BorderRadius.circular(
                                    AppRadii.xl,
                                  ),
                                ),
                                child: const Icon(
                                  Icons.health_and_safety_outlined,
                                  color: AppColors.warningForeground,
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    StatusBadge(status: entry.value.status),
                                    const SizedBox(height: 8),
                                    Text(
                                      entry.value.title,
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      entry.value.summary,
                                      style: const TextStyle(
                                        fontSize: 13,
                                        color: AppColors.muted,
                                        height: 1.4,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              const Icon(
                                Icons.chevron_right_rounded,
                                color: AppColors.subtle,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              )
              .toList(),
        );

      default:
        final documents = detail.documents;

        if (documents.isEmpty) {
          return EmptyState(
            icon: Icons.description_outlined,
            title: context.tr('no_documents_yet'),
            description: context.tr('upload_document_to_build_plan'),
            action: FilledButton.icon(
              onPressed: () => Navigator.pushNamed(
                context,
                AppRoutes.carePlanUpload,
                arguments: CarePlanUploadArgs(
                  planId: detail.plan.id,
                  documentTypes: const [],
                  returnToPrevious: true,
                ),
              ),
              icon: const Icon(Icons.upload_file_outlined, size: 18),
              label: Text(context.tr('upload_document')),
            ),
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: OutlinedButton.icon(
                onPressed: () async {
                  await Navigator.pushNamed(
                    context,
                    AppRoutes.carePlanUpload,
                    arguments: CarePlanUploadArgs(
                      planId: detail.plan.id,
                      documentTypes: const [],
                      returnToPrevious: true,
                    ),
                  );
                  if (mounted) await _loadPlan();
                },
                icon: const Icon(Icons.add_rounded, size: 17),
                label: Text(context.tr('add_document')),
              ),
            ),
            const SizedBox(height: 12),
            ...documents.asMap().entries.map(
              (entry) => FadeSlideIn(
                delay: Duration(milliseconds: 35 * entry.key.clamp(0, 5)),
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: AppCard(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: AppColors.infoSoft,
                            borderRadius: BorderRadius.circular(AppRadii.xl),
                          ),
                          child: const Icon(
                            Icons.description_outlined,
                            size: 21,
                            color: AppColors.info,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                entry.value.name,
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                context.tr(
                                  entry.value.pages == 1
                                      ? 'document_meta_page'
                                      : 'document_meta_pages',
                                  values: {
                                    'type': entry.value.type,
                                    'pages': entry.value.pages,
                                    'date': entry.value.date,
                                  },
                                ),
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.muted,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: () => _deleteDocument(entry.value.id),
                          icon: const Icon(
                            Icons.delete_outline_rounded,
                            size: 19,
                          ),
                          tooltip: context.tr('remove_document'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
    }
  }

  String _displayClock(String value) {
    final parts = value.split(':');
    if (parts.length < 2) return value;
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null) return value;
    final suffix = hour >= 12 ? 'PM' : 'AM';
    final hour12 = hour % 12 == 0 ? 12 : hour % 12;
    return '$hour12:${minute.toString().padLeft(2, '0')} $suffix';
  }

  String _visualOutcomeStatus(CareTaskOccurrence item) {
    if (!item.pending) return item.status;
    final now = DateTime.now();
    final dateParts = item.occurrenceDate.split('-');
    final timeParts = item.scheduledTime.split(':');
    if (dateParts.length != 3 || timeParts.length < 2) return 'upcoming';
    final scheduled = DateTime(
      int.tryParse(dateParts[0]) ?? now.year,
      int.tryParse(dateParts[1]) ?? now.month,
      int.tryParse(dateParts[2]) ?? now.day,
      int.tryParse(timeParts[0]) ?? 0,
      int.tryParse(timeParts[1]) ?? 0,
    );
    final difference = now.difference(scheduled).inMinutes;
    if (difference < -30) return 'upcoming';
    if (difference <= 30) return 'due';
    return 'overdue';
  }

  Future<void> _setOccurrenceOutcome(
    CareTaskOccurrence item,
    String outcome,
  ) async {
    if (_outcomeSavingIds.contains(item.id)) return;

    if (outcome == 'skipped') {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(context.tr('cpd_record_skip_title')),
          content: Text(context.tr('cpd_record_skip_body')),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text(context.tr('cancel')),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: Text(context.tr('cpd_record_skipped')),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
    }

    setState(() => _outcomeSavingIds.add(item.id));
    try {
      final result = await CareReliabilityService.instance.setOutcome(
        item,
        outcome,
      );
      final updated = result.occurrence;
      if (!mounted) return;
      setState(() {
        _todayOccurrences = _todayOccurrences
            .map((entry) => entry.id == updated.id ? updated : entry)
            .toList();
        final completed = _todayOccurrences
            .where((entry) => entry.completed)
            .length;
        final skipped = _todayOccurrences
            .where((entry) => entry.skipped)
            .length;
        final missed = _todayOccurrences.where((entry) => entry.missed).length;
        _todaySummary = CareTaskDaySummary(
          total: _todayOccurrences.length,
          completed: completed,
          skipped: skipped,
          missed: missed,
          pending: _todayOccurrences.length - completed - skipped - missed,
        );
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            outcome == 'completed'
                ? context.tr('cpd_task_marked_completed')
                : outcome == 'skipped'
                ? context.tr('cpd_task_recorded_skipped')
                : context.tr('cpd_task_outcome_cleared'),
          ),
        ),
      );
      if (result.queued) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.tr('cpd_outcome_saved_offline'))),
        );
      } else if (result.conflictRecovered) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.tr('cpd_outcome_conflict_recovered'))),
        );
      }
    } on CarePlanException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
    } finally {
      if (mounted) setState(() => _outcomeSavingIds.remove(item.id));
    }
  }

  Widget _todayTaskOutcomesSection(DemoPlan plan) {
    final summary = _todaySummary;
    final completed =
        summary?.completed ??
        _todayOccurrences.where((item) => item.completed).length;
    final total = summary?.total ?? _todayOccurrences.length;

    return AppCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.tr('cpd_today_outcomes_title'),
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      context.tr('cpd_today_outcomes_subtitle'),
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.muted,
                      ),
                    ),
                  ],
                ),
              ),
              if (total > 0)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primaryLight,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    context.tr(
                      'cpd_outcomes_progress',
                      values: {'completed': completed, 'total': total},
                    ),
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          if (_todayOccurrences.isEmpty)
            Text(
              plan.status == PlanStatus.completed
                  ? context.tr('cpd_no_occurrences_recorded')
                  : context.tr('cpd_no_tasks_scheduled_today'),
              style: const TextStyle(color: AppColors.muted),
            )
          else
            ..._todayOccurrences.map(_todayOccurrenceCard),
          if (_todayOccurrences.isNotEmpty) ...[
            const SizedBox(height: 4),
            SafetyNote(text: context.tr('cpd_outcomes_safety_note')),
          ],
        ],
      ),
    );
  }

  Widget _todayOccurrenceCard(CareTaskOccurrence item) {
    final visual = _visualOutcomeStatus(item);
    final saving = _outcomeSavingIds.contains(item.id);
    final isCompleted = item.completed;
    final isSkipped = item.skipped;
    final isMissed = item.missed;
    final statusLabel = switch (visual) {
      'completed' =>
        item.completedTime.isEmpty
            ? context.tr('cpd_status_completed')
            : context.tr(
                'cpd_status_completed_at',
                values: {'time': _displayClock(item.completedTime)},
              ),
      'skipped' => context.tr('cpd_status_skipped'),
      'missed' => context.tr('cpd_status_missed'),
      'overdue' => context.tr('cpd_status_overdue'),
      'due' => context.tr('cpd_status_due_now'),
      _ => context.tr('cpd_status_upcoming'),
    };
    final statusColor = switch (visual) {
      'completed' => AppColors.successForeground,
      'skipped' => AppColors.warningForeground,
      'missed' => AppColors.criticalForeground,
      'overdue' => AppColors.warningForeground,
      'due' => AppColors.primary,
      _ => AppColors.muted,
    };

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(AppRadii.xl),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.checklist_rounded,
                color: AppColors.primary,
                size: 21,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${_displayClock(item.scheduledTime)}${item.period.isEmpty ? '' : ' · ${_localizedPeriod(context, item.period)}'}',
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.muted,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                statusLabel,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: statusColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (isCompleted || isSkipped || isMissed)
            Align(
              alignment: Alignment.centerRight,
              child: OutlinedButton.icon(
                onPressed: saving
                    ? null
                    : isMissed
                    ? () => _setOccurrenceOutcome(item, 'completed')
                    : () => _setOccurrenceOutcome(item, 'pending'),
                icon: saving
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Icon(
                        isMissed ? Icons.check_circle_outline : Icons.undo,
                        size: 17,
                      ),
                label: Text(
                  isMissed
                      ? context.tr('cpd_correct_as_completed')
                      : context.tr('cpd_undo'),
                ),
              ),
            )
          else
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: saving
                        ? null
                        : () => _setOccurrenceOutcome(item, 'completed'),
                    icon: const Icon(Icons.check_circle_outline, size: 18),
                    label: Text(context.tr('cpd_mark_completed')),
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton(
                  onPressed: saving
                      ? null
                      : () => _setOccurrenceOutcome(item, 'skipped'),
                  child: Text(context.tr('cpd_record_skipped')),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Future<void> _deleteDocument(String documentId) async {
    if (AuthSession.instance.isGuest) return;
    try {
      await _carePlanService.deleteDocument(documentId);
      await _loadPlan();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.tr('cpd_document_removed'))),
        );
      }
    } on CarePlanException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
    }
  }

  Future<void> _removeMedicineInstruction(DemoTask task) async {
    if (AuthSession.instance.isGuest) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(context.tr('cpd_remove_medicine_title')),
        content: Text(
          context.tr(
            'cpd_remove_medicine_body',
            values: {'medicine': task.title},
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(context.tr('cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.criticalForeground,
            ),
            child: Text(context.tr('cpd_remove_from_sehatmate')),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    try {
      await _carePlanService.deleteInstruction(task.id);

      // Rebuild local notifications from backend truth. Cancelling the whole
      // plan first guarantees the removed medicine cannot leave an orphaned
      // Android notification behind.
      await NotificationService.instance.cancelPlan(widget.planId);

      final updated = await _carePlanService.fetchPlanDetail(widget.planId);
      if (updated.plan.status == PlanStatus.active &&
          updated.tasks.isNotEmpty) {
        await NotificationService.instance.scheduleNextOccurrences(
          planId: widget.planId,
          tasks: updated.tasks,
        );
      }

      if (!mounted) return;
      setState(() {
        _detail = updated;
        _periodOverrides.clear();
        _timeOverrides.clear();
        _unsavedPeriodChanges.clear();
      });
      await _loadPlan();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.tr('cpd_medicine_removed_rebuilt'))),
        );
      }
    } on CarePlanException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.tr('cpd_medicine_removed_rebuild_failed')),
          ),
        );
      }
    }
  }

  Future<void> _generateSchedule() async {
    if (AuthSession.instance.isGuest) {
      showDemoMessage(context, context.tr('cpd_schedule_sign_in_required'));
      return;
    }
    setState(() => _generatingSchedule = true);
    try {
      await _carePlanService.generateSchedule(widget.planId);
      await _loadPlan();
      if (mounted) {
        showDemoMessage(context, context.tr('cpd_schedule_generated'));
      }
    } on CarePlanException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
    } finally {
      if (mounted) setState(() => _generatingSchedule = false);
    }
  }

  Future<void> _continueFromSchedule() async {
    if (widget.returnToPrevious && Navigator.canPop(context)) {
      Navigator.pop(context);
      return;
    }
    if (widget.guidedSetup) {
      setState(() => _scheduleSaveState = 'Saving…');
      try {
        await _carePlanService.updateSetupStep(
          widget.planId,
          CareSetupStep.realityCheck,
        );
        if (!mounted) return;
        setState(() => _scheduleSaveState = 'Saved');
      } on CarePlanException catch (error) {
        if (!mounted) return;
        setState(() => _scheduleSaveState = 'Retry needed');
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
        return;
      }
    }
    if (!mounted) return;
    Navigator.pushReplacementNamed(
      context,
      AppRoutes.realityCheck,
      arguments: CareFlowArgs(
        planId: widget.planId,
        guidedSetup: widget.guidedSetup,
      ),
    );
  }

  bool _taskHasVerifiedExactTimeLock(DemoTask task) {
    final note = task.note.toLowerCase();
    final hasVerifiedExactReason =
        note.contains('exact clock time') &&
        note.contains('verified instruction');
    return task.timeLocked ||
        task.grounding.trim().toLowerCase() == 'explicit' ||
        hasVerifiedExactReason;
  }

  void _showVerifiedExactTimeLockedMessage() {
    showDemoMessage(context, context.tr('cpd_exact_time_locked_message'));
  }

  Future<void> _confirmScheduleItem(DemoTask task) async {
    if (_taskHasVerifiedExactTimeLock(task)) {
      _showVerifiedExactTimeLockedMessage();
      return;
    }
    final period =
        _periodOverrides[task.id] ?? _periodFrom('${task.time} ${task.note}');

    if (_periodAlreadyUsed(task, period)) {
      _showScheduleConflict(
        context.tr(
          'cpd_period_already_used',
          values: {'period': _localizedPeriod(context, period)},
        ),
      );
      return;
    }

    final initialTime = _parseTime(task.time) ?? _defaultTime(period);
    final selected = await _showRestrictedTimePicker(period, initialTime);
    if (selected == null || !mounted) return;
    final scheduleTime =
        '${selected.hour.toString().padLeft(2, '0')}:${selected.minute.toString().padLeft(2, '0')}';

    if (_timeAlreadyUsed(task, scheduleTime)) {
      _showScheduleConflict(
        context.tr(
          'cpd_time_already_used',
          values: {'time': selected.format(context)},
        ),
      );
      return;
    }

    try {
      setState(() => _scheduleSaveState = 'Saving…');
      await _carePlanService.confirmScheduleItem(
        task.id,
        scheduleTime: scheduleTime,
        displayTime:
            '$period · Confirmed reminder at ${selected.format(context)}',
      );

      if (!mounted) return;
      setState(() {
        _timeOverrides[task.id] = scheduleTime;
        _unsavedPeriodChanges.remove(task.id);
      });

      await _loadPlan();
      if (mounted) {
        setState(() => _scheduleSaveState = 'Saved');
        showDemoMessage(
          context,
          context.tr(
            'cpd_reminder_set_for_time',
            values: {
              'period': _localizedPeriod(context, period),
              'time': selected.format(context),
            },
          ),
        );
      }
    } on CarePlanException catch (error) {
      if (mounted) {
        setState(() => _scheduleSaveState = 'Retry needed');
        if (error.data?['medicalTimingConflict'] == true) {
          await _showMedicalTimingConflict(error);
        } else {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(error.message)));
        }
      }
    }
  }

  Future<void> _showMedicalTimingConflict(CarePlanException error) async {
    final data = error.data ?? const <String, dynamic>{};
    final originalInstruction =
        data['originalInstruction']?.toString().trim() ?? '';
    final originalTiming = data['originalTiming']?.toString().trim() ?? '';
    final recommendation = data['recommendation']?.toString().trim() ?? '';

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: const Icon(
          Icons.warning_amber_rounded,
          color: AppColors.criticalForeground,
          size: 34,
        ),
        title: Text(context.tr('cpd_medical_timing_conflict')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(error.message),
            if (originalInstruction.isNotEmpty) ...[
              const SizedBox(height: 14),
              Text(
                context.tr('cpd_verified_instruction_label'),
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 4),
              Text(
                [
                  originalInstruction,
                  if (originalTiming.isNotEmpty) originalTiming,
                ].join(' · '),
              ),
            ],
            if (recommendation.isNotEmpty) ...[
              const SizedBox(height: 14),
              Text(
                recommendation,
                style: const TextStyle(color: AppColors.muted, height: 1.4),
              ),
            ],
            const SizedBox(height: 12),
            Text(
              context.tr('cpd_prescription_not_changed'),
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              context.tr('cpd_timing_conflict_body'),
              style: const TextStyle(color: AppColors.muted, height: 1.4),
            ),
          ],
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(context.tr('cpd_ok')),
          ),
        ],
      ),
    );
  }

  Future<void> _editSchedulePeriod(DemoTask task) async {
    if (_taskHasVerifiedExactTimeLock(task)) {
      _showVerifiedExactTimeLockedMessage();
      return;
    }

    final current =
        _periodOverrides[task.id] ?? _periodFrom('${task.time} ${task.note}');
    final period = await showDialog<String>(
      context: context,
      builder: (dialogContext) => SimpleDialog(
        title: Text(context.tr('cpd_edit_time_period')),
        children: ['Morning', 'Afternoon', 'Evening', 'Night']
            .map(
              (value) => ListTile(
                leading: Icon(
                  value == current
                      ? Icons.radio_button_checked
                      : Icons.radio_button_off,
                  color: AppColors.primary,
                ),
                title: Text(_localizedPeriod(context, value)),
                subtitle: Text(_periodDescription(value)),
                onTap: () => Navigator.pop(dialogContext, value),
              ),
            )
            .toList(),
      ),
    );
    if (period == null || !mounted) return;

    if (_periodAlreadyUsed(task, period)) {
      _showScheduleConflict(
        context.tr(
          'cpd_period_already_used',
          values: {'period': _localizedPeriod(context, period)},
        ),
      );
      return;
    }

    setState(() {
      _periodOverrides[task.id] = period;
      _unsavedPeriodChanges.add(task.id);
      _scheduleSaveState = 'Choose time';
    });
  }

  bool _sameScheduleGroup(DemoTask first, DemoTask second) {
    if (first.id == second.id) return false;

    final firstTitle = first.title.trim().toLowerCase();
    final secondTitle = second.title.trim().toLowerCase();
    if (firstTitle.isEmpty || firstTitle != secondTitle) return false;

    final firstDay = first.day.trim();
    final secondDay = second.day.trim();

    // Schedule rows created from one instruction normally share the same title.
    // When both rows have a concrete date, only compare reminders on that date.
    if (firstDay.isNotEmpty && secondDay.isNotEmpty) {
      return firstDay == secondDay;
    }
    return true;
  }

  bool _periodAlreadyUsed(DemoTask task, String period) {
    final detail = _detail;
    if (detail == null) return false;

    return detail.tasks.any((other) {
      if (!_sameScheduleGroup(task, other)) return false;
      final otherPeriod =
          _periodOverrides[other.id] ??
          _periodFrom('${other.time} ${other.note}');
      return otherPeriod == period;
    });
  }

  bool _timeAlreadyUsed(DemoTask task, String scheduleTime) {
    final detail = _detail;
    if (detail == null) return false;

    final selected = _normalize24HourTime(scheduleTime);
    if (selected == null) return false;

    return detail.tasks.any((other) {
      if (!_sameScheduleGroup(task, other)) return false;

      final override = _timeOverrides[other.id];
      final otherTime = override != null
          ? _normalize24HourTime(override)
          : _timeOfDayTo24Hour(_parseTime(other.time));

      return otherTime != null && otherTime == selected;
    });
  }

  String? _normalize24HourTime(String value) {
    final parsed = _parseTime(value);
    return _timeOfDayTo24Hour(parsed);
  }

  String? _timeOfDayTo24Hour(TimeOfDay? value) {
    if (value == null) return null;
    return '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
  }

  void _showScheduleConflict(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<TimeOfDay?> _showRestrictedTimePicker(
    String period,
    TimeOfDay initial,
  ) async {
    final hours = switch (period) {
      'Morning' => List<int>.generate(8, (index) => index + 4),
      'Afternoon' => List<int>.generate(5, (index) => index + 12),
      'Evening' => List<int>.generate(4, (index) => index + 17),
      'Night' => <int>[21, 22, 23, 0, 1, 2, 3],
      _ => List<int>.generate(8, (index) => index + 4),
    };
    var hour = hours.contains(initial.hour)
        ? initial.hour
        : _defaultTime(period).hour;
    var minute = initial.minute;
    return showDialog<TimeOfDay>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(
            context.tr(
              'cpd_set_period_time',
              values: {'period': _localizedPeriod(context, period)},
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                context.tr(
                  'cpd_allowed_time_range',
                  values: {'range': _periodDescription(period)},
                ),
                style: const TextStyle(color: AppColors.muted),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<int>(
                      initialValue: hour,
                      isExpanded: true,
                      decoration: InputDecoration(
                        labelText: context.tr('cpd_label_hour'),
                      ),
                      items: hours
                          .map(
                            (value) => DropdownMenuItem(
                              value: value,
                              child: Text(_formatHour(value)),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        if (value != null) setDialogState(() => hour = value);
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: DropdownButtonFormField<int>(
                      initialValue: minute,
                      isExpanded: true,
                      decoration: InputDecoration(
                        labelText: context.tr('cpd_label_minute'),
                      ),
                      items: List<int>.generate(60, (index) => index)
                          .map(
                            (value) => DropdownMenuItem(
                              value: value,
                              child: Text(value.toString().padLeft(2, '0')),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        if (value != null) setDialogState(() => minute = value);
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(context.tr('cancel')),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(
                dialogContext,
                TimeOfDay(hour: hour, minute: minute),
              ),
              child: Text(context.tr('cpd_use_this_time')),
            ),
          ],
        ),
      ),
    );
  }

  String _formatHour(int hour) {
    final suffix = hour >= 12 ? 'PM' : 'AM';
    final display = hour % 12 == 0 ? 12 : hour % 12;
    return '$display $suffix';
  }

  String _periodFrom(String value) {
    final text = value.toLowerCase();

    // Once an exact reminder time has been saved, it is the strongest
    // source for the current period. This prevents an older recurrence
    // label such as "Evening" from overriding a user-edited "Night" slot.
    final match = RegExp(r'\b([01]?\d|2[0-3]):[0-5]\d\b').firstMatch(text);
    final hour = match == null ? null : int.tryParse(match.group(1)!);
    if (hour != null) {
      if (hour >= 4 && hour < 12) return 'Morning';
      if (hour >= 12 && hour < 17) return 'Afternoon';
      if (hour >= 17 && hour < 21) return 'Evening';
      return 'Night';
    }

    // Prefer the explicit user-editable Night/Bedtime label before
    // older recurrence wording that may still contain "Evening".
    if (text.contains('night') || text.contains('bedtime')) return 'Night';
    if (text.contains('afternoon')) return 'Afternoon';
    if (text.contains('evening')) return 'Evening';
    if (text.contains('morning')) return 'Morning';
    return 'Morning';
  }

  String _periodDescription(String period) => switch (period) {
    'Morning' => context.tr('cpd_period_morning_range'),
    'Afternoon' => context.tr('cpd_period_afternoon_range'),
    'Evening' => context.tr('cpd_period_evening_range'),
    'Night' => context.tr('cpd_period_night_range'),
    _ => context.tr('cpd_period_morning_range'),
  };

  TimeOfDay _defaultTime(String period) => switch (period) {
    'Afternoon' => const TimeOfDay(hour: 15, minute: 0),
    'Evening' => const TimeOfDay(hour: 19, minute: 0),
    'Night' => const TimeOfDay(hour: 22, minute: 0),
    _ => const TimeOfDay(hour: 8, minute: 0),
  };

  TimeOfDay? _parseTime(String value) {
    final match = RegExp(
      r'(\d{1,2}):(\d{2})\s*(AM|PM)?',
      caseSensitive: false,
    ).firstMatch(value.trim());

    if (match == null) return null;

    var hour = int.tryParse(match.group(1)!);
    final minute = int.tryParse(match.group(2)!);
    final suffix = match.group(3)?.toUpperCase();

    if (hour == null || minute == null || minute > 59) return null;

    if (suffix != null) {
      if (hour < 1 || hour > 12) return null;
      if (suffix == 'PM' && hour != 12) {
        hour += 12;
      } else if (suffix == 'AM' && hour == 12) {
        hour = 0;
      }
    } else if (hour > 23) {
      return null;
    }

    return TimeOfDay(hour: hour, minute: minute);
  }

  Widget _loadingView() => AppShell(
    currentRoute: AppRoutes.carePlans,
    title: context.tr('care_plan'),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _loadingSkeleton(width: 96, height: 14),
        const SizedBox(height: 14),
        AppCard(
          padding: const EdgeInsets.all(22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _loadingSkeleton(width: 115, height: 12),
              const SizedBox(height: 14),
              _loadingSkeleton(width: 250, height: 28),
              const SizedBox(height: 10),
              _loadingSkeleton(width: 210, height: 12),
              const SizedBox(height: 22),
              _loadingSkeleton(width: double.infinity, height: 10),
            ],
          ),
        ),
        const SizedBox(height: 14),
        LayoutBuilder(
          builder: (context, constraints) {
            final columns = constraints.maxWidth >= 760 ? 4 : 2;
            const gap = 10.0;
            final width =
                (constraints.maxWidth - ((columns - 1) * gap)) / columns;

            return Wrap(
              spacing: gap,
              runSpacing: gap,
              children: List.generate(
                4,
                (_) => SizedBox(
                  width: width,
                  child: AppCard(
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      children: [
                        _loadingSkeleton(width: 38, height: 38, radius: 12),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _loadingSkeleton(width: 46, height: 18),
                              const SizedBox(height: 6),
                              _loadingSkeleton(width: 82, height: 10),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 18),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _loadingSkeleton(width: 180, height: 16),
              const SizedBox(height: 14),
              _loadingSkeleton(width: double.infinity, height: 74, radius: 14),
              const SizedBox(height: 10),
              _loadingSkeleton(width: double.infinity, height: 74, radius: 14),
            ],
          ),
        ),
      ],
    ),
  );

  Widget _loadingSkeleton({
    required double width,
    required double height,
    double radius = 999,
  }) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: const Color(0xFFE8EEF2),
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }

  Widget _notFound(String? message) => AppShell(
    currentRoute: AppRoutes.carePlans,
    title: context.tr('care_plan'),
    child: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: AppCard(
          padding: const EdgeInsets.all(26),
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
                  Icons.find_in_page_outlined,
                  color: AppColors.warningForeground,
                  size: 27,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                context.tr('care_plan'),
                style: const TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                message ?? context.tr('care_plan_load_failed'),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppColors.muted,
                  fontSize: 13,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 18),
              FilledButton.icon(
                onPressed: () => Navigator.pushReplacementNamed(
                  context,
                  AppRoutes.carePlans,
                ),
                icon: const Icon(Icons.arrow_back_rounded, size: 18),
                label: Text(context.tr('care_plans')),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _InstructionRow extends StatelessWidget {
  const _InstructionRow({required this.task, this.onRemove});

  final DemoTask task;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: HoverLift(
      child: AppCard(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFFCCFBF1), Color(0xFFF0FDFA)],
                ),
                borderRadius: BorderRadius.circular(AppRadii.xl),
              ),
              child: Icon(task.icon, size: 20, color: AppColors.primary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    task.title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  if (task.note.trim().isNotEmpty) ...[
                    const SizedBox(height: 5),
                    Text(
                      task.note,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.muted,
                        height: 1.4,
                      ),
                    ),
                  ],
                  if (task.time.trim().isNotEmpty) ...[
                    const SizedBox(height: 9),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.schedule_outlined,
                            size: 13,
                            color: AppColors.muted,
                          ),
                          const SizedBox(width: 5),
                          Flexible(
                            child: Text(
                              task.time,
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppColors.muted,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                StatusBadge(status: task.status),
                if (onRemove != null) ...[
                  const SizedBox(height: 6),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    onPressed: onRemove,
                    icon: const Icon(Icons.delete_outline_rounded, size: 18),
                    tooltip: context.tr('remove'),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    ),
  );
}

class _ScheduleRow extends StatelessWidget {
  const _ScheduleRow({
    required this.task,
    required this.period,
    required this.displayTime,
    required this.periodChanged,
    required this.onEditPeriod,
    required this.onSetTime,
  });

  final DemoTask task;
  final String period;
  final String displayTime;
  final bool periodChanged;
  final VoidCallback onEditPeriod;
  final VoidCallback onSetTime;

  String? _formattedTime(String value) {
    final match = RegExp(
      r'(\d{1,2}):(\d{2})\s*(AM|PM)?',
      caseSensitive: false,
    ).firstMatch(value.trim());

    if (match == null) return null;

    var hour = int.tryParse(match.group(1)!);
    final minute = int.tryParse(match.group(2)!);
    final suffixFromValue = match.group(3)?.toUpperCase();

    if (hour == null || minute == null || minute > 59) return null;

    if (suffixFromValue != null) {
      if (hour < 1 || hour > 12) return null;
      if (suffixFromValue == 'PM' && hour != 12) {
        hour += 12;
      } else if (suffixFromValue == 'AM' && hour == 12) {
        hour = 0;
      }
    } else if (hour > 23) {
      return null;
    }

    final suffix = hour >= 12 ? 'PM' : 'AM';
    final displayHour = hour % 12 == 0 ? 12 : hour % 12;
    return '$displayHour:${minute.toString().padLeft(2, '0')} $suffix';
  }

  IconData _periodIcon() => switch (period) {
    'Morning' => Icons.wb_sunny_outlined,
    'Afternoon' => Icons.light_mode_outlined,
    'Evening' => Icons.wb_twilight_outlined,
    'Night' => Icons.nightlight_outlined,
    _ => Icons.schedule_outlined,
  };

  Widget _infoChip({
    required IconData icon,
    required String label,
    bool warning = false,
  }) {
    final background = warning ? AppColors.warningSoft : AppColors.primaryLight;
    final foreground = warning
        ? AppColors.warningForeground
        : AppColors.primary;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: foreground),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: foreground,
            ),
          ),
        ],
      ),
    );
  }

  Widget _actionButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
    bool primary = false,
  }) {
    if (primary) {
      return FilledButton.tonalIcon(
        onPressed: onPressed,
        icon: Icon(icon, size: 17),
        label: Text(label),
        style: FilledButton.styleFrom(
          minimumSize: const Size(0, 46),
          padding: const EdgeInsets.symmetric(horizontal: 14),
        ),
      );
    }

    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 17),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(0, 46),
        padding: const EdgeInsets.symmetric(horizontal: 14),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final formattedTime = _formattedTime(displayTime);
    final note = task.note.toLowerCase();
    final hasVerifiedExactReason =
        note.contains('exact clock time') &&
        note.contains('verified instruction');
    final exactTimeLocked =
        formattedTime != null &&
        (task.timeLocked ||
            task.grounding.trim().toLowerCase() == 'explicit' ||
            hasVerifiedExactReason);
    final needsTime =
        !exactTimeLocked &&
        (task.status == TaskStatus.atRisk ||
            periodChanged ||
            formattedTime == null);

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: HoverLift(
        child: AppCard(
          padding: const EdgeInsets.all(18),
          borderColor: needsTime
              ? AppColors.warning.withValues(alpha: .22)
              : AppColors.border,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: AppColors.primaryLight,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    alignment: Alignment.center,
                    child: Icon(task.icon, size: 21, color: AppColors.primary),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          task.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 16,
                            height: 1.25,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        if (task.note.trim().isNotEmpty) ...[
                          const SizedBox(height: 5),
                          Text(
                            task.note,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 13,
                              height: 1.35,
                              color: AppColors.muted,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _infoChip(
                    icon: _periodIcon(),
                    label: _localizedPeriod(context, period),
                  ),
                  _infoChip(
                    icon: needsTime
                        ? Icons.schedule_outlined
                        : Icons.alarm_outlined,
                    label: needsTime
                        ? context.tr('cpd_choose_exact_time')
                        : formattedTime,
                    warning: needsTime,
                  ),
                ],
              ),
              if (exactTimeLocked) ...[
                const SizedBox(height: 10),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.lock_outline,
                      size: 16,
                      color: AppColors.primary,
                    ),
                    const SizedBox(width: 7),
                    Expanded(
                      child: Text(
                        context.tr('cpd_exact_time_locked_note'),
                        style: const TextStyle(
                          fontSize: 12,
                          height: 1.35,
                          color: AppColors.muted,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
              if (periodChanged) ...[
                const SizedBox(height: 10),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.info_outline,
                      size: 16,
                      color: AppColors.warningForeground,
                    ),
                    const SizedBox(width: 7),
                    Expanded(
                      child: Text(
                        context.tr('cpd_period_changed_note'),
                        style: const TextStyle(
                          fontSize: 12,
                          height: 1.35,
                          color: AppColors.warningForeground,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 16),
              Container(height: 1, color: AppColors.border),
              const SizedBox(height: 14),
              if (exactTimeLocked)
                Container(
                  height: 46,
                  decoration: BoxDecoration(
                    border: Border.all(color: AppColors.border),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  alignment: Alignment.center,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.lock_outline,
                        size: 17,
                        color: AppColors.muted,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        context.tr('cpd_verified_exact_time'),
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                )
              else
                LayoutBuilder(
                  builder: (context, constraints) {
                    final stackActions = constraints.maxWidth < 300;
                    final editPeriod = _actionButton(
                      icon: Icons.edit_outlined,
                      label: context.tr('cpd_edit_period'),
                      onPressed: onEditPeriod,
                    );
                    final editTime = _actionButton(
                      icon: Icons.schedule_outlined,
                      label: needsTime
                          ? context.tr('cpd_set_time')
                          : context.tr('cpd_edit_time'),
                      onPressed: onSetTime,
                      primary: needsTime,
                    );

                    if (stackActions) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          editPeriod,
                          const SizedBox(height: 8),
                          editTime,
                        ],
                      );
                    }

                    return Row(
                      children: [
                        Expanded(child: editPeriod),
                        const SizedBox(width: 10),
                        Expanded(child: editTime),
                      ],
                    );
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }
}
