import 'package:flutter/material.dart';
import '../../../widgets/assistant_motion.dart';
import 'voice_companion_controller.dart';
import 'voice_companion_surface.dart';
import '../../../localization/language_scope.dart';

class VoiceCompanionScope extends InheritedNotifier<VoiceCompanionController> {
  const VoiceCompanionScope({
    super.key,
    required VoiceCompanionController controller,
    required super.child,
  }) : super(notifier: controller);
  static VoiceCompanionController? maybeOf(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<VoiceCompanionScope>()
      ?.notifier;
  static VoiceCompanionController? read(BuildContext context) =>
      (context
                  .getElementForInheritedWidgetOfExactType<
                    VoiceCompanionScope
                  >()
                  ?.widget
              as VoiceCompanionScope?)
          ?.notifier;
}

/// One application-owned voice presentation. Keep the Navigator mounted so
/// conversation and route state survive; do not compose another Agent page.
class VoiceCompanionHost extends StatelessWidget {
  const VoiceCompanionHost({
    super.key,
    required this.controller,
    required this.child,
  });
  final VoiceCompanionController controller;
  final Widget child;
  @override
  Widget build(BuildContext context) => VoiceCompanionScope(
    controller: controller,
    child: AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final showVoice =
            controller.state != 'idle' && controller.state != 'manual';
        return Stack(
          fit: StackFit.expand,
          children: [
            Offstage(
              offstage: showVoice,
              child: ExcludeFocus(
                excluding: showVoice,
                child: TickerMode(enabled: !showVoice, child: child),
              ),
            ),
            if (showVoice)
              AssistantEntrance(
                child: Overlay.wrap(
                  child: VoiceCompanionSurface(controller: controller),
                ),
              ),
          ],
        );
      },
    ),
  );
}

/// Entry/return controls on the typing page. Active-state content has one owner.
class VoiceCompanionControls extends StatelessWidget {
  const VoiceCompanionControls({super.key, this.compact = false});
  final bool compact;
  @override
  Widget build(BuildContext context) {
    final voice = VoiceCompanionScope.maybeOf(context);
    if (voice == null || (voice.state != 'idle' && voice.state != 'manual')) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: compact ? 8 : 12, vertical: 4),
      child: Wrap(
        spacing: 8,
        children: [
          TextButton.icon(
            style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
            onPressed: () async {
              FocusScope.of(context).unfocus();
              if (voice.voiceSessionId == null) {
                await voice.start(context.appLanguage);
              } else {
                await voice.resume();
              }
            },
            icon: const Icon(Icons.mic_outlined),
            label: Text(context.tr('agent_voice_start')),
          ),
          if (voice.voiceSessionId != null)
            TextButton(
              style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
              onPressed: voice.end,
              child: Text(context.tr('agent_voice_end')),
            ),
        ],
      ),
    );
  }
}
