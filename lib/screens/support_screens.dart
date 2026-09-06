import 'package:flutter/material.dart';

import '../core/app_routes.dart';
import '../core/app_theme.dart';
import '../data/demo_data.dart';
import '../localization/app_language.dart';
import '../localization/language_scope.dart';
import '../localization/localized_errors.dart';
import '../services/auth_service.dart';
import '../services/care_plan_service.dart';
import '../services/device_speech_service.dart';
import '../services/settings_service.dart';
import '../services/simple_care_service.dart';
import '../services/teach_back_service.dart';
import '../widgets/app_shell.dart';
import '../widgets/page_header.dart';
import '../widgets/ui.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key, this.settingsService});

  final SettingsService? settingsService;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final SettingsService _settings;
  bool _signingOut = false;

  @override
  void initState() {
    super.initState();
    _settings = widget.settingsService ?? SettingsService.instance;
    Future<void>.microtask(_settings.initialize);
  }

  Future<void> _setSimpleCareMode(bool enabled) async {
    try {
      await _settings.setSimpleCareMode(enabled);
    } on SettingsException {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr('settings_preference_save_failed'))),
      );
    }
  }

  Future<void> _setLanguage(AppLanguage language) async {
    try {
      await LanguageScope.read(context).setLanguage(language);
      if (!mounted) return;
      showDemoMessage(context, context.tr('language_changed'));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr('settings_language_update_failed'))),
      );
    }
  }

  Future<void> _signOut() async {
    setState(() => _signingOut = true);
    try {
      await AuthSession.instance.logout();
      if (!mounted) return;
      Navigator.pushNamedAndRemoveUntil(
        context,
        AppRoutes.landing,
        (_) => false,
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr('settings_sign_out_failed'))),
      );
    } finally {
      if (mounted) setState(() => _signingOut = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_settings, AuthSession.instance]),
      builder: (context, _) => AppShell(
        currentRoute: AppRoutes.settings,
        title: context.tr('settings'),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                PageHeader(
                  title: context.tr('settings'),
                  subtitle: context.tr('settings_subtitle'),
                ),
                _SettingsSection(
                  title: context.tr('settings_care_experience_section'),
                  icon: Icons.volunteer_activism_outlined,
                  children: [
                    _SettingsToggleRow(
                      switchKey: const Key('settings_simple_care_toggle'),
                      title: context.tr('simple_care_mode'),
                      description: context.tr('settings_simple_care_hint'),
                      value: _settings.simpleCareModeEnabled,
                      busy: _settings.savingSimpleCareMode,
                      onChanged: _setSimpleCareMode,
                    ),
                    if (_settings.simpleCareModeEnabled)
                      _SettingsActionRow(
                        icon: Icons.check_circle_outline,
                        title: context.tr('simple_care_mode_enabled'),
                        description: context.tr(
                          'simple_care_mode_enabled_description',
                        ),
                        action: OutlinedButton.icon(
                          onPressed: () => Navigator.pushNamed(
                            context,
                            AppRoutes.simpleCare,
                          ),
                          icon: const Icon(Icons.open_in_new, size: 17),
                          label: Text(context.tr('open_simple_care_view')),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 18),
                _SettingsSection(
                  title: context.tr('settings_language_section'),
                  icon: Icons.language_outlined,
                  children: [
                    _SettingsActionRow(
                      icon: Icons.translate_outlined,
                      title: context.tr('choose_language'),
                      description: context.tr(
                        'settings_current_language',
                        values: {'language': context.appLanguage.displayName},
                      ),
                      action: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 320),
                        child: DropdownButtonFormField<AppLanguage>(
                          key: const Key('settings_language_dropdown'),
                          initialValue: context.appLanguage,
                          isExpanded: true,
                          items: AppLanguage.values
                              .map(
                                (language) => DropdownMenuItem(
                                  value: language,
                                  child: Text(language.displayName),
                                ),
                              )
                              .toList(),
                          onChanged: (value) {
                            if (value != null) _setLanguage(value);
                          },
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                _SettingsSection(
                  title: context.tr('settings_reminders_section'),
                  icon: Icons.notifications_active_outlined,
                  children: [
                    _SettingsActionRow(
                      icon: Icons.alarm_on_outlined,
                      title: context.tr('settings_reminders_from_care_title'),
                      description: context.tr(
                        'settings_reminders_from_care_description',
                      ),
                      action: OutlinedButton.icon(
                        onPressed: () =>
                            Navigator.pushNamed(context, AppRoutes.calendar),
                        icon: const Icon(
                          Icons.calendar_month_outlined,
                          size: 17,
                        ),
                        label: Text(context.tr('open_calendar')),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                _SettingsSection(
                  title: context.tr('settings_account_section'),
                  icon: Icons.account_circle_outlined,
                  children: [
                    _AccountRow(onSignOut: _signingOut ? null : _signOut),
                  ],
                ),
                const SizedBox(height: 18),
                _SettingsSection(
                  title: context.tr('settings_privacy_data_section'),
                  icon: Icons.privacy_tip_outlined,
                  children: [
                    _SettingsActionRow(
                      icon: Icons.description_outlined,
                      title: context.tr('documents'),
                      description: context.tr('settings_documents_data_hint'),
                      action: OutlinedButton(
                        onPressed: () =>
                            Navigator.pushNamed(context, AppRoutes.documents),
                        child: Text(context.tr('open')),
                      ),
                    ),
                    _SettingsActionRow(
                      icon: Icons.checklist_outlined,
                      title: context.tr('care_plans'),
                      description: context.tr('settings_care_plans_data_hint'),
                      action: OutlinedButton(
                        onPressed: () =>
                            Navigator.pushNamed(context, AppRoutes.carePlans),
                        child: Text(context.tr('open')),
                      ),
                    ),
                    _SettingsActionRow(
                      icon: Icons.handshake_outlined,
                      title: context.tr('family_care'),
                      description: context.tr('settings_family_data_hint'),
                      action: OutlinedButton(
                        onPressed: () =>
                            Navigator.pushNamed(context, AppRoutes.family),
                        child: Text(context.tr('open')),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                _SettingsSection(
                  title: context.tr('settings_about_section'),
                  icon: Icons.info_outline,
                  children: [
                    _SettingsActionRow(
                      icon: Icons.favorite_border,
                      title: context.tr('app_name'),
                      description: context.tr('settings_about_description'),
                    ),
                  ],
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
}

class _SettingsSection extends StatelessWidget {
  const _SettingsSection({
    required this.title,
    required this.icon,
    required this.children,
  });

  final String title;
  final IconData icon;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 21, color: AppColors.primary),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          for (var index = 0; index < children.length; index++) ...[
            children[index],
            if (index < children.length - 1)
              const Divider(height: 24, color: AppColors.border),
          ],
        ],
      ),
    );
  }
}

class _SettingsToggleRow extends StatelessWidget {
  const _SettingsToggleRow({
    required this.switchKey,
    required this.title,
    required this.description,
    required this.value,
    required this.busy,
    required this.onChanged,
  });

  final Key switchKey;
  final String title;
  final String description;
  final bool value;
  final bool busy;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                description,
                style: const TextStyle(
                  fontSize: 14,
                  color: AppColors.muted,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        busy
            ? const SizedBox(
                width: 26,
                height: 26,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Switch(key: switchKey, value: value, onChanged: onChanged),
      ],
    );
  }
}

class _SettingsActionRow extends StatelessWidget {
  const _SettingsActionRow({
    required this.icon,
    required this.title,
    required this.description,
    this.action,
  });

  final IconData icon;
  final String title;
  final String description;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final leading = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: AppColors.primaryLight,
            borderRadius: BorderRadius.circular(AppRadii.lg),
          ),
          child: Icon(icon, size: 19, color: AppColors.primary),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                description,
                style: const TextStyle(
                  fontSize: 14,
                  color: AppColors.muted,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      ],
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        if (action == null) return leading;
        if (constraints.maxWidth < 560) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              leading,
              const SizedBox(height: 12),
              Align(alignment: AlignmentDirectional.centerStart, child: action),
            ],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(child: leading),
            const SizedBox(width: 16),
            action!,
          ],
        );
      },
    );
  }
}

class _AccountRow extends StatelessWidget {
  const _AccountRow({required this.onSignOut});

  final VoidCallback? onSignOut;

  @override
  Widget build(BuildContext context) {
    final user = AuthSession.instance.user;
    final name = user?.name.trim();
    final email = user?.email.trim();
    final title = name == null || name.isEmpty
        ? AuthSession.instance.isGuest
              ? context.tr('guest_user')
              : context.tr('settings_not_signed_in')
        : name;
    final description = email == null || email.isEmpty
        ? context.tr('settings_account_description')
        : email;

    return _SettingsActionRow(
      icon: Icons.person_outline,
      title: title,
      description: description,
      action: FilledButton.icon(
        key: const Key('settings_sign_out_button'),
        onPressed: onSignOut,
        icon: const Icon(Icons.logout, size: 17),
        label: Text(context.tr('logout')),
      ),
    );
  }
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
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
                PageHeader(
                  title: context.tr('patient_profile'),
                  subtitle: context.tr('patient_profile_subtitle'),
                  action: OutlinedButton(
                    onPressed: () =>
                        Navigator.pushNamed(context, AppRoutes.realityCheck),
                    child: Text(context.tr('update_reality_check')),
                  ),
                ),
                AppCard(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        context.tr('basic_details'),
                        style: const TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 14),
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final fields = [
                            fieldLabel(
                              context.tr('full_name'),
                              TextField(controller: name),
                            ),
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
                                        child: Text(
                                          ageGroupLabel(
                                            item,
                                            context.appLanguage,
                                          ),
                                        ),
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
                            fieldLabel(
                              context.tr('city'),
                              TextField(controller: city),
                            ),
                            fieldLabel(
                              context.tr('preferred_language'),
                              InputDecorator(
                                decoration: const InputDecoration(),
                                child: Text(demoLanguageLabel(state.language)),
                              ),
                            ),
                          ];
                          return constraints.maxWidth >= 520
                              ? Wrap(
                                  spacing: 16,
                                  runSpacing: 14,
                                  children: fields
                                      .map(
                                        (field) => SizedBox(
                                          width:
                                              (constraints.maxWidth - 16) / 2,
                                          child: field,
                                        ),
                                      )
                                      .toList(),
                                )
                              : Column(
                                  children: fields
                                      .map(
                                        (field) => Padding(
                                          padding: const EdgeInsets.only(
                                            bottom: 14,
                                          ),
                                          child: field,
                                        ),
                                      )
                                      .toList(),
                                );
                        },
                      ),
                      const SizedBox(height: 16),
                      FilledButton(
                        onPressed: _saving ? null : _saveProfile,
                        child: Text(context.tr('save_changes')),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                AppCard(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        context.tr('daily_routine_and_support'),
                        style: const TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 14),
                      ...realityQuestions
                          .take(5)
                          .toList()
                          .asMap()
                          .entries
                          .map(
                            (entry) => Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: Text(
                                      demoRealityQuestionText(
                                        entry.value,
                                        context.appLanguage,
                                      ),
                                      style: const TextStyle(
                                        fontSize: 15,
                                        color: AppColors.muted,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Flexible(
                                    child: Text(
                                      demoRealityOptionText(
                                        entry.value.options[entry.key %
                                            entry.value.options.length],
                                        context.appLanguage,
                                      ),
                                      textAlign: TextAlign.right,
                                      style: const TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                AppCard(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        context.tr('caregiver_support'),
                        style: const TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 12),
                      ...state.caregivers.map(
                        (caregiver) => Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  '${caregiver.name} · ${caregiver.relationship}',
                                  style: const TextStyle(fontSize: 15),
                                ),
                              ),
                              Text(
                                caregiver.availability,
                                style: const TextStyle(
                                  fontSize: 15,
                                  color: AppColors.muted,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      OutlinedButton(
                        onPressed: () =>
                            Navigator.pushNamed(context, AppRoutes.family),
                        child: Text(context.tr('manage_caregivers')),
                      ),
                    ],
                  ),
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

class SimpleCareScreen extends StatefulWidget {
  const SimpleCareScreen({super.key, this.service, this.settingsService});

  final SimpleCareClient? service;
  final SettingsService? settingsService;

  @override
  State<SimpleCareScreen> createState() => _SimpleCareScreenState();
}

class _SimpleCareScreenState extends State<SimpleCareScreen>
    with WidgetsBindingObserver {
  late final SimpleCareClient _service;
  late final SettingsService _settings;

  CareTaskAppDayData? _today;
  List<DemoPlan> _plans = const [];
  bool _loading = true;
  String? _error;
  bool _offline = false;
  final Set<String> _savingIds = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _service = widget.service ?? SimpleCareService.instance;
    _settings = widget.settingsService ?? SettingsService.instance;
    Future<void>.microtask(_settings.initialize);
    _load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && !_loading) {
      _load();
    }
  }

  Future<void> _load() async {
    if (widget.service == null &&
        (!AuthSession.instance.isAuthenticated ||
            AuthSession.instance.isGuest)) {
      setState(() {
        _loading = false;
        _offline = false;
        _error = '__simple_care_sign_in__';
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
      _offline = false;
    });

    try {
      final results = await Future.wait<Object>([
        _service.fetchTodayCare(),
        _service.fetchCarePlans(),
      ]);
      if (!mounted) return;
      setState(() {
        _today = results[0] as CareTaskAppDayData;
        _plans = results[1] as List<DemoPlan>;
        _loading = false;
      });
    } on CarePlanException catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _offline = error.retryable;
        _error = localizedCarePlanExceptionMessage(error, context.appLanguage);
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _offline = false;
        _error = context.tr('simple_care_load_failed_description');
      });
    }
  }

  Future<void> _setOutcome(CareTaskOccurrence occurrence, String status) async {
    setState(() => _savingIds.add(occurrence.id));
    try {
      final result = await _service.setOutcome(occurrence, status);
      if (!mounted) return;

      final current = _today;
      if (current != null) {
        final items = current.occurrences
            .map((item) => item.id == occurrence.id ? result.occurrence : item)
            .toList();
        setState(() {
          _today = CareTaskAppDayData(
            date: current.date,
            occurrences: items,
            summary: _summaryFor(items, current.summary),
          );
        });
      }

      if (result.queued) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.tr('simple_care_saved_offline'))),
        );
      } else if (result.conflictRecovered) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.tr('simple_care_conflict_restored'))),
        );
      }
    } on CarePlanException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            localizedCarePlanExceptionMessage(error, context.appLanguage),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _savingIds.remove(occurrence.id));
    }
  }

  CareTaskAppDaySummary _summaryFor(
    List<CareTaskOccurrence> items,
    CareTaskAppDaySummary previous,
  ) {
    var completed = 0;
    var skipped = 0;
    var missed = 0;
    var pending = 0;
    for (final item in items) {
      if (item.completed) {
        completed += 1;
      } else if (item.skipped) {
        skipped += 1;
      } else if (item.missed) {
        missed += 1;
      } else {
        pending += 1;
      }
    }
    return CareTaskAppDaySummary(
      total: items.length,
      completed: completed,
      skipped: skipped,
      missed: missed,
      pending: pending,
      activePlans: previous.activePlans,
      openCareGaps: previous.openCareGaps,
      careReadiness: previous.careReadiness,
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _settings,
      builder: (context, _) {
        return AppShell(
          currentRoute: AppRoutes.simpleCare,
          title: context.tr('simple_care'),
          child: _simpleCareBody(),
        );
      },
    );
  }

  Widget _simpleCareBody() {
    final today = _today;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            PageHeader(
              title: context.tr('simple_care'),
              subtitle: context.tr('simple_care_subtitle'),
              action: _SimpleCareModeChip(
                enabled: _settings.simpleCareModeEnabled,
              ),
            ),
            if (_loading)
              _LoadingState(text: context.tr('simple_care_loading'))
            else if (_error != null)
              _simpleCareError()
            else if (today == null || today.occurrences.isEmpty)
              EmptyState(
                icon: Icons.checklist_outlined,
                title: context.tr('simple_care_empty_title'),
                description: context.tr('simple_care_empty_description'),
                action: FilledButton.icon(
                  onPressed: () =>
                      Navigator.pushNamed(context, AppRoutes.carePlanNew),
                  icon: const Icon(Icons.upload_outlined, size: 17),
                  label: Text(context.tr('upload_document')),
                ),
              )
            else ...[
              _todayCard(today),
              const SizedBox(height: 18),
              _restOfToday(today),
              if (_importantStatusItems(today).isNotEmpty) ...[
                const SizedBox(height: 18),
                _importantStatus(today),
              ],
              const SizedBox(height: 18),
              _yourCare(),
            ],
            const SizedBox(height: 20),
            SafetyNote(
              text: context.tr('medical_emergency_contact_professional'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _simpleCareError() {
    if (_error == '__simple_care_sign_in__') {
      return EmptyState(
        icon: Icons.lock_outline,
        title: context.tr('simple_care_sign_in_required_title'),
        description: context.tr('simple_care_sign_in_required_description'),
        action: FilledButton(
          onPressed: () => Navigator.pushNamed(context, AppRoutes.auth),
          child: Text(context.tr('sign_in')),
        ),
      );
    }

    return EmptyState(
      icon: _offline ? Icons.wifi_off_outlined : Icons.error_outline,
      title: _offline
          ? context.tr('simple_care_offline_title')
          : context.tr('simple_care_error_title'),
      description: _error!,
      action: FilledButton(
        key: const Key('simple_care_retry_button'),
        onPressed: _load,
        child: Text(context.tr('retry')),
      ),
    );
  }

  Widget _todayCard(CareTaskAppDayData today) {
    final ordered = _sortedOccurrences(today.occurrences);
    final next =
        ordered
            .where((item) => item.missed || item.overdue || item.pending)
            .firstOrNull ??
        ordered.firstOrNull;

    return AppCard(
      padding: const EdgeInsets.all(24),
      color: AppColors.primaryLight,
      borderColor: AppColors.primary,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            context.tr('simple_care_today_heading'),
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: AppColors.accentForeground,
            ),
          ),
          const SizedBox(height: 12),
          if (next == null)
            Text(
              context.tr('nothing_left_today'),
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
            )
          else
            _PrimarySimpleCareTask(
              occurrence: next,
              saving: _savingIds.contains(next.id),
              statusLabel: _statusLabelFor(next),
              onComplete: next.missed
                  ? null
                  : () => _setOutcome(next, 'completed'),
              onSkip: next.pending ? () => _setOutcome(next, 'skipped') : null,
              onOpenPlan: () => Navigator.pushNamed(
                context,
                AppRoutes.carePlan(next.carePlanId),
              ),
            ),
        ],
      ),
    );
  }

  Widget _restOfToday(CareTaskAppDayData today) {
    final ordered = _sortedOccurrences(today.occurrences);
    return AppCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.tr('rest_of_today'),
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 12),
          ...ordered.map(
            (occurrence) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _SimpleCareTaskRow(
                occurrence: occurrence,
                saving: _savingIds.contains(occurrence.id),
                statusLabel: _statusLabelFor(occurrence),
                onComplete: occurrence.missed
                    ? null
                    : () => _setOutcome(occurrence, 'completed'),
                onSkip: occurrence.pending
                    ? () => _setOutcome(occurrence, 'skipped')
                    : null,
                onUndo: occurrence.completed || occurrence.skipped
                    ? () => _setOutcome(occurrence, 'pending')
                    : null,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _importantStatus(CareTaskAppDayData today) {
    final items = _importantStatusItems(today);
    return AppCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.tr('simple_care_important_status_heading'),
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 12),
          ...items.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _SimpleStatusRow(item: item),
            ),
          ),
        ],
      ),
    );
  }

  Widget _yourCare() {
    final activePlans = _plans
        .where((plan) => plan.status == PlanStatus.active)
        .toList();
    return AppCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.tr('simple_care_your_care_heading'),
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 520;
              final links = [
                _CareLink(
                  icon: Icons.checklist_outlined,
                  label: context.tr('care_plans'),
                  onTap: () => Navigator.pushNamed(
                    context,
                    activePlans.length == 1
                        ? AppRoutes.carePlan(activePlans.single.id)
                        : AppRoutes.carePlans,
                  ),
                ),
                _CareLink(
                  icon: Icons.speed_outlined,
                  label: context.tr('progress'),
                  onTap: () => Navigator.pushNamed(context, AppRoutes.progress),
                ),
                _CareLink(
                  icon: Icons.description_outlined,
                  label: context.tr('documents'),
                  onTap: () =>
                      Navigator.pushNamed(context, AppRoutes.documents),
                ),
                _CareLink(
                  icon: Icons.record_voice_over_outlined,
                  label: context.tr('teach_back'),
                  onTap: () =>
                      Navigator.pushNamed(context, AppRoutes.teachBack),
                ),
                _CareLink(
                  icon: Icons.handshake_outlined,
                  label: context.tr('family_care'),
                  onTap: () => Navigator.pushNamed(context, AppRoutes.family),
                ),
              ];

              if (compact) {
                return Column(
                  children: links
                      .map(
                        (link) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: link,
                        ),
                      )
                      .toList(),
                );
              }

              return Wrap(
                spacing: 10,
                runSpacing: 10,
                children: links
                    .map((link) => SizedBox(width: 220, child: link))
                    .toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  List<CareTaskOccurrence> _sortedOccurrences(
    List<CareTaskOccurrence> occurrences,
  ) {
    final ordered = List<CareTaskOccurrence>.of(occurrences);
    ordered.sort((a, b) {
      final rank = _priority(a).compareTo(_priority(b));
      if (rank != 0) return rank;
      return a.scheduledTime.compareTo(b.scheduledTime);
    });
    return ordered;
  }

  int _priority(CareTaskOccurrence occurrence) {
    if (occurrence.missed) return 0;
    if (occurrence.overdue) return 1;
    if (occurrence.pending) return 2;
    if (occurrence.skipped) return 3;
    return 4;
  }

  List<_SimpleStatusItem> _importantStatusItems(CareTaskAppDayData today) {
    final overdueCount = today.occurrences.where((item) => item.overdue).length;
    final items = <_SimpleStatusItem>[];
    if (today.summary.missed > 0) {
      items.add(
        _SimpleStatusItem(
          icon: Icons.error_outline,
          color: AppColors.criticalForeground,
          title: context.tr(
            'simple_care_status_missed_title',
            values: {'count': today.summary.missed},
          ),
          description: context.tr('simple_care_status_missed_description'),
        ),
      );
    }
    if (overdueCount > 0) {
      items.add(
        _SimpleStatusItem(
          icon: Icons.schedule_outlined,
          color: AppColors.criticalForeground,
          title: context.tr(
            'simple_care_status_overdue_title',
            values: {'count': overdueCount},
          ),
          description: context.tr('simple_care_status_overdue_description'),
        ),
      );
    }
    if (today.summary.openCareGaps > 0) {
      items.add(
        _SimpleStatusItem(
          icon: Icons.report_problem_outlined,
          color: AppColors.warningForeground,
          title: context.tr(
            'simple_care_status_gaps_title',
            values: {'count': today.summary.openCareGaps},
          ),
          description: context.tr('simple_care_status_gaps_description'),
        ),
      );
    }
    if (today.summary.activePlans > 0 &&
        today.summary.careReadiness > 0 &&
        today.summary.careReadiness < 70) {
      items.add(
        _SimpleStatusItem(
          icon: Icons.health_and_safety_outlined,
          color: AppColors.warningForeground,
          title: context.tr(
            'simple_care_status_readiness_title',
            values: {'score': today.summary.careReadiness},
          ),
          description: context.tr('simple_care_status_readiness_description'),
        ),
      );
    }
    return items;
  }

  String _statusLabelFor(CareTaskOccurrence occurrence) {
    if (occurrence.overdue) return context.tr('overdue');
    return switch (occurrence.status) {
      'completed' => context.tr('completed'),
      'skipped' => context.tr('skipped'),
      'missed' => context.tr('missed'),
      _ => context.tr('upcoming'),
    };
  }
}

