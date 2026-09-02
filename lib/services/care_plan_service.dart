import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../core/api_config.dart';
import '../data/demo_data.dart';
import 'auth_service.dart';

class CarePlanException implements Exception {
  const CarePlanException(
    this.message, {
    this.statusCode,
    this.retryable = false,
    this.data,
  });

  final String message;
  final int? statusCode;
  final bool retryable;
  final Map<String, dynamic>? data;

  bool get conflict => statusCode == 409;

  @override
  String toString() => message;
}

class CarePlanUploadArgs {
  const CarePlanUploadArgs({
    required this.planId,
    required this.documentTypes,
    this.guidedSetup = false,
    this.returnToPrevious = false,
  });

  final String planId;
  final List<String> documentTypes;
  final bool guidedSetup;
  final bool returnToPrevious;
}

class CarePlanReviewArgs {
  const CarePlanReviewArgs({
    required this.planId,
    this.guidedSetup = false,
    this.returnToPrevious = false,
  });

  final String planId;
  final bool guidedSetup;
  final bool returnToPrevious;
}

class CareFlowArgs {
  const CareFlowArgs({
    required this.planId,
    this.guidedSetup = false,
    this.returnToPrevious = false,
  });

  final String planId;
  final bool guidedSetup;
  final bool returnToPrevious;
}

class CarePlanDetailArgs {
  const CarePlanDetailArgs({
    this.initialTab = 0,
    this.guidedSetup = false,
    this.returnToPrevious = false,
  });

  final int initialTab;
  final bool guidedSetup;
  final bool returnToPrevious;
}

enum CareSetupStep {
  upload,
  review,
  schedule,
  realityCheck,
  simulation,
  careGaps,
  activate,
  complete,
}

class CareSetupProgress {
  const CareSetupProgress({
    required this.step,
    required this.title,
    required this.description,
  });

  final CareSetupStep step;
  final String title;
  final String description;

  static const totalSteps = 7;

  int get currentNumber => switch (step) {
    CareSetupStep.upload => 1,
    CareSetupStep.review => 2,
    CareSetupStep.schedule => 3,
    CareSetupStep.realityCheck => 4,
    CareSetupStep.simulation => 5,
    CareSetupStep.careGaps => 6,
    CareSetupStep.activate => 7,
    CareSetupStep.complete => 7,
  };

  int get completedCount =>
      step == CareSetupStep.complete ? totalSteps : currentNumber - 1;
}

class PlanRealityQuestion {
  const PlanRealityQuestion({
    required this.key,
    required this.category,
    required this.question,
    required this.options,
    this.intent = '',
    this.responseProfile = '',
    this.targetTaskIds = const [],
    this.period = 'any',
    this.reasonForAsking = '',
    this.source = '',
    this.selectedAnswer = '',
    this.note = '',
  });

  final String key;
  final String category;
  final String question;
  final List<String> options;
  final String intent;
  final String responseProfile;
  final List<String> targetTaskIds;
  final String period;
  final String reasonForAsking;
  final String source;
  final String selectedAnswer;
  final String note;

  bool get isAiGenerated => source.toLowerCase().contains('ai');
}

class PlanRealityCheckData {
  const PlanRealityCheckData({
    required this.source,
    required this.questionSetVersion,
    required this.questions,
  });

  final String source;
  final int? questionSetVersion;
  final List<PlanRealityQuestion> questions;

  bool get isAiPersonalized => source.toLowerCase().contains('ai');
}

class AdaptPlanResult {
  const AdaptPlanResult({required this.appliedCount, required this.keptCount});

  final int appliedCount;
  final int keptCount;
}

class CareSimulationData {
  const CareSimulationData({
    required this.readiness,
    required this.blocked,
    required this.atRisk,
    required this.ready,
    required this.unclear,
    required this.tasks,
    required this.findings,
    required this.adaptations,
    required this.blockers,
    required this.contextInsights,
    required this.unanswered,
    required this.activationAllowed,
    required this.hardBlockerCount,
  });

  final int readiness;
  final int blocked;
  final int atRisk;
  final int ready;
  final int unclear;

  final List<DemoTask> tasks;

  final List<Map<String, dynamic>>
      findings;

  final List<Map<String, dynamic>>
      adaptations;

  final List<Map<String, dynamic>>
      blockers;

  /// Context created from:
  /// - Care Gap "Add information"
  /// - answered healthcare-professional questions
  ///
  /// This context may guide practical next actions,
  /// but it must never automatically change verified
  /// treatment instructions.
  final List<Map<String, dynamic>>
      contextInsights;

  final int unanswered;
  final bool activationAllowed;
  final int hardBlockerCount;
}

class RoutineLearnedPeriod {
  const RoutineLearnedPeriod({
    required this.preferredTime,
    required this.confidence,
    required this.signalCount,
    required this.reason,
  });

  final String preferredTime;
  final String confidence;
  final int signalCount;
  final String reason;
}

class RoutineProfileData {
  const RoutineProfileData({
    required this.learningEnabled,
    required this.preferredReminderStyle,
    required this.notes,
    required this.learned,
    required this.totalSignals,
  });

  final bool learningEnabled;
  final String preferredReminderStyle;
  final Map<String, String> notes;
  final Map<String, RoutineLearnedPeriod> learned;
  final int totalSignals;
}

class CareInstructionReview {
  const CareInstructionReview({
    required this.id,
    required this.category,
    required this.title,
    required this.instruction,
    required this.timing,
    required this.sourcePage,
    required this.confidenceScore,
    required this.reviewStatus,
    required this.requiresProfessionalConfirmation,
    required this.ambiguityReason,
    required this.possibleInterpretation,
    required this.safetyNote,
    required this.safetyCheck,
    required this.originalTitle,
    required this.originalInstruction,
    required this.originalTiming,
    required this.duplicateOfInstructionId,
    required this.duplicateReason,
  });

  final String id;
  final String category;
  final String title;
  final String instruction;
  final String timing;
  final String sourcePage;
  final int? confidenceScore;
  final String reviewStatus;
  final bool requiresProfessionalConfirmation;
  final String ambiguityReason;
  final String possibleInterpretation;
  final String safetyNote;
  final InstructionSafetyCheck? safetyCheck;
  final String originalTitle;
  final String originalInstruction;
  final String originalTiming;
  final String duplicateOfInstructionId;
  final String duplicateReason;

  bool get isCorrected =>
      title.trim() != originalTitle.trim() ||
      instruction.trim() != originalInstruction.trim() ||
      timing.trim() != originalTiming.trim();

  bool get possibleDuplicate => duplicateReason.trim().isNotEmpty;

  CareInstructionReview copyWith({
    String? title,
    String? instruction,
    String? timing,
    String? reviewStatus,
    bool? requiresProfessionalConfirmation,
    String? ambiguityReason,
    String? possibleInterpretation,
    String? safetyNote,
    InstructionSafetyCheck? safetyCheck,
  }) => CareInstructionReview(
    id: id,
    category: category,
    title: title ?? this.title,
    instruction: instruction ?? this.instruction,
    timing: timing ?? this.timing,
    sourcePage: sourcePage,
    confidenceScore: confidenceScore,
    reviewStatus: reviewStatus ?? this.reviewStatus,
    requiresProfessionalConfirmation:
        requiresProfessionalConfirmation ??
        this.requiresProfessionalConfirmation,
    ambiguityReason: ambiguityReason ?? this.ambiguityReason,
    possibleInterpretation:
        possibleInterpretation ?? this.possibleInterpretation,
    safetyNote: safetyNote ?? this.safetyNote,
    safetyCheck: safetyCheck ?? this.safetyCheck,
    originalTitle: originalTitle,
    originalInstruction: originalInstruction,
    originalTiming: originalTiming,
    duplicateOfInstructionId: duplicateOfInstructionId,
    duplicateReason: duplicateReason,
  );
}

class SafetySource {
  const SafetySource({required this.title, required this.url});

  final String title;
  final String url;
}

class InstructionSafetyCheck {
  const InstructionSafetyCheck({
    required this.status,
    required this.summary,
    required this.possibleInterpretation,
    required this.questionForProfessional,
    required this.sources,
  });

  final String status;
  final String summary;
  final String possibleInterpretation;
  final String questionForProfessional;
  final List<SafetySource> sources;
}

class IngredientEvidenceItem {
  const IngredientEvidenceItem({required this.name, required this.strength});

  final String name;
  final String strength;
}

class IngredientEvidence {
  const IngredientEvidence({
    required this.brandName,
    required this.activeIngredients,
    required this.dosageForm,
    required this.manufacturer,
    required this.confidenceScore,
    required this.labelNeedsConfirmation,
    required this.labelNote,
    required this.purposeStatus,
    required this.purposeSummary,
    required this.questionForProfessional,
    required this.sources,
  });

  final String brandName;
  final List<IngredientEvidenceItem> activeIngredients;
  final String dosageForm;
  final String manufacturer;
  final int? confidenceScore;
  final bool labelNeedsConfirmation;
  final String labelNote;
  final String purposeStatus;
  final String purposeSummary;
  final String questionForProfessional;
  final List<SafetySource> sources;
}

