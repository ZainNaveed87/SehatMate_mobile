import 'package:flutter/material.dart';

import '../core/app_routes.dart';
import '../core/app_theme.dart';
import '../data/demo_data.dart';
import '../localization/language_scope.dart';
import '../widgets/app_shell.dart';
import '../widgets/page_header.dart';
import '../widgets/status_badge.dart';
import '../widgets/ui.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  String mode = 'Week';
  String selected = demoDays.first.iso;

  @override
  Widget build(BuildContext context) {
    final state = CareDemoState.instance;
    return AnimatedBuilder(
      animation: state,
      builder: (context, _) {
        final day = demoDays.firstWhere((item) => item.iso == selected);
        final dayTasks = state.tasks.where((task) => task.day == selected).toList();
        return AppShell(
          currentRoute: AppRoutes.calendar,
          title: context.tr('care_calendar'),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              PageHeader(title: context.tr('care_calendar'), subtitle: context.tr('care_calendar_subtitle')),
              Align(
                alignment: Alignment.centerLeft,
                child: AppTabs<String>(
                  tabs: [
                    AppTab('Week', context.tr('week')),
                    AppTab('Month', context.tr('month')),
                  ],
                  selected: mode,
                  onChanged: (value) => setState(() => mode = value),
                ),
              ),
              const SizedBox(height: 20),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                child: mode == 'Week'
                    ? Column(
                        key: const ValueKey('week'),
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          LayoutBuilder(
                            builder: (context, constraints) => GridView.count(
                              crossAxisCount: 7,
                              crossAxisSpacing: 8,
                              mainAxisSpacing: 8,
                              childAspectRatio: constraints.maxWidth < 620 ? .62 : 1.05,
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              children: demoDays.map((item) {
                                final count = state.tasks.where((task) => task.day == item.iso).length;
                                final active = selected == item.iso;
                                return InkWell(
                                  onTap: () => setState(() => selected = item.iso),
                                  borderRadius: BorderRadius.circular(AppRadii.xl),
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 180),
                                    padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 8),
                                    decoration: BoxDecoration(
                                      color: active ? AppColors.primaryLight : AppColors.card,
                                      border: Border.all(color: active ? AppColors.primary : AppColors.border),
                                      borderRadius: BorderRadius.circular(AppRadii.xl),
                                    ),
                                    child: FittedBox(
                                      fit: BoxFit.scaleDown,
                                      child: Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Text(_demoDayShort(context, item), style: const TextStyle(fontSize: 12, color: AppColors.muted)),
                                          Text('${item.number}', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
                                          Text(context.tr('task_count', values: {'count': count}), style: const TextStyle(fontSize: 11, color: AppColors.muted)),
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                          const SizedBox(height: 24),
                          Text('${_demoDayLong(context, day)} · ${_demoDateLabel(context, day)}', style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w600)),
                          const SizedBox(height: 12),
                          if (dayTasks.isEmpty)
                            EmptyState(title: context.tr('no_tasks_this_day'), description: context.tr('nothing_scheduled_for_date'))
                          else
                            ...dayTasks.asMap().entries.map((entry) => Padding(
                                  padding: const EdgeInsets.only(bottom: 10),
                                  child: FadeSlideIn(
                                    child: _CalendarTask(task: entry.value),
                                  ),
                                )),
                        ],
                      )
                    : AppCard(
                        key: const ValueKey('month'),
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            GridView.count(
                              crossAxisCount: 7,
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              childAspectRatio: 1.15,
                              children: const ['mon_initial', 'tue_initial', 'wed_initial', 'thu_initial', 'fri_initial', 'sat_initial', 'sun_initial']
                                  .map((label) => Center(child: Text(context.tr(label), style: const TextStyle(fontSize: 12, color: AppColors.muted, fontWeight: FontWeight.w600))))
                                  .toList(),
                            ),
                            GridView.count(
                              crossAxisCount: 7,
                              crossAxisSpacing: 6,
                              mainAxisSpacing: 6,
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              children: List.generate(31, (index) {
                                final number = index + 1;
                                final matching = demoDays.where((item) => item.number == number).firstOrNull;
                                final count = matching == null ? 0 : state.tasks.where((task) => task.day == matching.iso).length;
                                return Container(
                                  decoration: BoxDecoration(
                                    color: count > 0 ? AppColors.primaryLight : AppColors.card,
                                    border: Border.all(color: count > 0 ? AppColors.primary.withValues(alpha: .4) : AppColors.border),
                                    borderRadius: BorderRadius.circular(AppRadii.lg),
                                  ),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text('$number', style: const TextStyle(fontSize: 13)),
                                      if (count > 0) ...[
                                        const SizedBox(height: 4),
                                        const CircleAvatar(radius: 3, backgroundColor: AppColors.primary),
                                      ],
                                    ],
                                  ),
                                );
                              }),
                            ),
                          ],
                        ),
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _CalendarTask extends StatelessWidget {
  const _CalendarTask({required this.task});
  final DemoTask task;

  @override
  Widget build(BuildContext context) => AppCard(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            SizedBox(width: 76, child: Text(task.time, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.muted))),
            TaskIcon(icon: task.icon),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(demoTaskTitle(task, context.appLanguage), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)), Text(demoTaskNote(task, context.appLanguage), style: const TextStyle(fontSize: 14, color: AppColors.muted))])),
            const SizedBox(width: 8),
            StatusBadge(status: task.status),
          ],
        ),
      );
}

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = CareDemoState.instance;
    return AnimatedBuilder(
      animation: state,
      builder: (context, _) => AppShell(
        currentRoute: AppRoutes.notifications,
        title: context.tr('notifications'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            PageHeader(
              title: context.tr('notifications'),
              subtitle: context.tr('notifications_subtitle'),
              action: OutlinedButton(onPressed: state.markAllRead, child: Text(context.tr('mark_all_read'))),
            ),
            if (state.notifications.isEmpty)
              EmptyState(icon: Icons.notifications_none, title: context.tr('nothing_new'), description: context.tr('all_caught_up'))
            else
              for (final group in const ['Today', 'Yesterday']) ...[
                if (state.notifications.any((notification) => notification.group == group)) ...[
                  Text(group == 'Today' ? context.tr('today') : context.tr('yesterday'), style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 12),
                  ...state.notifications.where((notification) => notification.group == group).map((notification) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: InkWell(
                          onTap: () => state.markRead(notification.id),
                          borderRadius: BorderRadius.circular(AppRadii.xxl),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: notification.read ? AppColors.card : AppColors.primaryLight,
                              border: Border.all(color: AppColors.border),
                              borderRadius: BorderRadius.circular(AppRadii.xxl),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(notification.kind == null ? Icons.notifications_none : _kindIcon(notification.kind!), size: 21, color: AppColors.primary),
                                const SizedBox(width: 12),
                                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(demoNotificationTitle(notification, context.appLanguage), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)), Text(demoNotificationDetail(notification, context.appLanguage), style: const TextStyle(fontSize: 14, color: AppColors.muted))])),
                                if (!notification.read) const Padding(padding: EdgeInsets.only(top: 7), child: CircleAvatar(radius: 4, backgroundColor: AppColors.primary)),
                              ],
                            ),
                          ),
                        ),
                      )),
                  const SizedBox(height: 12),
                ],
              ],
          ],
        ),
      ),
    );
  }
}

