import 'package:flutter/material.dart';
import '../../../core/app_theme.dart';
import '../../../localization/language_scope.dart';
import '../widgets/agent_header.dart';
import 'voice_companion_controller.dart';
import 'sehatmate_voice_orb.dart';
import '../../../widgets/assistant_motion.dart';

class VoiceCompanionSurface extends StatefulWidget {
  const VoiceCompanionSurface({super.key, required this.controller});
  final VoiceCompanionController controller;
  @override
  State<VoiceCompanionSurface> createState() => _VoiceCompanionSurfaceState();
}

class _VoiceCompanionSurfaceState extends State<VoiceCompanionSurface> {
  bool _acting = false;
  bool _actionFailed = false;
  bool get _disconnected =>
      widget.controller.state == 'disconnected' ||
      (widget.controller.state == 'recovering' &&
          widget.controller.recoveryCode == 'LIVEKIT_DISCONNECTED');

  Future<void> _act(
    Future<void> Function() action, {
    bool allowWhileBusy = false,
  }) async {
    if (_acting && !allowWhileBusy) return;
    setState(() {
      _acting = true;
      _actionFailed = false;
    });
    try {
      await action();
    } catch (_) {
      // Keep unexpected action errors local to this presentation.
      if (mounted) setState(() => _actionFailed = true);
    } finally {
      if (mounted) setState(() => _acting = false);
    }
  }

  Future<void> _retry() async {
    final voice = widget.controller;
    final selectedLanguage = context.appLanguage;
    if (voice.recoveryRequired && !await voice.reconcile()) return;
    if (!mounted) return;
    if (voice.voiceSessionId == null) {
      await voice.start(selectedLanguage);
    } else {
      await voice.resume();
    }
  }

