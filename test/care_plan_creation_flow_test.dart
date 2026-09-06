import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sehatmate_ai/core/app_routes.dart';
import 'package:sehatmate_ai/localization/app_language.dart';
import 'package:sehatmate_ai/localization/app_strings.dart';
import 'package:sehatmate_ai/localization/language_controller.dart';
import 'package:sehatmate_ai/localization/language_scope.dart';
import 'package:sehatmate_ai/localization/localized_errors.dart';
import 'package:sehatmate_ai/screens/care_plans_screen.dart';
import 'package:sehatmate_ai/services/auth_service.dart';
import 'package:sehatmate_ai/services/care_plan_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _RecordingObserver extends NavigatorObserver {
  Route<dynamic>? lastPushed;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    lastPushed = route;
    super.didPush(route, previousRoute);
  }
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    FlutterSecureStorage.setMockInitialValues({
      'sehatroute_auth_token': 'session-token',
      'sehatroute_auth_user':
          '{"id":"user-1","name":"Test User","email":"test@example.com"}',
    });
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await AuthSession.instance.initialize();
  });

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test('required plan-name strings exist in all supported languages', () {
    for (final language in AppLanguage.values) {
      for (final key in const [
        'plan_name',
        'plan_name_hint',
        'plan_name_required',
        'plan_name_length_error',
        'care_plan_name_already_exists',
        'plan_name_helper',
      ]) {
        expect(AppStrings.get(key, language), isNot(key));
        expect(AppStrings.get(key, language).trim(), isNotEmpty);
      }
    }
  });

  test('upload args use neutral fallback only when no type was preselected', () {
    const newPlanArgs = CarePlanUploadArgs(planId: '7');
    expect(newPlanArgs.documentTypes, isEmpty);
    expect(newPlanArgs.documentTypeForUpload(0), 'other');

    const addDocumentArgs = CarePlanUploadArgs(
      planId: '7',
      documentTypes: ['prescription'],
    );
    expect(addDocumentArgs.documentTypeForUpload(0), 'prescription');
    expect(addDocumentArgs.documentTypeForUpload(99), 'prescription');
  });

  test('duplicate 409 localizes by stable backend code', () {
    const error = CarePlanException(
      'server text',
      statusCode: 409,
      data: {'code': 'CARE_PLAN_TITLE_EXISTS'},
    );

    expect(
      localizedCarePlanExceptionMessage(error, AppLanguage.english),
      'A care plan with this name already exists.',
    );
  });

  testWidgets('New Care Plan asks for plan name only', (tester) async {
    final service = CarePlanService(
      tokenProvider: () => 'session-token',
      client: MockClient((_) async => _jsonResponse(_createdPlan())),
    );

    await _pumpNewCarePlan(tester, service: service);

    expect(find.text('New Care Plan'), findsWidgets);
    expect(find.byKey(const ValueKey('new_care_plan_name_field')), findsOneWidget);
    expect(find.text('Prescription'), findsNothing);
    expect(find.text('Discharge Summary'), findsNothing);
    expect(find.text('Follow-Up Instructions'), findsNothing);
    expect(find.text('Lab Instructions'), findsNothing);
    expect(find.text('Other Medical Instructions'), findsNothing);

    final button = tester.widget<FilledButton>(
      find.byKey(const ValueKey('new_care_plan_continue_button')),
    );
    expect(button.onPressed, isNull);
  });

  testWidgets('invalid name keeps Continue disabled', (tester) async {
    final service = CarePlanService(
      tokenProvider: () => 'session-token',
      client: MockClient((_) async => _jsonResponse(_createdPlan())),
    );

    await _pumpNewCarePlan(tester, service: service);
    await tester.enterText(
      find.byKey(const ValueKey('new_care_plan_name_field')),
      'A',
    );
    await tester.pump();

    final button = tester.widget<FilledButton>(
      find.byKey(const ValueKey('new_care_plan_continue_button')),
    );
    expect(button.onPressed, isNull);
    expect(find.text('Plan name must be 2-80 characters.'), findsOneWidget);
  });

  testWidgets(
    'valid unique name creates plan and routes directly to Upload Documents',
    (tester) async {
      var requestCount = 0;
      Map<String, dynamic>? sentBody;
      final releaseResponse = Completer<void>();
      final service = CarePlanService(
        tokenProvider: () => 'session-token',
        client: MockClient((request) async {
          requestCount += 1;
          expect(request.method, 'POST');
          expect(request.url.path, '/api/care-plans');
          sentBody = jsonDecode(request.body) as Map<String, dynamic>;
          await releaseResponse.future;
          return _jsonResponse(_createdPlan(title: 'Morning Plan'));
        }),
      );
      final observer = _RecordingObserver();

      await _pumpNewCarePlan(tester, service: service, observer: observer);
      await tester.enterText(
        find.byKey(const ValueKey('new_care_plan_name_field')),
        '  Morning   Plan  ',
      );
      await tester.pump();

      final button = find.byKey(const ValueKey('new_care_plan_continue_button'));
      expect(tester.widget<FilledButton>(button).onPressed, isNotNull);

      await tester.tap(button);
      await tester.tap(button);
      await tester.pump();

      expect(requestCount, 1);
      expect(sentBody?['title'], 'Morning Plan');
      expect(sentBody?['title'], isNot('Prescription Care Plan'));

      releaseResponse.complete();
      await tester.pumpAndSettle();

      expect(observer.lastPushed?.settings.name, AppRoutes.carePlanUpload);
      final args = observer.lastPushed?.settings.arguments;
      expect(args, isA<CarePlanUploadArgs>());
      final uploadArgs = args! as CarePlanUploadArgs;
      expect(uploadArgs.planId, '7');
      expect(uploadArgs.documentTypes, isEmpty);
      expect(uploadArgs.guidedSetup, isTrue);
      expect(find.text('Upload Documents'), findsOneWidget);
    },
  );

  testWidgets('duplicate 409 shows localized useful error', (tester) async {
    final service = CarePlanService(
      tokenProvider: () => 'session-token',
      client: MockClient((_) async => _jsonResponse(
            {
              'success': false,
              'code': 'CARE_PLAN_TITLE_EXISTS',
              'message': 'A care plan with this name already exists.',
              'data': {'code': 'CARE_PLAN_TITLE_EXISTS'},
            },
            statusCode: 409,
          )),
    );

    await _pumpNewCarePlan(tester, service: service);
    await tester.enterText(
  find.byKey(const ValueKey('new_care_plan_name_field')),
  'Morning Plan',
);
await tester.pump();

await tester.tap(
  find.byKey(const ValueKey('new_care_plan_continue_button')),
);
await tester.pumpAndSettle();

    expect(find.text('A care plan with this name already exists.'), findsOneWidget);
  });
}

