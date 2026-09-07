import 'package:flutter/material.dart';

import '../core/app_routes.dart';
import '../core/app_theme.dart';
import '../localization/language_scope.dart';
import '../widgets/brand_logo.dart';
import '../widgets/ui.dart';
import '../services/auth_service.dart';

class LandingScreen extends StatefulWidget {
  const LandingScreen({super.key});

  @override
  State<LandingScreen> createState() => _LandingScreenState();
}

class _LandingScreenState extends State<LandingScreen> {
  bool menuOpen = false;
  final howItWorksKey = GlobalKey();
  final featuresKey = GlobalKey();
  final safetyKey = GlobalKey();
  final faqKey = GlobalKey();

  static const navKeys = [
    'landing_nav_how_it_works',
    'landing_nav_features',
    'landing_nav_safety',
    'landing_nav_faq',
  ];

  Future<void> _go(String route) async {
    if (route == AppRoutes.dashboard && !AuthSession.instance.canAccessApp) {
      await AuthSession.instance.startGuestSession();
    }
    if (!mounted) return;
    Navigator.pushNamed(context, route);
  }

  Future<void> _scrollTo(String keyName) async {
    final key = switch (keyName) {
      'landing_nav_how_it_works' => howItWorksKey,
      'landing_nav_features' => featuresKey,
      'landing_nav_safety' => safetyKey,
      _ => faqKey,
    };
    if (menuOpen) setState(() => menuOpen = false);
    final target = key.currentContext;
    if (target == null) return;
    await Scrollable.ensureVisible(
      target,
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeOutCubic,
      alignment: 0.02,
    );
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final desktopNav = width >= 820;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FBFA),
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverAppBar(
              pinned: true,
              toolbarHeight: 68,
              backgroundColor: AppColors.card.withValues(alpha: .96),
              surfaceTintColor: Colors.transparent,
              automaticallyImplyLeading: false,
              titleSpacing: 0,
              title: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1180),
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: width >= 640 ? 24 : 16,
                    ),
                    child: Row(
                      children: [
                        const BrandLogo(),
                        const Spacer(),
                        if (desktopNav) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 5,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF4F8F7),
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(
                                color: const Color(0xFFE3ECEA),
                              ),
                            ),
                            child: Row(
                              children: navKeys
                                  .map(
                                    (labelKey) => InkWell(
                                      onTap: () => _scrollTo(labelKey),
                                      borderRadius: BorderRadius.circular(999),
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 11,
                                          vertical: 7,
                                        ),
                                        child: Text(
                                          context.tr(labelKey),
                                          style: const TextStyle(
                                            color: AppColors.muted,
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    ),
                                  )
                                  .toList(),
                            ),
                          ),
                          const SizedBox(width: 10),
                          TextButton(
                            onPressed: () => _go(AppRoutes.auth),
                            child: Text(context.tr('sign_in')),
                          ),
                          const SizedBox(width: 4),
                          FilledButton.icon(
                            onPressed: () => _go(AppRoutes.auth),
                            icon: const Icon(
                              Icons.arrow_forward_rounded,
                              size: 16,
                            ),
                            label: Text(context.tr('get_started')),
                          ),
                        ] else
                          IconButton(
                            onPressed: () =>
                                setState(() => menuOpen = !menuOpen),
                            icon: Icon(
                              menuOpen
                                  ? Icons.close_rounded
                                  : Icons.menu_rounded,
                            ),
                            tooltip: context.tr(
                              menuOpen ? 'close_menu' : 'open_menu',
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
              bottom: PreferredSize(
                preferredSize: Size.fromHeight(menuOpen ? 224 : 1),
                child: Column(
                  children: [
                    const Divider(height: 1),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 180),
                      child: menuOpen
                          ? Container(
                              key: const ValueKey('landing-mobile-menu'),
                              color: AppColors.card,
                              width: double.infinity,
                              padding: const EdgeInsets.fromLTRB(
                                16,
                                10,
                                16,
                                18,
                              ),
                              child: Center(
                                child: ConstrainedBox(
                                  constraints: const BoxConstraints(
                                    maxWidth: 560,
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      ...navKeys.map(
                                        (labelKey) => InkWell(
                                          onTap: () => _scrollTo(labelKey),
                                          borderRadius: BorderRadius.circular(
                                            AppRadii.lg,
                                          ),
                                          child: Padding(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 10,
                                              vertical: 10,
                                            ),
                                            child: Text(
                                              context.tr(labelKey),
                                              style: const TextStyle(
                                                color: AppColors.muted,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Row(
                                        children: [
                                          Expanded(
                                            child: OutlinedButton(
                                              onPressed: () =>
                                                  _go(AppRoutes.auth),
                                              child: Text(
                                                context.tr('sign_in'),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: FilledButton(
                                              onPressed: () =>
                                                  _go(AppRoutes.auth),
                                              child: Text(
                                                context.tr('get_started'),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            )
                          : const SizedBox.shrink(
                              key: ValueKey('landing-menu-closed'),
                            ),
                    ),
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: _Hero(
                onNavigate: _go,
                onHowItWorks: () => _scrollTo('landing_nav_how_it_works'),
              ),
            ),
            SliverToBoxAdapter(
              child: _LandingSection(
                eyebrow: context.tr('landing_problem_eyebrow'),
                title: context.tr('landing_problem_title'),
                description: context.tr('landing_problem_description'),
                child: const _ProblemGrid(),
              ),
            ),
            SliverToBoxAdapter(
              child: _LandingSection(
                key: howItWorksKey,
                eyebrow: context.tr('landing_how_it_works_eyebrow'),
                title: context.tr('landing_how_it_works_title'),
                tinted: true,
                child: const _HowItWorksGrid(),
              ),
            ),
            SliverToBoxAdapter(
              child: _LandingSection(
                key: featuresKey,
                eyebrow: context.tr('landing_features_eyebrow'),
                title: context.tr('landing_features_title'),
                child: const _FeatureGrid(),
              ),
            ),
            SliverToBoxAdapter(
              child: _LandingSection(
                key: safetyKey,
                eyebrow: context.tr('landing_safety_eyebrow'),
                title: context.tr('landing_safety_title'),
                description: context.tr('landing_safety_description'),
                tinted: true,
                child: const _SafetyGrid(),
              ),
            ),
            SliverToBoxAdapter(
              child: _LandingSection(
                key: faqKey,
                eyebrow: context.tr('landing_faq_eyebrow'),
                title: context.tr('landing_faq_title'),
                child: const _FaqList(),
              ),
            ),
            SliverToBoxAdapter(child: _CallToAction(onNavigate: _go)),
            SliverToBoxAdapter(
              child: _Footer(onNavigate: _go, onSection: _scrollTo),
            ),
          ],
        ),
      ),
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero({required this.onNavigate, required this.onHowItWorks});

  final ValueChanged<String> onNavigate;
  final VoidCallback onHowItWorks;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFF0FDFA), Color(0xFFF8FBFA)],
        ),
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1180),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: MediaQuery.sizeOf(context).width >= 640 ? 24 : 16,
              vertical: MediaQuery.sizeOf(context).width >= 640 ? 82 : 52,
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final narrow = constraints.maxWidth < 860;

                final copy = Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 11,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.card,
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: AppColors.primary.withValues(alpha: .16),
                        ),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x100F172A),
                            blurRadius: 14,
                            spreadRadius: -8,
                            offset: Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.auto_awesome_rounded,
                            size: 14,
                            color: AppColors.primary,
                          ),
                          const SizedBox(width: 7),
                          Text(
                            context.tr('landing_hero_badge'),
                            style: const TextStyle(
                              color: AppColors.accentForeground,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      context.tr('landing_hero_title'),
                      style: TextStyle(
                        color: AppColors.foreground,
                        fontSize: narrow ? 38 : 52,
                        height: 1.06,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -1.1,
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      context.tr('landing_hero_description'),
                      style: const TextStyle(
                        color: AppColors.muted,
                        fontSize: 16,
                        height: 1.6,
                      ),
                    ),
                    const SizedBox(height: 26),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        FilledButton.icon(
                          onPressed: () => onNavigate(AppRoutes.carePlanNew),
                          iconAlignment: IconAlignment.end,
                          icon: const Icon(
                            Icons.arrow_forward_rounded,
                            size: 17,
                          ),
                          label: Text(context.tr('start_care_plan')),
                        ),
                        OutlinedButton.icon(
                          onPressed: onHowItWorks,
                          icon: const Icon(
                            Icons.play_circle_outline_rounded,
                            size: 17,
                          ),
                          label: Text(context.tr('see_how_it_works')),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.shield_outlined,
                          size: 15,
                          color: AppColors.primary,
                        ),
                        const SizedBox(width: 7),
                        Expanded(
                          child: Text(
                            context.tr('landing_demo_note'),
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.muted,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                );

                if (narrow) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      FadeSlideIn(child: copy),
                      const SizedBox(height: 38),
                      const FadeSlideIn(
                        delay: Duration(milliseconds: 90),
                        child: _PreviewCard(),
                      ),
                    ],
                  );
                }

                return Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(flex: 11, child: FadeSlideIn(child: copy)),
                    const SizedBox(width: 54),
                    const Expanded(
                      flex: 9,
                      child: FadeSlideIn(
                        delay: Duration(milliseconds: 90),
                        child: _PreviewCard(),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _PreviewCard extends StatelessWidget {
  const _PreviewCard();

  @override
  Widget build(BuildContext context) {
    return HoverLift(
      child: Container(
        padding: const EdgeInsets.all(1),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF99F6E4), Color(0xFFE2E8F0)],
          ),
          borderRadius: BorderRadius.circular(28),
          boxShadow: const [
            BoxShadow(
              color: Color(0x1C0F766E),
              blurRadius: 32,
              spreadRadius: -12,
              offset: Offset(0, 18),
            ),
          ],
        ),
        child: AppCard(
          padding: EdgeInsets.zero,
          radius: 27,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.all(18),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF0F766E), Color(0xFF0D9488)],
                  ),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(27)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: const Color(0x20FFFFFF),
                        borderRadius: BorderRadius.circular(AppRadii.xl),
                      ),
                      child: const Icon(
                        Icons.insights_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 11),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            context.tr('care_readiness'),
                            style: const TextStyle(
                              fontSize: 11,
                              color: Color(0xDFFFFFFF),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const Text(
                            '82%',
                            style: TextStyle(
                              fontSize: 30,
                              height: 1.05,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0x20FFFFFF),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        context.tr('good'),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: _MetricTile(
                            value: '8',
                            label: context.tr('ready'),
                            tone: _Tone.success,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _MetricTile(
                            value: '2',
                            label: context.tr('at_risk'),
                            tone: _Tone.warning,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _MetricTile(
                            value: '1',
                            label: context.tr('blocked'),
                            tone: _Tone.critical,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Divider(height: 1),
                    const SizedBox(height: 4),
                    _PreviewTask(
                      time: '8:00 AM',
                      title: context.tr('demo_morning_medicine'),
                      state: context.tr('ready'),
                      tone: _Tone.success,
                    ),
                    _PreviewTask(
                      time: '1:00 PM',
                      title: context.tr('demo_afternoon_medicine'),
                      state: context.tr('at_risk'),
                      tone: _Tone.warning,
                    ),
                    _PreviewTask(
                      time: '9:00 AM',
                      title: context.tr('demo_lab_visit_wednesday'),
                      state: context.tr('blocked'),
                      tone: _Tone.critical,
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

enum _Tone { success, warning, critical }

Color _toneSoft(_Tone tone) => switch (tone) {
  _Tone.success => AppColors.successSoft,
  _Tone.warning => AppColors.warningSoft,
  _Tone.critical => AppColors.criticalSoft,
};

Color _toneForeground(_Tone tone) => switch (tone) {
  _Tone.success => AppColors.successForeground,
  _Tone.warning => AppColors.warningForeground,
  _Tone.critical => AppColors.criticalForeground,
};

class _MetricTile extends StatelessWidget {
  const _MetricTile({
    required this.value,
    required this.label,
    required this.tone,
  });

  final String value;
  final String label;
  final _Tone tone;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
    decoration: BoxDecoration(
      color: _toneSoft(tone),
      borderRadius: BorderRadius.circular(AppRadii.xl),
    ),
    child: Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 19,
            fontWeight: FontWeight.w800,
            color: _toneForeground(tone),
          ),
        ),
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: _toneForeground(tone),
          ),
        ),
      ],
    ),
  );
}

class _PreviewTask extends StatelessWidget {
  const _PreviewTask({
    required this.time,
    required this.title,
    required this.state,
    required this.tone,
  });

  final String time;
  final String title;
  final String state;
  final _Tone tone;

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(top: 8),
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(
      color: const Color(0xFFF8FAFC),
      borderRadius: BorderRadius.circular(AppRadii.lg),
    ),
    child: Row(
      children: [
        SizedBox(
          width: 62,
          child: Text(
            time,
            style: const TextStyle(
              fontSize: 10,
              color: AppColors.muted,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        Expanded(
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
          ),
        ),
        const SizedBox(width: 8),
        Icon(
          tone == _Tone.success
              ? Icons.check_circle_outline_rounded
              : tone == _Tone.warning
              ? Icons.warning_amber_rounded
              : Icons.cancel_outlined,
          size: 14,
          color: _toneForeground(tone),
        ),
        const SizedBox(width: 4),
        Text(
          state,
          style: TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.w700,
            color: _toneForeground(tone),
          ),
        ),
      ],
    ),
  );
}

class _LandingSection extends StatelessWidget {
  const _LandingSection({
    required this.title,
    required this.child,
    super.key,
    this.eyebrow,
    this.description,
    this.tinted = false,
  });

  final String? eyebrow;
  final String title;
  final String? description;
  final Widget child;
  final bool tinted;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    color: tinted ? const Color(0xFFF4F8F7) : Colors.transparent,
    child: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1180),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: MediaQuery.sizeOf(context).width >= 640 ? 24 : 16,
            vertical: MediaQuery.sizeOf(context).width >= 640 ? 76 : 58,
          ),
          child: FadeSlideIn(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SectionHeading(
                  eyebrow: eyebrow,
                  title: title,
                  description: description,
                ),
                const SizedBox(height: 30),
                child,
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class _Grid extends StatelessWidget {
  const _Grid({required this.children, required this.desktopColumns});
  final List<Widget> children;
  final int desktopColumns;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final columns = constraints.maxWidth < 600
          ? 1
          : constraints.maxWidth < 900
          ? 2
          : desktopColumns;
      const gap = 16.0;
      final width = (constraints.maxWidth - (columns - 1) * gap) / columns;
      return Wrap(
        spacing: gap,
        runSpacing: gap,
        children: children
            .map((child) => SizedBox(width: width, child: child))
            .toList(),
      );
    },
  );
}

class _ProblemGrid extends StatelessWidget {
  const _ProblemGrid();
  static const items = [
    ('landing_problem_timing_title', 'landing_problem_timing_body'),
    ('landing_problem_help_title', 'landing_problem_help_body'),
    ('landing_problem_unclear_title', 'landing_problem_unclear_body'),
  ];

  @override
  Widget build(BuildContext context) => _Grid(
    desktopColumns: 3,
    children: items
        .map(
          (item) =>
              _InfoCard(title: context.tr(item.$1), body: context.tr(item.$2)),
        )
        .toList(),
  );
}

class _HowItWorksGrid extends StatelessWidget {
  const _HowItWorksGrid();
  static const items = [
    (
      Icons.assignment_outlined,
      'landing_how_upload_title',
      'landing_how_upload_body',
    ),
    (
      Icons.verified_user_outlined,
      'landing_how_verify_title',
      'landing_how_verify_body',
    ),
    (
      Icons.psychology_outlined,
      'landing_how_routine_title',
      'landing_how_routine_body',
    ),
    (
      Icons.route_outlined,
      'landing_how_simulation_title',
      'landing_how_simulation_body',
    ),
  ];

  @override
  Widget build(BuildContext context) => _Grid(
    desktopColumns: 4,
    children: List.generate(items.length, (index) {
      final item = items[index];
      return _IconCard(
        icon: item.$1,
        eyebrow: context.tr('step_number', values: {'number': index + 1}),
        title: context.tr(item.$2),
        body: context.tr(item.$3),
      );
    }),
  );
}

class _FeatureGrid extends StatelessWidget {
  const _FeatureGrid();
  static const items = [
    (
      Icons.route_outlined,
      'care_simulation',
      'landing_feature_simulation_body',
    ),
    (
      Icons.record_voice_over_outlined,
      'teach_back',
      'landing_feature_teach_back_body',
    ),
    (Icons.handshake_outlined, 'family_care', 'landing_feature_family_body'),
    (
      Icons.headphones_outlined,
      'simple_care_mode',
      'landing_feature_simple_body',
    ),
    (
      Icons.language_outlined,
      'landing_feature_languages_title',
      'landing_feature_languages_body',
    ),
    (
      Icons.verified_user_outlined,
      'landing_feature_verification_title',
      'landing_feature_verification_body',
    ),
  ];

  @override
  Widget build(BuildContext context) => _Grid(
    desktopColumns: 2,
    children: items
        .map(
          (item) => _IconCard(
            icon: item.$1,
            title: context.tr(item.$2),
            body: context.tr(item.$3),
          ),
        )
        .toList(),
  );
}

class _SafetyGrid extends StatelessWidget {
  const _SafetyGrid();
  static const items = [
    'landing_safety_verified',
    'landing_safety_readiness',
    'landing_safety_questions',
  ];

  @override
  Widget build(BuildContext context) => _Grid(
    desktopColumns: 3,
    children: items
        .map(
          (key) => AppCard(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.verified_user_outlined,
                  size: 21,
                  color: AppColors.primary,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    context.tr(key),
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppColors.muted,
                      height: 1.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
        )
        .toList(),
  );
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.title, required this.body});
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) => HoverLift(
    child: AppCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.primaryLight,
              borderRadius: BorderRadius.circular(AppRadii.lg),
            ),
            child: const Icon(
              Icons.lightbulb_outline_rounded,
              size: 18,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            title,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Text(
            body,
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.muted,
              height: 1.5,
            ),
          ),
        ],
      ),
    ),
  );
}

