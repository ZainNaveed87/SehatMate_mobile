import 'dart:async';

import 'package:flutter/material.dart';

import '../core/app_routes.dart';
import '../core/app_theme.dart';
import '../localization/language_scope.dart';
import '../services/auth_service.dart';
import '../services/care_plan_service.dart';
import '../widgets/app_shell.dart';
import '../widgets/care_setup_progress.dart';
import '../widgets/ui.dart';

class FocusedRealityCheckArgs {
  const FocusedRealityCheckArgs({
    required this.planId,
    required this.questionKey,
    this.reviewContextLabel = '',
  });

  final String planId;
  final String questionKey;
  final String reviewContextLabel;
}

class RealityCheckScreen extends StatefulWidget {
  const RealityCheckScreen({
    super.key,
    this.planId,
    this.guidedSetup = false,
    this.returnToPrevious = false,
    this.focusedQuestionKey,
    this.reviewContextLabel = '',
  });

  final String? planId;
  final bool guidedSetup;
  final bool returnToPrevious;

  /// If provided, only this Reality Check question is shown.
  ///
  /// Used when a specific Care Gap sends the user back to review
  /// the exact Reality Check answer linked to that gap.
  final String? focusedQuestionKey;

  /// Human-readable Care Gap context.
  ///
  /// Example:
  /// DemoMed Beta 5 mg · 14:00
  final String reviewContextLabel;

  @override
  State<RealityCheckScreen> createState() =>
      _RealityCheckScreenState();
}

class _RealityCheckScreenState extends State<RealityCheckScreen> {
  int index = 0;

  bool loading = true;
  bool saving = false;

  String? error;

  List<PlanRealityQuestion> questions = const [];

  final answers = <String, String>{};
  final notes = <String, String>{};

  final note = TextEditingController();

  Timer? _autosaveTimer;

  String _saveState = 'Saved';

  bool get _isFocusedReview =>
      widget.focusedQuestionKey?.trim().isNotEmpty ?? false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _autosaveTimer?.cancel();
    note.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // TRANSLATION FALLBACK
  // ---------------------------------------------------------------------------

  /// Some localization keys may not yet exist in the current language map.
  ///
  /// When context.tr(...) returns the key itself, show readable English
  /// fallback text instead of exposing internal strings such as:
  ///
  /// reality_option_yes_reliably
  /// reality_check_safety_note
  /// why_this_question
  String _trOrFallback(
    BuildContext context,
    String key,
    String fallback,
  ) {
    final translated = context.tr(key).trim();

    if (translated.isEmpty || translated == key) {
      return fallback;
    }

    return translated;
  }

  // ---------------------------------------------------------------------------
  // LOAD
  // ---------------------------------------------------------------------------

  Future<void> _load() async {
    if (widget.planId == null || AuthSession.instance.isGuest) {
      setState(() {
        loading = false;
        error =
            'Open a reviewed care plan to start its reality check.';
      });
      return;
    }

    try {
      final result =
          await CarePlanService.instance.fetchRealityQuestions(
        widget.planId!,
      );

      if (!mounted) return;

      answers.clear();
      notes.clear();

      // Load ALL current answers first.
      //
      // Focused Care Gap mode filters only what is displayed.
      // It does NOT clear or modify unrelated Reality Check answers.
      for (final item in result) {
        if (item.selectedAnswer.isNotEmpty &&
            item.selectedAnswer != '__custom__') {
          answers[item.key] = item.selectedAnswer;
        }

        if (item.note.isNotEmpty) {
          notes[item.key] = item.note;
        }
      }

      var visibleQuestions = result;

      final focusedKey =
          widget.focusedQuestionKey?.trim() ?? '';

      if (focusedKey.isNotEmpty) {
        visibleQuestions = result
            .where(
              (item) => item.key == focusedKey,
            )
            .toList();

        if (visibleQuestions.isEmpty) {
          setState(() {
            loading = false;
            error =
                'The Reality Check answer linked to this care gap is no longer available.';
          });
          return;
        }
      }

      setState(() {
        questions = visibleQuestions;
        index = 0;
        loading = false;
        error = null;
        _saveState = 'Saved';
      });

      _syncNote();
    } on CarePlanException catch (exception) {
      if (!mounted) return;

      setState(() {
        loading = false;
        error = exception.message;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        loading = false;
        error = 'Reality Check could not be loaded.';
      });
    }
  }

