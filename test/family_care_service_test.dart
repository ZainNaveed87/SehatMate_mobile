import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sehatmate_ai/services/family_care_service.dart';

void main() {
  test('createInvitation parses backend email delivery result', () async {
    late Map<String, dynamic> body;
    final service = FamilyCareService(
      tokenProvider: () => 'session-token',
      client: MockClient((request) async {
        expect(request.method, 'POST');
        expect(request.url.path, '/api/family/invitations');
        body = jsonDecode(request.body) as Map<String, dynamic>;
        return _jsonResponse({
          'data': {
            'invitation': {
              'id': '301',
              'relationshipLabel': 'Ammi',
              'status': 'pending',
              'requestedScopes': {'care_plan.read': true},
            },
            'emailDelivery': {'sent': true},
          },
        });
      }),
    );

    final result = await service.createInvitation(
      email: 'zain@example.com',
      relationshipLabel: 'Ammi',
      scopes: {'care_plan.read': true},
    );

    expect(body['email'], 'zain@example.com');
    expect(result.invitation.status, 'pending');
    expect(result.emailDelivery.sent, true);
  });

  test('fetchFamilyCarePlan parses read-only schedule visibility', () async {
    final service = FamilyCareService(
      tokenProvider: () => 'session-token',
      client: MockClient((request) async {
        expect(request.method, 'GET');
        expect(request.url.path, '/api/family/501/plans/8');
        return _jsonResponse({
          'data': {
            'relationship': {
              'id': '501',
              'relationshipLabel': 'Ammi',
              'status': 'active',
              'role': 'caregiver',
              'member': {'name': 'Ali Patient', 'email': 'ali@example.com'},
              'permissions': {'care_plan.read': true, 'schedule.read': false},
            },
            'plan': {'id': '8', 'title': 'Recovery plan', 'status': 'active'},
            'instructions': [
              {'id': '91', 'title': 'DemoMed', 'instruction': 'Take daily.'},
            ],
            'tasks': <Map<String, dynamic>>[],
            'schedule': {'allowed': false, 'requiredScope': 'schedule.read'},
            'readOnly': true,
          },
        });
      }),
    );

    final result = await service.fetchFamilyCarePlan(
      relationshipId: '501',
      planId: '8',
    );

    expect(result.planTitle, 'Recovery plan');
    expect(result.relationship.memberName, 'Ali Patient');
    expect(result.scheduleAllowed, false);
    expect(result.scheduleRequiredScope, 'schedule.read');
    expect(result.readOnly, true);
    expect(result.instructions, hasLength(1));
    expect(result.tasks, isEmpty);
  });
}

http.Response _jsonResponse(Map<String, dynamic> body) => http.Response(
  jsonEncode(body),
  200,
  headers: const {'content-type': 'application/json; charset=utf-8'},
);