class CareTaskOccurrence {
  const CareTaskOccurrence({
    required this.id,
    required this.carePlanId,
    required this.scheduleItemId,
    required this.occurrenceDate,
    required this.scheduledTime,
    required this.title,
    required this.taskKind,
    required this.period,
    required this.recurrenceText,
    required this.grounding,
    required this.status,
    required this.completedAt,
    required this.completedTime,
    required this.outcomeSource,
    required this.note,
    this.planTitle = '',
  });

  final String id;
  final String carePlanId;
  final String scheduleItemId;
  final String occurrenceDate;
  final String scheduledTime;
  final String title;
  final String taskKind;
  final String period;
  final String recurrenceText;
  final String grounding;
  final String status;
  final String completedAt;
  final String completedTime;
  final String outcomeSource;
  final String note;
  final String planTitle;

  bool get completed => status == 'completed';
  bool get skipped => status == 'skipped';
  bool get missed => status == 'missed';
  bool get pending => status == 'pending';

  /// A same-day pending reminder becomes visually overdue 45 minutes after
  /// its scheduled time. It stays pending so the user can still record what
  /// actually happened. On the next local day the backend reconciles it to
  /// `missed` and records the routine-learning signal.
  bool get overdue {
    if (!pending) return false;
    final date = DateTime.tryParse(occurrenceDate);
    final match = RegExp(r'^(\d{1,2}):(\d{2})').firstMatch(scheduledTime);
    if (date == null || match == null) return false;

    final now = DateTime.now();
    if (date.year != now.year ||
        date.month != now.month ||
        date.day != now.day) {
      return false;
    }

    final hour = int.tryParse(match.group(1)!) ?? -1;
    final minute = int.tryParse(match.group(2)!) ?? -1;
    if (hour < 0 || hour > 23 || minute < 0 || minute > 59) return false;

    final dueAt = DateTime(
      date.year,
      date.month,
      date.day,
      hour,
      minute,
    ).add(const Duration(minutes: 45));
    return now.isAfter(dueAt);
  }

  CareTaskOccurrence copyWith({
    String? status,
    String? completedAt,
    String? completedTime,
    String? outcomeSource,
    String? note,
  }) => CareTaskOccurrence(
    id: id,
    carePlanId: carePlanId,
    scheduleItemId: scheduleItemId,
    occurrenceDate: occurrenceDate,
    scheduledTime: scheduledTime,
    title: title,
    taskKind: taskKind,
    period: period,
    recurrenceText: recurrenceText,
    grounding: grounding,
    status: status ?? this.status,
    completedAt: completedAt ?? this.completedAt,
    completedTime: completedTime ?? this.completedTime,
    outcomeSource: outcomeSource ?? this.outcomeSource,
    note: note ?? this.note,
    planTitle: planTitle,
  );
}

class CareTaskDaySummary {
  const CareTaskDaySummary({
    required this.total,
    required this.completed,
    required this.skipped,
    required this.missed,
    required this.pending,
  });

  final int total;
  final int completed;
  final int skipped;
  final int missed;
  final int pending;
}

class CareTaskDayData {
  const CareTaskDayData({
    required this.date,
    required this.planStatus,
    required this.occurrences,
    required this.summary,
  });

  final String date;
  final String planStatus;
  final List<CareTaskOccurrence> occurrences;
  final CareTaskDaySummary summary;
}

class CareTaskOutcomeSummary {
  const CareTaskOutcomeSummary({
    required this.scheduled,
    required this.completed,
    required this.onTime,
    required this.late,
    required this.skipped,
    required this.missed,
    required this.pending,
  });

  final int scheduled;
  final int completed;
  final int onTime;
  final int late;
  final int skipped;
  final int missed;
  final int pending;
}

class CareTaskAppDaySummary {
  const CareTaskAppDaySummary({
    required this.total,
    required this.completed,
    required this.skipped,
    required this.missed,
    required this.pending,
    required this.activePlans,
    required this.openCareGaps,
    required this.careReadiness,
  });

  final int total;
  final int completed;
  final int skipped;
  final int missed;
  final int pending;
  final int activePlans;
  final int openCareGaps;
  final int careReadiness;
}

class CareTaskAppDayData {
  const CareTaskAppDayData({
    required this.date,
    required this.occurrences,
    required this.summary,
  });

  final String date;
  final List<CareTaskOccurrence> occurrences;
  final CareTaskAppDaySummary summary;
}

class CareTaskDailyOutcome {
  const CareTaskDailyOutcome({
    required this.date,
    required this.scheduled,
    required this.completed,
    required this.skipped,
    required this.missed,
    required this.pending,
  });

  final String date;
  final int scheduled;
  final int completed;
  final int skipped;
  final int missed;
  final int pending;

  int get decided => completed + skipped + missed;
  int get completionRate =>
      decided == 0 ? 0 : ((completed / decided) * 100).round();
}

class CareTaskAppOutcomeSummary {
  const CareTaskAppOutcomeSummary({
    required this.startDate,
    required this.endDate,
    required this.days,
    required this.scheduled,
    required this.completed,
    required this.onTime,
    required this.late,
    required this.skipped,
    required this.missed,
    required this.pending,
    required this.daily,
  });

  final String startDate;
  final String endDate;
  final int days;
  final int scheduled;
  final int completed;
  final int onTime;
  final int late;
  final int skipped;
  final int missed;
  final int pending;
  final List<CareTaskDailyOutcome> daily;

  int get decided => completed + skipped + missed;
  int get completionRate =>
      decided == 0 ? 0 : ((completed / decided) * 100).round();
}

class CarePlanDetailData {
  const CarePlanDetailData({
    required this.plan,
    required this.instructions,
    required this.tasks,
    required this.gaps,
    required this.documents,
  });

  final DemoPlan plan;
  final List<DemoTask> instructions;
  final List<DemoTask> tasks;
  final List<DemoGap> gaps;
  final List<DemoDocument> documents;
}

class CareGapSummaryData {
  const CareGapSummaryData({
    required this.total,
    required this.open,
    required this.blocking,
    required this.attention,
    required this.inProgress,
    required this.resolved,
  });

  final int total;
  final int open;
  final int blocking;
  final int attention;
  final int inProgress;
  final int resolved;
}

class CareGapItemData {
  const CareGapItemData({
    required this.id,
    required this.carePlanId,
    required this.taskId,
    required this.category,
    required this.gapType,
    required this.title,
    required this.status,
    required this.severity,
    required this.lifecycleStatus,
    required this.whenText,
    required this.summary,
    required this.instructionSnapshot,
    required this.patientReality,
    required this.reason,
    required this.nextStep,
    required this.resolutionNote,
    required this.sourceKind,
    required this.sourceId,
    required this.dueAt,
    required this.autoManaged,
    required this.blocking,
    required this.actionType,
    required this.actionLabel,
    required this.resolutionTitle,
    required this.resolutionSteps,
    required this.autoRecheck,
    required this.targetCarePlanId,
    required this.targetSourceKind,
    required this.targetSourceId,
    required this.targetCarePlanTab,
    required this.displaySeverity,
    required this.canMarkResolved,
  });

  final String id;
  final String carePlanId;
  final String? taskId;
  final String category;
  final String gapType;
  final String title;
  final String status;
  final String severity;
  final String lifecycleStatus;
  final String whenText;
  final String summary;
  final String instructionSnapshot;
  final String patientReality;
  final String reason;
  final String nextStep;
  final String resolutionNote;
  final String sourceKind;
  final String sourceId;
  final String dueAt;
  final bool autoManaged;
  final bool blocking;
  final String actionType;
  final String actionLabel;
  final String resolutionTitle;
  final List<String> resolutionSteps;
  final bool autoRecheck;
  final String targetCarePlanId;
  final String targetSourceKind;
  final String targetSourceId;
  final int? targetCarePlanTab;
  final String displaySeverity;
  final bool canMarkResolved;

  bool get isResolved => lifecycleStatus == 'resolved';
  bool get isInProgress => lifecycleStatus == 'in_progress';

  TaskStatus get badgeStatus {
    if (isResolved) return TaskStatus.resolved;
    return switch (status) {
      'blocked' => TaskStatus.blocked,
      'unclear' => TaskStatus.unclear,
      'at_risk' => TaskStatus.atRisk,
      _ => severity == 'blocking' ? TaskStatus.blocked : TaskStatus.atRisk,
    };
  }

  String get severityLabel {
    if (displaySeverity == 'previously_blocking' ||
        (isResolved && severity == 'blocking')) {
      return 'Previously blocking';
    }
    return severity == 'blocking' ? 'Blocking' : 'Needs attention';
  }

  bool get severityWasBlocking => severity == 'blocking';

  String get lifecycleLabel => switch (lifecycleStatus) {
    'in_progress' => 'In progress',
    'resolved' => 'Resolved',
    _ => 'Open',
  };

  String get typeLabel => switch (gapType) {
    'missing_information' => 'Missing information',
    'schedule_gap' => 'Schedule gap',
    'overdue' => 'Overdue',
    'verification' => 'Verification',
    'document_gap' => 'Document gap',
    'care_coordination' => 'Care coordination',
    _ => category.isEmpty ? 'Care gap' : category,
  };
}

