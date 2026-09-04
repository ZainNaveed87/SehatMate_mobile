import 'package:flutter/material.dart';

import '../core/app_routes.dart';
import '../core/app_theme.dart';
import '../localization/language_scope.dart';
import '../services/family_care_service.dart';
import '../widgets/app_shell.dart';
import '../widgets/page_header.dart';
import '../widgets/ui.dart';

class FamilyScreen extends StatefulWidget {
  const FamilyScreen({super.key});

  @override
  State<FamilyScreen> createState() => _FamilyScreenState();
}

class _FamilyScreenState extends State<FamilyScreen> {
  late Future<FamilyHomeData> _future = FamilyCareService.instance.fetchHome();

  void _refresh() {
    setState(() {
      _future = FamilyCareService.instance.fetchHome();
    });
  }

  @override
  Widget build(BuildContext context) => AppShell(
    currentRoute: AppRoutes.family,
    title: context.tr('family_care'),
    child: FutureBuilder<FamilyHomeData>(
      future: _future,
      builder: (context, snapshot) {
        final loading = snapshot.connectionState == ConnectionState.waiting;
        final error = snapshot.error;
        final data = snapshot.data;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            PageHeader(
              title: context.tr('family_care'),
              subtitle:
                  'Coordinate support with explicit patient-controlled permissions.',
              action: FilledButton.icon(
                onPressed: () async {
                  await Navigator.pushNamed(context, AppRoutes.familyNew);
                  if (mounted) _refresh();
                },
                icon: const Icon(Icons.person_add_alt_1_outlined, size: 18),
                label: const Text('Invite family member'),
              ),
            ),
            if (loading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(36),
                  child: CircularProgressIndicator(),
                ),
              )
            else if (error != null)
              EmptyState(
                icon: Icons.wifi_off_outlined,
                title: 'Family Care could not load',
                description: error.toString(),
                action: FilledButton.icon(
                  onPressed: _refresh,
                  icon: const Icon(Icons.refresh, size: 18),
                  label: const Text('Try again'),
                ),
              )
            else ...[
              _InvitationPanel(
                invitations: data?.pendingInvitations ?? const [],
                onChanged: _refresh,
              ),
              const SizedBox(height: 18),
              _RelationshipGrid(
                relationships: data?.relationships ?? const [],
                onChanged: _refresh,
              ),
            ],
            const SizedBox(height: 24),
            const SafetyNote(
              text:
                  'Family Care shares only authorized care-plan, task, care-gap, simulation and performance information. The patient remains the owner of medical data and clinical instructions.',
            ),
          ],
        );
      },
    ),
  );
}

class _InvitationPanel extends StatelessWidget {
  const _InvitationPanel({required this.invitations, required this.onChanged});

