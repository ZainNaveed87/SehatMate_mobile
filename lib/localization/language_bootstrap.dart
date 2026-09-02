import 'package:flutter/material.dart';

import 'app_language.dart';
import 'language_controller.dart';
import 'language_scope.dart';

class LanguageBootstrap extends StatefulWidget {
  const LanguageBootstrap({
    required this.builder,
    super.key,
  });

  final Widget Function(
    BuildContext context,
    AppLanguage language,
  ) builder;

  @override
  State<LanguageBootstrap> createState() => _LanguageBootstrapState();
}

class _LanguageBootstrapState extends State<LanguageBootstrap> {
  final controller = LanguageController.instance;

  @override
  void initState() {
    super.initState();
    controller.initialize();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) => LanguageScope(
        controller: controller,
        child: Builder(
          builder: (context) => widget.builder(
            context,
            controller.language,
          ),
        ),
      ),
    );
  }
}
