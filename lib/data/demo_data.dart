import 'dart:math' as math;

import 'package:flutter/material.dart';

enum TaskStatus { ready, atRisk, blocked, unclear, resolved }
enum TaskKind { medicine, lab, visit, dressing, caregiver }
enum PlanStatus { draft, processing, needsReview, realityCheck, needsAttention, active, completed }
enum ExtractedState { verified, review, unclear }

const patientAgeGroups = [
  'Under 18',
  '18 – 30',
  '31 – 45',
  '46 – 59',
  '60 – 70',
  '71 – 80',
  '81+',
];

class DemoTask {
  const DemoTask({required this.id, required this.day, required this.time, required this.title, required this.note, required this.kind, required this.status, this.completed = false, this.caregiverId, this.grounding = '', this.timeLocked = false});
  final String id;
  final String day;
  final String time;
  final String title;
  final String note;
  final TaskKind kind;
  final TaskStatus status;
  final bool completed;
  final String? caregiverId;
  final String grounding;
  final bool timeLocked;

  IconData get icon => switch (kind) {
        TaskKind.medicine => Icons.medication_outlined,
        TaskKind.lab => Icons.biotech_outlined,
        TaskKind.visit => Icons.local_hospital_outlined,
        TaskKind.dressing => Icons.healing_outlined,
        TaskKind.caregiver => Icons.handshake_outlined,
      };

  DemoTask copyWith({TaskStatus? status, bool? completed, String? caregiverId, String? grounding, bool? timeLocked}) => DemoTask(
        id: id,
        day: day,
        time: time,
        title: title,
        note: note,
        kind: kind,
        status: status ?? this.status,
        completed: completed ?? this.completed,
        caregiverId: caregiverId ?? this.caregiverId,
        grounding: grounding ?? this.grounding,
        timeLocked: timeLocked ?? this.timeLocked,
      );
}

class DemoGap {
  const DemoGap({required this.id, required this.title, required this.status, required this.category, required this.when, required this.summary, required this.instruction, required this.reality, required this.reason, required this.nextStep, this.taskId});
  final String id;
  final String title;
  final TaskStatus status;
  final String category;
  final String when;
  final String summary;
  final String instruction;
  final String reality;
  final String reason;
  final String nextStep;
  final String? taskId;

  DemoGap copyWith({TaskStatus? status}) => DemoGap(id: id, title: title, status: status ?? this.status, category: category, when: when, summary: summary, instruction: instruction, reality: reality, reason: reason, nextStep: nextStep, taskId: taskId);
}

class DemoCaregiver {
  const DemoCaregiver({required this.id, required this.name, required this.relationship, required this.phone, required this.availability, required this.helpsWith, required this.access, required this.taskIds});
  final String id;
  final String name;
  final String relationship;
  final String phone;
  final String availability;
  final List<String> helpsWith;
  final List<String> access;
  final List<String> taskIds;

  DemoCaregiver copyWith({List<String>? taskIds}) => DemoCaregiver(id: id, name: name, relationship: relationship, phone: phone, availability: availability, helpsWith: helpsWith, access: access, taskIds: taskIds ?? this.taskIds);
}

class DemoPlan {
  const DemoPlan({required this.id, required this.title, required this.status, required this.startDate, required this.readiness, required this.nextTask, required this.documents, this.durationMode = 'prescription', this.suggestedEndDate = '', this.plannedEndDate = ''});
  final String id;
  final String title;
  final PlanStatus status;
  final String startDate;
  final int readiness;
  final String nextTask;
  final List<String> documents;
  final String durationMode;
  final String suggestedEndDate;
  final String plannedEndDate;
}

class DemoDocument {
  const DemoDocument({required this.id, required this.name, required this.type, required this.date, required this.pages, required this.plan});
  final String id;
  final String name;
  final String type;
  final String date;
  final int pages;
  final String plan;
}

class ExtractedItem {
  const ExtractedItem({required this.id, required this.group, required this.title, required this.instruction, required this.timing, required this.source, required this.state});
  final String id;
  final String group;
  final String title;
  final String instruction;
  final String timing;
  final String source;
  final ExtractedState state;

