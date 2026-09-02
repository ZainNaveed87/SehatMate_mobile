import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'core/app_router.dart';
import 'core/app_routes.dart';
import 'core/app_theme.dart';
import 'localization/app_language.dart';
import 'localization/language_scope.dart';
import 'services/auth_service.dart';

class SehatRouteApp extends StatelessWidget {
  const SehatRouteApp({super.key});

  @override
  Widget build(BuildContext context) {
    ErrorWidget.builder =
        (_) => const _AppErrorWidget();

    final language =
        context.appLanguage;

    return MaterialApp(
      debugShowCheckedModeBanner:
          false,

      // App title also follows the
      // selected language.
      onGenerateTitle:
          (context) =>
              context.tr(
                'app_name',
              ),

      theme: AppTheme.light,

      // --------------------------------
      // GLOBAL LANGUAGE
      // --------------------------------

      locale:
          language.materialLocale,

      supportedLocales:
          supportedMaterialLocales,

      localizationsDelegates:
          GlobalMaterialLocalizations
              .delegates,

      // --------------------------------
      // TEXT DIRECTION
      // --------------------------------
      //
      // English     -> LTR
      // Urdu        -> RTL
      // Roman Urdu  -> LTR
      //
      builder:
          (context, child) =>
              Directionality(
        textDirection:
            language.textDirection,

        child:
            child ??
            const SizedBox.shrink(),
      ),

      // --------------------------------
      // ROUTING
      // --------------------------------

      initialRoute:
          _initialRoute(),

      onGenerateRoute:
          AppRouter.onGenerateRoute,
    );
  }

  String _initialRoute() {
    final session =
        AuthSession.instance;

    if (!session.isAuthenticated) {
      return AppRoutes.landing;
    }

    return session.needsOnboarding
        ? AppRoutes.onboarding
        : AppRoutes.dashboard;
  }
}

class _AppErrorWidget
    extends StatelessWidget {
  const _AppErrorWidget();

  @override
  Widget build(
    BuildContext context,
  ) {
    final route =
        ModalRoute.of(context)
                ?.settings
                .name ??
            AppRoutes.landing;

    return Material(
      color:
          AppColors.background,

      child: SafeArea(
        child: Center(
          child: Padding(
            padding:
                const EdgeInsets.all(
              24,
            ),

            child:
                ConstrainedBox(
              constraints:
                  const BoxConstraints(
                maxWidth: 420,
              ),

              child: Column(
                mainAxisSize:
                    MainAxisSize.min,

                children: [
                  Text(
                    context.tr(
                      'page_load_failed',
                    ),

                    textAlign:
                        TextAlign.center,

                    style:
                        const TextStyle(
                      fontSize: 20,
                      fontWeight:
                          FontWeight.w600,
                    ),
                  ),

                  const SizedBox(
                    height: 8,
                  ),

                  Text(
                    context.tr(
                      'page_load_failed_description',
                    ),

                    textAlign:
                        TextAlign.center,

                    style:
                        const TextStyle(
                      fontSize: 14,
                      color:
                          AppColors.muted,
                    ),
                  ),

                  const SizedBox(
                    height: 24,
                  ),

                  Wrap(
                    spacing: 8,
                    runSpacing: 8,

                    alignment:
                        WrapAlignment.center,

                    children: [
                      FilledButton(
                        onPressed: () =>
                            Navigator
                                .pushReplacementNamed(
                          context,
                          route,
                        ),

                        child: Text(
                          context.tr(
                            'retry',
                          ),
                        ),
                      ),

                      OutlinedButton(
                        onPressed: () =>
                            Navigator
                                .pushNamedAndRemoveUntil(
                          context,
                          AppRoutes
                              .landing,
                          (_) => false,
                        ),

                        child: Text(
                          context.tr(
                            'go_home',
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}