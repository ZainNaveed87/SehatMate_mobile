import 'package:flutter/material.dart';

import 'app_language.dart';
import 'app_strings.dart';
import 'language_controller.dart';

class LanguageScope extends InheritedNotifier<LanguageController> {
  const LanguageScope({
    required LanguageController controller,
    required super.child,
    super.key,
  }) : super(notifier: controller);

  static LanguageController watch(BuildContext context) {
    final scope =
        context.dependOnInheritedWidgetOfExactType<LanguageScope>();

    assert(
      scope != null,
      'LanguageScope is missing. Wrap the app with LanguageBootstrap.',
    );

    return scope!.notifier!;
  }

  static LanguageController read(BuildContext context) {
    final element =
        context.getElementForInheritedWidgetOfExactType<LanguageScope>();
    final scope = element?.widget as LanguageScope?;

    assert(
      scope != null,
      'LanguageScope is missing. Wrap the app with LanguageBootstrap.',
    );

    return scope!.notifier!;
  }
}

extension SehatMateLanguageContext on BuildContext {
  AppLanguage get appLanguage => LanguageScope.watch(this).language;

  bool get isUrdu => appLanguage == AppLanguage.urdu;

  String tr(
    String key, {
    Map<String, Object?> values = const {},
  }) =>
      AppStrings.get(key, appLanguage, values: values);
}
