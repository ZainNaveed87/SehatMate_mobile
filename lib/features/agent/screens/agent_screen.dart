import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/app_theme.dart';
import '../../../localization/app_language.dart';
import '../../../localization/language_scope.dart';
import '../../../services/auth_service.dart';
import '../../../widgets/ui.dart';
import '../agent_entry.dart';
import '../controllers/agent_controller.dart';
import '../models/agent_message.dart';
import '../navigation/agent_navigation_handler.dart';
import '../services/agent_service.dart';
import '../services/agent_voice_service.dart';

enum AgentVoiceUiState {
  idle,
  recording,
  transcribing,
  processing,
  speaking,
  error,
}

class AgentScreen extends StatefulWidget {
  const AgentScreen({
    super.key,
    this.args,
    this.controller,
    this.navigationHandler = const AgentNavigationHandler(),
    this.voiceRecorder,
    this.voiceTranscriber,
    this.voicePlayer,
  });

  final AgentScreenArgs? args;
  final AgentController? controller;
  final AgentNavigationHandler navigationHandler;
  final AgentVoiceRecorder? voiceRecorder;
  final AgentVoiceTranscriber? voiceTranscriber;
  final AgentVoicePlayer? voicePlayer;

  @override
  State<AgentScreen> createState() => _AgentScreenState();
}

class _AgentScreenState extends State<AgentScreen> {
  late final AgentController _controller;
  late final bool _ownsController;
  late final AgentVoiceRecorder _voiceRecorder;
  late final AgentVoiceTranscriber _voiceTranscriber;
  late final AgentVoicePlayer _voicePlayer;
  late final bool _ownsVoiceRecorder;
  late final bool _ownsVoicePlayer;
  final _composer = TextEditingController();
  final _scroll = ScrollController();
  final _focus = FocusNode();
  AgentVoiceUiState _voiceState = AgentVoiceUiState.idle;
  bool _stoppingRecording = false;

  @override
  void initState() {
    super.initState();
    _ownsController = widget.controller == null;
    _controller =
        widget.controller ??
        AgentController(
          client: AgentServiceClient(AgentService.instance),
          context: widget.args?.context,
        );
    _controller.addListener(_onControllerChanged);
    _controller.initialize();
    _ownsVoiceRecorder = widget.voiceRecorder == null;
    _ownsVoicePlayer = widget.voicePlayer == null;
    _voiceRecorder = widget.voiceRecorder ?? RecordAgentVoiceRecorder();
    _voiceTranscriber = widget.voiceTranscriber ?? AgentVoiceService.instance;
    _voicePlayer = widget.voicePlayer ?? AudioPlayersAgentVoicePlayer();
  }

  @override
  void dispose() {
    if (_voiceState == AgentVoiceUiState.recording) {
      unawaited(_voiceRecorder.stop());
    }
    unawaited(_voicePlayer.stop());
    if (_ownsVoiceRecorder) unawaited(_voiceRecorder.dispose());
    if (_ownsVoicePlayer) unawaited(_voicePlayer.dispose());
    _controller.removeListener(_onControllerChanged);
    if (_ownsController) _controller.dispose();
    _composer.dispose();
    _scroll.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _onControllerChanged() {
    if (!mounted) return;
    setState(() {});
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToEnd());
  }

  void _scrollToEnd() {
    if (!_scroll.hasClients) return;
    _scroll.animateTo(
      _scroll.position.maxScrollExtent,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
    );
  }

  Future<void> _send([String? override]) async {
    final text = (override ?? _composer.text).trim();
    if (text.isEmpty ||
        _controller.loading ||
        _controller.confirmationLoading) {
      return;
    }
    _composer.clear();
    await _controller.sendText(text);
  }

  Future<void> _retry() async {
    await _controller.retryLast();
  }

