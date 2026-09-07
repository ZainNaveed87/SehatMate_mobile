import 'package:flutter/material.dart';

import '../core/app_routes.dart';
import '../core/app_theme.dart';
import '../data/demo_data.dart';
import '../localization/language_scope.dart';
import '../localization/localized_errors.dart';
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
      for (final plan in plans.where(
        (item) => item.status == PlanStatus.completed,
      )) {
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
        _error = localizedCarePlanExceptionMessage(error, context.appLanguage);
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
      _plans
          .where(
            (plan) =>
                plan.status == PlanStatus.active ||
                plan.status == PlanStatus.needsAttention,
          )
          .toList(),
      _plans
          .where(
            (plan) =>
                plan.status == PlanStatus.draft ||
                plan.status == PlanStatus.processing ||
                plan.status == PlanStatus.needsReview ||
                plan.status == PlanStatus.realityCheck,
          )
          .toList(),
      _plans.where((plan) => plan.status == PlanStatus.completed).toList(),
    ];

    final activeCount = lists[0].length;
    final draftCount = lists[1].length;
    final completedCount = lists[2].length;
    final currentPlans = lists[selected];

    return AppShell(
      currentRoute: AppRoutes.carePlans,
      title: context.tr('care_plans'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          FadeSlideIn(
            child: _plansHero(
              activeCount: activeCount,
              draftCount: draftCount,
              completedCount: completedCount,
            ),
          ),

          const SizedBox(height: 18),

          FadeSlideIn(
            delay: const Duration(milliseconds: 60),
            child: _planMetrics(
              activeCount: activeCount,
              draftCount: draftCount,
              completedCount: completedCount,
            ),
          ),

          const SizedBox(height: 20),

          FadeSlideIn(
            delay: const Duration(milliseconds: 80),
            child: _premiumTabs(
              activeCount: activeCount,
              draftCount: draftCount,
              completedCount: completedCount,
            ),
          ),

          if (!_loading &&
              _error == null &&
              currentPlans.isNotEmpty &&
              !AuthSession.instance.isGuest) ...[
            const SizedBox(height: 14),
            FadeSlideIn(
              delay: const Duration(milliseconds: 100),
              child: _selectionBar(currentPlans),
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
            child: _loading
                ? Padding(
                    key: const ValueKey('care-plans-loading'),
                    padding: const EdgeInsets.only(top: 4),
                    child: _loadingSkeleton(),
                  )
                : _error != null
                ? FadeSlideIn(
                    key: const ValueKey('care-plans-error'),
                    child: _errorCard(),
                  )
                : KeyedSubtree(
                    key: ValueKey(
                      'care-plans-$selected-${currentPlans.length}',
                    ),
                    child: _PlanGrid(
                      plans: currentPlans,
                      onDelete: !AuthSession.instance.isGuest
                          ? _deletePlan
                          : null,
                      onComplete: !AuthSession.instance.isGuest
                          ? _completePlan
                          : null,
                      selectedIds: _selectedIds,
                      onSelectionChanged: (plan, checked) => setState(() {
                        if (checked) {
                          _selectedIds.add(plan.id);
                        } else {
                          _selectedIds.remove(plan.id);
                        }
                      }),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _plansHero({
    required int activeCount,
    required int draftCount,
    required int completedCount,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 640;

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
                    _heroCopy(
                      activeCount: activeCount,
                      draftCount: draftCount,
                      completedCount: completedCount,
                    ),
                    const SizedBox(height: 18),
                    FilledButton.icon(
                      onPressed: () =>
                          Navigator.pushNamed(context, AppRoutes.carePlanNew),
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: AppColors.primary,
                      ),
                      icon: const Icon(Icons.add_rounded, size: 18),
                      label: Text(context.tr('new_care_plan')),
                    ),
                  ],
                )
              else
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: _heroCopy(
                        activeCount: activeCount,
                        draftCount: draftCount,
                        completedCount: completedCount,
                      ),
                    ),
                    const SizedBox(width: 22),
                    FilledButton.icon(
                      onPressed: () =>
                          Navigator.pushNamed(context, AppRoutes.carePlanNew),
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: AppColors.primary,
                      ),
                      icon: const Icon(Icons.add_rounded, size: 18),
                      label: Text(context.tr('new_care_plan')),
                    ),
                  ],
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _heroCopy({
    required int activeCount,
    required int draftCount,
    required int completedCount,
  }) {
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
              Icon(
                Icons.health_and_safety_outlined,
                size: 15,
                color: Colors.white,
              ),
              SizedBox(width: 6),
              Text(
                'Care plans',
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
          context.tr('care_plans'),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 30,
            height: 1.08,
            fontWeight: FontWeight.w800,
            letterSpacing: -.45,
          ),
        ),
        const SizedBox(height: 9),
        Text(
          context.tr('care_plans_subtitle'),
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
          children: [
            _heroChip(
              icon: Icons.play_circle_outline_rounded,
              label: '$activeCount ${context.tr('active')}',
            ),
            _heroChip(
              icon: Icons.edit_note_outlined,
              label: '$draftCount ${context.tr('draft')}',
            ),
            _heroChip(
              icon: Icons.check_circle_outline_rounded,
              label: '$completedCount ${context.tr('completed')}',
            ),
          ],
        ),
      ],
    );
  }

  Widget _heroChip({required IconData icon, required String label}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0x1FFFFFFF),
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
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _planMetrics({
    required int activeCount,
    required int draftCount,
    required int completedCount,
  }) {
    final total = activeCount + draftCount + completedCount;

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 760 ? 4 : 2;
        const gap = 10.0;
        final width = (constraints.maxWidth - ((columns - 1) * gap)) / columns;

        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            _metricCard(
              width: width,
              value: total,
              label: context.tr('care_plans'),
              icon: Icons.folder_copy_outlined,
              background: AppColors.infoSoft,
              foreground: AppColors.infoForeground,
            ),
            _metricCard(
              width: width,
              value: activeCount,
              label: context.tr('active'),
              icon: Icons.play_circle_outline_rounded,
              background: AppColors.successSoft,
              foreground: AppColors.successForeground,
            ),
            _metricCard(
              width: width,
              value: draftCount,
              label: context.tr('draft'),
              icon: Icons.edit_note_outlined,
              background: AppColors.warningSoft,
              foreground: AppColors.warningForeground,
            ),
            _metricCard(
              width: width,
              value: completedCount,
              label: context.tr('completed'),
              icon: Icons.task_alt_rounded,
              background: AppColors.primaryLight,
              foreground: AppColors.primary,
            ),
          ],
        );
      },
    );
  }

  Widget _metricCard({
    required double width,
    required int value,
    required String label,
    required IconData icon,
    required Color background,
    required Color foreground,
  }) {
    return SizedBox(
      width: width,
      child: AppCard(
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
          ],
        ),
      ),
    );
  }

  Widget _premiumTabs({
    required int activeCount,
    required int draftCount,
    required int completedCount,
  }) {
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
          _tabButton(
            value: 0,
            label: context.tr('active'),
            count: activeCount,
            icon: Icons.play_circle_outline_rounded,
          ),
          _tabButton(
            value: 1,
            label: context.tr('draft'),
            count: draftCount,
            icon: Icons.edit_note_outlined,
          ),
          _tabButton(
            value: 2,
            label: context.tr('completed'),
            count: completedCount,
            icon: Icons.task_alt_rounded,
          ),
        ],
      ),
    );
  }

  Widget _tabButton({
    required int value,
    required String label,
    required int count,
    required IconData icon,
  }) {
    final active = selected == value;

    return InkWell(
      onTap: () {
        if (selected == value) return;
        setState(() {
          selected = value;
          _selectedIds.clear();
        });
      },
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
            const SizedBox(width: 7),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              decoration: BoxDecoration(
                color: active
                    ? AppColors.primaryLight
                    : const Color(0xFFE8EFEE),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                '$count',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: active ? AppColors.primary : AppColors.muted,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _selectionBar(List<DemoPlan> plans) {
    final ids = plans.map((item) => item.id).toSet();
    final allSelected = ids.isNotEmpty && _selectedIds.containsAll(ids);

    return AppCard(
      padding: const EdgeInsets.all(12),
      color: const Color(0xFFFAFCFD),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          OutlinedButton.icon(
            onPressed: () => setState(() {
              if (allSelected) {
                _selectedIds.clear();
              } else {
                _selectedIds
                  ..clear()
                  ..addAll(ids);
              }
            }),
            icon: Icon(
              allSelected ? Icons.deselect_rounded : Icons.select_all_rounded,
              size: 17,
            ),
            label: Text(
              allSelected
                  ? context.tr('clear_selection')
                  : context.tr('select_all'),
            ),
          ),
          if (_selectedIds.isNotEmpty)
            FilledButton.icon(
              onPressed: () => _deleteSelected(_selectedIds.toList()),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.criticalForeground,
              ),
              icon: const Icon(Icons.delete_outline_rounded, size: 17),
              label: Text(
                context.tr(
                  'delete_selected_count',
                  values: {'count': _selectedIds.length},
                ),
              ),
            ),
          OutlinedButton.icon(
            onPressed: () => _deleteSelected(
              plans.map((item) => item.id).toList(),
              all: true,
            ),
            icon: const Icon(Icons.delete_sweep_outlined, size: 17),
            label: Text(
              context.tr(
                'delete_all_section',
                values: {
                  'section': context
                      .tr(
                        selected == 0
                            ? 'active'
                            : selected == 1
                            ? 'draft'
                            : 'completed',
                      )
                      .toLowerCase(),
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _loadingSkeleton() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 720 ? 2 : 1;
        const gap = 16.0;
        final width = (constraints.maxWidth - (columns - 1) * gap) / columns;

        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: List.generate(
            4,
            (_) => SizedBox(
              width: width,
              child: AppCard(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        _skeleton(width: 40, height: 40, radius: 12),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _skeleton(width: double.infinity, height: 18),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _skeleton(width: 100, height: 11),
                    const SizedBox(height: 18),
                    _skeleton(width: double.infinity, height: 8),
                    const SizedBox(height: 16),
                    _skeleton(width: 180, height: 12),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _skeleton({
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

  Widget _errorCard() {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 540),
        child: AppCard(
          padding: const EdgeInsets.all(24),
          color: const Color(0xFFFFFBEB),
          borderColor: const Color(0xFFFDE68A),
          child: Column(
            children: [
              Container(
                width: 52,
                height: 52,
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
                _error!,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 13, height: 1.45),
              ),
              const SizedBox(height: 14),
              OutlinedButton.icon(
                onPressed: _loadPlans,
                icon: const Icon(Icons.refresh_rounded, size: 17),
                label: Text(context.tr('retry')),
              ),
            ],
          ),
        ),
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
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.criticalForeground,
            ),
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
      setState(
        () => _plans = _plans.where((item) => item.id != plan.id).toList(),
      );
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.tr('care_plan_deleted'))));
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
    }
  }

  Future<void> _deleteSelected(List<String> ids, {bool all = false}) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          context.tr(
            all
                ? 'delete_all_plans_question'
                : 'delete_selected_plans_question',
          ),
        ),
        content: Text(
          context.tr('bulk_delete_description', values: {'count': ids.length}),
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
      for (final id in ids) {
        await NotificationService.instance.cancelPlan(id);
      }
      await CarePlanService.instance.deletePlans(ids);
      if (!mounted) return;
      setState(() {
        _plans = _plans.where((item) => !ids.contains(item.id)).toList();
        _selectedIds.clear();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr('selected_care_plans_deleted'))),
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
    }
  }
}

class _PlanGrid extends StatelessWidget {
  const _PlanGrid({
    required this.plans,
    this.onDelete,
    this.onComplete,
    required this.selectedIds,
    required this.onSelectionChanged,
  });

  final List<DemoPlan> plans;
  final Future<void> Function(DemoPlan plan)? onDelete;
  final Future<void> Function(DemoPlan plan)? onComplete;
  final Set<String> selectedIds;
  final void Function(DemoPlan plan, bool selected) onSelectionChanged;

  @override
  Widget build(BuildContext context) {
    if (plans.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 36),
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
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: AppColors.primaryLight,
                borderRadius: BorderRadius.circular(AppRadii.xl),
              ),
              child: const Icon(
                Icons.checklist_outlined,
                color: AppColors.primary,
                size: 27,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              context.tr('no_care_plans_here'),
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 5),
            Text(
              context.tr('no_care_plan_in_state'),
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.muted,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: () =>
                  Navigator.pushNamed(context, AppRoutes.carePlanNew),
              icon: const Icon(Icons.add_rounded, size: 18),
              label: Text(context.tr('create_care_plan')),
            ),
          ],
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 760 ? 2 : 1;
        const gap = 16.0;
        final width = (constraints.maxWidth - (columns - 1) * gap) / columns;

        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: plans
              .asMap()
              .entries
              .map(
                (entry) => SizedBox(
                  width: width,
                  child: FadeSlideIn(
                    delay: Duration(milliseconds: 35 * entry.key.clamp(0, 5)),
                    child: _PlanCard(
                      plan: entry.value,
                      onDelete: onDelete,
                      onComplete: onComplete,
                      selected: selectedIds.contains(entry.value.id),
                      onSelectionChanged: onSelectionChanged,
                    ),
                  ),
                ),
              )
              .toList(),
        );
      },
    );
  }
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({
    required this.plan,
    this.onDelete,
    this.onComplete,
    required this.selected,
    required this.onSelectionChanged,
  });

  final DemoPlan plan;
  final Future<void> Function(DemoPlan plan)? onDelete;
  final Future<void> Function(DemoPlan plan)? onComplete;
  final bool selected;
  final void Function(DemoPlan plan, bool selected) onSelectionChanged;

  @override
  Widget build(BuildContext context) {
    final readiness = plan.readiness.clamp(0, 100);
    final attention = plan.status == PlanStatus.needsAttention;
    final statusAccent = attention
        ? AppColors.warning
        : plan.status == PlanStatus.completed
        ? AppColors.success
        : AppColors.primary;

    return HoverLift(
      cursor: SystemMouseCursors.click,
      child: InkWell(
        onTap: () => Navigator.pushNamed(context, AppRoutes.carePlan(plan.id)),
        borderRadius: BorderRadius.circular(AppRadii.xxl),
        child: AppCard(
          padding: EdgeInsets.zero,
          borderColor: selected
              ? AppColors.primary.withValues(alpha: .36)
              : statusAccent.withValues(alpha: .14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                height: 4,
                color: selected ? AppColors.primary : statusAccent,
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
                            color: attention
                                ? AppColors.warningSoft
                                : plan.status == PlanStatus.completed
                                ? AppColors.successSoft
                                : AppColors.primaryLight,
                            borderRadius: BorderRadius.circular(AppRadii.xl),
                          ),
                          child: Icon(
                            attention
                                ? Icons.warning_amber_rounded
                                : plan.status == PlanStatus.completed
                                ? Icons.task_alt_rounded
                                : Icons.health_and_safety_outlined,
                            color: attention
                                ? AppColors.warningForeground
                                : plan.status == PlanStatus.completed
                                ? AppColors.successForeground
                                : AppColors.primary,
                            size: 21,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                demoPlanTitle(plan, context.appLanguage),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 17,
                                  height: 1.25,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 7),
                              PlanStatusBadge(status: plan.status),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        if (onDelete != null ||
                            (plan.status == PlanStatus.active &&
                                onComplete != null))
                          PopupMenuButton<String>(
                            tooltip: context.tr('plan_actions'),
                            onSelected: (value) {
                              if (value == 'complete') {
                                onComplete?.call(plan);
                              }
                              if (value == 'delete') {
                                onDelete?.call(plan);
                              }
                            },
                            itemBuilder: (_) => [
                              if (plan.status == PlanStatus.active &&
                                  onComplete != null)
                                PopupMenuItem(
                                  value: 'complete',
                                  child: Text(context.tr('complete_plan')),
                                ),
                              if (onDelete != null)
                                PopupMenuItem(
                                  value: 'delete',
                                  child: Text(context.tr('delete_plan')),
                                ),
                            ],
                          ),
                      ],
                    ),

                    const SizedBox(height: 14),

                    Row(
                      children: [
                        const Icon(
                          Icons.calendar_today_outlined,
                          size: 14,
                          color: AppColors.muted,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            context.tr(
                              'started_date',
                              values: {
                                'date': displayPlanStartDate(
                                  plan.startDate,
                                  context.appLanguage,
                                ),
                              },
                            ),
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.muted,
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(AppRadii.xl),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  context.tr('care_readiness'),
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: AppColors.muted,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              Text(
                                '$readiness%',
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(999),
                            child: LinearProgressIndicator(
                              value: readiness / 100,
                              minHeight: 7,
                              color: statusAccent,
                              backgroundColor: const Color(0xFFE6ECEB),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 14),

                    Container(
                      padding: const EdgeInsets.all(11),
                      decoration: BoxDecoration(
                        color: AppColors.primaryLight,
                        borderRadius: BorderRadius.circular(AppRadii.lg),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.schedule_outlined,
                            size: 16,
                            color: AppColors.primary,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text.rich(
                              TextSpan(
                                children: [
                                  TextSpan(
                                    text: '${context.tr('next_label')}: ',
                                    style: const TextStyle(
                                      color: AppColors.muted,
                                    ),
                                  ),
                                  TextSpan(
                                    text: demoPlanNextTask(
                                      plan,
                                      context.appLanguage,
                                    ),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.accentForeground,
                                    ),
                                  ),
                                ],
                              ),
                              style: const TextStyle(fontSize: 12, height: 1.4),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 12),

                    Row(
                      children: [
                        Checkbox(
                          value: selected,
                          onChanged: (value) =>
                              onSelectionChanged(plan, value ?? false),
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            selected
                                ? context.tr('clear_selection')
                                : context.tr('select_all'),
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.muted,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const Icon(
                          Icons.chevron_right_rounded,
                          color: AppColors.subtle,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class NewCarePlanScreen extends StatefulWidget {
  const NewCarePlanScreen({super.key, this.carePlanService});

  final CarePlanService? carePlanService;

  @override
  State<NewCarePlanScreen> createState() => _NewCarePlanScreenState();
}

class _NewCarePlanScreenState extends State<NewCarePlanScreen> {
  final TextEditingController _planNameController = TextEditingController();
  bool _creating = false;
  bool _nameTouched = false;

  @override
  void dispose() {
    _planNameController.dispose();
    super.dispose();
  }

  String get _normalizedPlanName =>
      normalizeCarePlanNameForInput(_planNameController.text);

  String? get _planNameErrorKey {
    final normalized = _normalizedPlanName;
    if (normalized.isEmpty) return 'plan_name_required';
    final length = normalized.runes.length;
    if (length < 2 || length > 80) return 'plan_name_length_error';
    return null;
  }

  bool get _canContinue => !_creating && _planNameErrorKey == null;

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
            onPressed: () =>
                Navigator.pushReplacementNamed(context, AppRoutes.carePlans),
            icon: const Icon(Icons.arrow_back, size: 17),
            label: Text(context.tr('care_plans')),
          ),
        ),
        PageHeader(
          title: context.tr('new_care_plan'),
          subtitle: context.tr('plan_name_helper'),
        ),
        TextField(
          key: const ValueKey('new_care_plan_name_field'),
          controller: _planNameController,
          textInputAction: TextInputAction.done,
          decoration: InputDecoration(
            labelText: '${context.tr('plan_name')} *',
            hintText: context.tr('plan_name_hint'),
            helperText: context.tr('plan_name_helper'),
            errorText: _nameTouched && _planNameErrorKey != null
                ? context.tr(_planNameErrorKey!)
                : null,
          ),
          onChanged: (_) => setState(() => _nameTouched = true),
          onSubmitted: (_) {
            if (_canContinue) _continue();
          },
        ),
        const SizedBox(height: 24),
        SafetyNote(text: context.tr('new_plan_safety_note')),
        const SizedBox(height: 24),
        Align(
          alignment: AlignmentDirectional.centerEnd,
          child: FilledButton.icon(
            key: const ValueKey('new_care_plan_continue_button'),
            onPressed: _canContinue ? _continue : null,
            iconAlignment: IconAlignment.end,
            icon: const Icon(Icons.arrow_forward, size: 17),
            label: Text(context.tr('continue')),
          ),
        ),
      ],
    ),
  );

  Future<void> _continue() async {
    setState(() => _nameTouched = true);
    if (!_canContinue) return;

    if (AuthSession.instance.isGuest) {
      Navigator.pushNamed(context, AppRoutes.carePlanUpload);
      return;
    }

    setState(() => _creating = true);
    try {
      final service = widget.carePlanService ?? CarePlanService.instance;
      final plan = await service.createPlan(_normalizedPlanName);
      if (!mounted) return;
      Navigator.pushNamed(
        context,
        AppRoutes.carePlanUpload,
        arguments: CarePlanUploadArgs(
          planId: plan.id,
          documentTypes: const [],
          guidedSetup: true,
        ),
      );
    } on CarePlanException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            localizedCarePlanExceptionMessage(error, context.appLanguage),
          ),
        ),
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
}
