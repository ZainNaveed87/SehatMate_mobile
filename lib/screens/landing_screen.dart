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
    return Scaffold(
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverAppBar(
              pinned: true,
              toolbarHeight: 64,
              backgroundColor: AppColors.card.withValues(alpha: .95),
              surfaceTintColor: Colors.transparent,
              automaticallyImplyLeading: false,
              titleSpacing: 0,
              title: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1120),
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: MediaQuery.sizeOf(context).width >= 640 ? 24 : 16),
                    child: Row(
                      children: [
                        const BrandLogo(),
                        const Spacer(),
                        if (MediaQuery.sizeOf(context).width >= 768) ...[
                          ...navKeys.map(
                            (labelKey) => Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 14),
                              child: InkWell(
                                onTap: () => _scrollTo(labelKey),
                                borderRadius: BorderRadius.circular(8),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 8),
                                  child: Text(
                                    context.tr(labelKey),
                                    style: const TextStyle(
                                      color: AppColors.muted,
                                      fontSize: 15,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          TextButton(
                            onPressed: () => _go(AppRoutes.auth),
                            child: Text(context.tr('sign_in')),
                          ),
                          const SizedBox(width: 4),
                          FilledButton(
                            onPressed: () => _go(AppRoutes.auth),
                            child: Text(context.tr('get_started')),
                          ),
                        ] else
                          IconButton(
                            onPressed: () => setState(() => menuOpen = !menuOpen),
                            icon: const Icon(Icons.menu),
                            tooltip: context.tr(menuOpen ? 'close_menu' : 'open_menu'),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
              bottom: PreferredSize(
                preferredSize: Size.fromHeight(menuOpen ? 205 : 1),
                child: Column(
                  children: [
                    const Divider(height: 1),
                    if (menuOpen)
                      Container(
                        color: AppColors.card,
                        width: double.infinity,
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            ...navKeys.map(
                              (labelKey) => Padding(
                                padding: const EdgeInsets.symmetric(vertical: 7),
                                child: InkWell(
                                  onTap: () => _scrollTo(labelKey),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 3),
                                    child: Text(context.tr(labelKey), style: const TextStyle(color: AppColors.muted)),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton(
                                    onPressed: () => _go(AppRoutes.auth),
                                    child: Text(context.tr('sign_in')),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: FilledButton(
                                    onPressed: () => _go(AppRoutes.auth),
                                    child: Text(context.tr('get_started')),
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
            ),
            SliverToBoxAdapter(child: _Hero(onNavigate: _go, onHowItWorks: () => _scrollTo('landing_nav_how_it_works'))),
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
            SliverToBoxAdapter(child: _Footer(onNavigate: _go, onSection: _scrollTo)),
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
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1120),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: MediaQuery.sizeOf(context).width >= 640 ? 24 : 16,
            vertical: MediaQuery.sizeOf(context).width >= 640 ? 80 : 56,
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final narrow = constraints.maxWidth < 820;
              final copy = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                    decoration: BoxDecoration(
                      color: AppColors.primaryLight,
                      borderRadius: BorderRadius.circular(99),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.auto_awesome, size: 14, color: AppColors.primary),
                        const SizedBox(width: 7),
                        Text(
                          context.tr('landing_hero_badge'),
                          style: const TextStyle(
                            color: AppColors.accentForeground,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    context.tr('landing_hero_title'),
                    style: TextStyle(
                      color: AppColors.foreground,
                      fontSize: narrow ? 34 : 44,
                      height: 1.15,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.7,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    context.tr('landing_hero_description'),
                    style: const TextStyle(color: AppColors.muted, fontSize: 16, height: 1.55),
                  ),
                  const SizedBox(height: 28),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      FilledButton.icon(
                        onPressed: () => onNavigate(AppRoutes.carePlanNew),
                        iconAlignment: IconAlignment.end,
                        icon: const Icon(Icons.arrow_forward, size: 17),
                        label: Text(context.tr('start_care_plan')),
                      ),
                      OutlinedButton(
                        onPressed: onHowItWorks,
                        child: Text(context.tr('see_how_it_works')),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Text(
                    context.tr('landing_demo_note'),
                    style: const TextStyle(fontSize: 13, color: AppColors.muted),
                  ),
                ],
              );
              const preview = FadeSlideIn(child: _PreviewCard());
              final animatedCopy = FadeSlideIn(child: copy);
              if (narrow) {
                return Column(children: [animatedCopy, const SizedBox(height: 40), preview]);
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(child: animatedCopy),
                  const SizedBox(width: 56),
                  const Expanded(child: preview),
                ],
              );
            },
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
    return AppCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.tr('care_readiness'),
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.muted),
                    ),
                    const Text(
                      '82%',
                      style: TextStyle(fontSize: 40, height: 1.15, fontWeight: FontWeight.w700, color: AppColors.primary),
                    ),
                  ],
                ),
              ),
              _ToneTag(text: context.tr('good'), tone: _Tone.success),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: _MetricTile(value: '8', label: context.tr('ready'), tone: _Tone.success)),
              const SizedBox(width: 8),
              Expanded(child: _MetricTile(value: '2', label: context.tr('at_risk'), tone: _Tone.warning)),
              const SizedBox(width: 8),
              Expanded(child: _MetricTile(value: '1', label: context.tr('blocked'), tone: _Tone.critical)),
            ],
          ),
          const SizedBox(height: 20),
          const Divider(height: 1),
          const SizedBox(height: 16),
          _PreviewTask(time: '8:00 AM', title: context.tr('demo_morning_medicine'), state: context.tr('ready'), tone: _Tone.success),
          const SizedBox(height: 12),
          _PreviewTask(time: '1:00 PM', title: context.tr('demo_afternoon_medicine'), state: context.tr('at_risk'), tone: _Tone.warning),
          const SizedBox(height: 12),
          _PreviewTask(time: '9:00 AM', title: context.tr('demo_lab_visit_wednesday'), state: context.tr('blocked'), tone: _Tone.critical),
        ],
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

class _ToneTag extends StatelessWidget {
  const _ToneTag({required this.text, required this.tone});
  final String text;
  final _Tone tone;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(color: _toneSoft(tone), borderRadius: BorderRadius.circular(99)),
        child: Text(
          text,
          style: TextStyle(color: _toneForeground(tone), fontSize: 13, fontWeight: FontWeight.w500),
        ),
      );
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({required this.value, required this.label, required this.tone});
  final String value;
  final String label;
  final _Tone tone;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(color: _toneSoft(tone), borderRadius: BorderRadius.circular(AppRadii.xl)),
        child: Column(
          children: [
            Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: _toneForeground(tone))),
            Text(label, style: TextStyle(fontSize: 12, color: _toneForeground(tone))),
          ],
        ),
      );
}

