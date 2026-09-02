import 'package:flutter/material.dart';

import '../core/app_routes.dart';
import '../core/app_theme.dart';
import '../services/care_plan_service.dart';
import '../widgets/app_shell.dart';
import '../widgets/page_header.dart';
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
        const SnackBar(content: Text('Routine preferences saved.')),
      );
    } on CarePlanException catch (error) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message)),
      );
    }
  }

  Future<void> _resetLearning() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Reset learned routine?'),
        content: const Text(
          'This removes activity-based learning such as accepted suggestions and timing choices. Your manually written routine notes stay saved.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Reset learning'),
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
        const SnackBar(content: Text('Learned routine history reset.')),
      );
    } on CarePlanException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message)),
      );
    }
  }

  String _periodTitle(String period) => switch (period) {
        'morning' => 'Morning',
        'afternoon' => 'Afternoon',
        'evening' => 'Evening',
        'night' => 'Night',
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
    return AppShell(
      currentRoute: AppRoutes.routinePreferences,
      title: 'My Routine & Preferences',
      child: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_error!, textAlign: TextAlign.center),
                      const SizedBox(height: 12),
                      FilledButton(
                        onPressed: _load,
                        child: const Text('Try again'),
                      ),
                    ],
                  ),
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const PageHeader(
                      title: 'My Routine & Preferences',
                      subtitle:
                          'Tell SehatMate what usually works for you and control what it learns from your activity.',
                    ),
                    AppCard(
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            value: _learningEnabled,
                            onChanged: (value) {
                              setState(() => _learningEnabled = value);
                            },
                            title: const Text(
                              'Learn from my activity',
                              style: TextStyle(fontWeight: FontWeight.w700),
                            ),
                            subtitle: const Text(
                              'Accepted or rejected suggestions, schedule edits and Reality Check answers can improve future reminder suggestions.',
                            ),
                          ),
                          const Divider(),
                          const SizedBox(height: 8),
                          const Text(
                            'Preferred reminder style',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 8),
                          DropdownButtonFormField<String>(
                            initialValue: _reminderStyle,
                            items: const [
                              DropdownMenuItem(
                                value: 'Gentle',
                                child: Text('Gentle'),
                              ),
                              DropdownMenuItem(
                                value: 'Balanced',
                                child: Text('Balanced'),
                              ),
                              DropdownMenuItem(
                                value: 'Persistent',
                                child: Text('Persistent'),
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
                    const SizedBox(height: 16),
                    const Text(
                      'Your routine',
                      style: TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'These are explicit preferences you control. You can write a time, a range, or a short routine note.',
                      style: TextStyle(color: AppColors.muted),
                    ),
                    const SizedBox(height: 12),
                    for (final period
                        in const ['morning', 'afternoon', 'evening', 'night'])
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: AppCard(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                _periodTitle(period),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 8),
                              TextField(
                                controller: _controllers[period],
                                minLines: 2,
                                maxLines: 3,
                                decoration: InputDecoration(
                                  hintText: switch (period) {
                                    'morning' =>
                                      'Example: Usually free after 9:30 AM',
                                    'afternoon' =>
                                      'Example: Work is flexible after 2 PM',
                                    'evening' =>
                                      'Example: Dinner time changes',
                                    _ =>
                                      'Example: Prefer reminders around 10:30 PM',
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    const SizedBox(height: 8),
                    AppCard(
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              const Expanded(
                                child: Text(
                                  'Learned from your activity',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              Text(
                                '${_profile?.totalSignals ?? 0} signals',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.muted,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          for (final period
                              in const ['morning', 'afternoon', 'evening', 'night'])
                            _learnedPeriod(period),
                          const SizedBox(height: 8),
                          OutlinedButton.icon(
                            onPressed: _resetLearning,
                            icon: const Icon(Icons.restart_alt, size: 18),
                            label: const Text('Reset learned routine'),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    const SafetyNote(
                      text:
                          'Medical instructions are separate from routine learning. SehatMate may suggest a reminder that fits your routine, but it will not automatically move an explicit clinician-specified time.',
                    ),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: _saving ? null : _save,
                      icon: _saving
                          ? const SizedBox.square(
                              dimension: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.save_outlined, size: 18),
                      label: Text(
                        _saving ? 'Saving…' : 'Save preferences',
                      ),
                    ),
                    const SizedBox(height: 28),
                  ],
                ),
    );
  }

  Widget _learnedPeriod(String period) {
    final learned = _profile?.learned[period];
    final preferredTime = learned?.preferredTime ?? '';
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.secondary,
          borderRadius: BorderRadius.circular(AppRadii.lg),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.psychology_alt_outlined,
              color: AppColors.primary,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _periodTitle(period),
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    preferredTime.isEmpty
                        ? learned?.confidence ?? 'No pattern yet'
                        : '${_displayTime(preferredTime)} · ${learned?.confidence ?? ''}',
                  ),
                  if ((learned?.reason ?? '').isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(
                      learned!.reason,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.muted,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
