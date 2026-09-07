import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/app_routes.dart';
import '../core/app_theme.dart';
import '../data/demo_data.dart';
import '../localization/language_scope.dart';
import '../localization/localized_errors.dart';
import '../services/auth_service.dart';
import '../services/care_plan_service.dart';
import '../services/notification_service.dart';
import '../widgets/app_shell.dart';
import '../widgets/care_setup_progress.dart';
import '../widgets/ui.dart';

enum ReviewState { verified, review, unclear }

class ReviewInstruction {
  ReviewInstruction({
    required this.id,
    required this.group,
    required this.title,
    required this.instruction,
    required this.timing,
    required this.source,
    required this.state,
    this.confidenceScore,
    this.requiresProfessionalConfirmation = false,
    this.ambiguityReason = '',
    this.possibleInterpretation = '',
    this.safetyNote = '',
    this.safetyCheck,
    this.ingredientEvidence,
    String? originalTitle,
    String? originalInstruction,
    String? originalTiming,
    this.duplicateOfInstructionId = '',
    this.duplicateReason = '',
  }) : originalTitle = originalTitle ?? title,
       originalInstruction = originalInstruction ?? instruction,
       originalTiming = originalTiming ?? timing;
  final String id;
  final String group;
  String title;
  String instruction;
  String timing;
  final String source;
  final String originalTitle;
  final String originalInstruction;
  final String originalTiming;
  final String duplicateOfInstructionId;
  final String duplicateReason;
  final int? confidenceScore;
  ReviewState state;

  bool get isCorrected =>
      title.trim() != originalTitle.trim() ||
      instruction.trim() != originalInstruction.trim() ||
      _normalizedTiming(timing) != _normalizedTiming(originalTiming);

  bool get possibleDuplicate => duplicateReason.trim().isNotEmpty;

  static String _normalizedTiming(String value) =>
      value.trim() == 'Timing unclear in document' ? '' : value.trim();
  bool requiresProfessionalConfirmation;
  final String ambiguityReason;
  final String possibleInterpretation;
  final String safetyNote;
  InstructionSafetyCheck? safetyCheck;
  IngredientEvidence? ingredientEvidence;
}

class CarePlanReviewScreen extends StatefulWidget {
  const CarePlanReviewScreen({
    this.planId,
    this.guidedSetup = false,
    this.returnToPrevious = false,
    super.key,
  });

  final String? planId;
  final bool guidedSetup;
  final bool returnToPrevious;

  @override
  State<CarePlanReviewScreen> createState() => _CarePlanReviewScreenState();
}

class _CarePlanReviewScreenState extends State<CarePlanReviewScreen> {
  bool confirmed = false;
  bool loading = false;
  bool continuing = false;
  String? error;
  final savingIds = <String>{};
  final checkingIds = <String>{};
  final evidenceLoadingIds = <String>{};
  final items = <ReviewInstruction>[];
  static const groupOrder = [
    'Medicines',
    'Follow-Ups',
    'Lab Tests',
    'Care Tasks',
    'Other Instructions',
  ];

  @override
  void initState() {
    super.initState();
    if (AuthSession.instance.isGuest || widget.planId == null) {
      items.addAll(_demoItems());
    } else {
      _load();
    }
  }

  List<ReviewInstruction> _demoItems() => [
    ReviewInstruction(
      id: 'e1',
      group: 'Medicines',
      title: 'Paracetamol (demo)',
      instruction: '1 tablet',
      timing: 'Morning',
      source: 'Prescription — Page 1',
      state: ReviewState.review,
    ),
    ReviewInstruction(
      id: 'e2',
      group: 'Medicines',
      title: 'Antibiotic (demo)',
      instruction: '1 capsule',
      timing: 'Afternoon',
      source: 'Prescription — Page 1',
      state: ReviewState.review,
    ),
    ReviewInstruction(
      id: 'e3',
      group: 'Medicines',
      title: 'Evening tablet (demo)',
      instruction: '1 tablet',
      timing: 'Timing unclear in document',
      source: 'Prescription — Page 1',
      state: ReviewState.unclear,
    ),
    ReviewInstruction(
      id: 'e4',
      group: 'Follow-Ups',
      title: 'Hospital follow-up appointment',
      instruction: 'Visit outpatient clinic',
      timing: '22 August — 9:00 AM',
      source: 'Discharge Summary — Page 2',
      state: ReviewState.review,
    ),
    ReviewInstruction(
      id: 'e5',
      group: 'Lab Tests',
      title: 'Blood test',
      instruction: 'Fasting sample required',
      timing: '19 August — Morning',
      source: 'Discharge Summary — Page 3',
      state: ReviewState.review,
    ),
    ReviewInstruction(
      id: 'e6',
      group: 'Care Tasks',
      title: 'Wound dressing',
      instruction: 'Change dressing with assistance',
      timing: 'Daily',
      source: 'Discharge Summary — Page 2',
      state: ReviewState.review,
    ),
    ReviewInstruction(
      id: 'e7',
      group: 'Other Instructions',
      title: 'Fluid intake',
      instruction: 'Drink water regularly through the day',
      timing: 'Daily',
      source: 'Discharge Summary — Page 3',
      state: ReviewState.review,
    ),
  ];

