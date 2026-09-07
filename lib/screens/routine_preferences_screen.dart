import 'package:flutter/material.dart';

import '../core/app_routes.dart';
import '../core/app_theme.dart';
import '../localization/language_scope.dart';
import '../services/care_plan_service.dart';
import '../widgets/app_shell.dart';
import '../widgets/ui.dart';

class RoutinePreferencesScreen extends StatefulWidget {
  const RoutinePreferencesScreen({super.key});

  @override
  State<RoutinePreferencesScreen> createState() =>
      _RoutinePreferencesScreenState();
}

class _RoutinePreferencesScreenState extends State<RoutinePreferencesScreen> {
  final Map<String, TextEditingController> _controllers = {
    'morning': TextEditingController(),
    'afternoon': TextEditingController(),
    'evening': TextEditingController(),
    'night': TextEditingController(),
  };

  RoutineProfileData? _profile;
  bool _loading = true;
  bool _saving = false;
  String? _error;
  bool _learningEnabled = true;
  String _reminderStyle = 'Balanced';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final profile = await CarePlanService.instance.fetchRoutineProfile();
      if (!mounted) return;
      setState(() {
        _profile = profile;
        _learningEnabled = profile.learningEnabled;
        _reminderStyle = profile.preferredReminderStyle;
        for (final entry in _controllers.entries) {
          entry.value.text = profile.notes[entry.key] ?? '';
        }
        _loading = false;
        _error = null;
      });
    } on CarePlanException catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = error.message;
      });
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final profile = await CarePlanService.instance.updateRoutineProfile(
        learningEnabled: _learningEnabled,
        preferredReminderStyle: _reminderStyle,
        notes: {
          for (final entry in _controllers.entries)
            entry.key: entry.value.text.trim(),
        },
      );
      if (!mounted) return;
      setState(() {
        _profile = profile;
        _saving = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr('routine_save_success'))),
      );
    } on CarePlanException catch (error) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    }
  }

  Future<void> _resetLearning() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(context.tr('routine_reset_title')),
        content: Text(context.tr('routine_reset_content')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(context.tr('cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(context.tr('routine_reset_confirm')),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      final profile = await CarePlanService.instance.resetRoutineLearning();
      if (!mounted) return;
      setState(() => _profile = profile);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr('routine_reset_success'))),
      );
    } on CarePlanException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    }
  }

  String _periodTitle(String period) => switch (period) {
    'morning' => context.tr('routine_period_morning'),
    'afternoon' => context.tr('routine_period_afternoon'),
    'evening' => context.tr('routine_period_evening'),
    'night' => context.tr('routine_period_night'),
    _ => period,
  };

  String _displayTime(String value) {
    final parts = value.split(':');
    if (parts.length < 2) return value;
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null) return value;
    final suffix = hour >= 12 ? 'PM' : 'AM';
    final hour12 = hour % 12 == 0 ? 12 : hour % 12;
    return '$hour12:${minute.toString().padLeft(2, '0')} $suffix';
  }

  @override
  Widget build(BuildContext context) {
    final totalSignals = _profile?.totalSignals ?? 0;

    return AppShell(
      currentRoute: AppRoutes.routinePreferences,
      title: context.tr('routine_title'),
      child: _loading
          ? const _RoutineLoadingState()
          : _error != null
          ? _routineErrorState()
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                FadeSlideIn(child: _routineHero(totalSignals)),
                const SizedBox(height: 18),

                FadeSlideIn(
                  delay: const Duration(milliseconds: 60),
                  child: AppCard(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 38,
                              height: 38,
                              decoration: BoxDecoration(
                                color: AppColors.primaryLight,
                                borderRadius: BorderRadius.circular(
                                  AppRadii.lg,
                                ),
                              ),
                              child: const Icon(
                                Icons.tune_rounded,
                                size: 19,
                                color: AppColors.primary,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                context.tr('routine_reminder_style'),
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(AppRadii.xl),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: SwitchListTile(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 10,
                            ),
                            value: _learningEnabled,
                            onChanged: (value) {
                              setState(() => _learningEnabled = value);
                            },
                            secondary: Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: _learningEnabled
                                    ? AppColors.successSoft
                                    : const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(
                                  AppRadii.lg,
                                ),
                              ),
                              child: Icon(
                                Icons.psychology_alt_outlined,
                                size: 18,
                                color: _learningEnabled
                                    ? AppColors.successForeground
                                    : AppColors.muted,
                              ),
                            ),
                            title: Text(
                              context.tr('routine_learn_from_activity'),
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            subtitle: Text(
                              context.tr('routine_learn_subtitle'),
                              style: const TextStyle(fontSize: 10),
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        DropdownButtonFormField<String>(
                          initialValue: _reminderStyle,
                          decoration: InputDecoration(
                            prefixIcon: const Icon(
                              Icons.notifications_active_outlined,
                            ),
                            labelText: context.tr('routine_reminder_style'),
                          ),
                          items: [
                            DropdownMenuItem(
                              value: 'Gentle',
                              child: Text(context.tr('routine_style_gentle')),
                            ),
                            DropdownMenuItem(
                              value: 'Balanced',
                              child: Text(context.tr('routine_style_balanced')),
                            ),
                            DropdownMenuItem(
                              value: 'Persistent',
                              child: Text(
                                context.tr('routine_style_persistent'),
                              ),
                            ),
                          ],
                          onChanged: (value) {
                            if (value != null) {
                              setState(() => _reminderStyle = value);
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                FadeSlideIn(
                  delay: const Duration(milliseconds: 90),
                  child: Row(
                    children: [
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: AppColors.primaryLight,
                          borderRadius: BorderRadius.circular(AppRadii.lg),
                        ),
                        child: const Icon(
                          Icons.schedule_outlined,
                          size: 19,
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              context.tr('routine_your_routine'),
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              context.tr('routine_your_routine_desc'),
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppColors.muted,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                LayoutBuilder(
                  builder: (context, constraints) {
                    final periods = const [
                      'morning',
                      'afternoon',
                      'evening',
                      'night',
                    ];
                    final columns = constraints.maxWidth >= 720 ? 2 : 1;
                    const gap = 12.0;
                    final width =
                        (constraints.maxWidth - (columns - 1) * gap) / columns;

                    return Wrap(
                      spacing: gap,
                      runSpacing: gap,
                      children: periods
                          .map(
                            (period) => SizedBox(
                              width: width,
                              child: _routinePeriodCard(period),
                            ),
                          )
                          .toList(),
                    );
                  },
                ),

                const SizedBox(height: 20),

                FadeSlideIn(
                  delay: const Duration(milliseconds: 120),
                  child: AppCard(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 38,
                              height: 38,
                              decoration: BoxDecoration(
                                color: AppColors.successSoft,
                                borderRadius: BorderRadius.circular(
                                  AppRadii.lg,
                                ),
                              ),
                              child: const Icon(
                                Icons.auto_graph_rounded,
                                size: 19,
                                color: AppColors.successForeground,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                context.tr('routine_learned_from_activity'),
                                style: const TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 9,
                                vertical: 5,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.primaryLight,
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                context.tr(
                                  'routine_signals_count',
                                  values: {'count': '$totalSignals'},
                                ),
                                style: const TextStyle(
                                  fontSize: 9,
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        for (final period in const [
                          'morning',
                          'afternoon',
                          'evening',
                          'night',
                        ])
                          _learnedPeriod(period),
                        const SizedBox(height: 4),
                        OutlinedButton.icon(
                          onPressed: _resetLearning,
                          icon: const Icon(Icons.restart_alt_rounded, size: 18),
                          label: Text(context.tr('routine_reset_learned')),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 16),
                SafetyNote(text: context.tr('routine_safety_note')),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _saving ? null : _save,
                    icon: _saving
                        ? const SizedBox.square(
                            dimension: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.save_outlined, size: 18),
                    label: Text(
                      _saving
                          ? context.tr('routine_saving')
                          : context.tr('routine_save_preferences'),
                    ),
                  ),
                ),
                const SizedBox(height: 28),
              ],
            ),
    );
  }

  Widget _routineHero(int totalSignals) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0F766E), Color(0xFF0D9488), Color(0xFF14B8A6)],
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
            top: -72,
            end: -54,
            child: Container(
              width: 180,
              height: 180,
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
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(0x20FFFFFF),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.psychology_alt_outlined,
                      size: 14,
                      color: Colors.white,
                    ),
                    SizedBox(width: 6),
                    Text(
                      'Routine intelligence',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Text(
                context.tr('routine_title'),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 27,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                context.tr('routine_subtitle'),
                style: const TextStyle(
                  color: Color(0xE6FFFFFF),
                  fontSize: 12,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _routineHeroChip(
                    _learningEnabled
                        ? Icons.school_outlined
                        : Icons.pause_circle_outline_rounded,
                    _learningEnabled ? 'Learning on' : 'Learning off',
                  ),
                  _routineHeroChip(
                    Icons.notifications_outlined,
                    _reminderStyle,
                  ),
                  _routineHeroChip(
                    Icons.query_stats_outlined,
                    '$totalSignals signals',
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _routineHeroChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0x1FFFFFFF),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0x20FFFFFF)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: Colors.white),
          const SizedBox(width: 5),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _routinePeriodCard(String period) {
    final icon = switch (period) {
      'morning' => Icons.wb_sunny_outlined,
      'afternoon' => Icons.light_mode_outlined,
      'evening' => Icons.nights_stay_outlined,
      _ => Icons.bedtime_outlined,
    };

    final hint = switch (period) {
      'morning' => context.tr('routine_hint_morning'),
      'afternoon' => context.tr('routine_hint_afternoon'),
      'evening' => context.tr('routine_hint_evening'),
      _ => context.tr('routine_hint_night'),
    };

    return HoverLift(
      child: AppCard(
        padding: const EdgeInsets.all(15),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: AppColors.primaryLight,
                    borderRadius: BorderRadius.circular(AppRadii.lg),
                  ),
                  child: Icon(icon, size: 18, color: AppColors.primary),
                ),
                const SizedBox(width: 9),
                Text(
                  _periodTitle(period),
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 11),
            TextField(
              controller: _controllers[period],
              minLines: 2,
              maxLines: 3,
              decoration: InputDecoration(hintText: hint),
            ),
          ],
        ),
      ),
    );
  }

  Widget _routineErrorState() {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 540),
        child: AppCard(
          padding: const EdgeInsets.all(22),
          color: const Color(0xFFFFFBEB),
          borderColor: const Color(0xFFFDE68A),
          child: Column(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: AppColors.warningSoft,
                  borderRadius: BorderRadius.circular(AppRadii.xl),
                ),
                child: const Icon(
                  Icons.wifi_off_outlined,
                  color: AppColors.warningForeground,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.muted,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 14),
              FilledButton.icon(
                onPressed: _load,
                icon: const Icon(Icons.refresh_rounded, size: 17),
                label: Text(context.tr('retry')),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _learnedPeriod(String period) {
    final learned = _profile?.learned[period];
    final preferredTime = learned?.preferredTime ?? '';
    final hasPattern = preferredTime.isNotEmpty;

    return Container(
      margin: const EdgeInsets.only(bottom: 9),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: hasPattern ? const Color(0xFFF0FDFA) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(AppRadii.lg),
        border: Border.all(
          color: hasPattern
              ? AppColors.primary.withValues(alpha: .16)
              : AppColors.border,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: hasPattern
                  ? AppColors.primaryLight
                  : const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(AppRadii.lg),
            ),
            child: Icon(
              hasPattern
                  ? Icons.auto_awesome_outlined
                  : Icons.hourglass_empty_rounded,
              size: 17,
              color: hasPattern ? AppColors.primary : AppColors.muted,
            ),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _periodTitle(period),
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  preferredTime.isEmpty
                      ? learned?.confidence ??
                            context.tr('routine_no_pattern_yet')
                      : '${_displayTime(preferredTime)} · ${learned?.confidence ?? ''}',
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.muted,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if ((learned?.reason ?? '').isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    learned!.reason,
                    style: const TextStyle(
                      fontSize: 10,
                      color: AppColors.subtle,
                      height: 1.35,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RoutineLoadingState extends StatelessWidget {
  const _RoutineLoadingState();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          height: 165,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFE4F4F1), Color(0xFFF4F8F7)],
            ),
            borderRadius: BorderRadius.circular(28),
          ),
        ),
        const SizedBox(height: 14),
        AppCard(
          padding: const EdgeInsets.all(18),
          child: Column(
            children: [
              Container(
                height: 14,
                width: 180,
                decoration: BoxDecoration(
                  color: const Color(0xFFE8EEF2),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              const SizedBox(height: 12),
              Container(
                height: 10,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: const Color(0xFFE8EEF2),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              const SizedBox(height: 18),
              const CircularProgressIndicator(),
            ],
          ),
        ),
      ],
    );
  }
}
