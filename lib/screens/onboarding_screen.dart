import 'package:flutter/material.dart';

import '../core/app_routes.dart';
import '../core/app_theme.dart';
import '../data/demo_data.dart';
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
                          Text('Step $step of 4', style: const TextStyle(fontSize: 13, color: AppColors.muted)),
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
                                  label: const Text('Back'),
                                ),
                                const Spacer(),
                                FilledButton.icon(
                                  onPressed: _submitting ? null : _next,
                                  iconAlignment: IconAlignment.end,
                                  icon: step < 4 ? const Icon(Icons.arrow_forward, size: 17) : const SizedBox.shrink(),
                                  label: Text(step < 4 ? 'Continue' : 'Go to Dashboard'),
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
            const _StepHeading(
              title: 'Who are you using SehatMate for?',
              subtitle: 'This helps us decide how much detail to show.',
            ),
            const SizedBox(height: 20),
            OptionCard(
              label: 'Myself',
              description: 'I am the patient following the care plan.',
              selected: who == 'Myself',
              onTap: () => setState(() => who = 'Myself'),
            ),
            const SizedBox(height: 12),
            OptionCard(
              label: 'Someone I care for',
              description: 'I am a family member or caregiver.',
              selected: who == 'Someone I care for',
              onTap: () => setState(() => who = 'Someone I care for'),
            ),
          ],
        );
      case 2:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _StepHeading(
              title: 'Preferred language',
              subtitle: 'You can change this later in Settings.',
            ),
            const SizedBox(height: 20),
            ...['English', 'Urdu', 'Roman Urdu'].map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: OptionCard(
                  label: item,
                  selected: language == item,
                  onTap: () {
                    setState(() => language = item);
                    CareDemoState.instance.updatePreferences(language: item);
                  },
                ),
              ),
            ),
          ],
        );
      case 3:
        const options = [
          ('Standard', 'Normal text and full interface.'),
          ('Large Text', 'Bigger text across the whole app.'),
          ('Voice Guidance', 'Listen buttons on care tasks.'),
          ('Simple Care Mode', 'One task at a time, very large buttons.'),
        ];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _StepHeading(
              title: 'Accessibility',
              subtitle: 'Choose how comfortable the interface should be to read and use.',
            ),
            const SizedBox(height: 20),
            ...options.map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: OptionCard(
                  label: item.$1,
                  description: item.$2,
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
            const _StepHeading(
              title: 'Basic setup',
              subtitle: 'A few details to personalise the plan.',
            ),
            const SizedBox(height: 20),
            const Text('Patient name', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
            const SizedBox(height: 6),
            TextField(controller: name),
            const SizedBox(height: 16),
            const Text('Age group', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
            const SizedBox(height: 6),
            DropdownButtonFormField<String>(
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
                if (value != null) setState(() => ageGroup = value);
              },
            ),
            const SizedBox(height: 16),
            const Text('City', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
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
                  title: const Text('Caregiver support available', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
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
        const SnackBar(content: Text('Enter a valid patient name.')),
      );
      return;
    }
    if (city.text.trim().length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid city.')),
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
        const SnackBar(
          content: Text('Onboarding could not be saved. Please try again.'),
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
