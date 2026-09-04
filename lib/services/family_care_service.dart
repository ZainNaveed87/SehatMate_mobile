import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../core/api_config.dart';
import 'auth_service.dart';

class FamilyCareException implements Exception {
  const FamilyCareException(this.message);

  final String message;

  @override
  String toString() => message;
}

class FamilyPermissionScope {
  const FamilyPermissionScope(this.key, this.label);

  final String key;
  final String label;
}

const familyPermissionScopes = [
  FamilyPermissionScope('care_plan.read', 'Care plans'),
  FamilyPermissionScope('schedule.read', 'Schedule'),
  FamilyPermissionScope('task.read', 'Today tasks'),
  FamilyPermissionScope('care_gap.read', 'Care gaps'),
  FamilyPermissionScope('simulation.read', 'Simulation'),
  FamilyPermissionScope('performance.read', 'Performance'),
  FamilyPermissionScope('task.support', 'Practical task support'),
  FamilyPermissionScope('simulation.participate', 'Readiness support context'),
  FamilyPermissionScope('schedule.review_request', 'Schedule review requests'),
];

class FamilyInvitePerson {
  const FamilyInvitePerson({
    required this.id,
    required this.name,
    required this.email,
    required this.patientName,
  });

  final String id;
  final String name;
  final String email;
  final String patientName;
}

class FamilyInvitation {
  const FamilyInvitation({
    required this.id,
    required this.relationshipLabel,
    required this.status,
    required this.inviter,
    required this.caregiver,
    required this.careRecipient,
    required this.requestedScopes,
  });

  final String id;
  final String relationshipLabel;
  final String status;
  final FamilyInvitePerson? inviter;
  final FamilyInvitePerson? caregiver;
  final FamilyInvitePerson? careRecipient;
  final Map<String, bool> requestedScopes;
}

class FamilyRelationship {
  const FamilyRelationship({
    required this.id,
    required this.relationshipLabel,
    required this.status,
    required this.role,
    required this.memberName,
    required this.memberEmail,
    required this.patientName,
    required this.permissions,
    required this.summary,
  });

  final String id;
  final String relationshipLabel;
  final String status;
  final String role;
  final String memberName;
  final String memberEmail;
  final String patientName;
  final Map<String, bool> permissions;
  final FamilySummary? summary;

  bool get isCareRecipient => role == 'care_recipient';
}

class FamilyHomeData {
  const FamilyHomeData({
    required this.relationships,
    required this.pendingInvitations,
  });

  final List<FamilyRelationship> relationships;
  final List<FamilyInvitation> pendingInvitations;
}

class FamilySummary {
  const FamilySummary({required this.statusText, required this.sections});

  final String statusText;
  final Map<String, dynamic> sections;

  Map<String, dynamic> section(String key) {
    final value = sections[key];
    return value is Map<String, dynamic> ? value : const {};
  }
}

class FamilyMemberDetailData {
  const FamilyMemberDetailData({
    required this.relationship,
    required this.summary,
  });

  final FamilyRelationship relationship;
  final FamilySummary summary;
}

class FamilyCareService {
  FamilyCareService._();

  static final instance = FamilyCareService._();
  static const _timeout = Duration(seconds: 20);

  final http.Client _client = http.Client();

  Future<FamilyHomeData> fetchHome() async {
    final data = await _request('GET', '/family');
    return FamilyHomeData(
      relationships: _list(
        data['relationships'],
      ).map(_relationshipFromJson).toList(),
      pendingInvitations: _list(
        data['pendingInvitations'],
      ).map(_invitationFromJson).toList(),
    );
  }

  Future<void> createInvitation({
    required String email,
    required String relationshipLabel,
    required Map<String, bool> scopes,
  }) async {
    await _request(
      'POST',
      '/family/invitations',
      body: {
        'email': email.trim(),
        'relationshipLabel': relationshipLabel.trim(),
        'scopes': scopes,
      },
    );
  }

  Future<void> acceptInvitation(String invitationId) async {
    await _request('POST', '/family/invitations/$invitationId/accept');
  }

  Future<void> declineInvitation(String invitationId) async {
    await _request('POST', '/family/invitations/$invitationId/decline');
  }

  Future<FamilyMemberDetailData> fetchMemberSummary(
    String relationshipId,
  ) async {
    final data = await _request('GET', '/family/$relationshipId/summary');
    return FamilyMemberDetailData(
      relationship: _relationshipFromJson(_map(data['relationship'])),
      summary: _summaryFromJson(_map(data['summary'])),
    );
  }

  Future<FamilyRelationship> updatePermissions({
    required String relationshipId,
    required Map<String, bool> scopes,
  }) async {
    final data = await _request(
      'PATCH',
      '/family/relationships/$relationshipId/permissions',
      body: {'scopes': scopes},
    );
    return _relationshipFromJson(_map(data['relationship']));
  }

