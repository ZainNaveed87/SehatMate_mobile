import 'package:flutter/material.dart';

import '../core/app_routes.dart';
import '../core/app_theme.dart';
import '../localization/language_scope.dart';
import '../services/auth_service.dart';
import '../services/care_plan_service.dart';
import '../services/care_reliability_service.dart';
import '../widgets/app_shell.dart';
import '../widgets/ui.dart';

class CalendarRouteArgs {
  const CalendarRouteArgs({this.initialDate});

  final Object? initialDate;
}

String calendarLocalDateKey(DateTime value) =>
    '${value.year.toString().padLeft(4, '0')}-'
    '${value.month.toString().padLeft(2, '0')}-'
    '${value.day.toString().padLeft(2, '0')}';

DateTime? calendarInitialDateFrom(Object? value) {
  if (value is DateTime) {
    return DateTime(value.year, value.month, value.day);
  }

  if (value is! String) return null;
  final match = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(value.trim());
  if (match == null) return null;
  final year = int.tryParse(match.group(1)!);
  final month = int.tryParse(match.group(2)!);
  final day = int.tryParse(match.group(3)!);
  if (year == null || month == null || day == null) return null;

  final parsed = DateTime(year, month, day);
  if (parsed.year != year || parsed.month != month || parsed.day != day) {
    return null;
  }
  return parsed;
}

class TaskCalendarScreen extends StatefulWidget {
  const TaskCalendarScreen({
    super.key,
    this.initialDate,
    this.now,
    this.startReliability = true,
  });

  final Object? initialDate;
  final DateTime Function()? now;
  final bool startReliability;

  @override
  State<TaskCalendarScreen> createState() => _TaskCalendarScreenState();
}

