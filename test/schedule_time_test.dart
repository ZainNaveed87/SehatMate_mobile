import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sehatmate_ai/core/schedule_time.dart';

void main() {
  group('care schedule period validation', () {
    test('morning accepts morning and rejects night', () {
      expect(
        isTimeInCarePeriod(
          'Morning',
          const TimeOfDay(hour: 8, minute: 0),
        ),
        isTrue,
      );
      expect(
        isTimeInCarePeriod(
          'Morning',
          const TimeOfDay(hour: 22, minute: 0),
        ),
        isFalse,
      );
    });

    test('afternoon rejects morning and evening', () {
      expect(
        isTimeInCarePeriod(
          'Afternoon',
          const TimeOfDay(hour: 13, minute: 30),
        ),
        isTrue,
      );
      expect(
        isTimeInCarePeriod(
          'Afternoon',
          const TimeOfDay(hour: 9, minute: 0),
        ),
        isFalse,
      );
      expect(
        isTimeInCarePeriod(
          'Afternoon',
          const TimeOfDay(hour: 19, minute: 0),
        ),
        isFalse,
      );
    });

    test('night allows late night and early morning only', () {
      expect(
        isTimeInCarePeriod(
          'Night',
          const TimeOfDay(hour: 22, minute: 0),
        ),
        isTrue,
      );
      expect(
        isTimeInCarePeriod(
          'Night',
          const TimeOfDay(hour: 2, minute: 0),
        ),
        isTrue,
      );
      expect(
        isTimeInCarePeriod(
          'Night',
          const TimeOfDay(hour: 12, minute: 0),
        ),
        isFalse,
      );
    });
  });
}
