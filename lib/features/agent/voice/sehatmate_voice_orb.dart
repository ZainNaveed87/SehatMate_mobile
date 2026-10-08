import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../../../core/app_theme.dart';
import '../../../widgets/assistant_motion.dart';

/// Optional normalized real levels stay local to the visual. No fabricated
/// waveform: without an input, only a restrained breathing animation is shown.
class SehatMateVoiceOrb extends StatefulWidget {
  const SehatMateVoiceOrb({
    super.key,
    required this.state,
    this.size = 156,
    this.amplitude,
  });
  final String state;
  final double size;
  final ValueListenable<double>? amplitude;
  @override
  State<SehatMateVoiceOrb> createState() => _SehatMateVoiceOrbState();
}

class _SehatMateVoiceOrbState extends State<SehatMateVoiceOrb>
    with SingleTickerProviderStateMixin {
  late final _breath = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2400),
  );
  bool get _still => widget.state == 'muted' || widget.state == 'disconnected';
  void _sync() {
    if (_still ||
        widget.amplitude != null ||
        assistantReducedMotion(context) ||
        !TickerMode.valuesOf(context).enabled) {
      _breath.stop();
      _breath.value = 0;
    } else if (!_breath.isAnimating) {
      _breath.repeat(reverse: true);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(SehatMateVoiceOrb oldWidget) {
    super.didUpdateWidget(oldWidget);
    _sync();
  }

  @override
  void dispose() {
    _breath.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.amplitude != null &&
        (widget.state == 'listening' || widget.state == 'speaking')) {
      return ValueListenableBuilder<double>(
        valueListenable: widget.amplitude!,
        builder: (context, sample, _) => TweenAnimationBuilder<double>(
          tween: Tween(
            end: sample.isFinite ? sample.clamp(0, 1).toDouble() : 0,
          ),
          duration: assistantReducedMotion(context)
              ? Duration.zero
              : const Duration(milliseconds: 100),
          builder: (_, level, _) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _visual(level, reactive: true),
              const SizedBox(height: 12),
              SizedBox(
                width: 100,
                height: 24,
                child: CustomPaint(
                  key: const ValueKey('voice_waveform'),
                  painter: VoiceLevelPainter(level),
                ),
              ),
            ],
          ),
        ),
      );
    }
    return AnimatedBuilder(
      animation: _breath,
      builder: (_, _) => _visual(_breath.value),
    );
  }

  Widget _visual(double level, {bool reactive = false}) {
    final speaking = widget.state == 'speaking';
    final reduced = assistantReducedMotion(context);
    final coreSize = widget.size * .70;
    final icon = switch (widget.state) {
      'muted' => Icons.mic_off_rounded,
      'disconnected' => Icons.wifi_off_rounded,
      'recovering' => Icons.sync_rounded,
      'processing' => Icons.auto_awesome_rounded,
      'connecting' => Icons.link_rounded,
      'speaking' => Icons.graphic_eq_rounded,
      _ => Icons.mic_rounded,
    };
    return RepaintBoundary(
      child: SizedBox(
        key: const ValueKey('sehatmate_voice_orb'),
        width: widget.size,
        height: widget.size,
        child: Stack(
          alignment: Alignment.center,
          children: [
            for (final factor in [.94, .82])
              Transform.scale(
                scale: reduced ? 1 : 1 + level * (speaking ? .07 : .035),
                child: Container(
                  width: widget.size * factor,
                  height: widget.size * factor,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.primaryLight.withValues(
                      alpha: _still ? .18 : .30,
                    ),
                    border: Border.all(
                      color: AppColors.primary.withValues(
                        alpha: _still ? .10 : .14 + .10 * level,
                      ),
                    ),
                  ),
                ),
              ),
            Transform.scale(
              key: const ValueKey('voice_orb_core'),
              scale: reduced ? 1 : 1 + level * (reactive ? .10 : .025),
              child: AnimatedContainer(
                duration: reduced
                    ? Duration.zero
                    : const Duration(milliseconds: 220),
                width: coreSize,
                height: coreSize,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: _still
                        ? [AppColors.secondary, AppColors.primaryLight]
                        : [AppColors.primary, const Color(0xFF14B8A6)],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(
                        alpha: _still ? .05 : .18 + .05 * level,
                      ),
                      blurRadius: 18 + level * 8,
                      spreadRadius: 1,
                    ),
                  ],
                ),
                child: AnimatedSwitcher(
                  duration: reduced
                      ? Duration.zero
                      : const Duration(milliseconds: 220),
                  child: Icon(
                    icon,
                    key: ValueKey(icon),
                    color: _still ? AppColors.primary : Colors.white,
                    size: coreSize * .34,
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

class VoiceLevelPainter extends CustomPainter {
  const VoiceLevelPainter(this.level);
  final double level;
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.primary
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < 9; i++) {
      final weight = 1 - (i - 4).abs() / 6;
      final height = 4 + (size.height - 4) * level * weight;
      final x = (i + .5) * size.width / 9;
      canvas.drawLine(
        Offset(x, (size.height - height) / 2),
        Offset(x, (size.height + height) / 2),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(VoiceLevelPainter oldDelegate) =>
      oldDelegate.level != level;
}