class _SimpleCareModeChip extends StatelessWidget {
  const _SimpleCareModeChip({required this.enabled});

  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
      decoration: BoxDecoration(
        color: enabled ? AppColors.primaryLight : AppColors.secondary,
        borderRadius: BorderRadius.circular(AppRadii.md),
        border: Border.all(
          color: enabled ? AppColors.primary : AppColors.border,
        ),
      ),
      child: Text(
        enabled
            ? context.tr('simple_care_mode_on')
            : context.tr('simple_care_mode_off'),
        style: TextStyle(
          color: enabled ? AppColors.accentForeground : AppColors.muted,
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _PrimarySimpleCareTask extends StatelessWidget {
  const _PrimarySimpleCareTask({
    required this.occurrence,
    required this.saving,
    required this.statusLabel,
    required this.onOpenPlan,
    this.onComplete,
    this.onSkip,
  });

  final CareTaskOccurrence occurrence;
  final bool saving;
  final String statusLabel;
  final VoidCallback onOpenPlan;
  final VoidCallback? onComplete;
  final VoidCallback? onSkip;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            _TaskKindChip(kind: occurrence.taskKind),
            _StatusChip(
              label: statusLabel,
              urgent: occurrence.missed || occurrence.overdue,
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          occurrence.title,
          style: const TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w800,
            height: 1.15,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          _taskMeta(context, occurrence),
          style: const TextStyle(
            fontSize: 17,
            color: AppColors.muted,
            height: 1.35,
          ),
        ),
        if (occurrence.grounding.trim().isNotEmpty) ...[
          const SizedBox(height: 10),
          Text(
            occurrence.grounding,
            style: const TextStyle(fontSize: 15, height: 1.35),
          ),
        ],
        const SizedBox(height: 20),
        if (saving)
          const LinearProgressIndicator(minHeight: 3)
        else
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              if (onComplete != null)
                FilledButton.icon(
                  onPressed: onComplete,
                  icon: const Icon(Icons.check_circle_outline, size: 19),
                  label: Text(context.tr('complete')),
                ),
              if (onSkip != null)
                OutlinedButton(
                  onPressed: onSkip,
                  child: Text(context.tr('record_skipped')),
                ),
              OutlinedButton.icon(
                onPressed: onOpenPlan,
                icon: const Icon(Icons.open_in_new, size: 17),
                label: Text(context.tr('open_care_plan')),
              ),
            ],
          ),
      ],
    );
  }
}

