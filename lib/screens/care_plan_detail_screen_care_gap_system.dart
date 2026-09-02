import 'package:flutter/material.dart';

import '../core/app_routes.dart';
import '../core/app_theme.dart';
import '../data/demo_data.dart';
import '../services/auth_service.dart';
import '../services/care_plan_service.dart';
import '../widgets/app_shell.dart';
import '../widgets/page_header.dart';
import '../widgets/status_badge.dart';
import '../widgets/ui.dart';
import 'simulation_screen.dart';

class CarePlanDetailScreen extends StatefulWidget {
  const CarePlanDetailScreen({required this.planId, this.initialTab = 0, super.key});
  final String planId;
  final int initialTab;

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
      if (!mounted) return;
      setState(() {
        _detail = detail;
        _loading = false;
      });
    } on CarePlanException catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = error.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Care plan could not be loaded.';
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
      title: 'Care Plan',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => Navigator.pushReplacementNamed(context, AppRoutes.carePlans),
              icon: const Icon(Icons.arrow_back, size: 17),
              label: const Text('Care Plans'),
            ),
          ),
          PageHeader(
            title: plan.title,
            subtitle: 'Started ${plan.startDate} · Next: ${plan.nextTask}',
            action: PlanStatusBadge(status: plan.status),
          ),
          AppCard(
            child: Column(
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Expanded(child: Text('Care readiness', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500))),
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
          Align(
            alignment: Alignment.centerLeft,
            child: AppTabs<int>(
              tabs: const [
                AppTab(0, 'Instructions'),
                AppTab(1, 'Schedule'),
                AppTab(2, 'Simulation'),
                AppTab(3, 'Care Gaps'),
                AppTab(4, 'Documents'),
              ],
              selected: tab,
              onChanged: (value) => setState(() => tab = value),
            ),
          ),
          const SizedBox(height: 20),
          _tabContent(detail),
          const SizedBox(height: 32),
          const SafetyNote(text: 'This plan reflects instructions given by your healthcare professional. SehatMate does not change medical treatment.'),
        ],
      ),
      ),
    );
  }

  Widget _tabContent(CarePlanDetailData detail) {
    switch (tab) {
      case 0:
        if (detail.instructions.isEmpty) {
          return const EmptyState(
            icon: Icons.fact_check_outlined,
            title: 'No instructions yet',
            description: 'Upload documents to extract care instructions.',
          );
        }
        return Column(children: detail.instructions.map((task) => _InstructionRow(task: task)).toList());
      case 1:
        if (detail.tasks.isEmpty) {
          return EmptyState(
            icon: Icons.calendar_today_outlined,
            title: 'No scheduled tasks yet',
            description: 'Generate a schedule from the verified prescription instructions.',
            action: FilledButton.icon(
              onPressed: _generatingSchedule ? null : _generateSchedule,
              icon: _generatingSchedule
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.auto_awesome, size: 18),
              label: Text(_generatingSchedule ? 'Generating…' : 'Generate schedule'),
            ),
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'AI copied explicit timings and marked inferred slots for confirmation.',
                    style: TextStyle(fontSize: 13, color: AppColors.muted),
                  ),
                ),
                const SizedBox(width: 12),
                OutlinedButton.icon(
                  onPressed: _generatingSchedule ? null : _generateSchedule,
                  icon: const Icon(Icons.refresh, size: 17),
                  label: const Text('Regenerate'),
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
                  : () => Navigator.pushNamed(
                        context,
                        AppRoutes.realityCheck,
                        arguments: CareFlowArgs(planId: widget.planId),
                      ),
              icon: const Icon(Icons.arrow_forward, size: 18),
              label: Text(
                detail.tasks.any((task) => task.status == TaskStatus.atRisk) || _unsavedPeriodChanges.isNotEmpty
                    ? 'Confirm schedule items first'
                    : 'Continue to Reality Check',
              ),
            ),
          ],
        );
      case 2:
        return SimulationView(compact: true, planId: widget.planId);
      case 3:
        final openGaps = detail.gaps
            .where((gap) => gap.status != TaskStatus.resolved)
            .toList();
        if (openGaps.isEmpty) {
          return const EmptyState(
            icon: Icons.check_circle_outline,
            title: 'No open care gaps',
            description: 'There are no unresolved care-plan issues right now.',
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
            title: 'No documents yet',
            description: 'Upload a prescription or discharge summary to build this plan.',
            action: FilledButton(
              onPressed: () => Navigator.pushNamed(
                context,
                AppRoutes.carePlanUpload,
                arguments: CarePlanUploadArgs(
                  planId: detail.plan.id,
                  documentTypes: const [],
                ),
              ),
              child: const Text('Upload document'),
            ),
          );
        }
        return Column(
          children: documents
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
                              Text('${document.type} · ${document.pages} page${document.pages == 1 ? '' : 's'} · ${document.date}', style: const TextStyle(fontSize: 13, color: AppColors.muted)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              )
              .toList(),
        );
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

  Future<void> _confirmScheduleItem(DemoTask task) async {
    final period = _periodOverrides[task.id] ?? _periodFrom('${task.time} ${task.note}');
    final initialTime = _parseTime(task.time) ?? _defaultTime(period);
    final selected = await _showRestrictedTimePicker(period, initialTime);
    if (selected == null || !mounted) return;
    final scheduleTime = '${selected.hour.toString().padLeft(2, '0')}:${selected.minute.toString().padLeft(2, '0')}';
    try {
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
      if (mounted) showDemoMessage(context, '$period reminder set for ${selected.format(context)}.');
    } on CarePlanException catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.message)));
    }
  }

  Future<void> _editSchedulePeriod(DemoTask task) async {
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
    setState(() {
      _periodOverrides[task.id] = period;
      _unsavedPeriodChanges.add(task.id);
    });
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
    if (text.contains('afternoon')) return 'Afternoon';
    if (text.contains('evening')) return 'Evening';
    if (text.contains('night') || text.contains('bedtime')) return 'Night';
    if (text.contains('morning')) return 'Morning';
    final match = RegExp(r'\b([01]?\d|2[0-3]):[0-5]\d\b').firstMatch(text);
    final hour = match == null ? null : int.tryParse(match.group(1)!);
    if (hour != null) {
      if (hour >= 4 && hour < 12) return 'Morning';
      if (hour >= 12 && hour < 17) return 'Afternoon';
      if (hour >= 17 && hour < 21) return 'Evening';
      return 'Night';
    }
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
  const _InstructionRow({required this.task});
  final DemoTask task;

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
              StatusBadge(status: task.status),
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

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: AppCard(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              SizedBox(
                width: 118,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(period, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.muted)),
                    TextButton.icon(
                      onPressed: onEditPeriod,
                      style: TextButton.styleFrom(padding: EdgeInsets.zero, visualDensity: VisualDensity.compact),
                      icon: const Icon(Icons.edit_outlined, size: 15),
                      label: const Text('Edit period'),
                    ),
                    if (periodChanged)
                      const Text('Set a new time', style: TextStyle(fontSize: 11, color: AppColors.warningForeground)),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      task.title,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (task.note.trim().isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        task.note,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.muted,
                        ),
                      ),
                    ],
                    if (_formattedTime(displayTime) case final formattedTime?) ...[
                      const SizedBox(height: 6),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.schedule,
                            size: 15,
                            color: AppColors.primary,
                          ),
                          const SizedBox(width: 5),
                          Flexible(
                            child: Text(
                              formattedTime,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: onSetTime,
                icon: const Icon(Icons.schedule, size: 17),
                label: Text(task.status == TaskStatus.atRisk || periodChanged ? 'Set time' : 'Edit time'),
              ),
            ],
          ),
        ),
      );
}
