import 'package:flutter/material.dart';
import '../core/app_routes.dart';
import '../core/app_theme.dart';
import '../data/demo_data.dart';
import '../localization/language_scope.dart';
import '../services/auth_service.dart';
import '../services/document_service.dart';
import '../services/notification_center_service.dart';
import '../services/progress_service.dart';
import '../widgets/app_shell.dart';
import '../widgets/status_badge.dart';
import '../widgets/ui.dart';
import 'document_viewer_screen.dart';

Widget _libraryHeroChip(
  IconData icon,
  String label,
) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
    decoration: BoxDecoration(
      color: const Color(0x1FFFFFFF),
      borderRadius: BorderRadius.circular(999),
      border: Border.all(color: const Color(0x20FFFFFF)),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: Colors.white),
        const SizedBox(width: 5),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 10,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    ),
  );
}

class _LibraryLoadingSkeleton extends StatelessWidget {
  const _LibraryLoadingSkeleton();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(
        3,
        (index) => Padding(
          padding: EdgeInsets.only(bottom: index == 2 ? 0 : 10),
          child: AppCard(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8EEF2),
                    borderRadius: BorderRadius.circular(AppRadii.xl),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 150,
                        height: 13,
                        decoration: BoxDecoration(
                          color: const Color(0xFFE8EEF2),
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        width: double.infinity,
                        height: 9,
                        decoration: BoxDecoration(
                          color: const Color(0xFFE8EEF2),
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LibraryErrorCard extends StatelessWidget {
  const _LibraryErrorCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.onRetry,
    this.retryKey,
  });

  final IconData icon;
  final String title;
  final String description;
  final VoidCallback onRetry;
  final Key? retryKey;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 540),
        child: AppCard(
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
                child: Icon(
                  icon,
                  color: AppColors.warningForeground,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                description,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.muted,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 14),
              FilledButton.icon(
                key: retryKey,
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded, size: 17),
                label: Text(context.tr('retry')),
              ),
            ],
          ),
        ),
      ),
    );
  }
}


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
        final dayTasks =
            state.tasks.where((task) => task.day == selected).toList();
        final activeDays = demoDays
            .where(
              (item) => state.tasks.any((task) => task.day == item.iso),
            )
            .length;

        return AppShell(
          currentRoute: AppRoutes.calendar,
          title: context.tr('care_calendar'),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              FadeSlideIn(
                child: _calendarHero(
                  dayTasks: dayTasks.length,
                  weekTotal: state.tasks.length,
                  activeDays: activeDays,
                ),
              ),
              const SizedBox(height: 18),
              FadeSlideIn(
                delay: const Duration(milliseconds: 60),
                child: _modeSwitch(),
              ),
              const SizedBox(height: 18),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 230),
                child: mode == 'Week'
                    ? _weekView(
                        key: const ValueKey('week'),
                        state: state,
                        day: day,
                        dayTasks: dayTasks,
                      )
                    : _monthView(
                        key: const ValueKey('month'),
                        state: state,
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _calendarHero({
    required int dayTasks,
    required int weekTotal,
    required int activeDays,
  }) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF0F766E),
            Color(0xFF0D9488),
            Color(0xFF14B8A6),
          ],
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
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(0x20FFFFFF),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.calendar_month_outlined,
                      size: 14,
                      color: Colors.white,
                    ),
                    SizedBox(width: 6),
                    Text(
                      'Care schedule',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Text(
                context.tr('care_calendar'),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 27,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -.35,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                context.tr('care_calendar_subtitle'),
                style: const TextStyle(
                  color: Color(0xE6FFFFFF),
                  fontSize: 12,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _libraryHeroChip(
                    Icons.today_outlined,
                    '$dayTasks selected day',
                  ),
                  _libraryHeroChip(
                    Icons.view_week_outlined,
                    '$weekTotal total',
                  ),
                  _libraryHeroChip(
                    Icons.event_available_outlined,
                    '$activeDays active days',
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _modeSwitch() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F5F4),
        borderRadius: BorderRadius.circular(AppRadii.xl),
        border: Border.all(color: const Color(0xFFE1ECE9)),
      ),
      child: Row(
        children: [
          Expanded(
            child: _modeButton(
              value: 'Week',
              label: context.tr('week'),
              icon: Icons.view_week_outlined,
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: _modeButton(
              value: 'Month',
              label: context.tr('month'),
              icon: Icons.calendar_view_month_outlined,
            ),
          ),
        ],
      ),
    );
  }

  Widget _modeButton({
    required String value,
    required String label,
    required IconData icon,
  }) {
    final active = mode == value;

    return InkWell(
      onTap: () => setState(() => mode = value),
      borderRadius: BorderRadius.circular(AppRadii.lg),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 190),
        padding: const EdgeInsets.symmetric(vertical: 9),
        decoration: BoxDecoration(
          color: active ? AppColors.card : Colors.transparent,
          borderRadius: BorderRadius.circular(AppRadii.lg),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
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
                fontSize: 12,
                fontWeight:
                    active ? FontWeight.w800 : FontWeight.w600,
                color:
                    active ? AppColors.foreground : AppColors.muted,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _weekView({
    Key? key,
    required CareDemoState state,
    required DemoDay day,
    required List<DemoTask> dayTasks,
  }) {
    return Column(
      key: key,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppCard(
          padding: const EdgeInsets.all(12),
          child: LayoutBuilder(
            builder: (context, constraints) => GridView.count(
              crossAxisCount: 7,
              crossAxisSpacing: 7,
              mainAxisSpacing: 7,
              childAspectRatio:
                  constraints.maxWidth < 620 ? .58 : 1.0,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              children: demoDays.map((item) {
                final count = state.tasks
                    .where((task) => task.day == item.iso)
                    .length;
                final active = selected == item.iso;

                return InkWell(
                  onTap: () => setState(() => selected = item.iso),
                  borderRadius: BorderRadius.circular(AppRadii.lg),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 3,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      gradient: active
                          ? const LinearGradient(
                              colors: [
                                Color(0xFF0F766E),
                                Color(0xFF0D9488),
                              ],
                            )
                          : null,
                      color: active ? null : const Color(0xFFF8FAFC),
                      border: Border.all(
                        color: active
                            ? AppColors.primary
                            : AppColors.border,
                      ),
                      borderRadius: BorderRadius.circular(AppRadii.lg),
                    ),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            _demoDayShort(context, item),
                            style: TextStyle(
                              fontSize: 11,
                              color: active
                                  ? const Color(0xDFFFFFFF)
                                  : AppColors.muted,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            '${item.number}',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                              color: active
                                  ? Colors.white
                                  : AppColors.foreground,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 5,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: active
                                  ? const Color(0x20FFFFFF)
                                  : count > 0
                                      ? AppColors.primaryLight
                                      : Colors.transparent,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              '$count',
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                                color: active
                                    ? Colors.white
                                    : count > 0
                                        ? AppColors.primary
                                        : AppColors.subtle,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ),
        const SizedBox(height: 18),
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
                    _demoDayLong(context, day),
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    _demoDateLabel(context, day),
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.muted,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (dayTasks.isEmpty)
          EmptyState(
            title: context.tr('no_tasks_this_day'),
            description: context.tr('nothing_scheduled_for_date'),
          )
        else
          ...dayTasks.asMap().entries.map(
                (entry) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: FadeSlideIn(
                    delay: Duration(
                      milliseconds: 30 * entry.key.clamp(0, 5),
                    ),
                    child: _CalendarTask(task: entry.value),
                  ),
                ),
              ),
      ],
    );
  }

  Widget _monthView({
    Key? key,
    required CareDemoState state,
  }) {
    return AppCard(
      key: key,
      padding: const EdgeInsets.all(14),
      child: Column(
        children: [
          GridView.count(
            crossAxisCount: 7,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            childAspectRatio: 1.15,
            children: const [
              'mon_initial',
              'tue_initial',
              'wed_initial',
              'thu_initial',
              'fri_initial',
              'sat_initial',
              'sun_initial',
            ]
                .map(
                  (label) => Center(
                    child: Text(
                      context.tr(label),
                      style: const TextStyle(
                        fontSize: 10,
                        color: AppColors.muted,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                )
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
              final matching = demoDays
                  .where((item) => item.number == number)
                  .firstOrNull;
              final count = matching == null
                  ? 0
                  : state.tasks
                      .where((task) => task.day == matching.iso)
                      .length;

              return Container(
                decoration: BoxDecoration(
                  color: count > 0
                      ? AppColors.primaryLight
                      : const Color(0xFFF8FAFC),
                  border: Border.all(
                    color: count > 0
                        ? AppColors.primary.withValues(alpha: .25)
                        : AppColors.border,
                  ),
                  borderRadius: BorderRadius.circular(AppRadii.lg),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '$number',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight:
                            count > 0 ? FontWeight.w800 : FontWeight.w600,
                        color: count > 0
                            ? AppColors.primary
                            : AppColors.foreground,
                      ),
                    ),
                    if (count > 0) ...[
                      const SizedBox(height: 4),
                      const CircleAvatar(
                        radius: 3,
                        backgroundColor: AppColors.primary,
                      ),
                    ],
                  ],
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

}

class _CalendarTask extends StatelessWidget {
  const _CalendarTask({required this.task});

  final DemoTask task;

  @override
  Widget build(BuildContext context) => HoverLift(
        child: AppCard(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 66,
                padding:
                    const EdgeInsets.symmetric(horizontal: 7, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(AppRadii.lg),
                ),
                child: Text(
                  task.time,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: AppColors.muted,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              TaskIcon(icon: task.icon),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      demoTaskTitle(task, context.appLanguage),
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      demoTaskNote(task, context.appLanguage),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.muted,
                      ),
                    ),
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


class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key, this.service, this.session});

  final NotificationCenterClient? service;
  final ProfileSession? session;

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  late final NotificationCenterClient _service;
  late final ProfileSession _session;
  var _loading = true;
  var _refreshing = false;
  var _notifications = <AppNotification>[];
  var _filter = 'all';
  String? _error;
  bool _offline = false;

  @override
  void initState() {
    super.initState();
    _service = widget.service ?? NotificationCenterService.instance;
    _session = widget.session ?? AuthSession.instance;
    if (_session.isAuthenticated && !_session.isGuest) {
      _loadNotifications();
    } else {
      _loading = false;
    }
  }

  Future<void> _loadNotifications({bool refresh = false}) async {
    if (refresh) {
      setState(() => _refreshing = true);
    } else {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    try {
      final notifications = await _service.loadNotifications();
      if (!mounted) return;
      setState(() {
        _notifications = notifications;
        _loading = false;
        _refreshing = false;
        _error = null;
        _offline = false;
      });
    } on NotificationCenterException catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.message;
        _offline = error.retryable;
        _loading = false;
        _refreshing = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = context.tr('notification_center_load_failed');
        _offline = false;
        _loading = false;
        _refreshing = false;
      });
    }
  }

  Future<void> _markReadAndOpen(AppNotification notification) async {
    try {
      await _service.markRead(notification.id);
      if (!mounted) return;
      setState(() {
        _notifications = _notifications
            .map(
              (item) =>
                  item.id == notification.id ? item.copyWith(read: true) : item,
            )
            .toList();
      });
      final route = notification.route;
      if (route != null && route.isNotEmpty) {
        Navigator.pushNamed(context, route);
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr('notification_center_read_failed'))),
      );
    }
  }

  Future<void> _markAllRead() async {
    try {
      await _service.markAllRead(_notifications.map((item) => item.id));
      if (!mounted) return;
      setState(() {
        _notifications = _notifications
            .map((notification) => notification.copyWith(read: true))
            .toList();
      });
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr('notification_center_read_failed'))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final unreadCount = _notifications.where((item) => !item.read).length;
    final visible = _filter == 'unread'
        ? _notifications.where((item) => !item.read).toList()
        : _notifications;

    return AppShell(
      currentRoute: AppRoutes.notifications,
      title: context.tr('notifications'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          FadeSlideIn(
            child: _notificationHero(unreadCount),
          ),
          const SizedBox(height: 18),
          if (!_session.isAuthenticated || _session.isGuest)
            EmptyState(
              icon: Icons.lock_outline,
              title: context.tr('notification_center_sign_in_title'),
              description:
                  context.tr('notification_center_sign_in_message'),
              action: FilledButton(
                onPressed: () =>
                    Navigator.pushNamed(context, AppRoutes.auth),
                child: Text(context.tr('sign_in')),
              ),
            )
          else if (_loading)
            const _LibraryLoadingSkeleton()
          else if (_error != null)
            _LibraryErrorCard(
              icon: _offline
                  ? Icons.wifi_off_outlined
                  : Icons.error_outline,
              title: context.tr('notification_center_error_title'),
              description: _error!,
              onRetry: _loadNotifications,
              retryKey: const Key('notifications_retry_button'),
            )
          else ...[
            _notificationFilters(unreadCount),
            const SizedBox(height: 18),
            if (visible.isEmpty)
              EmptyState(
                icon: Icons.notifications_none,
                title: context.tr('nothing_new'),
                description: _filter == 'unread'
                    ? context.tr('notification_center_no_unread')
                    : context.tr('all_caught_up'),
              )
            else
              _NotificationGroups(
                notifications: visible,
                onTap: _markReadAndOpen,
              ),
          ],
          const SizedBox(height: 20),
          SafetyNote(
            text: context.tr('notification_center_safety_note'),
          ),
        ],
      ),
    );
  }

  Widget _notificationHero(int unreadCount) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFF0F766E),
            Color(0xFF0D9488),
            Color(0xFF14B8A6),
          ],
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
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 560;
          final copy = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                context.tr('notifications'),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 27,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                context.tr('notifications_subtitle'),
                style: const TextStyle(
                  color: Color(0xE6FFFFFF),
                  fontSize: 12,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _libraryHeroChip(
                    Icons.inbox_outlined,
                    '${_notifications.length} total',
                  ),
                  _libraryHeroChip(
                    Icons.mark_email_unread_outlined,
                    '$unreadCount unread',
                  ),
                ],
              ),
            ],
          );

          final actions = Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              IconButton.filled(
                key: const Key('notifications_refresh_button'),
                style: IconButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: AppColors.primary,
                ),
                onPressed: _refreshing
                    ? null
                    : () => _loadNotifications(refresh: true),
                icon: _refreshing
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.refresh_rounded, size: 19),
                tooltip: context.tr('refresh'),
              ),
              if (unreadCount > 0)
                OutlinedButton.icon(
                  key: const Key('notifications_mark_all_read_button'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(
                      color: Color(0x55FFFFFF),
                    ),
                  ),
                  onPressed: _markAllRead,
                  icon: const Icon(Icons.done_all_rounded, size: 17),
                  label: Text(context.tr('mark_all_read')),
                ),
            ],
          );

          return compact
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    copy,
                    const SizedBox(height: 16),
                    actions,
                  ],
                )
              : Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(child: copy),
                    const SizedBox(width: 18),
                    actions,
                  ],
                );
        },
      ),
    );
  }

  Widget _notificationFilters(int unreadCount) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F5F4),
        borderRadius: BorderRadius.circular(AppRadii.xl),
        border: Border.all(color: const Color(0xFFE1ECE9)),
      ),
      child: Row(
        children: [
          Expanded(
            child: _notificationFilter(
              value: 'all',
              label: context.tr('all'),
              count: _notifications.length,
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: _notificationFilter(
              value: 'unread',
              label: context.tr(
                'notification_center_unread_tab',
                values: {'count': unreadCount},
              ),
              count: unreadCount,
            ),
          ),
        ],
      ),
    );
  }

  Widget _notificationFilter({
    required String value,
    required String label,
    required int count,
  }) {
    final active = _filter == value;

    return InkWell(
      onTap: () => setState(() => _filter = value),
      borderRadius: BorderRadius.circular(AppRadii.lg),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 190),
        padding:
            const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
        decoration: BoxDecoration(
          color: active ? AppColors.card : Colors.transparent,
          borderRadius: BorderRadius.circular(AppRadii.lg),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight:
                      active ? FontWeight.w800 : FontWeight.w600,
                  color:
                      active ? AppColors.foreground : AppColors.muted,
                ),
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: active
                    ? AppColors.primaryLight
                    : const Color(0xFFE8EFEE),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                '$count',
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                  color:
                      active ? AppColors.primary : AppColors.muted,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

}

