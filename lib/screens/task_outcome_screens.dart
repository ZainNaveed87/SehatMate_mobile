import 'package:flutter/material.dart';

import '../core/app_routes.dart';
import '../core/app_theme.dart';
import '../localization/language_scope.dart';
import '../services/auth_service.dart';
import '../services/care_plan_service.dart';
import '../services/care_reliability_service.dart';
import '../widgets/app_shell.dart';
import '../widgets/page_header.dart';
import '../widgets/ui.dart';

class TaskCalendarScreen extends StatefulWidget {
  const TaskCalendarScreen({super.key});

  @override
  State<TaskCalendarScreen> createState() => _TaskCalendarScreenState();
}

class _TaskCalendarScreenState extends State<TaskCalendarScreen>
    with WidgetsBindingObserver {
  DateTime selectedDate = DateTime.now();
  CareTaskAppDayData? data;
  bool loading = true;
  String? error;
  final Set<String> savingIds = {};
  DateTime _lastToday = DateTime.now();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    CareReliabilityService.instance.start();
    _lastToday = _dateOnly(DateTime.now());
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
    final now = _dateOnly(DateTime.now());
    if (DateUtils.isSameDay(selectedDate, _lastToday) &&
        !DateUtils.isSameDay(now, _lastToday)) {
      selectedDate = now;
    }
    _lastToday = now;
    CareReliabilityService.instance.onAppResumed();
    _load();
  }

  DateTime _dateOnly(DateTime value) =>
      DateTime(value.year, value.month, value.day);

  DateTime get _dayOnly => _dateOnly(selectedDate);

  DateTime get _today => _dateOnly(DateTime.now());

  bool get _selectedIsToday => _dayOnly == _today;

  DateTime _startOfWeek(DateTime value) =>
      DateTime(value.year, value.month, value.day)
          .subtract(Duration(days: value.weekday - DateTime.monday));

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
            summary: _summaryFor(
              items,
              current.summary,
            ),
          );
        });
      }
      if (result.queued && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.tr('calendar_saved_offline')),
          ),
        );
      } else if (result.conflictRecovered && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.tr('calendar_conflict_restored')),
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
    return AppShell(
      currentRoute: AppRoutes.calendar,
      title: context.tr('calendar'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PageHeader(
            title: context.tr('calendar'),
            subtitle: context.tr('calendar_subtitle'),
            action: OutlinedButton.icon(
              onPressed: () {
                setState(() => selectedDate = DateTime.now());
                _load();
              },
              icon: const Icon(Icons.today_outlined, size: 17),
              label: Text(context.tr('today')),
            ),
          ),
          _syncBanner(),
          _weekPicker(),
          const SizedBox(height: 18),
          if (loading)
            const AppCard(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: Center(child: CircularProgressIndicator()),
              ),
            )
          else if (error != null)
            AppCard(
              child: Column(
                children: [
                  const Icon(Icons.cloud_off_outlined, size: 30),
                  const SizedBox(height: 10),
                  Text(_localizedError(context), textAlign: TextAlign.center),
                  const SizedBox(height: 12),
                  OutlinedButton(
                    onPressed: _load,
                    child: Text(context.tr('retry')),
                  ),
                ],
              ),
            )
          else
            _dayContent(),
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
          child: AppCard(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Icon(
                  sync.online
                      ? Icons.sync_outlined
                      : Icons.cloud_off_outlined,
                  size: 18,
                  color: AppColors.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    text,
                    style: const TextStyle(fontSize: 13),
                  ),
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
                    () => selectedDate =
                        selectedDate.subtract(const Duration(days: 7)),
                  );
                  _load();
                },
                icon: const Icon(Icons.chevron_left),
              ),
              Expanded(
                child: Text(
                  _weekLabel(context, start),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              IconButton(
                tooltip: context.tr('next_week'),
                onPressed: () {
                  setState(
                    () => selectedDate =
                        selectedDate.add(const Duration(days: 7)),
                  );
                  _load();
                },
                icon: const Icon(Icons.chevron_right),
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
    return InkWell(
      onTap: () {
        setState(() => selectedDate = day);
        _load();
      },
      borderRadius: BorderRadius.circular(14),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: EdgeInsets.symmetric(
          vertical: compact ? 9 : 11,
          horizontal: 2,
        ),
        decoration: BoxDecoration(
          color: selected ? AppColors.primaryLight : Colors.transparent,
          border: Border.all(
            color: selected ? AppColors.primary : Colors.transparent,
          ),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          children: [
            Text(
              _weekday(context, day.weekday),
              style: TextStyle(
                fontSize: compact ? 10 : 12,
                color: selected ? AppColors.primary : AppColors.muted,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              '${day.day}',
              style: TextStyle(
                fontSize: compact ? 14 : 16,
                fontWeight: FontWeight.w700,
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
        child: Column(
          children: [
            const Icon(Icons.event_available_outlined, size: 34),
            const SizedBox(height: 10),
            Text(
              context.tr(
                'no_care_tasks_on_date',
                values: {'date': _displayDate(context, selectedDate)},
              ),
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              context.tr('nothing_due_on_date'),
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.muted),
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
          child: Row(
            children: [
              Expanded(
                child: Text(
                  _displayDate(context, selectedDate),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Text(
                context.tr('calendar_completed_summary', values: {'completed': value.summary.completed, 'total': value.summary.total}),
                style: const TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        ...value.occurrences.map(
          (occurrence) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
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

    return AppCard(
      padding: const EdgeInsets.all(16),
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
                child: Icon(icon, color: AppColors.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      occurrence.title,
                      style: const TextStyle(
                        fontSize: 16,
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
                    const SizedBox(height: 5),
                    Text(
                      '${_clock(occurrence.scheduledTime)}'
                      '${occurrence.period.isEmpty ? '' : ' · ${_localizedPeriod(context, occurrence.period)}'}',
                      style: const TextStyle(
                        color: AppColors.muted,
                      ),
                    ),
                  ],
                ),
              ),
              _statusChip(
                context,
                occurrence.overdue ? 'overdue' : occurrence.status,
              ),
            ],
          ),
          if (canEdit) ...[
            const SizedBox(height: 14),
            if (saving)
              const LinearProgressIndicator(minHeight: 3)
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (!occurrence.completed)
                    FilledButton.icon(
                      onPressed: () => _setOutcome(occurrence, 'completed'),
                      icon: const Icon(Icons.check_circle_outline, size: 18),
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
                      icon: const Icon(Icons.undo, size: 17),
                      label: Text(context.tr('undo')),
                    ),
                ],
              ),
          ],
        ],
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
      final result =
          await CarePlanService.instance.fetchAllTaskOutcomeSummary(days: days);
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
    return AppShell(
      currentRoute: AppRoutes.progress,
      title: context.tr('progress'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PageHeader(
            title: context.tr('progress'),
            subtitle: context.tr('progress_subtitle'),
            action: PopupMenuButton<int>(
              tooltip: context.tr('time_range'),
              initialValue: days,
              onSelected: (value) {
                setState(() => days = value);
                _load();
              },
              itemBuilder: (_) => [
                PopupMenuItem(
                  value: 7,
                  child: Text(
                    context.tr('last_days', values: {'count': 7}),
                  ),
                ),
                PopupMenuItem(
                  value: 14,
                  child: Text(
                    context.tr('last_days', values: {'count': 14}),
                  ),
                ),
                PopupMenuItem(
                  value: 30,
                  child: Text(
                    context.tr('last_days', values: {'count': 30}),
                  ),
                ),
              ],
              child: OutlinedButton.icon(
                onPressed: null,
                icon: const Icon(Icons.date_range_outlined, size: 17),
                label: Text(
                  context.tr('last_days', values: {'count': days}),
                ),
              ),
            ),
          ),
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
                  Text(_localizedProgressError(context), textAlign: TextAlign.center),
                  const SizedBox(height: 12),
                  OutlinedButton(onPressed: _load, child: Text(context.tr('retry'))),
                ],
              ),
            )
          else
            _content(),
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
            const gap = 12.0;
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
        const SizedBox(height: 20),
        AppCard(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                context.tr('task_completion_by_day'),
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                context.tr('progress_safety_explanation'),
                style: const TextStyle(
                  color: AppColors.muted,
                  height: 1.4,
                ),
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
        const SizedBox(height: 16),
        AppCard(
          padding: const EdgeInsets.all(18),
          child: Wrap(
            spacing: 24,
            runSpacing: 12,
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

  Widget _metric(
    double width,
    String label,
    String value,
    String hint,
  ) {
    return SizedBox(
      width: width,
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

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        children: [
          Row(
            children: [
              SizedBox(
                width: 82,
                child: Text(
                  label,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(99),
                  child: LinearProgressIndicator(
                    minHeight: 9,
                    value: progress,
                    backgroundColor: AppColors.secondary,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(
                width: 48,
                child: Text(
                  decided == 0 ? '—' : '${day.completionRate}%',
                  textAlign: TextAlign.end,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          if (day.scheduled > 0) ...[
            const SizedBox(height: 4),
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
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.muted,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _plainStat(String label, int value) => SizedBox(
        width: 100,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$value',
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
              ),
            ),
            Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.muted,
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
