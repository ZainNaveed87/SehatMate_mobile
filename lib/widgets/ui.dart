import 'package:flutter/material.dart';

import '../core/app_theme.dart';
import '../data/demo_data.dart';

class AppCard extends StatelessWidget {
  const AppCard({
    required this.child,
    super.key,
    this.padding = const EdgeInsets.all(20),
    this.color = AppColors.card,
    this.borderColor = AppColors.border,
    this.radius = AppRadii.xxl,
  });

  final Widget child;
  final EdgeInsets padding;
  final Color color;
  final Color borderColor;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radius),
        side: BorderSide(color: borderColor),
      ),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: padding,
        child: child,
      ),
    );
  }
}

class SafetyNote extends StatelessWidget {
  const SafetyNote({required this.text, super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      color: AppColors.secondary,
      radius: AppRadii.xl,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 2),
            child: Icon(Icons.info_outline, size: 16, color: AppColors.primary),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 14, color: AppColors.muted, height: 1.5),
            ),
          ),
        ],
      ),
    );
  }
}

class SectionHeading extends StatelessWidget {
  const SectionHeading({
    required this.title,
    super.key,
    this.eyebrow,
    this.description,
  });

  final String? eyebrow;
  final String title;
  final String? description;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 680),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (eyebrow != null) ...[
            Text(
              eyebrow!.toUpperCase(),
              style: const TextStyle(
                color: AppColors.primary,
                fontSize: 13,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.6,
              ),
            ),
            const SizedBox(height: 8),
          ],
          Text(
            title,
            style: TextStyle(
              color: AppColors.foreground,
              fontSize: MediaQuery.sizeOf(context).width >= 640 ? 28 : 24,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.4,
            ),
          ),
          if (description != null) ...[
            const SizedBox(height: 12),
            Text(
              description!,
              style: const TextStyle(color: AppColors.muted, fontSize: 15, height: 1.55),
            ),
          ],
        ],
      ),
    );
  }
}

class OptionCard extends StatelessWidget {
  const OptionCard({
    required this.label,
    required this.selected,
    required this.onTap,
    super.key,
    this.description,
  });

  final String label;
  final String? description;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadii.xl),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: selected ? AppColors.primaryLight : AppColors.card,
          border: Border.all(color: selected ? AppColors.primary : AppColors.border),
          borderRadius: BorderRadius.circular(AppRadii.xl),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                  if (description != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      description!,
                      style: const TextStyle(fontSize: 13, color: AppColors.muted),
                    ),
                  ],
                ],
              ),
            ),
            if (selected)
              const Icon(Icons.check, size: 20, color: AppColors.primary),
          ],
        ),
      ),
    );
  }
}

class AppTab<T> {
  const AppTab(this.value, this.label);
  final T value;
  final String label;
}

class AppTabs<T> extends StatelessWidget {
  const AppTabs({required this.tabs, required this.selected, required this.onChanged, super.key});
  final List<AppTab<T>> tabs;
  final T selected;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(color: AppColors.secondary, borderRadius: BorderRadius.circular(AppRadii.lg)),
        child: Wrap(
          spacing: 0,
          runSpacing: 4,
          children: tabs.map((tab) {
            final active = tab.value == selected;
            return InkWell(
              onTap: () => onChanged(tab.value),
              borderRadius: BorderRadius.circular(AppRadii.md),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(color: active ? AppColors.card : Colors.transparent, borderRadius: BorderRadius.circular(AppRadii.md)),
                child: Text(tab.label, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: active ? AppColors.foreground : AppColors.muted)),
              ),
            );
          }).toList(),
        ),
      );
}

class EmptyState extends StatelessWidget {
  const EmptyState({
    required this.title,
    required this.description,
    super.key,
    this.icon = Icons.info_outline,
    this.action,
  });

  final String title;
  final String description;
  final IconData icon;
  final Widget? action;

  @override
  Widget build(BuildContext context) => DashedBorder(
        radius: AppRadii.xxl,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 52),
          decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(AppRadii.xxl)),
          child: Column(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: AppColors.primaryLight,
                child: Icon(icon, size: 21, color: AppColors.primary),
              ),
              const SizedBox(height: 12),
              Text(title, textAlign: TextAlign.center, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 390),
                child: Text(description, textAlign: TextAlign.center, style: const TextStyle(fontSize: 14, color: AppColors.muted)),
              ),
              if (action != null) ...[const SizedBox(height: 20), action!],
            ],
          ),
        ),
      );
}