class _NotificationGroups extends StatelessWidget {
  const _NotificationGroups({
    required this.notifications,
    required this.onTap,
  });

  final List<AppNotification> notifications;
  final ValueChanged<AppNotification> onTap;

  @override
  Widget build(BuildContext context) {
    final groups = <String, List<AppNotification>>{};

    for (final notification in notifications) {
      groups.putIfAbsent(_groupKey(notification.createdAt), () => []);
      groups[_groupKey(notification.createdAt)]!.add(notification);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final entry in groups.entries) ...[
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: AppColors.primaryLight,
                  borderRadius: BorderRadius.circular(AppRadii.lg),
                ),
                child: const Icon(
                  Icons.schedule_outlined,
                  size: 16,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: 9),
              Text(
                context.tr(entry.key),
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const Spacer(),
              Text(
                '${entry.value.length}',
                style: const TextStyle(
                  fontSize: 10,
                  color: AppColors.muted,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ...entry.value.map(
            (notification) => Padding(
              padding: const EdgeInsets.only(bottom: 9),
              child: _NotificationTile(
                notification: notification,
                onTap: () => onTap(notification),
              ),
            ),
          ),
          const SizedBox(height: 10),
        ],
      ],
    );
  }

  String _groupKey(DateTime createdAt) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final date =
        DateTime(createdAt.year, createdAt.month, createdAt.day);