class _TaskCalendarScreenState extends State<TaskCalendarScreen>
    with WidgetsBindingObserver {
  late DateTime selectedDate;
  CareTaskAppDayData? data;
  bool loading = true;
  String? error;
  final Set<String> savingIds = {};
  late DateTime _lastToday;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (widget.startReliability) {
      CareReliabilityService.instance.start();
    }
    selectedDate = _initialSelectedDate();
    _lastToday = _today;
    _load();
  }

  @override
  void didUpdateWidget(covariant TaskCalendarScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialDate == widget.initialDate) return;
    selectedDate = _initialSelectedDate();
    _lastToday = _today;
    _load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed || loading) return;
    final now = _today;
    if (DateUtils.isSameDay(selectedDate, _lastToday) &&
        !DateUtils.isSameDay(now, _lastToday)) {
      selectedDate = now;
    }
    _lastToday = now;
    if (widget.startReliability) {
      CareReliabilityService.instance.onAppResumed();
    }
    _load();
  }

  DateTime _dateOnly(DateTime value) =>
      DateTime(value.year, value.month, value.day);

  DateTime _now() => widget.now?.call() ?? DateTime.now();

  DateTime _initialSelectedDate() =>
      calendarInitialDateFrom(widget.initialDate) ?? _today;

  DateTime get _dayOnly => _dateOnly(selectedDate);

  DateTime get _today => _dateOnly(_now());

  bool get _selectedIsToday => _dayOnly == _today;

  DateTime _startOfWeek(DateTime value) => DateTime(
    value.year,
    value.month,
    value.day,
  ).subtract(Duration(days: value.weekday - DateTime.monday));

  Future<void> _load() async {
    if (AuthSession.instance.isGuest) {
      setState(() {
        loading = false;
        error = '__calendar_guest_sign_in__';
      });
      return;
    }

    setState(() {
      loading = true;
      error = null;
    });
    try {
      final result = await CarePlanService.instance.fetchAllTaskOccurrences(
        date: selectedDate,
      );
      if (!mounted) return;
      setState(() {
        data = result;
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
      final updated = result.occurrence;
      if (!mounted) return;
      final current = data;
      if (current != null) {
        final items = current.occurrences
            .map((item) => item.id == updated.id ? updated : item)
            .toList();
        setState(() {
          data = CareTaskAppDayData(
            date: current.date,
            occurrences: items,
            summary: _summaryFor(items, current.summary),
          );
        });
      }
      if (result.queued && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.tr('calendar_saved_offline'))),
        );
      } else if (result.conflictRecovered && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.tr('calendar_conflict_restored'))),
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

  CareTaskAppDaySummary _summaryFor(
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

  @override
  Widget build(BuildContext context) {
    final summary = data?.summary;

    return AppShell(
      currentRoute: AppRoutes.calendar,
      title: context.tr('calendar'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          FadeSlideIn(
            child: _TaskCareHero(
              title: context.tr('calendar'),
              subtitle: context.tr('calendar_subtitle'),
              icon: Icons.calendar_month_outlined,
              chips: [
                (Icons.today_outlined, _displayDate(context, selectedDate)),
                if (summary != null)
                  (
                    Icons.task_alt_outlined,
                    '${summary.completed}/${summary.total}',
                  ),
                if (summary != null)
                  (
                    Icons.health_and_safety_outlined,
                    '${summary.activePlans} ${context.tr('care_plans')}',
                  ),
              ],
              action: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: AppColors.primary,
                ),
                onPressed: () {
                  setState(() => selectedDate = _today);
                  _load();
                },
                icon: const Icon(Icons.today_outlined, size: 17),
                label: Text(context.tr('today')),
              ),
            ),
          ),
          const SizedBox(height: 14),
          _syncBanner(),
          FadeSlideIn(
            delay: const Duration(milliseconds: 60),
            child: _weekPicker(),
          ),
          const SizedBox(height: 18),
          if (loading)
            const _TaskCareLoadingCard()
          else if (error != null)
            AppCard(
              padding: const EdgeInsets.all(22),
              color: const Color(0xFFFFFBEB),
              borderColor: const Color(0xFFFDE68A),
              child: Column(
                children: [
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: AppColors.warningSoft,
                      borderRadius: BorderRadius.circular(AppRadii.xl),
                    ),
                    child: const Icon(
                      Icons.cloud_off_outlined,
                      size: 24,
                      color: AppColors.warningForeground,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _localizedError(context),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.muted,
                    ),
                  ),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: _load,
                    icon: const Icon(Icons.refresh_rounded, size: 17),
                    label: Text(context.tr('retry')),
                  ),
                ],
              ),
            )
          else
            FadeSlideIn(
              delay: const Duration(milliseconds: 90),
              child: _dayContent(),
            ),
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

        final text = !sync.online
            ? sync.pendingCount > 0
                  ? context.tr(
                      'calendar_offline_outcomes_waiting',
                      values: {'count': sync.pendingCount},
                    )
                  : context.tr('calendar_offline_saved_data')
            : sync.syncing
            ? context.tr('calendar_syncing')
            : context.tr(
                'calendar_outcomes_waiting',
                values: {'count': sync.pendingCount},
              );

        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Container(
            padding: const EdgeInsets.all(11),
            decoration: BoxDecoration(
              color: sync.online
                  ? const Color(0xFFF0FDFA)
                  : const Color(0xFFFFFBEB),
              borderRadius: BorderRadius.circular(AppRadii.xl),
              border: Border.all(
                color: sync.online
                    ? AppColors.primary.withValues(alpha: .16)
                    : const Color(0xFFFDE68A),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: sync.online
                        ? AppColors.primaryLight
                        : AppColors.warningSoft,
                    borderRadius: BorderRadius.circular(AppRadii.lg),
                  ),
                  child: Icon(
                    sync.online ? Icons.sync_rounded : Icons.cloud_off_outlined,
                    size: 17,
                    color: sync.online
                        ? AppColors.primary
                        : AppColors.warningForeground,
                  ),
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(
                    text,
                    style: const TextStyle(
                      fontSize: 10,
                      color: AppColors.muted,
                      height: 1.4,
                    ),
                  ),
                ),
                if (sync.syncing)
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _weekPicker() {
    final start = _startOfWeek(selectedDate);
    final days = List<DateTime>.generate(
      7,
      (index) => start.add(Duration(days: index)),
    );

    return AppCard(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          Row(
            children: [
              IconButton(
                tooltip: context.tr('previous_week'),
                onPressed: () {
                  setState(
                    () => selectedDate = selectedDate.subtract(
                      const Duration(days: 7),
                    ),
                  );
                  _load();
                },
                icon: const Icon(Icons.chevron_left_rounded),
              ),
              Expanded(
                child: Column(
                  children: [
                    Text(
                      _weekLabel(context, start),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _selectedIsToday
                          ? context.tr('today')
                          : _displayDate(context, selectedDate),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 9,
                        color: AppColors.muted,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: context.tr('next_week'),
                onPressed: () {
                  setState(
                    () => selectedDate = selectedDate.add(
                      const Duration(days: 7),
                    ),
                  );
                  _load();
                },
                icon: const Icon(Icons.chevron_right_rounded),
              ),
            ],
          ),
          const SizedBox(height: 8),
          LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 500;
              return Row(
                children: [
                  for (final day in days)
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 2),
                        child: _dayButton(day, compact),
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _dayButton(DateTime day, bool compact) {
    final selected = DateUtils.isSameDay(day, selectedDate);
    final isToday = DateUtils.isSameDay(day, _today);

    return InkWell(
      key: ValueKey(
        'calendar_day_${calendarLocalDateKey(day)}_${selected ? 'selected' : 'idle'}',
      ),
      onTap: () {
        setState(() => selectedDate = day);
        _load();
      },
      borderRadius: BorderRadius.circular(AppRadii.lg),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 170),
        padding: EdgeInsets.symmetric(
          vertical: compact ? 8 : 10,
          horizontal: 2,
        ),
        decoration: BoxDecoration(
          gradient: selected
              ? const LinearGradient(
                  colors: [Color(0xFF0F766E), Color(0xFF0D9488)],
                )
              : null,
          color: selected
              ? null
              : isToday
              ? const Color(0xFFF0FDFA)
              : const Color(0xFFF8FAFC),
          border: Border.all(
            color: selected
                ? AppColors.primary
                : isToday
                ? AppColors.primary.withValues(alpha: .18)
                : Colors.transparent,
          ),
          borderRadius: BorderRadius.circular(AppRadii.lg),
        ),
        child: Column(
          children: [
            Text(
              _weekday(context, day.weekday),
              style: TextStyle(
                fontSize: compact ? 9 : 10,
                color: selected ? const Color(0xDFFFFFFF) : AppColors.muted,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              '${day.day}',
              style: TextStyle(
                fontSize: compact ? 14 : 16,
                fontWeight: FontWeight.w800,
                color: selected ? Colors.white : AppColors.foreground,
              ),
            ),
            const SizedBox(height: 2),
            Container(
              width: 4,
              height: 4,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: selected
                    ? Colors.white
                    : isToday
                    ? AppColors.primary
                    : Colors.transparent,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _dayContent() {
    final value = data;

    if (value == null || value.occurrences.isEmpty) {
      return AppCard(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: AppColors.successSoft,
                borderRadius: BorderRadius.circular(AppRadii.xl),
              ),
              child: const Icon(
                Icons.event_available_outlined,
                size: 27,
                color: AppColors.successForeground,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              context.tr(
                'no_care_tasks_on_date',
                values: {'date': _displayDate(context, selectedDate)},
              ),
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            Text(
              context.tr('nothing_due_on_date'),
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 11, color: AppColors.muted),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppCard(
          padding: const EdgeInsets.all(16),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final copy = Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppColors.primaryLight,
                      borderRadius: BorderRadius.circular(AppRadii.lg),
                    ),
                    child: const Icon(
                      Icons.event_note_outlined,
                      size: 19,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _displayDate(context, selectedDate),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          context.tr(
                            'calendar_completed_summary',
                            values: {
                              'completed': value.summary.completed,
                              'total': value.summary.total,
                            },
                          ),
                          style: const TextStyle(
                            fontSize: 10,
                            color: AppColors.muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              );

              final stats = Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  _TaskSummaryPill(
                    label: context.tr('completed'),
                    value: value.summary.completed,
                    background: AppColors.successSoft,
                    foreground: AppColors.successForeground,
                  ),
                  _TaskSummaryPill(
                    label: context.tr('pending'),
                    value: value.summary.pending,
                    background: AppColors.primaryLight,
                    foreground: AppColors.primary,
                  ),
                  if (value.summary.missed > 0)
                    _TaskSummaryPill(
                      label: context.tr('missed'),
                      value: value.summary.missed,
                      background: AppColors.criticalSoft,
                      foreground: AppColors.criticalForeground,
                    ),
                ],
              );

              if (constraints.maxWidth < 560) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [copy, const SizedBox(height: 12), stats],
                );
              }

              return Row(
                children: [
                  Expanded(child: copy),
                  const SizedBox(width: 12),
                  stats,
                ],
              );
            },
          ),
        ),
        const SizedBox(height: 12),
        ...value.occurrences.map(
          (occurrence) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _taskCard(occurrence),
          ),
        ),
      ],
    );
  }

  Widget _taskCard(CareTaskOccurrence occurrence) {
    final saving = savingIds.contains(occurrence.id);
    final canEdit = _selectedIsToday && !occurrence.missed;
    final icon = switch (occurrence.taskKind.toLowerCase()) {
      'lab' || 'test' => Icons.biotech_outlined,
      'visit' || 'follow_up' => Icons.local_hospital_outlined,
      'dressing' || 'wound' => Icons.healing_outlined,
      'caregiver' => Icons.handshake_outlined,
      _ => Icons.medication_outlined,
    };

    final attention = occurrence.missed || occurrence.overdue;

    return HoverLift(
      child: AppCard(
        padding: EdgeInsets.zero,
        borderColor: attention
            ? AppColors.critical.withValues(alpha: .20)
            : AppColors.border,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (attention) Container(height: 4, color: AppColors.critical),
            Padding(
              padding: const EdgeInsets.all(14),
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
                          color: attention
                              ? AppColors.criticalSoft
                              : AppColors.primaryLight,
                          borderRadius: BorderRadius.circular(AppRadii.lg),
                        ),
                        child: Icon(
                          icon,
                          color: attention
                              ? AppColors.criticalForeground
                              : AppColors.primary,
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
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            if (occurrence.planTitle.isNotEmpty) ...[
                              const SizedBox(height: 2),
                              Text(
                                occurrence.planTitle,
                                style: const TextStyle(
                                  fontSize: 10,
                                  color: AppColors.muted,
                                ),
                              ),
                            ],
                            const SizedBox(height: 5),
                            Row(
                              children: [
                                const Icon(
                                  Icons.schedule_rounded,
                                  size: 13,
                                  color: AppColors.subtle,
                                ),
                                const SizedBox(width: 4),
                                Flexible(
                                  child: Text(
                                    '${_clock(occurrence.scheduledTime)}'
                                    '${occurrence.period.isEmpty ? '' : ' · ${_localizedPeriod(context, occurrence.period)}'}',
                                    style: const TextStyle(
                                      fontSize: 10,
                                      color: AppColors.muted,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      _statusChip(
                        context,
                        occurrence.overdue ? 'overdue' : occurrence.status,
                      ),
                    ],
                  ),
                  if (canEdit) ...[
                    const SizedBox(height: 12),
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
                            OutlinedButton.icon(
                              onPressed: () =>
                                  _setOutcome(occurrence, 'skipped'),
                              icon: const Icon(
                                Icons.skip_next_outlined,
                                size: 17,
                              ),
                              label: Text(context.tr('record_skipped')),
                            ),
                          if (occurrence.completed || occurrence.skipped)
                            TextButton.icon(
                              onPressed: () =>
                                  _setOutcome(occurrence, 'pending'),
                              icon: const Icon(Icons.undo_rounded, size: 17),
                              label: Text(context.tr('undo')),
                            ),
                        ],
                      ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statusChip(BuildContext context, String status) {
    final label = switch (status) {
      'completed' => context.tr('completed'),
      'skipped' => context.tr('skipped'),
      'missed' => context.tr('missed'),
      'overdue' => context.tr('overdue'),
      _ => context.tr('upcoming'),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: status == 'completed'
            ? AppColors.successSoft
            : (status == 'missed' || status == 'overdue')
            ? AppColors.criticalSoft
            : AppColors.secondary,
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: status == 'completed'
              ? AppColors.successForeground
              : (status == 'missed' || status == 'overdue')
              ? AppColors.criticalForeground
              : AppColors.muted,
        ),
      ),
    );
  }

  String _localizedError(BuildContext context) {
    if (error == '__calendar_guest_sign_in__') {
      return context.tr('calendar_sign_in_required');
    }
    return error ?? '';
  }

  String _weekLabel(BuildContext context, DateTime start) {
    final end = start.add(const Duration(days: 6));
    return context.tr(
      'calendar_week_range',
      values: {
        'startMonth': _month(context, start.month),
        'startDay': start.day,
        'endMonth': _month(context, end.month),
        'endDay': end.day,
        'year': end.year,
      },
    );
  }

  String _displayDate(BuildContext context, DateTime value) => context.tr(
    'calendar_full_date',
    values: {
      'weekday': _weekdayLong(context, value.weekday),
      'day': value.day,
      'month': _month(context, value.month),
      'year': value.year,
    },
  );

  String _weekday(BuildContext context, int value) => context.tr(
    const [
      'mon_short',
      'tue_short',
      'wed_short',
      'thu_short',
      'fri_short',
      'sat_short',
      'sun_short',
    ][value - 1],
  );

  String _weekdayLong(BuildContext context, int value) => context.tr(
    const [
      'monday',
      'tuesday',
      'wednesday',
      'thursday',
      'friday',
      'saturday',
      'sunday',
    ][value - 1],
  );

  String _month(BuildContext context, int value) => context.tr(
    const [
      'jan_short',
      'feb_short',
      'mar_short',
      'apr_short',
      'may_short',
      'jun_short',
      'jul_short',
      'aug_short',
      'sep_short',
      'oct_short',
      'nov_short',
      'dec_short',
    ][value - 1],
  );

  String _localizedPeriod(BuildContext context, String value) {
    return switch (value.trim().toLowerCase()) {
      'morning' => context.tr('morning'),
      'afternoon' => context.tr('afternoon'),
      'evening' => context.tr('evening'),
      'night' => context.tr('night'),
      _ => value,
    };
  }

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

class TaskProgressScreen extends StatefulWidget {
  const TaskProgressScreen({super.key});

  @override
  State<TaskProgressScreen> createState() => _TaskProgressScreenState();
}

class _TaskProgressScreenState extends State<TaskProgressScreen>
    with WidgetsBindingObserver {
  int days = 7;
  bool loading = true;
  String? error;
  CareTaskAppOutcomeSummary? data;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    CareReliabilityService.instance.start();
    _load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && !loading) {
      CareReliabilityService.instance.onAppResumed();
      _load();
    }
  }

  Future<void> _load() async {
    if (AuthSession.instance.isGuest) {
      setState(() {
        loading = false;
        error = '__progress_guest_sign_in__';
      });
      return;
    }
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final result = await CarePlanService.instance.fetchAllTaskOutcomeSummary(
        days: days,
      );
      if (!mounted) return;
      setState(() {
        data = result;
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

  @override
  Widget build(BuildContext context) {
    final value = data;

    return AppShell(
      currentRoute: AppRoutes.progress,
      title: context.tr('progress'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          FadeSlideIn(
            child: _TaskCareHero(
              title: context.tr('progress'),
              subtitle: context.tr('progress_subtitle'),
              icon: Icons.insights_outlined,
              chips: [
                (
                  Icons.date_range_outlined,
                  context.tr('last_days', values: {'count': days}),
                ),
                if (value != null)
                  (Icons.task_alt_outlined, '${value.completionRate}%'),
                if (value != null)
                  (
                    Icons.check_circle_outline_rounded,
                    '${value.completed} ${context.tr('completed')}',
                  ),
              ],
              action: PopupMenuButton<int>(
                tooltip: context.tr('time_range'),
                initialValue: days,
                onSelected: (range) {
                  setState(() => days = range);
                  _load();
                },
                itemBuilder: (_) => [
                  PopupMenuItem(
                    value: 7,
                    child: Text(context.tr('last_days', values: {'count': 7})),
                  ),
                  PopupMenuItem(
                    value: 14,
                    child: Text(context.tr('last_days', values: {'count': 14})),
                  ),
                  PopupMenuItem(
                    value: 30,
                    child: Text(context.tr('last_days', values: {'count': 30})),
                  ),
                ],
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(AppRadii.lg),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.date_range_outlined,
                        size: 16,
                        color: AppColors.primary,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '$days',
                        style: const TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 18),
          if (loading)
            const _TaskCareLoadingCard()
          else if (error != null)
            AppCard(
              padding: const EdgeInsets.all(22),
              color: const Color(0xFFFFFBEB),
              borderColor: const Color(0xFFFDE68A),
              child: Column(
                children: [
                  const Icon(
                    Icons.error_outline_rounded,
                    size: 28,
                    color: AppColors.warningForeground,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _localizedProgressError(context),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.muted,
                    ),
                  ),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: _load,
                    icon: const Icon(Icons.refresh_rounded, size: 17),
                    label: Text(context.tr('retry')),
                  ),
                ],
              ),
            )
          else
            FadeSlideIn(
              delay: const Duration(milliseconds: 70),
              child: _content(),
            ),
        ],
      ),
    );
  }

  Widget _content() {
    final value = data;
    if (value == null) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final columns = constraints.maxWidth >= 720 ? 4 : 2;
            const gap = 10.0;
            final width =
                (constraints.maxWidth - ((columns - 1) * gap)) / columns;

            return Wrap(
              spacing: gap,
              runSpacing: gap,
              children: [
                _metric(
                  width,
                  context.tr('task_completion'),
                  '${value.completionRate}%',
                  context.tr(
                    'completed_count',
                    values: {'count': value.completed},
                  ),
                ),
                _metric(
                  width,
                  context.tr('missed'),
                  '${value.missed}',
                  context.tr('recorded_automatically'),
                ),
                _metric(
                  width,
                  context.tr('skipped'),
                  '${value.skipped}',
                  context.tr('user_recorded'),
                ),
                _metric(
                  width,
                  context.tr('pending'),
                  '${value.pending}',
                  context.tr('not_decided_yet'),
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 16),
        AppCard(
          padding: const EdgeInsets.all(18),
          child: Column(
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
                      Icons.bar_chart_rounded,
                      size: 19,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          context.tr('task_completion_by_day'),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          context.tr('progress_safety_explanation'),
                          style: const TextStyle(
                            fontSize: 10,
                            color: AppColors.muted,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              if (value.daily.every((day) => day.scheduled == 0))
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  child: Text(
                    context.tr('no_task_outcomes_in_range'),
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: AppColors.muted),
                  ),
                )
              else
                ...value.daily.map(_dayRow),
            ],
          ),
        ),
        const SizedBox(height: 14),
        AppCard(
          padding: const EdgeInsets.all(16),
          child: Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _plainStat(context.tr('scheduled'), value.scheduled),
              _plainStat(context.tr('completed'), value.completed),
              _plainStat(context.tr('on_time'), value.onTime),
              _plainStat(context.tr('late'), value.late),
              _plainStat(context.tr('missed'), value.missed),
              _plainStat(context.tr('skipped'), value.skipped),
            ],
          ),
        ),
      ],
    );
  }

  Widget _metric(double width, String label, String value, String hint) {
    final isCompletion = label == context.tr('task_completion');

    return SizedBox(
      width: width,
      child: HoverLift(
        child: AppCard(
          padding: const EdgeInsets.all(14),
          color: isCompletion ? const Color(0xFFF0FDFA) : AppColors.card,
          borderColor: isCompletion
              ? AppColors.primary.withValues(alpha: .18)
              : AppColors.border,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: isCompletion
                      ? AppColors.primaryLight
                      : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(AppRadii.lg),
                ),
                child: Icon(
                  isCompletion
                      ? Icons.insights_outlined
                      : Icons.analytics_outlined,
                  size: 17,
                  color: isCompletion ? AppColors.primary : AppColors.muted,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 24,
                  height: 1,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                hint,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 9,
                  color: AppColors.muted,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _dayRow(CareTaskDailyOutcome day) {
    final decided = day.decided;
    final progress = decided == 0 ? 0.0 : day.completed / decided;
    final parsed = DateTime.tryParse(day.date);
    final label = parsed == null
        ? day.date
        : context.tr(
            'progress_day_label',
            values: {
              'weekday': _progressWeekday(context, parsed.weekday),
              'day': parsed.day,
              'month': _progressMonth(context, parsed.month),
            },
          );

    return Container(
      margin: const EdgeInsets.only(bottom: 9),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(AppRadii.lg),
      ),
      child: Column(
        children: [
          Row(
            children: [
              SizedBox(
                width: 82,
                child: Text(
                  label,
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(99),
                  child: LinearProgressIndicator(
                    minHeight: 8,
                    value: progress,
                    backgroundColor: const Color(0xFFE8EFEE),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(
                width: 46,
                child: Text(
                  decided == 0 ? '—' : '${day.completionRate}%',
                  textAlign: TextAlign.end,
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ],
          ),
          if (day.scheduled > 0) ...[
            const SizedBox(height: 5),
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: Text(
                context.tr(
                  day.pending > 0
                      ? 'progress_day_outcomes_with_pending'
                      : 'progress_day_outcomes',
                  values: {
                    'completed': day.completed,
                    'missed': day.missed,
                    'skipped': day.skipped,
                    'pending': day.pending,
                  },
                ),
                style: const TextStyle(fontSize: 9, color: AppColors.muted),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _plainStat(String label, int value) => Container(
    width: 112,
    padding: const EdgeInsets.all(11),
    decoration: BoxDecoration(
      color: const Color(0xFFF8FAFC),
      borderRadius: BorderRadius.circular(AppRadii.lg),
      border: Border.all(color: AppColors.border),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$value',
          style: const TextStyle(
            fontSize: 20,
            height: 1,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 9,
            color: AppColors.muted,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    ),
  );

  String _localizedProgressError(BuildContext context) {
    if (error == '__progress_guest_sign_in__') {
      return context.tr('progress_sign_in_required');
    }
    return error ?? '';
  }

  String _progressWeekday(BuildContext context, int value) => context.tr(
    const [
      'mon_short',
      'tue_short',
      'wed_short',
      'thu_short',
      'fri_short',
      'sat_short',
      'sun_short',
    ][value - 1],
  );

  String _progressMonth(BuildContext context, int value) => context.tr(
    const [
      'jan_short',
      'feb_short',
      'mar_short',
      'apr_short',
      'may_short',
      'jun_short',
      'jul_short',
      'aug_short',
      'sep_short',
      'oct_short',
      'nov_short',
      'dec_short',
    ][value - 1],
  );
}

class _TaskCareHero extends StatelessWidget {
  const _TaskCareHero({
    required this.title,
    required this.subtitle,
    required this.icon,
    this.chips = const [],
    this.action,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final List<(IconData, String)> chips;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(22),
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF0F766E), Color(0xFF0D9488), Color(0xFF14B8A6)],
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
    child: Stack(
      children: [
        PositionedDirectional(
          top: -72,
          end: -54,
          child: Container(
            width: 180,
            height: 180,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Color(0x14FFFFFF),
            ),
          ),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: const Color(0x20FFFFFF),
                    borderRadius: BorderRadius.circular(AppRadii.xl),
                  ),
                  child: Icon(icon, color: Colors.white, size: 22),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 25,
                          height: 1.12,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -.35,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          color: Color(0xE6FFFFFF),
                          fontSize: 11,
                          height: 1.45,
                        ),
                      ),
                    ],
                  ),
                ),
                if (action != null) ...[const SizedBox(width: 10), action!],
              ],
            ),
            if (chips.isNotEmpty) ...[
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: chips
                    .map(
                      (chip) => Container(
                        constraints: const BoxConstraints(maxWidth: 220),
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
                            Icon(chip.$1, size: 13, color: Colors.white),
                            const SizedBox(width: 5),
                            Flexible(
                              child: Text(
                                chip.$2,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                    .toList(),
              ),
            ],
          ],
        ),
      ],
    ),
  );
}

class _TaskCareLoadingCard extends StatelessWidget {
  const _TaskCareLoadingCard();

  @override
  Widget build(BuildContext context) => AppCard(
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
  );
}

class _TaskSummaryPill extends StatelessWidget {
  const _TaskSummaryPill({
    required this.label,
    required this.value,
    required this.background,
    required this.foreground,
  });

  final String label;
  final int value;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
    decoration: BoxDecoration(
      color: background,
      borderRadius: BorderRadius.circular(999),
    ),
    child: Text(
      '$label · $value',
      style: TextStyle(
        color: foreground,
        fontSize: 9,
        fontWeight: FontWeight.w800,
      ),
    ),
  );
}