class _PreviewTask extends StatelessWidget {
  const _PreviewTask({required this.time, required this.title, required this.state, required this.tone});
  final String time;
  final String title;
  final String state;
  final _Tone tone;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          SizedBox(width: 68, child: Text(time, style: const TextStyle(fontSize: 13, color: AppColors.muted))),
          Expanded(child: Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500))),
          const SizedBox(width: 8),
          Icon(
            tone == _Tone.success
                ? Icons.check_circle_outline
                : tone == _Tone.warning
                    ? Icons.warning_amber_rounded
                    : Icons.cancel_outlined,
            size: 15,
            color: _toneForeground(tone),
          ),
          const SizedBox(width: 4),
          Text(state, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: _toneForeground(tone))),
        ],
      );
}

class _LandingSection extends StatelessWidget {
  const _LandingSection({required this.title, required this.child, super.key, this.eyebrow, this.description});
  final String? eyebrow;
  final String title;
  final String? description;
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        decoration: const BoxDecoration(border: Border(top: BorderSide(color: AppColors.border))),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1120),
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: MediaQuery.sizeOf(context).width >= 640 ? 24 : 16,
                vertical: MediaQuery.sizeOf(context).width >= 640 ? 80 : 64,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SectionHeading(eyebrow: eyebrow, title: title, description: description),
                  const SizedBox(height: 32),
                  child,
                ],
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
          final columns = constraints.maxWidth < 600 ? 1 : constraints.maxWidth < 900 ? 2 : desktopColumns;
          const gap = 16.0;
          final width = (constraints.maxWidth - (columns - 1) * gap) / columns;
          return Wrap(
            spacing: gap,
            runSpacing: gap,
            children: children.map((child) => SizedBox(width: width, child: child)).toList(),
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
              (item) => _InfoCard(
                title: context.tr(item.$1),
                body: context.tr(item.$2),
              ),
            )
            .toList(),
      );
}

class _HowItWorksGrid extends StatelessWidget {
  const _HowItWorksGrid();
  static const items = [
    (Icons.assignment_outlined, 'landing_how_upload_title', 'landing_how_upload_body'),
    (Icons.verified_user_outlined, 'landing_how_verify_title', 'landing_how_verify_body'),
    (Icons.psychology_outlined, 'landing_how_routine_title', 'landing_how_routine_body'),
    (Icons.route_outlined, 'landing_how_simulation_title', 'landing_how_simulation_body'),
  ];