    if (date == today) return 'today';
    if (date == today.subtract(const Duration(days: 1))) {
      return 'yesterday';
    }
    return 'earlier';
  }
}


class _NotificationTile extends StatelessWidget {
  const _NotificationTile({
    required this.notification,
    required this.onTap,
  });

  final AppNotification notification;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final unread = !notification.read;

    return HoverLift(
      child: InkWell(
        key: Key('notification_${notification.id}'),
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadii.xxl),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: unread ? const Color(0xFFF0FDFA) : AppColors.card,
            border: Border.all(
              color: unread
                  ? AppColors.primary.withValues(alpha: .18)
                  : AppColors.border,
            ),
            borderRadius: BorderRadius.circular(AppRadii.xxl),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: unread
                      ? AppColors.primaryLight
                      : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(AppRadii.xl),
                ),
                child: Icon(
                  _notificationIcon(notification.type),
                  size: 19,
                  color:
                      unread ? AppColors.primary : AppColors.muted,
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            context.tr(
                              notification.titleKey,
                              values: notification.values,
                            ),
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: unread
                                  ? FontWeight.w800
                                  : FontWeight.w700,
                            ),
                          ),
                        ),
                        if (unread)
                          const CircleAvatar(
                            radius: 3.5,
                            backgroundColor: AppColors.primary,
                          ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      context.tr(
                        notification.messageKey,
                        values: notification.values,
                      ),
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.muted,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 7),
                    Row(
                      children: [
                        const Icon(
                          Icons.access_time_rounded,
                          size: 12,
                          color: AppColors.subtle,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _timeLabel(notification.createdAt),
                          style: const TextStyle(
                            fontSize: 10,
                            color: AppColors.subtle,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const Spacer(),
                        const Icon(
                          Icons.chevron_right_rounded,
                          size: 17,
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

  String _timeLabel(DateTime createdAt) {
    final hour = createdAt.hour;
    final suffix = hour >= 12 ? 'PM' : 'AM';
    final displayHour = hour % 12 == 0 ? 12 : hour % 12;
    return '$displayHour:${createdAt.minute.toString().padLeft(2, '0')} $suffix';
  }
}


IconData _notificationIcon(String type) => switch (type) {
  'task_due' ||
  'task_overdue' ||
  'task_missed' => Icons.event_available_outlined,
  'care_gap' => Icons.report_problem_outlined,
  'document_ready' || 'document_failed' => Icons.description_outlined,
  'family_invitation' => Icons.handshake_outlined,
  'permission' => Icons.notifications_off_outlined,
  _ => Icons.notifications_none,
};

typedef DocumentFileViewer =
    Future<void> Function(BuildContext context, DocumentFile file);

class DocumentsScreen extends StatefulWidget {
  const DocumentsScreen({super.key, this.service, this.fileViewer});

  final DocumentClient? service;
  final DocumentFileViewer? fileViewer;

  @override
  State<DocumentsScreen> createState() => _DocumentsScreenState();
}

class _DocumentsScreenState extends State<DocumentsScreen> {
  late final DocumentClient _service;
  late final DocumentFileViewer _fileViewer;
  var _loading = true;
  var _refreshing = false;
  var _documents = <CareDocument>[];
  String? _error;
  bool _offline = false;
  final _deleting = <String>{};

  @override
  void initState() {
    super.initState();
    _service = widget.service ?? DocumentService.instance;
    _fileViewer = widget.fileViewer ?? _openDocumentViewer;
    _loadDocuments();
  }

  Future<void> _loadDocuments({bool refresh = false}) async {
    if (refresh) {
      setState(() => _refreshing = true);
    } else {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final documents = await _service.listDocuments();
      if (!mounted) return;
      setState(() {
        _documents = documents;
        _error = null;
        _offline = false;
        _loading = false;
        _refreshing = false;
      });
    } on DocumentException catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.message;
        _offline = error.retryable;
        _loading = false;
        _refreshing = false;
      });
    }
  }

  Future<void> _view(CareDocument document) async {
    try {
      final file = await _service.fetchDocumentFile(document.id);
      if (!mounted) return;
      await _fileViewer(context, file);
    } on DocumentException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    }
  }

  Future<void> _delete(CareDocument document) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.tr('delete_document_question')),
        content: Text(
          document.hasInstructions || document.hasVerifiedInstructions
              ? context.tr(
                  'delete_document_with_instructions_warning',
                  values: {
                    'name': document.originalName,
                    'plan': document.carePlanTitle,
                    'count': document.instructionCount,
                    'verified': document.verifiedInstructionCount,
                  },
                )
              : context.tr(
                  'delete_document_description',
                  values: {
                    'name': document.originalName,
                    'plan': document.carePlanTitle,
                  },
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(context.tr('cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(context.tr('delete')),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _deleting.add(document.id));
    try {
      await _service.deleteDocument(document.id);
      await _loadDocuments(refresh: true);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.tr('document_removed'))));
    } on DocumentException catch (error) {
      if (!mounted) return;
      setState(() => _deleting.remove(document.id));
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final processed = _documents
        .where((item) => item.processingStatus == 'processed')
        .length;
    final processing = _documents
        .where((item) => item.processingStatus == 'processing')
        .length;
    final failed = _documents
        .where((item) => item.processingStatus == 'failed')
        .length;

    return AppShell(
      currentRoute: AppRoutes.documents,
      title: context.tr('documents'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          FadeSlideIn(
            child: _documentsHero(
              processed: processed,
              processing: processing,
              failed: failed,
            ),
          ),
          const SizedBox(height: 18),
          if (_loading)
            const _LibraryLoadingSkeleton()
          else if (_error != null)
            _LibraryErrorCard(
              icon: _offline
                  ? Icons.wifi_off_outlined
                  : Icons.error_outline,
              title: _offline
                  ? context.tr('documents_offline_title')
                  : context.tr('documents_error_title'),
              description: _error!,
              onRetry: _loadDocuments,
              retryKey: const Key('documents_retry_button'),
            )
          else if (_documents.isEmpty)
            EmptyState(
              icon: Icons.description_outlined,
              title: context.tr('no_documents_yet'),
              description:
                  context.tr('upload_prescription_or_discharge'),
              action: FilledButton.icon(
                onPressed: () =>
                    Navigator.pushNamed(context, AppRoutes.carePlanNew),
                icon:
                    const Icon(Icons.upload_file_rounded, size: 18),
                label: Text(context.tr('upload_document')),
              ),
            )
          else
            LayoutBuilder(
              builder: (context, constraints) {
                final columns = constraints.maxWidth >= 900
                    ? 3
                    : constraints.maxWidth >= 580
                        ? 2
                        : 1;
                const gap = 14.0;
                final width = (constraints.maxWidth -
                        (columns - 1) * gap) /
                    columns;

                return Wrap(
                  spacing: gap,
                  runSpacing: gap,
                  children: _documents
                      .map(
                        (document) => SizedBox(
                          width: width,
                          child: _documentCard(document),
                        ),
                      )
                      .toList(),
                );
              },
            ),
          const SizedBox(height: 22),
          SafetyNote(text: context.tr('documents_safety_note')),
        ],
      ),
    );
  }

  Widget _documentsHero({
    required int processed,
    required int processing,
    required int failed,
  }) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFF0F766E),
            Color(0xFF0D9488),
            Color(0xFF14B8A6),
          ],
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
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 560;

          final copy = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                context.tr('documents'),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 27,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                context.tr('documents_subtitle'),
                style: const TextStyle(
                  color: Color(0xE6FFFFFF),
                  fontSize: 12,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _libraryHeroChip(
                    Icons.description_outlined,
                    '${_documents.length} total',
                  ),
                  _libraryHeroChip(
                    Icons.check_circle_outline_rounded,
                    '$processed ready',
                  ),
                  if (processing > 0)
                    _libraryHeroChip(
                      Icons.hourglass_top_rounded,
                      '$processing processing',
                    ),
                  if (failed > 0)
                    _libraryHeroChip(
                      Icons.error_outline_rounded,
                      '$failed failed',
                    ),
                ],
              ),
            ],
          );

          final actions = Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              IconButton.filled(
                key: const Key('documents_refresh_button'),
                style: IconButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: AppColors.primary,
                ),
                onPressed: _refreshing
                    ? null
                    : () => _loadDocuments(refresh: true),
                icon: _refreshing
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.refresh_rounded, size: 19),
                tooltip: context.tr('refresh'),
              ),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: AppColors.primary,
                ),
                onPressed: () =>
                    Navigator.pushNamed(context, AppRoutes.carePlanNew),
                icon:
                    const Icon(Icons.upload_file_rounded, size: 18),
                label: Text(context.tr('upload')),
              ),
            ],
          );

          return compact
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    copy,
                    const SizedBox(height: 16),
                    actions,
                  ],
                )
              : Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(child: copy),
                    const SizedBox(width: 18),
                    actions,
                  ],
                );
        },
      ),
    );
  }

  Widget _documentCard(CareDocument document) {
    final deleting = _deleting.contains(document.id);
    final failed = document.processingStatus == 'failed';
    final processing = document.processingStatus == 'processing';

    final accent = failed
        ? AppColors.critical
        : processing
            ? AppColors.warning
            : AppColors.primary;

    final soft = failed
        ? AppColors.criticalSoft
        : processing
            ? AppColors.warningSoft
            : AppColors.primaryLight;

    return HoverLift(
      child: AppCard(
        padding: EdgeInsets.zero,
        borderColor: accent.withValues(alpha: .16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(height: 4, color: accent),
            Container(
              height: 96,
              margin: const EdgeInsets.fromLTRB(14, 14, 14, 0),
              decoration: BoxDecoration(
                color: soft,
                borderRadius: BorderRadius.circular(AppRadii.xl),
              ),
              child: Center(
                child: Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(AppRadii.xl),
                  ),
                  child: Icon(
                    _documentIcon(document),
                    size: 25,
                    color: accent,
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    document.originalName,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    _documentMeta(context, document),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 10,
                      color: AppColors.muted,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    document.carePlanTitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 10,
                      color: AppColors.subtle,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 9),
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: StatusBadge(
                      status: _processingStatus(document),
                      label: _processingLabel(context, document),
                    ),
                  ),
                  if (failed && document.processingError != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      document.processingError!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 10,
                        color: AppColors.critical,
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          key: Key('document_view_${document.id}'),
                          onPressed:
                              deleting ? null : () => _view(document),
                          icon: const Icon(
                            Icons.visibility_outlined,
                            size: 16,
                          ),
                          label: Text(context.tr('view')),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        key: Key('document_delete_${document.id}'),
                        onPressed:
                            deleting ? null : () => _delete(document),
                        tooltip: context.tr('delete'),
                        icon: deleting
                            ? const SizedBox(
                                width: 17,
                                height: 17,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(
                                Icons.delete_outline_rounded,
                                size: 18,
                              ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

}

class ProgressScreen extends StatefulWidget {
  const ProgressScreen({super.key, this.service});

  final ProgressClient? service;

  @override
  State<ProgressScreen> createState() => _ProgressScreenState();
}

class _ProgressScreenState extends State<ProgressScreen> {
  late final ProgressClient _service;
  var _loading = true;
  var _refreshing = false;
  ProgressSummary? _summary;
  String? _error;
  bool _offline = false;

  @override
  void initState() {
    super.initState();
    _service = widget.service ?? ProgressService.instance;
    _loadProgress();
  }

  Future<void> _loadProgress({bool refresh = false}) async {
    if (refresh) {
      setState(() => _refreshing = true);
    } else {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final summary = await _service.fetchSummary(days: 7);
      if (!mounted) return;
      setState(() {
        _summary = summary;
        _error = null;
        _offline = false;
        _loading = false;
        _refreshing = false;
      });
    } on ProgressException catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.message;
        _offline = error.retryable;
        _loading = false;
        _refreshing = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final summary = _summary;

    return AppShell(
      currentRoute: AppRoutes.progress,
      title: context.tr('progress'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          FadeSlideIn(
            child: _progressHero(summary),
          ),
          const SizedBox(height: 18),
          if (_loading)
            const _LibraryLoadingSkeleton()
          else if (_error != null)
            _LibraryErrorCard(
              icon: _offline
                  ? Icons.wifi_off_outlined
                  : Icons.error_outline,
              title: _offline
                  ? context.tr('progress_offline_title')
                  : context.tr('progress_error_title'),
              description: _error!,
              onRetry: _loadProgress,
              retryKey: const Key('progress_retry_button'),
            )
          else if (summary == null || summary.activePlanCount == 0)
            EmptyState(
              icon: Icons.insights_outlined,
              title: context.tr('progress_no_active_title'),
              description:
                  context.tr('progress_no_active_description'),
              action: FilledButton(
                onPressed: () =>
                    Navigator.pushNamed(context, AppRoutes.carePlanNew),
                child: Text(context.tr('upload_document')),
              ),
            )
          else ...[
            _ProgressCards(summary: summary),
            const SizedBox(height: 18),
            _TaskCompletionTrend(summary: summary),
            const SizedBox(height: 18),
            _ProgressDetails(summary: summary),
          ],
          const SizedBox(height: 22),
          SafetyNote(text: context.tr('progress_safety_note')),
        ],
      ),
    );
  }

  Widget _progressHero(ProgressSummary? summary) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFF0F766E),
            Color(0xFF0D9488),
            Color(0xFF14B8A6),
          ],
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
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.tr('care_progress'),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 27,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  context.tr('care_progress_subtitle'),
                  style: const TextStyle(
                    color: Color(0xE6FFFFFF),
                    fontSize: 12,
                    height: 1.45,
                  ),
                ),
                if (summary != null) ...[
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _libraryHeroChip(
                        Icons.speed_outlined,
                        '${context.tr('care_readiness')}: ${_scoreLabel(summary.readiness)}',
                      ),
                      _libraryHeroChip(
                        Icons.task_alt_outlined,
                        '${context.tr('tasks_completed')}: '
                        '${summary.tasks.completed}/${summary.tasks.scheduled}',
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 12),
          IconButton.filled(
            key: const Key('progress_refresh_button'),
            style: IconButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: AppColors.primary,
            ),
            onPressed: _refreshing
                ? null
                : () => _loadProgress(refresh: true),
            icon: _refreshing
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh_rounded, size: 19),
            tooltip: context.tr('refresh'),
          ),
        ],
      ),
    );
  }

}

