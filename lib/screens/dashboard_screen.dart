import 'package:flutter/material.dart';

import '../core/app_routes.dart';
import '../core/app_theme.dart';
import '../data/demo_data.dart';
import '../localization/language_scope.dart';
import '../services/auth_service.dart';
import '../services/care_plan_service.dart';
import '../services/care_reliability_service.dart';
import '../widgets/app_shell.dart';
import '../widgets/page_header.dart';
import '../widgets/ui.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with WidgetsBindingObserver {
  bool loading = true;
  String? error;
  List<DemoPlan> plans = const [];
  CareTaskAppDayData? today;
  DemoPlan? setupPlan;
  CareSetupProgress? setupProgress;
  RoutineProfileData? routineProfile;
  final Set<String> savingIds = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    CareReliabilityService.instance.start();
    if (AuthSession.instance.isGuest) {
      loading = false;
    } else {
      _load();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed &&
        !AuthSession.instance.isGuest &&
        !loading) {
      CareReliabilityService.instance.onAppResumed();
      _load();
    }
  }

  Future<void> _load() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final loadedPlans = await CarePlanService.instance.fetchPlans();
      final loadedToday = await CarePlanService.instance
          .fetchAllTaskOccurrences();

      RoutineProfileData? loadedRoutineProfile;
      try {
        loadedRoutineProfile = await CarePlanService.instance
            .fetchRoutineProfile();
      } on CarePlanException {
        // Routine intelligence is helpful but must never block today's care UI.
      }

      DemoPlan? pendingPlan;
      CareSetupProgress? pendingProgress;
      for (final plan in loadedPlans) {
        if (plan.status == PlanStatus.active ||
            plan.status == PlanStatus.completed) {
          continue;
        }
        final progress = await CarePlanService.instance.resolveSetupProgress(
          plan,
        );
        if (progress.step != CareSetupStep.complete) {
          pendingPlan = plan;
          pendingProgress = progress;
          break;
        }
      }

      if (!mounted) return;
      setState(() {
        plans = loadedPlans;
        today = loadedToday;
        setupPlan = pendingPlan;
        setupProgress = pendingProgress;
        routineProfile = loadedRoutineProfile;
        loading = false;
      });
    } on CarePlanException catch (exception) {
      if (!mounted) return;
      setState(() {
        loading = false;
        error = exception.message;
      });
    }
  }

  Future<void> _setOutcome(CareTaskOccurrence occurrence, String status) async {
    setState(() => savingIds.add(occurrence.id));
    try {
      final result = await CareReliabilityService.instance.setOutcome(
        occurrence,
        status,
      );
      if (!mounted) return;

      final current = today;
      if (current != null) {
        final items = current.occurrences
            .map((item) => item.id == occurrence.id ? result.occurrence : item)
            .toList();
        setState(() {
          today = CareTaskAppDayData(
            date: current.date,
            occurrences: items,
            summary: _summaryForDashboard(items, current.summary),
          );
        });
      }

      if (result.queued) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.tr('dashboard_saved_offline'))),
        );
      } else if (result.conflictRecovered) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.tr('dashboard_conflict_restored'))),
        );
      }
    } on CarePlanException catch (exception) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(exception.message)));
      }
    } finally {
      if (mounted) setState(() => savingIds.remove(occurrence.id));
    }
  }

  CareTaskAppDaySummary _summaryForDashboard(
    List<CareTaskOccurrence> items,
    CareTaskAppDaySummary previous,
  ) {
    var completed = 0;
    var skipped = 0;
    var missed = 0;
    var pending = 0;
    for (final item in items) {
      if (item.completed) {
        completed += 1;
      } else if (item.skipped) {
        skipped += 1;
      } else if (item.missed) {
        missed += 1;
      } else {
        pending += 1;
      }
    }
    return CareTaskAppDaySummary(
      total: items.length,
      completed: completed,
      skipped: skipped,
      missed: missed,
      pending: pending,
      activePlans: previous.activePlans,
      openCareGaps: previous.openCareGaps,
      careReadiness: previous.careReadiness,
    );
  }

  void _resumeSetup() {
    final plan = setupPlan;
    final progress = setupProgress;
    if (plan == null || progress == null) return;

    switch (progress.step) {
      case CareSetupStep.upload:
        Navigator.pushNamed(
          context,
          AppRoutes.carePlanUpload,
          arguments: CarePlanUploadArgs(
            planId: plan.id,
            documentTypes: const [],
            guidedSetup: true,
          ),
        );
        return;
      case CareSetupStep.review:
        Navigator.pushNamed(
          context,
          AppRoutes.carePlanReview,
          arguments: CarePlanReviewArgs(planId: plan.id, guidedSetup: true),
        );
        return;
      case CareSetupStep.schedule:
        Navigator.pushNamed(
          context,
          AppRoutes.carePlan(plan.id),
          arguments: const CarePlanDetailArgs(initialTab: 1, guidedSetup: true),
        );
        return;
      case CareSetupStep.realityCheck:
        Navigator.pushNamed(
          context,
          AppRoutes.realityCheck,
          arguments: CareFlowArgs(planId: plan.id, guidedSetup: true),
        );
        return;
      case CareSetupStep.simulation:
      case CareSetupStep.activate:
        Navigator.pushNamed(
          context,
          AppRoutes.simulation,
          arguments: CareFlowArgs(planId: plan.id, guidedSetup: true),
        );
        return;
      case CareSetupStep.careGaps:
        Navigator.pushNamed(context, AppRoutes.careGaps);
        return;
      case CareSetupStep.complete:
        Navigator.pushNamed(context, AppRoutes.carePlan(plan.id));
        return;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (AuthSession.instance.isGuest) return _guestDashboard();

    final name = AuthSession.instance.user?.name.trim() ?? '';
    final firstName = name.isEmpty
        ? context.tr('there')
        : name.split(RegExp(r'\s+')).first;
    final hour = DateTime.now().hour;
    final greeting = context.tr(
      hour < 12
          ? 'good_morning'
          : hour < 17
          ? 'good_afternoon'
          : 'good_evening',
    );
    final greetingText = context.tr(
      'greeting_name',
      values: {'greeting': greeting, 'name': firstName},
    );
    final overviewText = context.tr('dashboard_overview_today');

    return AppShell(
      currentRoute: AppRoutes.dashboard,
      title: greetingText,
      subtitle: overviewText,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          FadeSlideIn(child: _dashboardHero(greetingText, overviewText)),
          const SizedBox(height: 16),
          _syncBanner(),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 260),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            child: loading
                ? FadeSlideIn(
                    key: const ValueKey('dashboard-loading'),
                    delay: const Duration(milliseconds: 40),
                    child: _loadingSkeleton(),
                  )
                : error != null
                ? FadeSlideIn(
                    key: const ValueKey('dashboard-error'),
                    delay: const Duration(milliseconds: 40),
                    child: AppCard(
                      color: const Color(0xFFFFFBEB),
                      borderColor: const Color(0xFFFDE68A),
                      child: Column(
                        children: [
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: AppColors.warningSoft,
                              borderRadius: BorderRadius.circular(AppRadii.xl),
                            ),
                            child: const Icon(
                              Icons.cloud_off_outlined,
                              color: AppColors.warningForeground,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            error!,
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 14, height: 1.45),
                          ),
                          const SizedBox(height: 14),
                          OutlinedButton.icon(
                            onPressed: _load,
                            icon: const Icon(Icons.refresh, size: 18),
                            label: Text(context.tr('retry')),
                          ),
                        ],
                      ),
                    ),
                  )
                : Column(
                    key: const ValueKey('dashboard-content'),
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (setupPlan != null && setupProgress != null) ...[
                        FadeSlideIn(
                          delay: const Duration(milliseconds: 40),
                          child: _setupCard(),
                        ),
                        const SizedBox(height: 18),
                      ],
                      FadeSlideIn(
                        delay: const Duration(milliseconds: 80),
                        child: _metrics(),
                      ),
                      if (_smartRoutineInsight() != null) ...[
                        const SizedBox(height: 18),
                        FadeSlideIn(
                          delay: const Duration(milliseconds: 120),
                          child: _smartRoutineInsight()!,
                        ),
                      ],
                      const SizedBox(height: 24),
                      FadeSlideIn(
                        delay: const Duration(milliseconds: 160),
                        child: _todayTasks(),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _dashboardHero(String greetingText, String overviewText) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 620;

        return Container(
          padding: EdgeInsets.all(compact ? 20 : 24),
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
                blurRadius: 28,
                spreadRadius: -10,
                offset: Offset(0, 14),
              ),
            ],
          ),
          child: Stack(
            children: [
              PositionedDirectional(
                top: -46,
                end: -32,
                child: Container(
                  width: 140,
                  height: 140,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Color(0x1FFFFFFF),
                  ),
                ),
              ),
              PositionedDirectional(
                bottom: -62,
                start: -42,
                child: Container(
                  width: 150,
                  height: 150,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Color(0x12FFFFFF),
                  ),
                ),
              ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0x22FFFFFF),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(color: const Color(0x33FFFFFF)),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.favorite_rounded,
                                size: 15,
                                color: Colors.white,
                              ),
                              SizedBox(width: 6),
                              Text(
                                'SehatMate',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: .2,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          greetingText,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: compact ? 26 : 32,
                            height: 1.08,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -.5,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          overviewText,
                          style: const TextStyle(
                            color: Color(0xE6FFFFFF),
                            fontSize: 14,
                            height: 1.45,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  if (compact)
                    Material(
                      color: const Color(0x26FFFFFF),
                      borderRadius: BorderRadius.circular(AppRadii.xl),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(AppRadii.xl),
                        onTap: () =>
                            Navigator.pushNamed(context, AppRoutes.carePlanNew),
                        child: const SizedBox(
                          width: 48,
                          height: 48,
                          child: Icon(
                            Icons.add_rounded,
                            color: Colors.white,
                            size: 26,
                          ),
                        ),
                      ),
                    )
                  else
                    FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: AppColors.primaryDark,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 14,
                        ),
                      ),
                      onPressed: () =>
                          Navigator.pushNamed(context, AppRoutes.carePlanNew),
                      icon: const Icon(Icons.upload_outlined, size: 19),
                      label: Text(context.tr('upload_new_care_plan')),
                    ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _loadingSkeleton() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final columns = constraints.maxWidth >= 760 ? 4 : 2;
            const gap = 12.0;
            final width =
                (constraints.maxWidth - ((columns - 1) * gap)) / columns;

            return Wrap(
              spacing: gap,
              runSpacing: gap,
              children: List.generate(
                4,
                (index) => SizedBox(
                  width: width,
                  child: AppCard(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _skeletonBar(width: 74, height: 12),
                        const SizedBox(height: 14),
                        _skeletonBar(width: 58, height: 28),
                        const SizedBox(height: 8),
                        _skeletonBar(width: 96, height: 10),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 24),
        AppCard(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _skeletonBar(width: 145, height: 18),
              const SizedBox(height: 8),
              _skeletonBar(width: 220, height: 11),
              const SizedBox(height: 20),
              _skeletonBar(width: double.infinity, height: 70),
              const SizedBox(height: 10),
              _skeletonBar(width: double.infinity, height: 70),
            ],
          ),
        ),
      ],
    );
  }

  Widget _skeletonBar({required double width, required double height}) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: const Color(0xFFE8EEF2),
        borderRadius: BorderRadius.circular(999),
      ),
    );
  }

  Widget _syncBanner() {
    return AnimatedBuilder(
      animation: CareReliabilityService.instance,
      builder: (context, _) {
        final sync = CareReliabilityService.instance;
        if (sync.online && sync.pendingCount == 0 && !sync.syncing) {
          return const SizedBox.shrink();
        }

        final message = !sync.online
            ? sync.pendingCount > 0
                  ? context.tr(
                      'dashboard_offline_changes_waiting',
                      values: {'count': sync.pendingCount},
                    )
                  : context.tr('dashboard_offline_saved_data')
            : sync.syncing
            ? context.tr('dashboard_syncing')
            : context.tr(
                'dashboard_changes_waiting',
                values: {'count': sync.pendingCount},
              );

        return Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: AppCard(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            child: Row(
              children: [
                Icon(
                  sync.online ? Icons.sync_outlined : Icons.cloud_off_outlined,
                  size: 18,
                  color: AppColors.primary,
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(message, style: const TextStyle(fontSize: 13)),
                ),
                if (sync.online && sync.pendingCount > 0 && !sync.syncing)
                  TextButton(
                    onPressed: () => CareReliabilityService.instance.syncNow(),
                    child: Text(context.tr('sync_now')),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _setupCard() {
    final plan = setupPlan!;
    final progress = setupProgress!;
    final progressValue =
        progress.completedCount / CareSetupProgress.totalSteps;

    return HoverLift(
      cursor: SystemMouseCursors.click,
      child: AppCard(
        color: const Color(0xFFF0FDFA),
        borderColor: const Color(0xFF99F6E4),
        padding: const EdgeInsets.all(18),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final button = FilledButton.icon(
              onPressed: _resumeSetup,
              icon: const Icon(Icons.arrow_forward_rounded, size: 18),
              label: Text(context.tr('continue_setup')),
            );

            final content = Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: AppColors.primaryLight,
                    borderRadius: BorderRadius.circular(AppRadii.xl),
                  ),
                  child: const Icon(
                    Icons.route_outlined,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        context.tr('care_plan_setup_incomplete'),
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        plan.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 14,
                          color: AppColors.muted,
                        ),
                      ),
                      const SizedBox(height: 12),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(999),
                        child: LinearProgressIndicator(
                          value: progressValue.clamp(0.0, 1.0),
                          minHeight: 7,
                          backgroundColor: const Color(0xFFD5F5EF),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              context.tr(
                                'setup_progress_count',
                                values: {
                                  'completed': progress.completedCount,
                                  'total': CareSetupProgress.totalSteps,
                                },
                              ),
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                          Text(
                            context.tr(
                              'next_step',
                              values: {
                                'step': _setupStepTitle(context, progress.step),
                              },
                            ),
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.muted,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            );

            if (constraints.maxWidth < 560) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [content, const SizedBox(height: 16), button],
              );
            }

            return Row(
              children: [
                Expanded(child: content),
                const SizedBox(width: 18),
                button,
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _metrics() {
    final summary = today?.summary;
    final decided =
        (summary?.completed ?? 0) +
        (summary?.skipped ?? 0) +
        (summary?.missed ?? 0);
    final completionRate = decided == 0
        ? 0
        : (((summary?.completed ?? 0) / decided) * 100).round();

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 760 ? 4 : 2;
        const gap = 12.0;
        final width = (constraints.maxWidth - ((columns - 1) * gap)) / columns;

        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            _metricCard(
              width,
              context.tr('care_readiness'),
              '${summary?.careReadiness ?? 0}%',
              context.tr(
                'active_plans_count',
                values: {'count': summary?.activePlans ?? 0},
              ),
              () {
                final active = plans
                    .where((plan) => plan.status == PlanStatus.active)
                    .toList();
                if (active.isNotEmpty) {
                  Navigator.pushNamed(
                    context,
                    AppRoutes.carePlan(active.first.id),
                    arguments: const CarePlanDetailArgs(initialTab: 2),
                  );
                }
              },
              icon: Icons.favorite_border_rounded,
              accent: AppColors.primary,
              soft: AppColors.primaryLight,
            ),
            _metricCard(
              width,
              context.tr('today_tasks'),
              '${summary?.total ?? 0}',
              context.tr(
                'completed_count',
                values: {'count': summary?.completed ?? 0},
              ),
              () => Navigator.pushNamed(context, AppRoutes.calendar),
              icon: Icons.task_alt_rounded,
              accent: AppColors.info,
              soft: AppColors.infoSoft,
            ),
            _metricCard(
              width,
              context.tr('care_gaps'),
              '${summary?.openCareGaps ?? 0}',
              context.tr('current_unresolved'),
              () => Navigator.pushNamed(context, AppRoutes.careGaps),
              icon: Icons.health_and_safety_outlined,
              accent: AppColors.warning,
              soft: AppColors.warningSoft,
            ),
            _metricCard(
              width,
              context.tr('task_completion'),
              '$completionRate%',
              context.tr('decided_tasks_today'),
              () => Navigator.pushNamed(context, AppRoutes.progress),
              icon: Icons.insights_rounded,
              accent: AppColors.success,
              soft: AppColors.successSoft,
            ),
          ],
        );
      },
    );
  }

  Widget _metricCard(
    double width,
    String label,
    String value,
    String hint,
    VoidCallback onTap, {
    required IconData icon,
    required Color accent,
    required Color soft,
  }) {
    return SizedBox(
      width: width,
      child: HoverLift(
        cursor: SystemMouseCursors.click,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadii.xxl),
          child: AppCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: soft,
                        borderRadius: BorderRadius.circular(AppRadii.lg),
                      ),
                      child: Icon(icon, size: 19, color: accent),
                    ),
                    const Spacer(),
                    Icon(
                      Icons.arrow_outward_rounded,
                      size: 17,
                      color: AppColors.subtle,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.muted,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 220),
                  child: Text(
                    value,
                    key: ValueKey(value),
                    style: const TextStyle(
                      fontSize: 29,
                      height: 1.05,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -.4,
                    ),
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  hint,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.muted,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget? _smartRoutineInsight() {
    final profile = routineProfile;
    if (profile == null || !profile.learningEnabled) return null;

    const periods = ['morning', 'afternoon', 'evening', 'night'];
    MapEntry<String, RoutineLearnedPeriod>? best;

    for (final period in periods) {
      final learned = profile.learned[period];
      if (learned == null || learned.preferredTime.isEmpty) continue;
      if (best == null || learned.signalCount > best.value.signalCount) {
        best = MapEntry(period, learned);
      }
    }

    if (best == null) return null;
    final learned = best.value;
    final active = plans
        .where((plan) => plan.status == PlanStatus.active)
        .toList();

    return AppCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: AppColors.primaryLight,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.auto_awesome_outlined,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.tr('smart_routine_insight'),
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      context.tr(
                        'learned_preference_message',
                        values: {
                          'period': _localizedPeriod(context, best.key),
                          'time': _clock(learned.preferredTime),
                        },
                      ),
                      style: const TextStyle(height: 1.4),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      '${context.tr('routine_confidence_signals', values: {'confidence': learned.confidence, 'count': learned.signalCount})} ${learned.reason}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.muted,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (active.isNotEmpty) ...[
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () => Navigator.pushNamed(
                  context,
                  AppRoutes.carePlan(active.first.id),
                  arguments: const CarePlanDetailArgs(initialTab: 2),
                ),
                icon: const Icon(Icons.route_outlined, size: 17),
                label: Text(context.tr('review_with_adapt_my_plan')),
              ),
            ),
          ],
          SafetyNote(text: context.tr('routine_learning_safety_note')),
        ],
      ),
    );
  }

  Widget _todayTasks() {
    final value = today;
    return AppCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: AppColors.primaryLight,
                  borderRadius: BorderRadius.circular(AppRadii.xl),
                ),
                child: const Icon(
                  Icons.today_outlined,
                  color: AppColors.primary,
                  size: 21,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.tr('todays_care'),
                      style: const TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      context.tr('one_outcome_per_reminder'),
                      style: const TextStyle(
                        color: AppColors.muted,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              TextButton.icon(
                onPressed: () =>
                    Navigator.pushNamed(context, AppRoutes.calendar),
                icon: const Icon(Icons.calendar_month_outlined, size: 17),
                label: Text(context.tr('open_calendar')),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (value == null || value.occurrences.isEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 28),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(AppRadii.xl),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: AppColors.successSoft,
                      borderRadius: BorderRadius.circular(AppRadii.xl),
                    ),
                    child: const Icon(
                      Icons.check_circle_outline_rounded,
                      color: AppColors.success,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    context.tr('no_care_tasks_today'),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: AppColors.muted,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            )
          else
            for (var index = 0; index < value.occurrences.length; index++) ...[
              FadeSlideIn(
                delay: Duration(milliseconds: 35 * index.clamp(0, 5)),
                child: _todayRow(value.occurrences[index]),
              ),
              if (index != value.occurrences.length - 1)
                const SizedBox(height: 10),
            ],
        ],
      ),
    );
  }

  Widget _todayRow(CareTaskOccurrence occurrence) {
    final saving = savingIds.contains(occurrence.id);

    final Color statusColor = occurrence.completed
        ? AppColors.successForeground
        : occurrence.missed || occurrence.overdue
        ? AppColors.criticalForeground
        : occurrence.skipped
        ? AppColors.warningForeground
        : AppColors.muted;

    final Color statusSoft = occurrence.completed
        ? AppColors.successSoft
        : occurrence.missed || occurrence.overdue
        ? AppColors.criticalSoft
        : occurrence.skipped
        ? AppColors.warningSoft
        : const Color(0xFFF1F5F9);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: occurrence.completed
            ? const Color(0xFFFBFFFC)
            : const Color(0xFFFAFCFD),
        borderRadius: BorderRadius.circular(AppRadii.xl),
        border: Border.all(
          color: occurrence.completed
              ? const Color(0xFFBBF7D0)
              : AppColors.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: statusSoft,
                  borderRadius: BorderRadius.circular(AppRadii.lg),
                ),
                child: Icon(
                  occurrence.completed
                      ? Icons.check_rounded
                      : Icons.medication_outlined,
                  color: statusColor == AppColors.muted
                      ? AppColors.primary
                      : statusColor,
                  size: 20,
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      occurrence.title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                    if (occurrence.planTitle.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        occurrence.planTitle,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.muted,
                        ),
                      ),
                    ],
                    const SizedBox(height: 5),
                    Row(
                      children: [
                        const Icon(
                          Icons.schedule_outlined,
                          size: 14,
                          color: AppColors.subtle,
                        ),
                        const SizedBox(width: 5),
                        Expanded(
                          child: Text(
                            '${_clock(occurrence.scheduledTime)}'
                            '${occurrence.period.isEmpty ? '' : ' · ${_localizedPeriod(context, occurrence.period)}'}',
                            style: const TextStyle(
                              color: AppColors.muted,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                decoration: BoxDecoration(
                  color: statusSoft,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  _statusLabelFor(context, occurrence),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: statusColor,
                  ),
                ),
              ),
            ],
          ),
          if (!occurrence.missed) ...[
            const SizedBox(height: 12),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: saving
                  ? const ClipRRect(
                      key: ValueKey('saving'),
                      borderRadius: BorderRadius.all(Radius.circular(999)),
                      child: LinearProgressIndicator(minHeight: 4),
                    )
                  : Wrap(
                      key: ValueKey('${occurrence.id}-${occurrence.status}'),
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        if (!occurrence.completed)
                          FilledButton.icon(
                            onPressed: () =>
                                _setOutcome(occurrence, 'completed'),
                            icon: const Icon(
                              Icons.check_circle_outline,
                              size: 17,
                            ),
                            label: Text(context.tr('complete')),
                          ),
                        if (occurrence.pending)
                          OutlinedButton(
                            onPressed: () => _setOutcome(occurrence, 'skipped'),
                            child: Text(context.tr('record_skipped')),
                          ),
                        if (occurrence.completed || occurrence.skipped)
                          TextButton.icon(
                            onPressed: () => _setOutcome(occurrence, 'pending'),
                            icon: const Icon(Icons.undo, size: 16),
                            label: Text(context.tr('undo')),
                          ),
                      ],
                    ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _guestDashboard() {
    final state = CareDemoState.instance;
    return AppShell(
      currentRoute: AppRoutes.dashboard,
      title: context.tr('dashboard'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PageHeader(
            title: context.tr('guest_dashboard'),
            subtitle: context.tr('guest_dashboard_subtitle'),
          ),
          AppCard(
            child: Column(
              children: [
                Text(
                  context.tr(
                    'demo_tasks_count',
                    values: {'count': state.tasks.length},
                  ),
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: () => Navigator.pushNamed(context, AppRoutes.auth),
                  child: Text(context.tr('sign_in')),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _statusLabelFor(BuildContext context, CareTaskOccurrence occurrence) {
    if (occurrence.overdue) return context.tr('overdue');
    return switch (occurrence.status) {
      'completed' => context.tr('completed'),
      'skipped' => context.tr('skipped'),
      'missed' => context.tr('missed'),
      _ => context.tr('upcoming'),
    };
  }

  String _localizedPeriod(BuildContext context, String value) {
    return switch (value.trim().toLowerCase()) {
      'morning' => context.tr('morning'),
      'afternoon' => context.tr('afternoon'),
      'evening' => context.tr('evening'),
      'night' => context.tr('night'),
      _ => _titleCase(value),
    };
  }

  String _setupStepTitle(BuildContext context, CareSetupStep step) {
    return switch (step) {
      CareSetupStep.upload => context.tr('setup_step_upload'),
      CareSetupStep.review => context.tr('setup_step_review'),
      CareSetupStep.schedule => context.tr('setup_step_schedule'),
      CareSetupStep.realityCheck => context.tr('setup_step_reality'),
      CareSetupStep.simulation => context.tr('setup_step_simulation'),
      CareSetupStep.careGaps => context.tr('setup_step_care_gaps'),
      CareSetupStep.activate => context.tr('setup_step_activate'),
      CareSetupStep.complete => context.tr('setup_step_complete'),
    };
  }

  String _titleCase(String value) => value.isEmpty
      ? value
      : '${value.substring(0, 1).toUpperCase()}${value.substring(1)}';

  String _clock(String value) {
    final match = RegExp(r'^(\d{1,2}):(\d{2})').firstMatch(value);
    if (match == null) return value;
    final hour = int.tryParse(match.group(1)!) ?? 0;
    final minute = match.group(2)!;
    final suffix = hour >= 12 ? 'PM' : 'AM';
    final displayHour = hour % 12 == 0 ? 12 : hour % 12;
    return '$displayHour:$minute $suffix';
  }
}
