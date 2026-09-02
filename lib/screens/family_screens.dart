import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/app_routes.dart';
import '../core/app_theme.dart';
import '../data/demo_data.dart';
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
        title: 'Family & Caregivers',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            PageHeader(
              title: 'Family & Caregivers',
              subtitle: 'People helping with this care plan.',
              action: FilledButton.icon(onPressed: () => Navigator.pushNamed(context, AppRoutes.familyNew), icon: const Icon(Icons.person_add_alt_1_outlined, size: 18), label: const Text('Add Caregiver')),
            ),
            if (state.caregivers.isEmpty)
              const EmptyState(icon: Icons.group_outlined, title: 'No caregivers yet', description: 'Add a family member so care tasks can be shared.')
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
                      return FadeSlideIn(
                        child: AppCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(children: [CircleAvatar(radius: 22, backgroundColor: AppColors.primaryLight, child: Text(caregiver.name.substring(0, 1), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.accentForeground))), const SizedBox(width: 12), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(caregiver.name, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600)), Text(caregiver.relationship, style: const TextStyle(fontSize: 14, color: AppColors.muted))]))]),
                              const SizedBox(height: 16),
                              _line('Available', caregiver.availability),
                              _line('Helps with', caregiver.helpsWith.isEmpty ? 'Not set' : caregiver.helpsWith.join(', ')),
                              _line('Assigned tasks', '$assigned'),
                              const Spacer(),
                              Wrap(spacing: 8, runSpacing: 8, children: [
                                FilledButton(onPressed: () => Navigator.pushNamed(context, AppRoutes.caregiver(caregiver.id)), child: const Text('Open caregiver view')),
                                OutlinedButton.icon(onPressed: () => _callCaregiver(context, caregiver.phone), icon: const Icon(Icons.phone_outlined, size: 17), label: const Text('Call')),
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
            const SafetyNote(text: 'Caregivers only see the tasks assigned to them. Medical details stay with the patient account.'),
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
        title: 'Add Caregiver',
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 620),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextButton.icon(onPressed: () => Navigator.pushReplacementNamed(context, AppRoutes.family), icon: const Icon(Icons.arrow_back, size: 18), label: const Text('Family')),
                const PageHeader(title: 'Add a caregiver', subtitle: 'They will only see what you allow.'),
                AppCard(
                  padding: const EdgeInsets.all(24),
                  child: Form(
                    key: formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        LayoutBuilder(builder: (context, constraints) {
                          final fields = [
                            fieldLabel('Name', TextFormField(controller: name, decoration: const InputDecoration(hintText: 'Ahmed Khan'), validator: _required)),
                            fieldLabel('Relationship', TextFormField(controller: relationship, decoration: const InputDecoration(hintText: 'Son'), validator: _required)),
                            fieldLabel('Phone number', TextFormField(controller: phone, keyboardType: TextInputType.phone, decoration: const InputDecoration(hintText: '+92 300 1234567'), validator: _required)),
                            fieldLabel('Availability', TextFormField(controller: availability, decoration: const InputDecoration(hintText: '6 PM – 10 PM'), validator: _required)),
                          ];
                          if (constraints.maxWidth < 520) return Column(children: fields.map((field) => Padding(padding: const EdgeInsets.only(bottom: 14), child: field)).toList());
                          return Wrap(spacing: 16, runSpacing: 14, children: fields.map((field) => SizedBox(width: (constraints.maxWidth - 16) / 2, child: field)).toList());
                        }),
                        const SizedBox(height: 20),
                        const Text('Helps with', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 8),
                        _checks(helpOptions, helpsWith),
                        const SizedBox(height: 20),
                        const Text('Access permissions', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 8),
                        _checks(accessOptions, access),
                        const SizedBox(height: 24),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton(
                            onPressed: () {
                              if (!(formKey.currentState?.validate() ?? false)) return;
                              CareDemoState.instance.addCaregiver(name: name.text.trim(), relationship: relationship.text.trim(), phone: phone.text.trim(), availability: availability.text.trim(), helpsWith: helpsWith.toList(), access: access.toList());
                              showDemoMessage(context, 'Caregiver added');
                              Navigator.pushReplacementNamed(context, AppRoutes.family);
                            },
                            child: const Text('Add caregiver'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                const SafetyNote(text: 'Caregiver access can be changed or removed at any time from the family page.'),
              ],
            ),
          ),
        ),
      );

  Widget _checks(List<String> options, Set<String> selected) => Wrap(
        spacing: 12,
        runSpacing: 6,
        children: options.map((option) => InkWell(onTap: () => setState(() => selected.contains(option) ? selected.remove(option) : selected.add(option)), child: Row(mainAxisSize: MainAxisSize.min, children: [Checkbox(value: selected.contains(option), onChanged: (_) => setState(() => selected.contains(option) ? selected.remove(option) : selected.add(option))), Text(option, style: const TextStyle(fontSize: 14))]))).toList(),
      );

  static String? _required(String? value) => value == null || value.trim().isEmpty ? 'Required' : null;
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
          return AppShell(currentRoute: AppRoutes.family, title: 'Caregiver', child: EmptyState(title: 'Caregiver not found', description: 'This caregiver has been removed.', action: FilledButton(onPressed: () => Navigator.pushReplacementNamed(context, AppRoutes.family), child: const Text('Back to Family'))));
        }
        final assigned = state.tasks.where((task) => caregiver.taskIds.contains(task.id) || task.caregiverId == caregiver.id).toList();
        return AppShell(
          currentRoute: AppRoutes.caregiver(caregiverId),
          title: 'Caregiver View',
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 680),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextButton.icon(onPressed: () => Navigator.pushReplacementNamed(context, AppRoutes.family), icon: const Icon(Icons.arrow_back, size: 18), label: const Text('Family')),
                  PageHeader(
                    title: "${caregiver.name}'s tasks",
                    subtitle: '${caregiver.relationship} · Available ${caregiver.availability}',
                    action: OutlinedButton.icon(onPressed: () => _callCaregiver(context, caregiver.phone), icon: const Icon(Icons.phone_outlined, size: 17), label: const Text('Call')),
                  ),
                  if (assigned.isEmpty)
                    EmptyState(title: 'No tasks assigned yet', description: 'Assign a care task from the care gaps or schedule.', action: FilledButton(onPressed: () => Navigator.pushReplacementNamed(context, AppRoutes.careGaps), child: const Text('View Care Gaps')))
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
                                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(task.title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600)), Text('${task.time} · ${task.note}', style: const TextStyle(fontSize: 15, color: AppColors.muted))])),
                                  FilledButton.icon(onPressed: () { state.toggleTask(task.id); showDemoMessage(context, 'Task updated'); }, icon: const Icon(Icons.check, size: 17), label: Text(task.completed ? 'Done' : 'Mark done')),
                                ],
                              ),
                            ),
                          ),
                        )),
                  const SizedBox(height: 12),
                  const SafetyNote(text: 'Caregivers see assigned tasks only. Full medical details remain private to the patient.'),
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
    if (context.mounted) showDemoMessage(context, 'Call $phone');
  }
}
