import 'package:flutter/material.dart';

import '../core/app_routes.dart';
import '../core/app_theme.dart';
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

  static const navLabels = ['How It Works', 'Features', 'Safety', 'FAQ'];

  Future<void> _go(String route) async {
    if (route == AppRoutes.dashboard && !AuthSession.instance.canAccessApp) {
      await AuthSession.instance.startGuestSession();
    }
    if (!mounted) return;
    Navigator.pushNamed(context, route);
  }

  Future<void> _scrollTo(String label) async {
    final key = switch (label) {
      'How It Works' => howItWorksKey,
      'Features' => featuresKey,
      'Safety' => safetyKey,
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
                          ...navLabels.map(
                            (label) => Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 14),
                              child: InkWell(
                                onTap: () => _scrollTo(label),
                                borderRadius: BorderRadius.circular(8),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 8),
                                  child: Text(
                                    label,
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
                            child: const Text('Sign In'),
                          ),
                          const SizedBox(width: 4),
                          FilledButton(
                            onPressed: () => _go(AppRoutes.auth),
                            child: const Text('Get Started'),
                          ),
                        ] else
                          IconButton(
                            onPressed: () => setState(() => menuOpen = !menuOpen),
                            icon: const Icon(Icons.menu),
                            tooltip: menuOpen ? 'Close menu' : 'Open menu',
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
                            ...navLabels.map(
                              (label) => Padding(
                                padding: const EdgeInsets.symmetric(vertical: 7),
                                child: InkWell(
                                  onTap: () => _scrollTo(label),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 3),
                                    child: Text(label, style: const TextStyle(color: AppColors.muted)),
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
                                    child: const Text('Sign In'),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: FilledButton(
                                    onPressed: () => _go(AppRoutes.auth),
                                    child: const Text('Get Started'),
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
            SliverToBoxAdapter(child: _Hero(onNavigate: _go, onHowItWorks: () => _scrollTo('How It Works'))),
            const SliverToBoxAdapter(
              child: _LandingSection(
                eyebrow: 'The problem',
                title: 'Care plans are written for ideal days, not real ones.',
                description:
                    "Patients leave the hospital with clear instructions and still miss doses, appointments and dressings — not because they don't care, but because daily life gets in the way.",
                child: _ProblemGrid(),
              ),
            ),
            SliverToBoxAdapter(
              child: _LandingSection(
                key: howItWorksKey,
                eyebrow: 'How it works',
                title: "From doctor's instructions to a plan that fits real life.",
                child: _HowItWorksGrid(),
              ),
            ),
            SliverToBoxAdapter(
              child: _LandingSection(
                key: featuresKey,
                eyebrow: 'Features',
                title: 'Everything a family needs to keep the plan on track.',
                child: _FeatureGrid(),
              ),
            ),
            SliverToBoxAdapter(
              child: _LandingSection(
                key: safetyKey,
                eyebrow: 'Responsible AI',
                title: 'We are not replacing the doctor.',
                description:
                    'SehatMate helps organize and understand an existing care plan. It does not diagnose conditions, prescribe treatment or change doses.',
                child: _SafetyGrid(),
              ),
            ),
            SliverToBoxAdapter(
              child: _LandingSection(
                key: faqKey,
                eyebrow: 'FAQ',
                title: 'Common questions',
                child: _FaqList(),
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
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.auto_awesome, size: 14, color: AppColors.primary),
                        SizedBox(width: 7),
                        Text(
                          'Care-plan support, not diagnosis',
                          style: TextStyle(
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
                    'Make every care plan easier to follow at home.',
                    style: TextStyle(
                      color: AppColors.foreground,
                      fontSize: narrow ? 34 : 44,
                      height: 1.15,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.7,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'SehatMate AI helps identify real-life barriers that can make doctor-prescribed care difficult to follow, so patients and families can prepare before problems happen.',
                    style: TextStyle(color: AppColors.muted, fontSize: 16, height: 1.55),
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
                        label: const Text('Start Care Plan'),
                      ),
                      OutlinedButton(
                        onPressed: onHowItWorks,
                        child: const Text('See How It Works'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Demo experience with sample data. No real medical records required.',
                    style: TextStyle(fontSize: 13, color: AppColors.muted),
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
          const Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Care Readiness',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.muted),
                    ),
                    Text(
                      '82%',
                      style: TextStyle(fontSize: 40, height: 1.15, fontWeight: FontWeight.w700, color: AppColors.primary),
                    ),
                  ],
                ),
              ),
              _ToneTag(text: 'Good', tone: _Tone.success),
            ],
          ),
          const SizedBox(height: 16),
          const Row(
            children: [
              Expanded(child: _MetricTile(value: '8', label: 'Ready', tone: _Tone.success)),
              SizedBox(width: 8),
              Expanded(child: _MetricTile(value: '2', label: 'At Risk', tone: _Tone.warning)),
              SizedBox(width: 8),
              Expanded(child: _MetricTile(value: '1', label: 'Blocked', tone: _Tone.critical)),
            ],
          ),
          const SizedBox(height: 20),
          const Divider(height: 1),
          const SizedBox(height: 16),
          const _PreviewTask(time: '8:00 AM', title: 'Morning Medicine', state: 'Ready', tone: _Tone.success),
          const SizedBox(height: 12),
          const _PreviewTask(time: '1:00 PM', title: 'Afternoon Medicine', state: 'At Risk', tone: _Tone.warning),
          const SizedBox(height: 12),
          const _PreviewTask(time: '9:00 AM', title: 'Lab Visit — Wednesday', state: 'Blocked', tone: _Tone.critical),
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
    ('Timing clashes', 'Doses land while the patient is out of home or asleep.'),
    ('Missing help', 'Tasks need assistance at times when no caregiver is free.'),
    ('Unclear instructions', 'Handwritten notes leave families guessing about timings.'),
  ];

  @override
  Widget build(BuildContext context) => _Grid(
        desktopColumns: 3,
        children: items.map((item) => _InfoCard(title: item.$1, body: item.$2)).toList(),
      );
}

class _HowItWorksGrid extends StatelessWidget {
  const _HowItWorksGrid();
  static const items = [
    (Icons.assignment_outlined, 'Upload documents', 'Prescriptions, discharge summaries and follow-up slips.'),
    (Icons.verified_user_outlined, 'Verify extraction', 'You confirm every extracted instruction before it activates.'),
    (Icons.psychology_outlined, 'Share your routine', 'A short conversation about your day, help and transport.'),
    (Icons.route_outlined, 'See the simulation', 'A 7-day view showing ready, risky and blocked tasks.'),
  ];

  @override
  Widget build(BuildContext context) => _Grid(
        desktopColumns: 4,
        children: List.generate(items.length, (index) {
          final item = items[index];
          return _IconCard(icon: item.$1, eyebrow: 'Step ${index + 1}', title: item.$2, body: item.$3);
        }),
      );
}

class _FeatureGrid extends StatelessWidget {
  const _FeatureGrid();
  static const items = [
    (Icons.route_outlined, 'Care Simulation', 'Walk through the next seven days before they happen and see exactly where the plan is likely to break.'),
    (Icons.record_voice_over_outlined, 'Teach-Back', "Explain tomorrow's care in your own words and see what was remembered, missed or needs verification."),
    (Icons.handshake_outlined, 'Family Care', 'Assign tasks to the people who actually help, with the minimum access they need.'),
    (Icons.headphones_outlined, 'Simple Care Mode', 'One task at a time, large text and a listen button — built for elderly and low-literacy users.'),
    (Icons.language_outlined, 'Urdu & Roman Urdu', 'Switch the interface language so instructions are read the way the family speaks.'),
    (Icons.verified_user_outlined, 'Human verification', 'Nothing extracted by AI becomes part of the plan until a person confirms it.'),
  ];

  @override
  Widget build(BuildContext context) => _Grid(
        desktopColumns: 2,
        children: items.map((item) => _IconCard(icon: item.$1, title: item.$2, body: item.$3)).toList(),
      );
}

class _SafetyGrid extends StatelessWidget {
  const _SafetyGrid();
  static const items = [
    'Every extracted instruction is verified by a person before it is used.',
    'Care Readiness reflects practical feasibility, not medical risk.',
    'Unclear instructions become questions for a qualified healthcare professional.',
  ];

  @override
  Widget build(BuildContext context) => _Grid(
        desktopColumns: 3,
        children: items
            .map(
              (text) => AppCard(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.verified_user_outlined, size: 21, color: AppColors.primary),
                    const SizedBox(width: 12),
                    Expanded(child: Text(text, style: const TextStyle(fontSize: 14, color: AppColors.muted, height: 1.5))),
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
    ('Does SehatMate give medical advice?', 'No. It organizes instructions that a healthcare professional has already given, and helps you follow them at home.'),
    ('What does the Care Readiness score mean?', 'It shows how practical the care plan is against your daily routine, help and transport. It is not a medical risk score.'),
    ('Can family members use it?', 'Yes. Caregivers can be added with limited access and see only the tasks assigned to them.'),
    ('Is my document data private?', 'Documents stay linked to your care plan and can be deleted at any time from Settings.'),
    ('Which languages are supported?', 'English, Urdu and Roman Urdu, with a simplified low-literacy care mode.'),
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
                  title: Text(item.$1, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(item.$2, style: const TextStyle(fontSize: 15, color: AppColors.muted, height: 1.5)),
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
                    'Prepare the plan before the week begins.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: MediaQuery.sizeOf(context).width >= 640 ? 28 : 24, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 12),
                  ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: 580),
                    child: Text(
                      'Upload the discharge documents, share the daily routine, and see where the care plan needs help.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppColors.muted),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    alignment: WrapAlignment.center,
                    children: [
                      FilledButton(onPressed: () => onNavigate(AppRoutes.auth), child: const Text('Get Started')),
                      OutlinedButton(onPressed: () => onNavigate(AppRoutes.dashboard), child: const Text('View Demo Dashboard')),
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
                    const SizedBox(
                      width: 390,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          BrandLogo(),
                          SizedBox(height: 12),
                          Text(
                            'SehatMate helps organize and understand an existing care plan. It does not diagnose conditions or prescribe treatment.',
                            style: TextStyle(fontSize: 13, color: AppColors.muted),
                          ),
                        ],
                      ),
                    ),
                    Wrap(
                      spacing: 24,
                      runSpacing: 10,
                      children: [
                        ..._LandingScreenState.navLabels.map(
                          (label) => InkWell(
                            onTap: () => onSection(label),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              child: Text(label, style: const TextStyle(fontSize: 14, color: AppColors.muted)),
                            ),
                          ),
                        ),
                        TextButton(onPressed: () => onNavigate(AppRoutes.auth), child: const Text('Sign In')),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 32),
                const Text('© 2026 SehatMate AI. Demo product for presentation purposes.', style: TextStyle(fontSize: 13, color: AppColors.subtle)),
              ],
            ),
          ),
        ),
      );
}
