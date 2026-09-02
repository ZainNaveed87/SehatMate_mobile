import 'package:flutter/material.dart';

import '../core/app_routes.dart';
import '../core/app_theme.dart';
import '../data/demo_data.dart';
import '../localization/language_scope.dart';
import '../services/auth_service.dart';
import '../services/care_plan_service.dart';
import '../services/notification_service.dart';
import '../widgets/app_shell.dart';
import '../widgets/page_header.dart';
import '../widgets/status_badge.dart';
import '../widgets/ui.dart';

class CarePlansScreen extends StatefulWidget {
  const CarePlansScreen({super.key});

  @override
  State<CarePlansScreen> createState() => _CarePlansScreenState();
}

class _CarePlansScreenState extends State<CarePlansScreen> {
  int selected = 0;
  List<DemoPlan> _plans = const [];
  bool _loading = true;
  String? _error;
  final Set<String> _selectedIds = {};

  @override
  void initState() {
    super.initState();
    _loadPlans();
  }

  Future<void> _loadPlans() async {
    if (AuthSession.instance.isGuest) {
      setState(() {
        _plans = demoPlans;
        _loading = false;
        _error = null;
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final plans = await CarePlanService.instance.fetchPlans();
      for (final plan in plans.where((item) => item.status == PlanStatus.completed)) {
        await NotificationService.instance.cancelPlan(plan.id);
      }
      if (!mounted) return;
      setState(() {
        _plans = plans;
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
        _error = context.tr('care_plans_load_failed');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final lists = [
      _plans.where((plan) => plan.status == PlanStatus.active || plan.status == PlanStatus.needsAttention).toList(),
      _plans.where((plan) => plan.status == PlanStatus.draft || plan.status == PlanStatus.processing || plan.status == PlanStatus.needsReview || plan.status == PlanStatus.realityCheck).toList(),
      _plans.where((plan) => plan.status == PlanStatus.completed).toList(),
    ];
    return AppShell(
      currentRoute: AppRoutes.carePlans,
      title: context.tr('care_plans'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PageHeader(
            title: context.tr('care_plans'),
            subtitle: context.tr('care_plans_subtitle'),
            action: FilledButton.icon(
              onPressed: () => Navigator.pushNamed(context, AppRoutes.carePlanNew),
              icon: const Icon(Icons.add, size: 17),
              label: Text(context.tr('new_care_plan')),
            ),
          ),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: AppTabs<int>(
              tabs: [
                AppTab(0, context.tr('active')),
                AppTab(1, context.tr('draft')),
                AppTab(2, context.tr('completed')),
              ],
              selected: selected,
              onChanged: (value) => setState(() { selected = value; _selectedIds.clear(); }),
            ),
          ),
          const SizedBox(height: 20),
          if (!_loading && _error == null && lists[selected].isNotEmpty && !AuthSession.instance.isGuest) ...[
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: () => setState(() {
                    final ids = lists[selected].map((item) => item.id).toSet();
                    if (_selectedIds.containsAll(ids)) { _selectedIds.clear(); } else { _selectedIds..clear()..addAll(ids); }
                  }),
                  icon: Icon(_selectedIds.containsAll(lists[selected].map((item) => item.id)) ? Icons.deselect : Icons.select_all),
                  label: Text(_selectedIds.containsAll(lists[selected].map((item) => item.id)) ? context.tr('clear_selection') : context.tr('select_all')),
                ),
                if (_selectedIds.isNotEmpty)
                  FilledButton.icon(
                    onPressed: () => _deleteSelected(_selectedIds.toList()),
                    style: FilledButton.styleFrom(backgroundColor: AppColors.criticalForeground),
                    icon: const Icon(Icons.delete_outline),
                    label: Text(context.tr('delete_selected_count', values: {'count': _selectedIds.length})),
                  ),
                OutlinedButton.icon(
                  onPressed: () => _deleteSelected(lists[selected].map((item) => item.id).toList(), all: true),
                  icon: const Icon(Icons.delete_sweep_outlined),
                  label: Text(
                    context.tr(
                      'delete_all_section',
                      values: {
                        'section': context.tr(
                          selected == 0
                              ? 'active'
                              : selected == 1
                                  ? 'draft'
                                  : 'completed',
                        ).toLowerCase(),
                      },
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
          ],
          if (_loading)
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 48),
                child: CircularProgressIndicator(),
              ),
            )
          else if (_error != null)
            AppCard(
              child: Column(
                children: [
                  Text(_error!, textAlign: TextAlign.center),
                  const SizedBox(height: 14),
                  OutlinedButton(onPressed: _loadPlans, child: Text(context.tr('retry'))),
                ],
              ),
            )
          else
            _PlanGrid(
              plans: lists[selected],
              onDelete: !AuthSession.instance.isGuest ? _deletePlan : null,
              onComplete: !AuthSession.instance.isGuest ? _completePlan : null,
              selectedIds: _selectedIds,
              onSelectionChanged: (plan, checked) => setState(() {
                if (checked) { _selectedIds.add(plan.id); } else { _selectedIds.remove(plan.id); }
              }),
            ),
        ],
      ),
    );
  }

  Future<void> _deletePlan(DemoPlan plan) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(context.tr('delete_care_plan_question')),
        content: Text(
          context.tr(
            'delete_care_plan_description',
            values: {'plan': plan.title},
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(context.tr('cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.criticalForeground),
            child: Text(context.tr('delete_plan')),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    try {
      await NotificationService.instance.cancelPlan(plan.id);
      await CarePlanService.instance.deletePlan(plan.id);
      if (!mounted) return;
      setState(() => _plans = _plans.where((item) => item.id != plan.id).toList());
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr('care_plan_deleted'))),
      );
    } on CarePlanException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.message)));
      }
    }
  }

  Future<void> _deleteSelected(List<String> ids, {bool all = false}) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          context.tr(
            all ? 'delete_all_plans_question' : 'delete_selected_plans_question',
          ),
        ),
        content: Text(
          context.tr(
            'bulk_delete_description',
            values: {'count': ids.length},
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(context.tr('cancel')),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.criticalForeground,
            ),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(context.tr('delete')),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      for (final id in ids) { await NotificationService.instance.cancelPlan(id); }
      await CarePlanService.instance.deletePlans(ids);
      if (!mounted) return;
      setState(() { _plans = _plans.where((item) => !ids.contains(item.id)).toList(); _selectedIds.clear(); });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.tr('selected_care_plans_deleted'))));
    } on CarePlanException catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.message)));
    }
  }

  Future<void> _completePlan(DemoPlan plan) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(context.tr('complete_plan_question')),
        content: Text(context.tr('complete_plan_description')),
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
    if (confirmed != true) return;
    try {
      await NotificationService.instance.cancelPlan(plan.id);
      await CarePlanService.instance.completePlan(plan.id);
      await _loadPlans();
    } on CarePlanException catch (error) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.message))); }
  }
}

