import '../copilot/copilot_conflict.dart';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../widgets/agent_progress_card.dart';
import '../../../widgets/assistant_motion.dart';

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
import '../voice/voice_companion_controller.dart';
import '../voice/voice_companion_scope.dart';
import '../widgets/agent_header.dart';

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
    this.embedded = false,
    this.controller,
    this.navigationHandler = const AgentNavigationHandler(),
    this.voiceService,
    this.scrollController,
    this.onRealtimeVoice,
  });

  final AgentScreenArgs? args;
  final bool embedded;
  final AgentController? controller;
  final AgentNavigationHandler navigationHandler;
  final AgentVoiceClient? voiceService;
  final ScrollController? scrollController;
  final VoidCallback? onRealtimeVoice;

  @override
  State<AgentScreen> createState() => _AgentScreenState();
}

class _AgentScreenState extends State<AgentScreen> with WidgetsBindingObserver {
  late final AgentController _controller;
  late final bool _ownsController;
  late final AgentVoiceClient _voiceService;
  late final bool _ownsVoiceService;
  final _composer = TextEditingController();
  final _ownedScroll = ScrollController();
  ScrollController get _scroll=>widget.scrollController??_ownedScroll;
  int _lastMessageCount=0;
  bool _followNextMessage=false;
  final _focus = FocusNode();
  AgentVoiceUiState _voiceState = AgentVoiceUiState.idle;
  bool _finishingVoiceCapture = false;
  String? _editingMessageId;
  String _draftBeforeEdit = '';
  bool _editSubmitting = false;
  String? _pendingEditId;
  String? _pendingEditText;
  Set<String> _editExistingIds = {};
  final Set<String> _editedMessages = {};
  final Set<String> _replacedMessages = {};
  final Map<String, Key> _responseKeys = {};
  Key _progressKey = UniqueKey();
  bool _requestWasActive = false;
  Set<String> _requestExistingIds = {};
  bool get _requestActive =>
      _controller.requestProgress != AgentRequestProgress.idle;
  bool get _chatBusy =>
      _controller.loading ||
      _controller.confirmationLoading ||
      _controller.clarificationLoading ||
      !_controller.initialized ||
      _voiceBusy ||
      _editSubmitting;
  VoiceCompanionController? _companion;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _companion = VoiceCompanionScope.read(context);
    _ownsController = widget.controller == null && _companion == null;
    _controller =
        widget.controller ??
        _companion?.agent ??
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
    _ownedScroll.dispose();
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
    final messages = _controller.messages;
    final ids = messages.map((message) => message.id).toSet();
    if (_requestActive && !_requestWasActive) {
      _progressKey = UniqueKey();
      _requestExistingIds = ids;
    } else if (!_requestActive && _requestWasActive) {
      final replies = messages.where(
        (message) =>
            message.author == AgentMessageAuthor.assistant &&
            !_requestExistingIds.contains(message.id),
      );
      if (replies.isNotEmpty) _responseKeys[replies.last.id] = _progressKey;
    }
    _requestWasActive = _requestActive;
    if (_pendingEditId != null) {
      final revisions = messages.where(
        (message) =>
            message.author == AgentMessageAuthor.user &&
            !_editExistingIds.contains(message.id) &&
            message.text == _pendingEditText,
      );
      if (revisions.isNotEmpty) {
        _replacedMessages.add(_pendingEditId!);
        _editedMessages.add(revisions.last.id);
        _pendingEditId = null;
      }
    }
    _editedMessages.retainWhere(ids.contains);
    _replacedMessages.retainWhere(ids.contains);
    _responseKeys.removeWhere((id, _) => !ids.contains(id));
    final appended=messages.length>_lastMessageCount;
    final follow=appended && (_followNextMessage || !_scroll.hasClients || _scroll.position.extentAfter<100);
    if(appended)_followNextMessage=false;
    _lastMessageCount=messages.length;
    setState(() {});
    if(follow)WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToEnd());
  }

  void _scrollToEnd({int remainingFrames = 2}) {
    if (!mounted || !_scroll.hasClients) return;
    if (assistantReducedMotion(context)) {
      _scroll.jumpTo(_scroll.position.maxScrollExtent);
      // A lazy list can revise its extent after laying out newly added replies.
      if (remainingFrames > 0) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted &&
              _scroll.hasClients &&
              _scroll.position.extentAfter > 0) {
            _scrollToEnd(remainingFrames: remainingFrames - 1);
          }
        });
      }
      return;
    }
    _scroll.animateTo(
      _scroll.position.maxScrollExtent,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
    );
  }

  @override
  void didChangeMetrics() {
    if (mounted && _focus.hasFocus) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _scrollToEnd();
      });
    }
  }

  Future<void> _send([String? override]) async {
    final text = (override ?? _composer.text).trim();
    if (text.isEmpty ||
        _controller.loading ||
        _controller.confirmationLoading ||
        _controller.clarificationLoading) {
      return;
    }
    if (_editSubmitting) return;
    final editingId = override == null ? _editingMessageId : null;
    if (editingId != null) {
      _editSubmitting = true;
      _pendingEditId = editingId;
      _pendingEditText = text;
      _editExistingIds = _controller.messages
          .map((message) => message.id)
          .toSet();
      setState(() {});
    }
    _followNextMessage=true;
    _composer.clear();
    try {
      if (_companion?.voiceSessionId != null) {
        await _companion!.submitManual(text);
      } else {
        await _controller.sendText(text);
      }
    } finally {
      if (mounted && editingId != null) {
        setState(() {
          _editSubmitting = false;
          if (_pendingEditId == null) {
            _editingMessageId = null;
            _composer.text = _draftBeforeEdit;
            _draftBeforeEdit = '';
          } else {
            _composer.text = text;
          }
          _pendingEditId = null;
          _pendingEditText = null;
        });
      }
    }
  }

  Future<void> _userActions(AgentChatMessage message) async {
    final mayEdit = !_chatBusy;
    _focus.unfocus();
    final action = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: AppColors.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadii.xxl)),
      ),
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: SafeArea(
          top: false,
          child: Column(
            key: const ValueKey('agent_message_actions'),
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                key: const ValueKey('agent_edit_action'),
                enabled: mayEdit,
                leading: const Icon(
                  Icons.edit_outlined,
                  color: AppColors.primary,
                ),
                title: Text(context.tr('agent_edit')),
                onTap: mayEdit ? () => Navigator.pop(context, 'edit') : null,
              ),
              ListTile(
                key: const ValueKey('agent_copy_action'),
                leading: const Icon(
                  Icons.copy_outlined,
                  color: AppColors.primary,
                ),
                title: Text(context.tr('agent_copy')),
                onTap: () => Navigator.pop(context, 'copy'),
              ),
            ],
          ),
        ),
      ),
    );
    if (!mounted) return;
    if (action == 'copy') {
      await Clipboard.setData(ClipboardData(text: message.text));
    } else if (action == 'edit' && !_chatBusy) {
      setState(() {
        if (_editingMessageId == null) _draftBeforeEdit = _composer.text;
        _editingMessageId = message.id;
        _composer.value = TextEditingValue(
          text: message.text,
          selection: TextSelection.collapsed(offset: message.text.length),
        );
      });
      _focus.requestFocus();
    }
  }

  void _cancelEdit() {
    if (_editSubmitting) return;
    setState(() {
      _editingMessageId = null;
      _composer.text = _draftBeforeEdit;
      _draftBeforeEdit = '';
    });
    _focus.requestFocus();
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
    if (_companion != null) {
      _focus.unfocus();
      if (_companion!.state == 'manual') {
        await _companion!.resume();
      } else if (_companion!.enabled) {
        await _companion!.mute();
      } else {
        await _companion!.start(context.appLanguage);
      }
      return;
    }
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
        resizeToAvoidBottomInset: !widget.embedded,
        backgroundColor: AppColors.background,
        body: SafeArea(
          top:!widget.embedded,bottom:!widget.embedded,
          child: LayoutBuilder(
            builder: (context, layout) => Column(
              children: [
                if(!widget.embedded) AssistantEntrance(
                  key: const ValueKey('agent_header_entry'),
                  duration: const Duration(milliseconds: 320),
                  child: AgentHeader(
                    showBack: !widget.embedded,
                    compact: layout.maxHeight < 480,
                    title: context.tr('agent_title'),
                    subtitle: context.tr('agent_status_subtitle'),
                    waitForLanguageChange: _companion == null
                        ? null
                        : () => _companion!.languageChangeComplete,
                  ),
                ),
                Expanded(
                  child: AuthSession.instance.isAuthenticated
                      ? _conversation()
                      : _unavailableAuth(),
                ),
                if (AuthSession.instance.isAuthenticated && !widget.embedded)
                  if (_companion != null) const VoiceCompanionControls(),
                if (AuthSession.instance.isAuthenticated)
                  AssistantEntrance(
                    key: const ValueKey('agent_composer_entry'),
                    duration: const Duration(milliseconds: 420),
                    startFraction: .18,
                    child: _Composer(
                      editingMessage: _editingMessageId != null,
                      onCancelEdit: _editSubmitting ? null : _cancelEdit,
                      // Reserve room for the fixed language header at large
                      // accessibility text sizes, using the existing compact UI.
                      compact:
                          layout.maxHeight /
                              MediaQuery.textScalerOf(context).scale(1) <
                          480,
                      controller: _composer,
                      focusNode: _focus,
                      loading:
                          _controller.loading ||
                          _controller.confirmationLoading ||
                          _controller.clarificationLoading ||
                          !_controller.initialized,
                      voiceState: _voiceState,
                      voiceBusy: _voiceBusy,
                      onVoice: widget.onRealtimeVoice??_toggleVoice,
                      onSend: () => _send(),
                    ),
                  ),
              ],
            ),
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
        AgentSizeTransition(
          child:
              !_controller.initialized ||
                  messages.any(
                    (message) => message.author == AgentMessageAuthor.user,
                  )
              ? const SizedBox.shrink()
              : _EmptyAgentState(
                  key: const ValueKey('agent_welcome'),
                  enabled: _controller.initialized && !_requestActive,
                  onSuggestion: _send,
                ),
        ),
        if(!widget.embedded) Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.shield_outlined,
                size: 16,
                color: AppColors.muted,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  context.tr('agent_safety_note'),
                  style: const TextStyle(
                    fontSize: 12,
                    height: 1.4,
                    color: AppColors.muted,
                  ),
                ),
              ),
            ],
          ),
        ),
        if(_controller.taskWorkflow!=null&&const {'collecting','awaiting_confirmation'}.contains(_controller.taskWorkflow!.status))
          Padding(padding:const EdgeInsets.symmetric(vertical:8),child:Text('${context.tr('agent_task_draft')}${_controller.taskWorkflow!.title==null?'':': ${_controller.taskWorkflow!.title}'}',key:const Key('agent_task_workflow_summary'))),
        for (final conflict in _controller.conflicts)
          CopilotConflictCard(
            conflict: conflict,
            navigationHandler: widget.navigationHandler,
          ),
        ...messages.map((message) {
          final bubble = _MessageBubble(
            key: ValueKey('agent_message_${message.id}'),
            message: message,
            edited: _editedMessages.contains(message.id),
            replaced: _replacedMessages.contains(message.id),
            onUserActions: () => _userActions(message),
            navigationHandler: widget.navigationHandler,
            confirmationLoading: _controller.confirmationLoading,
            clarificationLoading: _controller.clarificationLoading,
            currentConfirmationId: pendingConfirmationId,
            currentClarificationId: pendingClarificationId,
            activeConfirmationMessageId: latestActiveConfirmationMessageId,
            activeClarificationMessageId: latestActiveClarificationMessageId,
            onConfirm: (id) => _companion?.voiceSessionId != null
                ? _companion!.confirm(id, true)
                : _controller.confirmPendingAction(id),
            onCancel: (id) => _companion?.voiceSessionId != null
                ? _companion!.confirm(id, false)
                : _controller.cancelPendingAction(id),
            onChooseClarification: (id, choice) =>
                _companion?.voiceSessionId != null
                ? _companion!.clarify(id, choice)
                : _controller.chooseClarificationOption(id, choice),
          );
          return message.author == AgentMessageAuthor.assistant
              ? AgentReplySlot(
                  key:
                      _responseKeys[message.id] ??
                      ValueKey('agent_reply_${message.id}'),
                  child: bubble,
                )
              : AssistantEntrance(
                  key: ValueKey('agent_motion_${message.id}'),
                  child: bubble,
                );
        }),
        if (_requestActive)
          AgentReplySlot(
            key: _progressKey,
            child: AgentProgressCard(
              key: const ValueKey('agent_request_progress'),
              progress: _controller.requestProgress,
            ),
          ),
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

