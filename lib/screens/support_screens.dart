import 'package:flutter/material.dart';

import '../core/app_routes.dart';
import '../core/app_theme.dart';
import '../data/demo_data.dart';
import '../services/auth_service.dart';
import '../widgets/app_shell.dart';
import '../widgets/page_header.dart';
import '../widgets/ui.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = CareDemoState.instance;
    return AnimatedBuilder(
      animation: state,
      builder: (context, _) => AppShell(
        currentRoute: AppRoutes.settings,
        title: 'Settings',
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const PageHeader(title: 'Settings', subtitle: 'Language, accessibility and privacy.'),
                AppCard(
                  padding: const EdgeInsets.all(24),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('Language', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 14),
                    SizedBox(width: 300, child: DropdownButtonFormField<String>(initialValue: state.language, items: const [DropdownMenuItem(value: 'English', child: Text('English')), DropdownMenuItem(value: 'Urdu', child: Text('اردو (Urdu)')), DropdownMenuItem(value: 'Roman Urdu', child: Text('Roman Urdu'))], onChanged: (value) { if (value != null) { state.updatePreferences(language: value); showDemoMessage(context, 'Language set to $value'); } })),
                  ]),
                ),
                const SizedBox(height: 18),
                AppCard(
                  padding: const EdgeInsets.all(24),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('Accessibility', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 12),
                    _toggle('Large text', 'Increase text size across the app', state.largeText, (value) => state.updatePreferences(largeText: value)),
                    _toggle('Voice guidance', 'Read instructions aloud where available', state.voiceGuidance, (value) => state.updatePreferences(voiceGuidance: value)),
                    _toggle('Simple Care Mode', 'Show one task at a time in plain language', state.simpleCareMode, (value) => state.updatePreferences(simpleCareMode: value)),
                    _toggle('Reduced motion', 'Minimise animations and transitions', state.reducedMotion, (value) => state.updatePreferences(reducedMotion: value), last: true),
                    if (state.simpleCareMode) ...[
                      const SizedBox(height: 14),
                      OutlinedButton(onPressed: () => Navigator.pushNamed(context, AppRoutes.simpleCare), child: const Text('Open Simple Care view')),
                    ],
                  ]),
                ),
                const SizedBox(height: 18),
                AppCard(
                  padding: const EdgeInsets.all(24),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('Privacy & data', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    const Text('Your documents and answers are used only to build and verify your care plan.', style: TextStyle(fontSize: 15, color: AppColors.muted)),
                    const SizedBox(height: 14),
                    Wrap(spacing: 8, runSpacing: 8, children: [OutlinedButton(onPressed: () => showDemoMessage(context, 'Data export requested'), child: const Text('Export my data')), OutlinedButton(onPressed: () => showDemoMessage(context, 'Account deletion is disabled in this demo.'), child: const Text('Delete account'))]),
                  ]),
                ),
                const SizedBox(height: 20),
                const SafetyNote(text: 'SehatMate supports understanding of an existing care plan. It does not provide medical advice or diagnosis.'),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _toggle(String label, String hint, bool value, ValueChanged<bool> onChanged, {bool last = false}) => Padding(
        padding: EdgeInsets.only(bottom: last ? 0 : 12),
        child: Row(children: [Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)), Text(hint, style: const TextStyle(fontSize: 14, color: AppColors.muted))])), const SizedBox(width: 12), Switch(value: value, onChanged: onChanged)]),
      );
}

class PatientProfileScreen extends StatefulWidget {
  const PatientProfileScreen({super.key});

  @override
  State<PatientProfileScreen> createState() => _PatientProfileScreenState();
}