class _SimpleCareTaskRow extends StatelessWidget {
  const _SimpleCareTaskRow({
    required this.occurrence,
    required this.saving,
    required this.statusLabel,
    this.onComplete,
    this.onSkip,
    this.onUndo,
  });

  final CareTaskOccurrence occurrence;
  final bool saving;
  final String statusLabel;
  final VoidCallback? onComplete;
  final VoidCallback? onSkip;
  final VoidCallback? onUndo;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: Key('simple_care_task_${occurrence.id}'),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.secondary,
        borderRadius: BorderRadius.circular(AppRadii.xl),
        border: Border.all(
          color: occurrence.missed || occurrence.overdue
              ? AppColors.critical
              : AppColors.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TaskIcon(icon: _iconForTaskKind(occurrence.taskKind), size: 40),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      occurrence.title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      _taskMeta(context, occurrence),
                      style: const TextStyle(
                        color: AppColors.muted,
                        fontSize: 13,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _StatusChip(
                label: statusLabel,
                urgent: occurrence.missed || occurrence.overdue,
              ),
            ],
          ),
          if (saving) ...[
            const SizedBox(height: 10),
            const LinearProgressIndicator(minHeight: 3),
          ] else if (onComplete != null ||
              onSkip != null ||
              onUndo != null) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (onComplete != null)
                  FilledButton.icon(
                    onPressed: onComplete,
                    icon: const Icon(Icons.check_circle_outline, size: 17),
                    label: Text(context.tr('complete')),
                  ),
                if (onSkip != null)
                  OutlinedButton(
                    onPressed: onSkip,
                    child: Text(context.tr('record_skipped')),
                  ),
                if (onUndo != null)
                  TextButton.icon(
                    onPressed: onUndo,
                    icon: const Icon(Icons.undo, size: 16),
                    label: Text(context.tr('undo')),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _TaskKindChip extends StatelessWidget {
  const _TaskKindChip({required this.kind});

  final String kind;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppRadii.md),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_iconForTaskKind(kind), size: 15, color: AppColors.primary),
          const SizedBox(width: 6),
          Text(
            _taskKindLabel(context, kind),
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.label, required this.urgent});

  final String label;
  final bool urgent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: urgent
            ? AppColors.critical.withValues(alpha: .12)
            : AppColors.card,
        borderRadius: BorderRadius.circular(AppRadii.md),
        border: Border.all(
          color: urgent ? AppColors.critical : AppColors.border,
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w800,
          color: urgent ? AppColors.criticalForeground : AppColors.muted,
        ),
      ),
    );
  }
}

