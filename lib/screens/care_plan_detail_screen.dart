import 'package:flutter/material.dart';

import '../core/app_routes.dart';
import '../core/app_theme.dart';
import '../data/demo_data.dart';
import '../localization/language_scope.dart';
import '../localization/localized_errors.dart';
import '../services/auth_service.dart';
import '../services/care_plan_service.dart';
import '../services/care_reliability_service.dart';
import '../services/notification_service.dart';
import '../widgets/app_shell.dart';
import '../widgets/care_setup_progress.dart';
import '../widgets/page_header.dart';
import '../widgets/status_badge.dart';
import '../widgets/ui.dart';
import 'simulation_screen.dart';

class CarePlanDetailScreen extends StatefulWidget {
  const CarePlanDetailScreen({
    required this.planId,
    this.initialTab = 0,
    this.guidedSetup = false,
    this.returnToPrevious = false,
    super.key,
  });

  final String planId;
  final int initialTab;
  final bool guidedSetup;
  final bool returnToPrevious;

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
      final detail = await CarePlanService.instance.fetchPlanDetail(widget.planId);
      var occurrences = const <CareTaskOccurrence>[];
      CareTaskDaySummary? daySummary;
      if (detail.plan.status == PlanStatus.active ||
          detail.plan.status == PlanStatus.completed) {
        try {
          final day = await CarePlanService.instance.fetchTaskOccurrences(widget.planId);
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
    return AnimatedBuilder(
      animation: CareDemoState.instance,
      builder: (context, _) => AppShell(
      currentRoute: AppRoutes.carePlan(plan.id),
      title: context.tr('care_plan'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Align(
            alignment: Alignment.centerLeft,
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
              icon: const Icon(Icons.arrow_back, size: 17),
              label: Text(
                widget.guidedSetup && tab == 1
                    ? context.tr('back_to_review')
                    : widget.returnToPrevious
                        ? context.tr('back')
                        : context.tr('care_plans'),
              ),
            ),
          ),
          PageHeader(
            title: demoPlanTitle(plan, context.appLanguage),
            subtitle: context.tr('care_plan_header_subtitle', values: {'date': displayPlanStartDate(plan.startDate, context.appLanguage), 'next': demoPlanNextTask(plan, context.appLanguage)}),
            action: PlanStatusBadge(status: plan.status),
          ),
          if (!widget.guidedSetup &&
              !AuthSession.instance.isGuest &&
              (plan.status == PlanStatus.active ||
                  plan.status == PlanStatus.completed)) ...[
            const SizedBox(height: 12),
            _planLifecycleActions(plan),
          ],
          if (widget.guidedSetup) ...[
            GuidedCareSetupProgress(
              currentStep: 3,
              planId: widget.planId,
              saveState: _scheduleSaveState,
            ),
            const SizedBox(height: 16),
          ],
          AppCard(
            child: Column(
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(child: Text(context.tr('care_readiness'), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500))),
                    Text('${plan.readiness}%', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: AppColors.primary)),
                  ],
                ),
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(99),
                  child: LinearProgressIndicator(value: plan.readiness / 100, minHeight: 10, color: AppColors.primary, backgroundColor: AppColors.secondary),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          if (!widget.guidedSetup) ...[
            Align(
              alignment: Alignment.centerLeft,
              child: AppTabs<int>(
                tabs: [
                  AppTab(0, context.tr('instructions')),
                  AppTab(1, context.tr('schedule')),
                  AppTab(2, context.tr('simulation')),
                  AppTab(3, context.tr('care_gaps')),
                  AppTab(4, context.tr('documents')),
                ],
                selected: tab,
                onChanged: (value) => setState(() => tab = value),
              ),
            ),
            const SizedBox(height: 20),
          ],
          _tabContent(detail),
          const SizedBox(height: 32),
          SafetyNote(text: context.tr('care_plan_detail_safety_note')),
        ],
      ),
      ),
    );
  }

  Widget _planLifecycleActions(DemoPlan plan) {
    final completed = plan.status == PlanStatus.completed;

    return AppCard(
      padding: const EdgeInsets.all(16),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final explanation = completed
              ? context.tr('completed_plan_reactivate_explanation')
              : context.tr('active_plan_complete_explanation');

          final text = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                completed ? context.tr('plan_completed') : context.tr('plan_actions'),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
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
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.restart_alt_outlined, size: 18),
                  label: Text(
                    _lifecycleSaving ? context.tr('reactivating') : context.tr('reactivate_plan'),
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
                    _lifecycleSaving ? context.tr('completing') : context.tr('complete_plan'),
                  ),
                );

          if (constraints.maxWidth < 520) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                text,
                const SizedBox(height: 14),
                action,
              ],
            );
          }

          return Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(child: text),
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
      await CarePlanService.instance.completePlan(plan.id);

      try {
        await NotificationService.instance.cancelPlan(plan.id);
      } catch (_) {
        // The server status is authoritative. A later plan refresh also
        // retries completed-plan reminder cleanup.
      }

      await _loadPlan();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr('care_plan_completed_reminders_stopped'))),
      );
    } on CarePlanException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(localizedCarePlanExceptionMessage(error, context.appLanguage))),
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
      final reactivated =
          await CarePlanService.instance.reactivatePlan(plan.id);

      final notificationResult =
          await NotificationService.instance.scheduleNextOccurrences(
        planId: plan.id,
        tasks: reactivated.tasks,
      );

      await _loadPlan();
      if (!mounted) return;

      final message = !notificationResult.permissionGranted
          ? context.tr('care_plan_reactivated_no_notification_permission')
          : !notificationResult.exactAlarmGranted
              ? context.tr('care_plan_reactivated_exact_alarm_missing')
              : context.tr('care_plan_reactivated_reminders_restored', values: {'count': notificationResult.scheduledCount});

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    } on CarePlanException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(localizedCarePlanExceptionMessage(error, context.appLanguage))),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.tr('plan_reactivation_device_failed'))),
        );
      }
    } finally {
      if (mounted) setState(() => _lifecycleSaving = false);
    }
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
              alignment: Alignment.centerRight,
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
            ...detail.instructions.map(
              (task) => _InstructionRow(
                task: task,
                onRemove: task.kind == TaskKind.medicine
                    ? () => _removeMedicineInstruction(task)
                    : null,
              ),
            ),
          ],
        );
      case 1:
        if (detail.tasks.isEmpty) {
          return EmptyState(
            icon: Icons.calendar_today_outlined,
            title: context.tr('no_scheduled_tasks_yet'),
            description: context.tr('generate_schedule_from_verified_instructions'),
            action: FilledButton.icon(
              onPressed: _generatingSchedule ? null : _generateSchedule,
              icon: _generatingSchedule
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.auto_awesome, size: 18),
              label: Text(_generatingSchedule ? context.tr('generating') : context.tr('generate_schedule')),
            ),
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (detail.plan.status == PlanStatus.active ||
                detail.plan.status == PlanStatus.completed) ...[
              _todayTaskOutcomesSection(detail.plan),
              const SizedBox(height: 22),
            ],
            Row(
              children: [
                Expanded(
                  child: Text(
                    context.tr('schedule_ai_copied_timings_help'),
                    style: const TextStyle(fontSize: 13, color: AppColors.muted),
                  ),
                ),
                const SizedBox(width: 12),
                OutlinedButton.icon(
                  onPressed: _generatingSchedule ? null : _generateSchedule,
                  icon: const Icon(Icons.refresh, size: 17),
                  label: Text(context.tr('regenerate')),
                ),
              ],
            ),
            const SizedBox(height: 14),
            ...detail.tasks.map(
              (task) => _ScheduleRow(
                task: task,
                period: _periodOverrides[task.id] ?? _periodFrom('${task.time} ${task.note}'),
                displayTime: _timeOverrides[task.id] ?? task.time,
                periodChanged: _unsavedPeriodChanges.contains(task.id),
                onEditPeriod: () => _editSchedulePeriod(task),
                onSetTime: () => _confirmScheduleItem(task),
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: detail.tasks.any((task) => task.status == TaskStatus.atRisk) || _unsavedPeriodChanges.isNotEmpty
                  ? null
                  : _continueFromSchedule,
              icon: Icon(widget.returnToPrevious ? Icons.check : Icons.arrow_forward, size: 18),
              label: Text(
                detail.tasks.any((task) => task.status == TaskStatus.atRisk) || _unsavedPeriodChanges.isNotEmpty
                    ? context.tr('confirm_schedule_items_first')
                    : widget.returnToPrevious
                        ? context.tr('done')
                        : context.tr('continue_to_reality_check'),
              ),
            ),
          ],
        );
      case 2:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Align(
              alignment: Alignment.centerRight,
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
            SimulationView(compact: true, planId: widget.planId),
          ],
        );
      case 3:
        final openGaps = detail.gaps
            .where((gap) => gap.status != TaskStatus.resolved)
            .toList();
        if (openGaps.isEmpty) {
          return EmptyState(
            icon: Icons.check_circle_outline,
            title: context.tr('no_open_care_gaps'),
            description: context.tr('no_unresolved_care_plan_issues'),
          );
        }
        return Column(
          children: openGaps
              .map(
                (gap) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: InkWell(
                    onTap: () async {
                      await Navigator.pushNamed(context, AppRoutes.careGap(gap.id));
                      if (mounted) await _loadPlan();
                    },
                    borderRadius: BorderRadius.circular(AppRadii.xxl),
                    child: AppCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          StatusBadge(status: gap.status),
                          const SizedBox(height: 8),
                          Text(gap.title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                          const SizedBox(height: 3),
                          Text(gap.summary, style: const TextStyle(fontSize: 14, color: AppColors.muted)),
                        ],
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
            action: FilledButton(
              onPressed: () => Navigator.pushNamed(
                context,
                AppRoutes.carePlanUpload,
                arguments: CarePlanUploadArgs(
                  planId: detail.plan.id,
                  documentTypes: const [],
                  returnToPrevious: true,
                ),
              ),
              child: Text(context.tr('upload_document')),
            ),
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Align(
              alignment: Alignment.centerRight,
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
                icon: const Icon(Icons.add, size: 17),
                label: Text(context.tr('add_document')),
              ),
            ),
            const SizedBox(height: 12),
            ...documents
              .map(
                (document) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: AppCard(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        const Icon(Icons.description_outlined, size: 21, color: AppColors.primary),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(document.name, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                              Text(context.tr(document.pages == 1 ? 'document_meta_page' : 'document_meta_pages', values: {'type': document.type, 'pages': document.pages, 'date': document.date}), style: const TextStyle(fontSize: 13, color: AppColors.muted)),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: () => _deleteDocument(document.id),
                          icon: const Icon(Icons.delete_outline, size: 19),
                          tooltip: context.tr('remove_document'),
                        ),
                      ],
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
          title: const Text('Record this reminder as skipped?'),
          content: const Text(
            'This only records what happened. SehatMate does not advise skipping or changing treatment. If you are unsure what to do next, check the verified instruction or ask a qualified healthcare professional.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Record skipped'),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
    }

    setState(() => _outcomeSavingIds.add(item.id));
    try {
      final result =
          await CareReliabilityService.instance.setOutcome(
        item,
        outcome,
      );
      final updated = result.occurrence;
      if (!mounted) return;
      setState(() {
        _todayOccurrences = _todayOccurrences
            .map((entry) => entry.id == updated.id ? updated : entry)
            .toList();
        final completed = _todayOccurrences.where((entry) => entry.completed).length;
        final skipped = _todayOccurrences.where((entry) => entry.skipped).length;
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
                ? 'Task marked completed.'
                : outcome == 'skipped'
                    ? 'Task recorded as skipped.'
                    : 'Task outcome cleared.',
          ),
        ),
      );
      if (result.queued) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Saved offline. This task outcome will sync automatically.',
            ),
          ),
        );
      } else if (result.conflictRecovered) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Latest server status restored because this task changed elsewhere.',
            ),
          ),
        );
      }
    } on CarePlanException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error.message)),
        );
      }
    } finally {
      if (mounted) setState(() => _outcomeSavingIds.remove(item.id));
    }
  }

  Widget _todayTaskOutcomesSection(DemoPlan plan) {
    final summary = _todaySummary;
    final completed = summary?.completed ??
        _todayOccurrences.where((item) => item.completed).length;
    final total = summary?.total ?? _todayOccurrences.length;

    return AppCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Today's task outcomes",
                      style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                    ),
                    SizedBox(height: 3),
                    Text(
                      'Each reminder is tracked separately for today.',
                      style: TextStyle(fontSize: 13, color: AppColors.muted),
                    ),
                  ],
                ),
              ),
              if (total > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                  decoration: BoxDecoration(
                    color: AppColors.primaryLight,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '$completed / $total done',
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
                  ? 'No task occurrences were recorded for today.'
                  : 'No tasks are scheduled for today.',
              style: const TextStyle(color: AppColors.muted),
            )
          else
            ..._todayOccurrences.map(_todayOccurrenceCard),
          if (_todayOccurrences.isNotEmpty) ...[
            const SizedBox(height: 4),
            const SafetyNote(
              text:
                  'Task outcomes record what happened. They do not change the verified medical instruction or tell you to skip, repeat, or change treatment.',
            ),
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
      'completed' => item.completedTime.isEmpty
          ? 'Completed'
          : 'Completed ${_displayClock(item.completedTime)}',
      'skipped' => 'Skipped',
      'missed' => 'Missed',
      'overdue' => 'Overdue',
      'due' => 'Due now',
      _ => 'Upcoming',
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
              const Icon(Icons.checklist_rounded, color: AppColors.primary, size: 21),
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
                      '${_displayClock(item.scheduledTime)}${item.period.isEmpty ? '' : ' · ${item.period[0].toUpperCase()}${item.period.substring(1)}'}',
                      style: const TextStyle(fontSize: 13, color: AppColors.muted),
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
                    : Icon(isMissed ? Icons.check_circle_outline : Icons.undo, size: 17),
                label: Text(isMissed ? 'Correct as completed' : 'Undo'),
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
                    label: const Text('Completed'),
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton(
                  onPressed: saving
                      ? null
                      : () => _setOccurrenceOutcome(item, 'skipped'),
                  child: const Text('Record skipped'),
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
      await CarePlanService.instance.deleteDocument(documentId);
      await _loadPlan();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Document removed.')),
        );
      }
    } on CarePlanException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error.message)),
        );
      }
    }
  }

  Future<void> _removeMedicineInstruction(DemoTask task) async {
    if (AuthSession.instance.isGuest) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Remove medicine from SehatMate?'),
        content: Text(
          'This removes "${task.title}" from this care plan, including its '
          'future SehatMate tasks and reminders. It does not mean the medicine '
          'should be stopped. Continue following the healthcare professional’s '
          'instructions unless they tell you otherwise.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.criticalForeground,
            ),
            child: const Text('Remove from SehatMate'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    try {
      await CarePlanService.instance.deleteInstruction(task.id);

      // Rebuild local notifications from backend truth. Cancelling the whole
      // plan first guarantees the removed medicine cannot leave an orphaned
      // Android notification behind.
      await NotificationService.instance.cancelPlan(widget.planId);

      final updated =
          await CarePlanService.instance.fetchPlanDetail(widget.planId);
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
          const SnackBar(
            content: Text(
              'Medicine removed from SehatMate and local reminders rebuilt.',
            ),
          ),
        );
      }
    } on CarePlanException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error.message)),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'The medicine was changed on the server, but local reminders '
              'could not be fully rebuilt. Reopen the app to reconcile them.',
            ),
          ),
        );
      }
    }
  }

  Future<void> _generateSchedule() async {
    if (AuthSession.instance.isGuest) {
      showDemoMessage(context, 'AI schedule generation is available after sign in.');
      return;
    }
    setState(() => _generatingSchedule = true);
    try {
      await CarePlanService.instance.generateSchedule(widget.planId);
      await _loadPlan();
      if (mounted) showDemoMessage(context, 'Schedule draft generated from verified instructions.');
    } on CarePlanException catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.message)));
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
        await CarePlanService.instance.updateSetupStep(
          widget.planId,
          CareSetupStep.realityCheck,
        );
        if (!mounted) return;
        setState(() => _scheduleSaveState = 'Saved');
      } on CarePlanException catch (error) {
        if (!mounted) return;
        setState(() => _scheduleSaveState = 'Retry needed');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error.message)),
        );
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
        note.contains('exact clock time') && note.contains('verified instruction');
    return task.timeLocked ||
        task.grounding.trim().toLowerCase() == 'explicit' ||
        hasVerifiedExactReason;
  }

  void _showVerifiedExactTimeLockedMessage() {
    showDemoMessage(
      context,
      'This exact time comes from the verified instruction and cannot be edited here.',
    );
  }

  Future<void> _confirmScheduleItem(DemoTask task) async {
    if (_taskHasVerifiedExactTimeLock(task)) {
      _showVerifiedExactTimeLockedMessage();
      return;
    }
    final period = _periodOverrides[task.id] ?? _periodFrom('${task.time} ${task.note}');

    if (_periodAlreadyUsed(task, period)) {
      _showScheduleConflict(
        '$period is already used for another reminder for this instruction. Choose a different period.',
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
        '${selected.format(context)} is already used for another reminder for this instruction. Choose a different time.',
      );
      return;
    }

    try {
      setState(() => _scheduleSaveState = 'Saving…');
      await CarePlanService.instance.confirmScheduleItem(
        task.id,
        scheduleTime: scheduleTime,
        displayTime: '$period · Confirmed reminder at ${selected.format(context)}',
      );

      if (!mounted) return;
      setState(() {
        _timeOverrides[task.id] = scheduleTime;
        _unsavedPeriodChanges.remove(task.id);
      });

      await _loadPlan();
      if (mounted) {
        setState(() => _scheduleSaveState = 'Saved');
        showDemoMessage(context, '$period reminder set for ${selected.format(context)}.');
      }
    } on CarePlanException catch (error) {
      if (mounted) {
        setState(() => _scheduleSaveState = 'Retry needed');
        if (error.data?['medicalTimingConflict'] == true) {
          await _showMedicalTimingConflict(error);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(error.message)),
          );
        }
      }
    }
  }

  Future<void> _showMedicalTimingConflict(CarePlanException error) async {
    final data = error.data ?? const <String, dynamic>{};
    final originalInstruction =
        data['originalInstruction']?.toString().trim() ?? '';
    final originalTiming = data['originalTiming']?.toString().trim() ?? '';
    final recommendation =
        data['recommendation']?.toString().trim() ?? '';

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: const Icon(
          Icons.warning_amber_rounded,
          color: AppColors.criticalForeground,
          size: 34,
        ),
        title: const Text('Medical timing conflict'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(error.message),
            if (originalInstruction.isNotEmpty) ...[
              const SizedBox(height: 14),
              const Text(
                'Verified instruction',
                style: TextStyle(fontWeight: FontWeight.w700),
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
                style: const TextStyle(
                  color: AppColors.muted,
                  height: 1.4,
                ),
              ),
            ],
            const SizedBox(height: 12),
            const Text(
              'The prescription instruction was not changed.',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: AppColors.primary,
              ),
            ),
          ],
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Choose a safe time'),
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

    final current = _periodOverrides[task.id] ?? _periodFrom('${task.time} ${task.note}');
    final period = await showDialog<String>(
      context: context,
      builder: (dialogContext) => SimpleDialog(
        title: const Text('Edit time period'),
        children: ['Morning', 'Afternoon', 'Evening', 'Night'].map((value) => ListTile(
          leading: Icon(value == current ? Icons.radio_button_checked : Icons.radio_button_off, color: AppColors.primary),
          title: Text(value),
          subtitle: Text(_periodDescription(value)),
          onTap: () => Navigator.pop(dialogContext, value),
        )).toList(),
      ),
    );
    if (period == null || !mounted) return;

    if (_periodAlreadyUsed(task, period)) {
      _showScheduleConflict(
        '$period is already used for another reminder for this instruction. Choose a different period.',
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
          _periodOverrides[other.id] ?? _periodFrom('${other.time} ${other.note}');
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
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<TimeOfDay?> _showRestrictedTimePicker(String period, TimeOfDay initial) async {
    final hours = switch (period) {
      'Morning' => List<int>.generate(8, (index) => index + 4),
      'Afternoon' => List<int>.generate(5, (index) => index + 12),
      'Evening' => List<int>.generate(4, (index) => index + 17),
      'Night' => <int>[21, 22, 23, 0, 1, 2, 3],
      _ => List<int>.generate(8, (index) => index + 4),
    };
    var hour = hours.contains(initial.hour) ? initial.hour : _defaultTime(period).hour;
    var minute = initial.minute;
    return showDialog<TimeOfDay>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('Set $period time'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Allowed: ${_periodDescription(period)}', style: const TextStyle(color: AppColors.muted)),
              const SizedBox(height: 16),
              Row(children: [
                Expanded(child: DropdownButtonFormField<int>(
                  initialValue: hour,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Hour'),
                  items: hours.map((value) => DropdownMenuItem(value: value, child: Text(_formatHour(value)))).toList(),
                  onChanged: (value) {
                    if (value != null) setDialogState(() => hour = value);
                  },
                )),
                const SizedBox(width: 10),
                Expanded(child: DropdownButtonFormField<int>(
                  initialValue: minute,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Minute'),
                  items: List<int>.generate(60, (index) => index).map((value) => DropdownMenuItem(value: value, child: Text(value.toString().padLeft(2, '0')))).toList(),
                  onChanged: (value) {
                    if (value != null) setDialogState(() => minute = value);
                  },
                )),
              ]),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(dialogContext, TimeOfDay(hour: hour, minute: minute)), child: const Text('Use this time')),
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
    'Morning' => '4:00 AM – 11:59 AM',
    'Afternoon' => '12:00 PM – 4:59 PM',
    'Evening' => '5:00 PM – 8:59 PM',
    'Night' => '9:00 PM – 3:59 AM',
    _ => '4:00 AM – 11:59 AM',
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

  Widget _loadingView() => const AppShell(
        currentRoute: AppRoutes.carePlans,
        title: 'Care Plan',
        child: Center(child: CircularProgressIndicator()),
      );

  Widget _notFound(String? message) => AppShell(
        currentRoute: AppRoutes.carePlans,
        title: 'Care Plan',
        child: AppCard(
          child: Column(
            children: [
              const Text('Care plan not found', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              Text(message ?? 'This plan may have been removed.', style: const TextStyle(color: AppColors.muted)),
              const SizedBox(height: 16),
              FilledButton(onPressed: () => Navigator.pushReplacementNamed(context, AppRoutes.carePlans), child: const Text('Back to Care Plans')),
            ],
          ),
        ),
      );
}

class _InstructionRow extends StatelessWidget {
  const _InstructionRow({
    required this.task,
    this.onRemove,
  });

  final DemoTask task;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: AppCard(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(color: AppColors.primaryLight, borderRadius: BorderRadius.circular(AppRadii.xl)),
                child: Icon(task.icon, size: 18, color: AppColors.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(task.title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                    Text('${task.note} · ${task.time}', style: const TextStyle(fontSize: 14, color: AppColors.muted)),
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
                      onPressed: onRemove,
                      tooltip: 'Remove medicine from SehatMate',
                      visualDensity: VisualDensity.compact,
                      icon: const Icon(
                        Icons.delete_outline,
                        size: 20,
                        color: AppColors.criticalForeground,
                      ),
                    ),
                  ],
                ],
              ),
            ],
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
    final foreground = warning ? AppColors.warningForeground : AppColors.primary;

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
        note.contains('exact clock time') && note.contains('verified instruction');
    final exactTimeLocked = formattedTime != null &&
        (task.timeLocked ||
            task.grounding.trim().toLowerCase() == 'explicit' ||
            hasVerifiedExactReason);
    final needsTime = !exactTimeLocked &&
        (task.status == TaskStatus.atRisk || periodChanged || formattedTime == null);

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: AppCard(
        padding: const EdgeInsets.all(18),
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
                _infoChip(icon: _periodIcon(), label: period),
                _infoChip(
                  icon: needsTime ? Icons.schedule_outlined : Icons.alarm_outlined,
                  label: needsTime ? 'Choose exact time' : formattedTime,
                  warning: needsTime,
                ),
              ],
            ),
            if (exactTimeLocked) ...[
              const SizedBox(height: 10),
              const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.lock_outline, size: 16, color: AppColors.primary),
                  SizedBox(width: 7),
                  Expanded(
                    child: Text(
                      'Exact time copied from the verified instruction. Reality Check can flag practical conflicts, but SehatRoute will not change this medical timing.',
                      style: TextStyle(
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
              const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline, size: 16, color: AppColors.warningForeground),
                  SizedBox(width: 7),
                  Expanded(
                    child: Text(
                      'Period changed. Choose an exact time inside this period to save it.',
                      style: TextStyle(
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
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.lock_outline, size: 17, color: AppColors.muted),
                    SizedBox(width: 8),
                    Text(
                      'Verified exact time',
                      style: TextStyle(fontWeight: FontWeight.w600),
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
                    label: 'Edit period',
                    onPressed: onEditPeriod,
                  );
                  final editTime = _actionButton(
                    icon: Icons.schedule_outlined,
                    label: needsTime ? 'Set time' : 'Edit time',
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
    );
  }
}
