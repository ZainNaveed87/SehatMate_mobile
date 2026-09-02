import 'package:flutter/material.dart';

import '../core/app_routes.dart';
import '../core/app_theme.dart';
import '../data/demo_data.dart';
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
          title: 'Care Calendar',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const PageHeader(title: 'Care Calendar', subtitle: 'Everything scheduled for this care plan.'),
              Align(
                alignment: Alignment.centerLeft,
                child: AppTabs<String>(
                  tabs: const [AppTab('Week', 'Week'), AppTab('Month', 'Month')],
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
                                          Text(item.short, style: const TextStyle(fontSize: 12, color: AppColors.muted)),
                                          Text('${item.number}', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
                                          Text('$count task${count == 1 ? '' : 's'}', style: const TextStyle(fontSize: 11, color: AppColors.muted)),
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                          const SizedBox(height: 24),
                          Text('${day.label} · ${day.dateLabel}', style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w600)),
                          const SizedBox(height: 12),
                          if (dayTasks.isEmpty)
                            const EmptyState(title: 'No tasks this day', description: 'Nothing is scheduled for this date.')
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
                              children: const ['M', 'T', 'W', 'T', 'F', 'S', 'S']
                                  .map((label) => Center(child: Text(label, style: const TextStyle(fontSize: 12, color: AppColors.muted, fontWeight: FontWeight.w600))))
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
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(task.title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)), Text(task.note, style: const TextStyle(fontSize: 14, color: AppColors.muted))])),
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
        title: 'Notifications',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            PageHeader(
              title: 'Notifications',
              subtitle: 'Care reminders and updates.',
              action: OutlinedButton(onPressed: state.markAllRead, child: const Text('Mark all read')),
            ),
            if (state.notifications.isEmpty)
              const EmptyState(icon: Icons.notifications_none, title: 'Nothing new', description: "You're all caught up.")
            else
              for (final group in const ['Today', 'Yesterday']) ...[
                if (state.notifications.any((notification) => notification.group == group)) ...[
                  Text(group, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
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
                                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(notification.title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)), Text(notification.detail, style: const TextStyle(fontSize: 14, color: AppColors.muted))])),
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
        title: 'Documents',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            PageHeader(
              title: 'Documents',
              subtitle: 'Every document used to build your care plans.',
              action: FilledButton.icon(onPressed: () => Navigator.pushNamed(context, AppRoutes.carePlanNew), icon: const Icon(Icons.upload, size: 18), label: const Text('Upload')),
            ),
            if (state.documents.isEmpty)
              EmptyState(icon: Icons.description_outlined, title: 'No documents yet', description: 'Upload a prescription or discharge summary to get started.', action: FilledButton(onPressed: () => Navigator.pushNamed(context, AppRoutes.carePlanNew), child: const Text('Upload document')))
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
                              Text('${document.type} · ${document.pages} page${document.pages == 1 ? '' : 's'} · ${document.date}', style: const TextStyle(fontSize: 13, color: AppColors.muted)),
                              Text(document.plan, style: const TextStyle(fontSize: 13, color: AppColors.subtle)),
                              const SizedBox(height: 12),
                              Wrap(spacing: 8, children: [
                                OutlinedButton.icon(onPressed: () => showDemoMessage(context, 'Document preview is not available in this demo.'), icon: const Icon(Icons.visibility_outlined, size: 17), label: const Text('View')),
                                TextButton.icon(onPressed: () { state.removeDocument(document.id); showDemoMessage(context, 'Document removed'); }, icon: const Icon(Icons.delete_outline, size: 17), label: const Text('Delete')),
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
            const SafetyNote(text: 'Documents are stored only to build and verify your care plan.'),
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
          ('Care readiness', '${state.readiness}%'),
          ('Tasks completed', '$completed/${state.tasks.length}'),
          ('Gaps resolved', '$resolved/${state.gaps.length}'),
          ('Understanding', '${state.understanding}%'),
        ];
        return AppShell(
          currentRoute: AppRoutes.progress,
          title: 'Progress',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const PageHeader(title: 'Care Progress', subtitle: 'How practical the care plan has become over time.'),
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
                    const Text('Care readiness trend', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 22),
                    SizedBox(
                      height: 220,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: readinessTrend.map((point) => Expanded(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 7), child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [Text('${point.$2}%', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)), const SizedBox(height: 7), TweenAnimationBuilder<double>(tween: Tween(begin: 0, end: point.$2 / maxReadiness), duration: const Duration(milliseconds: 500), curve: Curves.easeOut, builder: (context, value, _) => Container(height: 150 * value, decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: .85), borderRadius: const BorderRadius.vertical(top: Radius.circular(8))))), const SizedBox(height: 7), Text(point.$1, style: const TextStyle(fontSize: 13, color: AppColors.muted))])))).toList(),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              LayoutBuilder(builder: (context, constraints) {
                final cards = [
                  AppCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('Understanding score', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w600)), const SizedBox(height: 16), LinearProgressIndicator(value: state.understanding / 100, minHeight: 10, borderRadius: BorderRadius.circular(99)), const SizedBox(height: 12), const Text('Based on your latest Teach-Back session.', style: TextStyle(fontSize: 14, color: AppColors.muted))])),
                  AppCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('Most common barriers', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w600)), const SizedBox(height: 14), ...[('Transport', 3, 1.0), ('Caregiver availability', 2, .66), ('Medicine access', 1, .33)].map((item) => Padding(padding: const EdgeInsets.only(bottom: 10), child: Column(children: [Row(children: [Expanded(child: Text(item.$1)), Text('${item.$2} times', style: const TextStyle(color: AppColors.muted))]), const SizedBox(height: 5), LinearProgressIndicator(value: item.$3, minHeight: 6, borderRadius: BorderRadius.circular(99))]))) ])),
                ];
                return constraints.maxWidth >= 760 ? Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(child: cards[0]), const SizedBox(width: 16), Expanded(child: cards[1])]) : Column(children: [cards[0], const SizedBox(height: 16), cards[1]]);
              }),
              const SizedBox(height: 24),
              const SafetyNote(text: 'These metrics describe care-plan feasibility and understanding, not clinical outcomes.'),
            ],
          ),
        );
      },
    );
  }
}

IconData _kindIcon(TaskKind kind) => switch (kind) {
      TaskKind.medicine => Icons.medication_outlined,
      TaskKind.lab => Icons.biotech_outlined,
      TaskKind.visit => Icons.local_hospital_outlined,
      TaskKind.dressing => Icons.healing_outlined,
      TaskKind.caregiver => Icons.handshake_outlined,
    };