class _ProgressCards extends StatelessWidget {
  const _ProgressCards({required this.summary});

  final ProgressSummary summary;

  @override
  Widget build(BuildContext context) {
    final stats = [
      (
        context.tr('care_readiness'),
        _scoreLabel(summary.readiness),
        Icons.speed_outlined,
        AppColors.primaryLight,
        AppColors.primary,
      ),
      (
        context.tr('tasks_completed'),
        '${summary.tasks.completed}/${summary.tasks.scheduled}',
        Icons.task_alt_outlined,
        AppColors.successSoft,
        AppColors.successForeground,
      ),
      (
        context.tr('gaps_resolved'),
        '${summary.gaps.resolved}/${summary.gaps.total}',
        Icons.check_circle_outline_rounded,
        AppColors.primaryLight,
        AppColors.primary,
      ),
      (
        context.tr('understanding'),
        _understandingLabel(summary.understanding),
        Icons.psychology_alt_outlined,
        AppColors.warningSoft,
        AppColors.warningForeground,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 900
            ? 4
            : constraints.maxWidth >= 480
                ? 2
                : 1;
        const gap = 10.0;
        final width =
            (constraints.maxWidth - (columns - 1) * gap) / columns;

        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: stats
              .map(
                (stat) => SizedBox(
                  width: width,
                  child: AppCard(
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: stat.$4,
                            borderRadius:
                                BorderRadius.circular(AppRadii.lg),
                          ),
                          child: Icon(
                            stat.$3,
                            size: 19,
                            color: stat.$5,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                stat.$2,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 20,
                                  height: 1,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                stat.$1,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 10,
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
                ),
              )
              .toList(),
        );
      },
    );
  }
}