class _PlanGrid extends StatelessWidget {
  const _PlanGrid({required this.plans, this.onDelete, this.onComplete, required this.selectedIds, required this.onSelectionChanged});
  final List<DemoPlan> plans;
  final Future<void> Function(DemoPlan plan)? onDelete;
  final Future<void> Function(DemoPlan plan)? onComplete;
  final Set<String> selectedIds;
  final void Function(DemoPlan plan, bool selected) onSelectionChanged;

  @override
  Widget build(BuildContext context) {
    if (plans.isEmpty) {
      return AppCard(
        child: Column(
          children: [
            const CircleAvatar(radius: 22, backgroundColor: AppColors.primaryLight, child: Icon(Icons.checklist_outlined, color: AppColors.primary)),
            const SizedBox(height: 12),
            Text(
              context.tr('no_care_plans_here'),
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            Text(
              context.tr('no_care_plan_in_state'),
              style: const TextStyle(fontSize: 14, color: AppColors.muted),
            ),
            const SizedBox(height: 18),
            FilledButton(
              onPressed: () => Navigator.pushNamed(context, AppRoutes.carePlanNew),
              child: Text(context.tr('create_care_plan')),
            ),
          ],
        ),
      );
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 720 ? 2 : 1;
        const gap = 16.0;
        final width = (constraints.maxWidth - (columns - 1) * gap) / columns;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: plans.map((plan) => SizedBox(
            width: width,
            child: _PlanCard(plan: plan, onDelete: onDelete, onComplete: onComplete, selected: selectedIds.contains(plan.id), onSelectionChanged: onSelectionChanged),
          )).toList(),
        );
      },
    );
  }
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({required this.plan, this.onDelete, this.onComplete, required this.selected, required this.onSelectionChanged});
  final DemoPlan plan;
  final Future<void> Function(DemoPlan plan)? onDelete;
  final Future<void> Function(DemoPlan plan)? onComplete;
  final bool selected;
  final void Function(DemoPlan plan, bool selected) onSelectionChanged;

  @override
  Widget build(BuildContext context) => HoverLift(
        cursor: SystemMouseCursors.click,
        child: InkWell(
          onTap: () => Navigator.pushNamed(context, AppRoutes.carePlan(plan.id)),
          borderRadius: BorderRadius.circular(AppRadii.xxl),
          child: AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Checkbox(value: selected, onChanged: (value) => onSelectionChanged(plan, value ?? false)),
                  Expanded(child: Text(plan.title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600))),
                  if (onDelete != null || (plan.status == PlanStatus.active && onComplete != null))
                    PopupMenuButton<String>(
                      tooltip: context.tr('plan_actions'),
                      onSelected: (value) {
                        if (value == 'complete') onComplete?.call(plan);
                        if (value == 'delete') onDelete?.call(plan);
                      },
                      itemBuilder: (_) => [
                        if (plan.status == PlanStatus.active && onComplete != null)
                          PopupMenuItem(value: 'complete', child: Text(context.tr('complete_plan'))),
                        if (onDelete != null)
                          PopupMenuItem(value: 'delete', child: Text(context.tr('delete_plan'))),
                      ],
                    ),
                ],
              ),
              const SizedBox(height: 4),
              PlanStatusBadge(status: plan.status),
              const SizedBox(height: 8),
              Text(context.tr('started_date', values: {'date': plan.startDate}), style: const TextStyle(fontSize: 13, color: AppColors.muted)),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      context.tr('care_readiness'),
                      style: const TextStyle(fontSize: 13, color: AppColors.muted),
                    ),
                  ),
                  Text('${plan.readiness}%', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                ],
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(99),
                child: LinearProgressIndicator(value: plan.readiness / 100, minHeight: 8, color: AppColors.primary, backgroundColor: AppColors.secondary),
              ),
              const SizedBox(height: 16),
              Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: '${context.tr('next_label')}: ',
                      style: const TextStyle(color: AppColors.muted),
                    ),
                    TextSpan(text: plan.nextTask),
                  ],
                ),
                style: const TextStyle(fontSize: 14),
              ),
            ],
          ),
          ),
        ),
      );
}

