import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../core/api_config.dart';
import 'auth_service.dart';

class ProgressException implements Exception {
  const ProgressException(
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

class ProgressScore {
  const ProgressScore({required this.available, required this.score});

  final bool available;
  final int? score;
}

class ProgressTasks {
  const ProgressTasks({
    required this.scheduled,
    required this.completed,
    required this.skipped,
    required this.missed,
    required this.pending,
    required this.completionRate,
  });

  final int scheduled;
  final int completed;
  final int skipped;
  final int missed;
  final int pending;
  final int? completionRate;
}

class ProgressGaps {
  const ProgressGaps({
    required this.total,
    required this.open,
    required this.inProgress,
    required this.resolved,
  });

  final int total;
  final int open;
  final int inProgress;
  final int resolved;
}

class ProgressUnderstanding {
  const ProgressUnderstanding({
    required this.available,
    required this.score,
    required this.planId,
    required this.planTitle,
  });

  final bool available;
  final int? score;
  final String? planId;
  final String? planTitle;
}

class ProgressPlan {
  const ProgressPlan({required this.id, required this.title});

  final String id;
  final String title;
}

class ProgressTrendPoint {
  const ProgressTrendPoint({
    required this.date,
    required this.scheduled,
    required this.completed,
    required this.value,
  });

  final String date;
  final int scheduled;
  final int completed;
  final int? value;
}

class ProgressTrend {
  const ProgressTrend({required this.metric, required this.points});

  final String metric;
  final List<ProgressTrendPoint> points;
}

class ProgressSummary {
  const ProgressSummary({
    required this.date,
    required this.windowDays,
    required this.activePlanCount,
    required this.primaryPlan,
    required this.readiness,
    required this.tasks,
    required this.gaps,
    required this.understanding,
    required this.trend,
  });

  final String date;
  final int windowDays;
  final int activePlanCount;
  final ProgressPlan? primaryPlan;
  final ProgressScore readiness;
  final ProgressTasks tasks;
  final ProgressGaps gaps;
  final ProgressUnderstanding understanding;
  final ProgressTrend trend;
}

abstract class ProgressClient {
  Future<ProgressSummary> fetchSummary({int days = 7});
}

class ProgressService implements ProgressClient {
  ProgressService({http.Client? client, String? Function()? tokenProvider})
    : _client = client ?? http.Client(),
      _tokenProvider = tokenProvider ?? (() => AuthSession.instance.token);

  static final ProgressService instance = ProgressService();
  static const _timeout = Duration(seconds: 20);

  final http.Client _client;
  final String? Function() _tokenProvider;

  @override
  Future<ProgressSummary> fetchSummary({int days = 7}) async {
    final data = await _request('/progress/summary?days=$days');
    return _summaryFromJson(data);
  }

  Future<Map<String, dynamic>> _request(String path) async {
    final token = _tokenProvider();
    if (token == null || token.isEmpty) {
      throw const ProgressException('Please sign in to continue.');
    }

    try {
      final response = await _client
          .get(
            ApiConfig.endpoint(path),
            headers: {
              'Accept': 'application/json',
              'Authorization': 'Bearer $token',
            },
          )
          .timeout(_timeout);
      final decoded = _decode(response);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw ProgressException(
          decoded['message']?.toString() ??
              'Progress could not be loaded. Please try again.',
          statusCode: response.statusCode,
          retryable:
              response.statusCode == 408 ||
              response.statusCode == 429 ||
              response.statusCode >= 500,
        );
      }
      final data = decoded['data'];
      if (data is Map<String, dynamic>) return data;
      throw const ProgressException(
        'The server returned invalid progress data.',
      );
    } on TimeoutException {
      throw const ProgressException(
        'Could not connect to SehatMate. Please try again.',
        retryable: true,
      );
    } on http.ClientException {
      throw const ProgressException(
        'Could not connect to SehatMate. Please check your connection.',
        retryable: true,
      );
    } on FormatException {
      throw const ProgressException(
        'The server returned invalid progress data.',
      );
    }
  }

  Map<String, dynamic> _decode(http.Response response) {
    if (response.bodyBytes.isEmpty) return <String, dynamic>{};
    final decoded = jsonDecode(utf8.decode(response.bodyBytes));
    if (decoded is Map<String, dynamic>) return decoded;
    throw const FormatException('Expected a JSON object.');
  }

  ProgressSummary _summaryFromJson(Map<String, dynamic> json) {
    final primary = json['primaryPlan'] is Map<String, dynamic>
        ? json['primaryPlan'] as Map<String, dynamic>
        : null;
    return ProgressSummary(
      date: _text(json['date']),
      windowDays: _int(json['windowDays']),
      activePlanCount: _int(json['activePlanCount']),
      primaryPlan: primary == null
          ? null
          : ProgressPlan(
              id: _text(primary['id']),
              title: _text(primary['title']).isEmpty
                  ? 'Care plan'
                  : _text(primary['title']),
            ),
      readiness: _score(json['readiness']),
      tasks: _tasks(json['tasks']),
      gaps: _gaps(json['gaps']),
      understanding: _understanding(json['understanding']),
      trend: _trend(json['trend']),
    );
  }

  ProgressScore _score(dynamic value) {
    final json = value is Map<String, dynamic> ? value : const {};
    return ProgressScore(
      available: _bool(json['available']),
      score: json['score'] == null
          ? null
          : _int(json['score']).clamp(0, 100).toInt(),
    );
  }

  ProgressTasks _tasks(dynamic value) {
    final json = value is Map<String, dynamic> ? value : const {};
    return ProgressTasks(
      scheduled: _int(json['scheduled']),
      completed: _int(json['completed']),
      skipped: _int(json['skipped']),
      missed: _int(json['missed']),
      pending: _int(json['pending']),
      completionRate: json['completionRate'] == null
          ? null
          : _int(json['completionRate']).clamp(0, 100).toInt(),
    );
  }

  ProgressGaps _gaps(dynamic value) {
    final json = value is Map<String, dynamic> ? value : const {};
    return ProgressGaps(
      total: _int(json['total']),
      open: _int(json['open']),
      inProgress: _int(json['inProgress']),
      resolved: _int(json['resolved']),
    );
  }

  ProgressUnderstanding _understanding(dynamic value) {
    final json = value is Map<String, dynamic> ? value : const {};
    return ProgressUnderstanding(
      available: _bool(json['available']),
      score: json['score'] == null
          ? null
          : _int(json['score']).clamp(0, 100).toInt(),
      planId: _text(json['planId']).isEmpty ? null : _text(json['planId']),
      planTitle: _text(json['planTitle']).isEmpty
          ? null
          : _text(json['planTitle']),
    );
  }

  ProgressTrend _trend(dynamic value) {
    final json = value is Map<String, dynamic> ? value : const {};
    final points = json['points'] is List
        ? (json['points'] as List)
              .whereType<Map<String, dynamic>>()
              .map(
                (point) => ProgressTrendPoint(
                  date: _text(point['date']),
                  scheduled: _int(point['scheduled']),
                  completed: _int(point['completed']),
                  value: point['value'] == null
                      ? null
                      : _int(point['value']).clamp(0, 100).toInt(),
                ),
              )
              .where((point) => point.date.isNotEmpty)
              .toList()
        : const <ProgressTrendPoint>[];
    return ProgressTrend(metric: _text(json['metric']), points: points);
  }

  bool _bool(dynamic value) => value == true || value == 1 || value == '1';

  int _int(dynamic value) {
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  String _text(dynamic value) =>
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