  Future<void> _load() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final result = await CarePlanService.instance.fetchReviewInstructions(
        widget.planId!,
      );
      if (!mounted) return;
      setState(() {
        items
          ..clear()
          ..addAll(result.map(_fromApi));
        loading = false;
      });
    } on CarePlanException catch (exception) {
      if (!mounted) return;
      setState(() {
        loading = false;
        error = localizedCarePlanExceptionMessage(
          exception,
          context.appLanguage,
        );
      });
    }
  }

  ReviewInstruction _fromApi(CareInstructionReview item) => ReviewInstruction(
    id: item.id,
    group: switch (item.category) {
      'medicine' => 'Medicines',
      'follow_up' => 'Follow-Ups',
      'lab_test' => 'Lab Tests',
      'care_task' => 'Care Tasks',
      _ => 'Other Instructions',
    },
    title: item.title,
    instruction: item.instruction,
    timing: item.timing.isEmpty ? 'Timing unclear in document' : item.timing,
    source: item.sourcePage.isEmpty
        ? 'Uploaded document'
        : 'Uploaded document — ${item.sourcePage}',
    confidenceScore: item.confidenceScore,
    state: switch (item.reviewStatus) {
      'verified' => ReviewState.verified,
      'unclear' => ReviewState.unclear,
      _ => ReviewState.review,
    },
    requiresProfessionalConfirmation: item.requiresProfessionalConfirmation,
    ambiguityReason: item.ambiguityReason,
    possibleInterpretation: item.possibleInterpretation,
    safetyNote: item.safetyNote,
    safetyCheck: item.safetyCheck,
    originalTitle: item.originalTitle,
    originalInstruction: item.originalInstruction,
    originalTiming: item.originalTiming.isEmpty
        ? 'Timing unclear in document'
        : item.originalTiming,
    duplicateOfInstructionId: item.duplicateOfInstructionId,
    duplicateReason: item.duplicateReason,
  );

  @override
  Widget build(BuildContext context) {
    final visibleItems = items
        .where(
          (item) =>
              item.title.trim().isNotEmpty &&
              item.instruction.trim().isNotEmpty,
        )
        .toList();

    final visibleGroups = <String>[
      ...groupOrder.where(
        (group) => visibleItems.any((item) => item.group == group),
      ),
      ...visibleItems
          .map((item) => item.group)
          .where((group) => !groupOrder.contains(group))
          .toSet(),
    ];

    final verified = visibleItems
        .where((item) => item.state == ReviewState.verified)
        .length;

    final reviewed = visibleItems
        .where((item) => item.state != ReviewState.review)
        .length;

    final attention = visibleItems
        .where(
          (item) =>
              item.state == ReviewState.unclear ||
              item.requiresProfessionalConfirmation,
        )
        .length;

    final pending = (visibleItems.length - reviewed).clamp(
      0,
      visibleItems.length,
    );

    return AppShell(
      currentRoute: AppRoutes.carePlanReview,
      title: context.tr('verify_instructions'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton.icon(
              onPressed: () {
                if (widget.returnToPrevious && Navigator.canPop(context)) {
                  Navigator.pop(context);
                } else {
                  Navigator.pushReplacementNamed(context, AppRoutes.carePlans);
                }
              },
              icon: const Icon(Icons.arrow_back_rounded, size: 17),
              label: Text(context.tr('back')),
            ),
          ),
          const SizedBox(height: 6),

          FadeSlideIn(
            child: _reviewHero(
              reviewed: reviewed,
              total: visibleItems.length,
              verified: verified,
              attention: attention,
            ),
          ),

          if (widget.guidedSetup && widget.planId != null) ...[
            const SizedBox(height: 16),
            FadeSlideIn(
              delay: const Duration(milliseconds: 50),
              child: GuidedCareSetupProgress(
                currentStep: 2,
                planId: widget.planId!,
                saveState: savingIds.isNotEmpty ? 'Saving…' : 'Saved',
              ),
            ),
          ],

          const SizedBox(height: 18),

          FadeSlideIn(
            delay: const Duration(milliseconds: 70),
            child: _reviewMetricGrid(
              total: visibleItems.length,
              verified: verified,
              pending: pending,
              attention: attention,
            ),
          ),

          const SizedBox(height: 18),

          AnimatedSwitcher(
            duration: const Duration(milliseconds: 260),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            child: loading
                ? Padding(
                    key: const ValueKey('review-loading'),
                    padding: const EdgeInsets.only(top: 4),
                    child: _reviewLoadingSkeleton(),
                  )
                : error != null
                ? FadeSlideIn(
                    key: const ValueKey('review-error'),
                    child: _reviewErrorCard(),
                  )
                : visibleItems.isEmpty
                ? FadeSlideIn(
                    key: const ValueKey('review-empty'),
                    child: _reviewEmptyState(),
                  )
                : Column(
                    key: ValueKey(
                      'review-content-${visibleItems.length}-$reviewed',
                    ),
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      FadeSlideIn(
                        delay: const Duration(milliseconds: 90),
                        child: _reviewSummary(visibleItems),
                      ),
                      const SizedBox(height: 24),
                      ...visibleGroups.asMap().entries.map(
                        (entry) => FadeSlideIn(
                          delay: Duration(
                            milliseconds: 35 * entry.key.clamp(0, 5),
                          ),
                          child: _group(entry.value, visibleItems),
                        ),
                      ),
                      FadeSlideIn(
                        delay: const Duration(milliseconds: 120),
                        child: SafetyNote(
                          text: context.tr('review_instructions_safety_note'),
                        ),
                      ),
                      const SizedBox(height: 18),
                      FadeSlideIn(
                        delay: const Duration(milliseconds: 140),
                        child: _finalReviewCard(
                          reviewed: reviewed,
                          total: visibleItems.length,
                        ),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _reviewHero({
    required int reviewed,
    required int total,
    required int verified,
    required int attention,
  }) {
    final progress = total == 0 ? 0.0 : reviewed / total;

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 650;

        return Container(
          padding: EdgeInsets.all(compact ? 20 : 26),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF0F766E), Color(0xFF0D9488), Color(0xFF14B8A6)],
            ),
            borderRadius: BorderRadius.circular(AppRadii.xxxl),
            boxShadow: const [
              BoxShadow(
                color: Color(0x260F766E),
                blurRadius: 32,
                spreadRadius: -12,
                offset: Offset(0, 16),
              ),
            ],
          ),
          child: Stack(
            children: [
              PositionedDirectional(
                top: -72,
                end: -54,
                child: Container(
                  width: 190,
                  height: 190,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Color(0x16FFFFFF),
                  ),
                ),
              ),
              PositionedDirectional(
                bottom: -92,
                start: -62,
                child: Container(
                  width: 200,
                  height: 200,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Color(0x0FFFFFFF),
                  ),
                ),
              ),
              if (compact)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _heroCopy(
                      reviewed: reviewed,
                      total: total,
                      verified: verified,
                      attention: attention,
                    ),
                    const SizedBox(height: 18),
                    _heroProgressPanel(
                      reviewed: reviewed,
                      total: total,
                      progress: progress,
                      wide: true,
                    ),
                  ],
                )
              else
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: _heroCopy(
                        reviewed: reviewed,
                        total: total,
                        verified: verified,
                        attention: attention,
                      ),
                    ),
                    const SizedBox(width: 24),
                    _heroProgressPanel(
                      reviewed: reviewed,
                      total: total,
                      progress: progress,
                    ),
                  ],
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _heroCopy({
    required int reviewed,
    required int total,
    required int verified,
    required int attention,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0x20FFFFFF),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: const Color(0x30FFFFFF)),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.fact_check_outlined, size: 15, color: Colors.white),
              SizedBox(width: 6),
              Text(
                'Instruction verification',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Text(
          context.tr('review_extracted_instructions'),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 29,
            height: 1.08,
            fontWeight: FontWeight.w800,
            letterSpacing: -.45,
          ),
        ),
        const SizedBox(height: 9),
        Text(
          context.tr(
            'review_instructions_progress',
            values: {
              'reviewed': reviewed,
              'total': total,
              'verified': verified,
            },
          ),
          style: const TextStyle(
            color: Color(0xE6FFFFFF),
            fontSize: 13,
            height: 1.45,
          ),
        ),
        const SizedBox(height: 14),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _heroChip(
              icon: Icons.check_circle_outline_rounded,
              label: '$verified ${context.tr('verified')}',
            ),
            if (attention > 0)
              _heroChip(
                icon: Icons.warning_amber_rounded,
                label: '$attention ${context.tr('needs_confirmation')}',
                warning: true,
              ),
          ],
        ),
      ],
    );
  }

  Widget _heroChip({
    required IconData icon,
    required String label,
    bool warning = false,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: warning ? const Color(0x33FFF7ED) : const Color(0x1FFFFFFF),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: warning ? const Color(0x50FED7AA) : const Color(0x26FFFFFF),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.white),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _heroProgressPanel({
    required int reviewed,
    required int total,
    required double progress,
    bool wide = false,
  }) {
    final percent = (progress.clamp(0.0, 1.0) * 100).round();

    return Container(
      width: wide ? double.infinity : 180,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0x1FFFFFFF),
        borderRadius: BorderRadius.circular(AppRadii.xxl),
        border: Border.all(color: const Color(0x30FFFFFF)),
      ),
      child: wide
          ? Row(
              children: [
                _reviewProgressCircle(percent, progress),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Review progress',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '$reviewed of $total instructions reviewed',
                        style: const TextStyle(
                          color: Color(0xD5FFFFFF),
                          fontSize: 11,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            )
          : Column(
              children: [
                _reviewProgressCircle(percent, progress),
                const SizedBox(height: 10),
                const Text(
                  'Review progress',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '$reviewed / $total',
                  style: const TextStyle(
                    color: Color(0xD5FFFFFF),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
    );
  }

  Widget _reviewProgressCircle(int percent, double progress) {
    return SizedBox(
      width: 70,
      height: 70,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: 70,
            height: 70,
            child: CircularProgressIndicator(
              value: progress.clamp(0.0, 1.0),
              strokeWidth: 6,
              strokeCap: StrokeCap.round,
              backgroundColor: const Color(0x2AFFFFFF),
              color: Colors.white,
            ),
          ),
          Text(
            '$percent%',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 17,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _reviewMetricGrid({
    required int total,
    required int verified,
    required int pending,
    required int attention,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 760 ? 4 : 2;
        const gap = 10.0;
        final width = (constraints.maxWidth - ((columns - 1) * gap)) / columns;

        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            _reviewMetric(
              width: width,
              value: total,
              label: context.tr('instructions'),
              icon: Icons.document_scanner_outlined,
              background: AppColors.infoSoft,
              foreground: AppColors.infoForeground,
            ),
            _reviewMetric(
              width: width,
              value: verified,
              label: context.tr('verified'),
              icon: Icons.verified_outlined,
              background: AppColors.successSoft,
              foreground: AppColors.successForeground,
            ),
            _reviewMetric(
              width: width,
              value: pending,
              label: context.tr('needs_review'),
              icon: Icons.manage_search_outlined,
              background: const Color(0xFFF1F5F9),
              foreground: AppColors.muted,
            ),
            _reviewMetric(
              width: width,
              value: attention,
              label: context.tr('needs_confirmation'),
              icon: Icons.help_outline_rounded,
              background: AppColors.warningSoft,
              foreground: AppColors.warningForeground,
            ),
          ],
        );
      },
    );
  }

  Widget _reviewMetric({
    required double width,
    required int value,
    required String label,
    required IconData icon,
    required Color background,
    required Color foreground,
  }) {
    return SizedBox(
      width: width,
      child: AppCard(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: background,
                borderRadius: BorderRadius.circular(AppRadii.lg),
              ),
              child: Icon(icon, size: 18, color: foreground),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 220),
                    child: Text(
                      '$value',
                      key: ValueKey('$label-$value'),
                      style: const TextStyle(
                        fontSize: 20,
                        height: 1,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.muted,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _reviewLoadingSkeleton() {
    return Column(
      children: [
        for (var index = 0; index < 3; index++) ...[
          AppCard(
            padding: const EdgeInsets.all(18),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _skeleton(width: 44, height: 44, radius: 14),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _skeleton(width: 180, height: 16),
                      const SizedBox(height: 9),
                      _skeleton(width: 230, height: 11),
                      const SizedBox(height: 7),
                      _skeleton(width: 140, height: 11),
                      const SizedBox(height: 14),
                      _skeleton(width: double.infinity, height: 40, radius: 12),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (index != 2) const SizedBox(height: 12),
        ],
      ],
    );
  }

  Widget _skeleton({
    required double width,
    required double height,
    double radius = 999,
  }) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: const Color(0xFFE8EEF2),
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }

  Widget _reviewErrorCard() {
    return AppCard(
      color: const Color(0xFFFFFBEB),
      borderColor: const Color(0xFFFDE68A),
      child: Column(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.warningSoft,
              borderRadius: BorderRadius.circular(AppRadii.xl),
            ),
            child: const Icon(
              Icons.cloud_off_outlined,
              color: AppColors.warningForeground,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            error!,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 13, height: 1.45),
          ),
          const SizedBox(height: 14),
          OutlinedButton.icon(
            onPressed: _load,
            icon: const Icon(Icons.refresh_rounded, size: 17),
            label: Text(context.tr('retry')),
          ),
        ],
      ),
    );
  }

  Widget _reviewEmptyState() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 34),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFF0FDFA), Color(0xFFF8FAFC)],
        ),
        borderRadius: BorderRadius.circular(AppRadii.xxxl),
        border: Border.all(color: const Color(0xFFCCFBF1)),
      ),
      child: Column(
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: AppColors.primaryLight,
              borderRadius: BorderRadius.circular(AppRadii.xl),
            ),
            child: const Icon(
              Icons.document_scanner_outlined,
              color: AppColors.primary,
              size: 27,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            context.tr('no_instructions_extracted_upload_clearer'),
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 15,
              color: AppColors.muted,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }

  Widget _finalReviewCard({required int reviewed, required int total}) {
    final ready = confirmed && reviewed == total && !continuing;

    return AppCard(
      padding: const EdgeInsets.all(18),
      color: ready ? const Color(0xFFF0FDFA) : const Color(0xFFFAFCFD),
      borderColor: ready ? const Color(0xFF99F6E4) : AppColors.border,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: ready ? AppColors.successSoft : AppColors.primaryLight,
                  borderRadius: BorderRadius.circular(AppRadii.xl),
                ),
                child: Icon(
                  ready
                      ? Icons.verified_user_outlined
                      : Icons.fact_check_outlined,
                  color: ready
                      ? AppColors.successForeground
                      : AppColors.primary,
                  size: 21,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  value: confirmed,
                  onChanged: (value) =>
                      setState(() => confirmed = value ?? false),
                  controlAffinity: ListTileControlAffinity.leading,
                  title: Text(
                    context.tr('reviewed_against_original_document'),
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      height: 1.35,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: ready ? _continue : null,
              icon: continuing
                  ? const SizedBox(
                      width: 17,
                      height: 17,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Icon(
                      widget.returnToPrevious
                          ? Icons.save_outlined
                          : Icons.arrow_forward_rounded,
                      size: 18,
                    ),
              label: Text(
                continuing
                    ? context.tr('saving')
                    : widget.returnToPrevious
                    ? context.tr('save_changes')
                    : widget.guidedSetup
                    ? context.tr('continue_to_schedule')
                    : context.tr('continue'),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _group(String group, List<ReviewInstruction> visibleItems) {
    final groupItems = visibleItems
        .where((item) => item.group == group)
        .toList();

    if (groupItems.isEmpty) {
      return const SizedBox.shrink();
    }

    final verifiedCount = groupItems
        .where((item) => item.state == ReviewState.verified)
        .length;

    return Padding(
      padding: const EdgeInsets.only(bottom: 26),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: _groupColor(group),
                  borderRadius: BorderRadius.circular(AppRadii.lg),
                ),
                child: Icon(
                  _groupIcon(group),
                  size: 19,
                  color: _groupForeground(group),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _reviewGroupLabel(group),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$verifiedCount / ${groupItems.length} ${context.tr('verified')}',
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.muted,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '${groupItems.length}',
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.muted,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...groupItems.asMap().entries.map(
            (entry) => FadeSlideIn(
              delay: Duration(milliseconds: 30 * entry.key.clamp(0, 5)),
              child: Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _instruction(entry.value),
              ),
            ),
          ),
        ],
      ),
    );
  }

  IconData _groupIcon(String group) {
    return switch (group) {
      'Medicines' => Icons.medication_outlined,
      'Follow-Ups' => Icons.event_available_outlined,
      'Lab Tests' => Icons.science_outlined,
      'Care Tasks' => Icons.checklist_rounded,
      _ => Icons.notes_outlined,
    };
  }

  Color _groupColor(String group) {
    return switch (group) {
      'Medicines' => AppColors.primaryLight,
      'Follow-Ups' => AppColors.infoSoft,
      'Lab Tests' => const Color(0xFFF3E8FF),
      'Care Tasks' => AppColors.successSoft,
      _ => const Color(0xFFF1F5F9),
    };
  }

  Color _groupForeground(String group) {
    return switch (group) {
      'Medicines' => AppColors.primary,
      'Follow-Ups' => AppColors.infoForeground,
      'Lab Tests' => const Color(0xFF7E22CE),
      'Care Tasks' => AppColors.successForeground,
      _ => AppColors.muted,
    };
  }

  Widget _reviewSummary(List<ReviewInstruction> visibleItems) {
    final confirmedCount = visibleItems
        .where((item) => item.state == ReviewState.verified)
        .length;

    final attentionCount = visibleItems
        .where(
          (item) =>
              item.state == ReviewState.unclear ||
              item.requiresProfessionalConfirmation,
        )
        .length;

    final pendingCount = visibleItems.length - confirmedCount - attentionCount;

    return AppCard(
      padding: const EdgeInsets.all(16),
      color: const Color(0xFFFAFCFD),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.primaryLight,
              borderRadius: BorderRadius.circular(AppRadii.lg),
            ),
            child: const Icon(
              Icons.analytics_outlined,
              size: 20,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  context.tr('review_summary'),
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  context.tr('review_summary_help'),
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.muted,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _summaryChip(
                      context.tr(
                        'instructions_found_count',
                        values: {'count': visibleItems.length},
                      ),
                      Icons.document_scanner_outlined,
                      AppColors.primary,
                    ),
                    _summaryChip(
                      context.tr(
                        'instructions_confirmed_count',
                        values: {'count': confirmedCount},
                      ),
                      Icons.check_circle_outline,
                      AppColors.successForeground,
                    ),
                    if (pendingCount > 0)
                      _summaryChip(
                        context.tr(
                          'instructions_to_review_count',
                          values: {'count': pendingCount},
                        ),
                        Icons.manage_search_outlined,
                        AppColors.muted,
                      ),
                    if (attentionCount > 0)
                      _summaryChip(
                        context.tr(
                          'instructions_need_confirmation_count',
                          values: {'count': attentionCount},
                        ),
                        Icons.help_outline,
                        AppColors.warningForeground,
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _summaryChip(String label, IconData icon, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
    decoration: BoxDecoration(
      color: AppColors.card,
      border: Border.all(color: AppColors.border),
      borderRadius: BorderRadius.circular(99),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 15, color: color),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        ),
      ],
    ),
  );

  String _reviewGroupLabel(String group) => switch (group) {
    'Medicines' => context.tr('medicines'),
    'Follow-Ups' => context.tr('follow_ups'),
    'Lab Tests' => context.tr('lab_tests'),
    'Care Tasks' => context.tr('care_tasks'),
    'Other Instructions' => context.tr('other_instructions'),
    _ => group,
  };

  String _sourceDisplay(String source) {
    if (source == 'Uploaded document') {
      return context.tr('uploaded_document');
    }
    const prefix = 'Uploaded document — ';
    if (source.startsWith(prefix)) {
      return context.tr(
        'uploaded_document_source_page',
        values: {'source': source.substring(prefix.length)},
      );
    }
    return source;
  }

  String _sourceTitle(String title) {
    return title == 'Trusted health source'
        ? context.tr('trusted_health_source')
        : title;
  }

  Widget _instruction(ReviewInstruction item) {
    final (foreground, background, border, label) = switch (item.state) {
      ReviewState.verified => (
        AppColors.successForeground,
        AppColors.successSoft,
        AppColors.success,
        context.tr('verified'),
      ),
      ReviewState.review => (
        AppColors.muted,
        const Color(0xFFF1F5F9),
        AppColors.border,
        context.tr('needs_review'),
      ),
      ReviewState.unclear => (
        AppColors.warningForeground,
        AppColors.warningSoft,
        AppColors.warning,
        context.tr('unclear'),
      ),
    };

    final saving = savingIds.contains(item.id);
    final checking = checkingIds.contains(item.id);
    final needsAttention =
        item.state == ReviewState.unclear ||
        item.requiresProfessionalConfirmation;

    return HoverLift(
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(AppRadii.xxl),
          border: Border.all(
            color: needsAttention
                ? AppColors.warning.withValues(alpha: .24)
                : item.state == ReviewState.verified
                ? AppColors.success.withValues(alpha: .18)
                : AppColors.border,
          ),
          boxShadow: const [
            BoxShadow(
              color: Color(0x0D0F172A),
              blurRadius: 18,
              spreadRadius: -10,
              offset: Offset(0, 9),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(height: 4, color: border),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final compact = constraints.maxWidth < 520;

                      final heading = Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              color: background,
                              borderRadius: BorderRadius.circular(AppRadii.xl),
                            ),
                            child: Icon(
                              item.state == ReviewState.verified
                                  ? Icons.verified_outlined
                                  : needsAttention
                                  ? Icons.help_outline_rounded
                                  : Icons.manage_search_outlined,
                              size: 20,
                              color: foreground,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.title,
                                  style: const TextStyle(
                                    fontSize: 17,
                                    height: 1.25,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(height: 5),
                                Text(
                                  _instructionDetails(item),
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: AppColors.muted,
                                    height: 1.4,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.description_outlined,
                                      size: 13,
                                      color: AppColors.subtle,
                                    ),
                                    const SizedBox(width: 5),
                                    Expanded(
                                      child: Text(
                                        context.tr(
                                          'source_label_value',
                                          values: {
                                            'source': _sourceDisplay(
                                              item.source,
                                            ),
                                          },
                                        ),
                                        style: const TextStyle(
                                          fontSize: 11,
                                          color: AppColors.subtle,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      );

                      final status = Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: background,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          label,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: foreground,
                          ),
                        ),
                      );

                      if (compact) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            heading,
                            const SizedBox(height: 10),
                            status,
                          ],
                        );
                      }

                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: heading),
                          const SizedBox(width: 12),
                          status,
                        ],
                      );
                    },
                  ),

                  if (item.isCorrected || item.possibleDuplicate) ...[
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 7,
                      runSpacing: 7,
                      children: [
                        if (item.isCorrected)
                          _metaPill(
                            Icons.history_outlined,
                            context.tr('corrected_original_preserved'),
                            AppColors.primary,
                          ),
                        if (item.possibleDuplicate)
                          _metaPill(
                            Icons.content_copy_outlined,
                            context.tr('possible_duplicate_medicine'),
                            AppColors.warningForeground,
                          ),
                      ],
                    ),
                  ],

                  const SizedBox(height: 13),

                  Container(
                    padding: const EdgeInsets.all(11),
                    decoration: BoxDecoration(
                      color: needsAttention
                          ? AppColors.warningSoft
                          : item.state == ReviewState.verified
                          ? AppColors.successSoft
                          : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(AppRadii.lg),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          needsAttention
                              ? Icons.warning_amber_rounded
                              : item.safetyCheck != null
                              ? Icons.fact_check_outlined
                              : Icons.info_outline_rounded,
                          size: 16,
                          color: needsAttention
                              ? AppColors.warningForeground
                              : item.state == ReviewState.verified
                              ? AppColors.successForeground
                              : AppColors.primary,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _compactReviewMessage(item),
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.muted,
                              height: 1.4,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        TextButton(
                          onPressed: () => _showInstructionDetails(item),
                          child: Text(context.tr('details')),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 14),

                  LayoutBuilder(
                    builder: (context, constraints) {
                      final narrow = constraints.maxWidth < 480;

                      final confirmButton = FilledButton.icon(
                        onPressed: saving || item.state == ReviewState.verified
                            ? null
                            : () => _saveState(item, ReviewState.verified),
                        icon: saving
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.check_circle_outline, size: 17),
                        label: Text(
                          saving
                              ? context.tr('saving')
                              : item.state == ReviewState.verified
                              ? context.tr('saved')
                              : item.requiresProfessionalConfirmation
                              ? context.tr('doctor_confirmed')
                              : context.tr('looks_correct'),
                        ),
                      );

                      final editButton = OutlinedButton.icon(
                        onPressed: saving ? null : () => _edit(item),
                        icon: const Icon(Icons.edit_outlined, size: 17),
                        label: Text(context.tr('edit')),
                      );

                      final checkButton = OutlinedButton.icon(
                        onPressed: saving || checking
                            ? null
                            : () => _checkSafety(item),
                        icon: checking
                            ? const SizedBox(
                                width: 17,
                                height: 17,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.fact_check_outlined, size: 17),
                        label: Text(
                          checking
                              ? context.tr('checking')
                              : item.safetyCheck == null
                              ? context.tr('check_sources')
                              : context.tr('view_sources'),
                        ),
                      );

                      final duplicateButton = item.possibleDuplicate
                          ? OutlinedButton.icon(
                              onPressed: saving
                                  ? null
                                  : () => _removeDuplicate(item),
                              icon: const Icon(
                                Icons.delete_outline,
                                size: 17,
                                color: AppColors.criticalForeground,
                              ),
                              label: Text(context.tr('remove_duplicate')),
                            )
                          : null;

                      if (narrow) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            confirmButton,
                            const SizedBox(height: 8),
                            editButton,
                            const SizedBox(height: 8),
                            checkButton,
                            if (duplicateButton != null) ...[
                              const SizedBox(height: 8),
                              duplicateButton,
                            ],
                          ],
                        );
                      }

                      return Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          confirmButton,
                          editButton,
                          checkButton,
                          if (duplicateButton != null) duplicateButton,
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _metaPill(IconData icon, String label, Color foreground) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: foreground.withValues(alpha: 0.08),
        border: Border.all(color: foreground.withValues(alpha: 0.22)),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: foreground),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: foreground,
            ),
          ),
        ],
      ),
    );
  }

  String _compactReviewMessage(ReviewInstruction item) {
    if (item.possibleDuplicate) {
      return item.duplicateReason;
    }
    if (item.isCorrected) {
      return context.tr('confirmed_correction_original_preserved');
    }
    if (item.ingredientEvidence != null) {
      final ingredients = item.ingredientEvidence!.activeIngredients
          .map((value) => value.name)
          .join(', ');
      return ingredients.isEmpty
          ? context.tr('ingredient_label_needs_clearer_photo')
          : context.tr(
              'label_evidence_found',
              values: {'ingredients': ingredients},
            );
    }
    if (item.safetyCheck != null) {
      return switch (item.safetyCheck!.status) {
        'no_issue_found' => context.tr('medicine_name_record_found'),
        'needs_confirmation' => context.tr(
          'official_records_need_confirmation',
        ),
        _ => context.tr('no_reliable_medicine_match'),
      };
    }
    if (item.requiresProfessionalConfirmation ||
        item.state == ReviewState.unclear) {
      return item.ambiguityReason.isEmpty
          ? context.tr('critical_detail_unclear')
          : item.ambiguityReason;
    }
    if (item.state == ReviewState.verified) {
      return context.tr('confirmed_against_original_document');
    }
    return context.tr('compare_with_original_before_confirming');
  }

  Future<void> _showInstructionDetails(ReviewInstruction item) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.78,
        minChildSize: 0.5,
        maxChildSize: 0.94,
        builder: (sheetContext, scrollController) {
          final bottom = MediaQuery.viewPaddingOf(sheetContext).bottom;
          return Material(
            color: AppColors.card,
            clipBehavior: Clip.antiAlias,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            child: Column(
              children: [
                const SizedBox(height: 10),
                Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
                Expanded(
                  child: ListView(
                    controller: scrollController,
                    padding: const EdgeInsets.fromLTRB(20, 14, 20, 18),
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              item.title,
                              style: const TextStyle(
                                fontSize: 21,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          IconButton(
                            onPressed: () => Navigator.pop(sheetContext),
                            tooltip: context.tr('close'),
                            icon: const Icon(Icons.close),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _instructionDetails(item),
                        style: const TextStyle(
                          fontSize: 15,
                          color: AppColors.muted,
                          height: 1.45,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        item.source,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.subtle,
                        ),
                      ),
                      const SizedBox(height: 18),
                      if (item.isCorrected) ...[
                        _detailSection(
                          icon: Icons.history_outlined,
                          title: context.tr('original_from_uploaded_document'),
                          body: _originalInstructionDetails(item),
                          accent: AppColors.primary,
                        ),
                        const SizedBox(height: 10),
                        _detailSection(
                          icon: Icons.edit_note_outlined,
                          title: context.tr('confirmed_corrected_version'),
                          body: _instructionDetails(item),
                          accent: AppColors.successForeground,
                        ),
                        const SizedBox(height: 10),
                      ],
                      if (item.possibleDuplicate) ...[
                        _detailSection(
                          icon: Icons.content_copy_outlined,
                          title: context.tr('possible_duplicate_medicine'),
                          body: item.duplicateReason,
                          accent: AppColors.warningForeground,
                        ),
                        const SizedBox(height: 10),
                      ],
                      if (item.requiresProfessionalConfirmation ||
                          item.ambiguityReason.isNotEmpty)
                        _detailSection(
                          icon: Icons.help_outline,
                          title: context.tr('what_needs_confirmation'),
                          body: item.ambiguityReason.isEmpty
                              ? context.tr('safety_critical_detail_unclear')
                              : item.ambiguityReason,
                          accent: AppColors.warningForeground,
                        )
                      else if (item.state == ReviewState.review)
                        _detailSection(
                          icon: Icons.manage_search_outlined,
                          title: context.tr('why_review_this_item'),
                          body: context.tr('why_review_this_item_body'),
                          accent: AppColors.primary,
                        ),
                      if (item.possibleInterpretation.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        _detailSection(
                          icon: Icons.alt_route,
                          title: context.tr('possible_readings'),
                          body: item.possibleInterpretation,
                          accent: AppColors.muted,
                        ),
                      ],
                      if (item.safetyNote.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        _detailSection(
                          icon: Icons.shield_outlined,
                          title: context.tr('safety_note'),
                          body: item.safetyNote,
                          accent: AppColors.warningForeground,
                        ),
                      ],
                      if (item.safetyCheck != null) ...[
                        const SizedBox(height: 16),
                        _safetyCheckCard(item.safetyCheck!),
                      ],
                      if (item.ingredientEvidence != null) ...[
                        const SizedBox(height: 16),
                        _ingredientEvidenceCard(item.ingredientEvidence!),
                      ],
                    ],
                  ),
                ),
                Container(
                  padding: EdgeInsets.fromLTRB(
                    16,
                    10,
                    16,
                    bottom > 10 ? bottom : 10,
                  ),
                  decoration: const BoxDecoration(
                    color: AppColors.card,
                    border: Border(top: BorderSide(color: AppColors.border)),
                  ),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    alignment: WrapAlignment.center,
                    children: [
                      if (item.group == 'Medicines')
                        OutlinedButton.icon(
                          onPressed: evidenceLoadingIds.contains(item.id)
                              ? null
                              : () {
                                  Navigator.pop(sheetContext);
                                  _pickIngredientEvidence(item);
                                },
                          icon: const Icon(
                            Icons.add_a_photo_outlined,
                            size: 18,
                          ),
                          label: Text(
                            item.ingredientEvidence == null
                                ? context.tr('add_label_photo')
                                : context.tr('replace_label_photo'),
                          ),
                        ),
                      OutlinedButton.icon(
                        onPressed: () {
                          Navigator.pop(sheetContext);
                          _createDoctorQuestion(item);
                        },
                        icon: const Icon(
                          Icons.contact_support_outlined,
                          size: 18,
                        ),
                        label: Text(context.tr('doctor_question')),
                      ),
                      FilledButton(
                        onPressed: () => Navigator.pop(sheetContext),
                        child: Text(context.tr('done')),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _detailSection({
    required IconData icon,
    required String title,
    required String body,
    required Color accent,
  }) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: AppColors.secondary,
      border: Border.all(color: AppColors.border),
      borderRadius: BorderRadius.circular(AppRadii.xl),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 19, color: accent),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                body,
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.muted,
                  height: 1.45,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );

  String _originalInstructionDetails(ReviewInstruction item) {
    final instruction = item.originalInstruction.trim();
    final timing = item.originalTiming.trim();
    final title = item.originalTitle.trim();

    final details = <String>[
      if (title.isNotEmpty && title != item.title.trim()) title,
      instruction,
      if (timing.isNotEmpty &&
          timing != 'Timing unclear in document' &&
          !instruction.toLowerCase().contains(timing.toLowerCase()))
        timing,
    ].where((value) => value.isNotEmpty).toList();

    return details.join(' · ');
  }

  String _instructionDetails(ReviewInstruction item) {
    final instruction = item.instruction.trim();
    final timing = item.timing.trim();
    if (timing.isEmpty || timing == 'Timing unclear in document') {
      return instruction;
    }
    if (instruction.toLowerCase().contains(timing.toLowerCase())) {
      return instruction;
    }
    return '$instruction · $timing';
  }

  Widget _safetyCheckCard(InstructionSafetyCheck check) {
    final statusLabel = switch (check.status) {
      'no_issue_found' => context.tr('name_match_found'),
      'needs_confirmation' => context.tr('needs_confirmation'),
      _ => context.tr('not_verified'),
    };
    final statusColor = check.status == 'no_issue_found'
        ? AppColors.successForeground
        : AppColors.warningForeground;
    final statusBackground = check.status == 'no_issue_found'
        ? AppColors.successSoft
        : AppColors.warningSoft;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.secondary,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(AppRadii.xl),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  context.tr('trusted_source_check'),
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: statusBackground,
                  borderRadius: BorderRadius.circular(99),
                ),
                child: Text(
                  statusLabel,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: statusColor,
                  ),
                ),
              ),
            ],
          ),
          if (check.summary.isNotEmpty) ...[
            const SizedBox(height: 8),
            _highlightedText(
              check.summary,
              style: const TextStyle(fontSize: 13, height: 1.45),
            ),
          ],
          if (check.possibleInterpretation.isNotEmpty) ...[
            const SizedBox(height: 8),
            _highlightedText(
              context.tr(
                'possible_interpretation_only',
                values: {'interpretation': check.possibleInterpretation},
              ),
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                height: 1.45,
              ),
            ),
          ],
          if (check.questionForProfessional.isNotEmpty) ...[
            const SizedBox(height: 8),
            _highlightedText(
              context.tr(
                'ask_prefix',
                values: {'question': check.questionForProfessional},
              ),
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.warningForeground,
                height: 1.45,
              ),
              important: true,
            ),
          ],
          if (check.sources.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              context.tr('sources_checked'),
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
            ),
            ...check.sources.map(
              (source) => Padding(
                padding: const EdgeInsets.only(top: 8),
                child: SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => _openTrustedSource(source.url),
                    icon: const Icon(Icons.open_in_new, size: 16),
                    label: Align(
                      alignment: Alignment.centerLeft,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _sourceTitle(source.title),
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            Uri.tryParse(source.url)?.host ?? source.url,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.muted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
          const SizedBox(height: 10),
          _highlightedText(
            context.tr('trusted_database_safety_note'),
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.muted,
              height: 1.45,
            ),
            important: true,
          ),
        ],
      ),
    );
  }

  Widget _highlightedText(
    String text, {
    required TextStyle style,
    bool important = false,
  }) {
    final baseStyle = important
        ? style.copyWith(
            fontWeight: FontWeight.w700,
            fontStyle: FontStyle.italic,
          )
        : style;
    final quotedStyle = style.copyWith(
      fontWeight: FontWeight.w700,
      fontStyle: important ? FontStyle.italic : FontStyle.normal,
    );
    final pattern = RegExp(
      "(?<![A-Za-z0-9])'([^'\\n]+)'(?![A-Za-z0-9])|“([^”\\n]+)”|\"([^\"\\n]+)\"",
    );
    final spans = <TextSpan>[];
    var cursor = 0;

    for (final match in pattern.allMatches(text)) {
      if (match.start > cursor) {
        spans.add(
          TextSpan(text: text.substring(cursor, match.start), style: baseStyle),
        );
      }
      spans.add(TextSpan(text: match.group(0), style: quotedStyle));
      cursor = match.end;
    }

    if (cursor < text.length) {
      spans.add(TextSpan(text: text.substring(cursor), style: baseStyle));
    }

    return Text.rich(TextSpan(children: spans), textAlign: TextAlign.start);
  }

  Widget _ingredientEvidenceCard(IngredientEvidence evidence) {
    final statusLabel = switch (evidence.purposeStatus) {
      'broadly_consistent' => context.tr('broadly_consistent'),
      'purpose_not_stated' => context.tr('purpose_not_stated'),
      _ => context.tr('needs_confirmation'),
    };
    final statusColor = evidence.purposeStatus == 'broadly_consistent'
        ? AppColors.successForeground
        : AppColors.warningForeground;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.secondary,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(AppRadii.xl),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.science_outlined,
                size: 19,
                color: AppColors.primary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  context.tr('ingredient_label_evidence'),
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Text(
                statusLabel,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: statusColor,
                ),
              ),
            ],
          ),
          if (evidence.brandName.isNotEmpty) ...[
            const SizedBox(height: 12),
            _evidenceRow(context.tr('brand_on_package'), evidence.brandName),
          ],
          if (evidence.activeIngredients.isNotEmpty) ...[
            const SizedBox(height: 8),
            _evidenceRow(
              context.tr('active_ingredients'),
              evidence.activeIngredients
                  .map(
                    (item) => item.strength.isEmpty
                        ? item.name
                        : '${item.name} ${item.strength}',
                  )
                  .join(', '),
            ),
          ],
          if (evidence.dosageForm.isNotEmpty) ...[
            const SizedBox(height: 8),
            _evidenceRow(context.tr('form'), evidence.dosageForm),
          ],
          if (evidence.manufacturer.isNotEmpty) ...[
            const SizedBox(height: 8),
            _evidenceRow(context.tr('manufacturer'), evidence.manufacturer),
          ],
          const SizedBox(height: 12),
          Text(
            evidence.purposeSummary,
            style: const TextStyle(fontSize: 13, height: 1.45),
          ),
          if (evidence.labelNote.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              evidence.labelNote,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.muted,
                height: 1.4,
              ),
            ),
          ],
          if (evidence.sources.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              context.tr('evidence_sources'),
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
            ),
            ...evidence.sources.map(
              (source) => Padding(
                padding: const EdgeInsets.only(top: 7),
                child: OutlinedButton.icon(
                  onPressed: () => _openTrustedSource(source.url),
                  icon: const Icon(Icons.open_in_new, size: 16),
                  label: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      _sourceTitle(source.title),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ),
            ),
          ],
          const SizedBox(height: 10),
          Text(
            context.tr('ingredient_evidence_safety_note'),
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.muted,
              fontStyle: FontStyle.italic,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _evidenceRow(String label, String value) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      SizedBox(
        width: 118,
        child: Text(
          label,
          style: const TextStyle(fontSize: 12, color: AppColors.muted),
        ),
      ),
      const SizedBox(width: 8),
      Expanded(
        child: Text(
          value,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        ),
      ),
    ],
  );

  Future<void> _pickIngredientEvidence(ReviewInstruction item) async {
    if (AuthSession.instance.isGuest) {
      showDemoMessage(
        context,
        context.tr('ingredient_checking_sign_in_required'),
      );
      return;
    }
    final files = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['jpg', 'jpeg', 'png'],
    );
    if (files.isEmpty) return;
    final file = files.first;
    final byteLength = await file.length();
    if (byteLength > 10 * 1024 * 1024) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.tr('label_image_exceeds_10_mb_limit')),
          ),
        );
      }
      return;
    }
    final extension = file.name.split('.').last.toLowerCase();
    final mimeType = extension == 'png' ? 'image/png' : 'image/jpeg';
    setState(() => evidenceLoadingIds.add(item.id));
    try {
      final evidence = await CarePlanService.instance.analyzeIngredientEvidence(
        instructionId: item.id,
        originalName: file.name,
        mimeType: mimeType,
        bytes: await file.readAsBytes(),
      );
      if (!mounted) return;
      setState(() => item.ingredientEvidence = evidence);
      await _showInstructionDetails(item);
    } on CarePlanException catch (exception) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              localizedCarePlanExceptionMessage(exception, context.appLanguage),
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => evidenceLoadingIds.remove(item.id));
    }
  }

  Future<void> _openTrustedSource(String value) async {
    final uri = Uri.tryParse(value);
    if (uri == null ||
        !uri.hasScheme ||
        !await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.tr('trusted_source_page_open_failed')),
          ),
        );
      }
    }
  }

  Future<void> _checkSafety(ReviewInstruction item) async {
    if (AuthSession.instance.isGuest) {
      showDemoMessage(
        context,
        context.tr('trusted_source_checking_sign_in_required'),
      );
      return;
    }
    if (item.safetyCheck != null) {
      await _showInstructionDetails(item);
      return;
    }
    setState(() => checkingIds.add(item.id));
    try {
      final check = await CarePlanService.instance.checkInstructionSafety(
        item.id,
      );
      if (!mounted) return;
      setState(() {
        item.safetyCheck = check;
        if (check.status == 'needs_confirmation' ||
            check.status == 'source_not_found') {
          item.requiresProfessionalConfirmation = true;
          item.state = ReviewState.unclear;
        }
      });
      await _showInstructionDetails(item);
    } on CarePlanException catch (exception) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            localizedCarePlanExceptionMessage(exception, context.appLanguage),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => checkingIds.remove(item.id));
    }
  }

  Future<void> _removeDuplicate(ReviewInstruction item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(context.tr('remove_duplicate_instruction_question')),
        content: Text(
          context.tr(
            'remove_duplicate_instruction_body',
            values: {'title': item.title},
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(context.tr('cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.criticalForeground,
            ),
            child: Text(context.tr('remove_duplicate')),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => savingIds.add(item.id));
    try {
      if (!AuthSession.instance.isGuest && widget.planId != null) {
        await CarePlanService.instance.deleteInstruction(item.id);

        // If this plan had already scheduled Android reminders, rebuild them
        // from backend truth so the removed duplicate cannot leave an orphan.
        try {
          final detail = await CarePlanService.instance.fetchPlanDetail(
            widget.planId!,
          );
          await NotificationService.instance.cancelPlan(widget.planId!);
          if (detail.plan.status == PlanStatus.active &&
              detail.tasks.isNotEmpty) {
            await NotificationService.instance.scheduleNextOccurrences(
              planId: widget.planId!,
              tasks: detail.tasks,
            );
          }
        } catch (_) {
          // Backend deletion is authoritative. Normal app-resume reliability
          // reconciliation will repair local notifications if needed.
        }
      }

      if (!mounted) return;
      setState(() {
        items.removeWhere((entry) => entry.id == item.id);
      });
      showDemoMessage(context, context.tr('duplicate_instruction_removed'));
    } on CarePlanException catch (exception) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            localizedCarePlanExceptionMessage(exception, context.appLanguage),
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => savingIds.remove(item.id));
      }
    }
  }

  Future<bool> _saveState(ReviewInstruction item, ReviewState state) async {
    final previousState = item.state;
    final previousConfirmation = item.requiresProfessionalConfirmation;
    setState(() {
      savingIds.add(item.id);
      item.state = state;
      if (state == ReviewState.verified) {
        item.requiresProfessionalConfirmation = false;
      }
    });
    try {
      if (!AuthSession.instance.isGuest && widget.planId != null) {
        await CarePlanService.instance.reviewInstruction(
          instructionId: item.id,
          title: item.title,
          instruction: item.instruction,
          timing: item.timing == 'Timing unclear in document'
              ? ''
              : item.timing,
          reviewStatus: state == ReviewState.verified ? 'verified' : 'unclear',
        );
      }
      if (!mounted) return false;
      setState(() => item.state = state);
      showDemoMessage(
        context,
        state == ReviewState.verified
            ? context.tr('instruction_saved_as_verified')
            : context.tr('instruction_marked_as_unclear'),
      );
      return true;
    } on CarePlanException catch (exception) {
      if (!mounted) return false;
      setState(() {
        item.state = previousState;
        item.requiresProfessionalConfirmation = previousConfirmation;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            localizedCarePlanExceptionMessage(exception, context.appLanguage),
          ),
        ),
      );
      return false;
    } finally {
      if (mounted) setState(() => savingIds.remove(item.id));
    }
  }

  String _doctorQuestionFor(ReviewInstruction item) {
    final trustedQuestion =
        item.safetyCheck?.questionForProfessional.trim() ?? '';
    if (trustedQuestion.isNotEmpty) return trustedQuestion;
    final timing = item.timing == 'Timing unclear in document'
        ? context.tr('the_timing')
        : context.tr('the_timing_value', values: {'timing': item.timing});
    return context.tr(
      'doctor_question_confirm_instruction_template',
      values: {'timing': timing, 'title': item.title},
    );
  }

  Future<void> _createDoctorQuestion(ReviewInstruction item) async {
    final question = _doctorQuestionFor(item);
    final saved = await _saveState(item, ReviewState.unclear);
    if (!mounted || !saved) return;
    setState(() => item.requiresProfessionalConfirmation = true);

    final state = CareDemoState.instance;
    final alreadyAdded = state.questions.any(
      (question) => question.title == item.title && !question.answered,
    );
    if (!alreadyAdded) {
      state.addQuestion(
        group: item.group == 'Lab Tests' ? 'Tests' : item.group,
        title: item.title,
        question: question,
      );
    }

    final tags = <String>[
      if (item.group == 'Medicines') context.tr('medicine_name'),
      if (item.instruction.trim().isNotEmpty) context.tr('instruction'),
      if (item.timing == 'Timing unclear in document')
        context.tr('timing_unclear'),
      if (item.requiresProfessionalConfirmation)
        context.tr('confirmation_required'),
    ];

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.72,
        minChildSize: 0.48,
        maxChildSize: 0.92,
        builder: (sheetContext, scrollController) {
          final systemBottom = MediaQuery.viewPaddingOf(sheetContext).bottom;
          return Material(
            color: AppColors.card,
            clipBehavior: Clip.antiAlias,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            child: Column(
              children: [
                const SizedBox(height: 10),
                Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
                Expanded(
                  child: ListView(
                    controller: scrollController,
                    padding: const EdgeInsets.fromLTRB(20, 14, 20, 12),
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 42,
                            height: 42,
                            decoration: const BoxDecoration(
                              color: AppColors.successSoft,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.check_rounded,
                              color: AppColors.successForeground,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  context.tr('question_saved'),
                                  style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  context.tr('question_saved_description'),
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: AppColors.muted,
                                    height: 1.35,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            tooltip: context.tr('close'),
                            onPressed: () => Navigator.pop(sheetContext),
                            icon: const Icon(Icons.close),
                          ),
                        ],
                      ),
                      if (tags.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        Wrap(
                          spacing: 7,
                          runSpacing: 7,
                          children: tags
                              .map(
                                (tag) => Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.secondary,
                                    border: Border.all(color: AppColors.border),
                                    borderRadius: BorderRadius.circular(99),
                                  ),
                                  child: Text(
                                    tag,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              )
                              .toList(),
                        ),
                      ],
                      const SizedBox(height: 18),
                      Text(
                        context.tr('question_to_ask'),
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppColors.muted,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppColors.secondary,
                          border: Border.all(color: AppColors.border),
                          borderRadius: BorderRadius.circular(AppRadii.xl),
                        ),
                        child: SelectableText(
                          question,
                          style: const TextStyle(fontSize: 15, height: 1.45),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.info_outline,
                            size: 17,
                            color: AppColors.primary,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              context.tr(
                                'record_professional_response_before_confirming',
                              ),
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.muted,
                                height: 1.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: EdgeInsets.fromLTRB(
                    20,
                    12,
                    20,
                    systemBottom > 12 ? systemBottom : 12,
                  ),
                  decoration: const BoxDecoration(
                    color: AppColors.card,
                    border: Border(top: BorderSide(color: AppColors.border)),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: () {
                            Navigator.pop(sheetContext);
                            Navigator.pushNamed(
                              context,
                              AppRoutes.doctorQuestions,
                            );
                          },
                          icon: const Icon(Icons.arrow_forward, size: 18),
                          label: Text(context.tr('open_doctor_questions')),
                        ),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            final copiedMessage = context.tr('question_copied');
                            await Clipboard.setData(
                              ClipboardData(text: question),
                            );
                            if (sheetContext.mounted) {
                              ScaffoldMessenger.of(sheetContext).showSnackBar(
                                SnackBar(content: Text(copiedMessage)),
                              );
                            }
                          },
                          icon: const Icon(Icons.copy_outlined, size: 18),
                          label: Text(context.tr('copy_question')),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _edit(ReviewInstruction item) async {
    final edited = await showModalBottomSheet<(String, String, String)>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      showDragHandle: false,
      builder: (sheetContext) => _EditInstructionSheet(item: item),
    );

    if (edited != null) {
      final previous = (
        item.title,
        item.instruction,
        item.timing,
        item.requiresProfessionalConfirmation,
      );
      item.title = edited.$1;
      item.instruction = edited.$2;
      item.timing = edited.$3.isEmpty
          ? 'Timing unclear in document'
          : edited.$3;
      item.requiresProfessionalConfirmation = false;

      final saved = await _saveState(item, ReviewState.verified);
      if (!saved) {
        item.title = previous.$1;
        item.instruction = previous.$2;
        item.timing = previous.$3;
        item.requiresProfessionalConfirmation = previous.$4;
      } else if (mounted) {
        showDemoMessage(
          context,
          context.tr('instruction_updated_and_confirmed'),
        );
      }
    }
  }

  Future<void> _continue() async {
    setState(() => continuing = true);
    try {
      if (!AuthSession.instance.isGuest && widget.planId != null) {
        await CarePlanService.instance.finalizeReview(widget.planId!);
        if (widget.guidedSetup && !widget.returnToPrevious) {
          await CarePlanService.instance.updateSetupStep(
            widget.planId!,
            CareSetupStep.schedule,
          );
        }
      }
      if (!mounted) return;
      if (widget.planId == null || AuthSession.instance.isGuest) {
        Navigator.pushReplacementNamed(context, AppRoutes.carePlans);
      } else if (widget.returnToPrevious && Navigator.canPop(context)) {
        Navigator.pop(context);
      } else if (widget.guidedSetup) {
        Navigator.pushReplacementNamed(
          context,
          AppRoutes.carePlan(widget.planId!),
          arguments: const CarePlanDetailArgs(initialTab: 1, guidedSetup: true),
        );
      } else {
        Navigator.pushReplacementNamed(
          context,
          AppRoutes.carePlan(widget.planId!),
          arguments: const CarePlanDetailArgs(initialTab: 0),
        );
      }
    } on CarePlanException catch (exception) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            localizedCarePlanExceptionMessage(exception, context.appLanguage),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => continuing = false);
    }
  }
}

class _EditInstructionSheet extends StatefulWidget {
  const _EditInstructionSheet({required this.item});

  final ReviewInstruction item;

  @override
  State<_EditInstructionSheet> createState() => _EditInstructionSheetState();
}

class _EditInstructionSheetState extends State<_EditInstructionSheet> {
  late final TextEditingController _title;
  late final TextEditingController _instruction;
  late final TextEditingController _timing;

  @override
  void initState() {
    super.initState();
    _title = TextEditingController(text: widget.item.title);
    _instruction = TextEditingController(text: widget.item.instruction);
    _timing = TextEditingController(
      text: widget.item.timing == 'Timing unclear in document'
          ? ''
          : widget.item.timing,
    );
  }

  @override
  void dispose() {
    _title.dispose();
    _instruction.dispose();
    _timing.dispose();
    super.dispose();
  }

  void _save() {
    if (_title.text.trim().isEmpty || _instruction.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr('title_and_instruction_required'))),
      );
      return;
    }

    Navigator.pop(context, (
      _title.text.trim(),
      _instruction.text.trim(),
      _timing.text.trim(),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final keyboardBottom = MediaQuery.viewInsetsOf(context).bottom;
    final availableHeight = MediaQuery.sizeOf(context).height * 0.90;

    return SafeArea(
      top: false,
      bottom: true,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: availableHeight),
        child: Material(
          color: AppColors.card,
          clipBehavior: Clip.antiAlias,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 10),
              Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
              Flexible(
                child: SingleChildScrollView(
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: EdgeInsets.fromLTRB(20, 16, 20, 20 + keyboardBottom),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              context.tr('edit_instruction'),
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          IconButton(
                            onPressed: () => Navigator.pop(context),
                            tooltip: context.tr('close'),
                            icon: const Icon(Icons.close),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        widget.item.requiresProfessionalConfirmation
                            ? context.tr(
                                'save_correction_after_professional_confirmation',
                              )
                            : context.tr('correct_text_to_match_original'),
                        style: const TextStyle(
                          color: AppColors.muted,
                          height: 1.45,
                        ),
                      ),
                      const SizedBox(height: 18),
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppColors.secondary,
                          border: Border.all(color: AppColors.border),
                          borderRadius: BorderRadius.circular(AppRadii.xl),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(
                                  Icons.history_outlined,
                                  size: 18,
                                  color: AppColors.primary,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  context.tr(
                                    'original_from_document_read_only',
                                  ),
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 7),
                            Text(
                              [
                                    widget.item.originalTitle,
                                    widget.item.originalInstruction,
                                    if (widget.item.originalTiming.isNotEmpty &&
                                        widget.item.originalTiming !=
                                            'Timing unclear in document')
                                      widget.item.originalTiming,
                                  ]
                                  .where((value) => value.trim().isNotEmpty)
                                  .join(' · '),
                              style: const TextStyle(
                                fontSize: 13,
                                color: AppColors.muted,
                                height: 1.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 18),
                      Text(context.tr('title')),
                      const SizedBox(height: 6),
                      TextField(
                        controller: _title,
                        textInputAction: TextInputAction.next,
                      ),
                      const SizedBox(height: 12),
                      Text(context.tr('instruction')),
                      const SizedBox(height: 6),
                      TextField(
                        controller: _instruction,
                        minLines: 2,
                        maxLines: 4,
                        textInputAction: TextInputAction.next,
                      ),
                      const SizedBox(height: 12),
                      Text(context.tr('timing')),
                      const SizedBox(height: 6),
                      TextField(
                        controller: _timing,
                        textInputAction: TextInputAction.done,
                        onSubmitted: (_) => _save(),
                      ),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => Navigator.pop(context),
                              child: Text(context.tr('cancel')),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: FilledButton(
                              onPressed: _save,
                              child: Text(context.tr('save_and_confirm')),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