class _TaskCompletionTrend extends StatelessWidget {
  const _TaskCompletionTrend({required this.summary});

  final ProgressSummary summary;

  @override
  Widget build(BuildContext context) {
    final points = summary.trend.points;
    final hasData = points.any((point) => point.value != null);

    return AppCard(
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
                child: Text(
                  context.tr('task_completion_trend'),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          if (!hasData)
            EmptyState(
              icon: Icons.bar_chart_outlined,
              title: context.tr('progress_no_data_title'),
              description: context.tr('progress_no_data_description'),
            )
          else
            SizedBox(
              height: 220,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: points
                    .map(
                      (point) => Expanded(
                        child: Padding(
                          padding:
                              const EdgeInsets.symmetric(horizontal: 4),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              Text(
                                point.value == null
                                    ? '-'
                                    : '${point.value}%',
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 6),
                              TweenAnimationBuilder<double>(
                                tween: Tween(
                                  begin: 0,
                                  end: point.value == null
                                      ? .08
                                      : point.value! / 100,
                                ),
                                duration:
                                    const Duration(milliseconds: 500),
                                curve: Curves.easeOutCubic,
                                builder: (context, value, _) =>
                                    Container(
                                  height: 145 * value,
                                  decoration: BoxDecoration(
                                    gradient: point.value == null
                                        ? null
                                        : const LinearGradient(
                                            begin: Alignment.bottomCenter,
                                            end: Alignment.topCenter,
                                            colors: [
                                              Color(0xFF0F766E),
                                              Color(0xFF14B8A6),
                                            ],
                                          ),
                                    color: point.value == null
                                        ? AppColors.border
                                        : null,
                                    borderRadius:
                                        const BorderRadius.vertical(
                                      top: Radius.circular(8),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                _dayLabel(point.date),
                                style: const TextStyle(
                                  fontSize: 9,
                                  color: AppColors.muted,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
        ],
      ),
    );
  }
}


class _ProgressDetails extends StatelessWidget {
  const _ProgressDetails({required this.summary});

  final ProgressSummary summary;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final cards = [
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.tr('understanding_score'),
                  style: const TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 16),
                LinearProgressIndicator(
                  value: summary.understanding.score == null
                      ? null
                      : summary.understanding.score! / 100,
                  minHeight: 10,
                  borderRadius: BorderRadius.circular(99),
                ),
                const SizedBox(height: 12),
                Text(
                  summary.understanding.available
                      ? context.tr('latest_teach_back_basis')
                      : context.tr('progress_understanding_unavailable'),
                  style: const TextStyle(fontSize: 14, color: AppColors.muted),
                ),
              ],
            ),
          ),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.tr('progress_task_breakdown'),
                  style: const TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 14),
                _breakdownRow(context, 'completed', summary.tasks.completed),
                _breakdownRow(context, 'pending', summary.tasks.pending),
                _breakdownRow(context, 'skipped', summary.tasks.skipped),
                _breakdownRow(context, 'missed', summary.tasks.missed),
              ],
            ),
          ),
        ];
        return constraints.maxWidth >= 760
            ? Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: cards[0]),
                  const SizedBox(width: 16),
                  Expanded(child: cards[1]),
                ],
              )
            : Column(
                children: [cards[0], const SizedBox(height: 16), cards[1]],
              );
      },
    );
  }

  Widget _breakdownRow(BuildContext context, String labelKey, int count) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Expanded(child: Text(context.tr(labelKey))),
          Text(
            context.tr('times_count', values: {'count': count}),
            style: const TextStyle(color: AppColors.muted),
          ),
        ],
      ),
    );
  }
}

