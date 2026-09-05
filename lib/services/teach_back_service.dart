import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../core/api_config.dart';
import 'auth_service.dart';

class TeachBackException implements Exception {
  const TeachBackException(
    this.message, {
    this.statusCode,
    this.retryable = false,
  });

  final String message;
  final int? statusCode;
  final bool retryable;

  @override
  String toString() => message;
}

class TeachBackTarget {
  const TeachBackTarget({
    required this.targetType,
    required this.targetId,
    required this.carePlanId,
    required this.carePlanTitle,
    required this.title,
    required this.instruction,
    required this.timing,
    required this.notes,
    required this.sourceUpdatedAt,
  });

  final String targetType;
  final String targetId;
  final String carePlanId;
  final String carePlanTitle;
  final String title;
  final String instruction;
  final String timing;
  final String notes;
  final String sourceUpdatedAt;

  String get key => '$targetType:$targetId';
}

class TeachBackQuestion {
  const TeachBackQuestion({
    required this.id,
    required this.text,
    required this.focus,
    required this.order,
  });

  final String id;
  final String text;
  final String focus;
  final int order;
}

class TeachBackAssessment {
  const TeachBackAssessment({
    required this.id,
    required this.questionId,
    required this.questionText,
    required this.answerText,
    required this.status,
    required this.score,
    required this.matchedPoints,
    required this.missingPoints,
    required this.feedback,
    required this.retryPrompt,
    required this.planStatement,
  });

  final String id;
  final String questionId;
  final String questionText;
  final String answerText;
  final String status;
  final int score;
  final List<String> matchedPoints;
  final List<String> missingPoints;
  final String feedback;
  final String retryPrompt;
  final String planStatement;

  bool get understood => status == 'understood';
  bool get needsRetry => status == 'partial' || status == 'needs_review';
}

class TeachBackFinalResult {
  const TeachBackFinalResult({
    required this.completed,
    required this.score,
    required this.status,
    required this.questionCount,
    required this.answeredCount,
    required this.understoodCount,
    required this.needsReviewCount,
    required this.weakQuestionIds,
  });

  final bool completed;
  final int score;
  final String status;
  final int questionCount;
  final int answeredCount;
  final int understoodCount;
  final int needsReviewCount;
  final List<String> weakQuestionIds;
}

class TeachBackSession {
  const TeachBackSession({
    required this.target,
    required this.canAssess,
    required this.planStatement,
    required this.questions,
    required this.assessments,
    required this.finalResult,
    required this.language,
  });

  final TeachBackTarget target;
  final bool canAssess;
  final String planStatement;
  final List<TeachBackQuestion> questions;
  final List<TeachBackAssessment> assessments;
  final TeachBackFinalResult finalResult;
  final String language;

  Map<String, TeachBackAssessment> get assessmentsByQuestionId => {
    for (final assessment in assessments) assessment.questionId: assessment,
  };
}

class TeachBackAssessmentResponse {
  const TeachBackAssessmentResponse({
    required this.target,
    required this.assessment,
    required this.finalResult,
  });

  final TeachBackTarget target;
  final TeachBackAssessment assessment;
  final TeachBackFinalResult finalResult;
}

abstract class TeachBackClient {
  Future<List<TeachBackTarget>> fetchTargets();

  Future<TeachBackSession> fetchSession({
    required String targetType,
    required String targetId,
  });

  Future<TeachBackAssessmentResponse> assessAnswer({
    required String targetType,
    required String targetId,
    required String questionId,
    required String answer,
  });
}

class TeachBackService implements TeachBackClient {
  TeachBackService({http.Client? client, String? Function()? tokenProvider})
    : _client = client ?? http.Client(),
      _tokenProvider = tokenProvider ?? (() => AuthSession.instance.token);

  static final TeachBackService instance = TeachBackService();
  static const _timeout = Duration(seconds: 30);

  final http.Client _client;
  final String? Function() _tokenProvider;

  @override
  Future<List<TeachBackTarget>> fetchTargets() async {
    final data = await _request('GET', '/teach-back/targets');
    final targets = data['targets'];
    if (targets is! List) {
      throw const TeachBackException(
        'The server returned an invalid Teach Back target list.',
      );
    }
    return targets
        .whereType<Map<String, dynamic>>()
        .map(_targetFromJson)
        .where((target) => target.targetId.isNotEmpty)
        .toList();
  }

  @override
  Future<TeachBackSession> fetchSession({
    required String targetType,
    required String targetId,
  }) async {
    final data = await _request(
      'GET',
      '/teach-back/session/'
          '${Uri.encodeComponent(targetType)}/'
          '${Uri.encodeComponent(targetId)}',
    );
    return _sessionFromJson(data);
  }

  @override
  Future<TeachBackAssessmentResponse> assessAnswer({
    required String targetType,
    required String targetId,
    required String questionId,
    required String answer,
  }) async {
    final data = await _request(
      'POST',
      '/teach-back/assess',
      body: {
        'targetType': targetType,
        'targetId': targetId,
        'questionId': questionId,
        'answer': answer,
      },
    );
    final targetJson = data['target'];
    final assessmentJson = data['assessment'];
    final finalJson = data['finalResult'];
    if (targetJson is! Map<String, dynamic> ||
        assessmentJson is! Map<String, dynamic> ||
        finalJson is! Map<String, dynamic>) {
      throw const TeachBackException(
        'The server returned an invalid Teach Back assessment.',
      );
    }
    return TeachBackAssessmentResponse(
      target: _targetFromJson(targetJson),
      assessment: _assessmentFromJson(assessmentJson),
      finalResult: _finalResultFromJson(finalJson),
    );
  }