  ExtractedItem copyWith({String? title, String? instruction, String? timing, ExtractedState? state}) => ExtractedItem(id: id, group: group, title: title ?? this.title, instruction: instruction ?? this.instruction, timing: timing ?? this.timing, source: source, state: state ?? this.state);
}

class DoctorQuestion {
  const DoctorQuestion({required this.id, required this.group, required this.title, required this.question, this.answer, this.answered = false});
  final String id;
  final String group;
  final String title;
  final String question;
  final String? answer;
  final bool answered;

  DoctorQuestion copyWith({String? answer, bool? answered}) => DoctorQuestion(id: id, group: group, title: title, question: question, answer: answer ?? this.answer, answered: answered ?? this.answered);
}

class DemoNotification {
  const DemoNotification({required this.id, required this.group, required this.title, required this.detail, required this.kind, this.read = false});
  final String id;
  final String group;
  final String title;
  final String detail;
  final TaskKind? kind;
  final bool read;

  DemoNotification copyWith({bool? read}) => DemoNotification(id: id, group: group, title: title, detail: detail, kind: kind, read: read ?? this.read);
}

class DemoDay {
  const DemoDay(this.label, this.short, this.dateLabel, this.number, this.iso);
  final String label;
  final String short;
  final String dateLabel;
  final int number;
  final String iso;
}

class RealityQuestion {
  const RealityQuestion(this.id, this.category, this.question, this.options);
  final String id;
  final String category;
  final String question;
  final List<String> options;
}

const demoDays = [
  DemoDay('Monday', 'Mon', '17 August', 17, '2026-08-17'),
  DemoDay('Tuesday', 'Tue', '18 August', 18, '2026-08-18'),
  DemoDay('Wednesday', 'Wed', '19 August', 19, '2026-08-19'),
  DemoDay('Thursday', 'Thu', '20 August', 20, '2026-08-20'),
  DemoDay('Friday', 'Fri', '21 August', 21, '2026-08-21'),
  DemoDay('Saturday', 'Sat', '22 August', 22, '2026-08-22'),
  DemoDay('Sunday', 'Sun', '23 August', 23, '2026-08-23'),
];

const initialTasks = [
  DemoTask(id: 't1', day: '2026-08-17', time: '8:00 AM', title: 'Morning Medicine', note: '1 tablet after breakfast (demo)', kind: TaskKind.medicine, status: TaskStatus.ready, completed: true),
  DemoTask(id: 't2', day: '2026-08-17', time: '1:00 PM', title: 'Afternoon Medicine', note: 'Patient is usually away from home', kind: TaskKind.medicine, status: TaskStatus.atRisk),
  DemoTask(id: 't3', day: '2026-08-17', time: '6:00 PM', title: 'Dressing', note: 'Caregiver required', kind: TaskKind.dressing, status: TaskStatus.ready, caregiverId: 'c1'),
  DemoTask(id: 't4', day: '2026-08-17', time: '9:00 PM', title: 'Evening Medicine', note: 'Timing needs verification', kind: TaskKind.medicine, status: TaskStatus.unclear),
  DemoTask(id: 't5', day: '2026-08-17', time: '7:30 AM', title: 'Blood Pressure Check', note: 'Record reading in the app', kind: TaskKind.caregiver, status: TaskStatus.ready, completed: true),
  DemoTask(id: 't6', day: '2026-08-18', time: '8:00 AM', title: 'Morning Medicine', note: '1 tablet after breakfast (demo)', kind: TaskKind.medicine, status: TaskStatus.ready),
  DemoTask(id: 't7', day: '2026-08-18', time: '10:00 AM', title: 'Dressing', note: 'Usual caregiver unavailable', kind: TaskKind.dressing, status: TaskStatus.blocked),
  DemoTask(id: 't8', day: '2026-08-19', time: '9:00 AM', title: 'Lab Visit', note: 'No transport confirmed', kind: TaskKind.lab, status: TaskStatus.blocked),
  DemoTask(id: 't9', day: '2026-08-19', time: '8:00 AM', title: 'Morning Medicine', note: '1 tablet after breakfast (demo)', kind: TaskKind.medicine, status: TaskStatus.ready),
  DemoTask(id: 't10', day: '2026-08-20', time: '1:00 PM', title: 'Afternoon Medicine', note: 'Overlaps with time away from home', kind: TaskKind.medicine, status: TaskStatus.atRisk),
  DemoTask(id: 't11', day: '2026-08-21', time: '6:00 PM', title: 'Dressing', note: 'Caregiver available', kind: TaskKind.dressing, status: TaskStatus.ready, caregiverId: 'c1'),
  DemoTask(id: 't12', day: '2026-08-22', time: '9:00 AM', title: 'Hospital Follow-Up', note: 'Transport not arranged yet', kind: TaskKind.visit, status: TaskStatus.atRisk),
  DemoTask(id: 't13', day: '2026-08-23', time: '8:00 AM', title: 'Morning Medicine', note: '1 tablet after breakfast (demo)', kind: TaskKind.medicine, status: TaskStatus.ready),
  DemoTask(id: 't14', day: '2026-08-23', time: '6:00 PM', title: 'Dressing', note: 'Caregiver available', kind: TaskKind.dressing, status: TaskStatus.ready, caregiverId: 'c1'),
];