class NewCarePlanScreen extends StatefulWidget {
  const NewCarePlanScreen({super.key});

  @override
  State<NewCarePlanScreen> createState() => _NewCarePlanScreenState();
}

class _NewCarePlanScreenState extends State<NewCarePlanScreen> {
  final selected = <String>{'prescription'};
  bool _creating = false;
  static const options = [
    ('prescription', 'Prescription', Icons.medication_outlined, 'Medicines, doses and timings.'),
    ('discharge', 'Discharge Summary', Icons.local_hospital_outlined, 'Instructions after leaving hospital.'),
    ('followup', 'Follow-Up Instructions', Icons.description_outlined, 'Next appointments and reviews.'),
    ('lab', 'Lab Instructions', Icons.biotech_outlined, 'Tests and sample requirements.'),
    ('other', 'Other Medical Instructions', Icons.note_alt_outlined, 'Anything else from your clinic.'),
  ];

  @override
  Widget build(BuildContext context) => AppShell(
        currentRoute: AppRoutes.carePlanNew,
        title: context.tr('new_care_plan'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: TextButton.icon(
                onPressed: () => Navigator.pushReplacementNamed(context, AppRoutes.carePlans),
                icon: const Icon(Icons.arrow_back, size: 17),
                label: Text(context.tr('care_plans')),
              ),
            ),
            PageHeader(
              title: context.tr('what_would_you_like_to_add'),
              subtitle: context.tr('select_document_types_subtitle'),
            ),
            LayoutBuilder(
              builder: (context, constraints) {
                final columns = constraints.maxWidth >= 650 ? 2 : 1;
                const gap = 12.0;
                final width = (constraints.maxWidth - (columns - 1) * gap) / columns;
                return Wrap(
                  spacing: gap,
                  runSpacing: gap,
                  children: options.map((option) => SizedBox(width: width, child: _option(option))).toList(),
                );
              },
            ),
            const SizedBox(height: 24),
            SafetyNote(
              text: context.tr('new_plan_safety_note'),
            ),
            const SizedBox(height: 24),
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: FilledButton.icon(
                onPressed: selected.isEmpty || _creating ? null : _continue,
                iconAlignment: IconAlignment.end,
                icon: const Icon(Icons.arrow_forward, size: 17),
                label: Text(context.tr('continue')),
              ),
            ),
          ],
        ),
      );

  Future<void> _continue() async {
    if (AuthSession.instance.isGuest) {
      Navigator.pushNamed(context, AppRoutes.carePlanUpload);
      return;
    }

    setState(() => _creating = true);
    try {
      final selectedLabels = options
          .where((option) => selected.contains(option.$1))
          .map((option) => option.$2)
          .toList();
      final title = selectedLabels.length == 1
          ? '${selectedLabels.first} Care Plan'
          : 'Combined Care Plan';
      final plan = await CarePlanService.instance.createPlan(title);
      if (!mounted) return;
      Navigator.pushNamed(
        context,
        AppRoutes.carePlanUpload,
        arguments: CarePlanUploadArgs(
          planId: plan.id,
          documentTypes: selected.toList(),
        ),
      );
    } on CarePlanException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message)),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr('care_plan_create_failed'))),
      );
    } finally {
      if (mounted) setState(() => _creating = false);
    }
  }

  String _optionLabel(BuildContext context, String id) => switch (id) {
        'prescription' => context.tr('prescription'),
        'discharge' => context.tr('discharge_summary'),
        'followup' => context.tr('follow_up_instructions'),
        'lab' => context.tr('lab_instructions'),
        _ => context.tr('other_medical_instructions'),
      };

  String _optionDescription(BuildContext context, String id) => switch (id) {
        'prescription' => context.tr('prescription_description'),
        'discharge' => context.tr('discharge_description'),
        'followup' => context.tr('followup_description'),
        'lab' => context.tr('lab_description'),
        _ => context.tr('other_medical_description'),
      };

  Widget _option((String, String, IconData, String) option) {
    final active = selected.contains(option.$1);
    return InkWell(
      onTap: () => setState(() => active ? selected.remove(option.$1) : selected.add(option.$1)),
      borderRadius: BorderRadius.circular(AppRadii.xxl),
      child: AppCard(
        padding: const EdgeInsets.all(20),
        color: active ? AppColors.primaryLight : AppColors.card,
        borderColor: active ? AppColors.primary : AppColors.border,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(AppRadii.xl)),
              child: Icon(option.$3, size: 20, color: AppColors.primary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _optionLabel(context, option.$1),
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    _optionDescription(context, option.$1),
                    style: const TextStyle(fontSize: 13, color: AppColors.muted),
                  ),
                ],
              ),
            ),
            if (active) const Icon(Icons.check, size: 20, color: AppColors.primary),
          ],
        ),
      ),
    );
  }
}