  void _syncNote() {
    if (questions.isEmpty) {
      note.clear();
      return;
    }

    note.text = notes[questions[index].key] ?? '';
  }

  // ---------------------------------------------------------------------------
  // BUILD
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return AppShell(
      currentRoute: AppRoutes.realityCheck,
      title: _isFocusedReview
          ? 'Review Reality Check'
          : _trOrFallback(
              context,
              'life_reality_check',
              'Reality Check',
            ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: 620,
          ),
          child: loading
              ? const Padding(
                  padding: EdgeInsets.all(48),
                  child: Center(
                    child: CircularProgressIndicator(),
                  ),
                )
              : error != null
                  ? _errorState()
                  : questions.isEmpty
                      ? _emptyState()
                      : _questionView(),
        ),
      ),
    );
  }

  Widget _errorState() {
    return EmptyState(
      icon: Icons.info_outline,
      title: _trOrFallback(
        context,
        'reality_check_unavailable',
        'Reality Check unavailable',
      ),
      description: _localizedError(
        context,
        error!,
      ),
      action: FilledButton(
        onPressed: () {
          if (_isFocusedReview &&
              Navigator.canPop(context)) {
            Navigator.pop(context);
            return;
          }

          Navigator.pushReplacementNamed(
            context,
            AppRoutes.carePlans,
          );
        },
        child: Text(
          _isFocusedReview
              ? 'Back to Care Gap'
              : _trOrFallback(
                  context,
                  'open_care_plans',
                  'Open Care Plans',
                ),
        ),
      ),
    );
  }

  Widget _emptyState() {
    return EmptyState(
      icon: Icons.check_circle_outline,
      title: _trOrFallback(
        context,
        'no_routine_questions_needed',
        'No routine questions needed',
      ),
      description: _trOrFallback(
        context,
        'no_additional_practical_questions',
        'No additional practical questions are needed for this care plan.',
      ),
      action: FilledButton(
        onPressed: () {
          if (widget.returnToPrevious &&
              Navigator.canPop(context)) {
            Navigator.pop(context);
            return;
          }

          Navigator.pushReplacementNamed(
            context,
            AppRoutes.simulation,
            arguments: CareFlowArgs(
              planId: widget.planId!,
              guidedSetup: widget.guidedSetup,
            ),
          );
        },
        child: Text(
          widget.returnToPrevious
              ? _trOrFallback(
                  context,
                  'done',
                  'Done',
                )
              : _trOrFallback(
                  context,
                  'view_simulation',
                  'View Simulation',
                ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // QUESTION VIEW
  // ---------------------------------------------------------------------------

  Widget _questionView() {
    final question = questions[index];
    final selected = answers[question.key];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ---------------------------------------------------------------------
        // Focused Care Gap review information
        // ---------------------------------------------------------------------

        if (_isFocusedReview) ...[
          AppCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: EdgeInsets.only(top: 2),
                      child: Icon(
                        Icons.fact_check_outlined,
                        size: 20,
                        color: AppColors.primary,
                      ),
                    ),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Review the answer linked to this care gap',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  widget.reviewContextLabel.trim().isEmpty
                      ? 'Only the Reality Check question related to this care gap is shown.'
                      : 'Related to: ${widget.reviewContextLabel.trim()}',
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.muted,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Your saved answer is already selected. Change it only if your real routine has changed.',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.muted,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
        ],

        // ---------------------------------------------------------------------
        // Guided setup progress
        // ---------------------------------------------------------------------

        if (widget.guidedSetup &&
            widget.planId != null &&
            !_isFocusedReview) ...[
          GuidedCareSetupProgress(
            currentStep: 4,
            planId: widget.planId!,
            saveState: _saveState,
          ),
          const SizedBox(height: 18),
        ],

        // ---------------------------------------------------------------------
        // Question header
        // ---------------------------------------------------------------------

        Row(
          children: [
            Expanded(
              child: Text(
                _isFocusedReview
                    ? 'Focused review'
                    : _questionCounterText(),
                style: const TextStyle(
                  fontSize: 14,
                  color: AppColors.muted,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Flexible(
              child: Text(
                _categoryText(
                  context,
                  question,
                ),
                textAlign: TextAlign.end,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: AppColors.primary,
                ),
              ),
            ),
          ],
        ),

        if (!_isFocusedReview) ...[
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: (index + 1) / questions.length,
              minHeight: 8,
              color: AppColors.primary,
              backgroundColor: AppColors.secondary,
            ),
          ),
        ],

        const SizedBox(height: 24),

        // ---------------------------------------------------------------------
        // Main question card
        // ---------------------------------------------------------------------

        AppCard(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                _questionText(
                  context,
                  question,
                ),
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  height: 1.35,
                ),
              ),

              // -----------------------------------------------------------------
              // Why this question
              // -----------------------------------------------------------------

              if (question.reasonForAsking.trim().isNotEmpty) ...[
                const SizedBox(height: 14),
                ExpansionTile(
                  tilePadding: EdgeInsets.zero,
                  childrenPadding: const EdgeInsets.only(
                    bottom: 10,
                  ),
                  leading: const Icon(
                    Icons.info_outline,
                    color: AppColors.primary,
                  ),
                  title: Text(
                    _trOrFallback(
                      context,
                      'why_this_question',
                      'Why this question',
                    ),
                    style: const TextStyle(
                      color: AppColors.primary,
                    ),
                  ),
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.secondary,
                        borderRadius: BorderRadius.circular(
                          AppRadii.xl,
                        ),
                      ),
                      child: Text(
                        question.reasonForAsking,
                        style: const TextStyle(
                          fontSize: 14,
                          color: AppColors.muted,
                          height: 1.45,
                        ),
                      ),
                    ),
                  ],
                ),
              ],

              const SizedBox(height: 20),

              // -----------------------------------------------------------------
              // Options
              // -----------------------------------------------------------------

              ...question.options.map(
                (option) => Padding(
                  padding: const EdgeInsets.only(
                    bottom: 12,
                  ),
                  child: OptionCard(
                    label: _optionText(
                      context,
                      option,
                    ),
                    selected: selected == option,
                    onTap: () => _selectAnswer(
                      question.key,
                      option,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 8),

              // -----------------------------------------------------------------
              // Optional note
              // -----------------------------------------------------------------

              TextField(
                controller: note,
                maxLines: 3,
                onChanged: (_) {
                  setState(() {
                    if (_isFocusedReview) {
                      _saveState = 'Unsaved changes';
                    }
                  });

                  if (!_isFocusedReview) {
                    _scheduleAutosave();
                  }
                },
                decoration: InputDecoration(
                  hintText: selected != null &&
                          question.options.isNotEmpty &&
                          selected != question.options.first
                      ? _trOrFallback(
                          context,
                          'reality_add_more_detail_hint',
                          'Add more detail (optional)',
                        )
                      : _trOrFallback(
                          context,
                          'reality_write_own_answer_hint',
                          'Add a note (optional)',
                        ),
                ),
              ),

              const SizedBox(height: 10),

              Text(
                _trOrFallback(
                  context,
                  'reality_answer_signal_note',
                  'Your answer helps SehatRoute understand how well this care-plan step fits your real routine.',
                ),
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.muted,
                  height: 1.4,
                ),
              ),

              if (selected != null &&
                  question.options.isNotEmpty &&
                  selected != question.options.first) ...[
                const SizedBox(height: 10),
                Text(
                  _trOrFallback(
                    context,
                    'reality_honest_answer_note',
                    'Keep your answer honest so the plan reflects your real routine.',
                  ),
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.muted,
                    height: 1.4,
                  ),
                ),
              ],

              const SizedBox(height: 20),

              // -----------------------------------------------------------------
              // Responsive buttons
              // -----------------------------------------------------------------

              LayoutBuilder(
                builder: (
                  context,
                  constraints,
                ) {
                  final backButton = TextButton.icon(
                    onPressed: _isFocusedReview
                        ? Navigator.canPop(context)
                            ? () => Navigator.pop(context)
                            : null
                        : index > 0
                            ? _back
                            : widget.guidedSetup &&
                                    widget.planId != null
                                ? _backToSchedule
                                : null,
                    icon: const Icon(
                      Icons.arrow_back,
                      size: 17,
                    ),
                    label: Text(
                      _isFocusedReview
                          ? 'Back to Care Gap'
                          : index == 0 &&
                                  widget.guidedSetup
                              ? _trOrFallback(
                                  context,
                                  'back_to_schedule',
                                  'Back to Schedule',
                                )
                              : _trOrFallback(
                                  context,
                                  'back',
                                  'Back',
                                ),
                    ),
                  );

                  final saveButton = FilledButton(
                    onPressed:
                        (selected == null &&
                                    note.text.trim().isEmpty) ||
                                saving
                            ? null
                            : _next,
                    child: Text(
                      saving
                          ? _trOrFallback(
                              context,
                              'saving',
                              'Saving…',
                            )
                          : _isFocusedReview
                              ? 'Save & return'
                              : index ==
                                      questions.length - 1
                                  ? widget.returnToPrevious
                                      ? _trOrFallback(
                                          context,
                                          'save_changes',
                                          'Save changes',
                                        )
                                      : _trOrFallback(
                                          context,
                                          'build_simulation',
                                          'Build Simulation',
                                        )
                                  : _trOrFallback(
                                      context,
                                      'continue',
                                      'Continue',
                                    ),
                    ),
                  );

                  // Small/mobile width:
                  //
                  // [ Save & return ]
                  //
                  // ← Back to Care Gap
                  //
                  // This prevents the RenderFlex overflow visible
                  // on narrow phones.
                  if (constraints.maxWidth < 420) {
                    return Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.stretch,
                      children: [
                        SizedBox(
                          width: double.infinity,
                          child: saveButton,
                        ),
                        const SizedBox(height: 8),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: backButton,
                        ),
                      ],
                    );
                  }

                  return Row(
                    children: [
                      backButton,
                      const Spacer(),
                      saveButton,
                    ],
                  );
                },
              ),
            ],
          ),
        ),

        const SizedBox(height: 20),

        SafetyNote(
          text: _trOrFallback(
            context,
            'reality_check_safety_note',
            'Reality Check only reviews practical fit. It does not change treatment or verified medical instructions.',
          ),
        ),
      ],
    );
  }

  String _questionCounterText() {
    final translated = context.tr(
      'question_of_total',
      values: {
        'current': index + 1,
        'total': questions.length,
      },
    );

    if (translated.trim().isEmpty ||
        translated.trim() == 'question_of_total') {
      return 'Question ${index + 1} of ${questions.length}';
    }

    return translated;
  }

  // ---------------------------------------------------------------------------
  // ERROR TEXT
  // ---------------------------------------------------------------------------

  String _localizedError(
    BuildContext context,
    String value,
  ) {
    return switch (value) {
      'Open a reviewed care plan to start its reality check.' =>
        _trOrFallback(
          context,
          'reality_open_reviewed_plan_error',
          value,
        ),
      'Generate the schedule before starting the reality check.' =>
        _trOrFallback(
          context,
          'reality_generate_schedule_error',
          value,
        ),
      'Care plan not found.' =>
        _trOrFallback(
          context,
          'care_plan_not_found',
          value,
        ),
      'Complete the relevant reality-check questions.' =>
        _trOrFallback(
          context,
          'reality_complete_questions_error',
          value,
        ),
      _ => value,
    };
  }

  // ---------------------------------------------------------------------------
  // CATEGORY
  // ---------------------------------------------------------------------------

  String _categoryText(
    BuildContext context,
    PlanRealityQuestion question,
  ) {
    final fallback = question.category.trim().isEmpty
        ? 'Routine'
        : question.category;

    return switch (question.key) {
      'morning_routine' ||
      'daytime_access' ||
      'evening_routine' =>
        _trOrFallback(
          context,
          'reality_category_routine',
          fallback,
        ),
      'caregiver_support' =>
        _trOrFallback(
          context,
          'reality_category_support',
          fallback,
        ),
      'travel_access' =>
        _trOrFallback(
          context,
          'reality_category_visits_tests',
          fallback,
        ),
      'medicine_access' =>
        _trOrFallback(
          context,
          'reality_category_medicine_access',
          fallback,
        ),
      _ => fallback,
    };
  }

  // ---------------------------------------------------------------------------
  // QUESTION TEXT
  // ---------------------------------------------------------------------------

  String _questionText(
    BuildContext context,
    PlanRealityQuestion question,
  ) {
    final fallback = question.question;

    return switch (question.key) {
      'morning_routine' =>
        _trOrFallback(
          context,
          'reality_question_morning_routine',
          fallback,
        ),
      'daytime_access' =>
        _trOrFallback(
          context,
          'reality_question_daytime_access',
          fallback,
        ),
      'evening_routine' =>
        _trOrFallback(
          context,
          'reality_question_evening_routine',
          fallback,
        ),
      'caregiver_support' =>
        _trOrFallback(
          context,
          'reality_question_caregiver_support',
          fallback,
        ),
      'travel_access' =>
        _trOrFallback(
          context,
          'reality_question_travel_access',
          fallback,
        ),
      'medicine_access' =>
        _trOrFallback(
          context,
          'reality_question_medicine_access',
          fallback,
        ),
      _ => fallback,
    };
  }

  // ---------------------------------------------------------------------------
  // OPTION TEXT
  // ---------------------------------------------------------------------------

  String _optionText(
    BuildContext context,
    String option,
  ) {
    final translationKey = switch (option) {
      'I can follow the stated morning or meal instruction' =>
        'reality_option_morning_can_follow',
      'My morning time changes on some days' =>
        'reality_option_morning_changes',
      'This timing is usually difficult for me' =>
        'reality_option_timing_difficult_for_me',
      'Yes, reliably' =>
        'reality_option_yes_reliably',
      'Sometimes' =>
        'reality_option_sometimes',
      'Usually not' =>
        'reality_option_usually_not',
      'My evening routine changes' =>
        'reality_option_evening_changes',
      'This timing is usually difficult' =>
        'reality_option_timing_difficult',
      'Yes, when needed' =>
        'reality_option_yes_when_needed',
      'Only sometimes' =>
        'reality_option_only_sometimes',
      'No help is currently available' =>
        'reality_option_no_help_available',
      'Yes, transport is arranged' =>
        'reality_option_transport_arranged',
      'Transport still needs arranging' =>
        'reality_option_transport_needs_arranging',
      'I cannot reach it at that time' =>
        'reality_option_cannot_reach',
      'Yes, all of them' =>
        'reality_option_all_medicines',
      'Some are still missing' =>
        'reality_option_some_missing',
      'None yet' =>
        'reality_option_none_yet',
      _ => '',
    };

    if (translationKey.isEmpty) {
      return option;
    }

    return _trOrFallback(
      context,
      translationKey,
      option,
    );
  }

  // ---------------------------------------------------------------------------
  // ANSWER / NOTE STATE
  // ---------------------------------------------------------------------------

  void _storeNote() {
    if (questions.isNotEmpty) {
      notes[questions[index].key] =
          note.text.trim();
    }
  }

  void _selectAnswer(
    String key,
    String option,
  ) {
    setState(() {
      if (answers[key] == option) {
        answers.remove(key);
      } else {
        answers[key] = option;
      }

      _saveState = _isFocusedReview
          ? 'Unsaved changes'
          : 'Saving…';
    });

    // Normal Reality Check keeps autosave.
    //
    // Focused Care Gap review waits until the user explicitly
    // presses Save & return. This prevents accidental changes.
    if (!_isFocusedReview) {
      _scheduleAutosave(
        immediate: true,
      );
    }
  }

  // ---------------------------------------------------------------------------
  // AUTOSAVE
  // ---------------------------------------------------------------------------

  void _scheduleAutosave({
    bool immediate = false,
  }) {
    if (widget.planId == null ||
        AuthSession.instance.isGuest ||
        _isFocusedReview) {
      return;
    }

    _storeNote();

    _autosaveTimer?.cancel();

    if (mounted) {
      setState(() {
        _saveState = 'Saving…';
      });
    }

    _autosaveTimer = Timer(
      immediate
          ? const Duration(
              milliseconds: 250,
            )
          : const Duration(
              milliseconds: 700,
            ),
      () {
        _saveCurrent(
          showError: false,
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // SAVE CURRENT QUESTION
  // ---------------------------------------------------------------------------

  Future<bool> _saveCurrent({
    required bool showError,
  }) async {
    if (widget.planId == null ||
        AuthSession.instance.isGuest ||
        questions.isEmpty) {
      return true;
    }

    _storeNote();

    final question = questions[index];

    final selectedAnswer =
        answers[question.key];

    final writtenAnswer =
        (notes[question.key] ?? '').trim();

    final hasSelectedAnswer =
        selectedAnswer != null &&
            selectedAnswer.isNotEmpty;

    final hasWrittenAnswer =
        writtenAnswer.isNotEmpty;

    final answer = hasSelectedAnswer
        ? selectedAnswer
        : hasWrittenAnswer
            ? '__custom__'
            : '__clear__';

    if (showError && answer == '__clear__') {
      return false;
    }

    try {
      if (mounted) {
        setState(() {
          _saveState = 'Saving…';
        });
      }

      await CarePlanService.instance
          .saveRealityAnswers(
        widget.planId!,
        [
          {
            'key': question.key,
            'answer': answer,
            'note': writtenAnswer,
          },
        ],
      );

      if (mounted) {
        setState(() {
          _saveState = 'Saved';
        });
      }

      return true;
    } on CarePlanException catch (exception) {
      if (mounted) {
        setState(() {
          _saveState = 'Retry needed';
        });

        if (showError) {
          ScaffoldMessenger.of(context)
              .showSnackBar(
            SnackBar(
              content: Text(
                exception.message,
              ),
            ),
          );
        }
      }

      return false;
    } catch (_) {
      if (mounted) {
        setState(() {
          _saveState = 'Retry needed';
        });

        if (showError) {
          ScaffoldMessenger.of(context)
              .showSnackBar(
            const SnackBar(
              content: Text(
                'Reality Check could not be saved. Please try again.',
              ),
            ),
          );
        }
      }

      return false;
    }
  }

  // ---------------------------------------------------------------------------
  // BACK
  // ---------------------------------------------------------------------------

  void _back() {
    _storeNote();

    unawaited(
      _saveCurrent(
        showError: false,
      ),
    );

    setState(() {
      index--;
    });

    _syncNote();
  }

  void _backToSchedule() {
    _storeNote();

    unawaited(
      _saveCurrent(
        showError: false,
      ),
    );

    Navigator.pushReplacementNamed(
      context,
      AppRoutes.carePlan(
        widget.planId!,
      ),
      arguments: const CarePlanDetailArgs(
        initialTab: 1,
        guidedSetup: true,
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // NEXT / SAVE
  // ---------------------------------------------------------------------------

  Future<void> _next() async {
    _autosaveTimer?.cancel();
    _storeNote();

    // =========================================================================
    // FOCUSED CARE GAP REVIEW
    // =========================================================================

    if (_isFocusedReview) {
      setState(() {
        saving = true;
      });

      try {
        final saved =
            await _saveCurrent(
          showError: true,
        );

        if (!saved || !mounted) {
          return;
        }

        // Return directly to the same Care Gap screen.
        if (Navigator.canPop(context)) {
          Navigator.pop(
            context,
            true,
          );
          return;
        }

        // Safe fallback if this screen was somehow opened
        // without a previous route.
        Navigator.pushReplacementNamed(
          context,
          AppRoutes.careGaps,
          arguments: CareFlowArgs(
            planId: widget.planId!,
          ),
        );
      } finally {
        if (mounted) {
          setState(() {
            saving = false;
          });
        }
      }

      return;
    }

    // =========================================================================
    // NORMAL COMPLETE REALITY CHECK FLOW
    // =========================================================================

    final saved =
        await _saveCurrent(
      showError: true,
    );

    if (!saved) return;

    if (index < questions.length - 1) {
      setState(() {
        index++;
      });

      _syncNote();
      return;
    }

    setState(() {
      saving = true;
    });

    try {
      // Final consistency save for the complete currently visible
      // Reality Check question set.
      await CarePlanService.instance
          .saveRealityAnswers(
        widget.planId!,
        questions.map(
          (item) {
            final savedAnswer =
                answers[item.key];

            final savedNote =
                (notes[item.key] ?? '').trim();

            return {
              'key': item.key,
              'answer':
                  savedAnswer != null &&
                          savedAnswer.isNotEmpty
                      ? savedAnswer
                      : savedNote.isNotEmpty
                          ? '__custom__'
                          : '__clear__',
              'note': savedNote,
            };
          },
        ).toList(),
      );

      if (widget.guidedSetup &&
          !widget.returnToPrevious) {
        await CarePlanService.instance
            .updateSetupStep(
          widget.planId!,
          CareSetupStep.simulation,
        );
      }

      if (!mounted) return;

      if (widget.returnToPrevious &&
          Navigator.canPop(context)) {
        Navigator.pop(context);
        return;
      }

      Navigator.pushReplacementNamed(
        context,
        AppRoutes.simulation,
        arguments: CareFlowArgs(
          planId: widget.planId!,
          guidedSetup:
              widget.guidedSetup,
        ),
      );
    } on CarePlanException catch (exception) {
      if (mounted) {
        setState(() {
          _saveState = 'Retry needed';
        });

        ScaffoldMessenger.of(context)
            .showSnackBar(
          SnackBar(
            content: Text(
              exception.message,
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          saving = false;
        });
      }
    }
  }
}