const initialGaps = [
  DemoGap(id: 'g1', title: 'Transport unavailable for hospital follow-up', status: TaskStatus.blocked, category: 'Transport', when: '19 August — 9:00 AM', summary: 'No confirmed transport is currently available for the lab visit.', instruction: 'Lab test to be completed before the next follow-up appointment.', reality: 'Patient reported that transport is usually arranged by a family member at short notice.', reason: 'The visit is scheduled during working hours when no family member is free to travel.', nextStep: 'Confirm a ride with a caregiver, or ask the clinic about an alternative appointment time.', taskId: 't8'),
  DemoGap(id: 'g2', title: 'Dressing required while caregiver is unavailable', status: TaskStatus.blocked, category: 'Caregiver', when: '18 August — 10:00 AM', summary: 'The dressing task needs assistance, but the usual caregiver is not available in the morning.', instruction: 'Wound dressing to be changed with assistance.', reality: 'Ahmed Khan is available between 6 PM and 10 PM only.', reason: 'The scheduled time falls outside every recorded caregiver availability window.', nextStep: 'Assign another caregiver, or ask whether the dressing time can be shifted to the evening.', taskId: 't7'),
  DemoGap(id: 'g3', title: 'Afternoon medicine overlaps with time away from home', status: TaskStatus.atRisk, category: 'Routine', when: 'Daily — 1:00 PM', summary: 'The patient is usually out of home when the afternoon dose is due.', instruction: 'Afternoon dose to be taken after lunch.', reality: 'Patient leaves home around 11:00 AM and returns near 5:00 PM.', reason: 'No medicine is carried outside the home, so the dose is likely to be missed.', nextStep: 'Prepare a small carry-pouch with the afternoon dose, or confirm a flexible timing window.', taskId: 't2'),
  DemoGap(id: 'g4', title: 'Evening medicine timing is unclear in the document', status: TaskStatus.unclear, category: 'Instruction', when: 'Daily — evening', summary: 'A timing instruction in the uploaded document could not be read clearly.', instruction: 'Evening dose — handwriting partially unreadable.', reality: 'Patient is not certain whether the dose is before or after dinner.', reason: 'The extracted text was low confidence and was not auto-activated.', nextStep: 'Ask the healthcare professional to confirm the exact evening timing.', taskId: 't4'),
];

const initialCaregivers = [
  DemoCaregiver(id: 'c1', name: 'Ahmed Khan', relationship: 'Son', phone: '+92 300 1234567', availability: '6 PM – 10 PM', helpsWith: ['Dressing', 'Medicine reminders'], access: ['Assigned tasks only'], taskIds: ['t3', 't11']),
  DemoCaregiver(id: 'c2', name: 'Sana Khan', relationship: 'Daughter-in-law', phone: '+92 301 7654321', availability: '9 AM – 1 PM', helpsWith: ['Medicine reminders'], access: ['Assigned tasks only', 'Schedule'], taskIds: []),
];