  Future<Map<String, dynamic>> _request(
    String method,
    String path, {
    Map<String, dynamic>? body,
  }) async {
    final token = _tokenProvider();
    if (token == null || token.isEmpty) {
      throw const TeachBackException('Please sign in to use Teach Back.');
    }

    try {
      final headers = <String, String>{
        'Accept': 'application/json',
        'Content-Type': 'application/json; charset=utf-8',
        'Authorization': 'Bearer $token',
      };
      final uri = ApiConfig.endpoint(path);
      final http.Response response;
      if (method == 'POST') {
        response = await _client
            .post(uri, headers: headers, body: jsonEncode(body ?? const {}))
            .timeout(_timeout);
      } else {
        response = await _client.get(uri, headers: headers).timeout(_timeout);
      }

      final decoded = _decode(response);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw TeachBackException(
          decoded['message']?.toString() ??
              'Teach Back could not be completed.',
          statusCode: response.statusCode,
          retryable:
              response.statusCode == 408 ||
              response.statusCode == 429 ||
              response.statusCode >= 500,
        );
      }
      final data = decoded['data'];
      if (data is! Map<String, dynamic>) {
        throw const TeachBackException(
          'The server returned an invalid Teach Back response.',
        );
      }
      return data;
    } on TimeoutException {
      throw const TeachBackException(
        'The server took too long to respond. Please try again.',
        retryable: true,
      );
    } on http.ClientException {
      throw const TeachBackException(
        'Could not connect to the server. Check your connection.',
        retryable: true,
      );
    } on FormatException {
      throw const TeachBackException(
        'The server returned an invalid Teach Back response.',
      );
    }
  }

  Map<String, dynamic> _decode(http.Response response) {
    if (response.bodyBytes.isEmpty) return <String, dynamic>{};
    final decoded = jsonDecode(utf8.decode(response.bodyBytes));
    if (decoded is Map<String, dynamic>) return decoded;
    throw const FormatException('Expected a JSON object.');
  }

  TeachBackSession _sessionFromJson(Map<String, dynamic> json) {
    final targetJson = json['target'];
    final finalJson = json['finalResult'];
    if (targetJson is! Map<String, dynamic> ||
        finalJson is! Map<String, dynamic>) {
      throw const TeachBackException(
        'The server returned an invalid Teach Back session.',
      );
    }
    return TeachBackSession(
      target: _targetFromJson(targetJson),
      canAssess: _bool(json['canAssess']),
      planStatement: _displayText(json['planStatement']),
      language: _displayText(json['language']),
      questions: _listOfMaps(json['questions'])
          .map(_questionFromJson)
          .where(
            (question) => question.id.isNotEmpty && question.text.isNotEmpty,
          )
          .toList(),
      assessments: _listOfMaps(json['assessments'])
          .map(_assessmentFromJson)
          .where((assessment) => assessment.questionId.isNotEmpty)
          .toList(),
      finalResult: _finalResultFromJson(finalJson),
    );
  }

  TeachBackTarget _targetFromJson(Map<String, dynamic> json) {
    return TeachBackTarget(
      targetType: _displayText(json['targetType']),
      targetId: _displayText(json['targetId']),
      carePlanId: _displayText(json['carePlanId']),
      carePlanTitle: _displayText(json['carePlanTitle']),
      title: _displayText(json['title']).isEmpty
          ? 'Care-plan item'
          : _displayText(json['title']),
      instruction: _displayText(json['instruction']),
      timing: _displayText(json['timing']),
      notes: _displayText(json['notes']),
      sourceUpdatedAt: _displayText(json['sourceUpdatedAt']),
    );
  }

  TeachBackQuestion _questionFromJson(Map<String, dynamic> json) {
    return TeachBackQuestion(
      id: _displayText(json['id']),
      text: _displayText(json['text']),
      focus: _displayText(json['focus']),
      order: _int(json['order']),
    );
  }

  TeachBackAssessment _assessmentFromJson(Map<String, dynamic> json) {
    return TeachBackAssessment(
      id: _displayText(json['id']),
      questionId: _displayText(json['questionId']),
      questionText: _displayText(json['questionText']),
      answerText: _displayText(json['answerText']),
      status: _displayText(json['status']),
      score: _int(json['score']).clamp(0, 100).toInt(),
      matchedPoints: _listOfStrings(json['matchedPoints']),
      missingPoints: _listOfStrings(json['missingPoints']),
      feedback: _displayText(json['feedback']),
      retryPrompt: _displayText(json['retryPrompt']),
      planStatement: _displayText(json['planStatement']),
    );
  }

  TeachBackFinalResult _finalResultFromJson(Map<String, dynamic> json) {
    return TeachBackFinalResult(
      completed: _bool(json['completed']),
      score: _int(json['score']).clamp(0, 100).toInt(),
      status: _displayText(json['status']),
      questionCount: _int(json['questionCount']),
      answeredCount: _int(json['answeredCount']),
      understoodCount: _int(json['understoodCount']),
      needsReviewCount: _int(json['needsReviewCount']),
      weakQuestionIds: _listOfStrings(json['weakQuestionIds']),
    );
  }

  List<Map<String, dynamic>> _listOfMaps(dynamic value) {
    if (value is! List) return const [];
    return value.whereType<Map<String, dynamic>>().toList();
  }

  List<String> _listOfStrings(dynamic value) {
    if (value is! List) return const [];
    return value.map(_displayText).where((item) => item.isNotEmpty).toList();
  }

  bool _bool(dynamic value) => value == true || value == 1 || value == '1';

  int _int(dynamic value) {
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  String _displayText(dynamic value) =>
      value
          ?.toString()
          .replaceAll(
            RegExp(r'[\u0000-\u001F\u007F\u200B-\u200D\u2060\uFEFF]'),
            '',
          )
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim() ??
      '';
}
