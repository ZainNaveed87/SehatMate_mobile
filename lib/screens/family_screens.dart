import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/app_routes.dart';
import '../core/app_theme.dart';
import '../data/demo_data.dart';
import '../localization/language_scope.dart';
import '../widgets/app_shell.dart';
import '../widgets/page_header.dart';
import '../widgets/ui.dart';

class FamilyScreen extends StatelessWidget {
  const FamilyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = CareDemoState.instance;
    return AnimatedBuilder(
      animation: state,
      builder: (context, _) => AppShell(
        currentRoute: AppRoutes.family,
        title: context.tr('family_and_caregivers'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            PageHeader(
              title: context.tr('family_and_caregivers'),
              subtitle: context.tr('family_caregivers_subtitle'),
              action: FilledButton.icon(onPressed: () => Navigator.pushNamed(context, AppRoutes.familyNew), icon: const Icon(Icons.person_add_alt_1_outlined, size: 18), label: Text(context.tr('add_caregiver'))),
            ),
            if (state.caregivers.isEmpty)
              EmptyState(icon: Icons.group_outlined, title: context.tr('no_caregivers_yet'), description: context.tr('no_caregivers_yet_description'))
            else
              LayoutBuilder(
                builder: (context, constraints) {
                  final columns = constraints.maxWidth >= 720 ? 2 : 1;
                  return GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: state.caregivers.length,
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: columns, crossAxisSpacing: 16, mainAxisSpacing: 16, childAspectRatio: columns == 1 ? 1.55 : 1.25),
                    itemBuilder: (context, index) {
                      final caregiver = state.caregivers[index];
                      final assigned = state.tasks.where((task) => caregiver.taskIds.contains(task.id) || task.caregiverId == caregiver.id).length;
                      final helpsWith = caregiver.helpsWith.isEmpty ? context.tr('not_set') : caregiver.helpsWith.map((item) => caregiverOptionLabel(item, context.appLanguage)).join(', ');
                      return FadeSlideIn(
                        child: AppCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(children: [CircleAvatar(radius: 22, backgroundColor: AppColors.primaryLight, child: Text(caregiver.name.substring(0, 1), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.accentForeground))), const SizedBox(width: 12), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(caregiver.name, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600)), Text(caregiver.relationship, style: const TextStyle(fontSize: 14, color: AppColors.muted))]))]),
                              const SizedBox(height: 16),
                              _line(context.tr('available'), caregiver.availability),
                              _line(context.tr('helps_with'), helpsWith),
                              _line(context.tr('assigned_tasks'), '$assigned'),
                              const Spacer(),
                              Wrap(spacing: 8, runSpacing: 8, children: [
                                FilledButton(onPressed: () => Navigator.pushNamed(context, AppRoutes.caregiver(caregiver.id)), child: Text(context.tr('open_caregiver_view'))),
                                OutlinedButton.icon(onPressed: () => _callCaregiver(context, caregiver.phone), icon: const Icon(Icons.phone_outlined, size: 17), label: Text(context.tr('call'))),
                              ]),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            const SizedBox(height: 24),
            SafetyNote(text: context.tr('family_caregivers_safety_note')),
          ],
        ),
      ),
    );
  }

  Widget _line(String label, String value) => Padding(
        padding: const EdgeInsets.only(bottom: 7),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [SizedBox(width: 112, child: Text(label, style: const TextStyle(fontSize: 14, color: AppColors.muted))), Expanded(child: Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)))]),
      );
}

class AddCaregiverScreen extends StatefulWidget {
  const AddCaregiverScreen({super.key});

  @override
  State<AddCaregiverScreen> createState() => _AddCaregiverScreenState();
}

class _AddCaregiverScreenState extends State<AddCaregiverScreen> {
  final name = TextEditingController();
  final relationship = TextEditingController();
  final phone = TextEditingController();
  final availability = TextEditingController();
  final helpsWith = <String>{'Medicine reminders'};
  final access = <String>{'Assigned tasks only'};
  final formKey = GlobalKey<FormState>();

  static const helpOptions = ['Medicine reminders', 'Dressing', 'Travel', 'Appointments', 'Meals'];
  static const accessOptions = ['Assigned tasks only', 'Schedule', 'Care gaps', 'Documents'];