class DashedBorder extends StatelessWidget {
  const DashedBorder({required this.child, super.key, this.color = AppColors.border, this.radius = AppRadii.xl, this.strokeWidth = 1});
  final Widget child;
  final Color color;
  final double radius;
  final double strokeWidth;

  @override
  Widget build(BuildContext context) => CustomPaint(
        foregroundPainter: _DashedBorderPainter(color: color, radius: radius, strokeWidth: strokeWidth),
        child: child,
      );
}

class _DashedBorderPainter extends CustomPainter {
  const _DashedBorderPainter({required this.color, required this.radius, required this.strokeWidth});
  final Color color;
  final double radius;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final inset = strokeWidth / 2;
    final path = Path()..addRRect(RRect.fromRectAndRadius(Rect.fromLTWH(inset, inset, size.width - strokeWidth, size.height - strokeWidth), Radius.circular(radius)));
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;
    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        canvas.drawPath(metric.extractPath(distance, (distance + 7).clamp(0, metric.length).toDouble()), paint);
        distance += 12;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedBorderPainter oldDelegate) => oldDelegate.color != color || oldDelegate.radius != radius || oldDelegate.strokeWidth != strokeWidth;
}

class TaskIcon extends StatelessWidget {
  const TaskIcon({required this.icon, super.key, this.size = 36});
  final IconData icon;
  final double size;

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(color: AppColors.primaryLight, borderRadius: BorderRadius.circular(AppRadii.xl)),
        alignment: Alignment.center,
        child: Icon(icon, size: size * .5, color: AppColors.primary),
      );
}

class HoverLift extends StatefulWidget {
  const HoverLift({required this.child, super.key, this.cursor = SystemMouseCursors.basic});
  final Widget child;
  final MouseCursor cursor;

  @override
  State<HoverLift> createState() => _HoverLiftState();
}

class _HoverLiftState extends State<HoverLift> {
  bool hovered = false;

  @override
  Widget build(BuildContext context) {
    final reducedMotion = CareDemoState.instance.reducedMotion || MediaQuery.disableAnimationsOf(context);
    return MouseRegion(
      cursor: widget.cursor,
      onEnter: (_) => setState(() => hovered = true),
      onExit: (_) => setState(() => hovered = false),
      child: AnimatedContainer(
        duration: Duration(milliseconds: reducedMotion ? 1 : 180),
        curve: Curves.easeOut,
        transform: Matrix4.translationValues(0, hovered && !reducedMotion ? -2 : 0, 0),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadii.xxl),
          boxShadow: hovered && !reducedMotion
              ? const [BoxShadow(color: Color(0x2E0F172A), blurRadius: 24, spreadRadius: -12, offset: Offset(0, 8))]
              : const [],
        ),
        child: widget.child,
      ),
    );
  }
}

class FadeSlideIn extends StatefulWidget {
  const FadeSlideIn({required this.child, super.key, this.delay = Duration.zero});
  final Widget child;
  final Duration delay;

  @override
  State<FadeSlideIn> createState() => _FadeSlideInState();
}

class _FadeSlideInState extends State<FadeSlideIn> {
  bool visible = false;

  @override
  void initState() {
    super.initState();
    if (CareDemoState.instance.reducedMotion) {
      visible = true;
      return;
    }
    Future<void>.delayed(widget.delay, () {
      if (mounted) setState(() => visible = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    final reducedMotion = CareDemoState.instance.reducedMotion || MediaQuery.disableAnimationsOf(context);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: visible ? 1.0 : 0.0),
      duration: Duration(milliseconds: reducedMotion ? 1 : 220),
      curve: Curves.easeOut,
      child: widget.child,
      builder: (context, value, child) => Opacity(
        opacity: value,
        child: Transform.translate(offset: Offset(0, 6 * (1 - value)), child: child),
      ),
    );
  }
}

Widget fieldLabel(String label, Widget field) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        field,
      ],
    );

void showDemoMessage(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}