const demoPlans = [
  DemoPlan(id: 'p1', title: 'Post-Discharge Care Plan', status: PlanStatus.active, startDate: '17 Aug 2026', readiness: 82, nextTask: 'Afternoon Medicine — 1:00 PM', documents: ['d1', 'd2']),
  DemoPlan(id: 'p2', title: 'Wound Care Follow-Up', status: PlanStatus.needsAttention, startDate: '12 Aug 2026', readiness: 64, nextTask: 'Dressing — Tomorrow 10:00 AM', documents: ['d3']),
  DemoPlan(id: 'p3', title: 'Blood Pressure Review Plan', status: PlanStatus.draft, startDate: 'Not started', readiness: 0, nextTask: 'Upload documents to continue', documents: []),
  DemoPlan(id: 'p4', title: 'Post-Surgery Recovery Plan', status: PlanStatus.completed, startDate: '02 Jun 2026', readiness: 96, nextTask: 'Plan completed', documents: ['d4']),
];

const initialDocuments = [
  DemoDocument(id: 'd1', name: 'Prescription', type: 'PDF', date: '17 Aug 2026', pages: 1, plan: 'Post-Discharge Care Plan'),
  DemoDocument(id: 'd2', name: 'Discharge Summary', type: 'PDF', date: '17 Aug 2026', pages: 3, plan: 'Post-Discharge Care Plan'),
  DemoDocument(id: 'd3', name: 'Lab Instructions', type: 'JPG', date: '12 Aug 2026', pages: 1, plan: 'Wound Care Follow-Up'),
  DemoDocument(id: 'd4', name: 'Follow-Up Slip', type: 'JPG', date: '02 Jun 2026', pages: 1, plan: 'Post-Surgery Recovery Plan'),
];

const extractedItems = [
  ExtractedItem(id: 'e1', group: 'Medicines', title: 'Paracetamol (demo)', instruction: '1 tablet', timing: 'Morning', source: 'Prescription — Page 1', state: ExtractedState.review),
  ExtractedItem(id: 'e2', group: 'Medicines', title: 'Antibiotic (demo)', instruction: '1 capsule', timing: 'Afternoon', source: 'Prescription — Page 1', state: ExtractedState.review),
  ExtractedItem(id: 'e3', group: 'Medicines', title: 'Evening tablet (demo)', instruction: '1 tablet', timing: 'Timing unclear in document', source: 'Prescription — Page 1', state: ExtractedState.unclear),
  ExtractedItem(id: 'e4', group: 'Follow-Ups', title: 'Hospital follow-up appointment', instruction: 'Visit outpatient clinic', timing: '22 August — 9:00 AM', source: 'Discharge Summary — Page 2', state: ExtractedState.review),
  ExtractedItem(id: 'e5', group: 'Lab Tests', title: 'Blood test', instruction: 'Fasting sample required', timing: '19 August — Morning', source: 'Discharge Summary — Page 3', state: ExtractedState.review),
  ExtractedItem(id: 'e6', group: 'Care Tasks', title: 'Wound dressing', instruction: 'Change dressing with assistance', timing: 'Daily', source: 'Discharge Summary — Page 2', state: ExtractedState.review),
  ExtractedItem(id: 'e7', group: 'Other Instructions', title: 'Fluid intake', instruction: 'Drink water regularly through the day', timing: 'Daily', source: 'Discharge Summary — Page 3', state: ExtractedState.review),
];

const initialQuestions = [
  DoctorQuestion(id: 'q1', group: 'Medicines', title: 'Medicine Timing', question: 'What exact time should the evening medicine be taken?'),
  DoctorQuestion(id: 'q2', group: 'Medicines', title: 'Missed Dose', question: 'What should be done if the afternoon dose is taken late?'),
  DoctorQuestion(id: 'q3', group: 'Follow-Up', title: 'Appointment Flexibility', question: 'Can the hospital follow-up be moved to a later time in the day?'),
  DoctorQuestion(id: 'q4', group: 'Tests', title: 'Fasting Requirement', question: 'How many hours of fasting are needed before the blood test?', answered: true, answer: 'At least 8 hours before the sample.'),
  DoctorQuestion(id: 'q5', group: 'Care Instructions', title: 'Dressing Frequency', question: 'Can the dressing be changed in the evening instead of the morning?'),
];

