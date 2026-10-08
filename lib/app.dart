import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'core/app_router.dart';
import 'core/app_routes.dart';
import 'core/app_theme.dart';
import 'localization/app_language.dart';
import 'localization/language_controller.dart';
import 'localization/language_scope.dart';
import 'services/auth_service.dart';
import 'features/agent/controllers/agent_controller.dart';
import 'features/agent/services/agent_service.dart';
import 'features/agent/services/agent_session_store.dart';
import 'features/agent/services/agent_voice_service.dart';
import 'features/agent/navigation/agent_navigation_handler.dart';
import 'features/agent/voice/voice_companion_controller.dart';
import 'features/agent/voice/voice_companion_scope.dart';
import 'widgets/app_error_boundary.dart';
import 'features/agent/voice/voice_backend.dart';
import 'features/agent/voice/livekit_voice_transport.dart';

class SehatRouteApp extends StatefulWidget {
  const SehatRouteApp({super.key});

  @override
  State<SehatRouteApp> createState() => _SehatRouteAppState();
}

class _SehatRouteAppState extends State<SehatRouteApp>
    with WidgetsBindingObserver {
  final navigatorKey = GlobalKey<NavigatorState>();
  late VoiceCompanionController voice;
  String? accountId;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    AuthSession.instance.addListener(_authChanged);
    _createCompanion();
  }

  void _createCompanion() {
    accountId = AuthSession.instance.user?.id;
    final ownedAccountId = accountId;
    final backend = HttpVoiceBackend();
    final agent = AgentController(
      client: AgentServiceClient(AgentService.instance),
      sessionStore: AgentSessionStore(accountId: accountId ?? 'signed_out'),
    );
    voice = VoiceCompanionController(
      backend: backend,
      transport: LiveKitVoiceTransport(),
      agent: agent,
      device: AgentVoiceService(),
      authenticated: () =>
          AuthSession.instance.isAuthenticated &&
          AuthSession.instance.user?.id == ownedAccountId,
      ensureAgentSession: backend.ensureAgentSession,
      languagePreferences: LanguageController.instance,
    );
    voice.onResult = (response) {
      final context = navigatorKey.currentState?.overlay?.context;
      if (context != null && response.navigation != null) {
        unawaited(
          const AgentNavigationHandler().navigate(
            context,
            response.navigation!,
          ),
        );
      }
    };
  }

  void _authChanged() {
    if (AuthSession.instance.user?.id == accountId &&
        AuthSession.instance.isAuthenticated) {
      return;
    }
    final old = voice;
    unawaited(old.end());
    old.agent.dispose();
    old.dispose();
    _createCompanion();
    if (mounted) setState(() {});
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    unawaited(voice.lifecycle(state));
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    AuthSession.instance.removeListener(_authChanged);
    unawaited(voice.end());
    voice.agent.dispose();
    voice.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ErrorWidget.builder = (details) => AppBuildFailure(details: details);

    final language = context.appLanguage;

    return MaterialApp(
      navigatorKey: navigatorKey,
      debugShowCheckedModeBanner: false,

      // App title also follows the
      // selected language.
      onGenerateTitle: (context) => context.tr('app_name'),

      theme: AppTheme.light,

      // --------------------------------
      // GLOBAL LANGUAGE
      // --------------------------------
      locale: language.materialLocale,

      supportedLocales: supportedMaterialLocales,

      localizationsDelegates: GlobalMaterialLocalizations.delegates,

      // --------------------------------
      // TEXT DIRECTION
      // --------------------------------
      //
      // English     -> LTR
      // Urdu        -> RTL
      // Roman Urdu  -> LTR
      //
      builder: (context, child) => Directionality(
        textDirection: language.textDirection,
        child: VoiceCompanionHost(
          controller: voice,
          child: child ?? const SizedBox.shrink(),
        ),
      ),

      // --------------------------------
      // ROUTING
      // --------------------------------
      initialRoute: _initialRoute(),

      onGenerateRoute: AppRouter.onGenerateRoute,
    );
  }

  String _initialRoute() {
    final session = AuthSession.instance;

    if (!session.isAuthenticated) {
      return AppRoutes.landing;
    }

    return session.needsOnboarding ? AppRoutes.onboarding : AppRoutes.dashboard;
  }
}
