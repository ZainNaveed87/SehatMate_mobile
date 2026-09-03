import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sehatmate_ai/localization/app_language.dart';

void main() {
  test('language directions and labels remain stable', () {
    expect(AppLanguage.english.textDirection, TextDirection.ltr);
    expect(AppLanguage.urdu.textDirection, TextDirection.rtl);
    expect(AppLanguage.romanUrdu.textDirection, TextDirection.ltr);

    expect(AppLanguage.english.displayName, 'English');
    expect(AppLanguage.urdu.displayName, 'اردو');
    expect(AppLanguage.romanUrdu.displayName, 'Roman Urdu');
  });
}
