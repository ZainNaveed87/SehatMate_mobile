import 'package:flutter/material.dart';

import '../core/app_routes.dart';
import '../core/app_theme.dart';
import '../data/demo_data.dart';
import '../localization/app_language.dart';
import '../localization/language_scope.dart';
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
        title: context.tr('settings'),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                PageHeader(title: context.tr('settings'), subtitle: context.tr('settings_subtitle')),
                AppCard(
                  padding: const EdgeInsets.all(24),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(context.tr('language'), style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 14),
                    SizedBox(
                      width: 300,
                      child: DropdownButtonFormField<AppLanguage>(
                        initialValue: context.appLanguage,
                        items: AppLanguage.values
                            .map(
                              (language) => DropdownMenuItem(
                                value: language,
                                child: Text(language.displayName),
                              ),
                            )
                            .toList(),
                        onChanged: (value) async {
                          if (value == null) return;
                          await LanguageScope.read(context).setLanguage(value);
                          state.updatePreferences(language: value.displayName);
                          if (!context.mounted) return;
                          showDemoMessage(context, context.tr('language_changed'));
                        },
                      ),
                    ),
                  ]),
                ),
                const SizedBox(height: 18),
                AppCard(
                  padding: const EdgeInsets.all(24),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(context.tr('accessibility'), style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 12),
                    _toggle(context.tr('large_text'), context.tr('settings_large_text_hint'), state.largeText, (value) => state.updatePreferences(largeText: value)),
                    _toggle(context.tr('voice_guidance'), context.tr('settings_voice_guidance_hint'), state.voiceGuidance, (value) => state.updatePreferences(voiceGuidance: value)),
                    _toggle(context.tr('simple_care_mode'), context.tr('settings_simple_care_hint'), state.simpleCareMode, (value) => state.updatePreferences(simpleCareMode: value)),
                    _toggle(context.tr('reduced_motion'), context.tr('settings_reduced_motion_hint'), state.reducedMotion, (value) => state.updatePreferences(reducedMotion: value), last: true),
                    if (state.simpleCareMode) ...[
                      const SizedBox(height: 14),
                      OutlinedButton(onPressed: () => Navigator.pushNamed(context, AppRoutes.simpleCare), child: Text(context.tr('open_simple_care_view'))),
                    ],
                  ]),
                ),
                const SizedBox(height: 18),
                AppCard(
                  padding: const EdgeInsets.all(24),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(context.tr('privacy_and_data'), style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    Text(context.tr('privacy_data_description'), style: const TextStyle(fontSize: 15, color: AppColors.muted)),
                    const SizedBox(height: 14),
                    Wrap(spacing: 8, runSpacing: 8, children: [
                      OutlinedButton(onPressed: () => showDemoMessage(context, context.tr('data_export_requested')), child: Text(context.tr('export_my_data'))),
                      OutlinedButton(onPressed: () => showDemoMessage(context, context.tr('account_deletion_demo_disabled')), child: Text(context.tr('delete_account'))),
                    ]),
                  ]),
                ),
                const SizedBox(height: 20),
                SafetyNote(text: context.tr('settings_safety_note')),
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
        SnackBar(content: Text(context.tr('enter_valid_name_and_city'))),
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
      showDemoMessage(context, context.tr('profile_updated'));
    } on AuthException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message)),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr('profile_update_failed'))),
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
        title: context.tr('patient_profile'),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                PageHeader(title: context.tr('patient_profile'), subtitle: context.tr('patient_profile_subtitle'), action: OutlinedButton(onPressed: () => Navigator.pushNamed(context, AppRoutes.realityCheck), child: Text(context.tr('update_reality_check')))),
                AppCard(
                  padding: const EdgeInsets.all(24),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(context.tr('basic_details'), style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 14),
                    LayoutBuilder(builder: (context, constraints) {
                      final fields = [
                        fieldLabel(context.tr('full_name'), TextField(controller: name)),
                        fieldLabel(
                          context.tr('age_group'),
                          DropdownButtonFormField<String>(
                            key: ValueKey(ageGroup),
                            initialValue: ageGroup,
                            isExpanded: true,
                            decoration: const InputDecoration(),
                            items: patientAgeGroups
                                .map(
                                  (item) => DropdownMenuItem<String>(
                                    value: item,
                                    child: Text(ageGroupLabel(item, context.appLanguage)),
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
                        fieldLabel(context.tr('city'), TextField(controller: city)),
                        fieldLabel(
                          context.tr('preferred_language'),
                          InputDecorator(
                            decoration: const InputDecoration(),
                            child: Text(demoLanguageLabel(state.language)),
                          ),
                        ),
                      ];
                      return constraints.maxWidth >= 520 ? Wrap(spacing: 16, runSpacing: 14, children: fields.map((field) => SizedBox(width: (constraints.maxWidth - 16) / 2, child: field)).toList()) : Column(children: fields.map((field) => Padding(padding: const EdgeInsets.only(bottom: 14), child: field)).toList());
                    }),
                    const SizedBox(height: 16),
                    FilledButton(onPressed: _saving ? null : _saveProfile, child: Text(context.tr('save_changes'))),
                  ]),
                ),
                const SizedBox(height: 18),
                AppCard(
                  padding: const EdgeInsets.all(24),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(context.tr('daily_routine_and_support'), style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 14),
                    ...realityQuestions.take(5).toList().asMap().entries.map((entry) => Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(child: Text(demoRealityQuestionText(entry.value, context.appLanguage), style: const TextStyle(fontSize: 15, color: AppColors.muted))), const SizedBox(width: 12), Flexible(child: Text(demoRealityOptionText(entry.value.options[entry.key % entry.value.options.length], context.appLanguage), textAlign: TextAlign.right, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500)))]))),
                  ]),
                ),
                const SizedBox(height: 18),
                AppCard(
                  padding: const EdgeInsets.all(24),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(context.tr('caregiver_support'), style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 12),
                    ...state.caregivers.map((caregiver) => Padding(padding: const EdgeInsets.only(bottom: 8), child: Row(children: [Expanded(child: Text('${caregiver.name} · ${caregiver.relationship}', style: const TextStyle(fontSize: 15))), Text(caregiver.availability, style: const TextStyle(fontSize: 15, color: AppColors.muted))]))),
                    const SizedBox(height: 8),
                    OutlinedButton(onPressed: () => Navigator.pushNamed(context, AppRoutes.family), child: Text(context.tr('manage_caregivers'))),
                  ]),
                ),
                const SizedBox(height: 20),
                SafetyNote(text: context.tr('patient_profile_safety_note')),
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
          title: context.tr('simple_care'),
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
                      Text(context.tr('next_thing_to_do'), style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: AppColors.accentForeground)),
                      if (next == null)
                        Padding(padding: const EdgeInsets.only(top: 12), child: Text(context.tr('nothing_left_today'), style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700)))
                      else ...[
                        const SizedBox(height: 12),
                        Text(demoTaskTitle(next, context.appLanguage), textAlign: TextAlign.center, style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w700, height: 1.15)),
                        const SizedBox(height: 8),
                        Text(next.time, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w600, color: AppColors.muted)),
                        const SizedBox(height: 8),
                        Text(demoTaskNote(next, context.appLanguage), textAlign: TextAlign.center, style: const TextStyle(fontSize: 18, color: AppColors.muted)),
                        const SizedBox(height: 20),
                        SizedBox(width: double.infinity, height: 56, child: FilledButton.icon(onPressed: () { state.toggleTask(next.id); showDemoMessage(context, context.tr('marked_as_done')); }, icon: const Icon(Icons.check, size: 25), label: Text(next.completed ? context.tr('done') : context.tr('mark_as_done'), style: const TextStyle(fontSize: 19)))),
                      ],
                    ]),
                  ),
                  const SizedBox(height: 24),
                  Text(context.tr('rest_of_today'), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 12),
                  ...todays.map((task) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: AnimatedOpacity(
                          opacity: task.completed ? .6 : 1,
                          duration: const Duration(milliseconds: 180),
                          child: AppCard(
                            padding: const EdgeInsets.all(18),
                            child: Row(children: [TaskIcon(icon: task.icon, size: 46), const SizedBox(width: 14), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(demoTaskTitle(task, context.appLanguage), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600)), Text(task.time, style: const TextStyle(fontSize: 18, color: AppColors.muted))])), OutlinedButton(onPressed: () => state.toggleTask(task.id), child: const Icon(Icons.check, size: 24))]),
                          ),
                        ),
                      )),
                  const SizedBox(height: 12),
                  AppCard(
                    padding: const EdgeInsets.all(24),
                    child: Column(children: [Text(context.tr('need_help'), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600)), const SizedBox(height: 4), Text('${caregiver?.name ?? ''} · ${caregiver?.phone ?? ''}', style: const TextStyle(fontSize: 17, color: AppColors.muted)), const SizedBox(height: 14), SizedBox(width: double.infinity, height: 54, child: OutlinedButton.icon(onPressed: () => Navigator.pushNamed(context, AppRoutes.family), icon: const Icon(Icons.phone_outlined, size: 25), label: Text(context.tr('contact_family'), style: const TextStyle(fontSize: 19))))]),
                  ),
                  const SizedBox(height: 20),
                  SafetyNote(text: context.tr('medical_emergency_contact_professional')),
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
    ('tb1', 'teach_back_prompt_morning_medicine', 'teach_back_plan_morning_medicine'),
    ('tb2', 'teach_back_prompt_hospital_visit', 'teach_back_plan_hospital_visit'),
    ('tb3', 'teach_back_prompt_dressing_help', 'teach_back_plan_dressing_help'),
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
        title: context.tr('teach_back'),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: FadeSlideIn(
              child: AppCard(
                padding: const EdgeInsets.all(30),
                child: Column(children: [
                  const Icon(Icons.check_circle_outline, size: 50, color: AppColors.success),
                  const SizedBox(height: 14),
                  Text(context.tr('understanding_recorded'), style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 6),
                  Text(context.tr('understanding_score_summary', values: {'score': score}), textAlign: TextAlign.center, style: const TextStyle(fontSize: 15, color: AppColors.muted)),
                  const SizedBox(height: 18),
                  LinearProgressIndicator(value: score / 100, minHeight: 10, borderRadius: BorderRadius.circular(99)),
                  const SizedBox(height: 22),
                  FilledButton.icon(onPressed: () => setState(() { index = 0; answers.clear(); controller.clear(); done = false; }), icon: const Icon(Icons.refresh, size: 18), label: Text(context.tr('retry'))),
                ]),
              ),
            ),
          ),
        ),
      );
    }
    final prompt = prompts[index];
    return AppShell(
      currentRoute: AppRoutes.teachBack,
      title: context.tr('teach_back'),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 620),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              PageHeader(
                title: context.tr('teach_back_title'),
                subtitle: context.tr('current_understanding_score', values: {'score': state.understanding}),
              ),
              LinearProgressIndicator(value: (index + 1) / prompts.length, minHeight: 8, borderRadius: BorderRadius.circular(99)),
              const SizedBox(height: 20),
              FadeSlideIn(
                key: ValueKey(prompt.$1),
                child: AppCard(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(context.tr('question_counter_caps', values: {'current': index + 1, 'total': prompts.length}), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.muted, letterSpacing: .5)),
                      const SizedBox(height: 8),
                      Text(context.tr(prompt.$2), style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 14),
                      TextField(controller: controller, minLines: 4, maxLines: 5, onChanged: (value) => setState(() => answers[prompt.$1] = value), decoration: InputDecoration(hintText: context.tr('type_or_speak_answer'))),
                      const SizedBox(height: 10),
                      OutlinedButton.icon(onPressed: () => showDemoMessage(context, context.tr('voice_capture_demo_unavailable')), icon: const Icon(Icons.mic_none, size: 18), label: Text(context.tr('speak_answer'))),
                      if (controller.text.trim().isNotEmpty) ...[
                        const SizedBox(height: 14),
                        Container(width: double.infinity, padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: AppColors.primaryLight, borderRadius: BorderRadius.circular(AppRadii.xl)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(context.tr('what_plan_says'), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.accentForeground)), Text(context.tr(prompt.$3), style: const TextStyle(fontSize: 14, color: AppColors.muted))])),
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
                          child: Text(index + 1 == prompts.length ? context.tr('finish') : context.tr('next_label')),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 18),
              SafetyNote(text: context.tr('teach_back_safety_note')),
            ],
          ),
        ),
      ),
    );
  }
}