  @override
  Widget build(BuildContext context) {
    final voice = widget.controller;
    const visibleStates = {
      'connecting',
      'listening',
      'processing',
      'speaking',
      'recovering',
      'disconnected',
      'muted',
      'awaiting_confirmation',
      'awaiting_clarification',
    };
    final state = _actionFailed
        ? 'recovering'
        : _disconnected
        ? 'disconnected'
        : visibleStates.contains(voice.state)
        ? voice.state
        : 'recovering';
    final connecting = state == 'connecting';
    final processing = state == 'processing';
    final speaking = state == 'speaking';
    final recovering = state == 'recovering';
    final transcript = processing
        ? voice.finalTranscript
        : (voice.interimTranscript.isNotEmpty
              ? voice.interimTranscript
              : voice.finalTranscript);
    final detail = speaking || state.startsWith('awaiting_')
        ? voice.reply
        : (state == 'listening' || processing ? transcript : '');
    final subtitle = _actionFailed
        ? 'agent_voice_action_failed_detail'
        : connecting
        ? 'agent_voice_connecting_detail'
        : state == 'listening'
        ? 'agent_voice_speak_naturally'
        : recovering
        ? (voice.speechBudgetExhausted
              ? 'agent_voice_budget_detail'
              : voice.speechUnavailable
              ? 'agent_voice_speech_unavailable_detail'
              : voice.recoveryCode == 'VOICE_TURN_DELAYED'
              ? 'agent_voice_delayed_detail'
              : 'agent_voice_recovering_detail')
        : _disconnected
        ? 'agent_voice_disconnected_detail'
        : state == 'muted'
        ? 'agent_voice_muted_detail'
        : null;

    return Material(
      color: AppColors.background,
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) => Column(
              children: [
                AgentHeader(
                  compact: constraints.maxHeight < 480,
                  title: context.tr('agent_title'),
                  subtitle: context.tr('agent_status_subtitle'),
                  showBack: false,
                  languageEnabled: !connecting,
                  waitForLanguageChange: () => voice.languageChangeComplete,
                ),
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, body) => SingleChildScrollView(
                      key: const ValueKey('voice_content_scroll'),
                      padding: const EdgeInsets.all(24),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          minHeight: (body.maxHeight - 48).clamp(
                            0,
                            double.infinity,
                          ),
                        ),
                        child: Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 560),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                SehatMateVoiceOrb(
                                  state: state,
                                  size: body.maxHeight < 300 ? 112 : 164,
                                ),
                                const SizedBox(height: 24),
                                AnimatedSwitcher(
                                  duration: assistantReducedMotion(context)
                                      ? Duration.zero
                                      : const Duration(milliseconds: 220),
                                  // Keep the entrance fade, but never paint two
                                  // contradictory state titles over each other.
                                  layoutBuilder:
                                      (currentChild, previousChildren) =>
                                          currentChild ??
                                          const SizedBox.shrink(),
                                  child: Semantics(
                                    key: ValueKey(state),
                                    liveRegion: true,
                                    child: Text(
                                      context.tr('agent_companion_$state'),
                                      textAlign: TextAlign.center,
                                      style: Theme.of(context)
                                          .textTheme
                                          .headlineSmall
                                          ?.copyWith(
                                            fontWeight: FontWeight.w700,
                                            color: AppColors.foreground,
                                          ),
                                    ),
                                  ),
                                ),
                                if (subtitle != null) ...[
                                  const SizedBox(height: 8),
                                  Text(
                                    context.tr(subtitle),
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      color: AppColors.muted,
                                      height: 1.5,
                                    ),
                                  ),
                                ],
                                if (detail.isNotEmpty) ...[
                                  const SizedBox(height: 24),
                                  AnimatedSize(
                                    duration: assistantReducedMotion(context)
                                        ? Duration.zero
                                        : const Duration(milliseconds: 220),
                                    alignment: Alignment.topCenter,
                                    child: Container(
                                      key: const ValueKey(
                                        'voice_transcript_surface',
                                      ),
                                      width: double.infinity,
                                      padding: const EdgeInsets.all(16),
                                      decoration: BoxDecoration(
                                        color: speaking
                                            ? AppColors.card
                                            : const Color(0xFFF0FAF7),
                                        boxShadow: const [
                                          BoxShadow(
                                            color: Color(0x0D0F766E),
                                            blurRadius: 16,
                                            offset: Offset(0, 6),
                                          ),
                                        ],
                                        border: Border.all(
                                          color: AppColors.border,
                                        ),
                                        borderRadius: BorderRadius.circular(
                                          AppRadii.xl,
                                        ),
                                      ),
                                      child: Text(
                                        detail,
                                        textAlign: TextAlign.center,
                                      ),
                                    ),
                                  ),
                                ],
                                if (recovering &&
                                        !voice.recoveryRequired &&
                                        voice.voiceSessionId != null ||
                                    voice.hasDeviceTtsOffer) ...[
                                  const SizedBox(height: 16),
                                  Wrap(
                                    alignment: WrapAlignment.center,
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: [
                                      if (recovering &&
                                          !voice.recoveryRequired &&
                                          voice.voiceSessionId != null)
                                        _button(
                                          'agent_device_speech',
                                          voice.useDeviceSpeech,
                                        ),
                                      if (voice.hasDeviceTtsOffer)
                                        _button(
                                          'agent_device_tts',
                                          voice.speakDeviceFallback,
                                        ),
                                    ],
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: constraints.maxHeight * .35,
                  ),
                  child: SingleChildScrollView(
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      decoration: const BoxDecoration(
                        color: AppColors.card,
                        border: Border(
                          top: BorderSide(color: AppColors.border),
                        ),
                      ),
                      child: Wrap(
                        key: const ValueKey('voice_bottom_controls'),
                        alignment: WrapAlignment.center,
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          if (connecting)
                            _button('cancel', voice.end)
                          else ...[
                            if (recovering || _disconnected)
                              _button(
                                _disconnected
                                    ? 'agent_voice_reconnect'
                                    : 'retry',
                                _retry,
                                primary: true,
                              )
                            else if (speaking)
                              _button(
                                'agent_voice_interrupt',
                                voice.interrupt,
                                primary: true,
                              )
                            else if (!processing)
                              _button(
                                voice.muted
                                    ? 'agent_voice_resume'
                                    : 'agent_voice_mute',
                                voice.muted ? voice.resume : voice.mute,
                                primary: true,
                              ),
                            if (!speaking)
                              _button(
                                'agent_manual_mode',
                                voice.manual,
                                disabled: processing,
                              ),
                            _button('agent_voice_end', voice.end),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _button(
    String key,
    Future<void> Function() action, {
    bool primary = false,
    bool disabled = false,
  }) {
    final closing = key == 'agent_voice_end' || key == 'cancel';
    final callback = disabled || (_acting && !closing)
        ? null
        : () => _act(action, allowWhileBusy: closing);
    final icon = switch (key) {
      'agent_voice_mute' => Icons.mic_off_outlined,
      'agent_voice_resume' => Icons.mic_rounded,
      'agent_manual_mode' => Icons.keyboard_outlined,
      'agent_voice_end' || 'cancel' => Icons.close_rounded,
      'agent_voice_interrupt' => Icons.back_hand_outlined,
      _ => Icons.refresh_rounded,
    };
    final label = Text(context.tr(key));
    return primary
        ? AssistantPress(
            child: FilledButton.icon(
              onPressed: callback,
              style: FilledButton.styleFrom(
                minimumSize: const Size(48, 48),
                backgroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                shape: const StadiumBorder(),
              ),
              icon: Icon(icon, size: 18),
              label: label,
            ),
          )
        : AssistantPress(
            child: TextButton.icon(
              onPressed: callback,
              style: TextButton.styleFrom(
                minimumSize: const Size(48, 48),
                foregroundColor: closing
                    ? AppColors.criticalForeground
                    : AppColors.primary,
                backgroundColor: closing
                    ? const Color(0xFFFFF4F2)
                    : const Color(0xFFF0FAF7),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                shape: const StadiumBorder(),
                side: const BorderSide(color: AppColors.border),
              ),
              icon: Icon(icon, size: 18),
              label: label,
            ),
          );
  }
}
