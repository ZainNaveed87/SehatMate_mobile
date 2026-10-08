import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sehatmate_ai/features/agent/voice/sehatmate_voice_orb.dart';

void main() {
  testWidgets('real injected levels drive only the orb and waveform', (
    tester,
  ) async {
    final level = ValueNotifier<double>(0);
    addTearDown(level.dispose);
    var parentBuilds = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            parentBuilds++;
            return Center(
              child: SehatMateVoiceOrb(state: 'listening', amplitude: level),
            );
          },
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 120));
    final before = tester
        .widget<Transform>(find.byKey(const ValueKey('voice_orb_core')))
        .transform
        .getMaxScaleOnAxis();
    final builds = parentBuilds;
    level.value = .8;
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 120));
    final after = tester
        .widget<Transform>(find.byKey(const ValueKey('voice_orb_core')))
        .transform
        .getMaxScaleOnAxis();
    expect(after, greaterThan(before));
    expect(
      tester
          .widget<CustomPaint>(find.byKey(const ValueKey('voice_waveform')))
          .painter,
      isA<VoiceLevelPainter>().having(
        (p) => p.level,
        'level',
        closeTo(.8, .001),
      ),
    );
    expect(parentBuilds, builds);
    level.value = double.nan;
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 120));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 3));
    expect(tester.binding.transientCallbackCount, 0);
  });

  testWidgets('fallback breathes without claiming a live waveform', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Center(child: SehatMateVoiceOrb(state: 'listening')),
      ),
    );
    final initial = tester
        .widget<Transform>(find.byKey(const ValueKey('voice_orb_core')))
        .transform
        .getMaxScaleOnAxis();
    await tester.pump(const Duration(milliseconds: 1200));
    final later = tester
        .widget<Transform>(find.byKey(const ValueKey('voice_orb_core')))
        .transform
        .getMaxScaleOnAxis();
    expect(later, greaterThan(initial));
    expect(find.byKey(const ValueKey('voice_waveform')), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 3));
    expect(tester.binding.transientCallbackCount, 0);
  });

  testWidgets('reduced motion and muted state stop decorative motion', (
    tester,
  ) async {
    for (final state in ['listening', 'muted', 'disconnected']) {
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: true),
            child: child!,
          ),
          home: Center(child: SehatMateVoiceOrb(state: state)),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<Transform>(find.byKey(const ValueKey('voice_orb_core')))
            .transform
            .getMaxScaleOnAxis(),
        1,
      );
      expect(tester.takeException(), isNull);
    }
    expect(find.byIcon(Icons.wifi_off_rounded), findsOneWidget);
  });
}
