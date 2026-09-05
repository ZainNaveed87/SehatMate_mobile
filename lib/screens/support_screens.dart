import 'package:flutter/material.dart';

import '../core/app_routes.dart';
import '../core/app_theme.dart';
import '../data/demo_data.dart';
import '../localization/app_language.dart';
import '../localization/language_scope.dart';
import '../services/auth_service.dart';
import '../services/device_speech_service.dart';
import '../services/teach_back_service.dart';
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
  const TeachBackScreen({super.key, this.service, this.speechInput});

  final TeachBackClient? service;
  final DeviceSpeechInput? speechInput;

  @override
  State<TeachBackScreen> createState() => _TeachBackScreenState();
}

class _TeachBackScreenState extends State<TeachBackScreen> {
  late final TeachBackClient _service;
  late final DeviceSpeechInput _speechInput;

  final controller = TextEditingController();
  final answers = <String, String>{};
  final assessments = <String, TeachBackAssessment>{};

  List<TeachBackTarget> targets = const [];
  TeachBackTarget? selectedTarget;
  TeachBackSession? session;
  TeachBackFinalResult? finalResult;

  int index = 0;
  bool loading = true;
  bool loadingSession = false;
  bool submitting = false;
  bool listening = false;
  bool showFinal = false;
  String errorMessage = '';
  String speechMessage = '';

  @override
  void initState() {
    super.initState();
    _service = widget.service ?? TeachBackService.instance;
    _speechInput = widget.speechInput ?? DeviceSpeechService.instance;
    Future<void>.microtask(_loadTargets);
  }

  @override
  void dispose() {
    controller.dispose();
    _speechInput.stopListening();
    super.dispose();
  }

  TeachBackQuestion? get currentQuestion {
    final questions = session?.questions ?? const <TeachBackQuestion>[];
    if (questions.isEmpty || index < 0 || index >= questions.length) {
      return null;
    }
    return questions[index];
  }

  TeachBackAssessment? get currentAssessment {
    final question = currentQuestion;
    if (question == null) return null;
    return assessments[question.id];
  }

  void _answerChanged(String value) {
    final question = currentQuestion;
    if (question == null) return;
    answers[question.id] = value;
    if (mounted) setState(() {});
  }

  Future<void> _loadTargets() async {
    if (widget.service == null && !AuthSession.instance.isAuthenticated) {
      setState(() {
        loading = false;
        errorMessage = context.tr('teach_back_sign_in_required');
      });
      return;
    }

    setState(() {
      loading = true;
      errorMessage = '';
      speechMessage = '';
      showFinal = false;
    });

    try {
      final loadedTargets = await _service.fetchTargets();
      if (!mounted) return;
      if (loadedTargets.isEmpty) {
        setState(() {
          targets = const [];
          selectedTarget = null;
          session = null;
          loading = false;
        });
        return;
      }
      targets = loadedTargets;
      selectedTarget = loadedTargets.first;
      await _loadSession(loadedTargets.first, showLoading: false);
    } on TeachBackException catch (error) {
      if (!mounted) return;
      setState(() {
        loading = false;
        errorMessage = error.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        loading = false;
        errorMessage = context.tr('teach_back_load_failed');
      });
    }
  }

  Future<void> _loadSession(
    TeachBackTarget target, {
    bool showLoading = true,
  }) async {
    if (showLoading) {
      setState(() {
        loadingSession = true;
        errorMessage = '';
        speechMessage = '';
      });
    }

    try {
      final loadedSession = await _service.fetchSession(
        targetType: target.targetType,
        targetId: target.targetId,
      );
      if (!mounted) return;

      final loadedAssessments = loadedSession.assessmentsByQuestionId;
      final firstOpen = loadedSession.questions.indexWhere(
        (question) => !loadedAssessments.containsKey(question.id),
      );
      final nextIndex = firstOpen >= 0 ? firstOpen : 0;

      answers
        ..clear()
        ..addEntries(
          loadedAssessments.values.map(
            (assessment) =>
                MapEntry(assessment.questionId, assessment.answerText),
          ),
        );
      assessments
        ..clear()
        ..addAll(loadedAssessments);

      setState(() {
        selectedTarget = target;
        session = loadedSession;
        finalResult = loadedSession.finalResult;
        index = nextIndex;
        showFinal = loadedSession.finalResult.completed;
        loading = false;
        loadingSession = false;
        controller.text = loadedSession.questions.isEmpty
            ? ''
            : answers[loadedSession.questions[nextIndex].id] ?? '';
      });

      _syncDemoUnderstanding(loadedSession.finalResult);
    } on TeachBackException catch (error) {
      if (!mounted) return;
      setState(() {
        loading = false;
        loadingSession = false;
        errorMessage = error.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        loading = false;
        loadingSession = false;
        errorMessage = context.tr('teach_back_load_failed');
      });
    }
  }

