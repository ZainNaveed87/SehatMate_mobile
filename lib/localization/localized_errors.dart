import '../services/auth_service.dart';
import '../services/care_plan_service.dart';
import 'app_language.dart';
import 'app_strings.dart';

String localizedCarePlanExceptionMessage(
  CarePlanException exception,
  AppLanguage language,
) {
  return localizedKnownMessage(exception.message, language);
}

String localizedAuthExceptionMessage(
  AuthException exception,
  AppLanguage language,
) {
  return localizedKnownMessage(exception.message, language);
}

String localizedKnownMessage(String message, AppLanguage language) {
  final key = _knownMessageKeys[message];
  return key == null ? message : AppStrings.get(key, language);
}

const _knownMessageKeys = <String, String>{
  'The server returned an invalid plan list.':
      'error_invalid_plan_list',
  'The server returned an invalid care plan.':
      'error_invalid_care_plan',
  'The server returned an invalid task outcome.':
      'error_invalid_task_outcome',
  'The document is empty or exceeds the 20 MB limit.':
      'error_document_empty_or_too_large',
  'The server returned an invalid document.':
      'error_invalid_document',
  'The server did not return a document ID.':
      'error_missing_document_id',
  'The server returned an invalid safety check.':
      'error_invalid_safety_check',
  'The label image is empty or exceeds the 10 MB limit.':
      'error_label_image_empty_or_too_large',
  'The server returned invalid ingredient evidence.':
      'error_invalid_ingredient_evidence',
  'The server returned an invalid routine profile.':
      'error_invalid_routine_profile',
  'The server returned an invalid care gap.':
      'error_invalid_care_gap',
  'Enter the answer you received from your healthcare professional.':
      'error_enter_professional_answer',
  'Please sign in to continue.':
      'error_sign_in_to_continue',
  'The care plan request could not be completed.':
      'error_care_plan_request_failed',
  'The server returned an invalid response.':
      'error_invalid_server_response',
  'The server took too long to respond. Please try again.':
      'error_server_timeout',
  'Could not connect to the server. Check your internet connection.':
      'error_server_connection',
  'Could not connect to the server. Check the API URL and internet connection.':
      'error_api_connection',
  'The request could not be completed.':
      'error_request_failed',
  'Upload failed. Please try again.':
      'error_upload_failed_try_again',
  'The server returned an invalid profile.':
      'error_invalid_profile',
  'Google Web Client ID is not configured.':
      'error_google_client_not_configured',
  'Google Sign-In is not supported on this platform.':
      'error_google_unsupported',
  'Google did not return a valid ID token.':
      'error_google_missing_token',
  'Google Sign-In was cancelled.':
      'error_google_cancelled',
  'Google Sign-In configuration is incorrect. Check the package name, SHA-1 and Web Client ID.':
      'error_google_config_incorrect_full',
  'Google Sign-In is not configured correctly on this device.':
      'error_google_device_config',
  'Google Sign-In screen could not be opened.':
      'error_google_ui_unavailable',
  'Google Sign-In failed. Please try again.':
      'error_google_failed',
  'Google Sign-In configuration is incorrect. Check the Web Client ID.':
      'error_google_config_incorrect_short',
  'Google Sign-In could not be initialized.':
      'error_google_init_failed',
  'API URL is not configured. Run the app with --dart-define=API_BASE_URL=https://your-domain.com/api':
      'error_api_url_not_configured',
  'The server did not return a valid session.':
      'error_invalid_session',
};