const initialNotifications = [
  DemoNotification(id: 'n1', group: 'Today', title: 'Medicine due soon', detail: '30 minutes remaining', kind: TaskKind.medicine),
  DemoNotification(id: 'n2', group: 'Today', title: 'Transport unresolved', detail: "Tomorrow's hospital visit has no confirmed transport", kind: TaskKind.visit),
  DemoNotification(id: 'n3', group: 'Today', title: 'Ahmed completed a caregiver task', detail: 'Dressing assistance marked completed', kind: TaskKind.caregiver, read: true),
  DemoNotification(id: 'n4', group: 'Yesterday', title: 'Teach-Back completed', detail: 'Understanding score recorded at 76%', kind: null, read: true),
];

const realityQuestions = [
  RealityQuestion('r1', 'Routine', 'When do you usually wake up?', ['Before 6 AM', '6 – 8 AM', '8 – 10 AM', 'After 10 AM']),
  RealityQuestion('r2', 'Routine', 'When do you usually leave home?', ['I stay at home', 'Before 9 AM', '9 AM – 12 PM', 'After 12 PM']),
  RealityQuestion('r3', 'Routine', 'When do you usually return home?', ['I stay at home', 'Before 3 PM', '3 – 6 PM', 'After 6 PM']),
  RealityQuestion('r4', 'Caregiver', "Do any care tasks need someone's assistance?", ['Yes, dressing', 'Yes, medicines', 'Yes, travel', 'No assistance needed']),
  RealityQuestion('r5', 'Caregiver', 'Who is usually available to help?', ['Son', 'Daughter', 'Spouse', 'Neighbour or friend']),
  RealityQuestion('r6', 'Caregiver', 'At what times is that person usually available?', ['Morning', 'Afternoon', 'Evening', 'Weekends only']),
  RealityQuestion('r7', 'Transport', 'How do you usually travel to your clinic?', ['Family car', 'Rickshaw or taxi', 'Public transport', 'Walking']),
  RealityQuestion('r8', 'Medicine Access', 'Have all prescribed medicines been obtained?', ['Yes, all of them', 'Some are missing', 'None yet']),
  RealityQuestion('r9', 'Reading & Understanding', 'Can the written instructions be read comfortably?', ['Yes, easily', 'With difficulty', 'Someone reads them for me']),
];

const readinessTrend = <(String, int)>[('Week 1', 48), ('Week 2', 64), ('Week 3', 78), ('Week 4', 91)];

class CareDemoState extends ChangeNotifier {
  CareDemoState._();
  static final instance = CareDemoState._();

  List<DemoTask> tasks = List.of(initialTasks);
  List<DemoGap> gaps = List.of(initialGaps);
  List<DemoCaregiver> caregivers = List.of(initialCaregivers);
  List<DoctorQuestion> questions = List.of(initialQuestions);
  List<DemoNotification> notifications = List.of(initialNotifications);
  List<DemoDocument> documents = List.of(initialDocuments);
  int understanding = 76;
  String language = 'Roman Urdu';
  bool largeText = false;
  bool voiceGuidance = false;
  bool simpleCareMode = false;
  bool reducedMotion = false;
  bool carePlanActivated = false;

  int get readiness => math.min(100, 64 + gaps.where((gap) => gap.status == TaskStatus.resolved).length * 8);
  int get unreadNotifications => notifications.where((notification) => !notification.read).length;
  bool get hasOpenGaps => gaps.any((gap) => gap.status != TaskStatus.resolved);
  bool get canActivateCarePlan => !hasOpenGaps;

  void activateCarePlan() {
    if (!canActivateCarePlan) return;
    carePlanActivated = true;
    notifyListeners();
  }

