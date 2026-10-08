import 'package:flutter/material.dart';

bool assistantReducedMotion(BuildContext context) =>
    MediaQuery.disableAnimationsOf(context) ||
    MediaQuery.accessibleNavigationOf(context);

/// Entrance motion runs once for a stable message/widget key, never delays data.
class AssistantEntrance extends StatelessWidget {
  const AssistantEntrance({
    super.key,
    required this.child,
    this.duration = const Duration(milliseconds: 220),
    this.startFraction = 0,
  });
  final Widget child;
  final Duration duration;
  final double startFraction;
  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
    tween: Tween(begin: 0, end: 1),
    duration: assistantReducedMotion(context) ? Duration.zero : duration,
    child: child,
    builder: (_, value, child) {
      final progress = Curves.easeOut.transform(
        ((value - startFraction) / (1 - startFraction)).clamp(0, 1),
      );
      return Opacity(
        opacity: progress,
        child: Transform.translate(
          offset: Offset(0, 6 * (1 - progress)),
          child: child,
        ),
      );
    },
  );
}

/// Pointer feedback supplements the existing button's keyboard/reader actions.
class AssistantPress extends StatefulWidget {
  const AssistantPress({super.key, required this.child, this.scaleKey});
  final Widget child;
  final Key? scaleKey;
  @override
  State<AssistantPress> createState() => _AssistantPressState();
}

class _AssistantPressState extends State<AssistantPress> {
  bool _pressed = false;
  @override
  Widget build(BuildContext context) => Listener(
    onPointerDown: (_) => setState(() => _pressed = true),
    onPointerUp: (_) => setState(() => _pressed = false),
    onPointerCancel: (_) => setState(() => _pressed = false),
    child: AnimatedScale(
      key: widget.scaleKey,
      scale: _pressed && !assistantReducedMotion(context) ? .96 : 1,
      duration: const Duration(milliseconds: 120),
      child: widget.child,
    ),
  );
}
