abstract final class AppRoutes {
  static const landing = '/';
  static const auth = '/auth';
  static const onboarding = '/onboarding';
  static const dashboard = '/dashboard';
  static const carePlans = '/care-plans';
  static const carePlanNew = '/care-plan/new';
  static const carePlanUpload = '/care-plan/upload';
  static const carePlanReview = '/care-plan/review';
  static const calendar = '/calendar';
  static const family = '/family';
  static const familyNew = '/family/new';
  static const teachBack = '/teach-back';
  static const progress = '/progress';
  static const documents = '/documents';
  static const careGaps = '/care-gaps';
  static const simulation = '/simulation';
  static const realityCheck = '/reality-check';
  static const doctorQuestions = '/doctor-questions';
  static const simpleCare = '/simple-care';
  static const notifications = '/notifications';
  static const patientProfile = '/patient-profile';
  static const settings = '/settings';
  static const routinePreferences = '/routine-preferences';

  static const publicRoutes = {landing, auth};

  static String carePlan(String id) => '/care-plan/$id';
  static String careGap(String id) => '/care-gaps/$id';
  static String caregiver(String id) => '/family/$id';
}