  bool get _voiceBusy =>
      _voiceState == AgentVoiceUiState.recording ||
      _voiceState == AgentVoiceUiState.transcribing ||
      _voiceState == AgentVoiceUiState.processing ||
      _voiceState == AgentVoiceUiState.speaking ||
      _stoppingRecording;

  Future<void> _toggleVoice() async {
    if (_voiceState == AgentVoiceUiState.recording) {
      await _stopVoiceRecording();
      return;
    }
    if (_voiceBusy || _controller.loading || _controller.confirmationLoading) {
      return;
    }

    await _voicePlayer.stop();
    final allowed = await _voiceRecorder.hasPermission();
    if (!mounted) return;
    if (!allowed) {
      _showVoiceMessage(context.tr('agent_voice_permission_denied'));
      setState(() => _voiceState = AgentVoiceUiState.error);
      return;
    }

    try {
      await _voiceRecorder.start();
      if (!mounted) return;
      setState(() => _voiceState = AgentVoiceUiState.recording);
    } catch (_) {
      if (!mounted) return;
      _showVoiceMessage(context.tr('agent_voice_error'));
      setState(() => _voiceState = AgentVoiceUiState.error);
    }
  }

  Future<void> _stopVoiceRecording() async {
    if (_voiceState != AgentVoiceUiState.recording || _stoppingRecording) {
      return;
    }
    _stoppingRecording = true;
    setState(() => _voiceState = AgentVoiceUiState.transcribing);

    try {
      final recording = await _voiceRecorder.stop();
      if (!mounted) return;
      if (recording == null || recording.duration <= Duration.zero) {
        _showVoiceMessage(context.tr('agent_voice_no_speech'));
        setState(() => _voiceState = AgentVoiceUiState.error);
        return;
      }

      final transcript = await _voiceTranscriber.transcribe(recording);
      if (!mounted) return;
      final text = transcript.text.trim();
      if (text.isEmpty) {
        _showVoiceMessage(context.tr('agent_voice_no_speech'));
        setState(() => _voiceState = AgentVoiceUiState.error);
        return;
      }

      setState(() => _voiceState = AgentVoiceUiState.processing);
      final response = await _controller.sendText(text, requestSpeech: true);
      if (!mounted) return;
      final speech = response?.speech;
      if (speech == null) {
        setState(() => _voiceState = AgentVoiceUiState.idle);
        return;
      }

      setState(() => _voiceState = AgentVoiceUiState.speaking);
      try {
        await _voicePlayer.play(speech);
      } catch (_) {
        if (mounted) _showVoiceMessage(context.tr('agent_voice_tts_error'));
      }
      if (mounted) setState(() => _voiceState = AgentVoiceUiState.idle);
    } on AgentException catch (error) {
      if (!mounted) return;
      _showVoiceMessage(
        error.code == AgentErrorCode.noSpeech
            ? context.tr('agent_voice_no_speech')
            : context.tr('agent_voice_error'),
      );
      setState(() => _voiceState = AgentVoiceUiState.error);
    } catch (_) {
      if (!mounted) return;
      _showVoiceMessage(context.tr('agent_voice_error'));
      setState(() => _voiceState = AgentVoiceUiState.error);
    } finally {
      _stoppingRecording = false;
    }
  }

  void _showVoiceMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final language = context.appLanguage;