class _SimpleStatusItem {
  const _SimpleStatusItem({
    required this.icon,
    required this.color,
    required this.title,
    required this.description,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String description;
}

class _SimpleStatusRow extends StatelessWidget {
  const _SimpleStatusRow({required this.item});

  final _SimpleStatusItem item;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: item.color.withValues(alpha: .08),
        borderRadius: BorderRadius.circular(AppRadii.xl),
        border: Border.all(color: item.color.withValues(alpha: .34)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(item.icon, size: 21, color: item.color),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: item.color,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  item.description,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.muted,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CareLink extends StatelessWidget {
  const _CareLink({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 18),
      label: Text(label, overflow: TextOverflow.ellipsis),
    );
  }
}

IconData _iconForTaskKind(String kind) {
  final normalized = kind.trim().toLowerCase();
  if (normalized.contains('medicine') || normalized.contains('medication')) {
    return Icons.medication_outlined;
  }
  if (normalized.contains('appointment') || normalized.contains('visit')) {
    return Icons.event_available_outlined;
  }
  return Icons.checklist_outlined;
}

String _taskKindLabel(BuildContext context, String kind) {
  final normalized = kind.trim().toLowerCase();
  if (normalized.contains('medicine') || normalized.contains('medication')) {
    return context.tr('simple_care_task_kind_medicine');
  }
  if (normalized.contains('appointment') || normalized.contains('visit')) {
    return context.tr('simple_care_task_kind_appointment');
  }
  return context.tr('simple_care_task_kind_care');
}

String _taskMeta(BuildContext context, CareTaskOccurrence occurrence) {
  final parts = <String>[
    _clock(occurrence.scheduledTime),
    if (occurrence.period.trim().isNotEmpty)
      _localizedPeriod(context, occurrence.period),
    if (occurrence.planTitle.trim().isNotEmpty) occurrence.planTitle,
  ];
  return parts.where((part) => part.trim().isNotEmpty).join(' · ');
}

String _localizedPeriod(BuildContext context, String value) {
  return switch (value.trim().toLowerCase()) {
    'morning' => context.tr('morning'),
    'afternoon' => context.tr('afternoon'),
    'evening' => context.tr('evening'),
    'night' => context.tr('night'),
    _ => _titleCase(value),
  };
}

String _titleCase(String value) => value.isEmpty
    ? value
    : '${value.substring(0, 1).toUpperCase()}${value.substring(1)}';

String _clock(String value) {
  final match = RegExp(r'^(\d{1,2}):(\d{2})').firstMatch(value);
  if (match == null) return value;
  final hour = int.tryParse(match.group(1)!) ?? 0;
  final minute = match.group(2)!;
  final suffix = hour >= 12 ? 'PM' : 'AM';
  final displayHour = hour % 12 == 0 ? 12 : hour % 12;
  return '$displayHour:$minute $suffix';
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
