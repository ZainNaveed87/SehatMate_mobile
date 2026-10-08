import 'package:flutter/material.dart';
import '../core/app_theme.dart';
import 'assistant_motion.dart';

const assistantHeroTag = 'sehatmate_assistant';

class AssistantLauncher extends StatefulWidget {
  const AssistantLauncher({
    super.key,
    required this.label,
    required this.onPressed,
  });
  final String label;
  final VoidCallback onPressed;
  @override
  State<AssistantLauncher> createState() => _AssistantLauncherState();
}

class _AssistantLauncherState extends State<AssistantLauncher>
    with SingleTickerProviderStateMixin {
  late final _breath = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 3),
  );
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (assistantReducedMotion(context) ||
        !TickerMode.valuesOf(context).enabled) {
      _breath.stop();
      _breath.value = 0;
    } else if (!_breath.isAnimating) {
      _breath.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _breath.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _breath,
    child: AssistantPress(
      scaleKey: const ValueKey('assistant_launcher_press'),
      child: FloatingActionButton(
        key: const ValueKey('assistant_launcher'),
        heroTag: assistantHeroTag,
        tooltip: widget.label,
        onPressed: widget.onPressed,
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 3,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.xl),
        ),
        child: const Icon(Icons.auto_awesome_rounded),
      ),
    ),
    builder: (_, child) => DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadii.xxl),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(
              alpha: .10 + .05 * _breath.value,
            ),
            blurRadius: 14 + 8 * _breath.value,
            spreadRadius: 2 * _breath.value,
          ),
        ],
      ),
      child: Transform.scale(scale: 1 + .018 * _breath.value, child: child),
    ),
  );
}
