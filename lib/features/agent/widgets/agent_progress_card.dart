import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../core/app_theme.dart';
import '../../../localization/language_scope.dart';
import '../../../widgets/assistant_motion.dart';
import '../controllers/agent_controller.dart';

class AgentProgressCard extends StatelessWidget {
  const AgentProgressCard({super.key, required this.progress});
  final AgentRequestProgress progress;
  @override
  Widget build(BuildContext context) {
    final label = switch (progress) {
      AgentRequestProgress.restoringSession => 'agent_progress_restoring',
      AgentRequestProgress.applyingResponse => 'agent_progress_preparing',
      _ => 'agent_progress_waiting',
    };
    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFFF0FAF7),
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(AppRadii.xl),
        ),
        child: Row(
          children: [
            const _ActivityMark(),
            const SizedBox(width: 12),
            Expanded(
              child: Semantics(
                liveRegion: true,
                child: AnimatedSwitcher(
                  duration: assistantReducedMotion(context)
                      ? Duration.zero
                      : const Duration(milliseconds: 200),
                  layoutBuilder: (current, previous) =>
                      current ?? const SizedBox.shrink(),
                  transitionBuilder: agentReplyTransition,
                  child: Text(
                    context.tr(label),
                    key: ValueKey(label),
                    style: const TextStyle(
                      color: AppColors.primaryDark,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Widget agentReplyTransition(Widget child, Animation<double> animation) =>
    FadeTransition(
      opacity: animation,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, .08),
          end: Offset.zero,
        ).animate(animation),
        child: child,
      ),
    );

/// Keeps the pending and completed response in one stable list slot.
class AgentSizeTransition extends StatelessWidget {
  const AgentSizeTransition({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => assistantReducedMotion(context)
      ? child
      : AnimatedSize(
          duration: const Duration(milliseconds: 220),
          alignment: Alignment.topCenter,
          child: child,
        );
}

class AgentReplySlot extends StatelessWidget {
  const AgentReplySlot({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) {
    final duration = assistantReducedMotion(context)
        ? Duration.zero
        : const Duration(milliseconds: 220);
    return AgentSizeTransition(
      child: AnimatedSwitcher(
        duration: duration,
        transitionBuilder: agentReplyTransition,
        child: child,
      ),
    );
  }
}

/// Motion signals an outstanding operation; it never changes progress labels.
class _ActivityMark extends StatefulWidget {
  const _ActivityMark();
  @override
  State<_ActivityMark> createState() => _ActivityMarkState();
}

class _ActivityMarkState extends State<_ActivityMark>
    with SingleTickerProviderStateMixin {
  late final _motion = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1800),
  );
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (assistantReducedMotion(context) ||
        !TickerMode.valuesOf(context).enabled) {
      _motion.stop();
      _motion.value = 0;
    } else if (!_motion.isAnimating) {
      _motion.repeat();
    }
  }

  @override
  void dispose() {
    _motion.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: AnimatedBuilder(
      animation: _motion,
      builder: (_, _) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Transform.scale(
            scale: 1 + .025 * math.sin(_motion.value * math.pi * 2),
            child: const Icon(
              Icons.auto_awesome_rounded,
              color: AppColors.primary,
              size: 26,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(
              3,
              (i) => Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: Opacity(
                  opacity: assistantReducedMotion(context)
                      ? .6
                      : .35 +
                            .55 *
                                (1 +
                                    math.sin(
                                      (_motion.value - i / 4) * math.pi * 2,
                                    )) /
                                2,
                  child: Container(
                    width: 4,
                    height: 4,
                    decoration: const BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
