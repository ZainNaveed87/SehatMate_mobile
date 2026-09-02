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
      final loadedToday =
          await CarePlanService.instance.fetchAllTaskOccurrences();

      RoutineProfileData? loadedRoutineProfile;
      try {
        loadedRoutineProfile =
            await CarePlanService.instance.fetchRoutineProfile();
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
        final progress =
            await CarePlanService.instance.resolveSetupProgress(plan);
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

  Future<void> _setOutcome(
    CareTaskOccurrence occurrence,
    String status,
  ) async {
    setState(() => savingIds.add(occurrence.id));
    try {
      final result =
          await CareReliabilityService.instance.setOutcome(
        occurrence,
        status,
      );
      if (!mounted) return;

      final current = today;
      if (current != null) {
        final items = current.occurrences
            .map(
              (item) => item.id == occurrence.id
                  ? result.occurrence
                  : item,
            )
            .toList();
        setState(() {
          today = CareTaskAppDayData(
            date: current.date,
            occurrences: items,
            summary: _summaryForDashboard(
              items,
              current.summary,
            ),
          );
        });
      }

      if (result.queued) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.tr('dashboard_saved_offline')),
          ),
        );
      } else if (result.conflictRecovered) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.tr('dashboard_conflict_restored')),
          ),
        );
      }
    } on CarePlanException catch (exception) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(exception.message)),
        );
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
          arguments: CarePlanReviewArgs(
            planId: plan.id,
            guidedSetup: true,
          ),
        );
        return;
      case CareSetupStep.schedule:
        Navigator.pushNamed(
          context,
          AppRoutes.carePlan(plan.id),
          arguments: const CarePlanDetailArgs(
            initialTab: 1,
            guidedSetup: true,
          ),
        );
        return;
      case CareSetupStep.realityCheck:
        Navigator.pushNamed(
          context,
          AppRoutes.realityCheck,
          arguments: CareFlowArgs(
            planId: plan.id,
            guidedSetup: true,
          ),
        );
        return;
      case CareSetupStep.simulation:
      case CareSetupStep.activate:
        Navigator.pushNamed(
          context,
          AppRoutes.simulation,
          arguments: CareFlowArgs(
            planId: plan.id,
            guidedSetup: true,
          ),
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
      values: {
        'greeting': greeting,
        'name': firstName,
      },
    );
    final overviewText = context.tr('dashboard_overview_today');

    return AppShell(
      currentRoute: AppRoutes.dashboard,
      title: greetingText,
      subtitle: overviewText,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PageHeader(
            title: greetingText,
            subtitle: overviewText,
            action: IconButton.filled(
              onPressed: () =>
                  Navigator.pushNamed(context, AppRoutes.carePlanNew),
              icon: const Icon(Icons.upload_outlined),
              tooltip: context.tr('upload_new_care_plan'),
            ),
          ),
          _syncBanner(),
          if (loading)
            const AppCard(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator()),
              ),
            )
          else if (error != null)
            AppCard(
              child: Column(
                children: [
                  const Icon(Icons.cloud_off_outlined, size: 32),
                  const SizedBox(height: 10),
                  Text(error!, textAlign: TextAlign.center),
                  const SizedBox(height: 14),
                  OutlinedButton(
                    onPressed: _load,
                    child: Text(context.tr('retry')),
                  ),
                ],
              ),
            )
          else ...[
            if (setupPlan != null && setupProgress != null) ...[
              _setupCard(),
              const SizedBox(height: 18),
            ],
            _metrics(),
            if (_smartRoutineInsight() != null) ...[
              const SizedBox(height: 18),
              _smartRoutineInsight()!,
            ],
            const SizedBox(height: 24),
            _todayTasks(),
          ],
        ],
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
            padding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 11,
            ),
            child: Row(
              children: [
                Icon(
                  sync.online
                      ? Icons.sync_outlined
                      : Icons.cloud_off_outlined,
                  size: 18,
                  color: AppColors.primary,
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(
                    message,
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
                if (sync.online && sync.pendingCount > 0 && !sync.syncing)
                  TextButton(
                    onPressed: () =>
                        CareReliabilityService.instance.syncNow(),
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
    return AppCard(
      padding: const EdgeInsets.all(18),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final button = FilledButton(
            onPressed: _resumeSetup,
            child: Text(context.tr('continue_setup')),
          );
          final content = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                context.tr('care_plan_setup_incomplete'),
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                plan.title,
                style: const TextStyle(
                  fontSize: 15,
                  color: AppColors.muted,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                context.tr(
                  'setup_progress_count',
                  values: {
                    'completed': progress.completedCount,
                    'total': CareSetupProgress.totalSteps,
                  },
                ),
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                context.tr(
                  'next_step',
                  values: {'step': _setupStepTitle(context, progress.step)},
                ),
                style: const TextStyle(color: AppColors.muted),
              ),
            ],
          );

          if (constraints.maxWidth < 520) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                content,
                const SizedBox(height: 14),
                button,
              ],
            );
          }
          return Row(
            children: [
              Expanded(child: content),
              const SizedBox(width: 16),
              button,
            ],
          );
        },
      ),
    );
  }

  Widget _metrics() {
    final summary = today?.summary;
    final decided = (summary?.completed ?? 0) +
        (summary?.skipped ?? 0) +
        (summary?.missed ?? 0);
    final completionRate = decided == 0
        ? 0
        : (((summary?.completed ?? 0) / decided) * 100).round();

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 760 ? 4 : 2;
        const gap = 12.0;
        final width =
            (constraints.maxWidth - ((columns - 1) * gap)) / columns;
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
            ),
            _metricCard(
              width,
              context.tr('care_gaps'),
              '${summary?.openCareGaps ?? 0}',
              context.tr('current_unresolved'),
              () => Navigator.pushNamed(context, AppRoutes.careGaps),
            ),
            _metricCard(
              width,
              context.tr('task_completion'),
              '$completionRate%',
              context.tr('decided_tasks_today'),
              () => Navigator.pushNamed(context, AppRoutes.progress),
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
    VoidCallback onTap,
  ) {
    return SizedBox(
      width: width,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: AppCard(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(color: AppColors.muted)),
              const SizedBox(height: 8),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                hint,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.muted,
                ),
              ),
            ],
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
      if (best == null ||
          learned.signalCount > best.value.signalCount) {
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
                      '${context.tr(
                        'routine_confidence_signals',
                        values: {
                          'confidence': learned.confidence,
                          'count': learned.signalCount,
                        },
                      )} ${learned.reason}',
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
          SafetyNote(
            text: context.tr('routine_learning_safety_note'),
          ),
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
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.tr('todays_care'),
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      context.tr('one_outcome_per_reminder'),
                      style: const TextStyle(
                        color: AppColors.muted,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              TextButton(
                onPressed: () =>
                    Navigator.pushNamed(context, AppRoutes.calendar),
                child: Text(context.tr('open_calendar')),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (value == null || value.occurrences.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Text(
                context.tr('no_care_tasks_today'),
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.muted),
              ),
            )
          else
            ...value.occurrences.map(
              (occurrence) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _todayRow(occurrence),
              ),
            ),
        ],
      ),
    );
  }

  Widget _todayRow(CareTaskOccurrence occurrence) {
    final saving = savingIds.contains(occurrence.id);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.secondary,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.checklist_outlined,
                color: AppColors.primary,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      occurrence.title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (occurrence.planTitle.isNotEmpty)
                      Text(
                        occurrence.planTitle,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.muted,
                        ),
                      ),
                    const SizedBox(height: 3),
                    Text(
                      '${_clock(occurrence.scheduledTime)}'
                      '${occurrence.period.isEmpty ? '' : ' · ${_localizedPeriod(context, occurrence.period)}'}',
                      style: const TextStyle(
                        color: AppColors.muted,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                _statusLabelFor(context, occurrence),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: occurrence.completed
                      ? AppColors.successForeground
                      : (occurrence.missed || occurrence.overdue)
                          ? AppColors.criticalForeground
                          : AppColors.muted,
                ),
              ),
            ],
          ),
          if (!occurrence.missed) ...[
            const SizedBox(height: 10),
            if (saving)
              const LinearProgressIndicator(minHeight: 3)
            else
              Wrap(
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
                      onPressed: () =>
                          _setOutcome(occurrence, 'skipped'),
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
                  onPressed: () =>
                      Navigator.pushNamed(context, AppRoutes.auth),
                  child: Text(context.tr('sign_in')),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _statusLabelFor(
    BuildContext context,
    CareTaskOccurrence occurrence,
  ) {
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

  String _setupStepTitle(
    BuildContext context,
    CareSetupStep step,
  ) {
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
