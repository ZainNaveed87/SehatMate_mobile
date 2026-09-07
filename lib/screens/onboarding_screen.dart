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

  String _currentStepTitle() => 'Set up your care';

  IconData _currentStepIcon() {
    return switch (step) {
      1 => Icons.person_search_outlined,
      2 => Icons.badge_outlined,
      3 => Icons.language_rounded,
      4 => Icons.flag_outlined,
      5 => Icons.description_outlined,
      6 => Icons.notifications_active_outlined,
      _ => Icons.accessibility_new_rounded,
    };
  }

  @override
  Widget build(BuildContext context) {
    if (!_session.isAuthenticated || _session.isGuest) {
      return Scaffold(
        backgroundColor: const Color(0xFFF4F8F7),
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: AppCard(
                  padding: const EdgeInsets.all(24),
                  child: EmptyState(
                    icon: Icons.lock_outline,
                    title: context.tr('onboarding_sign_in_title'),
                    description: context.tr('onboarding_sign_in_message'),
                    action: FilledButton.icon(
                      onPressed: () => Navigator.pushReplacementNamed(
                        context,
                        AppRoutes.auth,
                      ),
                      icon: const Icon(Icons.login_rounded, size: 18),
                      label: Text(context.tr('sign_in')),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    final width = MediaQuery.sizeOf(context).width;
    final desktop = width >= 900;

    return Scaffold(
      backgroundColor: const Color(0xFFF4F8F7),
      body: SafeArea(
        child: Stack(
          children: [
            PositionedDirectional(
              top: -120,
              end: -100,
              child: Container(
                width: 300,
                height: 300,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color(0x100D9488),
                ),
              ),
            ),
            PositionedDirectional(
              bottom: -150,
              start: -110,
              child: Container(
                width: 340,
                height: 340,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color(0x0B14B8A6),
                ),
              ),
            ),
            SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                width >= 640 ? 24 : 16,
                0,
                width >= 640 ? 24 : 16,
                48,
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1040),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
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
                              borderRadius:
                                  BorderRadius.circular(AppRadii.lg),
                              child: const Padding(
                                padding: EdgeInsets.symmetric(vertical: 8),
                                child: BrandLogo(),
                              ),
                            ),
                            const Spacer(),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.card,
                                borderRadius: BorderRadius.circular(999),
                                border: Border.all(color: AppColors.border),
                              ),
                              child: Text(
                                context.tr(
                                  'onboarding_step_of_total',
                                  values: {
                                    'step': step,
                                    'total': _totalSteps,
                                  },
                                ),
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: AppColors.muted,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (desktop)
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(
                              width: 310,
                              child: _onboardingHero(),
                            ),
                            const SizedBox(width: 18),
                            Expanded(child: _onboardingCard()),
                          ],
                        )
                      else ...[
                        _onboardingHero(compact: true),
                        const SizedBox(height: 14),
                        _onboardingCard(),
                      ],
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

  Widget _onboardingHero({bool compact = false}) {
    final progress = step / _totalSteps;

    return Container(
      padding: EdgeInsets.all(compact ? 18 : 24),
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
            top: -68,
            end: -50,
            child: Container(
              width: 175,
              height: 175,
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
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: const Color(0x20FFFFFF),
                  borderRadius: BorderRadius.circular(AppRadii.xl),
                  border: Border.all(color: const Color(0x2FFFFFFF)),
                ),
                child: Icon(
                  _currentStepIcon(),
                  color: Colors.white,
                  size: 23,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Set up SehatMate',
                style: TextStyle(
                  color: Color(0xDFFFFFFF),
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                _currentStepTitle(),
                style: TextStyle(
                  color: Colors.white,
                  fontSize: compact ? 23 : 27,
                  height: 1.12,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -.35,
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Text(
                    '$step / $_totalSteps',
                    style: const TextStyle(
                      color: Color(0xE6FFFFFF),
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${(progress * 100).round()}%',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 6,
                  color: Colors.white,
                  backgroundColor: const Color(0x30FFFFFF),
                ),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: List.generate(
                  _totalSteps,
                  (index) {
                    final number = index + 1;
                    final active = number == step;
                    final complete = number < step;

                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      width: active ? 34 : 26,
                      height: 26,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: complete || active
                            ? Colors.white
                            : const Color(0x16FFFFFF),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: complete || active
                              ? Colors.white
                              : const Color(0x38FFFFFF),
                        ),
                      ),
                      child: complete
                          ? const Icon(
                              Icons.check_rounded,
                              size: 14,
                              color: AppColors.primary,
                            )
                          : Text(
                              '$number',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: active
                                    ? AppColors.primary
                                    : const Color(0xC8FFFFFF),
                              ),
                            ),
                    );
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _onboardingCard() {
    return AppCard(
      padding: EdgeInsets.zero,
      radius: 28,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            height: 4,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Color(0xFF0F766E),
                  Color(0xFF14B8A6),
                ],
              ),
              borderRadius: BorderRadius.vertical(
                top: Radius.circular(28),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(22),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeInCubic,
              transitionBuilder: (child, animation) {
                final slide = Tween<Offset>(
                  begin: const Offset(.025, 0),
                  end: Offset.zero,
                ).animate(animation);

                return FadeTransition(
                  opacity: animation,
                  child: SlideTransition(
                    position: slide,
                    child: child,
                  ),
                );
              },
              child: Column(
                key: ValueKey(step),
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _stepContent(),
                  const SizedBox(height: 28),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final backButton = TextButton.icon(
                        onPressed: _submitting ? null : _back,
                        icon: const Icon(
                          Icons.arrow_back_rounded,
                          size: 17,
                        ),
                        label: Text(context.tr('back')),
                      );

                      final nextButton = FilledButton.icon(
                        key: const Key('onboarding_next_button'),
                        onPressed: _submitting ? null : _next,
                        iconAlignment: IconAlignment.end,
                        icon: step < _totalSteps
                            ? const Icon(
                                Icons.arrow_forward_rounded,
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
                                : const Icon(
                                    Icons.check_rounded,
                                    size: 17,
                                  ),
                        label: Text(
                          step < _totalSteps
                              ? context.tr('continue')
                              : context.tr('finish_setup'),
                        ),
                      );

                      if (constraints.maxWidth < 420) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            SizedBox(
                              width: double.infinity,
                              child: nextButton,
                            ),
                            const SizedBox(height: 8),
                            Align(
                              alignment:
                                  AlignmentDirectional.centerStart,
                              child: backButton,
                            ),
                          ],
                        );
                      }

                      return Row(
                        children: [
                          backButton,
                          const Spacer(),
                          nextButton,
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
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
  const _StepHeading({
    required this.title,
    required this.subtitle,
  });

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: const TextStyle(
              fontSize: 22,
              height: 1.2,
              fontWeight: FontWeight.w800,
              letterSpacing: -.2,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: const TextStyle(
              color: AppColors.muted,
              fontSize: 13,
              height: 1.45,
            ),
          ),
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
    return HoverLift(
      child: InkWell(
        onTap: () => onChanged(!selected),
        borderRadius: BorderRadius.circular(AppRadii.xl),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: double.infinity,
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            color: selected
                ? const Color(0xFFF0FDFA)
                : AppColors.card,
            border: Border.all(
              color: selected
                  ? AppColors.primary.withValues(alpha: .38)
                  : AppColors.border,
            ),
            borderRadius: BorderRadius.circular(AppRadii.xl),
            boxShadow: selected
                ? const [
                    BoxShadow(
                      color: Color(0x120F766E),
                      blurRadius: 14,
                      spreadRadius: -8,
                      offset: Offset(0, 7),
                    ),
                  ]
                : const [],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: selected
                      ? AppColors.primary
                      : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(AppRadii.lg),
                ),
                child: Icon(
                  selected
                      ? Icons.check_rounded
                      : Icons.add_rounded,
                  size: 18,
                  color:
                      selected ? Colors.white : AppColors.muted,
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      description,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.muted,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              Checkbox(
                value: selected,
                onChanged: (value) => onChanged(value ?? false),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
