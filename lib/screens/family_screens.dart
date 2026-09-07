import 'package:flutter/material.dart';

import '../core/app_routes.dart';
import '../core/app_theme.dart';
import '../localization/language_scope.dart';
import '../services/family_care_service.dart';
import '../widgets/app_shell.dart';
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
        final invitations =
            data?.pendingInvitations ?? const <FamilyInvitation>[];
        final relationships =
            data?.relationships ?? const <FamilyRelationship>[];

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            FadeSlideIn(
              child: _familyHero(
                relationships: relationships.length,
                invitations: invitations.length,
              ),
            ),
            const SizedBox(height: 18),
            FadeSlideIn(
              delay: const Duration(milliseconds: 60),
              child: _familyMetrics(
                relationships: relationships.length,
                invitations: invitations.length,
              ),
            ),
            const SizedBox(height: 20),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              child: loading
                  ? const _FamilyLoadingSkeleton(
                      key: ValueKey('family-loading'),
                    )
                  : error != null
                  ? _FamilyErrorCard(
                      key: const ValueKey('family-error'),
                      error: error.toString(),
                      onRetry: _refresh,
                    )
                  : Column(
                      key: ValueKey(
                        'family-content-${relationships.length}-${invitations.length}',
                      ),
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _InvitationPanel(
                          invitations: invitations,
                          onChanged: _refresh,
                        ),
                        if (invitations.isNotEmpty) const SizedBox(height: 20),
                        _RelationshipGrid(
                          relationships: relationships,
                          onChanged: _refresh,
                        ),
                      ],
                    ),
            ),
            const SizedBox(height: 22),
            const FadeSlideIn(
              delay: Duration(milliseconds: 120),
              child: SafetyNote(
                text:
                    'Family Care shares only authorized care-plan, task, care-gap, simulation and performance information. The patient remains the owner of medical data and clinical instructions.',
              ),
            ),
          ],
        );
      },
    ),
  );

  Widget _familyHero({required int relationships, required int invitations}) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 620;

        return Container(
          padding: EdgeInsets.all(compact ? 20 : 26),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF0F766E), Color(0xFF0D9488), Color(0xFF14B8A6)],
            ),
            borderRadius: BorderRadius.circular(28),
            boxShadow: const [
              BoxShadow(
                color: Color(0x260F766E),
                blurRadius: 32,
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
                  width: 190,
                  height: 190,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Color(0x16FFFFFF),
                  ),
                ),
              ),
              if (compact)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _familyHeroCopy(
                      relationships: relationships,
                      invitations: invitations,
                    ),
                    const SizedBox(height: 18),
                    FilledButton.icon(
                      onPressed: () async {
                        await Navigator.pushNamed(context, AppRoutes.familyNew);
                        if (mounted) _refresh();
                      },
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: AppColors.primary,
                      ),
                      icon: const Icon(
                        Icons.person_add_alt_1_outlined,
                        size: 18,
                      ),
                      label: const Text('Invite family member'),
                    ),
                  ],
                )
              else
                Row(
                  children: [
                    Expanded(
                      child: _familyHeroCopy(
                        relationships: relationships,
                        invitations: invitations,
                      ),
                    ),
                    const SizedBox(width: 22),
                    FilledButton.icon(
                      onPressed: () async {
                        await Navigator.pushNamed(context, AppRoutes.familyNew);
                        if (mounted) _refresh();
                      },
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: AppColors.primary,
                      ),
                      icon: const Icon(
                        Icons.person_add_alt_1_outlined,
                        size: 18,
                      ),
                      label: const Text('Invite family member'),
                    ),
                  ],
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _familyHeroCopy({
    required int relationships,
    required int invitations,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0x20FFFFFF),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: const Color(0x30FFFFFF)),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.groups_outlined, size: 15, color: Colors.white),
              SizedBox(width: 6),
              Text(
                'Patient-controlled sharing',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Text(
          context.tr('family_care'),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 30,
            height: 1.08,
            fontWeight: FontWeight.w800,
            letterSpacing: -.45,
          ),
        ),
        const SizedBox(height: 9),
        const Text(
          'Coordinate support with explicit patient-controlled permissions.',
          style: TextStyle(
            color: Color(0xE6FFFFFF),
            fontSize: 13,
            height: 1.45,
          ),
        ),
        const SizedBox(height: 14),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _familyHeroChip(
              icon: Icons.handshake_outlined,
              label:
                  '$relationships active relationship${relationships == 1 ? '' : 's'}',
            ),
            _familyHeroChip(
              icon: Icons.mail_outline_rounded,
              label:
                  '$invitations pending invitation${invitations == 1 ? '' : 's'}',
            ),
          ],
        ),
      ],
    );
  }

  Widget _familyHeroChip({required IconData icon, required String label}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0x1FFFFFFF),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0x26FFFFFF)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.white),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _familyMetrics({
    required int relationships,
    required int invitations,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 620 ? 2 : 1;
        const gap = 10.0;
        final width = (constraints.maxWidth - ((columns - 1) * gap)) / columns;

        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            _familyMetric(
              width: width,
              icon: Icons.handshake_outlined,
              value: relationships,
              label: 'Active family relationships',
              background: AppColors.successSoft,
              foreground: AppColors.successForeground,
            ),
            _familyMetric(
              width: width,
              icon: Icons.mark_email_unread_outlined,
              value: invitations,
              label: 'Pending invitations',
              background: AppColors.primaryLight,
              foreground: AppColors.primary,
            ),
          ],
        );
      },
    );
  }

  Widget _familyMetric({
    required double width,
    required IconData icon,
    required int value,
    required String label,
    required Color background,
    required Color foreground,
  }) {
    return SizedBox(
      width: width,
      child: AppCard(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: background,
                borderRadius: BorderRadius.circular(AppRadii.lg),
              ),
              child: Icon(icon, size: 19, color: foreground),
            ),
            const SizedBox(width: 11),
            Text(
              '$value',
              style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w800),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.muted,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FamilyLoadingSkeleton extends StatelessWidget {
  const _FamilyLoadingSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(
        3,
        (index) => Padding(
          padding: EdgeInsets.only(bottom: index == 2 ? 0 : 12),
          child: AppCard(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8EEF2),
                    borderRadius: BorderRadius.circular(AppRadii.xl),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 160,
                        height: 14,
                        decoration: BoxDecoration(
                          color: const Color(0xFFE8EEF2),
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        width: double.infinity,
                        height: 10,
                        decoration: BoxDecoration(
                          color: const Color(0xFFE8EEF2),
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FamilyErrorCard extends StatelessWidget {
  const _FamilyErrorCard({
    super.key,
    required this.error,
    required this.onRetry,
    this.buttonLabel = 'Try again',
  });

  final String error;
  final VoidCallback onRetry;
  final String buttonLabel;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 540),
        child: AppCard(
          padding: const EdgeInsets.all(24),
          color: const Color(0xFFFFFBEB),
          borderColor: const Color(0xFFFDE68A),
          child: Column(
            children: [
              Container(
                width: 52,
                height: 52,
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
                error,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.muted,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 14),
              FilledButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded, size: 17),
                label: Text(buttonLabel),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InvitationPanel extends StatelessWidget {
  const _InvitationPanel({required this.invitations, required this.onChanged});

  final List<FamilyInvitation> invitations;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    if (invitations.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: AppColors.primaryLight,
                borderRadius: BorderRadius.circular(AppRadii.lg),
              ),
              child: const Icon(
                Icons.mail_outline_rounded,
                size: 19,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(width: 10),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Pending invitations',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Review invitations waiting for a response',
                    style: TextStyle(fontSize: 12, color: AppColors.muted),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
              decoration: BoxDecoration(
                color: AppColors.primaryLight,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                '${invitations.length}',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: AppColors.primary,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ...invitations.asMap().entries.map(
          (entry) => FadeSlideIn(
            delay: Duration(milliseconds: 30 * entry.key.clamp(0, 5)),
            child: Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _InvitationCard(
                invitation: entry.value,
                onChanged: onChanged,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _InvitationCard extends StatelessWidget {
  const _InvitationCard({required this.invitation, required this.onChanged});

  final FamilyInvitation invitation;
  final VoidCallback onChanged;

  String get _personName {
    if (invitation.isIncoming) {
      final patientName = invitation.careRecipient?.patientName.trim() ?? '';
      if (patientName.isNotEmpty) return patientName;

      final inviterName = invitation.inviter?.name.trim() ?? '';
      return inviterName.isEmpty ? 'Family member' : inviterName;
    }

    final caregiverName = invitation.caregiver?.name.trim() ?? '';
    return caregiverName.isEmpty ? 'Family member' : caregiverName;
  }

  String get _description {
    final label = invitation.relationshipLabel.trim().isEmpty
        ? 'Family caregiver'
        : invitation.relationshipLabel.trim();

    if (invitation.isIncoming) {
      final inviterName = invitation.inviter?.name.trim() ?? '';
      return inviterName.isEmpty
          ? '$label invitation'
          : '$label invitation from $inviterName';
    }

    final caregiverName = invitation.caregiver?.name.trim() ?? '';
    return caregiverName.isEmpty
        ? '$label invitation sent'
        : '$label invitation sent to $caregiverName';
  }

  @override
  Widget build(BuildContext context) {
    final incoming = invitation.canRespond;

    return HoverLift(
      child: AppCard(
        padding: EdgeInsets.zero,
        borderColor: incoming
            ? AppColors.primary.withValues(alpha: .20)
            : AppColors.border,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              height: 3,
              color: incoming ? AppColors.primary : AppColors.border,
            ),
            Padding(
              padding: const EdgeInsets.all(15),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: incoming
                              ? AppColors.primaryLight
                              : const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(AppRadii.xl),
                        ),
                        child: Icon(
                          incoming
                              ? Icons.mark_email_unread_outlined
                              : Icons.outgoing_mail,
                          size: 20,
                          color: incoming ? AppColors.primary : AppColors.muted,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _personName,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _description,
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.muted,
                                height: 1.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (!invitation.canRespond) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 9,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.primaryLight,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: const Text(
                            'Pending',
                            style: TextStyle(
                              color: AppColors.accentForeground,
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (invitation.canRespond) ...[
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: () => _handleInvitation(
                              context,
                              invitation.id,
                              accept: true,
                            ),
                            icon: const Icon(Icons.check_rounded, size: 17),
                            label: const Text('Accept'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => _handleInvitation(
                              context,
                              invitation.id,
                              accept: false,
                            ),
                            icon: const Icon(Icons.close_rounded, size: 17),
                            label: const Text('Decline'),
                          ),
                        ),
                      ],
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
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 34),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFF0FDFA), Color(0xFFF8FAFC)],
          ),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: const Color(0xFFCCFBF1)),
        ),
        child: Column(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: AppColors.primaryLight,
                borderRadius: BorderRadius.circular(AppRadii.xl),
              ),
              child: const Icon(
                Icons.handshake_outlined,
                color: AppColors.primary,
                size: 27,
              ),
            ),
            const SizedBox(height: 14),
            const Text(
              'No active family relationships yet',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            const Text(
              'Invite a trusted SehatMate user, or accept an invitation from someone you support.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: AppColors.muted,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: () async {
                await Navigator.pushNamed(context, AppRoutes.familyNew);
                onChanged();
              },
              icon: const Icon(Icons.person_add_alt_1_outlined, size: 18),
              label: const Text('Invite family member'),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: AppColors.successSoft,
                borderRadius: BorderRadius.circular(AppRadii.lg),
              ),
              child: const Icon(
                Icons.people_alt_outlined,
                size: 19,
                color: AppColors.successForeground,
              ),
            ),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                'Family members',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth < 760) {
              return Column(
                children: [
                  for (
                    var index = 0;
                    index < relationships.length;
                    index++
                  ) ...[
                    _FamilyRelationshipCard(relationship: relationships[index]),
                    if (index != relationships.length - 1)
                      const SizedBox(height: 14),
                  ],
                ],
              );
            }

            final cardWidth = (constraints.maxWidth - 14) / 2;
            return Wrap(
              spacing: 14,
              runSpacing: 14,
              children: [
                for (final relationship in relationships)
                  SizedBox(
                    width: cardWidth,
                    child: _FamilyRelationshipCard(relationship: relationship),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _FamilyRelationshipCard extends StatelessWidget {
  const _FamilyRelationshipCard({required this.relationship});

  final FamilyRelationship relationship;

  @override
  Widget build(BuildContext context) {
    final summary = relationship.summary;
    final todaySection = summary?.section('today') ?? const {};
    final taskSummary = _map(todaySection['taskSummary']);
    final completed = _int(taskSummary['completed']);
    final total = _int(taskSummary['total']);
    final careGapSection = summary?.section('careGaps') ?? const {};
    final gapSummary = _map(careGapSection['summary']);
    final openGaps = _int(gapSummary['open']);
    final status = summary?.statusText ?? 'Support may help';

    final memberName = relationship.memberName.trim().isEmpty
        ? 'Family member'
        : relationship.memberName.trim();

    final attention =
        status.toLowerCase().contains('attention') ||
        status.toLowerCase().contains('help');

    return FadeSlideIn(
      child: HoverLift(
        cursor: SystemMouseCursors.click,
        child: AppCard(
          padding: EdgeInsets.zero,
          borderColor: attention
              ? AppColors.warning.withValues(alpha: .20)
              : const Color(0xFFCCFBF1),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                height: 4,
                color: attention ? AppColors.warning : AppColors.primary,
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CircleAvatar(
                          radius: 23,
                          backgroundColor: attention
                              ? AppColors.warningSoft
                              : AppColors.primaryLight,
                          child: Text(
                            memberName.substring(0, 1).toUpperCase(),
                            style: TextStyle(
                              color: attention
                                  ? AppColors.warningForeground
                                  : AppColors.accentForeground,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                memberName,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                relationship.relationshipLabel,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.muted,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        _StatusPill(label: status),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: _FamilyMiniMetric(
                            icon: Icons.task_alt_outlined,
                            value: total == 0 ? '—' : '$completed/$total',
                            label: 'Today tasks',
                            background: AppColors.primaryLight,
                            foreground: AppColors.primary,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _FamilyMiniMetric(
                            icon: Icons.report_problem_outlined,
                            value: '$openGaps',
                            label: 'Open gaps',
                            background: openGaps > 0
                                ? AppColors.warningSoft
                                : AppColors.successSoft,
                            foreground: openGaps > 0
                                ? AppColors.warningForeground
                                : AppColors.successForeground,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: () => Navigator.pushNamed(
                          context,
                          AppRoutes.caregiver(relationship.id),
                        ),
                        icon: const Icon(Icons.open_in_new_rounded, size: 17),
                        label: const Text('Open member'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FamilyMiniMetric extends StatelessWidget {
  const _FamilyMiniMetric({
    required this.icon,
    required this.value,
    required this.label,
    required this.background,
    required this.foreground,
  });

  final IconData icon;
  final String value;
  final String label;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(AppRadii.lg),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: foreground),
          const SizedBox(width: 7),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: foreground,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 9,
                    color: AppColors.muted,
                    fontWeight: FontWeight.w600,
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
        constraints: const BoxConstraints(maxWidth: 760),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: TextButton.icon(
                onPressed: () =>
                    Navigator.pushReplacementNamed(context, AppRoutes.family),
                icon: const Icon(Icons.arrow_back_rounded, size: 18),
                label: const Text('Family Care'),
              ),
            ),
            const SizedBox(height: 6),
            FadeSlideIn(
              child: Container(
                padding: const EdgeInsets.all(22),
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
                      color: Color(0x220F766E),
                      blurRadius: 28,
                      spreadRadius: -12,
                      offset: Offset(0, 14),
                    ),
                  ],
                ),
                child: const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.person_add_alt_1_outlined,
                      color: Colors.white,
                      size: 28,
                    ),
                    SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Invite a SehatMate user',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          SizedBox(height: 6),
                          Text(
                            'The invitation is created in the app and SehatMate will also try to notify them by email. Access starts only after they accept.',
                            style: TextStyle(
                              color: Color(0xE6FFFFFF),
                              fontSize: 13,
                              height: 1.45,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 18),
            FadeSlideIn(
              delay: const Duration(milliseconds: 60),
              child: AppCard(
                padding: const EdgeInsets.all(20),
                child: Form(
                  key: formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _inviteSectionHeader(
                        icon: Icons.person_outline_rounded,
                        title: 'Who are you inviting?',
                      ),
                      const SizedBox(height: 14),
                      fieldLabel(
                        'SehatMate account email',
                        TextFormField(
                          controller: email,
                          keyboardType: TextInputType.emailAddress,
                          decoration: const InputDecoration(
                            hintText: 'name@example.com',
                            prefixIcon: Icon(Icons.alternate_email_rounded),
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
                            prefixIcon: Icon(Icons.badge_outlined),
                          ),
                          validator: (value) =>
                              value == null || value.trim().isEmpty
                              ? 'Enter a relationship label.'
                              : null,
                        ),
                      ),
                      const SizedBox(height: 24),
                      _inviteSectionHeader(
                        icon: Icons.admin_panel_settings_outlined,
                        title: 'Permissions',
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'Choose only the information and support actions this person should be able to access.',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.muted,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 12),
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
                                    color: Colors.white,
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

  Widget _inviteSectionHeader({required IconData icon, required String title}) {
    return Row(
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: AppColors.primaryLight,
            borderRadius: BorderRadius.circular(AppRadii.lg),
          ),
          child: Icon(icon, size: 17, color: AppColors.primary),
        ),
        const SizedBox(width: 9),
        Text(
          title,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
        ),
      ],
    );
  }

  Future<void> _submit() async {
    if (!(formKey.currentState?.validate() ?? false)) return;
    setState(() => saving = true);
    try {
      final result = await FamilyCareService.instance.createInvitation(
        email: email.text,
        relationshipLabel: relationship.text,
        scopes: scopes,
      );
      if (!mounted) return;
      showDemoMessage(
        context,
        result.emailDelivery.sent
            ? 'Invitation sent by email and added to SehatMate.'
            : 'Invitation added to SehatMate. Email delivery did not complete.',
      );
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
          return const _FamilyLoadingSkeleton();
        }

        if (snapshot.hasError) {
          return _FamilyErrorCard(
            error: snapshot.error.toString(),
            onRetry: () =>
                Navigator.pushReplacementNamed(context, AppRoutes.family),
            buttonLabel: 'Back to Family Care',
          );
        }

        final data = snapshot.data!;
        final memberName = data.relationship.memberName.trim().isEmpty
            ? 'Family member'
            : data.relationship.memberName.trim();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: TextButton.icon(
                onPressed: () =>
                    Navigator.pushReplacementNamed(context, AppRoutes.family),
                icon: const Icon(Icons.arrow_back_rounded, size: 18),
                label: const Text('Family Care'),
              ),
            ),
            const SizedBox(height: 6),
            FadeSlideIn(
              child: Container(
                padding: const EdgeInsets.all(22),
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
                ),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final compact = constraints.maxWidth < 560;

                    final copy = Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CircleAvatar(
                          radius: 25,
                          backgroundColor: const Color(0x26FFFFFF),
                          child: Text(
                            memberName.substring(0, 1).toUpperCase(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        const SizedBox(width: 13),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                memberName,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 24,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 5),
                              Text(
                                '${data.relationship.relationshipLabel} · ${data.summary.statusText}',
                                style: const TextStyle(
                                  color: Color(0xE6FFFFFF),
                                  fontSize: 12,
                                  height: 1.4,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    );

                    final revoke = OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: const BorderSide(color: Color(0x48FFFFFF)),
                      ),
                      onPressed: () => _confirmRevoke(context),
                      icon: const Icon(Icons.link_off_outlined, size: 18),
                      label: const Text('Revoke'),
                    );

                    if (compact) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [copy, const SizedBox(height: 14), revoke],
                      );
                    }

                    return Row(
                      children: [
                        Expanded(child: copy),
                        const SizedBox(width: 18),
                        revoke,
                      ],
                    );
                  },
                ),
              ),
            ),
            const SizedBox(height: 18),
            _FamilyDetailSections(
              summary: data.summary,
              relationshipId: data.relationship.id,
            ),
            if (data.relationship.isCareRecipient) ...[
              const SizedBox(height: 18),
              FadeSlideIn(
                child: AppCard(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(
                            Icons.admin_panel_settings_outlined,
                            color: AppColors.primary,
                            size: 20,
                          ),
                          SizedBox(width: 8),
                          Text(
                            'Manage permissions',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      _PermissionEditor(
                        relationship: data.relationship,
                        onSaved: _refresh,
                      ),
                    ],
                  ),
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

class FamilyCarePlanScreen extends StatefulWidget {
  const FamilyCarePlanScreen({
    required this.relationshipId,
    required this.planId,
    super.key,
  });

  final String relationshipId;
  final String planId;

  @override
  State<FamilyCarePlanScreen> createState() => _FamilyCarePlanScreenState();
}

class _FamilyCarePlanScreenState extends State<FamilyCarePlanScreen> {
  late Future<FamilyCarePlanDetailData> _future = FamilyCareService.instance
      .fetchFamilyCarePlan(
        relationshipId: widget.relationshipId,
        planId: widget.planId,
      );

  void _refresh() {
    setState(() {
      _future = FamilyCareService.instance.fetchFamilyCarePlan(
        relationshipId: widget.relationshipId,
        planId: widget.planId,
      );
    });
  }

  @override
  Widget build(BuildContext context) => AppShell(
    currentRoute: AppRoutes.familyPlan(widget.relationshipId, widget.planId),
    title: 'Family care plan',
    child: FutureBuilder<FamilyCarePlanDetailData>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const _FamilyLoadingSkeleton();
        }

        if (snapshot.hasError) {
          return _FamilyErrorCard(
            error: snapshot.error.toString(),
            onRetry: _refresh,
          );
        }

        final data = snapshot.data!;
        final instructions = data.instructions;
        final tasks = data.tasks;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: TextButton.icon(
                onPressed: () => Navigator.pushReplacementNamed(
                  context,
                  AppRoutes.caregiver(widget.relationshipId),
                ),
                icon: const Icon(Icons.arrow_back_rounded, size: 18),
                label: const Text('Family member'),
              ),
            ),
            const SizedBox(height: 6),
            FadeSlideIn(
              child: Container(
                padding: const EdgeInsets.all(22),
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
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: const Color(0x20FFFFFF),
                        borderRadius: BorderRadius.circular(AppRadii.xl),
                      ),
                      child: const Icon(
                        Icons.medical_information_outlined,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 13),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            data.planTitle,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 23,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            '${data.relationship.memberName} · Read-only Family Care view',
                            style: const TextStyle(
                              color: Color(0xE6FFFFFF),
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 10),
                          _StatusPill(label: data.planStatus, inverted: true),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 18),
            FadeSlideIn(
              delay: const Duration(milliseconds: 60),
              child: _familyPlanSection(
                icon: Icons.verified_outlined,
                title: 'Verified instructions',
                child: instructions.isEmpty
                    ? const Text(
                        'No verified instructions are visible for this plan.',
                        style: TextStyle(color: AppColors.muted),
                      )
                    : Column(
                        children: instructions.map((item) {
                          final timing = _text(item['timing']);
                          return _SimpleRow(
                            title: _text(item['title']),
                            detail: [
                              _text(item['instruction']),
                              if (timing.isNotEmpty) timing,
                            ].where((value) => value.isNotEmpty).join(' · '),
                          );
                        }).toList(),
                      ),
              ),
            ),
            const SizedBox(height: 14),
            FadeSlideIn(
              delay: const Duration(milliseconds: 90),
              child: _familyPlanSection(
                icon: Icons.calendar_month_outlined,
                title: 'Schedule',
                child: !data.scheduleAllowed
                    ? Text(
                        'Permission required: ${data.scheduleRequiredScope}',
                        style: const TextStyle(color: AppColors.muted),
                      )
                    : tasks.isEmpty
                    ? const Text(
                        'No schedule rows are visible for this plan.',
                        style: TextStyle(color: AppColors.muted),
                      )
                    : Column(
                        children: tasks.map((item) {
                          final time = _text(item['task_time']).isEmpty
                              ? _text(item['display_time'])
                              : _text(item['task_time']);
                          final note = _text(item['note']);
                          final status = _text(item['status']);
                          return _SimpleRow(
                            title: _text(item['title']),
                            detail: [
                              if (time.isNotEmpty) time,
                              if (note.isNotEmpty) note,
                              if (status.isNotEmpty) status,
                            ].join(' · '),
                          );
                        }).toList(),
                      ),
              ),
            ),
            const SizedBox(height: 18),
            const SafetyNote(
              text:
                  'This Family Care plan view is read-only. It does not allow reminder, dose, prescription or verified-instruction changes.',
            ),
          ],
        );
      },
    ),
  );

  Widget _familyPlanSection({
    required IconData icon,
    required String title,
    required Widget child,
  }) {
    return AppCard(
      padding: const EdgeInsets.all(17),
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
                  borderRadius: BorderRadius.circular(AppRadii.lg),
                ),
                child: Icon(icon, size: 19, color: AppColors.primary),
              ),
              const SizedBox(width: 10),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _FamilyDetailSections extends StatelessWidget {
  const _FamilyDetailSections({
    required this.summary,
    required this.relationshipId,
  });

  final FamilySummary summary;
  final String relationshipId;

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
                      onTap: _text(item['id']).isEmpty
                          ? null
                          : () => Navigator.pushNamed(
                              context,
                              AppRoutes.familyPlan(
                                relationshipId,
                                _text(item['id']),
                              ),
                            ),
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
      child: FadeSlideIn(
        child: AppCard(
          padding: const EdgeInsets.all(16),
          borderColor: allowed
              ? AppColors.border
              : AppColors.warning.withValues(alpha: .18),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: allowed
                      ? AppColors.primaryLight
                      : AppColors.warningSoft,
                  borderRadius: BorderRadius.circular(AppRadii.xl),
                ),
                child: Icon(
                  icon,
                  size: 20,
                  color: allowed
                      ? AppColors.primary
                      : AppColors.warningForeground,
                ),
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
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 7),
                    if (allowed)
                      builder(section)
                    else
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.warningSoft,
                          borderRadius: BorderRadius.circular(AppRadii.lg),
                        ),
                        child: Text(
                          'Permission required: ${_text(section['requiredScope'])}',
                          style: const TextStyle(
                            color: AppColors.warningForeground,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
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
        showCheckmark: true,
        avatar: Icon(
          selected ? Icons.check_circle_outline_rounded : Icons.circle_outlined,
          size: 15,
        ),
        label: Text(scope.label),
        side: BorderSide(
          color: selected
              ? AppColors.primary.withValues(alpha: .24)
              : AppColors.border,
        ),
        selectedColor: AppColors.primaryLight,
        backgroundColor: const Color(0xFFF8FAFC),
        onSelected: (value) {
          scopes[scope.key] = value;
          onChanged();
        },
      );
    }).toList(),
  );
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.label, this.inverted = false});

  final String label;
  final bool inverted;

  @override
  Widget build(BuildContext context) {
    final attention = label.toLowerCase().contains('attention');

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: inverted
            ? const Color(0x20FFFFFF)
            : attention
            ? AppColors.warningSoft
            : AppColors.successSoft,
        borderRadius: BorderRadius.circular(999),
        border: inverted ? Border.all(color: const Color(0x28FFFFFF)) : null,
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: inverted
              ? Colors.white
              : attention
              ? AppColors.warningForeground
              : AppColors.successForeground,
          fontSize: 10,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}



class _SimpleRow extends StatelessWidget {
  const _SimpleRow({required this.title, required this.detail, this.onTap});

  final String title;
  final String detail;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final child = Container(
      margin: const EdgeInsets.only(top: 7),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: onTap == null
            ? const Color(0xFFF8FAFC)
            : AppColors.primaryLight.withValues(alpha: .55),
        borderRadius: BorderRadius.circular(AppRadii.lg),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            onTap == null
                ? Icons.chevron_right_rounded
                : Icons.open_in_new_rounded,
            size: 17,
            color: onTap == null ? AppColors.muted : AppColors.primary,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title.isEmpty ? 'Care item' : title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (detail.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    detail,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.muted,
                      fontSize: 11,
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

    if (onTap == null) return child;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadii.lg),
        child: child,
      ),
    );
  }
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
