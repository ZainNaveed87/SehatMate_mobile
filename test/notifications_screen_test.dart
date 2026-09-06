import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sehatmate_ai/core/app_routes.dart';
import 'package:sehatmate_ai/localization/language_controller.dart';
import 'package:sehatmate_ai/localization/language_scope.dart';
import 'package:sehatmate_ai/screens/library_screens.dart';
import 'package:sehatmate_ai/services/auth_service.dart';
import 'package:sehatmate_ai/services/notification_center_service.dart';

void main() {
  testWidgets('NotificationsScreen shows truthful empty state', (tester) async {
    await _pumpNotifications(
      tester,
      service: _FakeNotificationCenterClient([const <AppNotification>[]]),
    );

    expect(find.text('Nothing new'), findsOneWidget);
    expect(find.text("You're all caught up."), findsOneWidget);
    expect(find.text('Medicine due soon'), findsNothing);
    expect(find.text('Transport unresolved'), findsNothing);
  });

  testWidgets('NotificationsScreen shows retryable error and retries', (
    tester,
  ) async {
    final service = _FakeNotificationCenterClient([
      const NotificationCenterException('Network unavailable', retryable: true),
      [_notification()],
    ]);
    await _pumpNotifications(tester, service: service);

    expect(find.text('Notifications could not load'), findsOneWidget);
    expect(find.text('Network unavailable'), findsOneWidget);

    await tester.tap(find.byKey(const Key('notifications_retry_button')));
    await tester.pumpAndSettle();

    expect(find.text('Document instructions ready'), findsOneWidget);
    expect(find.text('Network unavailable'), findsNothing);
    expect(service.loadCalls, 2);
  });

  testWidgets('tapping a notification marks it read and opens its route', (
    tester,
  ) async {
    final service = _FakeNotificationCenterClient([
      [_notification()],
    ]);
    await _pumpNotifications(tester, service: service);

    await tester.tap(find.byKey(const Key('notification_doc-ready')));
    await tester.pumpAndSettle();

    expect(service.readIds, ['doc-ready']);
    expect(find.text('Documents destination'), findsOneWidget);
  });

  testWidgets('sign-in required state does not load demo notifications', (
    tester,
  ) async {
    final service = _FakeNotificationCenterClient([const <AppNotification>[]]);
    await _pumpNotifications(
      tester,
      service: service,
      session: _FakeProfileSession(isAuthenticated: false),
    );

    expect(find.text('Sign in to view real notifications'), findsOneWidget);
    expect(service.loadCalls, 0);
    expect(find.text('Medicine due soon'), findsNothing);
  });
}

Future<void> _pumpNotifications(
  WidgetTester tester, {
  required NotificationCenterClient service,
  ProfileSession? session,
}) async {
  await tester.pumpWidget(
    LanguageScope(
      controller: LanguageController.forTesting(),
      child: MaterialApp(
        routes: {
          AppRoutes.auth: (_) => const Scaffold(body: Text('Auth destination')),
          AppRoutes.documents: (_) =>
              const Scaffold(body: Text('Documents destination')),
        },
        home: NotificationsScreen(
          service: service,
          session: session ?? _FakeProfileSession(),
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pumpAndSettle();
}

AppNotification _notification() {
  return AppNotification(
    id: 'doc-ready',
    type: 'document_ready',
    titleKey: 'notification_center_document_ready_title',
    messageKey: 'notification_center_document_ready_message',
    values: const {'document': 'rx.pdf', 'count': 3},
    createdAt: DateTime(2026, 9, 6, 10),
    route: AppRoutes.documents,
  );
}

class _FakeNotificationCenterClient implements NotificationCenterClient {
  _FakeNotificationCenterClient(List<Object> responses)
    : _responses = List<Object>.of(responses);

  final List<Object> _responses;
  final readIds = <String>[];
  final markAllIds = <String>[];
  var loadCalls = 0;

  @override
  Future<List<AppNotification>> loadNotifications() async {
    loadCalls += 1;
    final response = _responses.length > 1
        ? _responses.removeAt(0)
        : _responses.single;
    if (response is List<AppNotification>) {
      return response;
    }
    throw response;
  }

  @override
  Future<void> markAllRead(Iterable<String> ids) async {
    markAllIds.addAll(ids);
  }

  @override
  Future<void> markRead(String id) async {
    readIds.add(id);
  }
}

class _FakeProfileSession extends ChangeNotifier implements ProfileSession {
  _FakeProfileSession({this.isAuthenticated = true});

  @override
  final bool isAuthenticated;

  @override
  bool get isGuest => false;

  @override
  AuthUser? get user => isAuthenticated
      ? const AuthUser(id: 'user-1', name: 'Sara Khan', email: 'sara@test.com')
      : null;

  @override
  PatientProfile? get profile => null;

  @override
  bool get canAccessApp => isAuthenticated || isGuest;

  @override
  bool get needsOnboarding => false;

  @override
  Future<PatientProfile> completeOnboarding({
    required String usingFor,
    required String patientName,
    required String ageGroup,
    required String city,
    required String preferredLanguage,
    required String accessibilityMode,
    required bool caregiverSupport,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<PatientProfile?> fetchProfile() async => null;

  @override
  Future<PatientProfile> updateProfile(PatientProfile profile) {
    throw UnimplementedError();
  }
}