class _PatientProfileScreenState extends State<PatientProfileScreen> {
  late final TextEditingController name;
  String ageGroup = '60 – 70';
  final city = TextEditingController(text: 'Karachi');
  PatientProfile? _profile;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    name = TextEditingController(
      text: AuthSession.instance.user?.name ?? 'Ali Khan',
    );
    Future<void>.microtask(_loadProfile);
  }

  @override
  void dispose() {
    name.dispose();
    city.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    if (!AuthSession.instance.isAuthenticated) return;
    try {
      final profile = await AuthSession.instance.fetchProfile();
      if (!mounted || profile == null) return;
      setState(() {
        _profile = profile;
        name.text = profile.patientName;
        ageGroup = patientAgeGroups.contains(profile.ageGroup)
            ? profile.ageGroup
            : '60 – 70';
        city.text = profile.city;
      });
      CareDemoState.instance.updatePreferences(
        language: profile.preferredLanguage,
        largeText: profile.accessibilityMode == 'Large Text',
        voiceGuidance: profile.accessibilityMode == 'Voice Guidance',
        simpleCareMode: profile.accessibilityMode == 'Simple Care Mode',
      );
    } on AuthException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message)),
      );
    }
  }

  Future<void> _saveProfile() async {
    if (name.text.trim().length < 2 || city.text.trim().length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid name and city.')),
      );
      return;
    }

    final current = _profile ?? AuthSession.instance.profile;
    final state = CareDemoState.instance;
    final accessibilityMode = state.simpleCareMode
        ? 'Simple Care Mode'
        : state.voiceGuidance
            ? 'Voice Guidance'
            : state.largeText
                ? 'Large Text'
                : 'Standard';

    setState(() => _saving = true);
    try {
      final updated = await AuthSession.instance.updateProfile(
        PatientProfile(
          usingFor: current?.usingFor ?? 'Myself',
          patientName: name.text.trim(),
          ageGroup: ageGroup,
          city: city.text.trim(),
          preferredLanguage: state.language,
          accessibilityMode: accessibilityMode,
          caregiverSupport: current?.caregiverSupport ?? false,
          onboardingCompleted: true,
        ),
      );
      if (!mounted) return;
      setState(() => _profile = updated);
      showDemoMessage(context, 'Profile updated');
    } on AuthException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message)),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile could not be updated.')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = CareDemoState.instance;
    return AnimatedBuilder(
      animation: state,
      builder: (context, _) => AppShell(
        currentRoute: AppRoutes.patientProfile,
        title: 'Patient Profile',
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                PageHeader(title: 'Patient Profile', subtitle: 'Used to check whether the care plan fits daily life.', action: OutlinedButton(onPressed: () => Navigator.pushNamed(context, AppRoutes.realityCheck), child: const Text('Update Reality Check'))),
                AppCard(
                  padding: const EdgeInsets.all(24),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('Basic details', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 14),
                    LayoutBuilder(builder: (context, constraints) {
                      final fields = [
                        fieldLabel('Full name', TextField(controller: name)),
                        fieldLabel(
                          'Age group',
                          DropdownButtonFormField<String>(
                            key: ValueKey(ageGroup),
                            initialValue: ageGroup,
                            isExpanded: true,
                            decoration: const InputDecoration(),
                            items: patientAgeGroups
                                .map(
                                  (item) => DropdownMenuItem<String>(
                                    value: item,
                                    child: Text(item),
                                  ),
                                )
                                .toList(),
                            onChanged: (value) {
                              if (value != null) {
                                setState(() => ageGroup = value);
                              }
                            },
                          ),
                        ),
                        fieldLabel('City', TextField(controller: city)),
                        fieldLabel(
                          'Preferred language',
                          InputDecorator(
                            decoration: const InputDecoration(),
                            child: Text(state.language),
                          ),
                        ),
                      ];
                      return constraints.maxWidth >= 520 ? Wrap(spacing: 16, runSpacing: 14, children: fields.map((field) => SizedBox(width: (constraints.maxWidth - 16) / 2, child: field)).toList()) : Column(children: fields.map((field) => Padding(padding: const EdgeInsets.only(bottom: 14), child: field)).toList());
                    }),
                    const SizedBox(height: 16),
                    FilledButton(onPressed: _saving ? null : _saveProfile, child: const Text('Save changes')),
                  ]),
                ),
                const SizedBox(height: 18),
                AppCard(
                  padding: const EdgeInsets.all(24),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('Daily routine & support', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 14),
                    ...realityQuestions.take(5).toList().asMap().entries.map((entry) => Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(child: Text(entry.value.question, style: const TextStyle(fontSize: 15, color: AppColors.muted))), const SizedBox(width: 12), Flexible(child: Text(entry.value.options[entry.key % entry.value.options.length], textAlign: TextAlign.right, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500)))]))),
                  ]),
                ),
                const SizedBox(height: 18),
                AppCard(
                  padding: const EdgeInsets.all(24),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('Caregiver support', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 12),
                    ...state.caregivers.map((caregiver) => Padding(padding: const EdgeInsets.only(bottom: 8), child: Row(children: [Expanded(child: Text('${caregiver.name} · ${caregiver.relationship}', style: const TextStyle(fontSize: 15))), Text(caregiver.availability, style: const TextStyle(fontSize: 15, color: AppColors.muted))]))),
                    const SizedBox(height: 8),
                    OutlinedButton(onPressed: () => Navigator.pushNamed(context, AppRoutes.family), child: const Text('Manage caregivers')),
                  ]),
                ),
                const SizedBox(height: 20),
                const SafetyNote(text: 'This profile stores practical living information only, never clinical assessments.'),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class SimpleCareScreen extends StatelessWidget {
  const SimpleCareScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = CareDemoState.instance;
    return AnimatedBuilder(
      animation: state,
      builder: (context, _) {
        final todays = state.tasks.where((task) => task.day == demoDays.first.iso).toList();
        final next = todays.where((task) => !task.completed).firstOrNull ?? todays.firstOrNull;
        final caregiver = state.caregivers.firstOrNull;
        return AppShell(
          currentRoute: AppRoutes.simpleCare,
          title: 'Simple Care',
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(28),
                    decoration: BoxDecoration(color: AppColors.primaryLight, border: Border.all(color: AppColors.primary, width: 2), borderRadius: BorderRadius.circular(AppRadii.xxxl)),
                    child: Column(children: [
                      const Text('Next thing to do', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: AppColors.accentForeground)),
                      if (next == null)
                        const Padding(padding: EdgeInsets.only(top: 12), child: Text('Nothing left for today', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700)))
                      else ...[
                        const SizedBox(height: 12),
                        Text(next.title, textAlign: TextAlign.center, style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w700, height: 1.15)),
                        const SizedBox(height: 8),
                        Text(next.time, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w600, color: AppColors.muted)),
                        const SizedBox(height: 8),
                        Text(next.note, textAlign: TextAlign.center, style: const TextStyle(fontSize: 18, color: AppColors.muted)),
                        const SizedBox(height: 20),
                        SizedBox(width: double.infinity, height: 56, child: FilledButton.icon(onPressed: () { state.toggleTask(next.id); showDemoMessage(context, 'Marked as done'); }, icon: const Icon(Icons.check, size: 25), label: Text(next.completed ? 'Done' : 'Mark as done', style: const TextStyle(fontSize: 19)))),
                      ],
                    ]),
                  ),
                  const SizedBox(height: 24),
                  const Text('Rest of today', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 12),
                  ...todays.map((task) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: AnimatedOpacity(
                          opacity: task.completed ? .6 : 1,
                          duration: const Duration(milliseconds: 180),
                          child: AppCard(
                            padding: const EdgeInsets.all(18),
                            child: Row(children: [TaskIcon(icon: task.icon, size: 46), const SizedBox(width: 14), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(task.title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600)), Text(task.time, style: const TextStyle(fontSize: 18, color: AppColors.muted))])), OutlinedButton(onPressed: () => state.toggleTask(task.id), child: const Icon(Icons.check, size: 24))]),
                          ),
                        ),
                      )),
                  const SizedBox(height: 12),
                  AppCard(
                    padding: const EdgeInsets.all(24),
                    child: Column(children: [const Text('Need help?', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600)), const SizedBox(height: 4), Text('${caregiver?.name ?? ''} · ${caregiver?.phone ?? ''}', style: const TextStyle(fontSize: 17, color: AppColors.muted)), const SizedBox(height: 14), SizedBox(width: double.infinity, height: 54, child: OutlinedButton.icon(onPressed: () => Navigator.pushNamed(context, AppRoutes.family), icon: const Icon(Icons.phone_outlined, size: 25), label: const Text('Contact family', style: TextStyle(fontSize: 19))))]),
                  ),
                  const SizedBox(height: 20),
                  const SafetyNote(text: 'For any medical emergency, contact a healthcare professional immediately.'),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class TeachBackScreen extends StatefulWidget {
  const TeachBackScreen({super.key});

  @override
  State<TeachBackScreen> createState() => _TeachBackScreenState();
}

