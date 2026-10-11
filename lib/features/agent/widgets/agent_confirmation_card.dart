import 'package:flutter/material.dart';
import '../../../core/app_theme.dart';
import '../../../localization/language_scope.dart';
import '../voice/voice_companion_controller.dart';

/// A view of the existing authoritative confirmation, never a new transaction.
class AgentPendingConfirmation extends StatelessWidget {
  const AgentPendingConfirmation({super.key, required this.voice,
    required this.surface, this.allowConfirm = true, this.carePlanOnly = false,
    this.showMessage = true});
  final VoiceCompanionController voice;
  final String surface;
  final bool allowConfirm, carePlanOnly, showMessage;
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: Listenable.merge([voice, voice.agent]),
    builder: (context, _) {
      final agent = voice.agent, pending = agent.pendingConfirmation;
      if (pending == null) return const SizedBox.shrink();
      final task = agent.taskWorkflow;
      if (carePlanOnly && (pending.kind != 'create_care_plan' ||
          task?.status != 'awaiting_confirmation' ||
          task?.confirmationId != pending.confirmationId)) {
        return const SizedBox.shrink();
      }
      final inVoice = voice.voiceSessionId != null;
      final busy = agent.loading || agent.confirmationLoading ||
          agent.clarificationLoading || (inVoice && !voice.canResolveConfirmation);
      return Padding(
        key: ValueKey('${surface}_pending_confirmation'),
        padding: const EdgeInsets.only(top: 12),
        child: AgentConfirmationCard(
          messageId: 'pending', confirmationId: pending.confirmationId,
          message: pending.message, kind: pending.kind, active: true,
          loading: busy, allowConfirm: allowConfirm, showMessage: showMessage,
          buttonKeyPrefix: '${surface}_confirmation',
          onConfirm: (id) => inVoice ? voice.confirm(id, true) : agent.confirmPendingAction(id),
          onCancel: (id) => inVoice ? voice.confirm(id, false) : agent.cancelPendingAction(id),
        ),
      );
    },
  );
}

class AgentConfirmationCard extends StatelessWidget {
  const AgentConfirmationCard({
    super.key,
    required this.messageId,
    required this.confirmationId,
    required this.message,
    required this.kind,
    required this.active,
    required this.loading,
    required this.onConfirm,
    required this.onCancel,
    this.allowConfirm = true,
    this.showMessage = true,
    this.buttonKeyPrefix,
  });

  final String messageId;
  final String confirmationId;
  final String message;
  final String kind;
  final bool active;
  final bool allowConfirm;
  final bool showMessage;
  final String? buttonKeyPrefix;
  final bool loading;
  final ValueChanged<String> onConfirm;
  final ValueChanged<String> onCancel;

  @override
  Widget build(BuildContext context) {
    final titleKey = kind == 'schedule_time'
        ? 'agent_review_reminder_time'
        : 'agent_review_change';
    return Container(
      key: ValueKey('agent_confirmation_card_${messageId}_$confirmationId'),
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.primaryLight,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(AppRadii.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.tr(titleKey),
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          if (showMessage) ...[
            const SizedBox(height: 8),
            Text(message, style: const TextStyle(height: 1.35)),
          ],
          const SizedBox(height: 6),
          Text(
            context.tr('agent_nothing_changed_yet'),
            style: const TextStyle(color: AppColors.muted, fontSize: 13),
          ),
          if (kind == 'schedule_time') ...[
            const SizedBox(height: 6),
            Text(
              context.tr('agent_schedule_medical_recheck'),
              style: const TextStyle(color: AppColors.muted, fontSize: 13),
            ),
          ],
          const SizedBox(height: 10),
          Wrap(
            alignment: WrapAlignment.end,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              TextButton(
                key: ValueKey(buttonKeyPrefix == null ? 'agent_cancel_${messageId}_$confirmationId' : '${buttonKeyPrefix}_cancel'),
                onPressed: active && !loading
                    ? () => onCancel(confirmationId)
                    : null,
                child: Text(context.tr('cancel')),
              ),
              const SizedBox(width: 8),
              FilledButton.icon(
                key: ValueKey(buttonKeyPrefix == null ? 'agent_confirm_${messageId}_$confirmationId' : '${buttonKeyPrefix}_confirm'),
                onPressed: active && !loading && allowConfirm
                    ? () => onConfirm(confirmationId)
                    : null,
                icon: loading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.check, size: 17),
                label: Text(context.tr('agent_confirm_action')),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