class _IconCard extends StatelessWidget {
  const _IconCard({
    required this.icon,
    required this.title,
    required this.body,
    this.eyebrow,
  });
  final IconData icon;
  final String? eyebrow;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) => HoverLift(
    child: AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.primaryLight,
              borderRadius: BorderRadius.circular(AppRadii.xl),
            ),
            child: Icon(icon, size: 20, color: AppColors.primary),
          ),
          const SizedBox(height: 16),
          if (eyebrow != null)
            Text(
              eyebrow!,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.primary,
              ),
            ),
          Text(
            title,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 6),
          Text(
            body,
            style: const TextStyle(
              fontSize: 14,
              color: AppColors.muted,
              height: 1.5,
            ),
          ),
        ],
      ),
    ),
  );
}

class _FaqList extends StatelessWidget {
  const _FaqList();
  static const items = [
    ('landing_faq_medical_advice_q', 'landing_faq_medical_advice_a'),
    ('landing_faq_readiness_q', 'landing_faq_readiness_a'),
    ('landing_faq_family_q', 'landing_faq_family_a'),
    ('landing_faq_privacy_q', 'landing_faq_privacy_a'),
    ('landing_faq_languages_q', 'landing_faq_languages_a'),
  ];

  @override
  Widget build(BuildContext context) => ConstrainedBox(
    constraints: const BoxConstraints(maxWidth: 760),
    child: Column(
      children: items
          .map(
            (item) => ExpansionTile(
              tilePadding: EdgeInsets.zero,
              childrenPadding: const EdgeInsets.only(bottom: 16),
              shape: const Border(bottom: BorderSide(color: AppColors.border)),
              collapsedShape: const Border(
                bottom: BorderSide(color: AppColors.border),
              ),
              title: Text(
                context.tr(item.$1),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    context.tr(item.$2),
                    style: const TextStyle(
                      fontSize: 15,
                      color: AppColors.muted,
                      height: 1.5,
                    ),
                  ),
                ),
              ],
            ),
          )
          .toList(),
    ),
  );
}