  Future<void> _submitAnswer() async {
    final target = selectedTarget;
    final question = currentQuestion;
    final answer = (question == null ? '' : answers[question.id] ?? '').trim();
    if (target == null || question == null || answer.isEmpty || submitting) {
      return;
    }

    setState(() {
      submitting = true;
      errorMessage = '';
      speechMessage = '';
    });

    try {
      final response = await _service.assessAnswer(
        targetType: target.targetType,
        targetId: target.targetId,
        questionId: question.id,
        answer: answer,
      );
      if (!mounted) return;
      setState(() {
        answers[question.id] = answer;
        assessments[question.id] = response.assessment;
        finalResult = response.finalResult;
        submitting = false;
        showFinal = response.finalResult.completed;
      });
      _syncDemoUnderstanding(response.finalResult);
    } on TeachBackException catch (error) {
      if (!mounted) return;
      setState(() {
        submitting = false;
        errorMessage = error.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        submitting = false;
        errorMessage = context.tr('teach_back_backend_error');
      });
    }
  }

  Future<void> _toggleSpeech() async {
    final question = currentQuestion;
    if (question == null) return;

    if (listening) {
      await _speechInput.stopListening();
      if (mounted) setState(() => listening = false);
      return;
    }

    setState(() {
      speechMessage = '';
      listening = true;
    });

    final result = await _speechInput.startListening(
      localeId: context.appLanguage.speechRecognitionLocale,
      onTranscript: (transcript) {
        if (!mounted) return;
        controller
          ..text = transcript
          ..selection = TextSelection.collapsed(offset: transcript.length);
        answers[question.id] = transcript;
        setState(() {});
      },
      onDone: () {
        if (mounted) setState(() => listening = false);
      },
    );

    if (!mounted) return;
    if (!result.started) {
      setState(() {
        listening = false;
        speechMessage = result.message.isEmpty
            ? context.tr('teach_back_mic_unavailable')
            : result.message;
      });
    }
  }

  void _goToQuestion(int nextIndex) {
    final questions = session?.questions ?? const <TeachBackQuestion>[];
    if (nextIndex < 0 || nextIndex >= questions.length) return;
    setState(() {
      index = nextIndex;
      showFinal = false;
      speechMessage = '';
      controller.text = answers[questions[nextIndex].id] ?? '';
    });
  }

  void _nextQuestion() {
    final questions = session?.questions ?? const <TeachBackQuestion>[];
    final nextOpen = questions.indexWhere(
      (question) =>
          questions.indexOf(question) > index &&
          !assessments.containsKey(question.id),
    );
    if (nextOpen >= 0) {
      _goToQuestion(nextOpen);
      return;
    }
    if (index + 1 < questions.length) {
      _goToQuestion(index + 1);
      return;
    }
    setState(() => showFinal = true);
  }

  void _retryCurrent() {
    final question = currentQuestion;
    if (question == null) return;
    setState(() {
      assessments.remove(question.id);
      showFinal = false;
      speechMessage = '';
      controller.text = answers[question.id] ?? '';
    });
  }

  void _retryWeakQuestions() {
    final questions = session?.questions ?? const <TeachBackQuestion>[];
    final weakIds = finalResult?.weakQuestionIds ?? const <String>[];
    final firstWeak = questions.indexWhere(
      (question) => weakIds.contains(question.id),
    );
    if (firstWeak < 0) {
      _goToQuestion(0);
      return;
    }
    setState(() {
      for (final id in weakIds) {
        assessments.remove(id);
      }
      index = firstWeak;
      showFinal = false;
      speechMessage = '';
      controller.text = answers[questions[firstWeak].id] ?? '';
    });
  }

  void _syncDemoUnderstanding(TeachBackFinalResult result) {
    if (result.completed) {
      CareDemoState.instance.setUnderstanding(result.score);
    }
  }

  String _statusLabel(String status) => switch (status) {
    'understood' => context.tr('teach_back_status_understood'),
    'partial' => context.tr('teach_back_status_partial'),
    'needs_review' => context.tr('teach_back_status_needs_review'),
    'mostly_understood' => context.tr('teach_back_status_mostly'),
    'in_progress' => context.tr('teach_back_status_in_progress'),
    _ => context.tr('teach_back_status_cannot_assess'),
  };

