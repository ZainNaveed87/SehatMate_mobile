import 'package:flutter/material.dart';

import '../core/app_routes.dart';
import '../core/app_theme.dart';
import '../data/demo_data.dart';
import '../localization/language_scope.dart';
import '../services/auth_service.dart';
import '../widgets/brand_logo.dart';
import '../widgets/ui.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  int step = 1;
  String who = 'Myself';
  String language = 'Roman Urdu';
  String access = 'Standard';
  bool caregiver = true;
  bool _submitting = false;
  late final TextEditingController name;
  String ageGroup = '60 – 70';
  final city = TextEditingController(text: 'Karachi');

  @override
  void initState() {
    super.initState();
    name = TextEditingController(text: AuthSession.instance.user?.name ?? 'Ali Khan');
  }

  @override
  void dispose() {
    name.dispose();
    city.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 64),
                child: Column(
                  children: [
                    SizedBox(
                      height: 72,
                      child: Row(
                        children: [
                          InkWell(
                            onTap: () => Navigator.pushReplacementNamed(context, AppRoutes.landing),
                            child: const BrandLogo(),
                          ),
                          const Spacer(),
                          Text(
                            context.tr(
                              'onboarding_step_of_total',
                              values: {'step': step, 'total': 4},
                            ),
                            style: const TextStyle(fontSize: 13, color: AppColors.muted),
                          ),
                        ],
                      ),
                    ),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(99),
                      child: LinearProgressIndicator(
                        value: step / 4,
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
                                  onPressed: _back,
                                  icon: const Icon(Icons.arrow_back, size: 17),
                                  label: Text(context.tr('back')),
                                ),
                                const Spacer(),
                                FilledButton.icon(
                                  onPressed: _submitting ? null : _next,
                                  iconAlignment: IconAlignment.end,
                                  icon: step < 4 ? const Icon(Icons.arrow_forward, size: 17) : const SizedBox.shrink(),
                                  label: Text(step < 4 ? context.tr('continue') : context.tr('go_to_dashboard')),
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
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _StepHeading(
              title: context.tr('onboarding_who_title'),
              subtitle: context.tr('onboarding_who_subtitle'),
            ),
            const SizedBox(height: 20),
            OptionCard(
              label: context.tr('onboarding_myself'),
              description: context.tr('onboarding_myself_description'),
              selected: who == 'Myself',
              onTap: () => setState(() => who = 'Myself'),
            ),
            const SizedBox(height: 12),
            OptionCard(
              label: context.tr('onboarding_someone_i_care_for'),
              description: context.tr('onboarding_someone_description'),
              selected: who == 'Someone I care for',
              onTap: () => setState(() => who = 'Someone I care for'),
            ),
          ],
        );
      case 2:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _StepHeading(
              title: context.tr('preferred_language'),
              subtitle: context.tr('language_change_later_settings'),
            ),
            const SizedBox(height: 20),
            ...['English', 'Urdu', 'Roman Urdu'].map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: OptionCard(
                  label: demoLanguageLabel(item),
                  selected: language == item,
                  onTap: () async {
                    setState(() => language = item);
                    CareDemoState.instance.updatePreferences(language: item);
                    await LanguageScope.read(context).setFromStorageValue(item);
                  },
                ),
              ),
            ),
          ],
        );
      case 3:
        const options = [
          ('Standard', 'standard', 'standard_accessibility_description'),
          ('Large Text', 'large_text', 'large_text_description'),
          ('Voice Guidance', 'voice_guidance', 'voice_guidance_description'),
          ('Simple Care Mode', 'simple_care_mode', 'simple_care_mode_description'),
        ];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _StepHeading(
              title: context.tr('accessibility'),
              subtitle: context.tr('accessibility_subtitle'),
            ),
            const SizedBox(height: 20),
            ...options.map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: OptionCard(
                  label: context.tr(item.$2),
                  description: context.tr(item.$3),
                  selected: access == item.$1,
                  onTap: () {
                    setState(() => access = item.$1);
                    CareDemoState.instance.updatePreferences(
                      largeText: item.$1 == 'Large Text',
                      voiceGuidance: item.$1 == 'Voice Guidance',
                      simpleCareMode: item.$1 == 'Simple Care Mode',
                    );
                  },
                ),
              ),
            ),
          ],
        );
      default:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _StepHeading(
              title: context.tr('basic_setup'),
              subtitle: context.tr('basic_setup_subtitle'),
            ),
            const SizedBox(height: 20),
            Text(context.tr('patient_name'), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
            const SizedBox(height: 6),
            TextField(controller: name),
            const SizedBox(height: 16),
            Text(context.tr('age_group'), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
            const SizedBox(height: 6),
            DropdownButtonFormField<String>(
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
                if (value != null) setState(() => ageGroup = value);
              },
            ),
            const SizedBox(height: 16),
            Text(context.tr('city'), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
            const SizedBox(height: 6),
            TextField(controller: city),
            const SizedBox(height: 16),
            Material(
              color: AppColors.card,
              shape: RoundedRectangleBorder(
                side: const BorderSide(color: AppColors.border),
                borderRadius: BorderRadius.circular(AppRadii.xl),
              ),
              clipBehavior: Clip.antiAlias,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                child: SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: caregiver,
                  onChanged: (value) => setState(() => caregiver = value),
                  title: Text(context.tr('caregiver_support_available'), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                ),
              ),
            ),
          ],
        );
    }
  }

  void _back() {
    if (step == 1) {
      Navigator.pushReplacementNamed(context, AppRoutes.auth);
    } else {
      setState(() => step--);
    }
  }

  Future<void> _next() async {
    if (step < 4) {
      setState(() => step++);
      return;
    }

    if (name.text.trim().length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr('enter_valid_patient_name'))),
      );
      return;
    }
    if (city.text.trim().length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr('enter_valid_city'))),
      );
      return;
    }

    setState(() => _submitting = true);
    try {
      await AuthSession.instance.completeOnboarding(
        usingFor: who,
        patientName: name.text,
        ageGroup: ageGroup,
        city: city.text,
        preferredLanguage: language,
        accessibilityMode: access,
        caregiverSupport: caregiver,
      );
      if (!mounted) return;
      Navigator.pushNamedAndRemoveUntil(
        context,
        AppRoutes.dashboard,
        (_) => false,
      );
    } on AuthException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message)),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.tr('onboarding_save_failed')),
        ),
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
          Text(title, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(subtitle, style: const TextStyle(color: AppColors.muted)),
        ],
      );
}