class _CallToAction extends StatelessWidget {
  const _CallToAction({required this.onNavigate});

  final ValueChanged<String> onNavigate;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: EdgeInsets.symmetric(
      horizontal: MediaQuery.sizeOf(context).width >= 640 ? 24 : 16,
      vertical: 66,
    ),
    child: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1180),
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: MediaQuery.sizeOf(context).width >= 640 ? 48 : 22,
            vertical: 42,
          ),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF0F766E), Color(0xFF0D9488), Color(0xFF14B8A6)],
            ),
            borderRadius: BorderRadius.circular(28),
            boxShadow: const [
              BoxShadow(
                color: Color(0x220F766E),
                blurRadius: 30,
                spreadRadius: -12,
                offset: Offset(0, 16),
              ),
            ],
          ),
          child: Column(
            children: [
              Text(
                context.tr('landing_cta_title'),
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: MediaQuery.sizeOf(context).width >= 640 ? 30 : 24,
                  height: 1.15,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 11),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 620),
                child: Text(
                  context.tr('landing_cta_description'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Color(0xE6FFFFFF),
                    fontSize: 13,
                    height: 1.5,
                  ),
                ),
              ),
              const SizedBox(height: 22),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                alignment: WrapAlignment.center,
                children: [
                  FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: AppColors.primary,
                    ),
                    onPressed: () => onNavigate(AppRoutes.auth),
                    child: Text(context.tr('get_started')),
                  ),
                  OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Color(0x55FFFFFF)),
                    ),
                    onPressed: () => onNavigate(AppRoutes.dashboard),
                    child: Text(context.tr('view_demo_dashboard')),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _Footer extends StatelessWidget {
  const _Footer({required this.onNavigate, required this.onSection});

  final ValueChanged<String> onNavigate;
  final ValueChanged<String> onSection;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    color: const Color(0xFF0F2725),
    padding: EdgeInsets.symmetric(
      horizontal: MediaQuery.sizeOf(context).width >= 640 ? 24 : 16,
      vertical: 42,
    ),
    child: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1180),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 40,
              runSpacing: 24,
              children: [
                SizedBox(
                  width: 410,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const BrandLogo(),
                      const SizedBox(height: 12),
                      Text(
                        context.tr('landing_footer_description'),
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xBFFFFFFF),
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
                Wrap(
                  spacing: 20,
                  runSpacing: 8,
                  children: [
                    ..._LandingScreenState.navKeys.map(
                      (labelKey) => InkWell(
                        onTap: () => onSection(labelKey),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            vertical: 8,
                            horizontal: 4,
                          ),
                          child: Text(
                            context.tr(labelKey),
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xD9FFFFFF),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ),
                    TextButton(
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.white,
                      ),
                      onPressed: () => onNavigate(AppRoutes.auth),
                      child: Text(context.tr('sign_in')),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 28),
            const Divider(color: Color(0x26FFFFFF)),
            const SizedBox(height: 18),
            Text(
              context.tr('landing_footer_copyright'),
              style: const TextStyle(fontSize: 11, color: Color(0x99FFFFFF)),
            ),
          ],
        ),
      ),
    ),
  );
}
