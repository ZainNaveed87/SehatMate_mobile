import 'package:flutter/material.dart';

String carePeriodAllowedWindow(String timing) {
  final value = timing.toLowerCase();
  if (value.contains('morning')) return '4:00 AM – 11:59 AM';
  if (value.contains('afternoon')) return '12:00 PM – 4:59 PM';
  if (value.contains('evening')) return '5:00 PM – 8:59 PM';
  if (value.contains('night')) return '9:00 PM – 3:59 AM';
  return 'Any exact time that matches the original document';
}

bool hasFixedCarePeriod(String timing) {
  final value = timing.toLowerCase();
  return value.contains('morning') ||
      value.contains('afternoon') ||
      value.contains('evening') ||
      value.contains('night');
}

bool isTimeInCarePeriod(String timing, TimeOfDay time) {
  final value = timing.toLowerCase();
  if (value.contains('morning')) return time.hour >= 4 && time.hour < 12;
  if (value.contains('afternoon')) return time.hour >= 12 && time.hour < 17;
  if (value.contains('evening')) return time.hour >= 17 && time.hour < 21;
  if (value.contains('night')) return time.hour >= 21 || time.hour < 4;
  return true;
}
