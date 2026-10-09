import '../copilot/copilot_strings.dart';
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
    this.unifiedPresentation=false,
  });
  final VoiceCompanionController controller;
  final Widget child;
  final bool unifiedPresentation;
  @override
  Widget build(BuildContext context) => VoiceCompanionScope(
    controller: controller,
    child: Overlay.wrap(
      child: AnimatedBuilder(
        animation: controller,
        builder: (context, _) {
          final showVoice =
              controller.state != 'idle' &&
              controller.state != 'manual' &&
              !controller.presentationMinimized;
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
              if (!unifiedPresentation && !showVoice &&
                  controller.presentationMinimized &&
                  controller.state != 'idle' &&
                  controller.state != 'manual')
                PositionedDirectional(
                  top: MediaQuery.paddingOf(context).top + 6,
                  end: 8,
                  child: Material(
                    elevation: 3,
                    borderRadius: BorderRadius.circular(30),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          tooltip: copilotText(context, 'return_voice'),
                          onPressed: controller.expandPresentation,
                          icon: const Icon(Icons.mic),
                        ),
                        IconButton(
                          tooltip: copilotText(
                            context,
                            controller.muted ? 'unmute' : 'mute',
                          ),
                          onPressed: controller.muted
                              ? controller.resume
                              : controller.mute,
                          icon: Icon(
                            controller.muted ? Icons.mic_off : Icons.mic_none,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              if (showVoice)
                AssistantEntrance(
                  child: Overlay.wrap(
                    child: Stack(
                      children: [
                        VoiceCompanionSurface(controller: controller),
                        PositionedDirectional(
                          top: MediaQuery.paddingOf(context).top + 4,
                          end: 8,
                          child: Material(
                            color: Colors.transparent,
                            child: IconButton(
                              tooltip: copilotText(context, 'minimize_voice'),
                              onPressed: controller.minimizePresentation,
                              icon: const Icon(Icons.minimize),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          );
        },
      ),
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
              voice.expandPresentation();
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