class _EmptyAgentState extends StatelessWidget {
  const _EmptyAgentState({
    super.key,
    required this.enabled,
    required this.onSuggestion,
  });
  final bool enabled;
  final ValueChanged<String> onSuggestion;
  @override
  Widget build(BuildContext context) {
    final suggestions = switch (context.appLanguage) {
      AppLanguage.english => const [
        'What is my next task?',
        'How is my performance?',
        'Show my care gaps.',
      ],
      AppLanguage.urdu => const [
        'آج میرا اگلا کام کیا ہے؟',
        'میری کارکردگی کیسی ہے؟',
        'میرے کیئر گیپس دکھائیں۔',
      ],
      AppLanguage.romanUrdu => const [
        'Aaj mera next task kya hai?',
        'Meri performance kesi hai?',
        'Mere care gaps batao.',
      ],
    };
    return AssistantEntrance(
      duration: const Duration(milliseconds: 420),
      startFraction: .06,
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFF1FAF8), AppColors.card],
          ),
          borderRadius: BorderRadius.circular(AppRadii.xxl),
          border: Border.all(color: const Color(0xFFDCEAE7)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.primaryLight,
                borderRadius: BorderRadius.circular(AppRadii.lg),
              ),
              child: const Icon(
                Icons.auto_awesome_rounded,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              context.tr('agent_empty_title'),
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                height: 1.25,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              context.tr('agent_empty_desc'),
              style: const TextStyle(
                color: AppColors.muted,
                fontSize: 14,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 18),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (var i = 0; i < suggestions.length; i++)
                  AssistantEntrance(
                    duration: const Duration(milliseconds: 420),
                    startFraction: .15 + i * .12,
                    child: ActionChip(
                      avatar: Icon(
                        [
                          Icons.next_plan_outlined,
                          Icons.insights_outlined,
                          Icons.fact_check_outlined,
                        ][i],
                        size: 16,
                        color: AppColors.primary,
                      ),
                      label: Text(suggestions[i]),
                      backgroundColor: AppColors.card,
                      side: const BorderSide(color: AppColors.border),
                      onPressed: enabled
                          ? () => onSuggestion(suggestions[i])
                          : null,
                    ),
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
    super.key,
    required this.message,
    required this.edited,
    required this.replaced,
    required this.onUserActions,
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
  final bool edited;
  final bool replaced;
  final VoidCallback onUserActions;
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
      child: GestureDetector(
        onLongPress: isUser ? onUserActions : null,
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
            color: isUser ? null : const Color(0xFFF5FBF9),
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
                color: isUser
                    ? const Color(0x1F0F766E)
                    : const Color(0x0D0F172A),
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
              if (isUser)
                Text(
                  message.text,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    height: 1.45,
                  ),
                )
              else
                SelectableText(
                  message.failed
                      ? _localizedAgentFailure(context, message.failureCode)
                      : message.text,
                  style: const TextStyle(
                    color: AppColors.foreground,
                    fontSize: 15,
                    height: 1.45,
                  ),
                ),
              if (isUser && (edited || replaced))
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    context.tr(
                      replaced ? 'agent_replaced_locally' : 'agent_edited',
                    ),
                    style: const TextStyle(color: Colors.white, fontSize: 12),
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

String _localizedAgentFailure(BuildContext context, String? code) {
  return context.tr(switch (code) {
    'unauthenticated' || 'forbidden' => 'agent_error_auth',
    'malformed' => 'agent_error_malformed',
    'rateLimited' => 'agent_error_rate_limited',
    _ => 'agent_error_unavailable',
  });
}

class _Composer extends StatelessWidget {
  const _Composer({
    this.compact = false,
    required this.editingMessage,
    required this.onCancelEdit,
    required this.controller,
    required this.focusNode,
    required this.loading,
    required this.voiceState,
    required this.voiceBusy,
    required this.onVoice,
    required this.onSend,
  });

  final bool compact;
  final bool editingMessage;
  final VoidCallback? onCancelEdit;
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
      padding: EdgeInsets.fromLTRB(12, 9, 12, 9),
      decoration: const BoxDecoration(
        color: Color(0xFFF8FBFA),
        border: Border(top: BorderSide(color: Color(0xFFDDE8E6))),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (editingMessage) ...[
              Row(
                key: const ValueKey('agent_editing_bar'),
                children: [
                  const Icon(
                    Icons.edit_outlined,
                    color: AppColors.primary,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      context.tr('agent_editing_message'),
                      style: const TextStyle(
                        color: AppColors.primaryDark,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  TextButton(
                    key: const ValueKey('agent_cancel_edit'),
                    onPressed: onCancelEdit,
                    style: TextButton.styleFrom(
                      minimumSize: const Size(48, 48),
                    ),
                    child: Text(context.tr('cancel')),
                  ),
                ],
              ),
              const SizedBox(height: 6),
            ],
            if (voiceState != AgentVoiceUiState.idle) ...[
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: _VoiceStatusPill(state: voiceState),
              ),
              const SizedBox(height: 8),
            ],
            ValueListenableBuilder<TextEditingValue>(
              valueListenable: controller,
              builder: (context, editing, _) => AnimatedContainer(
                key: const ValueKey('agent_composer_surface'),
                duration: assistantReducedMotion(context)
                    ? Duration.zero
                    : const Duration(milliseconds: 200),
                padding: const EdgeInsets.fromLTRB(6, 5, 5, 5),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(AppRadii.xl),
                  border: Border.all(
                    color: editing.text.isNotEmpty
                        ? AppColors.primary
                        : const Color(0xFFD6E4E1),
                  ),
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
                        maxLines: compact ? (editingMessage ? 1 : 2) : 5,
                        maxLength: 2000,
                        textInputAction: TextInputAction.newline,
                        decoration: InputDecoration(
                          counterText: '',
                          hintText: context.tr('agent_input_hint'),
                          hintMaxLines: compact ? 1 : null,
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
                    AssistantPress(
                      child: IconButton.filledTonal(
                        key: const ValueKey('agent_mic_button'),
                        style: IconButton.styleFrom(
                          minimumSize: const Size(48, 48),
                          backgroundColor: AppColors.primaryLight,
                          foregroundColor: AppColors.primary,
                        ),
                        tooltip: _voiceTooltip(context, voiceState),
                        onPressed:
                            loading && voiceState != AgentVoiceUiState.recording
                            ? null
                            : onVoice,
                        icon: _voiceIcon(voiceState),
                      ),
                    ),
                    const SizedBox(width: 5),
                    ValueListenableBuilder<TextEditingValue>(
                      valueListenable: controller,
                      builder: (context, value, _) {
                        final canSend =
                            value.text.trim().isNotEmpty &&
                            !loading &&
                            !voiceBusy;
                        return AssistantPress(
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            decoration: BoxDecoration(
                              color: canSend
                                  ? AppColors.primary
                                  : AppColors.secondary,
                              borderRadius: BorderRadius.circular(AppRadii.lg),
                            ),
                            child: IconButton(
                              key: const ValueKey('agent_send_button'),
                              style: IconButton.styleFrom(
                                minimumSize: const Size(48, 48),
                                foregroundColor: Colors.white,
                                disabledForegroundColor: AppColors.subtle,
                              ),
                              tooltip: context.tr(
                                editingMessage ? 'agent_save_resend' : 'send',
                              ),
                              onPressed: canSend ? onSend : null,
                              icon: loading
                                  ? SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        value: assistantReducedMotion(context)
                                            ? .65
                                            : null,
                                        strokeWidth: 2,
                                        color: AppColors.primary,
                                      ),
                                    )
                                  : Icon(
                                      editingMessage
                                          ? Icons.check_rounded
                                          : Icons.send_outlined,
                                    ),
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
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