  void toggleTask(String id) {
    tasks = tasks.map((task) => task.id == id ? task.copyWith(completed: !task.completed) : task).toList();
    notifyListeners();
  }

  void resolveGap(String id) {
    final gap = gaps.where((item) => item.id == id).firstOrNull;
    final taskId = gap?.taskId;
    gaps = gaps.map((item) => item.id == id ? item.copyWith(status: TaskStatus.resolved) : item).toList();
    if (taskId != null) {
      tasks = tasks.map((task) => task.id == taskId ? task.copyWith(status: TaskStatus.ready) : task).toList();
    }
    notifyListeners();
  }

  void assignGap(String gapId, String caregiverId) {
    final taskId = gaps.where((item) => item.id == gapId).firstOrNull?.taskId;
    if (taskId != null) {
      tasks = tasks.map((task) => task.id == taskId ? task.copyWith(status: TaskStatus.ready, caregiverId: caregiverId) : task).toList();
      caregivers = caregivers.map((caregiver) {
        if (caregiver.id != caregiverId || caregiver.taskIds.contains(taskId)) return caregiver;
        return caregiver.copyWith(taskIds: [...caregiver.taskIds, taskId]);
      }).toList();
    }
    gaps = gaps.map((item) => item.id == gapId ? item.copyWith(status: TaskStatus.resolved) : item).toList();
    notifyListeners();
  }

  void addCaregiver({required String name, required String relationship, required String phone, required String availability, required List<String> helpsWith, required List<String> access}) {
    caregivers = [...caregivers, DemoCaregiver(id: 'c${DateTime.now().millisecondsSinceEpoch}', name: name, relationship: relationship, phone: phone, availability: availability, helpsWith: helpsWith, access: access, taskIds: const [])];
    notifyListeners();
  }

  void answerQuestion(String id, String answer) {
    questions = questions.map((question) => question.id == id ? question.copyWith(answer: answer, answered: true) : question).toList();
    notifyListeners();
  }

  void addQuestion({required String group, required String title, required String question}) {
    questions = [...questions, DoctorQuestion(id: 'q${DateTime.now().millisecondsSinceEpoch}', group: group, title: title, question: question)];
    notifyListeners();
  }

  void markRead(String id) {
    notifications = notifications.map((notification) => notification.id == id ? notification.copyWith(read: true) : notification).toList();
    notifyListeners();
  }

  void markAllRead() {
    notifications = notifications.map((notification) => notification.copyWith(read: true)).toList();
    notifyListeners();
  }

  void removeDocument(String id) {
    documents = documents.where((document) => document.id != id).toList();
    notifyListeners();
  }

  void setUnderstanding(int value) {
    understanding = value.clamp(0, 100).toInt();
    notifyListeners();
  }

  void updatePreferences({String? language, bool? largeText, bool? voiceGuidance, bool? simpleCareMode, bool? reducedMotion}) {
    this.language = language ?? this.language;
    this.largeText = largeText ?? this.largeText;
    this.voiceGuidance = voiceGuidance ?? this.voiceGuidance;
    this.simpleCareMode = simpleCareMode ?? this.simpleCareMode;
    this.reducedMotion = reducedMotion ?? this.reducedMotion;
    notifyListeners();
  }
}

extension FirstOrNullExtension<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}

String taskStatusLabel(TaskStatus status) => switch (status) {
      TaskStatus.ready => 'Ready',
      TaskStatus.atRisk => 'At Risk',
      TaskStatus.blocked => 'Blocked',
      TaskStatus.unclear => 'Unclear',
      TaskStatus.resolved => 'Resolved',
    };

String planStatusLabel(PlanStatus status) => switch (status) {
      PlanStatus.draft => 'Draft',
      PlanStatus.processing => 'Processing',
      PlanStatus.needsReview => 'Needs Review',
      PlanStatus.realityCheck => 'Reality Check Required',
      PlanStatus.needsAttention => 'Needs Attention',
      PlanStatus.active => 'Active',
      PlanStatus.completed => 'Completed',
    };
