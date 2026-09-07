import 'package:flutter/material.dart';

import '../core/app_routes.dart';
import '../core/app_theme.dart';
import '../data/demo_data.dart';
import '../services/auth_service.dart';
import '../services/care_plan_service.dart';
import '../widgets/app_shell.dart';
import '../widgets/status_badge.dart';
import '../widgets/ui.dart';
import 'simulation_screen.dart';

class CarePlanDetailScreen extends StatefulWidget {
  const CarePlanDetailScreen({
    required this.planId,
    this.initialTab = 0,
    super.key,
  });
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
      final detail = await CarePlanService.instance.fetchPlanDetail(
        widget.planId,
      );
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
    final openGaps = detail.gaps
        .where((gap) => gap.status != TaskStatus.resolved)
        .length;

    return AnimatedBuilder(
      animation: CareDemoState.instance,
      builder: (context, _) => AppShell(
        currentRoute: AppRoutes.carePlan(plan.id),
        title: 'Care Plan',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: TextButton.icon(
                onPressed: () => Navigator.pushReplacementNamed(
                  context,
                  AppRoutes.carePlans,
                ),
                icon: const Icon(Icons.arrow_back_rounded, size: 17),
                label: const Text('Care Plans'),
              ),
            ),
            const SizedBox(height: 6),

            FadeSlideIn(child: _planHero(detail)),

            const SizedBox(height: 18),

            FadeSlideIn(
              delay: const Duration(milliseconds: 60),
              child: _planMetrics(
                instructions: detail.instructions.length,
                scheduleItems: detail.tasks.length,
                openGaps: openGaps,
                documents: detail.documents.length,
              ),
            ),

            const SizedBox(height: 22),

            FadeSlideIn(
              delay: const Duration(milliseconds: 90),
              child: _tabSelector(),
            ),

            const SizedBox(height: 16),

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
                key: ValueKey(tab),
                child: _tabContent(detail),
              ),
            ),

            const SizedBox(height: 28),

            const FadeSlideIn(
              delay: Duration(milliseconds: 120),
              child: SafetyNote(
                text:
                    'This plan reflects instructions given by your healthcare professional. SehatMate does not change medical treatment.',
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _planHero(CarePlanDetailData detail) {
    final plan = detail.plan;

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 620;

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
                blurRadius: 30,
                spreadRadius: -12,
                offset: Offset(0, 15),
              ),
            ],
          ),
          child: Stack(
            children: [
              PositionedDirectional(
                top: -64,
                end: -48,
                child: Container(
                  width: 180,
                  height: 180,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Color(0x16FFFFFF),
                  ),
                ),
              ),
              PositionedDirectional(
                bottom: -78,
                start: -52,
                child: Container(
                  width: 180,
                  height: 180,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Color(0x0FFFFFFF),
                  ),
                ),
              ),
              if (compact)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _planHeroHeading(plan),
                    const SizedBox(height: 18),
                    _readinessPanel(plan.readiness, compact: true),
                  ],
                )
              else
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(child: _planHeroHeading(plan)),
                    const SizedBox(width: 24),
                    _readinessPanel(plan.readiness),
                  ],
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _planHeroHeading(DemoPlan plan) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0x20FFFFFF),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: const Color(0x2FFFFFFF)),
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
          plan.title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 29,
            height: 1.08,
            fontWeight: FontWeight.w800,
            letterSpacing: -.45,
          ),
        ),
        const SizedBox(height: 9),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _heroInfoChip(
              icon: Icons.calendar_today_outlined,
              label: 'Started ${plan.startDate}',
            ),
            _heroInfoChip(
              icon: Icons.schedule_outlined,
              label: 'Next: ${plan.nextTask}',
            ),
          ],
        ),
        const SizedBox(height: 15),
        PlanStatusBadge(status: plan.status),
      ],
    );
  }

  Widget _heroInfoChip({required IconData icon, required String label}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0x18FFFFFF),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0x24FFFFFF)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.white),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              style: const TextStyle(
                color: Color(0xE8FFFFFF),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _readinessPanel(int readiness, {bool compact = false}) {
    final safeReadiness = readiness.clamp(0, 100);

    return Container(
      width: compact ? double.infinity : 170,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0x1FFFFFFF),
        borderRadius: BorderRadius.circular(AppRadii.xxl),
        border: Border.all(color: const Color(0x2FFFFFFF)),
      ),
      child: compact
          ? Row(
              children: [
                _readinessCircle(safeReadiness),
                const SizedBox(width: 14),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Care readiness',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      SizedBox(height: 3),
                      Text(
                        'How ready this plan is for day-to-day use.',
                        style: TextStyle(
                          color: Color(0xCFFFFFFF),
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
                _readinessCircle(safeReadiness),
                const SizedBox(height: 10),
                const Text(
                  'Care readiness',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
    );
  }

  Widget _readinessCircle(int readiness) {
    return SizedBox(
      width: 68,
      height: 68,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: 68,
            height: 68,
            child: CircularProgressIndicator(
              value: readiness / 100,
              strokeWidth: 6,
              strokeCap: StrokeCap.round,
              backgroundColor: const Color(0x28FFFFFF),
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

  Widget _planMetrics({
    required int instructions,
    required int scheduleItems,
    required int openGaps,
    required int documents,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 760 ? 4 : 2;
        const gap = 10.0;
        final width = (constraints.maxWidth - ((columns - 1) * gap)) / columns;

        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            _planMetric(
              width: width,
              value: instructions,
              label: 'Instructions',
              icon: Icons.fact_check_outlined,
              background: AppColors.primaryLight,
              foreground: AppColors.primary,
            ),
            _planMetric(
              width: width,
              value: scheduleItems,
              label: 'Schedule items',
              icon: Icons.calendar_month_outlined,
              background: AppColors.infoSoft,
              foreground: AppColors.info,
            ),
            _planMetric(
              width: width,
              value: openGaps,
              label: 'Open care gaps',
              icon: Icons.health_and_safety_outlined,
              background: openGaps > 0
                  ? AppColors.warningSoft
                  : AppColors.successSoft,
              foreground: openGaps > 0 ? AppColors.warning : AppColors.success,
            ),
            _planMetric(
              width: width,
              value: documents,
              label: 'Documents',
              icon: Icons.description_outlined,
              background: const Color(0xFFF1F5F9),
              foreground: AppColors.muted,
            ),
          ],
        );
      },
    );
  }

  Widget _planMetric({
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

  Widget _tabSelector() {
    const tabs = [
      (0, 'Instructions', Icons.fact_check_outlined),
      (1, 'Schedule', Icons.calendar_month_outlined),
      (2, 'Simulation', Icons.auto_graph_outlined),
      (3, 'Care Gaps', Icons.health_and_safety_outlined),
      (4, 'Documents', Icons.description_outlined),
    ];

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
        children: tabs.map((item) {
          final active = tab == item.$1;

          return InkWell(
            onTap: () => setState(() => tab = item.$1),
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
                    item.$3,
                    size: 16,
                    color: active ? AppColors.primary : AppColors.muted,
                  ),
                  const SizedBox(width: 7),
                  Text(
                    item.$2,
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
        }).toList(),
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

        return Column(
          children: detail.instructions
              .asMap()
              .entries
              .map(
                (entry) => FadeSlideIn(
                  delay: Duration(milliseconds: 35 * entry.key.clamp(0, 5)),
                  child: _InstructionRow(task: entry.value),
                ),
              )
              .toList(),
        );

      case 1:
        if (detail.tasks.isEmpty) {
          return _premiumEmptySchedule();
        }

        final scheduleBlocked =
            detail.tasks.any((task) => task.status == TaskStatus.atRisk) ||
            _unsavedPeriodChanges.isNotEmpty;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppCard(
              color: const Color(0xFFF0FDFA),
              borderColor: const Color(0xFFCCFBF1),
              padding: const EdgeInsets.all(15),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: AppColors.primaryLight,
                      borderRadius: BorderRadius.circular(AppRadii.lg),
                    ),
                    child: const Icon(
                      Icons.auto_awesome_outlined,
                      color: AppColors.primary,
                      size: 19,
                    ),
                  ),
                  const SizedBox(width: 11),
                  const Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(top: 2),
                      child: Text(
                        'AI copied explicit timings and marked inferred slots for confirmation.',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.muted,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    onPressed: _generatingSchedule ? null : _generateSchedule,
                    icon: _generatingSchedule
                        ? const SizedBox(
                            width: 15,
                            height: 15,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.refresh_rounded, size: 17),
                    label: const Text('Regenerate'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            ...detail.tasks.asMap().entries.map(
              (entry) => FadeSlideIn(
                delay: Duration(milliseconds: 35 * entry.key.clamp(0, 5)),
                child: _ScheduleRow(
                  task: entry.value,
                  period:
                      _periodOverrides[entry.value.id] ??
                      _periodFrom('${entry.value.time} ${entry.value.note}'),
                  displayTime:
                      _timeOverrides[entry.value.id] ?? entry.value.time,
                  periodChanged: _unsavedPeriodChanges.contains(entry.value.id),
                  onEditPeriod: () => _editSchedulePeriod(entry.value),
                  onSetTime: () => _confirmScheduleItem(entry.value),
                ),
              ),
            ),
            const SizedBox(height: 6),
            Container(
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
                  onPressed: scheduleBlocked
                      ? null
                      : () => Navigator.pushNamed(
                          context,
                          AppRoutes.realityCheck,
                          arguments: CareFlowArgs(planId: widget.planId),
                        ),
                  icon: Icon(
                    scheduleBlocked
                        ? Icons.schedule_outlined
                        : Icons.arrow_forward_rounded,
                    size: 18,
                  ),
                  label: Text(
                    scheduleBlocked
                        ? 'Confirm schedule items first'
                        : 'Continue to Reality Check',
                  ),
                ),
              ),
            ),
          ],
        );

      case 2:
        return FadeSlideIn(
          child: AppCard(
            padding: const EdgeInsets.all(10),
            child: SimulationView(compact: true, planId: widget.planId),
          ),
        );

      case 3:
        final openGaps = detail.gaps
            .where((gap) => gap.status != TaskStatus.resolved)
            .toList();

        if (openGaps.isEmpty) {
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 34),
            decoration: BoxDecoration(
              color: const Color(0xFFF0FDFA),
              borderRadius: BorderRadius.circular(AppRadii.xxxl),
              border: Border.all(color: const Color(0xFFCCFBF1)),
            ),
            child: const Column(
              children: [
                Icon(
                  Icons.verified_user_outlined,
                  size: 34,
                  color: AppColors.success,
                ),
                SizedBox(height: 12),
                Text(
                  'No open care gaps',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                ),
                SizedBox(height: 5),
                Text(
                  'There are no unresolved care-plan issues right now.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: AppColors.muted),
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
                          padding: const EdgeInsets.all(16),
                          borderColor: AppColors.warning.withValues(alpha: .18),
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
            title: 'No documents yet',
            description:
                'Upload a prescription or discharge summary to build this plan.',
            action: FilledButton.icon(
              onPressed: () => Navigator.pushNamed(
                context,
                AppRoutes.carePlanUpload,
                arguments: CarePlanUploadArgs(
                  planId: detail.plan.id,
                  documentTypes: const [],
                ),
              ),
              icon: const Icon(Icons.upload_file_outlined, size: 18),
              label: const Text('Upload document'),
            ),
          );
        }

        return Column(
          children: documents
              .asMap()
              .entries
              .map(
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
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  '${entry.value.type} · ${entry.value.pages} page${entry.value.pages == 1 ? '' : 's'} · ${entry.value.date}',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: AppColors.muted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Icon(
                            Icons.verified_outlined,
                            size: 19,
                            color: AppColors.primary,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              )
              .toList(),
        );
    }
  }

  Widget _premiumEmptySchedule() {
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
          const Text(
            'No scheduled tasks yet',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          const Text(
            'Generate a schedule from the verified prescription instructions.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.muted, fontSize: 13, height: 1.4),
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
              _generatingSchedule ? 'Generating…' : 'Generate schedule',
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _generateSchedule() async {
    if (AuthSession.instance.isGuest) {
      showDemoMessage(
        context,
        'AI schedule generation is available after sign in.',
      );
      return;
    }
    setState(() => _generatingSchedule = true);
    try {
      await CarePlanService.instance.generateSchedule(widget.planId);
      await _loadPlan();
      if (mounted) {
        showDemoMessage(
          context,
          'Schedule draft generated from verified instructions.',
        );
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

  Future<void> _confirmScheduleItem(DemoTask task) async {
    final period =
        _periodOverrides[task.id] ?? _periodFrom('${task.time} ${task.note}');
    final initialTime = _parseTime(task.time) ?? _defaultTime(period);
    final selected = await _showRestrictedTimePicker(period, initialTime);
    if (selected == null || !mounted) return;
    final scheduleTime =
        '${selected.hour.toString().padLeft(2, '0')}:${selected.minute.toString().padLeft(2, '0')}';
    try {
      await CarePlanService.instance.confirmScheduleItem(
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
        showDemoMessage(
          context,
          '$period reminder set for ${selected.format(context)}.',
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

  Future<void> _editSchedulePeriod(DemoTask task) async {
    final current =
        _periodOverrides[task.id] ?? _periodFrom('${task.time} ${task.note}');
    final period = await showDialog<String>(
      context: context,
      builder: (dialogContext) => SimpleDialog(
        title: const Text('Edit time period'),
        children: ['Morning', 'Afternoon', 'Evening', 'Night']
            .map(
              (value) => ListTile(
                leading: Icon(
                  value == current
                      ? Icons.radio_button_checked
                      : Icons.radio_button_off,
                  color: AppColors.primary,
                ),
                title: Text(value),
                subtitle: Text(_periodDescription(value)),
                onTap: () => Navigator.pop(dialogContext, value),
              ),
            )
            .toList(),
      ),
    );
    if (period == null || !mounted) return;
    setState(() {
      _periodOverrides[task.id] = period;
      _unsavedPeriodChanges.add(task.id);
    });
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
          title: Text('Set $period time'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Allowed: ${_periodDescription(period)}',
                style: const TextStyle(color: AppColors.muted),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<int>(
                      initialValue: hour,
                      isExpanded: true,
                      decoration: const InputDecoration(labelText: 'Hour'),
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
                      decoration: const InputDecoration(labelText: 'Minute'),
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
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(
                dialogContext,
                TimeOfDay(hour: hour, minute: minute),
              ),
              child: const Text('Use this time'),
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

  Widget _loadingView() => AppShell(
    currentRoute: AppRoutes.carePlans,
    title: 'Care Plan',
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _loadingBar(width: 95, height: 14),
        const SizedBox(height: 16),
        AppCard(
          padding: const EdgeInsets.all(22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _loadingBar(width: 110, height: 12),
              const SizedBox(height: 14),
              _loadingBar(width: 240, height: 28),
              const SizedBox(height: 10),
              _loadingBar(width: 190, height: 12),
              const SizedBox(height: 22),
              _loadingBar(width: double.infinity, height: 10),
            ],
          ),
        ),
        const SizedBox(height: 16),
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
                        _loadingBar(width: 38, height: 38, radius: 12),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _loadingBar(width: 45, height: 18),
                              const SizedBox(height: 6),
                              _loadingBar(width: 80, height: 10),
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
              _loadingBar(width: 180, height: 16),
              const SizedBox(height: 14),
              _loadingBar(width: double.infinity, height: 70, radius: 14),
              const SizedBox(height: 10),
              _loadingBar(width: double.infinity, height: 70, radius: 14),
            ],
          ),
        ),
      ],
    ),
  );

  Widget _loadingBar({
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
    title: 'Care Plan',
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
              const Text(
                'Care plan not found',
                style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 6),
              Text(
                message ?? 'This plan may have been removed.',
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
                label: const Text('Back to Care Plans'),
              ),
            ],
          ),
        ),
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
                  colors: [Color(0xFFCCFBF1), Color(0xFFE6FFFA)],
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
                    const SizedBox(height: 8),
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
            StatusBadge(status: task.status),
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

  @override
  Widget build(BuildContext context) {
    final needsTime = task.status == TaskStatus.atRisk || periodChanged;
    final formattedTime = _formattedTime(displayTime);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: HoverLift(
        child: AppCard(
          padding: const EdgeInsets.all(16),
          borderColor: needsTime
              ? AppColors.warning.withValues(alpha: .24)
              : AppColors.border,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 620;

              final periodPanel = Container(
                padding: const EdgeInsets.all(11),
                decoration: BoxDecoration(
                  color: needsTime
                      ? AppColors.warningSoft
                      : AppColors.primaryLight,
                  borderRadius: BorderRadius.circular(AppRadii.xl),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _periodIcon(period),
                          size: 17,
                          color: needsTime
                              ? AppColors.warningForeground
                              : AppColors.primary,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          period,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: needsTime
                                ? AppColors.warningForeground
                                : AppColors.accentForeground,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    InkWell(
                      onTap: onEditPeriod,
                      borderRadius: BorderRadius.circular(AppRadii.sm),
                      child: const Padding(
                        padding: EdgeInsets.symmetric(vertical: 2),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.edit_outlined,
                              size: 13,
                              color: AppColors.muted,
                            ),
                            SizedBox(width: 4),
                            Text(
                              'Edit period',
                              style: TextStyle(
                                fontSize: 11,
                                color: AppColors.muted,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (periodChanged) ...[
                      const SizedBox(height: 5),
                      const Text(
                        'Set a new time',
                        style: TextStyle(
                          fontSize: 10,
                          color: AppColors.warningForeground,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ],
                ),
              );

              final taskInfo = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    task.title,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  if (task.note.trim().isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      task.note,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.muted,
                        height: 1.35,
                      ),
                    ),
                  ],
                  if (formattedTime != null) ...[
                    const SizedBox(height: 9),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: needsTime
                            ? AppColors.warningSoft
                            : const Color(0xFFF0FDFA),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.schedule_rounded,
                            size: 14,
                            color: needsTime
                                ? AppColors.warningForeground
                                : AppColors.primary,
                          ),
                          const SizedBox(width: 5),
                          Flexible(
                            child: Text(
                              formattedTime,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: needsTime
                                    ? AppColors.warningForeground
                                    : AppColors.primary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              );

              final action = OutlinedButton.icon(
                onPressed: onSetTime,
                icon: Icon(
                  needsTime
                      ? Icons.add_alarm_outlined
                      : Icons.edit_calendar_outlined,
                  size: 17,
                ),
                label: Text(needsTime ? 'Set time' : 'Edit time'),
              );

              if (compact) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    periodPanel,
                    const SizedBox(height: 12),
                    taskInfo,
                    const SizedBox(height: 13),
                    action,
                  ],
                );
              }

              return Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  SizedBox(width: 150, child: periodPanel),
                  const SizedBox(width: 14),
                  Expanded(child: taskInfo),
                  const SizedBox(width: 12),
                  action,
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  static IconData _periodIcon(String period) {
    return switch (period) {
      'Morning' => Icons.wb_sunny_outlined,
      'Afternoon' => Icons.light_mode_outlined,
      'Evening' => Icons.wb_twilight_outlined,
      'Night' => Icons.nightlight_outlined,
      _ => Icons.schedule_outlined,
    };
  }
}
