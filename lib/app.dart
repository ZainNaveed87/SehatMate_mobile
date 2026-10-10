import 'features/agent/copilot/copilot_walkthrough_controller.dart';
import 'features/agent/navigation/agent_navigation_coordinator.dart';
import 'features/agent/models/agent_response.dart';
import 'features/agent/copilot/copilot_navigation_observer.dart';
import 'features/agent/copilot/copilot_strings.dart';
import 'features/agent/copilot/copilot.dart';
import 'features/agent/copilot/copilot_host.dart';
import 'features/agent/copilot/copilot_service.dart';
import 'features/agent/copilot/copilot_memory_review.dart';
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
  late CopilotRegistry copilotRegistry;
  late CopilotExecutor copilotExecutor;
  late CopilotPresentation copilotPresentation;
  late CopilotWalkthroughController copilotWalkthrough;
  late CopilotService copilotService;
  late CopilotNavigationObserver copilotObserver;
  late AgentNavigationCoordinator copilotNavigation;
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
    final registry = CopilotRegistry(accountId: accountId ?? 'signed_out');
    copilotRegistry = registry;
    copilotObserver = CopilotNavigationObserver(registry);
    copilotPresentation = CopilotPresentation();
    final presentation=copilotPresentation;
    copilotNavigation=AgentNavigationCoordinator(navigatorKey:navigatorKey,observer:copilotObserver,registry:registry,
      beforeVisualAction:() async {
        if(!registry.valid)return;
        presentation.enterGuided(GuidanceSummary(registry.snapshot?.screenId??'home'));
        voice.minimizePresentation();
        FocusManager.instance.primaryFocus?.unfocus();
        await WidgetsBinding.instance.endOfFrame;
      });
    registry.beforeVisualAction=()async{if(!registry.valid)return;presentation.enterGuided(GuidanceSummary(registry.snapshot?.screenId??'home',targetId:presentation.guidance?.targetId??registry.highlightedTarget));voice.minimizePresentation();FocusManager.instance.primaryFocus?.unfocus();await WidgetsBinding.instance.endOfFrame;};
    copilotWalkthrough=CopilotWalkthroughController(registry:registry,presentation:presentation);
    registry.walkthroughCommand=copilotWalkthrough.command;
    registry.appLanguageCode=()=>LanguageController.instance.language.agentLanguageCode;
    registry.setAppLanguage=(code)async {
      if(!registry.valid||AuthSession.instance.user?.id!=ownedAccountId)return false;
      final language=AppLanguageX.fromStorage(code);
      if(!await voice.applyAppLanguage(language))return false;
      await WidgetsBinding.instance.endOfFrame;
      return registry.valid&&AuthSession.instance.user?.id==ownedAccountId&&LanguageController.instance.language==language;
    };
    final navigation=copilotNavigation;
    late CopilotExecutor executor;
    late CopilotService service;
    late AgentController agent;
    agent = AgentController(
      client: AgentServiceClient(AgentService.instance),
      sessionStore: AgentSessionStore(accountId: accountId ?? 'signed_out'),
      contextProvider: () => registry.snapshot?.context,
      prepareLanguage: () => LanguageController.instance.prepareAgentLanguage(LanguageController.instance.language),
      onCopilotResult: (response, source) async {
        final planNavigates=response.uiPlan?.operations.any((op)=>registry.snapshot?.actions.any((a)=>a.id==op.actionId&&const {'navigate_to_registered_route','open_entity'}.contains(a.kind))??false)??false;
        if (!registry.valid || AuthSession.instance.user?.id != ownedAccountId) {
          return;
        }
        if (response.uiPlan != null) {
          presentation.enterGuided(GuidanceSummary(registry.snapshot?.screenId??'home'));
          voice.minimizePresentation();
          await WidgetsBinding.instance.endOfFrame;
          if (!registry.valid ||
              AuthSession.instance.user?.id != ownedAccountId) {
            return;
          }
          if (await service.ensureCurrent(response.sessionId)) {
            final plan = response.uiPlan!;
            if (plan.continuationDepth > 0 &&
                !plan.guidanceOnly(registry.snapshot)) {
              return;
            }
            final plannedActions =
                registry.snapshot?.actions ?? const <CopilotAction>[];
            final cancellation = executor.cancellationGeneration;
            final receipts = await executor.run(plan, source: source);
            final snapshot = registry.snapshot;
            final executedKind = receipts.isEmpty
                ? null
                : plannedActions
                      .where(
                        (a) =>
                            a.id == receipts.last.actionId &&
                            a.targetId == receipts.last.targetId,
                      )
                      .firstOrNull
                      ?.kind;
            if (copilotShouldContinueAfter(executedKind) &&
                receipts.isNotEmpty &&
                receipts.last.code == 'succeeded' &&
                snapshot != null &&
                (snapshot.version != plan.version || executedKind=='set_language') &&
                registry.valid &&
                !executor.paused &&
                cancellation == executor.cancellationGeneration &&
                plan.continuationDepth < 4 &&
                await service.ensureCurrent(response.sessionId)) {
              try {
                final envelope = await service.request(
                  'continue',
                  body: {
                    'sessionId': response.sessionId,
                    'planId': plan.id,
                    'context': snapshot.context.toJson(),
                    'source': source,
                  },
                );
                if (!registry.valid ||
                    executor.paused ||
                    cancellation != executor.cancellationGeneration ||
                    registry.snapshot?.version != snapshot.version) {
                  return;
                }
                final payload = envelope['data'];
                if (payload is Map<String, dynamic>) {
                  final guidance = AgentResponse.fromJson({
                    'success': envelope['success'],
                    ...payload,
                  });
                  if (guidance.navigation != null ||
                      guidance.confirmation != null ||
                      guidance.memoryProposal != null ||
                      (guidance.uiPlan != null &&
                          !guidance.uiPlan!.guidanceOnly(registry.snapshot))) {
                    return;
                  }
                  await agent.acceptCopilotContinuation(
                    guidance,
                    source: source,
                  );
                }
              } catch (_) {
                /* A completed step remains completed if narration is unavailable. */
              }
            }
          } else if (registry.valid) {
            executor.contextUnavailable();
            copilotPresentation.open();
          }
        }
        if (!registry.valid || AuthSession.instance.user?.id != ownedAccountId) {
          return;
        }
        if (response.conflicts.isNotEmpty) {
          voice.minimizePresentation();
          copilotPresentation.open();
        }
        if(response.navigation!=null&&!planNavigates&&registry.valid) {
          final result=await navigation.navigate(response.navigation!);
          if(!result.succeeded&&registry.valid){executor.contextUnavailable();presentation.openChat();}
          if(result.succeeded&&response.navigation!.target=='care_plan_new'&&registry.valid) {
            final shown=await registry.reveal('care_plan_new.name','focus');
            if(shown&&registry.valid)presentation.enterGuided(const GuidanceSummary('care_plan_new',targetId:'care_plan_new.name'));
          }
        }
        if (response.memoryProposal != null && registry.valid) {
          final context = navigatorKey.currentState?.overlay?.context;
          if (context != null && context.mounted) {
            await confirmCopilotMemory(
              context,
              service,
              response.memoryProposal!,
              response.sessionId,
            );
          }
        }
      },
    );
    executor = CopilotExecutor(
      registry: registry,
      confirm: (action) async {
        final context = navigatorKey.currentState?.overlay?.context;
        if (context == null || !context.mounted || !registry.valid) {
          return false;
        }
        final target = registry.snapshot?.targets
            .where((t) => t.id == action.targetId)
            .firstOrNull;
        voice.minimizePresentation();
        return await showDialog<bool>(
              context: context,
              builder: (context) => CopilotAccountSurface(
                registry: registry,
                child: AlertDialog(
                  title: Text(copilotText(context, 'review_change')),
                  content: Text(
                    '${target?.label ?? action.kind}${action.kind=='set_language'?': ${AppLanguageX.fromStorage(action.id.split('.').last).displayName}':''}\n\n${copilotText(context, 'save_notice')}',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: Text(context.tr('cancel')),
                    ),
                    FilledButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: Text(context.tr('confirm')),
                    ),
                  ],
                ),
              ),
            ) ??
            false;
      },
      receipt: (value) => service.receipt(value),
    );
    copilotExecutor = executor;
    service = CopilotService(
      registry: registry,
      agent: agent,
      syncActive: () => voice.enabled,
    );
    copilotService = service;
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

  }

  void _authChanged() {
    if (AuthSession.instance.user?.id == accountId &&
        AuthSession.instance.isAuthenticated) {
      return;
    }
    copilotNavigation.invalidate();
    copilotWalkthrough.stop();
    copilotRegistry.invalidate();
    copilotService.dispose();
    copilotExecutor.cancel();
    copilotExecutor.dispose();
    copilotPresentation.dispose();
    copilotWalkthrough.dispose();
    copilotNavigation.invalidate();
    copilotRegistry.dispose();
    final old = voice;
    unawaited(old.end());
    old.agent.dispose();
    old.dispose();
    _createCompanion();
    if (mounted) setState(() {});
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    copilotService.setForeground(state == AppLifecycleState.resumed);
    unawaited(voice.lifecycle(state));
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    AuthSession.instance.removeListener(_authChanged);
    copilotNavigation.invalidate();
    copilotWalkthrough.stop();
    copilotRegistry.invalidate();
    copilotService.dispose();
    copilotExecutor.cancel();
    copilotExecutor.dispose();
    copilotPresentation.dispose();
    copilotWalkthrough.dispose();
    copilotNavigation.invalidate();
    copilotRegistry.dispose();
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
      navigatorObservers: [copilotObserver],
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
        child: AgentNavigationScope(coordinator:copilotNavigation,child: VoiceCompanionHost(
          unifiedPresentation:true,
          controller: voice,
          child: CopilotHost(
            enabled:AuthSession.instance.isAuthenticated&&!AuthSession.instance.needsOnboarding,
            voice: voice,
            registry: copilotRegistry,
            executor: copilotExecutor,
            presentation: copilotPresentation,
            navigationHandler: AgentNavigationHandler(
              navigatorKey: navigatorKey,
            ),
            onMemory: () {
              final context = navigatorKey.currentState?.overlay?.context;
              if (context != null) {
                showCopilotMemoryReview(context, copilotService);
              }
            },
            child: child ?? const SizedBox.shrink(),
          ),
        )),
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
