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
import '../widgets/page_header.dart';
import '../widgets/status_badge.dart';
import '../widgets/ui.dart';
import 'document_viewer_screen.dart';

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
        SizedBox(
          width: 76,
          child: Text(
            task.time,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.muted,
            ),
          ),
        ),
        TaskIcon(icon: task.icon),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                demoTaskTitle(task, context.appLanguage),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                demoTaskNote(task, context.appLanguage),
                style: const TextStyle(fontSize: 14, color: AppColors.muted),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        StatusBadge(status: task.status),
      ],
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PageHeader(
            title: context.tr('notifications'),
            subtitle: context.tr('notifications_subtitle'),
            action: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                IconButton.filledTonal(
                  key: const Key('notifications_refresh_button'),
                  onPressed: _refreshing
                      ? null
                      : () => _loadNotifications(refresh: true),
                  icon: _refreshing
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.refresh, size: 19),
                  tooltip: context.tr('refresh'),
                ),
                if (unreadCount > 0)
                  OutlinedButton.icon(
                    key: const Key('notifications_mark_all_read_button'),
                    onPressed: _markAllRead,
                    icon: const Icon(Icons.done_all, size: 17),
                    label: Text(context.tr('mark_all_read')),
                  ),
              ],
            ),
          ),
          if (!_session.isAuthenticated || _session.isGuest)
            EmptyState(
              icon: Icons.lock_outline,
              title: context.tr('notification_center_sign_in_title'),
              description: context.tr('notification_center_sign_in_message'),
              action: FilledButton(
                onPressed: () => Navigator.pushNamed(context, AppRoutes.auth),
                child: Text(context.tr('sign_in')),
              ),
            )
          else if (_loading)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(48),
                child: CircularProgressIndicator(),
              ),
            )
          else if (_error != null)
            EmptyState(
              icon: _offline ? Icons.wifi_off_outlined : Icons.error_outline,
              title: context.tr('notification_center_error_title'),
              description: _error!,
              action: FilledButton(
                key: const Key('notifications_retry_button'),
                onPressed: _loadNotifications,
                child: Text(context.tr('retry')),
              ),
            )
          else ...[
            AppTabs<String>(
              tabs: [
                AppTab('all', context.tr('all')),
                AppTab(
                  'unread',
                  context.tr(
                    'notification_center_unread_tab',
                    values: {'count': unreadCount},
                  ),
                ),
              ],
              selected: _filter,
              onChanged: (value) => setState(() => _filter = value),
            ),
            const SizedBox(height: 20),
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
          SafetyNote(text: context.tr('notification_center_safety_note')),
        ],
      ),
    );
  }
}

