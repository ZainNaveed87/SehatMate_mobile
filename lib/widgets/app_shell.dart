import 'package:flutter/material.dart';

import '../core/app_routes.dart';
import '../core/app_theme.dart';
import '../data/demo_data.dart';
import '../features/agent/agent_entry.dart';
import '../features/agent/models/agent_context.dart';
import '../localization/app_language.dart';
import '../localization/language_scope.dart';
import '../services/auth_service.dart';
import 'brand_logo.dart';

const _logoutAction = '__logout__';

/// Keeps Dashboard as the stable authenticated root.
///
/// Top-level shell navigation should not continuously replace the only route
/// in the Navigator. Otherwise Android Back can exhaust the stack and make
/// navigation look like the user was signed out.
///
/// Result:
///
/// Dashboard -> Care Plans -> Back -> Dashboard
///
/// Dashboard -> Care Plans -> Calendar -> Back -> Dashboard
///
/// Detail-screen navigation can still use its normal local route stack.
void _navigateShellRoute(
  BuildContext context, {
  required String currentRoute,
  required String route,
}) {
  if (route == currentRoute) {
    return;
  }

  if (route == AppRoutes.dashboard) {
    Navigator.pushNamedAndRemoveUntil(
      context,
      AppRoutes.dashboard,
      (_) => false,
    );
    return;
  }

  Navigator.pushNamedAndRemoveUntil(
    context,
    route,
    (candidate) => candidate.settings.name == AppRoutes.dashboard,
  );
}

class ShellNavItem {
  const ShellNavItem(
    this.route,
    this.labelKey,
    this.icon, {
    this.mobileLabelKey,
  });

  final String route;
  final String labelKey;
  final String? mobileLabelKey;
  final IconData icon;

  String label(BuildContext context) => context.tr(labelKey);

  String mobileLabel(BuildContext context) =>
      context.tr(mobileLabelKey ?? labelKey);
}

const shellNav = [
  ShellNavItem(
    AppRoutes.dashboard,
    'dashboard',
    Icons.dashboard_outlined,
    mobileLabelKey: 'home',
  ),
  ShellNavItem(
    AppRoutes.carePlans,
    'care_plans',
    Icons.checklist_outlined,
    mobileLabelKey: 'plans',
  ),
  ShellNavItem(AppRoutes.calendar, 'calendar', Icons.calendar_month_outlined),
  ShellNavItem(
    AppRoutes.family,
    'family_care',
    Icons.handshake_outlined,
    mobileLabelKey: 'family',
  ),
  ShellNavItem(
    AppRoutes.teachBack,
    'teach_back',
    Icons.record_voice_over_outlined,
  ),
  ShellNavItem(AppRoutes.progress, 'progress', Icons.speed_outlined),
  ShellNavItem(AppRoutes.documents, 'documents', Icons.description_outlined),
];

class AppShell extends StatelessWidget {
  const AppShell({
    required this.currentRoute,
    required this.title,
    required this.child,
    super.key,
    this.subtitle,
  });

  final String currentRoute;
  final String title;
  final String? subtitle;
  final Widget child;

  void _go(BuildContext context, String route) {
    _navigateShellRoute(context, currentRoute: currentRoute, route: route);
  }