  @override
  void dispose() {
    name.dispose();
    relationship.dispose();
    phone.dispose();
    availability.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AppShell(
        currentRoute: AppRoutes.familyNew,
        title: context.tr('add_caregiver'),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 620),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextButton.icon(onPressed: () => Navigator.pushReplacementNamed(context, AppRoutes.family), icon: const Icon(Icons.arrow_back, size: 18), label: Text(context.tr('family'))),
                PageHeader(title: context.tr('add_a_caregiver'), subtitle: context.tr('add_caregiver_subtitle')),
                AppCard(
                  padding: const EdgeInsets.all(24),
                  child: Form(
                    key: formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        LayoutBuilder(builder: (context, constraints) {
                          final fields = [
                            fieldLabel(context.tr('name'), TextFormField(controller: name, decoration: const InputDecoration(hintText: 'Ahmed Khan'), validator: (value) => _required(context, value))),
                            fieldLabel(context.tr('relationship'), TextFormField(controller: relationship, decoration: InputDecoration(hintText: context.tr('son')), validator: (value) => _required(context, value))),
                            fieldLabel(context.tr('phone_number'), TextFormField(controller: phone, keyboardType: TextInputType.phone, decoration: const InputDecoration(hintText: '+92 300 1234567'), validator: (value) => _required(context, value))),
                            fieldLabel(context.tr('availability'), TextFormField(controller: availability, decoration: const InputDecoration(hintText: '6 PM – 10 PM'), validator: (value) => _required(context, value))),
                          ];
                          if (constraints.maxWidth < 520) return Column(children: fields.map((field) => Padding(padding: const EdgeInsets.only(bottom: 14), child: field)).toList());
                          return Wrap(spacing: 16, runSpacing: 14, children: fields.map((field) => SizedBox(width: (constraints.maxWidth - 16) / 2, child: field)).toList());
                        }),
                        const SizedBox(height: 20),
                        Text(context.tr('helps_with'), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 8),
                        _checks(context, helpOptions, helpsWith),
                        const SizedBox(height: 20),
                        Text(context.tr('access_permissions'), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 8),
                        _checks(context, accessOptions, access),
                        const SizedBox(height: 24),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton(
                            onPressed: () {
                              if (!(formKey.currentState?.validate() ?? false)) return;
                              CareDemoState.instance.addCaregiver(name: name.text.trim(), relationship: relationship.text.trim(), phone: phone.text.trim(), availability: availability.text.trim(), helpsWith: helpsWith.toList(), access: access.toList());
                              showDemoMessage(context, context.tr('caregiver_added'));
                              Navigator.pushReplacementNamed(context, AppRoutes.family);
                            },
                            child: Text(context.tr('add_caregiver')),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                SafetyNote(text: context.tr('caregiver_access_safety_note')),
              ],
            ),
          ),
        ),
      );

  Widget _checks(BuildContext context, List<String> options, Set<String> selected) => Wrap(
        spacing: 12,
        runSpacing: 6,
        children: options.map((option) => InkWell(onTap: () => setState(() => selected.contains(option) ? selected.remove(option) : selected.add(option)), child: Row(mainAxisSize: MainAxisSize.min, children: [Checkbox(value: selected.contains(option), onChanged: (_) => setState(() => selected.contains(option) ? selected.remove(option) : selected.add(option))), Text(caregiverOptionLabel(option, context.appLanguage), style: const TextStyle(fontSize: 14))]))).toList(),
      );

  static String? _required(BuildContext context, String? value) => value == null || value.trim().isEmpty ? context.tr('required_field') : null;
}

class CaregiverDetailScreen extends StatelessWidget {
  const CaregiverDetailScreen({required this.caregiverId, super.key});
  final String caregiverId;

  @override
  Widget build(BuildContext context) {
    final state = CareDemoState.instance;
    return AnimatedBuilder(
      animation: state,
      builder: (context, _) {
        final caregiver = state.caregivers.where((item) => item.id == caregiverId).firstOrNull;
        if (caregiver == null) {
          return AppShell(currentRoute: AppRoutes.family, title: context.tr('caregiver'), child: EmptyState(title: context.tr('caregiver_not_found'), description: context.tr('caregiver_not_found_description'), action: FilledButton(onPressed: () => Navigator.pushReplacementNamed(context, AppRoutes.family), child: Text(context.tr('back_to_family')))));
        }
        final assigned = state.tasks.where((task) => caregiver.taskIds.contains(task.id) || task.caregiverId == caregiver.id).toList();
        return AppShell(
          currentRoute: AppRoutes.caregiver(caregiverId),
          title: context.tr('caregiver_view'),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 680),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextButton.icon(onPressed: () => Navigator.pushReplacementNamed(context, AppRoutes.family), icon: const Icon(Icons.arrow_back, size: 18), label: Text(context.tr('family'))),
                  PageHeader(
                    title: context.tr('caregiver_tasks_title', values: {'name': caregiver.name}),
                    subtitle: context.tr('caregiver_available_subtitle', values: {'relationship': caregiver.relationship, 'availability': caregiver.availability}),
                    action: OutlinedButton.icon(onPressed: () => _callCaregiver(context, caregiver.phone), icon: const Icon(Icons.phone_outlined, size: 17), label: Text(context.tr('call'))),
                  ),
                  if (assigned.isEmpty)
                    EmptyState(title: context.tr('no_tasks_assigned_yet'), description: context.tr('no_tasks_assigned_yet_description'), action: FilledButton(onPressed: () => Navigator.pushReplacementNamed(context, AppRoutes.careGaps), child: Text(context.tr('view_care_gaps'))))
                  else
                    ...assigned.map((task) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: AnimatedOpacity(
                            opacity: task.completed ? .6 : 1,
                            duration: const Duration(milliseconds: 180),
                            child: AppCard(
                              child: Row(
                                children: [
                                  TaskIcon(icon: task.icon, size: 40),
                                  const SizedBox(width: 14),
                                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(demoTaskTitle(task, context.appLanguage), style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600)), Text('${task.time} · ${demoTaskNote(task, context.appLanguage)}', style: const TextStyle(fontSize: 15, color: AppColors.muted))])),
                                  FilledButton.icon(onPressed: () { state.toggleTask(task.id); showDemoMessage(context, context.tr('task_updated')); }, icon: const Icon(Icons.check, size: 17), label: Text(task.completed ? context.tr('done') : context.tr('mark_as_done'))),
                                ],
                              ),
                            ),
                          ),
                        )),
                  const SizedBox(height: 12),
                  SafetyNote(text: context.tr('caregiver_detail_safety_note')),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

Future<void> _callCaregiver(BuildContext context, String phone) async {
  final uri = Uri(scheme: 'tel', path: phone.replaceAll(' ', ''));
  if (!await launchUrl(uri)) {
    if (context.mounted) showDemoMessage(context, context.tr('call_phone', values: {'phone': phone}));
  }
}