class DocumentsScreen extends StatelessWidget {
  const DocumentsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = CareDemoState.instance;
    return AnimatedBuilder(
      animation: state,
      builder: (context, _) => AppShell(
        currentRoute: AppRoutes.documents,
        title: context.tr('documents'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            PageHeader(
              title: context.tr('documents'),
              subtitle: context.tr('documents_subtitle'),
              action: FilledButton.icon(onPressed: () => Navigator.pushNamed(context, AppRoutes.carePlanNew), icon: const Icon(Icons.upload, size: 18), label: Text(context.tr('upload'))),
            ),
            if (state.documents.isEmpty)
              EmptyState(icon: Icons.description_outlined, title: context.tr('no_documents_yet'), description: context.tr('upload_prescription_or_discharge'), action: FilledButton(onPressed: () => Navigator.pushNamed(context, AppRoutes.carePlanNew), child: Text(context.tr('upload_document'))))
            else
              LayoutBuilder(
                builder: (context, constraints) {
                  final columns = constraints.maxWidth >= 900 ? 3 : constraints.maxWidth >= 560 ? 2 : 1;
                  return GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: columns, mainAxisSpacing: 16, crossAxisSpacing: 16, childAspectRatio: columns == 1 ? 1.55 : .92),
                    itemCount: state.documents.length,
                    itemBuilder: (context, index) {
                      final document = state.documents[index];
                      return FadeSlideIn(
                        child: AppCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(child: Container(width: double.infinity, decoration: BoxDecoration(color: AppColors.secondary, borderRadius: BorderRadius.circular(AppRadii.xl)), child: const Icon(Icons.description_outlined, size: 38, color: AppColors.primary))),
                              const SizedBox(height: 12),
                              Text(document.name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                              Text(context.tr('document_pages_summary', values: {'type': document.type, 'pages': document.pages, 'date': document.date}), style: const TextStyle(fontSize: 13, color: AppColors.muted)),
                              Text(document.plan, style: const TextStyle(fontSize: 13, color: AppColors.subtle)),
                              const SizedBox(height: 12),
                              Wrap(spacing: 8, children: [
                                OutlinedButton.icon(onPressed: () => showDemoMessage(context, context.tr('document_preview_demo_unavailable')), icon: const Icon(Icons.visibility_outlined, size: 17), label: Text(context.tr('view'))),
                                TextButton.icon(onPressed: () { state.removeDocument(document.id); showDemoMessage(context, context.tr('document_removed')); }, icon: const Icon(Icons.delete_outline, size: 17), label: Text(context.tr('delete'))),
                              ]),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            const SizedBox(height: 24),
            SafetyNote(text: context.tr('documents_safety_note')),
          ],
        ),
      ),
    );
  }
}

class ProgressScreen extends StatelessWidget {
  const ProgressScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = CareDemoState.instance;
    return AnimatedBuilder(
      animation: state,
      builder: (context, _) {
        final completed = state.tasks.where((task) => task.completed).length;
        final resolved = state.gaps.where((gap) => gap.status == TaskStatus.resolved).length;
        final maxReadiness = readinessTrend.map((point) => point.$2).fold<int>(state.readiness, (highest, value) => value > highest ? value : highest);
        final stats = [
          (context.tr('care_readiness'), '${state.readiness}%'),
          (context.tr('tasks_completed'), '$completed/${state.tasks.length}'),
          (context.tr('gaps_resolved'), '$resolved/${state.gaps.length}'),
          (context.tr('understanding'), '${state.understanding}%'),
        ];
        return AppShell(
          currentRoute: AppRoutes.progress,
          title: context.tr('progress'),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              PageHeader(title: context.tr('care_progress'), subtitle: context.tr('care_progress_subtitle')),
              LayoutBuilder(builder: (context, constraints) {
                final columns = constraints.maxWidth >= 900 ? 4 : constraints.maxWidth >= 480 ? 2 : 1;
                return GridView.count(
                  crossAxisCount: columns,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  childAspectRatio: columns == 1 ? 3.2 : 1.55,
                  children: stats.map((stat) => AppCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [Text(stat.$1, style: const TextStyle(fontSize: 14, color: AppColors.muted)), Text(stat.$2, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w700, color: AppColors.primary))]))).toList(),
                );
              }),
              const SizedBox(height: 24),
              AppCard(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(context.tr('care_readiness_trend'), style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 22),
                    SizedBox(
                      height: 220,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: readinessTrend.map((point) => Expanded(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 7), child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [Text('${point.$2}%', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)), const SizedBox(height: 7), TweenAnimationBuilder<double>(tween: Tween(begin: 0, end: point.$2 / maxReadiness), duration: const Duration(milliseconds: 500), curve: Curves.easeOut, builder: (context, value, _) => Container(height: 150 * value, decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: .85), borderRadius: const BorderRadius.vertical(top: Radius.circular(8))))), const SizedBox(height: 7), Text(_readinessTrendLabel(context, point.$1), style: const TextStyle(fontSize: 13, color: AppColors.muted))])))).toList(),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              LayoutBuilder(builder: (context, constraints) {
                final cards = [
                  AppCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(context.tr('understanding_score'), style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w600)), const SizedBox(height: 16), LinearProgressIndicator(value: state.understanding / 100, minHeight: 10, borderRadius: BorderRadius.circular(99)), const SizedBox(height: 12), Text(context.tr('latest_teach_back_basis'), style: const TextStyle(fontSize: 14, color: AppColors.muted))])),
                  AppCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(context.tr('most_common_barriers'), style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w600)), const SizedBox(height: 14), ...[(context.tr('transport'), 3, 1.0), (context.tr('caregiver_availability'), 2, .66), (context.tr('medicine_access'), 1, .33)].map((item) => Padding(padding: const EdgeInsets.only(bottom: 10), child: Column(children: [Row(children: [Expanded(child: Text(item.$1)), Text(context.tr('times_count', values: {'count': item.$2}), style: const TextStyle(color: AppColors.muted))]), const SizedBox(height: 5), LinearProgressIndicator(value: item.$3, minHeight: 6, borderRadius: BorderRadius.circular(99))]))) ])),
                ];
                return constraints.maxWidth >= 760 ? Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(child: cards[0]), const SizedBox(width: 16), Expanded(child: cards[1])]) : Column(children: [cards[0], const SizedBox(height: 16), cards[1]]);
              }),
              const SizedBox(height: 24),
              SafetyNote(text: context.tr('progress_demo_safety_note')),
            ],
          ),
        );
      },
    );
  }
}