  @override
  Widget build(BuildContext context) {
    final desktop = MediaQuery.sizeOf(context).width >= 1024;
    final language = context.appLanguage;

    return Directionality(
      textDirection: language.textDirection,
      child: Scaffold(
        floatingActionButton: AuthSession.instance.canAccessApp
            ? FloatingActionButton.small(
                tooltip: context.tr('agent_title'),
                onPressed: () => openAgent(
                  context,
                  screenContext: _agentContextForRoute(currentRoute),
                ),
                child: const Icon(Icons.auto_awesome_outlined),
              )
            : null,
        bottomNavigationBar: desktop
            ? null
            : _MobileNavigation(currentRoute: currentRoute),
        body: SafeArea(
          child: Row(
            children: [
              if (desktop)
                _DesktopSidebar(
                  currentRoute: currentRoute,
                  onNavigate: (route) => _go(context, route),
                ),
              Expanded(
                child: Column(
                  children: [
                    _ShellHeader(
                      desktop: desktop,
                      title: title,
                      subtitle: subtitle,
                      onNavigate: (route) => _go(context, route),
                    ),
                    Expanded(
                      child: SingleChildScrollView(
                        padding: EdgeInsets.fromLTRB(
                          desktop ? 24 : 16,
                          24,
                          desktop ? 24 : 16,
                          desktop ? 48 : 28,
                        ),
                        child: Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 1180),
                            child: child,
                          ),
                        ),
                      ),
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

AgentScreenContext? _agentContextForRoute(String route) {
  if (route == AppRoutes.dashboard) {
    return const AgentScreenContext(screenId: 'home');
  }
  if (route == AppRoutes.calendar) {
    return const AgentScreenContext(screenId: 'today');
  }
  if (route == AppRoutes.carePlans) {
    return const AgentScreenContext(screenId: 'care_plans');
  }
  if (route == AppRoutes.realityCheck) {
    return const AgentScreenContext(screenId: 'reality_check');
  }
  if (route == AppRoutes.simulation) {
    return const AgentScreenContext(screenId: 'simulation');
  }
  if (route == AppRoutes.careGaps) {
    return const AgentScreenContext(screenId: 'care_gaps');
  }
  if (route == AppRoutes.family) {
    return const AgentScreenContext(screenId: 'family_care');
  }
  if (route == AppRoutes.routinePreferences) {
    return const AgentScreenContext(screenId: 'routine_settings');
  }
  if (route == AppRoutes.patientProfile) {
    return const AgentScreenContext(screenId: 'profile');
  }
  if (route == AppRoutes.documents) {
    return const AgentScreenContext(screenId: 'documents');
  }
  if (route == AppRoutes.notifications) {
    return const AgentScreenContext(screenId: 'notifications');
  }
  if (route == AppRoutes.settings) {
    return const AgentScreenContext(screenId: 'settings');
  }

  const carePlanPrefix = '/care-plan/';
  if (route.startsWith(carePlanPrefix)) {
    final id = route.split('/').last;
    return AgentScreenContext(
      screenId: 'care_plan_detail',
      entity: AgentEntityContext(type: 'care_plan', id: id),
    );
  }
  if (route.startsWith('${AppRoutes.careGaps}/')) {
    final id = route.split('/').last;
    return AgentScreenContext(
      screenId: 'care_gap_detail',
      entity: AgentEntityContext(type: 'care_gap', id: id),
    );
  }
  if (route.startsWith('${AppRoutes.family}/')) {
    final id = route.split('/').last;
    return AgentScreenContext(
      screenId: 'family_member_detail',
      entity: AgentEntityContext(type: 'family_member', id: id),
    );
  }

  return null;
}

class _DesktopSidebar extends StatelessWidget {
  const _DesktopSidebar({required this.currentRoute, required this.onNavigate});

  final String currentRoute;
  final ValueChanged<String> onNavigate;

  bool _active(String route) => currentRoute.startsWith(route);

  @override
  Widget build(BuildContext context) => Container(
    width: 248,
    decoration: const BoxDecoration(
      color: AppColors.card,
      border: Border(right: BorderSide(color: AppColors.border)),
    ),
    child: Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
          child: Align(
            alignment: AlignmentDirectional.centerStart,
            child: InkWell(
              onTap: () => onNavigate(AppRoutes.dashboard),
              child: const BrandLogo(),
            ),
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            children: shellNav.map((item) => _sideItem(context, item)).toList(),
          ),
        ),
        const Divider(height: 1),
        Padding(
          padding: const EdgeInsets.all(12),
          child: _sideItem(
            context,
            const ShellNavItem(
              AppRoutes.settings,
              'settings',
              Icons.settings_outlined,
            ),
          ),
        ),
      ],
    ),
  );

  Widget _sideItem(BuildContext context, ShellNavItem item) {
    final active = _active(item.route);

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: InkWell(
        onTap: () => onNavigate(item.route),
        borderRadius: BorderRadius.circular(AppRadii.xl),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
          decoration: BoxDecoration(
            color: active ? AppColors.primaryLight : Colors.transparent,
            borderRadius: BorderRadius.circular(AppRadii.xl),
          ),
          child: Row(
            children: [
              Icon(
                item.icon,
                size: 19,
                color: active ? AppColors.accentForeground : AppColors.muted,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  item.label(context),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: active
                        ? AppColors.accentForeground
                        : AppColors.muted,
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ShellHeader extends StatelessWidget {
  const _ShellHeader({
    required this.desktop,
    required this.title,
    required this.onNavigate,
    this.subtitle,
  });

  final bool desktop;
  final String title;
  final String? subtitle;
  final ValueChanged<String> onNavigate;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: Listenable.merge([CareDemoState.instance, AuthSession.instance]),
    builder: (context, _) {
      final user = AuthSession.instance.user;
      final displayName = user?.name ?? context.tr('guest_user');
      final displayEmail = user?.email ?? context.tr('demo_access');
      final initials = user?.initials ?? 'G';

      return Container(
        height: 64,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: const BoxDecoration(
          color: AppColors.card,
          border: Border(bottom: BorderSide(color: AppColors.border)),
        ),
        child: Row(
          children: [
            if (desktop)
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (subtitle != null)
                      Text(
                        subtitle!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.muted,
                        ),
                      ),
                  ],
                ),
              )
            else ...[
              InkWell(
                onTap: () => onNavigate(AppRoutes.dashboard),
                child: const BrandLogo(),
              ),
              const Spacer(),
            ],
            _LanguageMenu(compact: !desktop),
            const SizedBox(width: 8),
            Stack(
              children: [
                IconButton(
                  tooltip: context.tr('notifications'),
                  onPressed: () => onNavigate(AppRoutes.notifications),
                  icon: const Icon(Icons.notifications_none, size: 20),
                ),
                if (CareDemoState.instance.unreadNotifications > 0)
                  const PositionedDirectional(
                    end: 10,
                    top: 10,
                    child: CircleAvatar(
                      radius: 4,
                      backgroundColor: AppColors.critical,
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 4),
            PopupMenuButton<String>(
              onSelected: (value) async {
                if (value != _logoutAction) {
                  onNavigate(value);
                  return;
                }

                await AuthSession.instance.logout();
                if (!context.mounted) return;

                Navigator.pushNamedAndRemoveUntil(
                  context,
                  AppRoutes.landing,
                  (_) => false,
                );
              },
              itemBuilder: (_) => [
                PopupMenuItem<String>(
                  enabled: false,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        displayName,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          color: AppColors.foreground,
                        ),
                      ),
                      Text(
                        displayEmail,
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.muted,
                        ),
                      ),
                    ],
                  ),
                ),
                const PopupMenuDivider(),
                PopupMenuItem(
                  value: AppRoutes.patientProfile,
                  child: Text(context.tr('patient_profile')),
                ),
                PopupMenuItem(
                  value: AppRoutes.settings,
                  child: Text(context.tr('language')),
                ),
                PopupMenuItem(
                  value: AppRoutes.settings,
                  child: Text(context.tr('settings')),
                ),
                const PopupMenuDivider(),
                PopupMenuItem(
                  value: _logoutAction,
                  child: Text(context.tr('logout')),
                ),
              ],
              child: CircleAvatar(
                radius: 18,
                backgroundColor: AppColors.primaryLight,
                child: Text(
                  initials,
                  style: const TextStyle(
                    color: AppColors.accentForeground,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    },
  );
}

class _LanguageMenu extends StatelessWidget {
  const _LanguageMenu({required this.compact});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    final controller = LanguageScope.watch(context);
    final selected = controller.language;

    return PopupMenuButton<AppLanguage>(
      tooltip: context.tr('choose_language'),
      initialValue: selected,
      onSelected: (language) async {
        await controller.setLanguage(language);

        // Keep the older demo preference in sync so existing demo-only code
        // that still reads CareDemoState.language does not disagree.
        CareDemoState.instance.updatePreferences(
          language: language.displayName,
        );
      },
      itemBuilder: (_) => AppLanguage.values
          .map(
            (language) => PopupMenuItem<AppLanguage>(
              value: language,
              child: Row(
                children: [
                  SizedBox(
                    width: 22,
                    child: selected == language
                        ? const Icon(Icons.check, size: 18)
                        : null,
                  ),
                  const SizedBox(width: 8),
                  Text(language.displayName),
                ],
              ),
            ),
          )
          .toList(),
      child: Container(
        height: 36,
        constraints: BoxConstraints(minWidth: compact ? 36 : 88),
        padding: EdgeInsets.symmetric(horizontal: compact ? 8 : 12),
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(AppRadii.md),
        ),
        alignment: Alignment.center,
        child: compact
            ? const Icon(Icons.language_outlined, size: 19)
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.language_outlined, size: 17),
                  const SizedBox(width: 7),
                  Text(
                    selected.shortLabel,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class _MobileNavigation extends StatelessWidget {
  const _MobileNavigation({required this.currentRoute});

  final String currentRoute;

  @override
  Widget build(BuildContext context) {
    final items = shellNav.take(4).toList();

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.card,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            ...items.map(
              (item) => Expanded(
                child: _MobileItem(item: item, currentRoute: currentRoute),
              ),
            ),
            Expanded(
              child: PopupMenuButton<String>(
                onSelected: (route) => _navigateShellRoute(
                  context,
                  currentRoute: currentRoute,
                  route: route,
                ),
                itemBuilder: (_) => [
                  PopupMenuItem(
                    value: AppRoutes.teachBack,
                    child: Text(context.tr('teach_back')),
                  ),
                  PopupMenuItem(
                    value: AppRoutes.careGaps,
                    child: Text(context.tr('care_gaps')),
                  ),
                  PopupMenuItem(
                    value: AppRoutes.simulation,
                    child: Text(context.tr('care_simulation')),
                  ),
                  PopupMenuItem(
                    value: AppRoutes.progress,
                    child: Text(context.tr('progress')),
                  ),
                  PopupMenuItem(
                    value: AppRoutes.documents,
                    child: Text(context.tr('documents')),
                  ),
                  PopupMenuItem(
                    value: AppRoutes.simpleCare,
                    child: Text(context.tr('simple_care_mode')),
                  ),
                  PopupMenuItem(
                    value: AppRoutes.settings,
                    child: Text(context.tr('settings')),
                  ),
                ],
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 9),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.more_horiz,
                        size: 21,
                        color: AppColors.muted,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        context.tr('more'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.muted,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MobileItem extends StatelessWidget {
  const _MobileItem({required this.item, required this.currentRoute});

  final ShellNavItem item;
  final String currentRoute;

  @override
  Widget build(BuildContext context) {
    final active = currentRoute.startsWith(item.route);
    final color = active ? AppColors.primary : AppColors.muted;

    return InkWell(
      onTap: () => _navigateShellRoute(
        context,
        currentRoute: currentRoute,
        route: item.route,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 9),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(item.icon, size: 21, color: color),
            const SizedBox(height: 3),
            Text(
              item.mobileLabel(context),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12, color: color),
            ),
          ],
        ),
      ),
    );
  }
}
