import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sehatmate_ai/localization/language_controller.dart';
import 'package:sehatmate_ai/localization/language_scope.dart';
import 'package:sehatmate_ai/screens/support_screens.dart';
import 'package:sehatmate_ai/services/device_speech_service.dart';
import 'package:sehatmate_ai/services/teach_back_service.dart';

void main() {
  testWidgets('loads Teach-Back targets and the first question', (
    tester,
  ) async {
    await _pumpTeachBack(tester, service: _FakeTeachBackClient());

    expect(find.text('Teach-Back'), findsWidgets);
    expect(find.text('Tell me what you need to do.'), findsOneWidget);
    expect(find.text('Check answer'), findsOneWidget);
  });

  testWidgets('shows an empty state when there are no verified targets', (
    tester,
  ) async {
    await _pumpTeachBack(
      tester,
      service: _FakeTeachBackClient(targets: const []),
    );

    expect(find.text('No verified care-plan items yet'), findsOneWidget);
    expect(
      find.text(
        'Teach-Back becomes available after your extracted care plan is verified.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('submits answer and shows partial retry guidance', (
    tester,
  ) async {
    final service = _FakeTeachBackClient(
      responses: [
        _response(
          assessment: _assessment(
            status: 'partial',
            score: 55,
            missingPoints: const ['Say that it should be after breakfast.'],
          ),
        ),
      ],
    );
    await _pumpTeachBack(tester, service: service);

    await _enterAnswerAndExpectSubmitReady(tester, 'I will take one tablet.');
    await _tapSubmit(tester);
    await tester.pumpAndSettle();

    expect(service.assessCalls, 1);
    expect(service.submittedAnswers, ['I will take one tablet.']);
    expect(find.text('Partly understood'), findsOneWidget);
    expect(find.text('Say that it should be after breakfast.'), findsOneWidget);
    expect(find.text('Retry this answer'), findsOneWidget);
  });

  testWidgets(
    'shows final result only after backend marks the session complete',
    (tester) async {
      final service = _FakeTeachBackClient(
        responses: [
          _response(
            finalResult: _finalResult(
              completed: true,
              score: 92,
              answeredCount: 1,
              understoodCount: 1,
            ),
          ),
        ],
      );
      await _pumpTeachBack(tester, service: service);

      await _enterAnswerAndExpectSubmitReady(
        tester,
        'I will take one tablet after breakfast.',
      );
      await _tapSubmit(tester);
      await tester.pumpAndSettle();

      expect(service.assessCalls, 1);
      expect(find.text('Understanding recorded'), findsOneWidget);
      expect(find.text('Understanding score: 92%'), findsOneWidget);
      expect(find.text('1 of 1 understood'), findsOneWidget);
      expect(find.text('Try all again'), findsNothing);
    },
  );

  testWidgets('final screen keeps weak retry without try-all reload', (
    tester,
  ) async {
    final service = _FakeTeachBackClient(
      responses: [
        _response(
          assessment: _assessment(status: 'needs_review', score: 60),
          finalResult: _finalResult(
            completed: true,
            score: 60,
            answeredCount: 1,
            needsReviewCount: 1,
            weakQuestionIds: const ['what_to_do'],
          ),
        ),
      ],
    );
    await _pumpTeachBack(tester, service: service);

    await _enterAnswerAndExpectSubmitReady(tester, 'I take a tablet.');
    await _tapSubmit(tester);
    await tester.pumpAndSettle();

    expect(service.assessCalls, 1);
    expect(find.text('Retry weak answers'), findsOneWidget);
    expect(find.text('Try all again'), findsNothing);

    await tester.tap(find.text('Retry weak answers'));
    await tester.pumpAndSettle();

    expect(find.text('Tell me what you need to do.'), findsOneWidget);
    expect(find.text('Check answer'), findsOneWidget);
    expect(find.text('Needs review'), findsNothing);
  });

  testWidgets('shows backend assessment errors without claiming success', (
    tester,
  ) async {
    final service = _FakeTeachBackClient(
      assessError: const TeachBackException('Server failure.'),
    );
    await _pumpTeachBack(tester, service: service);

    await _enterAnswerAndExpectSubmitReady(tester, 'I will take it.');
    await _tapSubmit(tester);
    await tester.pumpAndSettle();

    expect(service.assessCalls, 1);
    expect(find.text('Teach-Back is unavailable'), findsOneWidget);
    expect(find.text('Server failure.'), findsOneWidget);
    expect(find.text('Understanding recorded'), findsNothing);
  });

  testWidgets(
    'voice transcript fills the answer field without auto-submitting',
    (tester) async {
      final service = _FakeTeachBackClient();
      final speech = _FakeSpeechInput(transcript: 'Spoken answer from mic');

      await _pumpTeachBack(tester, service: service, speechInput: speech);

      await tester.tap(find.byKey(const Key('teach_back_speak_button')));
      await tester.pumpAndSettle();

      final field = tester.widget<TextField>(
        find.byKey(const Key('teach_back_answer_field')),
      );
      expect(field.controller?.text, 'Spoken answer from mic');
      _expectSubmitEnabled();
      expect(service.submittedAnswers, isEmpty);
      expect(speech.lastLocaleId, 'en-US');
    },
  );

  testWidgets('microphone failures are shown as non-blocking messages', (
    tester,
  ) async {
    final speech = _FakeSpeechInput(
      started: false,
      message: 'Speech is blocked.',
    );

    await _pumpTeachBack(
      tester,
      service: _FakeTeachBackClient(),
      speechInput: speech,
    );

    await tester.tap(find.byKey(const Key('teach_back_speak_button')));
    await tester.pumpAndSettle();

    expect(find.text('Speech is blocked.'), findsOneWidget);
    expect(find.text('Check answer'), findsOneWidget);
  });
}

Future<void> _enterAnswerAndExpectSubmitReady(
  WidgetTester tester,
  String answer,
) async {
  final fieldFinder = find.byKey(const Key('teach_back_answer_field'));
  final buttonFinder = find.byKey(const Key('teach_back_submit_button'));

  expect(fieldFinder, findsOneWidget);
  expect(buttonFinder, findsOneWidget);
  expect(
    find.descendant(of: buttonFinder, matching: find.text('Check answer')),
    findsOneWidget,
  );
  expect(find.text('Loading'), findsNothing);

  await tester.enterText(fieldFinder, answer);
  await tester.pump();

  final field = tester.widget<TextField>(fieldFinder);
  expect(field.controller?.text, answer);
  _expectSubmitEnabled();
}

Future<void> _tapSubmit(WidgetTester tester) async {
  final buttonFinder = find.byKey(const Key('teach_back_submit_button'));
  _expectSubmitEnabled();
  await tester.ensureVisible(buttonFinder);
  await tester.tap(buttonFinder);
}

void _expectSubmitEnabled() {
  final button = testerWidget<FilledButton>(
    find.byKey(const Key('teach_back_submit_button')),
  );
  expect(button.onPressed, isNotNull);
}

T testerWidget<T extends Widget>(Finder finder) {
  final widgets = finder.evaluate().map((element) => element.widget).toList();
  expect(widgets, hasLength(1));
  return widgets.single as T;
}

Future<void> _pumpTeachBack(
  WidgetTester tester, {
  required TeachBackClient service,
  DeviceSpeechInput? speechInput,
}) async {
  await tester.pumpWidget(
    LanguageScope(
      controller: LanguageController.instance,
      child: MaterialApp(
        home: TeachBackScreen(
          service: service,
          speechInput: speechInput ?? _FakeSpeechInput(),
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pumpAndSettle();
}

class _FakeTeachBackClient implements TeachBackClient {
  _FakeTeachBackClient({
    List<TeachBackTarget>? targets,
    TeachBackSession? session,
    List<TeachBackAssessmentResponse>? responses,
    this.assessError,
  }) : targets = targets ?? const [_target],
       session = session ?? _session(),
       responses = List<TeachBackAssessmentResponse>.of(
         responses ?? [_response()],
       );

  final List<TeachBackTarget> targets;
  final TeachBackSession session;
  final List<TeachBackAssessmentResponse> responses;
  final Object? assessError;
  final submittedAnswers = <String>[];
  int assessCalls = 0;

  @override
  Future<List<TeachBackTarget>> fetchTargets() async => targets;

  @override
  Future<TeachBackSession> fetchSession({
    required String targetType,
    required String targetId,
  }) async {
    expect(targetType, _target.targetType);
    expect(targetId, _target.targetId);
    return session;
  }

  @override
  Future<TeachBackAssessmentResponse> assessAnswer({
    required String targetType,
    required String targetId,
    required String questionId,
    required String answer,
  }) async {
    assessCalls += 1;
    submittedAnswers.add(answer);
    if (assessError != null) throw assessError!;
    expect(targetType, _target.targetType);
    expect(targetId, _target.targetId);
    expect(questionId, 'what_to_do');
    return responses.isEmpty ? _response() : responses.removeAt(0);
  }
}

class _FakeSpeechInput implements DeviceSpeechInput {
  _FakeSpeechInput({
    this.started = true,
    this.message = '',
    this.transcript = '',
  });

  final bool started;
  final String message;
  final String transcript;
  String? lastLocaleId;
  bool _listening = false;

  @override
  bool get isListening => _listening;

  @override
  Future<DeviceSpeechStartResult> startListening({
    required String localeId,
    required ValueChanged<String> onTranscript,
    required VoidCallback onDone,
  }) async {
    lastLocaleId = localeId;
    if (!started) {
      _listening = false;
      return DeviceSpeechStartResult(started: false, message: message);
    }
    _listening = true;
    if (transcript.isNotEmpty) {
      onTranscript(transcript);
    }
    onDone();
    _listening = false;
    return const DeviceSpeechStartResult(started: true);
  }

  @override
  Future<void> stopListening() async {
    _listening = false;
  }
}

const _target = TeachBackTarget(
  targetType: 'instruction',
  targetId: 'inst-1',
  carePlanId: 'plan-1',
  carePlanTitle: 'Blood pressure plan',
  title: 'Take tablet',
  instruction: 'Take one tablet',
  timing: 'After breakfast',
  notes: 'Use water',
  sourceUpdatedAt: '2026-09-05T08:00:00.000Z',
);

TeachBackSession _session({
  List<TeachBackQuestion> questions = const [_question],
  List<TeachBackAssessment> assessments = const [],
  TeachBackFinalResult? finalResult,
}) => TeachBackSession(
  target: _target,
  canAssess: true,
  planStatement: 'Take one tablet after breakfast.',
  questions: questions,
  assessments: assessments,
  finalResult: finalResult ?? _finalResult(),
  language: 'English',
);

const _question = TeachBackQuestion(
  id: 'what_to_do',
  text: 'Tell me what you need to do.',
  focus: 'action',
  order: 1,
);

TeachBackAssessmentResponse _response({
  TeachBackAssessment? assessment,
  TeachBackFinalResult? finalResult,
}) => TeachBackAssessmentResponse(
  target: _target,
  assessment: assessment ?? _assessment(),
  finalResult: finalResult ?? _finalResult(answeredCount: 1),
);

TeachBackAssessment _assessment({
  String status = 'understood',
  int score = 92,
  List<String> matchedPoints = const ['one tablet'],
  List<String> missingPoints = const [],
}) => TeachBackAssessment(
  id: 'attempt-1',
  questionId: 'what_to_do',
  questionText: 'Tell me what you need to do.',
  answerText: 'I will take one tablet after breakfast.',
  status: status,
  score: score,
  matchedPoints: matchedPoints,
  missingPoints: missingPoints,
  feedback: 'You understood this instruction.',
  retryPrompt: 'Try saying when you will take it.',
  planStatement: 'Take one tablet after breakfast.',
);

TeachBackFinalResult _finalResult({
  bool completed = false,
  int score = 0,
  int questionCount = 1,
  int answeredCount = 0,
  int understoodCount = 0,
  int needsReviewCount = 0,
  List<String> weakQuestionIds = const [],
}) => TeachBackFinalResult(
  completed: completed,
  score: score,
  status: completed ? 'understood' : 'in_progress',
  questionCount: questionCount,
  answeredCount: answeredCount,
  understoodCount: understoodCount,
  needsReviewCount: needsReviewCount,
  weakQuestionIds: weakQuestionIds,
);