class CareGapDoctorQuestionData {
  const CareGapDoctorQuestionData({
    required this.id,
    required this.groupName,
    required this.title,
    required this.question,
    required this.answer,
    required this.status,
  });

  final String id;
  final String groupName;
  final String title;
  final String question;
  final String answer;
  final String status;

  bool get answered => status == 'answered';
}

class CareGapListData {
  const CareGapListData({required this.summary, required this.gaps});

  final CareGapSummaryData summary;
  final List<CareGapItemData> gaps;
}

class CareGapDetailData {
  const CareGapDetailData({required this.gap, required this.doctorQuestions});

  final CareGapItemData gap;
  final List<CareGapDoctorQuestionData> doctorQuestions;
}

class CarePlanService {
  CarePlanService._();

  static final CarePlanService instance = CarePlanService._();
  static const _timeout = Duration(seconds: 20);

  final http.Client _client = http.Client();

  static const _cachePrefix = 'sehatmate_care_cache_v1';

  String _cacheKey(String suffix) {
    final userId = AuthSession.instance.user?.id ?? 'guest';
    return '$_cachePrefix:$userId:$suffix';
  }

  Future<void> _writeCache(String suffix, Map<String, dynamic> data) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_cacheKey(suffix), jsonEncode(data));
    } catch (_) {
      // Cache failures must never block authoritative care data.
    }
  }

  Future<Map<String, dynamic>?> _readCache(String suffix) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_cacheKey(suffix));
      if (raw == null || raw.isEmpty) return null;
      final decoded = jsonDecode(raw);
      return decoded is Map<String, dynamic> ? decoded : null;
    } catch (_) {
      return null;
    }
  }

  Future<void> _removeCache(String suffix) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_cacheKey(suffix));
    } catch (_) {
      // Cache invalidation must never block the authoritative server change.
    }
  }

  Future<void> _removeCachePrefixes(List<String> suffixPrefixes) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final prefixes = suffixPrefixes.map(_cacheKey).toList();
      final keys = prefs
          .getKeys()
          .where((key) => prefixes.any(key.startsWith))
          .toList();
      for (final key in keys) {
        await prefs.remove(key);
      }
    } catch (_) {
      // The next successful network refresh will rebuild these caches.
    }
  }

  Future<void> clearUserCache() async {
    final prefs = await SharedPreferences.getInstance();
    final prefix = '$_cachePrefix:${AuthSession.instance.user?.id ?? 'guest'}:';
    final keys = prefs
        .getKeys()
        .where((key) => key.startsWith(prefix))
        .toList();
    for (final key in keys) {
      await prefs.remove(key);
    }
  }

  CareSetupProgress _progressForStep(CareSetupStep step) => switch (step) {
    CareSetupStep.upload => const CareSetupProgress(
      step: CareSetupStep.upload,
      title: 'Upload & extract documents',
      description: 'Add the source documents and extract their instructions.',
    ),
    CareSetupStep.review => const CareSetupProgress(
      step: CareSetupStep.review,
      title: 'Review extracted instructions',
      description:
          'Check every extracted instruction against the original document.',
    ),
    CareSetupStep.schedule => const CareSetupProgress(
      step: CareSetupStep.schedule,
      title: 'Finish schedule setup',
      description: 'Confirm every required reminder period and exact time.',
    ),
    CareSetupStep.realityCheck => const CareSetupProgress(
      step: CareSetupStep.realityCheck,
      title: 'Continue Reality Check',
      description: 'Answer the remaining practical routine questions.',
    ),
    CareSetupStep.simulation => const CareSetupProgress(
      step: CareSetupStep.simulation,
      title: 'Review simulation',
      description: 'Review practical fit and SehatMate suggestions.',
    ),
    CareSetupStep.careGaps => const CareSetupProgress(
      step: CareSetupStep.careGaps,
      title: 'Review Care Gaps',
      description:
          'Resolve only the required blockers before the final simulation.',
    ),
    CareSetupStep.activate => const CareSetupProgress(
      step: CareSetupStep.activate,
      title: 'Final review & activation',
      description: 'Review the updated simulation and activate the care plan.',
    ),
    CareSetupStep.complete => const CareSetupProgress(
      step: CareSetupStep.complete,
      title: 'Open care plan',
      description: 'This care plan has finished setup.',
    ),
  };

  CareSetupStep _setupStepFromApi(Object? value) =>
      switch (_displayText(value)) {
        'upload' => CareSetupStep.upload,
        'review' => CareSetupStep.review,
        'schedule' => CareSetupStep.schedule,
        'reality_check' => CareSetupStep.realityCheck,
        'simulation' => CareSetupStep.simulation,
        'care_gaps' => CareSetupStep.careGaps,
        'activate' => CareSetupStep.activate,
        'complete' => CareSetupStep.complete,
        _ => CareSetupStep.upload,
      };

  String _setupStepApiValue(CareSetupStep step) => switch (step) {
    CareSetupStep.upload => 'upload',
    CareSetupStep.review => 'review',
    CareSetupStep.schedule => 'schedule',
    CareSetupStep.realityCheck => 'reality_check',
    CareSetupStep.simulation => 'simulation',
    CareSetupStep.careGaps => 'care_gaps',
    CareSetupStep.activate => 'activate',
    CareSetupStep.complete => 'complete',
  };

  Future<CareSetupProgress> fetchSetupProgress(String planId) async {
    final data = await _request('GET', '/care-plans/$planId/setup-progress');
    return _progressForStep(_setupStepFromApi(data['step']));
  }

  Future<void> updateSetupStep(String planId, CareSetupStep step) async {
    await _request(
      'PATCH',
      '/care-plans/$planId/setup-progress',
      body: {'step': _setupStepApiValue(step)},
    );
  }

  Future<CareSetupProgress> resolveSetupProgress(DemoPlan plan) async {
    if (plan.status == PlanStatus.active ||
        plan.status == PlanStatus.completed) {
      return _progressForStep(CareSetupStep.complete);
    }

    try {
      return await fetchSetupProgress(plan.id);
    } on CarePlanException {
      // Compatibility fallback for a backend that has not been restarted yet.
    }

    if (plan.status == PlanStatus.draft ||
        plan.status == PlanStatus.processing) {
      return _progressForStep(CareSetupStep.upload);
    }
    if (plan.status == PlanStatus.needsReview) {
      return _progressForStep(CareSetupStep.review);
    }

    final detail = await fetchPlanDetail(plan.id);
    if (detail.tasks.isEmpty ||
        detail.tasks.any(
          (task) =>
              task.status == TaskStatus.atRisk ||
              task.status == TaskStatus.unclear,
        )) {
      return _progressForStep(CareSetupStep.schedule);
    }

    try {
      final questions = await fetchRealityQuestions(plan.id);
      if (questions.any((question) => question.selectedAnswer.isEmpty)) {
        return _progressForStep(CareSetupStep.realityCheck);
      }
    } on CarePlanException {
      return _progressForStep(CareSetupStep.schedule);
    }

    return _progressForStep(CareSetupStep.simulation);
  }

  Future<List<DemoPlan>> fetchPlans() async {
    Map<String, dynamic> data;
    try {
      data = await _request('GET', '/care-plans');
      await _writeCache('plans', data);
    } on CarePlanException catch (error) {
      if (!error.retryable) rethrow;
      final cached = await _readCache('plans');
      if (cached == null) rethrow;
      data = cached;
    }

    final plans = data['plans'];
    if (plans is! List) {
      throw const CarePlanException(
        'The server returned an invalid plan list.',
      );
    }

    return plans.whereType<Map<String, dynamic>>().map(_planFromJson).toList();
  }

  Future<DemoPlan> createPlan(String title) async {
    final data = await _request(
      'POST',
      '/care-plans',
      body: {'title': title.trim()},
    );
    final plan = data['plan'];
    if (plan is! Map<String, dynamic>) {
      throw const CarePlanException(
        'The server returned an invalid care plan.',
      );
    }
    return _planFromJson(plan);
  }

  Future<void> deletePlan(String planId) async {
    await _request('DELETE', '/care-plans/$planId');
  }

  Future<void> deletePlans(List<String> planIds) async {
    await _request(
      'POST',
      '/care-plans/bulk-delete',
      body: {'planIds': planIds},
    );
  }

  Future<void> savePlanDuration(
    String planId, {
    required String mode,
    String? endDate,
  }) async {
    await _request(
      'PATCH',
      '/care-plans/$planId/duration',
      body: {'mode': mode, 'endDate': endDate},
    );
  }

  Future<void> completePlan(String planId) async {
    await _request(
      'PATCH',
      '/care-plans/$planId/status',
      body: const {'status': 'completed'},
    );
  }

  Future<CarePlanDetailData> reactivatePlan(String planId) async {
    await _request(
      'PATCH',
      '/care-plans/$planId/status',
      body: const {'status': 'active'},
    );
    return fetchPlanDetail(planId);
  }

  String _dateKey(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-'
      '${value.month.toString().padLeft(2, '0')}-'
      '${value.day.toString().padLeft(2, '0')}';

  Future<CareTaskAppDayData> fetchAllTaskOccurrences({DateTime? date}) async {
    final target = date ?? DateTime.now();
    final targetDate = _dateKey(target);
    final today = _dateKey(DateTime.now());
    final cacheSuffix = 'task-day:$targetDate';

    Map<String, dynamic> data;
    try {
      data = await _request(
        'GET',
        '/task-occurrences?date=$targetDate&today=$today',
      );
      await _writeCache(cacheSuffix, data);
    } on CarePlanException catch (error) {
      if (!error.retryable) rethrow;
      final cached = await _readCache(cacheSuffix);
      if (cached == null) rethrow;
      data = cached;
    }

    final summary = data['summary'] is Map<String, dynamic>
        ? data['summary'] as Map<String, dynamic>
        : <String, dynamic>{};

    return CareTaskAppDayData(
      date: _displayText(data['date']),
      occurrences: _listOfMaps(
        data['occurrences'],
      ).map(_taskOccurrenceFromJson).toList(),
      summary: CareTaskAppDaySummary(
        total: _integer(summary['total']),
        completed: _integer(summary['completed']),
        skipped: _integer(summary['skipped']),
        missed: _integer(summary['missed']),
        pending: _integer(summary['pending']),
        activePlans: _integer(summary['activePlans']),
        openCareGaps: _integer(summary['openCareGaps']),
        careReadiness: _integer(summary['careReadiness']),
      ),
    );
  }

  Future<CareTaskAppOutcomeSummary> fetchAllTaskOutcomeSummary({
    int days = 7,
  }) async {
    final safeDays = days.clamp(1, 31).toInt();
    final now = DateTime.now();
    final endDate = _dateKey(now);
    final cacheSuffix = 'task-summary:$safeDays:$endDate';

    Map<String, dynamic> data;
    try {
      data = await _request(
        'GET',
        '/task-outcomes/summary?days=$safeDays&endDate=$endDate&today=$endDate',
      );
      await _writeCache(cacheSuffix, data);
    } on CarePlanException catch (error) {
      if (!error.retryable) rethrow;
      final cached = await _readCache(cacheSuffix);
      if (cached == null) rethrow;
      data = cached;
    }

    final summary = data['summary'] is Map<String, dynamic>
        ? data['summary'] as Map<String, dynamic>
        : <String, dynamic>{};

    return CareTaskAppOutcomeSummary(
      startDate: _displayText(data['startDate']),
      endDate: _displayText(data['endDate']),
      days: _integer(data['days']),
      scheduled: _integer(summary['scheduled']),
      completed: _integer(summary['completed']),
      onTime: _integer(summary['onTime']),
      late: _integer(summary['late']),
      skipped: _integer(summary['skipped']),
      missed: _integer(summary['missed']),
      pending: _integer(summary['pending']),
      daily: _listOfMaps(data['daily'])
          .map(
            (item) => CareTaskDailyOutcome(
              date: _displayText(item['date']),
              scheduled: _integer(item['scheduled']),
              completed: _integer(item['completed']),
              skipped: _integer(item['skipped']),
              missed: _integer(item['missed']),
              pending: _integer(item['pending']),
            ),
          )
          .toList(),
    );
  }

  Future<CareTaskDayData> fetchTaskOccurrences(
    String planId, {
    DateTime? date,
  }) async {
    final target = date ?? DateTime.now();
    final targetDate = _dateKey(target);
    final today = _dateKey(DateTime.now());
    final data = await _request(
      'GET',
      '/care-plans/$planId/task-occurrences?date=$targetDate&today=$today',
    );
    final summary = data['summary'] is Map<String, dynamic>
        ? data['summary'] as Map<String, dynamic>
        : <String, dynamic>{};
    return CareTaskDayData(
      date: _displayText(data['date']),
      planStatus: _displayText(data['planStatus']),
      occurrences: _listOfMaps(
        data['occurrences'],
      ).map(_taskOccurrenceFromJson).toList(),
      summary: CareTaskDaySummary(
        total: _integer(summary['total']),
        completed: _integer(summary['completed']),
        skipped: _integer(summary['skipped']),
        missed: _integer(summary['missed']),
        pending: _integer(summary['pending']),
      ),
    );
  }

  Future<CareTaskOccurrence> setTaskOccurrenceOutcome(
    String occurrenceId, {
    required String status,
    String note = '',
    String operationKey = '',
    String baseStatus = '',
  }) async {
    final data = await _request(
      'PATCH',
      '/task-occurrences/$occurrenceId/outcome',
      body: {
        'status': status,
        'note': note.trim(),
        'today': _dateKey(DateTime.now()),
        if (operationKey.trim().isNotEmpty) 'operationKey': operationKey.trim(),
        if (baseStatus.trim().isNotEmpty) 'baseStatus': baseStatus.trim(),
      },
    );
    final occurrence = data['occurrence'];
    if (occurrence is! Map<String, dynamic>) {
      throw const CarePlanException(
        'The server returned an invalid task outcome.',
      );
    }
    return _taskOccurrenceFromJson(occurrence);
  }

  CareTaskOccurrence taskOccurrenceFromJson(Map<String, dynamic> json) =>
      _taskOccurrenceFromJson(json);

  Map<String, dynamic> taskOccurrenceToJson(CareTaskOccurrence item) => {
    'id': item.id,
    'carePlanId': item.carePlanId,
    'scheduleItemId': item.scheduleItemId,
    'occurrenceDate': item.occurrenceDate,
    'scheduledTime': item.scheduledTime,
    'title': item.title,
    'taskKind': item.taskKind,
    'period': item.period,
    'recurrenceText': item.recurrenceText,
    'grounding': item.grounding,
    'status': item.status,
    'completedAt': item.completedAt,
    'completedTime': item.completedTime,
    'outcomeSource': item.outcomeSource,
    'note': item.note,
    'planTitle': item.planTitle,
  };

  Future<void> applyOptimisticOutcomeToCaches(
    CareTaskOccurrence before,
    CareTaskOccurrence after,
  ) async {
    final daySuffix = 'task-day:${before.occurrenceDate}';
    final day = await _readCache(daySuffix);
    if (day != null) {
      final occurrences = _listOfMaps(day['occurrences']);
      if (occurrences.any((item) => _displayText(item['id']) == before.id)) {
        day['occurrences'] = occurrences
            .map(
              (item) => _displayText(item['id']) == before.id
                  ? taskOccurrenceToJson(after)
                  : item,
            )
            .toList();
        final summary = day['summary'] is Map<String, dynamic>
            ? Map<String, dynamic>.from(day['summary'] as Map<String, dynamic>)
            : <String, dynamic>{};
        _adjustStatusCounters(summary, before.status, after.status);
        day['summary'] = summary;
        await _writeCache(daySuffix, day);
      }
    }

    final prefs = await SharedPreferences.getInstance();
    final prefix = _cacheKey('task-summary:');
    final keys = prefs
        .getKeys()
        .where((key) => key.startsWith(prefix))
        .toList();
    for (final key in keys) {
      try {
        final raw = prefs.getString(key);
        if (raw == null) continue;
        final decoded = jsonDecode(raw);
        if (decoded is! Map<String, dynamic>) continue;
        final data = Map<String, dynamic>.from(decoded);
        final startDate = _displayText(data['startDate']);
        final endDate = _displayText(data['endDate']);
        if (before.occurrenceDate.compareTo(startDate) < 0 ||
            before.occurrenceDate.compareTo(endDate) > 0) {
          continue;
        }

        final summary = data['summary'] is Map<String, dynamic>
            ? Map<String, dynamic>.from(data['summary'] as Map<String, dynamic>)
            : <String, dynamic>{};
        _adjustStatusCounters(summary, before.status, after.status);
        data['summary'] = summary;

        final daily = _listOfMaps(data['daily']);
        data['daily'] = daily.map((item) {
          if (_displayText(item['date']) != before.occurrenceDate) return item;
          final copy = Map<String, dynamic>.from(item);
          _adjustStatusCounters(copy, before.status, after.status);
          return copy;
        }).toList();

        await prefs.setString(key, jsonEncode(data));
      } catch (_) {
        // The next successful online refresh replaces any stale cache.
      }
    }
  }

  void _adjustStatusCounters(
    Map<String, dynamic> counters,
    String before,
    String after,
  ) {
    if (before == after) return;
    if (counters.containsKey(before)) {
      counters[before] = (_integer(counters[before]) - 1).clamp(0, 1 << 30);
    }
    if (counters.containsKey(after)) {
      counters[after] = _integer(counters[after]) + 1;
    }
  }

  Future<CareTaskOutcomeSummary> fetchTaskOutcomeSummary(
    String planId, {
    int days = 7,
  }) async {
    final safeDays = days.clamp(1, 31);
    final endDate = _dateKey(DateTime.now());
    final data = await _request(
      'GET',
      '/care-plans/$planId/task-outcomes/summary'
          '?days=$safeDays&endDate=$endDate&today=$endDate',
    );
    final summary = data['summary'] is Map<String, dynamic>
        ? data['summary'] as Map<String, dynamic>
        : <String, dynamic>{};
    return CareTaskOutcomeSummary(
      scheduled: _integer(summary['scheduled']),
      completed: _integer(summary['completed']),
      onTime: _integer(summary['onTime']),
      late: _integer(summary['late']),
      skipped: _integer(summary['skipped']),
      missed: _integer(summary['missed']),
      pending: _integer(summary['pending']),
    );
  }

  Future<CarePlanDetailData> fetchPlanDetail(String planId) async {
    Map<String, dynamic> data;
    try {
      data = await _request('GET', '/care-plans/$planId');
      await _writeCache('plan:$planId', data);
    } on CarePlanException catch (error) {
      if (!error.retryable) rethrow;
      final cached = await _readCache('plan:$planId');
      if (cached == null) rethrow;
      data = cached;
    }
    final planJson = data['plan'];
    if (planJson is! Map<String, dynamic>) {
      throw const CarePlanException(
        'The server returned an invalid care plan.',
      );
    }

    final plan = _planFromJson(planJson);
    final instructions = _listOfMaps(
      data.containsKey('verifiedInstructions')
          ? data['verifiedInstructions']
          : data['instructions'],
    ).map(_instructionFromJson).toList();
    final tasks = _listOfMaps(data['tasks']).map(_taskFromJson).toList();
    final gaps = _listOfMaps(data['gaps']).map(_gapFromJson).toList();
    final documents = _listOfMaps(
      data['documents'],
    ).map((item) => _documentFromJson(item, plan.title)).toList();

    return CarePlanDetailData(
      plan: plan,
      instructions: instructions,
      tasks: tasks,
      gaps: gaps,
      documents: documents,
    );
  }

  Future<String> uploadDocument({
    required String planId,
    required String documentType,
    required String originalName,
    required String mimeType,
    required List<int> bytes,
  }) async {
    if (bytes.isEmpty || bytes.length > 20 * 1024 * 1024) {
      throw const CarePlanException(
        'The document is empty or exceeds the 20 MB limit.',
      );
    }
    final data = await _request(
      'POST',
      '/care-plans/$planId/documents',
      body: {
        'documentType': documentType,
        'originalName': originalName,
        'mimeType': mimeType,
        'contentBase64': base64Encode(bytes),
      },
    );
    final document = data['document'];
    if (document is! Map<String, dynamic>) {
      throw const CarePlanException('The server returned an invalid document.');
    }
    final documentId = document['id']?.toString() ?? '';
    if (documentId.isEmpty) {
      throw const CarePlanException('The server did not return a document ID.');
    }
    return documentId;
  }

  Future<void> deleteDocument(String documentId) async {
    await _request('DELETE', '/documents/$documentId');
  }

  Future<Map<String, dynamic>> deleteInstruction(String instructionId) async {
    final data = await _request('DELETE', '/instructions/$instructionId');
    final planId = _displayText(data['planId']);

    // A destructive instruction change invalidates the old schedule snapshot.
    // Without this, an offline-fallback read could resurrect a deleted
    // medicine card even though MySQL has already removed its schedule row.
    if (planId.isNotEmpty) {
      await _removeCache('plan:$planId');
    }
    await _removeCache('plans');
    await _removeCachePrefixes(['task-day:', 'task-summary:']);

    return data;
  }

  Future<int> extractInstructions(String planId) async {
    final data = await _request(
      'POST',
      '/care-plans/$planId/extract',
      timeout: const Duration(minutes: 3),
    );
    return _integer(data['instructionCount']);
  }

  Future<List<CareInstructionReview>> fetchReviewInstructions(
    String planId,
  ) async {
    final data = await _request('GET', '/care-plans/$planId');
    return _listOfMaps(data['instructions'])
        .map((json) {
          final category = _displayText(json['category']);
          final reviewStatus = _displayText(json['review_status']);
          return CareInstructionReview(
            id: _displayText(json['id']),
            category: category.isEmpty ? 'other' : category,
            title: _displayText(json['title']),
            instruction: _displayText(json['instruction']),
            timing: _displayText(json['timing']),
            sourcePage: _displayText(json['source_page']),
            confidenceScore: json['confidence_score'] == null
                ? null
                : _integer(json['confidence_score']).clamp(0, 100).toInt(),
            reviewStatus: reviewStatus.isEmpty ? 'pending' : reviewStatus,
            requiresProfessionalConfirmation: _boolean(
              json['requires_professional_confirmation'],
            ),
            ambiguityReason: _displayText(json['ambiguity_reason']),
            possibleInterpretation: _displayText(
              json['possible_interpretation'],
            ),
            safetyNote: _displayText(json['safety_note']),
            safetyCheck: _safetyCheckFromInstruction(json),
            originalTitle: _displayText(json['original_title']).isEmpty
                ? _displayText(json['title'])
                : _displayText(json['original_title']),
            originalInstruction:
                _displayText(json['original_instruction']).isEmpty
                ? _displayText(json['instruction'])
                : _displayText(json['original_instruction']),
            originalTiming: _displayText(json['original_timing']),
            duplicateOfInstructionId: _displayText(
              json['duplicate_of_instruction_id'],
            ),
            duplicateReason: _displayText(json['duplicate_reason']),
          );
        })
        .where(
          (item) =>
              item.id.isNotEmpty &&
              item.title.trim().isNotEmpty &&
              item.instruction.trim().isNotEmpty,
        )
        .toList();
  }

  Future<void> reviewInstruction({
    required String instructionId,
    required String title,
    required String instruction,
    required String timing,
    required String reviewStatus,
  }) async {
    await _request(
      'PATCH',
      '/instructions/$instructionId',
      body: {
        'title': title.trim(),
        'instruction': instruction.trim(),
        'timing': timing.trim(),
        'reviewStatus': reviewStatus,
      },
    );
  }

  Future<InstructionSafetyCheck> checkInstructionSafety(
    String instructionId,
  ) async {
    final data = await _request(
      'POST',
      '/instructions/$instructionId/safety-check',
      timeout: const Duration(minutes: 2),
    );
    final check = data['safetyCheck'];
    if (check is! Map<String, dynamic>) {
      throw const CarePlanException(
        'The server returned an invalid safety check.',
      );
    }
    return _safetyCheckFromJson(check);
  }

  Future<IngredientEvidence> analyzeIngredientEvidence({
    required String instructionId,
    required String originalName,
    required String mimeType,
    required List<int> bytes,
  }) async {
    if (bytes.isEmpty || bytes.length > 10 * 1024 * 1024) {
      throw const CarePlanException(
        'The label image is empty or exceeds the 10 MB limit.',
      );
    }
    final data = await _request(
      'POST',
      '/instructions/$instructionId/ingredient-evidence',
      body: {
        'originalName': originalName,
        'mimeType': mimeType,
        'contentBase64': base64Encode(bytes),
      },
      timeout: const Duration(minutes: 3),
    );
    final evidence = data['evidence'];
    if (evidence is! Map<String, dynamic>) {
      throw const CarePlanException(
        'The server returned invalid ingredient evidence.',
      );
    }
    final confidence = evidence['confidenceScore'];
    return IngredientEvidence(
      brandName: _displayText(evidence['brandName']),
      activeIngredients: _listOfMaps(evidence['activeIngredients'])
          .map(
            (item) => IngredientEvidenceItem(
              name: _displayText(item['name']),
              strength: _displayText(item['strength']),
            ),
          )
          .where((item) => item.name.isNotEmpty)
          .toList(),
      dosageForm: _displayText(evidence['dosageForm']),
      manufacturer: _displayText(evidence['manufacturer']),
      confidenceScore: confidence == null
          ? null
          : _integer(confidence).clamp(0, 100).toInt(),
      labelNeedsConfirmation: _boolean(evidence['labelNeedsConfirmation']),
      labelNote: _displayText(evidence['labelNote']),
      purposeStatus: _displayText(evidence['purposeStatus']),
      purposeSummary: _displayText(evidence['purposeSummary']),
      questionForProfessional: _displayText(
        evidence['questionForProfessional'],
      ),
      sources: _listOfMaps(evidence['sources'])
          .map(
            (item) => SafetySource(
              title: _displayText(item['title']).isEmpty
                  ? 'Trusted health source'
                  : _displayText(item['title']),
              url: _displayText(item['url']),
            ),
          )
          .where((source) => source.url.isNotEmpty)
          .toList(),
    );
  }

  Future<void> finalizeReview(String planId) async {
    await _request('POST', '/care-plans/$planId/finalize-review');
  }

  Future<void> generateSchedule(String planId) async {
    await _request(
      'POST',
      '/care-plans/$planId/generate-schedule',
      timeout: const Duration(minutes: 2),
    );
  }

  Future<void> confirmScheduleItem(
    String itemId, {
    required String scheduleTime,
    String displayTime = '',
    String learningSource = '',
  }) async {
    await _request(
      'PATCH',
      '/schedule-items/$itemId/confirm',
      body: {
        'scheduleTime': scheduleTime.trim(),
        'displayTime': displayTime.trim(),
        if (learningSource.trim().isNotEmpty)
          'learningSource': learningSource.trim(),
      },
    );
  }

  Future<PlanRealityCheckData> fetchRealityCheck(String planId) async {
    final data = await _request('GET', '/care-plans/$planId/reality-check');
    final questions = _listOfMaps(data['questions'])
        .map(
          (item) => PlanRealityQuestion(
            key: _displayText(item['key']),
            category: _displayText(item['category']),
            question: _displayText(item['question']),
            options: item['options'] is List
                ? (item['options'] as List)
                      .map(_displayText)
                      .where((value) => value.isNotEmpty)
                      .toList()
                : const [],
            intent: _displayText(item['intent']),
            responseProfile: _displayText(
              item['responseProfile'] ?? item['responseType'],
            ),
            targetTaskIds: item['targetTaskIds'] is List
                ? (item['targetTaskIds'] as List)
                      .map(_displayText)
                      .where((value) => value.isNotEmpty)
                      .toList()
                : const [],
            period: _displayText(item['period']).isEmpty
                ? 'any'
                : _displayText(item['period']),
            reasonForAsking: _displayText(item['reasonForAsking']),
            source: _displayText(item['source']),
            selectedAnswer: _displayText(item['selectedAnswer']),
            note: _displayText(item['note']),
          ),
        )
        .where((item) => item.key.isNotEmpty && item.question.isNotEmpty)
        .toList();

    final rawVersion = data['questionSetVersion'];
    return PlanRealityCheckData(
      source: _displayText(data['source']),
      questionSetVersion: rawVersion == null ? null : _integer(rawVersion),
      questions: questions,
    );
  }

  Future<List<PlanRealityQuestion>> fetchRealityQuestions(String planId) async {
    return (await fetchRealityCheck(planId)).questions;
  }

  Future<void> saveRealityAnswers(
    String planId,
    List<Map<String, String>> answers, {
    int? questionSetVersion,
  }) async {
    await _request(
      'POST',
      '/care-plans/$planId/reality-check',
      body: {
        'answers': answers,
        if (questionSetVersion != null)
          'questionSetVersion': questionSetVersion,
      },
    );
  }

  Future<AdaptPlanResult> adaptPlan(
    String planId,
    List<Map<String, String>> adjustments,
  ) async {
    final data = await _request(
      'POST',
      '/care-plans/$planId/adapt-plan',
      body: {'adjustments': adjustments},
    );
    return AdaptPlanResult(
      appliedCount: _integer(data['appliedCount']),
      keptCount: _integer(data['keptCount']),
    );
  }

  Future<CareSimulationData> fetchSimulation(String planId) async {
    final data = await _request('GET', '/care-plans/$planId/simulation');
    final metrics = data['metrics'] is Map<String, dynamic>
        ? data['metrics'] as Map<String, dynamic>
        : <String, dynamic>{};

    final findingsCount = data['findings'] is List
        ? (data['findings'] as List).length
        : 0;
    final adaptationsCount = data['adaptations'] is List
        ? (data['adaptations'] as List).length
        : 0;
    debugPrint(
      '[SehatMate Simulation API] plan=$planId '
      'readiness=${data['readiness']} '
      'atRisk=${metrics['atRisk']} '
      'blocked=${metrics['blocked']} '
      'findings=$findingsCount '
      'adaptations=$adaptationsCount '
      'unanswered=${data['unanswered']}',
    );

    return CareSimulationData(
      readiness: _integer(data['readiness']).clamp(0, 100).toInt(),
      blocked: _integer(metrics['blocked']),
      atRisk: _integer(metrics['atRisk']),
      ready: _integer(metrics['ready']),
      unclear: _integer(metrics['unclear']),
      tasks: _listOfMaps(data['tasks'])
          .map(
            (item) => DemoTask(
              id: _displayText(item['id']),
              day: _displayText(item['schedule_date']),
              time: _displayText(item['schedule_time']).isNotEmpty
                  ? _displayText(item['schedule_time'])
                  : (_displayText(item['display_time']).isNotEmpty
                        ? _displayText(item['display_time'])
                        : 'Review timing'),
              title: _displayText(item['title']),
              note: [
                _displayText(item['recurrence_text']),
                _displayText(item['reason']),
              ].where((value) => value.isNotEmpty).join(' · '),
              kind: _taskKind(_displayText(item['task_kind'])),
              status: _taskStatus(_displayText(item['status'])),
              grounding: _displayText(item['grounding']),
            ),
          )
          .toList(),
      findings: _listOfMaps(data['findings']),
      adaptations: _listOfMaps(data['adaptations']),
      blockers: _listOfMaps(data['blockers']),
      contextInsights:
    _listOfMaps(
  data['contextInsights'],
),
      unanswered: _integer(data['unanswered']),
      activationAllowed: data['activationAllowed'] == true,
      hardBlockerCount: _integer(data['hardBlockerCount']),
    );
  }

  Future<RoutineProfileData> fetchRoutineProfile() async {
    Map<String, dynamic> data;
    try {
      data = await _request('GET', '/routine-profile');
      await _writeCache('routine-profile', data);
    } on CarePlanException catch (error) {
      if (!error.retryable) rethrow;
      final cached = await _readCache('routine-profile');
      if (cached == null) rethrow;
      data = cached;
    }
    final profile = data['profile'];
    if (profile is! Map<String, dynamic>) {
      throw const CarePlanException(
        'The server returned an invalid routine profile.',
      );
    }
    return _routineProfileFromJson(profile);
  }

  Future<RoutineProfileData> updateRoutineProfile({
    required bool learningEnabled,
    required String preferredReminderStyle,
    required Map<String, String> notes,
  }) async {
    final data = await _request(
      'PATCH',
      '/routine-profile',
      body: {
        'learningEnabled': learningEnabled,
        'preferredReminderStyle': preferredReminderStyle,
        'notes': notes,
      },
    );
    final profile = data['profile'];
    if (profile is! Map<String, dynamic>) {
      throw const CarePlanException(
        'The server returned an invalid routine profile.',
      );
    }
    return _routineProfileFromJson(profile);
  }

  Future<RoutineProfileData> resetRoutineLearning() async {
    final data = await _request('POST', '/routine-profile/reset-learning');
    final profile = data['profile'];
    if (profile is! Map<String, dynamic>) {
      throw const CarePlanException(
        'The server returned an invalid routine profile.',
      );
    }
    return _routineProfileFromJson(profile);
  }

  Future<void> recordRoutineSignal({
    required String eventType,
    String carePlanId = '',
    String taskId = '',
    String period = '',
    String scheduleTime = '',
    String signalValue = '',
  }) async {
    await _request(
      'POST',
      '/routine-learning/events',
      body: {
        'eventType': eventType,
        if (carePlanId.isNotEmpty) 'carePlanId': carePlanId,
        if (taskId.isNotEmpty) 'taskId': taskId,
        if (period.isNotEmpty) 'period': period,
        if (scheduleTime.isNotEmpty) 'scheduleTime': scheduleTime,
        if (signalValue.isNotEmpty) 'signalValue': signalValue,
      },
    );
  }

  Future<CareGapListData> fetchCareGaps(String planId) async {
    final data = await _request('GET', '/care-plans/$planId/care-gaps');
    return CareGapListData(
      summary: _careGapSummaryFromJson(
        data['summary'] is Map<String, dynamic>
            ? data['summary'] as Map<String, dynamic>
            : const <String, dynamic>{},
      ),
      gaps: _listOfMaps(data['gaps']).map(_careGapItemFromJson).toList(),
    );
  }

  Future<CareGapListData> refreshCareGaps(String planId) async {
    final data = await _request(
      'POST',
      '/care-plans/$planId/care-gaps/refresh',
    );
    return CareGapListData(
      summary: _careGapSummaryFromJson(
        data['summary'] is Map<String, dynamic>
            ? data['summary'] as Map<String, dynamic>
            : const <String, dynamic>{},
      ),
      gaps: _listOfMaps(data['gaps']).map(_careGapItemFromJson).toList(),
    );
  }

  Future<CareGapDetailData> fetchCareGap(String gapId) async {
    final data = await _request('GET', '/care-gaps/$gapId');
    final gap = data['gap'];
    if (gap is! Map<String, dynamic>) {
      throw const CarePlanException('The server returned an invalid care gap.');
    }

    return CareGapDetailData(
      gap: _careGapItemFromJson(gap),
      doctorQuestions: _listOfMaps(
        data['doctorQuestions'],
      ).map(_careGapDoctorQuestionFromJson).toList(),
    );
  }

  Future<CareGapItemData> updateCareGap(
    String gapId, {
    required String lifecycleStatus,
    String resolutionNote = '',
  }) async {
    final data = await _request(
      'PATCH',
      '/care-gaps/$gapId',
      body: {
        'lifecycleStatus': lifecycleStatus,
        'resolutionNote': resolutionNote.trim(),
      },
    );
    final gap = data['gap'];
    if (gap is! Map<String, dynamic>) {
      throw const CarePlanException('The server returned an invalid care gap.');
    }
    return _careGapItemFromJson(gap);
  }

  Future<String> createCareGapDoctorQuestion(
    String gapId, {
    required String groupName,
    required String title,
    required String question,
  }) async {
    final data = await _request(
      'POST',
      '/care-gaps/$gapId/doctor-question',
      body: {
        'groupName': groupName.trim(),
        'title': title.trim(),
        'question': question.trim(),
      },
    );
    return _displayText(data['questionId']);
  }

  Future<void> answerCareGapDoctorQuestion(
    String questionId, {
    required String answer,
  }) async {
    final cleanedAnswer = answer.trim();

    if (cleanedAnswer.isEmpty) {
      throw const CarePlanException(
        'Enter the answer you received from your healthcare professional.',
      );
    }

    await _request(
      'PATCH',
      '/doctor-questions/$questionId',
      body: {'answer': cleanedAnswer, 'status': 'answered'},
    );
  }

  Future<CarePlanDetailData> activatePlan(String planId) async {
    await _request(
      'PATCH',
      '/care-plans/$planId/status',
      body: const {'status': 'active'},
    );
    return fetchPlanDetail(planId);
  }

  List<Map<String, dynamic>> _listOfMaps(dynamic value) {
    if (value is! List) return const [];
    return value.whereType<Map<String, dynamic>>().toList();
  }

  bool _boolean(dynamic value) => value == true || value == 1 || value == '1';

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

  InstructionSafetyCheck? _safetyCheckFromInstruction(
    Map<String, dynamic> json,
  ) {
    final rawStatus = _displayText(json['safety_check_status']);
    final status = rawStatus.isEmpty ? 'not_checked' : rawStatus;
    if (status == 'not_checked') return null;
    return InstructionSafetyCheck(
      status: status,
      summary: _displayText(json['safety_check_summary']),
      possibleInterpretation: _displayText(
        json['safety_possible_interpretation'],
      ),
      questionForProfessional: _displayText(json['safety_question']),
      sources: _listOfMaps(json['safety_sources'])
          .map(
            (item) => SafetySource(
              title: _displayText(item['title']).isEmpty
                  ? 'Trusted health source'
                  : _displayText(item['title']),
              url: _displayText(item['url']),
            ),
          )
          .where((source) => source.url.isNotEmpty)
          .toList(),
    );
  }

  InstructionSafetyCheck _safetyCheckFromJson(Map<String, dynamic> json) {
    return InstructionSafetyCheck(
      status: _displayText(json['status']).isEmpty
          ? 'source_not_found'
          : _displayText(json['status']),
      summary: _displayText(json['summary']),
      possibleInterpretation: _displayText(json['possibleInterpretation']),
      questionForProfessional: _displayText(json['questionForProfessional']),
      sources: _listOfMaps(json['sources'])
          .map(
            (item) => SafetySource(
              title: _displayText(item['title']).isEmpty
                  ? 'Trusted health source'
                  : _displayText(item['title']),
              url: _displayText(item['url']),
            ),
          )
          .where((source) => source.url.isNotEmpty)
          .toList(),
    );
  }

  DemoPlan _planFromJson(Map<String, dynamic> json) {
    final status = _planStatus(json['status']?.toString());
    final startDate = _displayDate(
      json['startDate'] ?? json['createdAt'],
      fallback: status == PlanStatus.draft ? 'Not started' : 'Recently',
    );
    return DemoPlan(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? 'Care Plan',
      status: status,
      startDate: startDate,
      readiness: _integer(json['readinessScore']).clamp(0, 100).toInt(),
      nextTask: _nextStep(status),
      documents: const [],
      durationMode: _displayText(json['durationMode']).isEmpty
          ? 'prescription'
          : _displayText(json['durationMode']),
      suggestedEndDate: _displayText(json['suggestedEndDate']),
      plannedEndDate: _displayText(json['plannedEndDate']),
    );
  }

  RoutineProfileData _routineProfileFromJson(Map<String, dynamic> json) {
    final rawNotes = json['notes'] is Map<String, dynamic>
        ? json['notes'] as Map<String, dynamic>
        : const <String, dynamic>{};
    final rawLearned = json['learned'] is Map<String, dynamic>
        ? json['learned'] as Map<String, dynamic>
        : const <String, dynamic>{};

    final learned = <String, RoutineLearnedPeriod>{};
    for (final period in const ['morning', 'afternoon', 'evening', 'night']) {
      final item = rawLearned[period] is Map<String, dynamic>
          ? rawLearned[period] as Map<String, dynamic>
          : const <String, dynamic>{};
      learned[period] = RoutineLearnedPeriod(
        preferredTime: _displayText(item['preferredTime']),
        confidence: _displayText(item['confidence']).isEmpty
            ? 'No pattern yet'
            : _displayText(item['confidence']),
        signalCount: _integer(item['signalCount']),
        reason: _displayText(item['reason']),
      );
    }

    return RoutineProfileData(
      learningEnabled: json['learningEnabled'] != false,
      preferredReminderStyle:
          _displayText(json['preferredReminderStyle']).isEmpty
          ? 'Balanced'
          : _displayText(json['preferredReminderStyle']),
      notes: {
        for (final period in const ['morning', 'afternoon', 'evening', 'night'])
          period: _displayText(rawNotes[period]),
      },
      learned: learned,
      totalSignals: _integer(json['totalSignals']),
    );
  }

  DemoTask _instructionFromJson(Map<String, dynamic> json) {
    final reviewStatus = json['review_status']?.toString();
    return DemoTask(
      id: json['id']?.toString() ?? '',
      day: '',
      time: json['timing']?.toString() ?? 'Timing not set',
      title: json['title']?.toString() ?? 'Care instruction',
      note: json['instruction']?.toString() ?? '',
      kind: _taskKind(json['category']?.toString()),
      status: reviewStatus == 'verified'
          ? TaskStatus.ready
          : reviewStatus == 'unclear'
          ? TaskStatus.unclear
          : TaskStatus.atRisk,
    );
  }

  CareTaskOccurrence _taskOccurrenceFromJson(Map<String, dynamic> json) {
    return CareTaskOccurrence(
      id: _displayText(json['id']),
      carePlanId: _displayText(json['carePlanId']),
      scheduleItemId: _displayText(json['scheduleItemId']),
      occurrenceDate: _displayText(json['occurrenceDate']),
      scheduledTime: _displayText(json['scheduledTime']),
      title: _displayText(json['title']).isEmpty
          ? 'Care task'
          : _displayText(json['title']),
      taskKind: _displayText(json['taskKind']),
      period: _displayText(json['period']),
      recurrenceText: _displayText(json['recurrenceText']),
      grounding: _displayText(json['grounding']),
      status: _displayText(json['status']).isEmpty
          ? 'pending'
          : _displayText(json['status']),
      completedAt: _displayText(json['completedAt']),
      completedTime: _displayText(json['completedTime']),
      outcomeSource: _displayText(json['outcomeSource']),
      note: _displayText(json['note']),
      planTitle: _displayText(json['planTitle']),
    );
  }

  DemoTask _taskFromJson(Map<String, dynamic> json) {
    return DemoTask(
      id: json['id']?.toString() ?? '',
      day: json['task_date']?.toString() ?? '',
      time: json['task_time']?.toString() ?? 'Time not set',
      title: json['title']?.toString() ?? 'Care task',
      note: json['note']?.toString() ?? '',
      kind: _taskKind(json['task_kind']?.toString()),
      status: _taskStatus(json['status']?.toString()),
      completed: json['status']?.toString() == 'completed',
      caregiverId: json['caregiver_id']?.toString(),
      grounding: _displayText(json['grounding']),
      timeLocked:
          json['time_locked'] == true || _integer(json['time_locked']) == 1,
    );
  }

  CareGapSummaryData _careGapSummaryFromJson(Map<String, dynamic> json) {
    return CareGapSummaryData(
      total: _integer(json['total']),
      open: _integer(json['open']),
      blocking: _integer(json['blocking']),
      attention: _integer(json['attention']),
      inProgress: _integer(json['inProgress']),
      resolved: _integer(json['resolved']),
    );
  }

  CareGapItemData _careGapItemFromJson(Map<String, dynamic> json) {
    final target = json['target'] is Map<String, dynamic>
        ? json['target'] as Map<String, dynamic>
        : const <String, dynamic>{};
    final targetTabRaw = target['care_plan_tab'];
    final targetTab = targetTabRaw == null
        ? null
        : int.tryParse(targetTabRaw.toString());
    final resolutionSteps = json['resolution_steps'] is List
        ? (json['resolution_steps'] as List)
              .map(_displayText)
              .where((step) => step.isNotEmpty)
              .toList()
        : const <String>[];

    final carePlanId = _displayText(json['care_plan_id']);
    final sourceKind = _displayText(json['source_kind']);
    final sourceId = _displayText(json['source_id']);

    return CareGapItemData(
      id: _displayText(json['id']),
      carePlanId: carePlanId,
      taskId: _displayText(json['task_id']).isEmpty
          ? null
          : _displayText(json['task_id']),
      category: _displayText(json['category']),
      gapType: _displayText(json['gap_type']),
      title: _displayText(json['title']).isEmpty
          ? 'Care gap'
          : _displayText(json['title']),
      status: _displayText(json['status']),
      severity: _displayText(json['severity']).isEmpty
          ? 'attention'
          : _displayText(json['severity']),
      lifecycleStatus: _displayText(json['lifecycle_status']).isEmpty
          ? (_displayText(json['status']) == 'resolved' ? 'resolved' : 'open')
          : _displayText(json['lifecycle_status']),
      whenText: _displayText(json['when_text']),
      summary: _displayText(json['summary']),
      instructionSnapshot: _displayText(json['instruction_snapshot']),
      patientReality: _displayText(json['patient_reality']),
      reason: _displayText(json['reason']),
      nextStep: _displayText(json['next_step']),
      resolutionNote: _displayText(json['resolution_note']),
      sourceKind: sourceKind,
      sourceId: sourceId,
      dueAt: _displayText(json['due_at']),
      autoManaged: _boolean(json['auto_managed']),
      blocking: _boolean(json['blocking']),
      actionType: _displayText(json['action_type']),
      actionLabel: _displayText(json['action_label']).isEmpty
          ? 'Review care plan'
          : _displayText(json['action_label']),
      resolutionTitle: _displayText(json['resolution_title']).isEmpty
          ? 'How to resolve this gap'
          : _displayText(json['resolution_title']),
      resolutionSteps: resolutionSteps,
      autoRecheck: json.containsKey('auto_recheck')
          ? _boolean(json['auto_recheck'])
          : _boolean(json['auto_managed']),
      targetCarePlanId: _displayText(target['care_plan_id']).isEmpty
          ? carePlanId
          : _displayText(target['care_plan_id']),
      targetSourceKind: _displayText(target['source_kind']).isEmpty
          ? sourceKind
          : _displayText(target['source_kind']),
      targetSourceId: _displayText(target['source_id']).isEmpty
          ? sourceId
          : _displayText(target['source_id']),
      targetCarePlanTab: targetTab,
      displaySeverity: _displayText(json['display_severity']),
      canMarkResolved: json.containsKey('can_mark_resolved')
          ? _boolean(json['can_mark_resolved'])
          : !_boolean(json['auto_managed']),
    );
  }

  CareGapDoctorQuestionData _careGapDoctorQuestionFromJson(
    Map<String, dynamic> json,
  ) {
    return CareGapDoctorQuestionData(
      id: _displayText(json['id']),
      groupName: _displayText(json['group_name']),
      title: _displayText(json['title']),
      question: _displayText(json['question']),
      answer: _displayText(json['answer']),
      status: _displayText(json['status']),
    );
  }

  DemoGap _gapFromJson(Map<String, dynamic> json) {
    return DemoGap(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? 'Care gap',
      status: _taskStatus(json['status']?.toString()),
      category: json['category']?.toString() ?? 'Care plan',
      when: json['when_text']?.toString() ?? '',
      summary: json['summary']?.toString() ?? '',
      instruction: json['instruction_snapshot']?.toString() ?? '',
      reality: json['patient_reality']?.toString() ?? '',
      reason: json['reason']?.toString() ?? '',
      nextStep: json['next_step']?.toString() ?? '',
      taskId: json['task_id']?.toString(),
    );
  }

  DemoDocument _documentFromJson(Map<String, dynamic> json, String planTitle) {
    final originalName = json['original_name']?.toString() ?? 'Document';
    final extension = originalName.contains('.')
        ? originalName.split('.').last.toUpperCase()
        : 'FILE';
    return DemoDocument(
      id: json['id']?.toString() ?? '',
      name: originalName,
      type: extension,
      date: _displayDate(json['created_at'], fallback: 'Recently'),
      pages: _integer(json['page_count']).clamp(0, 9999).toInt(),
      plan: planTitle,
    );
  }

  Future<Map<String, dynamic>> _request(
    String method,
    String path, {
    Map<String, dynamic>? body,
    Duration timeout = _timeout,
  }) async {
    final token = AuthSession.instance.token;
    if (token == null || token.isEmpty) {
      throw const CarePlanException('Please sign in to continue.');
    }

    final idempotentOutcomeWrite =
        path.contains('/task-occurrences/') &&
        path.endsWith('/outcome') &&
        _displayText(body?['operationKey']).isNotEmpty;
    final safeToRetry = method == 'GET' || idempotentOutcomeWrite;
    final maxAttempts = safeToRetry ? 3 : 1;
    CarePlanException? lastError;

    for (var attempt = 1; attempt <= maxAttempts; attempt += 1) {
      try {
        final headers = <String, String>{
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
              .timeout(timeout);
        } else if (method == 'PATCH') {
          response = await _client
              .patch(
                uri,
                headers: headers,
                body: jsonEncode(body ?? const <String, dynamic>{}),
              )
              .timeout(timeout);
        } else if (method == 'DELETE') {
          response = await _client
              .delete(uri, headers: headers)
              .timeout(timeout);
        } else {
          response = await _client.get(uri, headers: headers).timeout(timeout);
        }

        final decoded = _decode(response);
        if (response.statusCode < 200 || response.statusCode >= 300) {
          final retryableStatus =
              response.statusCode == 408 ||
              response.statusCode == 429 ||
              response.statusCode >= 500;
          final error = CarePlanException(
            decoded['message']?.toString() ??
                'The care plan request could not be completed.',
            statusCode: response.statusCode,
            retryable: retryableStatus,
            data: decoded['data'] is Map<String, dynamic>
                ? decoded['data'] as Map<String, dynamic>
                : null,
          );
          if (safeToRetry && retryableStatus && attempt < maxAttempts) {
            await Future<void>.delayed(
              Duration(milliseconds: 350 * (1 << (attempt - 1))),
            );
            lastError = error;
            continue;
          }
          throw error;
        }

        final data = decoded['data'];
        if (data is! Map<String, dynamic>) {
          throw const CarePlanException(
            'The server returned an invalid response.',
          );
        }
        return data;
      } on TimeoutException {
        final error = const CarePlanException(
          'The server took too long to respond. Please try again.',
          retryable: true,
        );
        if (safeToRetry && attempt < maxAttempts) {
          await Future<void>.delayed(
            Duration(milliseconds: 350 * (1 << (attempt - 1))),
          );
          lastError = error;
          continue;
        }
        throw error;
      } on http.ClientException {
        final error = const CarePlanException(
          'Could not connect to the server. Check your internet connection.',
          retryable: true,
        );
        if (safeToRetry && attempt < maxAttempts) {
          await Future<void>.delayed(
            Duration(milliseconds: 350 * (1 << (attempt - 1))),
          );
          lastError = error;
          continue;
        }
        throw error;
      } on FormatException {
        throw const CarePlanException(
          'The server returned an invalid response.',
        );
      }
    }

    throw lastError ??
        const CarePlanException(
          'The request could not be completed.',
          retryable: true,
        );
  }

  Map<String, dynamic> _decode(http.Response response) {
    if (response.bodyBytes.isEmpty) return <String, dynamic>{};
    final decoded = jsonDecode(utf8.decode(response.bodyBytes));
    if (decoded is Map<String, dynamic>) return decoded;
    throw const FormatException('Expected a JSON object.');
  }

  int _integer(dynamic value) {
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  PlanStatus _planStatus(String? value) => switch (value) {
    'processing' => PlanStatus.processing,
    'needs_review' => PlanStatus.needsReview,
    'reality_check' => PlanStatus.realityCheck,
    'needs_attention' => PlanStatus.needsAttention,
    'active' => PlanStatus.active,
    'completed' => PlanStatus.completed,
    _ => PlanStatus.draft,
  };

  TaskStatus _taskStatus(String? value) => switch (value) {
    'ready' => TaskStatus.ready,
    'pending' => TaskStatus.ready,
    'at_risk' => TaskStatus.atRisk,
    'blocked' => TaskStatus.blocked,
    'open' => TaskStatus.blocked,
    'unclear' => TaskStatus.unclear,
    'resolved' => TaskStatus.resolved,
    'completed' => TaskStatus.resolved,
    _ => TaskStatus.ready,
  };

  TaskKind _taskKind(String? value) {
    final normalized = value?.toLowerCase() ?? '';
    if (normalized.contains('lab') || normalized.contains('test')) {
      return TaskKind.lab;
    }
    if (normalized.contains('visit') || normalized.contains('follow')) {
      return TaskKind.visit;
    }
    if (normalized.contains('dress') || normalized.contains('wound')) {
      return TaskKind.dressing;
    }
    if (normalized.contains('caregiver') || normalized.contains('support')) {
      return TaskKind.caregiver;
    }
    return TaskKind.medicine;
  }

  String _nextStep(PlanStatus status) => switch (status) {
    PlanStatus.draft => 'Upload documents to continue',
    PlanStatus.processing => 'Documents are being processed',
    PlanStatus.needsReview => 'Review extracted instructions',
    PlanStatus.realityCheck => 'Complete the reality check',
    PlanStatus.needsAttention => 'Resolve open care gaps',
    PlanStatus.active => 'Open the schedule for the next task',
    PlanStatus.completed => 'Plan completed',
  };

  String _displayDate(dynamic value, {required String fallback}) {
    final parsed = DateTime.tryParse(value?.toString() ?? '');
    if (parsed == null) return fallback;
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${parsed.day.toString().padLeft(2, '0')} '
        '${months[parsed.month - 1]} ${parsed.year}';
  }
}
