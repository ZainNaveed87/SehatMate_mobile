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
import '../models/agent_response.dart';
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
    this.voiceService,
  });

  final AgentScreenArgs? args;
  final AgentController? controller;
  final AgentNavigationHandler navigationHandler;
  final AgentVoiceClient? voiceService;

  @override
  State<AgentScreen> createState() => _AgentScreenState();
}

class _AgentScreenState extends State<AgentScreen> with WidgetsBindingObserver {
  late final AgentController _controller;
  late final bool _ownsController;
  late final AgentVoiceClient _voiceService;
  late final bool _ownsVoiceService;
  final _composer = TextEditingController();
  final _scroll = ScrollController();
  final _focus = FocusNode();
  AgentVoiceUiState _voiceState = AgentVoiceUiState.idle;
  bool _finishingVoiceCapture = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _ownsController = widget.controller == null;
    _controller =
        widget.controller ??
        AgentController(
          client: AgentServiceClient(AgentService.instance),
          context: widget.args?.context,
        );
    _controller.addListener(_onControllerChanged);
    _controller.initialize();
    _ownsVoiceService = widget.voiceService == null;
    _voiceService = widget.voiceService ?? AgentVoiceService.instance;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_voiceService.cancelListening());
    unawaited(_voiceService.stopSpeaking());
    if (_ownsVoiceService) unawaited(_voiceService.dispose());
    _controller.removeListener(_onControllerChanged);
    if (_ownsController) _controller.dispose();
    _composer.dispose();
    _scroll.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) return;
    unawaited(_voiceService.cancelListening());
    unawaited(_voiceService.stopSpeaking());
    if (mounted && _voiceState != AgentVoiceUiState.idle) {
      setState(() => _voiceState = AgentVoiceUiState.idle);
    }
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
        _controller.confirmationLoading ||
        _controller.clarificationLoading) {
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
      _finishingVoiceCapture;

  Future<void> _toggleVoice() async {
    if (_voiceState == AgentVoiceUiState.recording) {
      await _completeVoiceCapture();
      return;
    }
    if (_voiceBusy ||
        _controller.loading ||
        _controller.confirmationLoading ||
        _controller.clarificationLoading) {
      return;
    }

    final language = context.appLanguage;
    await _voiceService.stopSpeaking();
    final available = await _voiceService.initializeSpeech(language);
    if (!mounted) return;
    if (!available) {
      _showVoiceMessage(context.tr('agent_voice_error'));
      setState(() => _voiceState = AgentVoiceUiState.error);
      return;
    }

    try {
      setState(() => _voiceState = AgentVoiceUiState.recording);
      await _voiceService.startListening(
        language: language,
        onListeningComplete: () => unawaited(_completeVoiceCapture()),
      );
      if (!mounted) return;
    } catch (_) {
      if (!mounted) return;
      _showVoiceMessage(context.tr('agent_voice_error'));
      setState(() => _voiceState = AgentVoiceUiState.error);
    }
  }

  Future<void> _completeVoiceCapture() async {
    if (_voiceState != AgentVoiceUiState.recording || _finishingVoiceCapture) {
      return;
    }
    _finishingVoiceCapture = true;
    setState(() => _voiceState = AgentVoiceUiState.transcribing);

    try {
      final transcript = await _voiceService.stopListening();
      if (!mounted) return;
      final text = transcript.text.trim();
      if (text.isEmpty) {
        _showVoiceMessage(context.tr('agent_voice_no_speech'));
        setState(() => _voiceState = AgentVoiceUiState.error);
        return;
      }

      setState(() => _voiceState = AgentVoiceUiState.processing);
      final response = await _controller.sendText(text);
      if (!mounted) return;
      if (response == null || response.reply.trim().isEmpty) {
        setState(() => _voiceState = AgentVoiceUiState.idle);
        return;
      }
      final reply = response.reply;

      setState(() => _voiceState = AgentVoiceUiState.speaking);
      try {
        await _voiceService.speak(
          reply,
          language: AppLanguageX.fromStorage(response.language),
        );
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
      _finishingVoiceCapture = false;
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
                      _controller.clarificationLoading ||
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
    final pendingClarificationId =
        _controller.pendingClarification?.clarificationId;
    String? latestActiveConfirmationMessageId;
    String? latestActiveClarificationMessageId;
    if (pendingConfirmationId != null) {
      for (final message in messages) {
        if (message.author == AgentMessageAuthor.assistant &&
            message.confirmation?.confirmationId == pendingConfirmationId) {
          latestActiveConfirmationMessageId = message.id;
        }
      }
    }
    if (pendingClarificationId != null) {
      for (final message in messages) {
        if (message.author == AgentMessageAuthor.assistant &&
            message.clarification?.clarificationId == pendingClarificationId) {
          latestActiveClarificationMessageId = message.id;
        }
      }
    }

    return ListView(
      controller: _scroll,
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 18),
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
            clarificationLoading: _controller.clarificationLoading,
            currentConfirmationId: pendingConfirmationId,
            currentClarificationId: pendingClarificationId,
            activeConfirmationMessageId: latestActiveConfirmationMessageId,
            activeClarificationMessageId: latestActiveClarificationMessageId,
            onConfirm: _controller.confirmPendingAction,
            onCancel: _controller.cancelPendingAction,
            onChooseClarification: _controller.chooseClarificationOption,
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
      margin: const EdgeInsets.fromLTRB(12, 10, 12, 4),
      padding: const EdgeInsets.fromLTRB(8, 9, 12, 9),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppRadii.xl),
        border: Border.all(color: const Color(0xFFDCE8E6)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x120F172A),
            blurRadius: 18,
            spreadRadius: -8,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          IconButton(
            tooltip: context.tr('back'),
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back_rounded),
          ),
          const SizedBox(width: 4),
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF0F766E), Color(0xFF14B8A6)],
              ),
              borderRadius: BorderRadius.circular(AppRadii.lg),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x260F766E),
                  blurRadius: 14,
                  spreadRadius: -6,
                  offset: Offset(0, 7),
                ),
              ],
            ),
            child: const Icon(
              Icons.auto_awesome_rounded,
              color: Colors.white,
              size: 20,
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
                    fontWeight: FontWeight.w800,
                    letterSpacing: -.2,
                  ),
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    Container(
                      width: 7,
                      height: 7,
                      decoration: const BoxDecoration(
                        color: AppColors.success,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.muted,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: AppColors.primaryLight,
              borderRadius: BorderRadius.circular(AppRadii.md),
            ),
            child: const Icon(
              Icons.shield_outlined,
              color: AppColors.primary,
              size: 17,
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

    return FadeSlideIn(
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFF1FAF8), Color(0xFFFFFFFF)],
          ),
          borderRadius: BorderRadius.circular(AppRadii.xxl),
          border: Border.all(color: const Color(0xFFDCEAE7)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x100F172A),
              blurRadius: 24,
              spreadRadius: -10,
              offset: Offset(0, 12),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF0F766E), Color(0xFF14B8A6)],
                    ),
                    borderRadius: BorderRadius.circular(AppRadii.xl),
                  ),
                  child: const Icon(
                    Icons.auto_awesome_rounded,
                    color: Colors.white,
                    size: 23,
                  ),
                ),
                const SizedBox(width: 13),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        context.tr('agent_empty_title'),
                        style: const TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -.25,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        context.tr('agent_empty_desc'),
                        style: const TextStyle(
                          color: AppColors.muted,
                          fontSize: 13,
                          height: 1.45,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(height: 1),
            const SizedBox(height: 13),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (var i = 0; i < suggestions.length; i++)
                  ActionChip(
                    avatar: Icon(
                      switch (i) {
                        0 => Icons.insights_outlined,
                        1 => Icons.next_plan_outlined,
                        2 => Icons.warning_amber_rounded,
                        3 => Icons.analytics_outlined,
                        _ => Icons.tune_rounded,
                      },
                      size: 16,
                      color: AppColors.primary,
                    ),
                    label: Text(suggestions[i]),
                    backgroundColor: Colors.white,
                    side: const BorderSide(color: Color(0xFFD9E7E4)),
                    labelStyle: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                    onPressed: enabled
                        ? () => onSuggestion(suggestions[i])
                        : null,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({
    required this.message,
    required this.navigationHandler,
    required this.confirmationLoading,
    required this.clarificationLoading,
    required this.currentConfirmationId,
    required this.currentClarificationId,
    required this.activeConfirmationMessageId,
    required this.activeClarificationMessageId,
    required this.onConfirm,
    required this.onCancel,
    required this.onChooseClarification,
  });

  final AgentChatMessage message;
  final AgentNavigationHandler navigationHandler;
  final bool confirmationLoading;
  final bool clarificationLoading;
  final String? currentConfirmationId;
  final String? currentClarificationId;
  final String? activeConfirmationMessageId;
  final String? activeClarificationMessageId;
  final ValueChanged<String> onConfirm;
  final ValueChanged<String> onCancel;
  final void Function(String clarificationId, String choiceId)
  onChooseClarification;

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
              : MediaQuery.sizeOf(context).width * .86,
        ),
        margin: EdgeInsetsDirectional.only(
          start: isUser ? 36 : 0,
          end: isUser ? 0 : 36,
          bottom: 12,
        ),
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        decoration: BoxDecoration(
          gradient: isUser
              ? const LinearGradient(
                  colors: [Color(0xFF0F766E), Color(0xFF0D9488)],
                )
              : null,
          color: isUser ? null : AppColors.card,
          border: Border.all(
            color: message.failed
                ? AppColors.criticalSoft
                : isUser
                ? const Color(0x00000000)
                : const Color(0xFFDCE7E5),
          ),
          borderRadius: BorderRadiusDirectional.only(
            topStart: Radius.circular(AppRadii.xl),
            topEnd: Radius.circular(AppRadii.xl),
            bottomStart: Radius.circular(isUser ? AppRadii.xl : 6),
            bottomEnd: Radius.circular(isUser ? 6 : AppRadii.xl),
          ),
          boxShadow: [
            BoxShadow(
              color: isUser ? const Color(0x1F0F766E) : const Color(0x0D0F172A),
              blurRadius: 16,
              spreadRadius: -8,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!isUser) ...[
              const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.auto_awesome_rounded,
                    size: 13,
                    color: AppColors.primary,
                  ),
                  SizedBox(width: 5),
                  Text(
                    'AI',
                    style: TextStyle(
                      color: AppColors.primary,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: .6,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 7),
            ],
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
                icon: const Icon(Icons.refresh_rounded, size: 17),
                label: Text(context.tr('retry')),
              ),
            ] else if (showOpen) ...[
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: () =>
                    navigationHandler.navigate(context, navigation),
                icon: const Icon(Icons.open_in_new_rounded, size: 17),
                label: Text(context.tr('open')),
              ),
            ],
            if (!isUser && message.clarification != null) ...[
              const SizedBox(height: 10),
              _ClarificationCard(
                messageId: message.id,
                clarification: message.clarification!,
                active:
                    message.clarification!.clarificationId ==
                        currentClarificationId &&
                    message.id == activeClarificationMessageId,
                loading: clarificationLoading,
                onChoose: onChooseClarification,
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

class _ClarificationCard extends StatelessWidget {
  const _ClarificationCard({
    required this.messageId,
    required this.clarification,
    required this.active,
    required this.loading,
    required this.onChoose,
  });

  final String messageId;
  final AgentClarification clarification;
  final bool active;
  final bool loading;
  final void Function(String clarificationId, String choiceId) onChoose;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: ValueKey(
        'agent_clarification_card_${messageId}_${clarification.clarificationId}',
      ),
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
            clarification.question,
            style: const TextStyle(fontWeight: FontWeight.w700, height: 1.35),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final option in clarification.options)
                OutlinedButton.icon(
                  key: ValueKey(
                    'agent_clarification_choice_${messageId}_${clarification.clarificationId}_${option.choiceId}',
                  ),
                  onPressed: active && !loading
                      ? () => onChoose(
                          clarification.clarificationId,
                          option.choiceId,
                        )
                      : null,
                  icon: loading
                      ? const SizedBox(
                          width: 15,
                          height: 15,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.check_circle_outline, size: 17),
                  label: Text(option.label),
                ),
            ],
          ),
        ],
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
        9,
        12,
        9 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      decoration: const BoxDecoration(
        color: Color(0xFFF8FBFA),
        border: Border(top: BorderSide(color: Color(0xFFDDE8E6))),
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
            Container(
              padding: const EdgeInsets.fromLTRB(6, 5, 5, 5),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(AppRadii.xl),
                border: Border.all(color: const Color(0xFFD6E4E1)),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x100F172A),
                    blurRadius: 18,
                    spreadRadius: -9,
                    offset: Offset(0, 8),
                  ),
                ],
              ),
              child: Row(
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
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        disabledBorder: InputBorder.none,
                        filled: false,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 11,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  IconButton.filledTonal(
                    key: const ValueKey('agent_mic_button'),
                    tooltip: _voiceTooltip(context, voiceState),
                    onPressed:
                        loading && voiceState != AgentVoiceUiState.recording
                        ? null
                        : onVoice,
                    icon: _voiceIcon(voiceState),
                  ),
                  const SizedBox(width: 5),
                  ValueListenableBuilder<TextEditingValue>(
                    valueListenable: controller,
                    builder: (context, value, _) {
                      final canSend =
                          value.text.trim().isNotEmpty &&
                          !loading &&
                          !voiceBusy;
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