String _scoreLabel(ProgressScore score) =>
    score.available && score.score != null ? '${score.score}%' : '-';

String _understandingLabel(ProgressUnderstanding understanding) =>
    understanding.available && understanding.score != null
    ? '${understanding.score}%'
    : '-';

String _dayLabel(String value) {
  final parsed = DateTime.tryParse(value);
  if (parsed == null) return value;
  return '${parsed.month}/${parsed.day}';
}

IconData _documentIcon(CareDocument document) {
  final mime = document.mimeType.toLowerCase();
  if (mime.contains('pdf')) return Icons.picture_as_pdf_outlined;
  if (mime.contains('image')) return Icons.image_outlined;
  return Icons.description_outlined;
}

String _documentMeta(BuildContext context, CareDocument document) {
  final items = [
    context.tr('document_type_${document.documentType}'),
    _fileSize(document.fileSizeBytes),
    if (document.pageCount != null)
      context.tr('document_page_count', values: {'count': document.pageCount}),
    _dateLabel(document.createdAt),
  ].where((item) => item.trim().isNotEmpty).join(' · ');
  return items;
}

String _processingLabel(BuildContext context, CareDocument document) {
  return context.tr('document_status_${document.processingStatus}');
}

TaskStatus _processingStatus(CareDocument document) {
  return switch (document.processingStatus) {
    'processed' => TaskStatus.ready,
    'processing' => TaskStatus.atRisk,
    'failed' => TaskStatus.blocked,
    _ => TaskStatus.unclear,
  };
}