class _TeachBackScreenState extends State<TeachBackScreen> {
  static const prompts = [
    ('tb1', 'When will you take your morning medicine?', 'Every morning at 8:00 AM, after breakfast.'),
    ('tb2', 'What will you do before your hospital visit?', 'Fast overnight and arrive by 10:00 AM with a confirmed ride.'),
    ('tb3', 'Who helps you with dressing changes?', 'Ahmed helps with the dressing in the evening.'),
  ];
  final answers = <String, String>{};
  final controller = TextEditingController();
  int index = 0;
  bool done = false;

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  int get score => (70 + answers.values.where((answer) => answer.trim().length > 12).length * 10).clamp(0, 100).toInt();

  @override
  Widget build(BuildContext context) {
    final state = CareDemoState.instance;
    if (done) {
      return AppShell(
        currentRoute: AppRoutes.teachBack,
        title: 'Teach-Back',
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: FadeSlideIn(
              child: AppCard(
                padding: const EdgeInsets.all(30),
                child: Column(children: [const Icon(Icons.check_circle_outline, size: 50, color: AppColors.success), const SizedBox(height: 14), const Text('Understanding recorded', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700)), const SizedBox(height: 6), Text('Understanding score: $score% — clear on medicines, review the visit preparation once more.', textAlign: TextAlign.center, style: const TextStyle(fontSize: 15, color: AppColors.muted)), const SizedBox(height: 18), LinearProgressIndicator(value: score / 100, minHeight: 10, borderRadius: BorderRadius.circular(99)), const SizedBox(height: 22), FilledButton.icon(onPressed: () => setState(() { index = 0; answers.clear(); controller.clear(); done = false; }), icon: const Icon(Icons.refresh, size: 18), label: const Text('Try again'))]),
              ),
            ),
          ),
        ),
      );
    }
    final prompt = prompts[index];
    return AppShell(
      currentRoute: AppRoutes.teachBack,
      title: 'Teach-Back',
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 620),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              PageHeader(title: 'Explain the plan in your own words', subtitle: 'Current understanding score: ${state.understanding}%'),
              LinearProgressIndicator(value: (index + 1) / prompts.length, minHeight: 8, borderRadius: BorderRadius.circular(99)),
              const SizedBox(height: 20),
              FadeSlideIn(
                key: ValueKey(prompt.$1),
                child: AppCard(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('QUESTION ${index + 1} OF ${prompts.length}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.muted, letterSpacing: .5)),
                      const SizedBox(height: 8),
                      Text(prompt.$2, style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 14),
                      TextField(controller: controller, minLines: 4, maxLines: 5, onChanged: (value) => setState(() => answers[prompt.$1] = value), decoration: const InputDecoration(hintText: 'Type your answer, or speak it aloud')),
                      const SizedBox(height: 10),
                      OutlinedButton.icon(onPressed: () => showDemoMessage(context, 'Voice capture is not connected in this demo.'), icon: const Icon(Icons.mic_none, size: 18), label: const Text('Speak answer')),
                      if (controller.text.trim().isNotEmpty) ...[
                        const SizedBox(height: 14),
                        Container(width: double.infinity, padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: AppColors.primaryLight, borderRadius: BorderRadius.circular(AppRadii.xl)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('What the plan says', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.accentForeground)), Text(prompt.$3, style: const TextStyle(fontSize: 14, color: AppColors.muted))])),
                      ],
                      const SizedBox(height: 18),
                      Align(
                        alignment: Alignment.centerRight,
                        child: FilledButton(
                          onPressed: controller.text.trim().isEmpty ? null : () {
                            answers[prompt.$1] = controller.text.trim();
                            if (index + 1 == prompts.length) {
                              state.setUnderstanding(score);
                              setState(() => done = true);
                            } else {
                              setState(() { index += 1; controller.text = answers[prompts[index].$1] ?? ''; });
                            }
                          },
                          child: Text(index + 1 == prompts.length ? 'Finish' : 'Next'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 18),
              const SafetyNote(text: 'This check measures understanding of the care plan only. It is not a medical assessment.'),
            ],
          ),
        ),
      ),
    );
  }
}