  final List<FamilyInvitation> invitations;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    if (invitations.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Pending invitations',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 10),
        ...invitations.map(
          (invitation) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: AppCard(
              radius: AppRadii.lg,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const TaskIcon(icon: Icons.mail_outline, size: 42),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          invitation.careRecipient?.patientName.isNotEmpty ==
                                  true
                              ? invitation.careRecipient!.patientName
                              : invitation.inviter?.name ?? 'Family member',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${invitation.relationshipLabel} invitation from ${invitation.inviter?.name ?? 'SehatMate user'}',
                          style: const TextStyle(color: AppColors.muted),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      FilledButton(
                        onPressed: () => _handleInvitation(
                          context,
                          invitation.id,
                          accept: true,
                        ),
                        child: const Text('Accept'),
                      ),
                      OutlinedButton(
                        onPressed: () => _handleInvitation(
                          context,
                          invitation.id,
                          accept: false,
                        ),
                        child: const Text('Decline'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _handleInvitation(
    BuildContext context,
    String invitationId, {
    required bool accept,
  }) async {
    try {
      if (accept) {
        await FamilyCareService.instance.acceptInvitation(invitationId);
      } else {
        await FamilyCareService.instance.declineInvitation(invitationId);
      }
      if (!context.mounted) return;
      showDemoMessage(
        context,
        accept ? 'Family invitation accepted.' : 'Family invitation declined.',
      );
      onChanged();
    } on FamilyCareException catch (error) {
      if (context.mounted) showDemoMessage(context, error.message);
    }
  }
}

class _RelationshipGrid extends StatelessWidget {
  const _RelationshipGrid({
    required this.relationships,
    required this.onChanged,
  });

  final List<FamilyRelationship> relationships;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    if (relationships.isEmpty) {
      return EmptyState(
        icon: Icons.handshake_outlined,
        title: 'No active family relationships yet',
        description:
            'Invite a trusted SehatMate user, or accept an invitation from someone you support.',
        action: FilledButton.icon(
          onPressed: () async {
            await Navigator.pushNamed(context, AppRoutes.familyNew);
            onChanged();
          },
          icon: const Icon(Icons.person_add_alt_1_outlined, size: 18),
          label: const Text('Invite family member'),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 760 ? 2 : 1;
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: relationships.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            crossAxisSpacing: 14,
            mainAxisSpacing: 14,
            childAspectRatio: columns == 1 ? 1.75 : 1.35,
          ),
          itemBuilder: (context, index) {
            final relationship = relationships[index];
            final summary = relationship.summary;
            final todaySection = summary?.section('today') ?? const {};
            final taskSummary = _map(todaySection['taskSummary']);
            final completed = _int(taskSummary['completed']);
            final total = _int(taskSummary['total']);
            final careGapSection = summary?.section('careGaps') ?? const {};
            final gapSummary = _map(careGapSection['summary']);
            final openGaps = _int(gapSummary['open']);
            final status = summary?.statusText ?? 'Support may help';

            return FadeSlideIn(
              child: AppCard(
                radius: AppRadii.lg,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 22,
                          backgroundColor: AppColors.primaryLight,
                          child: Text(
                            relationship.memberName
                                .substring(0, 1)
                                .toUpperCase(),
                            style: const TextStyle(
                              color: AppColors.accentForeground,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                relationship.memberName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              Text(
                                relationship.relationshipLabel,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(color: AppColors.muted),
                              ),
                            ],
                          ),
                        ),
                        _StatusPill(label: status),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _MetricLine(
                      icon: Icons.task_alt_outlined,
                      label: total == 0
                          ? 'Today tasks unavailable'
                          : '$completed/$total today tasks complete',
                    ),
                    const SizedBox(height: 8),
                    _MetricLine(
                      icon: Icons.report_problem_outlined,
                      label: openGaps == 0
                          ? 'No open care gaps shown'
                          : '$openGaps open care gap${openGaps == 1 ? '' : 's'}',
                    ),
                    const Spacer(),
                    Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: FilledButton.icon(
                        onPressed: () => Navigator.pushNamed(
                          context,
                          AppRoutes.caregiver(relationship.id),
                        ),
                        icon: const Icon(Icons.open_in_new, size: 17),
                        label: const Text('Open member'),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class AddCaregiverScreen extends StatefulWidget {
  const AddCaregiverScreen({super.key});

  @override
  State<AddCaregiverScreen> createState() => _AddCaregiverScreenState();
}

class _AddCaregiverScreenState extends State<AddCaregiverScreen> {
  final email = TextEditingController();
  final relationship = TextEditingController(text: 'Family caregiver');
  final formKey = GlobalKey<FormState>();
  var saving = false;

  late final Map<String, bool> scopes = {
    for (final scope in familyPermissionScopes)
      scope.key: {
        'care_plan.read',
        'schedule.read',
        'task.read',
        'care_gap.read',
        'simulation.read',
        'performance.read',
      }.contains(scope.key),
  };

  @override
  void dispose() {
    email.dispose();
    relationship.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AppShell(
    currentRoute: AppRoutes.familyNew,
    title: 'Invite family member',
    child: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextButton.icon(
              onPressed: () =>
                  Navigator.pushReplacementNamed(context, AppRoutes.family),
              icon: const Icon(Icons.arrow_back, size: 18),
              label: const Text('Family Care'),
            ),
            const PageHeader(
              title: 'Invite a SehatMate user',
              subtitle:
                  'The invitation stays inside the app. Access starts only after the other user accepts.',
            ),
            AppCard(
              radius: AppRadii.lg,
              padding: const EdgeInsets.all(22),
              child: Form(
                key: formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    fieldLabel(
                      'SehatMate account email',
                      TextFormField(
                        controller: email,
                        keyboardType: TextInputType.emailAddress,
                        decoration: const InputDecoration(
                          hintText: 'name@example.com',
                        ),
                        validator: (value) =>
                            value == null || !value.contains('@')
                            ? 'Enter a valid email.'
                            : null,
                      ),
                    ),
                    const SizedBox(height: 14),
                    fieldLabel(
                      'Relationship label',
                      TextFormField(
                        controller: relationship,
                        decoration: const InputDecoration(
                          hintText: 'Ammi, Abu, daughter, caregiver',
                        ),
                        validator: (value) =>
                            value == null || value.trim().isEmpty
                            ? 'Enter a relationship label.'
                            : null,
                      ),
                    ),
                    const SizedBox(height: 22),
                    const Text(
                      'Permissions',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _PermissionToggles(
                      scopes: scopes,
                      onChanged: () => setState(() {}),
                    ),
                    const SizedBox(height: 22),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: saving ? null : _submit,
                        icon: saving
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.send_outlined, size: 18),
                        label: const Text('Send invitation'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 18),
            const SafetyNote(
              text:
                  'Family permissions never allow dose, prescription, diagnosis or medical-instruction changes. Sensitive actions still require SehatMate confirmation and safety checks.',
            ),
          ],
        ),
      ),
    ),
  );

  Future<void> _submit() async {
    if (!(formKey.currentState?.validate() ?? false)) return;
    setState(() => saving = true);
    try {
      await FamilyCareService.instance.createInvitation(
        email: email.text,
        relationshipLabel: relationship.text,
        scopes: scopes,
      );
      if (!mounted) return;
      showDemoMessage(context, 'Family invitation sent.');
      Navigator.pushReplacementNamed(context, AppRoutes.family);
    } on FamilyCareException catch (error) {
      if (mounted) showDemoMessage(context, error.message);
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }
}

class CaregiverDetailScreen extends StatefulWidget {
  const CaregiverDetailScreen({required this.caregiverId, super.key});

  final String caregiverId;

  @override
  State<CaregiverDetailScreen> createState() => _CaregiverDetailScreenState();
}

class _CaregiverDetailScreenState extends State<CaregiverDetailScreen> {
  late Future<FamilyMemberDetailData> _future = FamilyCareService.instance
      .fetchMemberSummary(widget.caregiverId);

  void _refresh() {
    setState(() {
      _future = FamilyCareService.instance.fetchMemberSummary(
        widget.caregiverId,
      );
    });
  }

  @override
  Widget build(BuildContext context) => AppShell(
    currentRoute: AppRoutes.caregiver(widget.caregiverId),
    title: 'Family member',
    child: FutureBuilder<FamilyMemberDetailData>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(36),
              child: CircularProgressIndicator(),
            ),
          );
        }
        if (snapshot.hasError) {
          return EmptyState(
            icon: Icons.lock_outline,
            title: 'Family member unavailable',
            description: snapshot.error.toString(),
            action: FilledButton.icon(
              onPressed: () =>
                  Navigator.pushReplacementNamed(context, AppRoutes.family),
              icon: const Icon(Icons.arrow_back, size: 18),
              label: const Text('Back to Family Care'),
            ),
          );
        }

        final data = snapshot.data!;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextButton.icon(
              onPressed: () =>
                  Navigator.pushReplacementNamed(context, AppRoutes.family),
              icon: const Icon(Icons.arrow_back, size: 18),
              label: const Text('Family Care'),
            ),
            PageHeader(
              title: data.relationship.memberName,
              subtitle:
                  '${data.relationship.relationshipLabel} · ${data.summary.statusText}',
              action: OutlinedButton.icon(
                onPressed: () => _confirmRevoke(context),
                icon: const Icon(Icons.link_off_outlined, size: 18),
                label: const Text('Revoke'),
              ),
            ),
            _FamilyDetailSections(summary: data.summary),
            if (data.relationship.isCareRecipient) ...[
              const SizedBox(height: 18),
              AppCard(
                radius: AppRadii.lg,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Manage permissions',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _PermissionEditor(
                      relationship: data.relationship,
                      onSaved: _refresh,
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 18),
            const SafetyNote(
              text:
                  'This view does not switch accounts. You remain signed in as yourself, and every section is authorized again by the server.',
            ),
          ],
        );
      },
    ),
  );

  Future<void> _confirmRevoke(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Revoke family access?'),
        content: const Text(
          'This immediately blocks shared Family Care access for this relationship.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Revoke'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await FamilyCareService.instance.revokeRelationship(widget.caregiverId);
      if (!context.mounted) return;
      showDemoMessage(context, 'Family access revoked.');
      Navigator.pushReplacementNamed(context, AppRoutes.family);
    } on FamilyCareException catch (error) {
      if (context.mounted) showDemoMessage(context, error.message);
    }
  }
}

class _FamilyDetailSections extends StatelessWidget {
  const _FamilyDetailSections({required this.summary});

  final FamilySummary summary;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      _SectionCard(
        icon: Icons.medical_information_outlined,
        title: 'Active care plans',
        section: summary.section('carePlans'),
        builder: (section) {
          final active = _int(section['activeCount']);
          final total = _int(section['totalCount']);
          final items = _list(section['items']);
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('$active active · $total total'),
              ...items
                  .take(4)
                  .map(
                    (item) => _SimpleRow(
                      title: _text(item['title']),
                      detail: _text(item['status']),
                    ),
                  ),
            ],
          );
        },
      ),
      _SectionCard(
        icon: Icons.today_outlined,
        title: 'Today',
        section: summary.section('today'),
        builder: (section) {
          final taskSummary = _map(section['taskSummary']);
          final occurrences = _list(section['occurrences']);
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${_int(taskSummary['completed'])}/${_int(taskSummary['total'])} complete · ${_int(taskSummary['pending'])} pending · ${_int(taskSummary['missed'])} missed',
              ),
              ...occurrences
                  .take(6)
                  .map(
                    (item) => _SimpleRow(
                      title: _text(item['title']),
                      detail:
                          '${_text(item['scheduledTime']).isEmpty ? 'Time not set' : _text(item['scheduledTime'])} · ${_text(item['status'])}',
                    ),
                  ),
            ],
          );
        },
      ),
      _SectionCard(
        icon: Icons.report_problem_outlined,
        title: 'Care gaps',
        section: summary.section('careGaps'),
        builder: (section) {
          final gapSummary = _map(section['summary']);
          final items = _list(section['items']);
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${_int(gapSummary['open'])} open · ${_int(gapSummary['blocking'])} blocking · ${_int(gapSummary['attention'])} need attention',
              ),
              ...items
                  .take(5)
                  .map(
                    (item) => _SimpleRow(
                      title: _text(item['title']),
                      detail: _text(item['next_step']).isEmpty
                          ? _text(item['summary'])
                          : _text(item['next_step']),
                    ),
                  ),
            ],
          );
        },
      ),
      _SectionCard(
        icon: Icons.psychology_alt_outlined,
        title: 'Simulation / readiness',
        section: summary.section('simulation'),
        builder: (section) => Text(
          section['planId'] == null
              ? 'No care plan selected for simulation.'
              : 'Readiness ${_int(section['readiness'])}% · ${_int(_map(section['metrics'])['atRisk'])} at risk · ${_int(section['hardBlockerCount'])} blockers',
        ),
      ),
      _SectionCard(
        icon: Icons.speed_outlined,
        title: 'Performance',
        section: summary.section('performance'),
        builder: (section) {
          final today = _map(section['today']);
          final todaySummary = _map(today['summary']);
          final primaryPlan = _text(_map(section['primaryPlan'])['title']);
          return Text(
            '${_int(todaySummary['completed'])} completed today · ${_int(todaySummary['pending'])} pending · ${primaryPlan.isEmpty ? 'No primary plan' : primaryPlan}',
          );
        },
      ),
    ],
  );
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.icon,
    required this.title,
    required this.section,
    required this.builder,
  });

  final IconData icon;
  final String title;
  final Map<String, dynamic> section;
  final Widget Function(Map<String, dynamic>) builder;

  @override
  Widget build(BuildContext context) {
    final allowed = section['allowed'] == true;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: AppCard(
        radius: AppRadii.lg,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TaskIcon(icon: icon, size: 40),
            const SizedBox(width: 14),
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
                  const SizedBox(height: 6),
                  if (allowed)
                    builder(section)
                  else
                    Text(
                      'Permission required: ${_text(section['requiredScope'])}',
                      style: const TextStyle(color: AppColors.muted),
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

class _PermissionEditor extends StatefulWidget {
  const _PermissionEditor({required this.relationship, required this.onSaved});

  final FamilyRelationship relationship;
  final VoidCallback onSaved;

  @override
  State<_PermissionEditor> createState() => _PermissionEditorState();
}

class _PermissionEditorState extends State<_PermissionEditor> {
  late final Map<String, bool> scopes = Map.of(widget.relationship.permissions);
  var saving = false;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _PermissionToggles(scopes: scopes, onChanged: () => setState(() {})),
      const SizedBox(height: 12),
      Align(
        alignment: AlignmentDirectional.centerStart,
        child: FilledButton.icon(
          onPressed: saving ? null : _save,
          icon: saving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.save_outlined, size: 18),
          label: const Text('Save permissions'),
        ),
      ),
    ],
  );

  Future<void> _save() async {
    setState(() => saving = true);
    try {
      await FamilyCareService.instance.updatePermissions(
        relationshipId: widget.relationship.id,
        scopes: scopes,
      );
      if (!mounted) return;
      showDemoMessage(context, 'Family permissions updated.');
      widget.onSaved();
    } on FamilyCareException catch (error) {
      if (mounted) showDemoMessage(context, error.message);
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }
}

class _PermissionToggles extends StatelessWidget {
  const _PermissionToggles({required this.scopes, required this.onChanged});

  final Map<String, bool> scopes;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 8,
    runSpacing: 8,
    children: familyPermissionScopes.map((scope) {
      final selected = scopes[scope.key] == true;
      return FilterChip(
        selected: selected,
        label: Text(scope.label),
        onSelected: (value) {
          scopes[scope.key] = value;
          onChanged();
        },
      );
    }).toList(),
  );
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final attention = label.toLowerCase().contains('attention');
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: attention ? AppColors.warningSoft : AppColors.successSoft,
        borderRadius: BorderRadius.circular(AppRadii.md),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: attention ? AppColors.warning : AppColors.success,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _MetricLine extends StatelessWidget {
  const _MetricLine({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Icon(icon, size: 17, color: AppColors.muted),
      const SizedBox(width: 8),
      Expanded(
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: AppColors.muted),
        ),
      ),
    ],
  );
}

class _SimpleRow extends StatelessWidget {
  const _SimpleRow({required this.title, required this.detail});

  final String title;
  final String detail;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 8),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.chevron_right, size: 18, color: AppColors.muted),
        const SizedBox(width: 4),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title.isEmpty ? 'Care item' : title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              if (detail.isNotEmpty)
                Text(
                  detail,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: AppColors.muted, fontSize: 13),
                ),
            ],
          ),
        ),
      ],
    ),
  );
}

Map<String, dynamic> _map(dynamic value) {
  return value is Map<String, dynamic> ? value : const <String, dynamic>{};
}

List<Map<String, dynamic>> _list(dynamic value) {
  if (value is! List) return const [];
  return value.whereType<Map<String, dynamic>>().toList();
}

int _int(dynamic value) {
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

String _text(dynamic value) =>
    value
        ?.toString()
        .replaceAll(RegExp(r'[\u0000-\u001F\u007F]'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim() ??
    '';