    return Directionality(
      textDirection: language.textDirection,
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          child: Column(
            children: [
              _AgentHeader(
                title: context.tr('agent_title'),
                subtitle: context.tr('agent_status_subtitle'),
              ),
              Expanded(
                child: AuthSession.instance.isAuthenticated
                    ? _conversation()
                    : _unavailableAuth(),
              ),
              if (AuthSession.instance.isAuthenticated)
                _Composer(
                  controller: _composer,
                  focusNode: _focus,
                  loading:
                      _controller.loading ||
                      _controller.confirmationLoading ||
                      !_controller.initialized,
                  voiceState: _voiceState,
                  voiceBusy: _voiceBusy,
                  onVoice: _toggleVoice,
                  onSend: () => _send(),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _conversation() {
    final messages = _controller.messages;
    final pendingConfirmationId =
        _controller.pendingConfirmation?.confirmationId;
    String? latestActiveConfirmationMessageId;
    if (pendingConfirmationId != null) {
      for (final message in messages) {
        if (message.author == AgentMessageAuthor.assistant &&
            message.confirmation?.confirmationId == pendingConfirmationId) {
          latestActiveConfirmationMessageId = message.id;
        }
      }
    }

    return ListView(
      controller: _scroll,
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
      children: [
        SafetyNote(text: context.tr('agent_safety_note')),
        const SizedBox(height: 18),
        if (messages.isEmpty)
          _EmptyAgentState(
            enabled: _controller.initialized && !_controller.loading,
            onSuggestion: _send,
          ),
        ...messages.map(
          (message) => _MessageBubble(
            message: message,
            navigationHandler: widget.navigationHandler,
            confirmationLoading: _controller.confirmationLoading,
            currentConfirmationId: pendingConfirmationId,
            activeConfirmationMessageId: latestActiveConfirmationMessageId,
            onConfirm: _controller.confirmPendingAction,
            onCancel: _controller.cancelPendingAction,
          ),
        ),
        if (_controller.loading || _controller.initializing)
          const _TypingBubble(),
      ],
    );
  }

  Widget _unavailableAuth() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: EmptyState(
          icon: Icons.lock_outline,
          title: context.tr('agent_sign_in_required_title'),
          description: context.tr('agent_sign_in_required_desc'),
        ),
      ),
    );
  }
}

class _AgentHeader extends StatelessWidget {
  const _AgentHeader({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 68,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: const BoxDecoration(
        color: AppColors.card,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          IconButton(
            tooltip: context.tr('back'),
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back),
          ),
          const SizedBox(width: 4),
          const CircleAvatar(
            radius: 18,
            backgroundColor: AppColors.primaryLight,
            child: Icon(
              Icons.auto_awesome_outlined,
              color: AppColors.primary,
              size: 19,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  maxLines: 1,
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
}

class _EmptyAgentState extends StatelessWidget {
  const _EmptyAgentState({required this.enabled, required this.onSuggestion});

  final bool enabled;
  final ValueChanged<String> onSuggestion;

  @override
  Widget build(BuildContext context) {
    final suggestions = switch (context.appLanguage) {
      AppLanguage.english => const [
        'How is my performance?',
        'What is my next task?',
        'Show my care gaps.',
        'Explain my simulation.',
        'Open routine settings.',
      ],
      AppLanguage.urdu => const [
        'میری کارکردگی کیسی ہے؟',
        'آج میرا اگلا کام کیا ہے؟',
        'میرے کیئر گیپس دکھائیں۔',
        'میری سیمیولیشن سمجھائیں۔',
        'روٹین سیٹنگز کھولیں۔',
      ],
      AppLanguage.romanUrdu => const [
        'Meri performance kesi hai?',
        'Aaj mera next task kya hai?',
        'Mere care gaps batao.',
        'Meri simulation samjhao.',
        'Routine settings kholo.',
      ],
    };

    return AppCard(
      padding: const EdgeInsets.all(18),
      radius: AppRadii.xl,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.tr('agent_empty_title'),
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(
            context.tr('agent_empty_desc'),
            style: const TextStyle(color: AppColors.muted, fontSize: 14),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final suggestion in suggestions)
                ActionChip(
                  avatar: const Icon(Icons.north_east, size: 16),
                  label: Text(suggestion),
                  onPressed: enabled ? () => onSuggestion(suggestion) : null,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({
    required this.message,
    required this.navigationHandler,
    required this.confirmationLoading,
    required this.currentConfirmationId,
    required this.activeConfirmationMessageId,
    required this.onConfirm,
    required this.onCancel,
  });

  final AgentChatMessage message;
  final AgentNavigationHandler navigationHandler;
  final bool confirmationLoading;
  final String? currentConfirmationId;
  final String? activeConfirmationMessageId;
  final ValueChanged<String> onConfirm;
  final ValueChanged<String> onCancel;

  @override
  Widget build(BuildContext context) {
    final isUser = message.author == AgentMessageAuthor.user;
    final alignment = isUser
        ? AlignmentDirectional.centerEnd
        : AlignmentDirectional.centerStart;
    final navigation = message.navigation;
    final showOpen =
        navigation != null && navigationHandler.canNavigate(navigation);

    return Align(
      alignment: alignment,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width >= 620
              ? 520
              : MediaQuery.sizeOf(context).width * .84,
        ),
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        decoration: BoxDecoration(
          color: isUser ? AppColors.primary : AppColors.card,
          border: Border.all(
            color: message.failed ? AppColors.criticalSoft : AppColors.border,
          ),
          borderRadius: BorderRadius.circular(AppRadii.lg),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SelectableText(
              message.failed
                  ? _localizedAgentFailure(context, message.text)
                  : message.text,
              style: TextStyle(
                color: isUser ? Colors.white : AppColors.foreground,
                fontSize: 15,
                height: 1.45,
              ),
            ),
            if (message.failed) ...[
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: () {
                  final state = context
                      .findAncestorStateOfType<_AgentScreenState>();
                  state?._retry();
                },
                icon: const Icon(Icons.refresh, size: 17),
                label: Text(context.tr('retry')),
              ),
            ] else if (showOpen) ...[
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: () =>
                    navigationHandler.navigate(context, navigation),
                icon: const Icon(Icons.open_in_new, size: 17),
                label: Text(context.tr('open')),
              ),
            ],
            if (!isUser && message.confirmation != null) ...[
              const SizedBox(height: 10),
              _ConfirmationCard(
                messageId: message.id,
                confirmationId: message.confirmation!.confirmationId,
                message: message.confirmation!.message,
                kind: message.confirmation!.kind,
                active:
                    message.confirmation!.confirmationId ==
                        currentConfirmationId &&
                    message.id == activeConfirmationMessageId,
                loading: confirmationLoading,
                onConfirm: onConfirm,
                onCancel: onCancel,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ConfirmationCard extends StatelessWidget {
  const _ConfirmationCard({
    required this.messageId,
    required this.confirmationId,
    required this.message,
    required this.kind,
    required this.active,
    required this.loading,
    required this.onConfirm,
    required this.onCancel,
  });

  final String messageId;
  final String confirmationId;
  final String message;
  final String kind;
  final bool active;
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
          const SizedBox(height: 8),
          Text(message, style: const TextStyle(height: 1.35)),
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
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                key: ValueKey('agent_cancel_${messageId}_$confirmationId'),
                onPressed: active && !loading
                    ? () => onCancel(confirmationId)
                    : null,
                child: Text(context.tr('cancel')),
              ),
              const SizedBox(width: 8),
              FilledButton.icon(
                key: ValueKey('agent_confirm_${messageId}_$confirmationId'),
                onPressed: active && !loading
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

String _localizedAgentFailure(BuildContext context, String message) {
  final normalized = message.trim();
  if (normalized == 'Please sign in to continue.') {
    return context.tr('agent_error_auth');
  }
  if (normalized == 'SehatMate AI returned an invalid response.') {
    return context.tr('agent_error_malformed');
  }
  if (normalized ==
      'SehatMate AI is busy right now. Please try again shortly.') {
    return context.tr('agent_error_rate_limited');
  }
  if (normalized.isEmpty ||
      normalized ==
          'SehatMate AI is temporarily unavailable. Please try again.') {
    return context.tr('agent_error_unavailable');
  }
  return normalized;
}

class _TypingBubble extends StatelessWidget {
  const _TypingBubble();

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.card,
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(AppRadii.lg),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: 10),
            Text(
              context.tr('agent_thinking'),
              style: const TextStyle(color: AppColors.muted),
            ),
          ],
        ),
      ),
    );
  }
}

class _Composer extends StatelessWidget {
  const _Composer({
    required this.controller,
    required this.focusNode,
    required this.loading,
    required this.voiceState,
    required this.voiceBusy,
    required this.onVoice,
    required this.onSend,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final bool loading;
  final AgentVoiceUiState voiceState;
  final bool voiceBusy;
  final VoidCallback onVoice;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        12,
        10,
        12,
        10 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      decoration: const BoxDecoration(
        color: AppColors.card,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (voiceState != AgentVoiceUiState.idle) ...[
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: _VoiceStatusPill(state: voiceState),
              ),
              const SizedBox(height: 8),
            ],
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: TextField(
                    key: const ValueKey('agent_composer'),
                    controller: controller,
                    focusNode: focusNode,
                    enabled: !loading && !voiceBusy,
                    minLines: 1,
                    maxLines: 5,
                    maxLength: 2000,
                    textInputAction: TextInputAction.newline,
                    decoration: InputDecoration(
                      counterText: '',
                      hintText: context.tr('agent_input_hint'),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filledTonal(
                  key: const ValueKey('agent_mic_button'),
                  tooltip: _voiceTooltip(context, voiceState),
                  onPressed:
                      loading && voiceState != AgentVoiceUiState.recording
                      ? null
                      : onVoice,
                  icon: _voiceIcon(voiceState),
                ),
                const SizedBox(width: 8),
                ValueListenableBuilder<TextEditingValue>(
                  valueListenable: controller,
                  builder: (context, value, _) {
                    final canSend =
                        value.text.trim().isNotEmpty && !loading && !voiceBusy;
                    return IconButton.filled(
                      tooltip: context.tr('send'),
                      onPressed: canSend ? onSend : null,
                      icon: loading
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.send_outlined),
                    );
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _VoiceStatusPill extends StatelessWidget {
  const _VoiceStatusPill({required this.state});

  final AgentVoiceUiState state;

  @override
  Widget build(BuildContext context) {
    final textKey = switch (state) {
      AgentVoiceUiState.recording => 'agent_voice_recording',
      AgentVoiceUiState.transcribing => 'agent_voice_transcribing',
      AgentVoiceUiState.processing => 'agent_voice_processing',
      AgentVoiceUiState.speaking => 'agent_voice_speaking',
      AgentVoiceUiState.error => 'agent_voice_error_short',
      AgentVoiceUiState.idle => 'agent_voice_idle',
    };
    return Container(
      key: const ValueKey('agent_voice_status'),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.primaryLight,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(AppRadii.md),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (state == AgentVoiceUiState.transcribing ||
              state == AgentVoiceUiState.processing ||
              state == AgentVoiceUiState.speaking) ...[
            const SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: 8),
          ],
          Text(
            context.tr(textKey),
            style: const TextStyle(fontSize: 13, color: AppColors.foreground),
          ),
        ],
      ),
    );
  }
}

Widget _voiceIcon(AgentVoiceUiState state) {
  return switch (state) {
    AgentVoiceUiState.recording => const Icon(Icons.stop),
    AgentVoiceUiState.transcribing ||
    AgentVoiceUiState.processing ||
    AgentVoiceUiState.speaking => const SizedBox(
      width: 18,
      height: 18,
      child: CircularProgressIndicator(strokeWidth: 2),
    ),
    AgentVoiceUiState.error ||
    AgentVoiceUiState.idle => const Icon(Icons.mic_none),
  };
}

String _voiceTooltip(BuildContext context, AgentVoiceUiState state) {
  if (state == AgentVoiceUiState.recording) {
    return context.tr('agent_voice_stop');
  }
  return context.tr('agent_voice_start');
}