  Future<void> revokeRelationship(String relationshipId) async {
    await _request('POST', '/family/relationships/$relationshipId/revoke');
  }

  Future<Map<String, dynamic>> _request(
    String method,
    String path, {
    Map<String, dynamic>? body,
  }) async {
    final token = AuthSession.instance.token;
    if (token == null || token.isEmpty) {
      throw const FamilyCareException('Please sign in to continue.');
    }

    try {
      final headers = {
        'Accept': 'application/json',
        'Content-Type': 'application/json; charset=utf-8',
        'Authorization': 'Bearer $token',
      };
      final uri = ApiConfig.endpoint(path);
      late final http.Response response;
      if (method == 'POST') {
        response = await _client
            .post(
              uri,
              headers: headers,
              body: jsonEncode(body ?? const <String, dynamic>{}),
            )
            .timeout(_timeout);
      } else if (method == 'PATCH') {
        response = await _client
            .patch(
              uri,
              headers: headers,
              body: jsonEncode(body ?? const <String, dynamic>{}),
            )
            .timeout(_timeout);
      } else {
        response = await _client.get(uri, headers: headers).timeout(_timeout);
      }

      final decoded = _decode(response);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw FamilyCareException(
          decoded['message']?.toString() ??
              'The Family Care request could not be completed.',
        );
      }
      final data = decoded['data'];
      if (data is! Map<String, dynamic>) {
        throw const FamilyCareException(
          'The server returned an invalid response.',
        );
      }
      return data;
    } on TimeoutException {
      throw const FamilyCareException(
        'The server took too long to respond. Please try again.',
      );
    } on http.ClientException {
      throw const FamilyCareException(
        'Could not connect to the server. Check your connection.',
      );
    } on FormatException {
      throw const FamilyCareException(
        'The server returned an invalid response.',
      );
    }
  }

  Map<String, dynamic> _decode(http.Response response) {
    if (response.bodyBytes.isEmpty) return <String, dynamic>{};
    final decoded = jsonDecode(utf8.decode(response.bodyBytes));
    if (decoded is Map<String, dynamic>) return decoded;
    throw const FormatException('Expected JSON object.');
  }

  FamilyRelationship _relationshipFromJson(Map<String, dynamic> json) {
    final member = _map(json['member']);
    return FamilyRelationship(
      id: _text(json['id']),
      relationshipLabel: _text(json['relationshipLabel']),
      status: _text(json['status']).isEmpty ? 'active' : _text(json['status']),
      role: _text(json['role']),
      memberName: _text(member['name']).isEmpty
          ? 'Family member'
          : _text(member['name']),
      memberEmail: _text(member['email']),
      patientName: _text(member['patientName']),
      permissions: _boolMap(json['permissions']),
      summary: json['summary'] is Map<String, dynamic>
          ? _summaryFromJson(json['summary'] as Map<String, dynamic>)
          : null,
    );
  }

  FamilyInvitation _invitationFromJson(Map<String, dynamic> json) {
    return FamilyInvitation(
      id: _text(json['id']),
      relationshipLabel: _text(json['relationshipLabel']),
      status: _text(json['status']),
      inviter: _personFromJson(json['inviter']),
      caregiver: _personFromJson(json['caregiver']),
      careRecipient: _personFromJson(json['careRecipient']),
      requestedScopes: _boolMap(json['requestedScopes']),
    );
  }

  FamilyInvitePerson? _personFromJson(dynamic value) {
    if (value is! Map<String, dynamic>) return null;
    return FamilyInvitePerson(
      id: _text(value['id']),
      name: _text(value['name']),
      email: _text(value['email']),
      patientName: _text(value['patientName']),
    );
  }

  FamilySummary _summaryFromJson(Map<String, dynamic> json) {
    return FamilySummary(
      statusText: _text(json['statusText']).isEmpty
          ? 'Support may help'
          : _text(json['statusText']),
      sections: json,
    );
  }

  List<Map<String, dynamic>> _list(dynamic value) {
    if (value is! List) return const [];
    return value.whereType<Map<String, dynamic>>().toList();
  }

  Map<String, dynamic> _map(dynamic value) {
    return value is Map<String, dynamic> ? value : const <String, dynamic>{};
  }

  Map<String, bool> _boolMap(dynamic value) {
    final source = _map(value);
    return {
      for (final scope in familyPermissionScopes)
        scope.key: source[scope.key] == true || source[scope.key] == 1,
    };
  }

  String _text(dynamic value) =>
      value
          ?.toString()
          .replaceAll(RegExp(r'[\u0000-\u001F\u007F]'), '')
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim() ??
      '';
}