  Color _statusColor(String status) => switch (status) {
    'understood' => AppColors.success,
    'mostly_understood' || 'partial' => AppColors.warning,
    'needs_review' => AppColors.critical,
    _ => AppColors.muted,
  };

  @override
  Widget build(BuildContext context) {
    final title = context.tr('teach_back');
    return AppShell(
      currentRoute: AppRoutes.teachBack,
      title: title,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 680),
          child: AnimatedBuilder(
            animation: CareDemoState.instance,
            builder: (context, _) {
              if (loading) return _LoadingState(text: context.tr('loading'));
              if (errorMessage.isNotEmpty) {
                return _MessageState(
                  icon: Icons.lock_outline,
                  title: context.tr('teach_back_unavailable'),
                  message: errorMessage,
                  action: OutlinedButton.icon(
                    onPressed: _loadTargets,
                    icon: const Icon(Icons.refresh, size: 18),
                    label: Text(context.tr('retry')),
                  ),
                );
              }
              if (targets.isEmpty) {
                return _MessageState(
                  icon: Icons.fact_check_outlined,
                  title: context.tr('teach_back_empty'),
                  message: context.tr('teach_back_empty_detail'),
                  action: OutlinedButton.icon(
                    onPressed: () => Navigator.pushReplacementNamed(
                      context,
                      AppRoutes.carePlans,
                    ),
                    icon: const Icon(Icons.checklist_outlined, size: 18),
                    label: Text(context.tr('care_plans')),
                  ),
                );
              }
              if (showFinal && finalResult != null) {
                return _FinalResultCard(
                  result: finalResult!,
                  statusLabel: _statusLabel(finalResult!.status),
                  statusColor: _statusColor(finalResult!.status),
                  onRetryWeak: _retryWeakQuestions,
                  onDashboard: () => Navigator.pushReplacementNamed(
                    context,
                    AppRoutes.dashboard,
                  ),
                  onCarePlan: selectedTarget?.carePlanId.isEmpty ?? true
                      ? null
                      : () => Navigator.pushReplacementNamed(
                          context,
                          AppRoutes.carePlan(selectedTarget!.carePlanId),
                        ),
                );
              }
              return _SessionBody(
                targets: targets,
                selectedTarget: selectedTarget,
                session: session,
                currentQuestion: currentQuestion,
                currentAssessment: currentAssessment,
                canSubmit:
                    currentQuestion != null &&
                    (answers[currentQuestion!.id] ?? '').trim().isNotEmpty &&
                    !submitting,
                controller: controller,
                index: index,
                loadingSession: loadingSession,
                submitting: submitting,
                listening: listening,
                speechMessage: speechMessage,
                onTargetChanged: (targetKey) {
                  final target = targets
                      .where((item) => item.key == targetKey)
                      .firstOrNull;
                  if (target != null) _loadSession(target);
                },
                onSubmit: _submitAnswer,
                onToggleSpeech: _toggleSpeech,
                onAnswerChanged: _answerChanged,
                onRetry: _retryCurrent,
                onNext: _nextQuestion,
                statusLabel: currentAssessment == null
                    ? ''
                    : _statusLabel(currentAssessment!.status),
                statusColor: currentAssessment == null
                    ? AppColors.muted
                    : _statusColor(currentAssessment!.status),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _LoadingState extends StatelessWidget {
  const _LoadingState({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(28),
      child: Row(
        children: [
          const SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(width: 14),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}

class _MessageState extends StatelessWidget {
  const _MessageState({
    required this.icon,
    required this.title,
    required this.message,
    this.action,
  });

  final IconData icon;
  final String title;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 34, color: AppColors.primary),
          const SizedBox(height: 14),
          Text(
            title,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(message, style: const TextStyle(color: AppColors.muted)),
          if (action != null) ...[const SizedBox(height: 18), action!],
        ],
      ),
    );
  }
}

class _SessionBody extends StatelessWidget {
  const _SessionBody({
    required this.targets,
    required this.selectedTarget,
    required this.session,
    required this.currentQuestion,
    required this.currentAssessment,
    required this.canSubmit,
    required this.controller,
    required this.index,
    required this.loadingSession,
    required this.submitting,
    required this.listening,
    required this.speechMessage,
    required this.onTargetChanged,
    required this.onSubmit,
    required this.onToggleSpeech,
    required this.onAnswerChanged,
    required this.onRetry,
    required this.onNext,
    required this.statusLabel,
    required this.statusColor,
  });

  final List<TeachBackTarget> targets;
  final TeachBackTarget? selectedTarget;
  final TeachBackSession? session;
  final TeachBackQuestion? currentQuestion;
  final TeachBackAssessment? currentAssessment;
  final bool canSubmit;
  final TextEditingController controller;
  final int index;
  final bool loadingSession;
  final bool submitting;
  final bool listening;
  final String speechMessage;
  final ValueChanged<String?> onTargetChanged;
  final VoidCallback onSubmit;
  final VoidCallback onToggleSpeech;
  final ValueChanged<String> onAnswerChanged;
  final VoidCallback onRetry;
  final VoidCallback onNext;
  final String statusLabel;
  final Color statusColor;

  @override
  Widget build(BuildContext context) {
    final questions = session?.questions ?? const <TeachBackQuestion>[];
    final question = currentQuestion;
    final assessment = currentAssessment;
    final progress = questions.isEmpty ? 0.0 : (index + 1) / questions.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        PageHeader(
          title: context.tr('teach_back_title'),
          subtitle: context.tr('teach_back_subtitle'),
        ),
        if (targets.length > 1) ...[
          fieldLabel(
            context.tr('teach_back_target_label'),
            DropdownButtonFormField<String>(
              key: const Key('teach_back_target_dropdown'),
              initialValue: selectedTarget?.key,
              isExpanded: true,
              items: targets
                  .map(
                    (target) => DropdownMenuItem<String>(
                      value: target.key,
                      child: Text(
                        target.title,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  )
                  .toList(),
              onChanged: loadingSession || submitting ? null : onTargetChanged,
            ),
          ),
          const SizedBox(height: 18),
        ],
        if (loadingSession)
          _LoadingState(text: context.tr('loading'))
        else if (session == null || !session!.canAssess || question == null)
          _MessageState(
            icon: Icons.info_outline,
            title: context.tr('teach_back_no_assess'),
            message: context.tr('teach_back_empty_detail'),
          )
        else ...[
          LinearProgressIndicator(
            value: progress,
            minHeight: 8,
            borderRadius: BorderRadius.circular(99),
          ),
          const SizedBox(height: 20),
          FadeSlideIn(
            key: ValueKey('${selectedTarget?.key}:${question.id}:$index'),
            child: AppCard(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.tr(
                      'teach_back_question_count',
                      values: {'current': index + 1, 'total': questions.length},
                    ),
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.muted,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    question.text,
                    style: const TextStyle(
                      fontSize: 21,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    key: const Key('teach_back_answer_field'),
                    controller: controller,
                    minLines: 4,
                    maxLines: 5,
                    enabled: !submitting,
                    onChanged: onAnswerChanged,
                    decoration: InputDecoration(
                      hintText: context.tr('teach_back_answer_hint'),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      OutlinedButton.icon(
                        key: const Key('teach_back_speak_button'),
                        onPressed: submitting ? null : onToggleSpeech,
                        icon: Icon(
                          listening
                              ? Icons.stop_circle_outlined
                              : Icons.mic_none,
                          size: 18,
                        ),
                        label: Text(
                          listening
                              ? context.tr('teach_back_stop_listening')
                              : context.tr('teach_back_speak_answer'),
                        ),
                      ),
                      FilledButton.icon(
                        key: const Key('teach_back_submit_button'),
                        onPressed: canSubmit ? onSubmit : null,
                        icon: submitting
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.check_circle_outline, size: 18),
                        label: Text(
                          submitting
                              ? context.tr('teach_back_checking')
                              : context.tr('teach_back_check_answer'),
                        ),
                      ),
                    ],
                  ),
                  if (speechMessage.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Text(
                      speechMessage,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.warningForeground,
                      ),
                    ),
                  ],
                  if (assessment != null) ...[
                    const SizedBox(height: 18),
                    _AssessmentPanel(
                      assessment: assessment,
                      statusLabel: statusLabel,
                      statusColor: statusColor,
                      onRetry: onRetry,
                      onNext: onNext,
                      isLast: index + 1 >= questions.length,
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 18),
          SafetyNote(text: context.tr('teach_back_safety_note')),
        ],
      ],
    );
  }
}

class _AssessmentPanel extends StatelessWidget {
  const _AssessmentPanel({
    required this.assessment,
    required this.statusLabel,
    required this.statusColor,
    required this.onRetry,
    required this.onNext,
    required this.isLast,
  });

  final TeachBackAssessment assessment;
  final String statusLabel;
  final Color statusColor;
  final VoidCallback onRetry;
  final VoidCallback onNext;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.secondary,
        borderRadius: BorderRadius.circular(AppRadii.lg),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.verified_outlined, size: 18, color: statusColor),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  statusLabel,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: statusColor,
                  ),
                ),
              ),
              Text(
                '${assessment.score}%',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: statusColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(assessment.feedback),
          if (assessment.matchedPoints.isNotEmpty) ...[
            const SizedBox(height: 14),
            _PointList(
              title: context.tr('teach_back_what_understood'),
              points: assessment.matchedPoints,
              icon: Icons.check_circle_outline,
              color: AppColors.success,
            ),
          ],
          if (assessment.missingPoints.isNotEmpty) ...[
            const SizedBox(height: 14),
            _PointList(
              title: context.tr('teach_back_missing'),
              points: assessment.missingPoints,
              icon: Icons.info_outline,
              color: AppColors.warning,
            ),
          ],
          if (assessment.planStatement.isNotEmpty) ...[
            const SizedBox(height: 14),
            Text(
              context.tr('teach_back_plan_says'),
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              assessment.planStatement,
              style: const TextStyle(color: AppColors.muted),
            ),
          ],
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (assessment.needsRetry)
                OutlinedButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh, size: 18),
                  label: Text(context.tr('teach_back_retry_answer')),
                ),
              FilledButton.icon(
                onPressed: onNext,
                icon: Icon(
                  isLast ? Icons.flag_outlined : Icons.arrow_forward,
                  size: 18,
                ),
                label: Text(
                  isLast
                      ? context.tr('teach_back_finish')
                      : context.tr('teach_back_next_question'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PointList extends StatelessWidget {
  const _PointList({
    required this.title,
    required this.points,
    required this.icon,
    required this.color,
  });

  final String title;
  final List<String> points;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 6),
        ...points.map(
          (point) => Padding(
            padding: const EdgeInsets.only(bottom: 5),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Icon(icon, size: 15, color: color),
                ),
                const SizedBox(width: 8),
                Expanded(child: Text(point)),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _FinalResultCard extends StatelessWidget {
  const _FinalResultCard({
    required this.result,
    required this.statusLabel,
    required this.statusColor,
    required this.onRetryWeak,
    required this.onDashboard,
    required this.onCarePlan,
  });

  final TeachBackFinalResult result;
  final String statusLabel;
  final Color statusColor;
  final VoidCallback onRetryWeak;
  final VoidCallback onDashboard;
  final VoidCallback? onCarePlan;

  @override
  Widget build(BuildContext context) {
    return FadeSlideIn(
      child: AppCard(
        padding: const EdgeInsets.all(30),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.check_circle_outline, size: 48, color: statusColor),
            const SizedBox(height: 14),
            Text(
              context.tr('teach_back_understanding_recorded'),
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(
              statusLabel,
              style: TextStyle(color: statusColor, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 18),
            LinearProgressIndicator(
              value: result.score / 100,
              minHeight: 10,
              borderRadius: BorderRadius.circular(99),
            ),
            const SizedBox(height: 14),
            Text(
              context.tr(
                'teach_back_understanding_score',
                values: {'score': result.score},
              ),
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _ResultChip(
                  icon: Icons.task_alt,
                  text: context.tr(
                    'teach_back_questions_understood',
                    values: {
                      'count': result.understoodCount,
                      'total': result.questionCount,
                    },
                  ),
                ),
                _ResultChip(
                  icon: Icons.info_outline,
                  text: context.tr(
                    'teach_back_needs_review_count',
                    values: {'count': result.needsReviewCount},
                  ),
                ),
              ],
            ),
            const SizedBox(height: 22),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (result.weakQuestionIds.isNotEmpty)
                  OutlinedButton.icon(
                    onPressed: onRetryWeak,
                    icon: const Icon(Icons.refresh, size: 18),
                    label: Text(context.tr('teach_back_retry_weak')),
                  ),
                if (onCarePlan != null)
                  FilledButton.icon(
                    onPressed: onCarePlan,
                    icon: const Icon(Icons.checklist_outlined, size: 18),
                    label: Text(context.tr('teach_back_return_care_plan')),
                  ),
                FilledButton.icon(
                  onPressed: onDashboard,
                  icon: const Icon(Icons.dashboard_outlined, size: 18),
                  label: Text(context.tr('teach_back_return_dashboard')),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ResultChip extends StatelessWidget {
  const _ResultChip({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: AppColors.primaryLight,
        borderRadius: BorderRadius.circular(AppRadii.md),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: AppColors.accentForeground),
          const SizedBox(width: 7),
          Text(
            text,
            style: const TextStyle(
              color: AppColors.accentForeground,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