String _demoDayShort(BuildContext context, DemoDay day) => context.tr(
      switch (day.short) {
        'Mon' => 'mon_short',
        'Tue' => 'tue_short',
        'Wed' => 'wed_short',
        'Thu' => 'thu_short',
        'Fri' => 'fri_short',
        'Sat' => 'sat_short',
        _ => 'sun_short',
      },
    );

String _demoDayLong(BuildContext context, DemoDay day) => context.tr(
      switch (day.label) {
        'Monday' => 'monday',
        'Tuesday' => 'tuesday',
        'Wednesday' => 'wednesday',
        'Thursday' => 'thursday',
        'Friday' => 'friday',
        'Saturday' => 'saturday',
        _ => 'sunday',
      },
    );

String _demoDateLabel(BuildContext context, DemoDay day) => context.tr(
      'progress_day_label',
      values: {
        'weekday': '',
        'day': day.number,
        'month': context.tr('aug_short'),
      },
    ).trim();

String _readinessTrendLabel(BuildContext context, String value) {
  final match = RegExp(r'^Week (\d+)$').firstMatch(value);
  if (match == null) return value;
  return context.tr('week_number', values: {'number': match.group(1)});
}

IconData _kindIcon(TaskKind kind) => switch (kind) {
      TaskKind.medicine => Icons.medication_outlined,
      TaskKind.lab => Icons.biotech_outlined,
      TaskKind.visit => Icons.local_hospital_outlined,
      TaskKind.dressing => Icons.healing_outlined,
      TaskKind.caregiver => Icons.handshake_outlined,
    };