  @override
  Widget build(BuildContext context) => _Grid(
        desktopColumns: 4,
        children: List.generate(items.length, (index) {
          final item = items[index];
          return _IconCard(
            icon: item.$1,
            eyebrow: context.tr(
              'step_number',
              values: {'number': index + 1},
            ),
            title: context.tr(item.$2),
            body: context.tr(item.$3),
          );
        }),
      );
}

class _FeatureGrid extends StatelessWidget {
  const _FeatureGrid();
  static const items = [
    (Icons.route_outlined, 'care_simulation', 'landing_feature_simulation_body'),
    (Icons.record_voice_over_outlined, 'teach_back', 'landing_feature_teach_back_body'),
    (Icons.handshake_outlined, 'family_care', 'landing_feature_family_body'),
    (Icons.headphones_outlined, 'simple_care_mode', 'landing_feature_simple_body'),
    (Icons.language_outlined, 'landing_feature_languages_title', 'landing_feature_languages_body'),
    (Icons.verified_user_outlined, 'landing_feature_verification_title', 'landing_feature_verification_body'),
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
                    const Icon(Icons.verified_user_outlined, size: 21, color: AppColors.primary),
                    const SizedBox(width: 12),
                    Expanded(child: Text(context.tr(key), style: const TextStyle(fontSize: 14, color: AppColors.muted, height: 1.5))),
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
  Widget build(BuildContext context) => AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Text(body, style: const TextStyle(fontSize: 14, color: AppColors.muted, height: 1.5)),
          ],
        ),
      );
}

class _IconCard extends StatelessWidget {
  const _IconCard({required this.icon, required this.title, required this.body, this.eyebrow});
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
              decoration: BoxDecoration(color: AppColors.primaryLight, borderRadius: BorderRadius.circular(AppRadii.xl)),
              child: Icon(icon, size: 20, color: AppColors.primary),
            ),
            const SizedBox(height: 16),
            if (eyebrow != null)
              Text(eyebrow!, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.primary)),
            Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            Text(body, style: const TextStyle(fontSize: 14, color: AppColors.muted, height: 1.5)),
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
                  collapsedShape: const Border(bottom: BorderSide(color: AppColors.border)),
                  title: Text(context.tr(item.$1), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(context.tr(item.$2), style: const TextStyle(fontSize: 15, color: AppColors.muted, height: 1.5)),
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
        decoration: const BoxDecoration(border: Border(top: BorderSide(color: AppColors.border))),
        padding: EdgeInsets.symmetric(horizontal: MediaQuery.sizeOf(context).width >= 640 ? 24 : 16, vertical: 64),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1120),
            child: AppCard(
              padding: EdgeInsets.symmetric(horizontal: MediaQuery.sizeOf(context).width >= 640 ? 48 : 24, vertical: 40),
              child: Column(
                children: [
                  Text(
                    context.tr('landing_cta_title'),
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: MediaQuery.sizeOf(context).width >= 640 ? 28 : 24, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 12),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 580),
                    child: Text(
                      context.tr('landing_cta_description'),
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: AppColors.muted),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    alignment: WrapAlignment.center,
                    children: [
                      FilledButton(onPressed: () => onNavigate(AppRoutes.auth), child: Text(context.tr('get_started'))),
                      OutlinedButton(onPressed: () => onNavigate(AppRoutes.dashboard), child: Text(context.tr('view_demo_dashboard'))),
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
        color: AppColors.card,
        padding: EdgeInsets.symmetric(horizontal: MediaQuery.sizeOf(context).width >= 640 ? 24 : 16, vertical: 40),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1120),
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
                      width: 390,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const BrandLogo(),
                          const SizedBox(height: 12),
                          Text(
                            context.tr('landing_footer_description'),
                            style: const TextStyle(fontSize: 13, color: AppColors.muted),
                          ),
                        ],
                      ),
                    ),
                    Wrap(
                      spacing: 24,
                      runSpacing: 10,
                      children: [
                        ..._LandingScreenState.navKeys.map(
                          (labelKey) => InkWell(
                            onTap: () => onSection(labelKey),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              child: Text(context.tr(labelKey), style: const TextStyle(fontSize: 14, color: AppColors.muted)),
                            ),
                          ),
                        ),
                        TextButton(onPressed: () => onNavigate(AppRoutes.auth), child: Text(context.tr('sign_in'))),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 32),
                Text(context.tr('landing_footer_copyright'), style: const TextStyle(fontSize: 13, color: AppColors.subtle)),
              ],
            ),
          ),
        ),
      );
}