Future<void> _pumpNewCarePlan(
  WidgetTester tester, {
  required CarePlanService service,
  _RecordingObserver? observer,
  AppLanguage language = AppLanguage.english,
}) async {
  final languageController = LanguageController.forTesting();
  await languageController.setLanguage(language, syncToServer: false);

  await tester.pumpWidget(
    LanguageScope(
      controller: languageController,
      child: MaterialApp(
        navigatorObservers: [
          if (observer != null) observer,
        ],
        onGenerateRoute: (settings) => MaterialPageRoute<void>(
          settings: settings,
          builder: (_) {
            if (settings.name == AppRoutes.carePlanUpload) {
              return const Scaffold(
                body: Center(child: Text('Upload Documents')),
              );
            }
            return NewCarePlanScreen(carePlanService: service);
          },
        ),
        home: NewCarePlanScreen(carePlanService: service),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

http.Response _jsonResponse(
  Map<String, dynamic> body, {
  int statusCode = 200,
}) => http.Response(
      jsonEncode(body),
      statusCode,
      headers: const {'content-type': 'application/json; charset=utf-8'},
    );

Map<String, dynamic> _createdPlan({String title = 'Morning Plan'}) => {
      'success': true,
      'data': {
        'plan': {
          'id': '7',
          'title': title,
          'status': 'draft',
          'readinessScore': 0,
          'durationMode': 'prescription',
          'createdAt': '2026-09-06T10:00:00Z',
        },
      },
    };