String _fileSize(int bytes) {
  if (bytes <= 0) return '';
  if (bytes >= 1024 * 1024) {
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
  if (bytes >= 1024) return '${(bytes / 1024).round()} KB';
  return '$bytes B';
}

String _dateLabel(DateTime? date) {
  if (date == null) return '';
  return '${date.day.toString().padLeft(2, '0')}/'
      '${date.month.toString().padLeft(2, '0')}/${date.year}';
}

Future<void> _openDocumentViewer(
  BuildContext context,
  DocumentFile file,
) async {
  await Navigator.of(context).push<void>(
    MaterialPageRoute<void>(builder: (_) => DocumentViewerScreen(file: file)),
  );
}

String _demoDayShort(BuildContext context, DemoDay day) =>
    context.tr(switch (day.short) {
      'Mon' => 'mon_short',
      'Tue' => 'tue_short',
      'Wed' => 'wed_short',
      'Thu' => 'thu_short',
      'Fri' => 'fri_short',
      'Sat' => 'sat_short',
      _ => 'sun_short',
    });

String _demoDayLong(BuildContext context, DemoDay day) =>
    context.tr(switch (day.label) {
      'Monday' => 'monday',
      'Tuesday' => 'tuesday',
      'Wednesday' => 'wednesday',
      'Thursday' => 'thursday',
      'Friday' => 'friday',
      'Saturday' => 'saturday',
      _ => 'sunday',
    });

String _demoDateLabel(BuildContext context, DemoDay day) => context
    .tr(
      'progress_day_label',
      values: {
        'weekday': '',
        'day': day.number,
        'month': context.tr('aug_short'),
      },
    )
    .trim();