class _NotificationGroups extends StatelessWidget {
  const _NotificationGroups({required this.notifications, required this.onTap});

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
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final entry in groups.entries) ...[
          Text(
            context.tr(entry.key),
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          ...entry.value.map(
            (notification) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _NotificationTile(
                notification: notification,
                onTap: () => onTap(notification),
              ),
            ),
          ),
          const SizedBox(height: 12),
        ],
      ],
    );
  }

  String _groupKey(DateTime createdAt) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final date = DateTime(createdAt.year, createdAt.month, createdAt.day);
    if (date == today) return 'today';
    if (date == today.subtract(const Duration(days: 1))) return 'yesterday';
    return 'earlier';
  }
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({required this.notification, required this.onTap});

  final AppNotification notification;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      key: Key('notification_${notification.id}'),
      onTap: onTap,
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
            Icon(
              _notificationIcon(notification.type),
              size: 21,
              color: AppColors.primary,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.tr(
                      notification.titleKey,
                      values: notification.values,
                    ),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    context.tr(
                      notification.messageKey,
                      values: notification.values,
                    ),
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppColors.muted,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _timeLabel(notification.createdAt),
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.subtle,
                    ),
                  ),
                ],
              ),
            ),
            if (!notification.read)
              const Padding(
                padding: EdgeInsets.only(top: 7),
                child: CircleAvatar(
                  radius: 4,
                  backgroundColor: AppColors.primary,
                ),
              ),
          ],
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
    return AppShell(
      currentRoute: AppRoutes.documents,
      title: context.tr('documents'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PageHeader(
            title: context.tr('documents'),
            subtitle: context.tr('documents_subtitle'),
            action: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                IconButton.filledTonal(
                  key: const Key('documents_refresh_button'),
                  onPressed: _refreshing
                      ? null
                      : () => _loadDocuments(refresh: true),
                  icon: _refreshing
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.refresh, size: 19),
                  tooltip: context.tr('refresh'),
                ),
                FilledButton.icon(
                  onPressed: () =>
                      Navigator.pushNamed(context, AppRoutes.carePlanNew),
                  icon: const Icon(Icons.upload, size: 18),
                  label: Text(context.tr('upload')),
                ),
              ],
            ),
          ),
          if (_loading)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(48),
                child: CircularProgressIndicator(),
              ),
            )
          else if (_error != null)
            EmptyState(
              icon: _offline ? Icons.wifi_off_outlined : Icons.error_outline,
              title: _offline
                  ? context.tr('documents_offline_title')
                  : context.tr('documents_error_title'),
              description: _error!,
              action: FilledButton(
                key: const Key('documents_retry_button'),
                onPressed: _loadDocuments,
                child: Text(context.tr('retry')),
              ),
            )
          else if (_documents.isEmpty)
            EmptyState(
              icon: Icons.description_outlined,
              title: context.tr('no_documents_yet'),
              description: context.tr('upload_prescription_or_discharge'),
              action: FilledButton(
                onPressed: () =>
                    Navigator.pushNamed(context, AppRoutes.carePlanNew),
                child: Text(context.tr('upload_document')),
              ),
            )
          else
            LayoutBuilder(
              builder: (context, constraints) {
                final columns = constraints.maxWidth >= 900
                    ? 3
                    : constraints.maxWidth >= 560
                    ? 2
                    : 1;
                return GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: columns,
                    mainAxisSpacing: 16,
                    crossAxisSpacing: 16,
                    mainAxisExtent: columns == 1 ? 340 : null,
                    childAspectRatio: columns == 1 ? 1 : .9,
                  ),
                  itemCount: _documents.length,
                  itemBuilder: (context, index) {
                    final document = _documents[index];
                    final deleting = _deleting.contains(document.id);
                    return FadeSlideIn(
                      child: AppCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(
                              height: 90,
                              width: double.infinity,
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  color: AppColors.secondary,
                                  borderRadius: BorderRadius.circular(
                                    AppRadii.xl,
                                  ),
                                ),
                                child: Center(
                                  child: Icon(
                                    _documentIcon(document),
                                    size: 42,
                                    color: AppColors.primary,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              document.originalName,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _documentMeta(context, document),
                              style: const TextStyle(
                                fontSize: 13,
                                color: AppColors.muted,
                              ),
                            ),
                            Text(
                              document.carePlanTitle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 13,
                                color: AppColors.subtle,
                              ),
                            ),
                            const SizedBox(height: 8),
                            StatusBadge(
                              status: _processingStatus(document),
                              label: _processingLabel(context, document),
                            ),
                            if (document.processingStatus == 'failed' &&
                                document.processingError != null) ...[
                              const SizedBox(height: 8),
                              Text(
                                document.processingError!,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.critical,
                                ),
                              ),
                            ],
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                OutlinedButton.icon(
                                  key: Key('document_view_${document.id}'),
                                  onPressed: deleting
                                      ? null
                                      : () => _view(document),
                                  icon: const Icon(
                                    Icons.visibility_outlined,
                                    size: 17,
                                  ),
                                  label: Text(context.tr('view')),
                                ),
                                TextButton.icon(
                                  key: Key('document_delete_${document.id}'),
                                  onPressed: deleting
                                      ? null
                                      : () => _delete(document),
                                  icon: deleting
                                      ? const SizedBox(
                                          width: 17,
                                          height: 17,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                          ),
                                        )
                                      : const Icon(
                                          Icons.delete_outline,
                                          size: 17,
                                        ),
                                  label: Text(context.tr('delete')),
                                ),
                              ],
                            ),
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PageHeader(
            title: context.tr('care_progress'),
            subtitle: context.tr('care_progress_subtitle'),
            action: IconButton.filledTonal(
              key: const Key('progress_refresh_button'),
              onPressed: _refreshing
                  ? null
                  : () => _loadProgress(refresh: true),
              icon: _refreshing
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.refresh, size: 19),
              tooltip: context.tr('refresh'),
            ),
          ),
          if (_loading)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(48),
                child: CircularProgressIndicator(),
              ),
            )
          else if (_error != null)
            EmptyState(
              icon: _offline ? Icons.wifi_off_outlined : Icons.error_outline,
              title: _offline
                  ? context.tr('progress_offline_title')
                  : context.tr('progress_error_title'),
              description: _error!,
              action: FilledButton(
                key: const Key('progress_retry_button'),
                onPressed: _loadProgress,
                child: Text(context.tr('retry')),
              ),
            )
          else if (summary == null || summary.activePlanCount == 0)
            EmptyState(
              icon: Icons.insights_outlined,
              title: context.tr('progress_no_active_title'),
              description: context.tr('progress_no_active_description'),
              action: FilledButton(
                onPressed: () =>
                    Navigator.pushNamed(context, AppRoutes.carePlanNew),
                child: Text(context.tr('upload_document')),
              ),
            )
          else ...[
            _ProgressCards(summary: summary),
            const SizedBox(height: 24),
            _TaskCompletionTrend(summary: summary),
            const SizedBox(height: 24),
            _ProgressDetails(summary: summary),
          ],
          const SizedBox(height: 24),
          SafetyNote(text: context.tr('progress_safety_note')),
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
      (context.tr('care_readiness'), _scoreLabel(summary.readiness)),
      (
        context.tr('tasks_completed'),
        '${summary.tasks.completed}/${summary.tasks.scheduled}',
      ),
      (
        context.tr('gaps_resolved'),
        '${summary.gaps.resolved}/${summary.gaps.total}',
      ),
      (context.tr('understanding'), _understandingLabel(summary.understanding)),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 900
            ? 4
            : constraints.maxWidth >= 480
            ? 2
            : 1;
        return GridView.count(
          crossAxisCount: columns,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          childAspectRatio: columns == 1 ? 3.2 : 1.55,
          children: stats
              .map(
                (stat) => AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        stat.$1,
                        style: const TextStyle(
                          fontSize: 14,
                          color: AppColors.muted,
                        ),
                      ),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          stat.$2,
                          style: const TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                    ],
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
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.tr('task_completion_trend'),
            style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 22),
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
                          padding: const EdgeInsets.symmetric(horizontal: 5),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              Text(
                                point.value == null ? '-' : '${point.value}%',
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 7),
                              TweenAnimationBuilder<double>(
                                tween: Tween(
                                  begin: 0,
                                  end: point.value == null
                                      ? .08
                                      : point.value! / 100,
                                ),
                                duration: const Duration(milliseconds: 450),
                                curve: Curves.easeOut,
                                builder: (context, value, _) => Container(
                                  height: 150 * value,
                                  decoration: BoxDecoration(
                                    color: point.value == null
                                        ? AppColors.border
                                        : AppColors.primary.withValues(
                                            alpha: .85,
                                          ),
                                    borderRadius: const BorderRadius.vertical(
                                      top: Radius.circular(8),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 7),
                              Text(
                                _dayLabel(point.date),
                                style: const TextStyle(
                                  fontSize: 12,
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
