import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/app_routes.dart';
import '../core/app_theme.dart';
import '../data/demo_data.dart';
import '../localization/app_language.dart';
import '../localization/language_scope.dart';
import '../services/auth_service.dart';
import '../services/notification_service.dart';
import '../services/settings_service.dart';
import '../widgets/brand_logo.dart';
import '../widgets/ui.dart';

typedef ReminderPermissionRequester =
    Future<NotificationPermissionSnapshot> Function();

abstract interface class OnboardingPreferenceStore {
  Future<void> save({
    required Set<String> goals,
    required String documentIntent,
    required bool remindersRequested,
  });
}

class SharedPreferencesOnboardingPreferenceStore
    implements OnboardingPreferenceStore {
  const SharedPreferencesOnboardingPreferenceStore();

  static const goalsKey = 'sehatmate_onboarding_goals_v1';
  static const documentIntentKey = 'sehatmate_onboarding_document_intent_v1';
  static const remindersRequestedKey =
      'sehatmate_onboarding_reminders_requested_v1';

  @override
  Future<void> save({
    required Set<String> goals,
    required String documentIntent,
    required bool remindersRequested,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(goalsKey, goals.toList()..sort());
    await prefs.setString(documentIntentKey, documentIntent);
    await prefs.setBool(remindersRequestedKey, remindersRequested);
  }
}

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({
    super.key,
    this.session,
    this.settingsService,
    this.preferenceStore,
    this.reminderPermissionRequester,
  });

  final ProfileSession? session;
  final SettingsService? settingsService;
  final OnboardingPreferenceStore? preferenceStore;
  final ReminderPermissionRequester? reminderPermissionRequester;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  static const _totalSteps = 7;

  late final ProfileSession _session;
  late final SettingsService _settings;
  late final OnboardingPreferenceStore _preferenceStore;
  late final ReminderPermissionRequester _requestReminderPermission;
  late final TextEditingController name;
  final city = TextEditingController();

  int step = 1;
  String who = 'Myself';
  String ageGroup = '';
  AppLanguage language = AppLanguage.english;
  final selectedGoals = <String>{};
  String documentIntent = 'later';
  String reminderIntent = '';
  bool simpleCareMode = false;
  bool _submitting = false;
  bool _languageInitialized = false;

  @override
  void initState() {
    super.initState();
    _session = widget.session ?? AuthSession.instance;
    _settings = widget.settingsService ?? SettingsService.instance;
    _preferenceStore =
        widget.preferenceStore ??
        const SharedPreferencesOnboardingPreferenceStore();
    _requestReminderPermission =
        widget.reminderPermissionRequester ??
        NotificationService.instance.requestReminderPermission;
    name = TextEditingController(text: _session.user?.name ?? '');
    Future<void>.microtask(_initializeSettings);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_languageInitialized) {
      language = context.appLanguage;
      _languageInitialized = true;
    }
  }

  @override
  void dispose() {
    name.dispose();
    city.dispose();
    super.dispose();
  }

  Future<void> _initializeSettings() async {
    await _settings.initialize();
    if (!mounted) return;
    setState(() => simpleCareMode = _settings.simpleCareModeEnabled);
  }

  @override
  Widget build(BuildContext context) {
    if (!_session.isAuthenticated || _session.isGuest) {
      return Scaffold(
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: EmptyState(
                  icon: Icons.lock_outline,
                  title: context.tr('onboarding_sign_in_title'),
                  description: context.tr('onboarding_sign_in_message'),
                  action: FilledButton(
                    onPressed: () =>
                        Navigator.pushReplacementNamed(context, AppRoutes.auth),
                    child: Text(context.tr('sign_in')),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 64),
                child: Column(
                  children: [
                    SizedBox(
                      height: 72,
                      child: Row(
                        children: [
                          InkWell(
                            onTap: () => Navigator.pushReplacementNamed(
                              context,
                              AppRoutes.landing,
                            ),
                            child: const BrandLogo(),
                          ),
                          const Spacer(),
                          Text(
                            context.tr(
                              'onboarding_step_of_total',
                              values: {'step': step, 'total': _totalSteps},
                            ),
                            style: const TextStyle(
                              fontSize: 13,
                              color: AppColors.muted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(99),
                      child: LinearProgressIndicator(
                        value: step / _totalSteps,
                        minHeight: 8,
                        color: AppColors.primary,
                        backgroundColor: AppColors.secondary,
                      ),
                    ),
                    const SizedBox(height: 24),
                    AppCard(
                      padding: const EdgeInsets.all(24),
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 200),
                        child: Column(
                          key: ValueKey(step),
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _stepContent(),
                            const SizedBox(height: 28),
                            Row(
                              children: [
                                TextButton.icon(
                                  onPressed: _submitting ? null : _back,
                                  icon: const Icon(Icons.arrow_back, size: 17),
                                  label: Text(context.tr('back')),
                                ),
                                const Spacer(),
                                FilledButton.icon(
                                  key: const Key('onboarding_next_button'),
                                  onPressed: _submitting ? null : _next,
                                  iconAlignment: IconAlignment.end,
                                  icon: step < _totalSteps
                                      ? const Icon(
                                          Icons.arrow_forward,
                                          size: 17,
                                        )
                                      : _submitting
                                      ? const SizedBox(
                                          width: 17,
                                          height: 17,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Colors.white,
                                          ),
                                        )
                                      : const Icon(Icons.check, size: 17),
                                  label: Text(
                                    step < _totalSteps
                                        ? context.tr('continue')
                                        : context.tr('finish_setup'),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _stepContent() {
    switch (step) {
      case 1:
        return _whoStep();
      case 2:
        return _profileStep();
      case 3:
        return _languageStep();
      case 4:
        return _goalsStep();
      case 5:
        return _documentStep();
      case 6:
        return _remindersStep();
      default:
        return _simpleCareStep();
    }
  }

  Widget _whoStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _StepHeading(
          title: context.tr('onboarding_who_title'),
          subtitle: context.tr('onboarding_who_subtitle'),
        ),
        const SizedBox(height: 20),
        OptionCard(
          key: const Key('onboarding_who_myself'),
          label: context.tr('onboarding_myself'),
          description: context.tr('onboarding_myself_description'),
          selected: who == 'Myself',
          onTap: () => setState(() => who = 'Myself'),
        ),
        const SizedBox(height: 12),
        OptionCard(
          key: const Key('onboarding_who_someone'),
          label: context.tr('onboarding_someone_i_care_for'),
          description: context.tr('onboarding_someone_description'),
          selected: who == 'Someone I care for',
          onTap: () => setState(() => who = 'Someone I care for'),
        ),
      ],
    );
  }

  Widget _profileStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _StepHeading(
          title: context.tr('onboarding_profile_title'),
          subtitle: context.tr('onboarding_profile_subtitle'),
        ),
        const SizedBox(height: 20),
        fieldLabel(
          context.tr('patient_name'),
          TextField(
            key: const Key('onboarding_name_field'),
            controller: name,
            textInputAction: TextInputAction.next,
          ),
        ),
        const SizedBox(height: 16),
        fieldLabel(
          context.tr('age_group'),
          DropdownButtonFormField<String>(
            key: const Key('onboarding_age_dropdown'),
            initialValue: ageGroup,
            isExpanded: true,
            decoration: const InputDecoration(),
            items: [
              DropdownMenuItem(value: '', child: Text(context.tr('not_added'))),
              ...patientAgeGroups.map(
                (item) => DropdownMenuItem<String>(
                  value: item,
                  child: Text(ageGroupLabel(item, context.appLanguage)),
                ),
              ),
            ],
            onChanged: (value) => setState(() => ageGroup = value ?? ''),
          ),
        ),
        const SizedBox(height: 16),
        fieldLabel(
          context.tr('city'),
          TextField(
            key: const Key('onboarding_city_field'),
            controller: city,
            decoration: InputDecoration(hintText: context.tr('not_added')),
          ),
        ),
      ],
    );
  }

  Widget _languageStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _StepHeading(
          title: context.tr('onboarding_language_title'),
          subtitle: context.tr('language_change_later_settings'),
        ),
        const SizedBox(height: 20),
        ...AppLanguage.values.map(
          (item) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: OptionCard(
              key: Key('onboarding_language_${item.storageValue}'),
              label: item.displayName,
              selected: language == item,
              onTap: () async {
                setState(() => language = item);
                await LanguageScope.read(context).setLanguage(item);
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _goalsStep() {
    final goals = [
      _GoalOption(
        'understand_plan',
        'onboarding_goal_understand_plan',
        'onboarding_goal_understand_plan_desc',
      ),
      _GoalOption(
        'track_tasks',
        'onboarding_goal_track_tasks',
        'onboarding_goal_track_tasks_desc',
      ),
      _GoalOption(
        'documents',
        'onboarding_goal_documents',
        'onboarding_goal_documents_desc',
      ),
      _GoalOption(
        'family',
        'onboarding_goal_family',
        'onboarding_goal_family_desc',
      ),
      _GoalOption(
        'teach_back',
        'onboarding_goal_teach_back',
        'onboarding_goal_teach_back_desc',
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _StepHeading(
          title: context.tr('onboarding_goals_title'),
          subtitle: context.tr('onboarding_goals_subtitle'),
        ),
        const SizedBox(height: 20),
        ...goals.map(
          (goal) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _CheckboxOptionCard(
              key: Key('onboarding_goal_${goal.key}'),
              label: context.tr(goal.labelKey),
              description: context.tr(goal.descriptionKey),
              selected: selectedGoals.contains(goal.key),
              onChanged: (selected) => setState(() {
                if (selected) {
                  selectedGoals.add(goal.key);
                } else {
                  selectedGoals.remove(goal.key);
                }
              }),
            ),
          ),
        ),
      ],
    );
  }

  Widget _documentStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _StepHeading(
          title: context.tr('onboarding_document_title'),
          subtitle: context.tr('onboarding_document_subtitle'),
        ),
        const SizedBox(height: 20),
        OptionCard(
          key: const Key('onboarding_document_upload'),
          label: context.tr('onboarding_document_upload_now'),
          description: context.tr('onboarding_document_upload_now_desc'),
          selected: documentIntent == 'upload',
          onTap: () => setState(() => documentIntent = 'upload'),
        ),
        const SizedBox(height: 12),
        OptionCard(
          key: const Key('onboarding_document_later'),
          label: context.tr('onboarding_document_later'),
          description: context.tr('onboarding_document_later_desc'),
          selected: documentIntent == 'later',
          onTap: () => setState(() => documentIntent = 'later'),
        ),
        const SizedBox(height: 12),
        OptionCard(
          key: const Key('onboarding_document_no'),
          label: context.tr('onboarding_document_no'),
          description: context.tr('onboarding_document_no_desc'),
          selected: documentIntent == 'none',
          onTap: () => setState(() => documentIntent = 'none'),
        ),
      ],
    );
  }

  Widget _remindersStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _StepHeading(
          title: context.tr('onboarding_reminders_title'),
          subtitle: context.tr('onboarding_reminders_subtitle'),
        ),
        const SizedBox(height: 20),
        OptionCard(
          key: const Key('onboarding_reminders_yes'),
          label: context.tr('onboarding_reminders_yes'),
          description: context.tr('onboarding_reminders_yes_desc'),
          selected: reminderIntent == 'yes',
          onTap: () => setState(() => reminderIntent = 'yes'),
        ),
        const SizedBox(height: 12),
        OptionCard(
          key: const Key('onboarding_reminders_later'),
          label: context.tr('onboarding_reminders_later'),
          description: context.tr('onboarding_reminders_later_desc'),
          selected: reminderIntent == 'later',
          onTap: () => setState(() => reminderIntent = 'later'),
        ),
      ],
    );
  }

  Widget _simpleCareStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _StepHeading(
          title: context.tr('onboarding_simple_care_title'),
          subtitle: context.tr('onboarding_simple_care_subtitle'),
        ),
        const SizedBox(height: 20),
        Material(
          color: AppColors.card,
          shape: RoundedRectangleBorder(
            side: const BorderSide(color: AppColors.border),
            borderRadius: BorderRadius.circular(AppRadii.xl),
          ),
          clipBehavior: Clip.antiAlias,
          child: SwitchListTile(
            key: const Key('onboarding_simple_care_switch'),
            value: simpleCareMode,
            onChanged: (value) => setState(() => simpleCareMode = value),
            title: Text(
              context.tr('simple_care_mode'),
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle: Text(context.tr('onboarding_simple_care_desc')),
          ),
        ),
      ],
    );
  }

  void _back() {
    if (step == 1) {
      Navigator.pushReplacementNamed(context, AppRoutes.auth);
    } else {
      setState(() => step--);
    }
  }

  Future<void> _next() async {
    if (step == 2 && !_profileFieldsAreValid()) return;
    if (step == 6 && reminderIntent.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr('onboarding_choose_reminders'))),
      );
      return;
    }
    if (step < _totalSteps) {
      setState(() => step++);
      return;
    }
    await _finish();
  }

  bool _profileFieldsAreValid() {
    if (name.text.trim().length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr('enter_valid_patient_name'))),
      );
      return false;
    }
    if (city.text.trim().isNotEmpty && city.text.trim().length < 2) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.tr('enter_valid_city'))));
      return false;
    }
    return true;
  }

  Future<void> _finish() async {
    if (!_profileFieldsAreValid() || _submitting) return;
    setState(() => _submitting = true);
    try {
      if (reminderIntent == 'yes') {
        final permission = await _requestReminderPermission();
        if (permission.notificationsDisabled && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(context.tr('onboarding_reminders_denied'))),
          );
        }
      }

      await _settings.setSimpleCareMode(simpleCareMode);
      await _preferenceStore.save(
        goals: selectedGoals,
        documentIntent: documentIntent,
        remindersRequested: reminderIntent == 'yes',
      );

      final profile = await _session.completeOnboarding(
        usingFor: who,
        patientName: name.text,
        ageGroup: ageGroup,
        city: city.text,
        preferredLanguage: language.serverPreferredLanguage,
        accessibilityMode: simpleCareMode ? 'Simple Care Mode' : 'Standard',
        caregiverSupport: false,
      );
      if (!mounted) return;
      await LanguageScope.read(
        context,
      ).setFromServerPreferredLanguage(profile.preferredLanguage);
      if (!mounted) return;
      Navigator.pushNamedAndRemoveUntil(
        context,
        documentIntent == 'upload'
            ? AppRoutes.carePlanNew
            : AppRoutes.dashboard,
        (_) => false,
      );
    } on AuthException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    } on SettingsException {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr('settings_preference_save_failed'))),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr('onboarding_save_failed'))),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }
}

class _StepHeading extends StatelessWidget {
  const _StepHeading({required this.title, required this.subtitle});
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        title,
        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
      ),
      const SizedBox(height: 4),
      Text(subtitle, style: const TextStyle(color: AppColors.muted)),
    ],
  );
}

class _GoalOption {
  const _GoalOption(this.key, this.labelKey, this.descriptionKey);

  final String key;
  final String labelKey;
  final String descriptionKey;
}

class _CheckboxOptionCard extends StatelessWidget {
  const _CheckboxOptionCard({
    required this.label,
    required this.description,
    required this.selected,
    required this.onChanged,
    super.key,
  });

  final String label;
  final String description;
  final bool selected;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => onChanged(!selected),
      borderRadius: BorderRadius.circular(AppRadii.xl),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: selected ? AppColors.primaryLight : AppColors.card,
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.border,
          ),
          borderRadius: BorderRadius.circular(AppRadii.xl),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Checkbox(
              value: selected,
              onChanged: (value) => onChanged(value ?? false),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    description,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.muted,
                    ),
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
