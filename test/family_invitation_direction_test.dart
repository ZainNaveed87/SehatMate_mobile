import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sehatmate_ai/services/family_care_service.dart';

void main() {
  test(
    'Family Home distinguishes outgoing invitation from actionable incoming invite',
    () async {
      final service = FamilyCareService(
        tokenProvider: () => 'session-token',
        client: MockClient((request) async {
          expect(request.method, 'GET');
          expect(request.url.path, '/api/family');

          return http.Response(
            jsonEncode({
              'data': {
                'relationships': <Map<String, dynamic>>[],
                'pendingInvitations': [
                  {
                    'id': '11',
                    'careRecipientUserId': '1',
                    'caregiverUserId': '2',
                    'relationshipLabel': 'Family caregiver',
                    'status': 'pending',
                    'direction': 'outgoing',
                    'canRespond': false,
                    'inviter': {
                      'id': '1',
                      'name': 'Patient',
                      'email': 'patient@example.com',
                    },
                    'caregiver': {
                      'id': '2',
                      'name': 'Caregiver',
                      'email': 'caregiver@example.com',
                    },
                    'careRecipient': {
                      'id': '1',
                      'name': 'Patient',
                      'email': 'patient@example.com',
                      'patientName': 'Patient',
                    },
                    'requestedScopes': {'care_plan.read': true},
                    'createdAt': '2026-09-07T12:00:00.000Z',
                  },
                  {
                    'id': '12',
                    'careRecipientUserId': '3',
                    'caregiverUserId': '1',
                    'relationshipLabel': 'Family caregiver',
                    'status': 'pending',
                    'direction': 'incoming',
                    'canRespond': true,
                    'inviter': {
                      'id': '3',
                      'name': 'Other Patient',
                      'email': 'other@example.com',
                    },
                    'caregiver': {
                      'id': '1',
                      'name': 'Patient',
                      'email': 'patient@example.com',
                    },
                    'careRecipient': {
                      'id': '3',
                      'name': 'Other Patient',
                      'email': 'other@example.com',
                      'patientName': 'Other Patient',
                    },
                    'requestedScopes': {'care_plan.read': true},
                    'createdAt': '2026-09-07T12:01:00.000Z',
                  },
                ],
              },
            }),
            200,
            headers: const {'content-type': 'application/json; charset=utf-8'},
          );
        }),
      );

      final home = await service.fetchHome();

      expect(home.pendingInvitations, hasLength(2));

      final outgoing = home.pendingInvitations[0];
      expect(outgoing.isOutgoing, isTrue);
      expect(outgoing.isIncoming, isFalse);
      expect(outgoing.canRespond, isFalse);

      final incoming = home.pendingInvitations[1];
      expect(incoming.isIncoming, isTrue);
      expect(incoming.isOutgoing, isFalse);
      expect(incoming.canRespond, isTrue);
    },
  );
}
