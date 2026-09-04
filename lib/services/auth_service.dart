import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;

import '../core/api_config.dart';

class AuthUser {
  const AuthUser({required this.id, required this.name, required this.email});

  final String id;
  final String name;
  final String email;

  factory AuthUser.fromJson(Map<String, dynamic> json) {
    return AuthUser(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {'id': id, 'name': name, 'email': email};
  }

  String get initials {
    final parts = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList();

    if (parts.isEmpty) {
      return 'U';
    }

    if (parts.length == 1) {
      return parts.first.substring(0, 1).toUpperCase();
    }

    return '${parts.first.substring(0, 1)}'
            '${parts.last.substring(0, 1)}'
        .toUpperCase();
  }
}

class GoogleAuthResult {
  const GoogleAuthResult({required this.user, required this.isNewUser});

  final AuthUser user;
  final bool isNewUser;
}

class PasswordResetRequestResult {
  const PasswordResetRequestResult({required this.cooldownSeconds});

  final int cooldownSeconds;
}

class PatientProfile {
  const PatientProfile({
    required this.usingFor,
    required this.patientName,
    required this.ageGroup,
    required this.city,
    required this.preferredLanguage,
    required this.accessibilityMode,
    required this.caregiverSupport,
    required this.onboardingCompleted,
  });

  final String usingFor;
  final String patientName;
  final String ageGroup;
  final String city;
  final String preferredLanguage;
  final String accessibilityMode;
  final bool caregiverSupport;
  final bool onboardingCompleted;

  PatientProfile copyWith({
    String? usingFor,
    String? patientName,
    String? ageGroup,
    String? city,
    String? preferredLanguage,
    String? accessibilityMode,
    bool? caregiverSupport,
    bool? onboardingCompleted,
  }) {
    return PatientProfile(
      usingFor: usingFor ?? this.usingFor,
      patientName: patientName ?? this.patientName,
      ageGroup: ageGroup ?? this.ageGroup,
      city: city ?? this.city,
      preferredLanguage: preferredLanguage ?? this.preferredLanguage,
      accessibilityMode: accessibilityMode ?? this.accessibilityMode,
      caregiverSupport: caregiverSupport ?? this.caregiverSupport,
      onboardingCompleted: onboardingCompleted ?? this.onboardingCompleted,
    );
  }

  factory PatientProfile.fromJson(Map<String, dynamic> json) {
    return PatientProfile(
      usingFor: json['usingFor']?.toString() ?? 'Myself',
      patientName: json['patientName']?.toString() ?? '',
      ageGroup: json['ageGroup']?.toString() ?? '60 – 70',
      city: json['city']?.toString() ?? '',
      preferredLanguage: json['preferredLanguage']?.toString() ?? 'Roman Urdu',
      accessibilityMode: json['accessibilityMode']?.toString() ?? 'Standard',
      caregiverSupport: json['caregiverSupport'] == true,
      onboardingCompleted: json['onboardingCompleted'] == true,
    );
  }

  Map<String, dynamic> toRequestJson() {
    return {
      'usingFor': usingFor,
      'patientName': patientName,
      'ageGroup': ageGroup,
      'city': city,
      'preferredLanguage': preferredLanguage,
      'accessibilityMode': accessibilityMode,
      'caregiverSupport': caregiverSupport,
    };
  }
}

class AuthException implements Exception {
  const AuthException(this.message);

  final String message;

  @override
  String toString() => message;
}

class AuthSession extends ChangeNotifier {
  AuthSession._();

  static final AuthSession instance = AuthSession._();

  static const String _tokenKey = 'sehatroute_auth_token';
  static const String _userKey = 'sehatroute_auth_user';
  static const String _onboardingKeyPrefix = 'sehatroute_onboarding_complete_';

  static const Duration _requestTimeout = Duration(seconds: 20);

  static const String _googleWebClientId = String.fromEnvironment(
    'GOOGLE_WEB_CLIENT_ID',
    defaultValue:
        '333869910734-2ju6rlcq5ha1mohotb782a8l8r8pq712.apps.googleusercontent.com',
  );

  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  final http.Client _client = http.Client();
  final GoogleSignIn _googleSignIn = GoogleSignIn.instance;

  String? _token;
  AuthUser? _user;
  PatientProfile? _profile;

  bool _initialized = false;
  bool _googleInitialized = false;
  bool _onboardingComplete = false;
  bool _guestMode = false;

  String? get token => _token;

  AuthUser? get user => _user;

  PatientProfile? get profile => _profile;

  bool get isAuthenticated => _token != null && _user != null;

  bool get isGuest => _guestMode;

  bool get canAccessApp => isAuthenticated || isGuest;

  bool get needsOnboarding => isAuthenticated && !_onboardingComplete;

  bool get initialized => _initialized;

  Future<void> initialize() async {
    if (_initialized) {
      return;
    }

    try {
      final storedToken = await _storage.read(key: _tokenKey);
      final storedUser = await _storage.read(key: _userKey);

      if (storedToken != null && storedUser != null) {
        final decoded = jsonDecode(storedUser);

        if (decoded is Map<String, dynamic>) {
          _token = storedToken;
          _user = AuthUser.fromJson(decoded);
          await _loadOnboardingState();
        }
      }
    } catch (_) {
      await _storage.delete(key: _tokenKey);
      await _storage.delete(key: _userKey);
    } finally {
      _initialized = true;
      notifyListeners();
    }
  }

  Future<AuthUser> login({
    required String email,
    required String password,
  }) async {
    final data = await _post('/auth/login', {
      'email': email.trim(),
      'password': password,
    });

    return _saveSession(data);
  }

  Future<AuthUser> register({
    required String name,
    required String email,
    required String password,
  }) async {
    final data = await _post('/auth/register', {
      'name': name.trim(),
      'email': email.trim(),
      'password': password,
    });

    return _saveSession(data);
  }

  Future<PasswordResetRequestResult> requestPasswordReset({
    required String email,
  }) async {
    final data = await _post('/auth/forgot-password', {'email': email.trim()});

    final rawCooldown = data['cooldownSeconds'];

    final cooldown = rawCooldown is num
        ? rawCooldown.toInt()
        : int.tryParse(rawCooldown?.toString() ?? '') ?? 60;

    return PasswordResetRequestResult(
      cooldownSeconds: cooldown.clamp(0, 300).toInt(),
    );
  }

  Future<String> verifyPasswordResetCode({
    required String email,
    required String code,
  }) async {
    final data = await _post('/auth/verify-reset-code', {
      'email': email.trim(),
      'code': code.trim(),
    });

    final resetToken = data['resetToken']?.toString() ?? '';

    if (resetToken.isEmpty) {
      throw const AuthException(
        'The server did not return a valid password reset session.',
      );
    }

    return resetToken;
  }

  Future<void> resetPassword({
    required String email,
    required String resetToken,
    required String newPassword,
  }) async {
    await _post('/auth/reset-password', {
      'email': email.trim(),
      'resetToken': resetToken,
      'newPassword': newPassword,
    });
  }

  Future<GoogleAuthResult> loginWithGoogle() async {
    if (_googleWebClientId.trim().isEmpty) {
      throw const AuthException('Google Web Client ID is not configured.');
    }

    await _initializeGoogleSignIn();

    if (!_googleSignIn.supportsAuthenticate()) {
      throw const AuthException(
        'Google Sign-In is not supported on this platform.',
      );
    }

    try {
      final account = await _googleSignIn.authenticate();
      final idToken = account.authentication.idToken;

      if (idToken == null || idToken.isEmpty) {
        throw const AuthException('Google did not return a valid ID token.');
      }

      final data = await _post('/auth/google', {'idToken': idToken});

      final isNewUser = data['isNewUser'] == true;
      final user = await _saveSession(data);

      return GoogleAuthResult(user: user, isNewUser: isNewUser);
    } on GoogleSignInException catch (error) {
      switch (error.code) {
        case GoogleSignInExceptionCode.canceled:
          throw const AuthException('Google Sign-In was cancelled.');

        case GoogleSignInExceptionCode.clientConfigurationError:
          throw const AuthException(
            'Google Sign-In configuration is incorrect. Check the package name, SHA-1 and Web Client ID.',
          );

        case GoogleSignInExceptionCode.providerConfigurationError:
          throw const AuthException(
            'Google Sign-In is not configured correctly on this device.',
          );

        case GoogleSignInExceptionCode.uiUnavailable:
          throw const AuthException(
            'Google Sign-In screen could not be opened.',
          );

        default:
          throw const AuthException('Google Sign-In failed. Please try again.');
      }
    }
  }

  Future<void> logout() async {
    _token = null;
    _user = null;
    _profile = null;
    _onboardingComplete = false;
    _guestMode = false;

    await _storage.delete(key: _tokenKey);
    await _storage.delete(key: _userKey);

    if (_googleInitialized) {
      try {
        await _googleSignIn.signOut();
      } catch (_) {
        // Local session must still be cleared if Google sign-out fails.
      }
    }

    notifyListeners();
  }

  Future<void> startGuestSession() async {
    await logout();
    _guestMode = true;
    notifyListeners();
  }

  Future<PatientProfile> completeOnboarding({
    required String usingFor,
    required String patientName,
    required String ageGroup,
    required String city,
    required String preferredLanguage,
    required String accessibilityMode,
    required bool caregiverSupport,
  }) async {
    final data = await _post('/onboarding/complete', {
      'usingFor': usingFor,
      'patientName': patientName.trim(),
      'ageGroup': ageGroup,
      'city': city.trim(),
      'preferredLanguage': preferredLanguage,
      'accessibilityMode': accessibilityMode,
      'caregiverSupport': caregiverSupport,
    }, authenticated: true);

    final profileJson = data['profile'];
    if (profileJson is! Map<String, dynamic>) {
      throw const AuthException('The server returned an invalid profile.');
    }

    final profile = PatientProfile.fromJson(profileJson);
    _profile = profile;
    _onboardingComplete =
        data['onboardingCompleted'] == true || profile.onboardingCompleted;
    await _saveOnboardingState();
    notifyListeners();
    return profile;
  }

  Future<PatientProfile?> fetchProfile() async {
    final data = await _get('/profile', authenticated: true);
    final profileJson = data['profile'];
    if (profileJson == null) {
      _profile = null;
      return null;
    }
    if (profileJson is! Map<String, dynamic>) {
      throw const AuthException('The server returned an invalid profile.');
    }

    final profile = PatientProfile.fromJson(profileJson);
    _profile = profile;
    _onboardingComplete = profile.onboardingCompleted;
    await _saveOnboardingState();
    notifyListeners();
    return profile;
  }

  Future<PatientProfile> updateProfile(PatientProfile profile) async {
    final data = await _put(
      '/profile',
      profile.toRequestJson(),
      authenticated: true,
    );
    final profileJson = data['profile'];
    if (profileJson is! Map<String, dynamic>) {
      throw const AuthException('The server returned an invalid profile.');
    }

    final updated = PatientProfile.fromJson(profileJson);
    _profile = updated;
    _onboardingComplete = updated.onboardingCompleted;
    await _saveOnboardingState();
    notifyListeners();
    return updated;
  }

  String _onboardingKeyFor(String userId) => '$_onboardingKeyPrefix$userId';

  Future<void> _loadOnboardingState() async {
    final user = _user;
    if (user == null) {
      _onboardingComplete = false;
      return;
    }
    _onboardingComplete =
        await _storage.read(key: _onboardingKeyFor(user.id)) == 'true';
  }

  Future<void> _saveOnboardingState() async {
    final user = _user;
    if (user == null) return;
    await _storage.write(
      key: _onboardingKeyFor(user.id),
      value: _onboardingComplete ? 'true' : 'false',
    );
  }

  Future<void> _initializeGoogleSignIn() async {
    if (_googleInitialized) {
      return;
    }

    try {
      await _googleSignIn.initialize(serverClientId: _googleWebClientId.trim());

      _googleInitialized = true;
    } on GoogleSignInException catch (error) {
      if (error.code == GoogleSignInExceptionCode.clientConfigurationError) {
        throw const AuthException(
          'Google Sign-In configuration is incorrect. Check the Web Client ID.',
        );
      }

      throw const AuthException('Google Sign-In could not be initialized.');
    }
  }

  Future<Map<String, dynamic>> _post(
    String path,
    Map<String, dynamic> body, {
    bool authenticated = false,
  }) {
    return _request('POST', path, body: body, authenticated: authenticated);
  }

  Future<Map<String, dynamic>> _put(
    String path,
    Map<String, dynamic> body, {
    bool authenticated = false,
  }) {
    return _request('PUT', path, body: body, authenticated: authenticated);
  }

  Future<Map<String, dynamic>> _get(String path, {bool authenticated = false}) {
    return _request('GET', path, authenticated: authenticated);
  }

  Future<Map<String, dynamic>> _request(
    String method,
    String path, {
    Map<String, dynamic>? body,
    bool authenticated = false,
  }) async {
    if (!ApiConfig.isConfigured) {
      throw const AuthException(
        'API URL is not configured. Run the app with '
        '--dart-define=API_BASE_URL=https://your-domain.com/api',
      );
    }

    if (authenticated && !isAuthenticated) {
      throw const AuthException('Please sign in to continue.');
    }

    try {
      final headers = <String, String>{
        'Content-Type': 'application/json; charset=utf-8',
        'Accept': 'application/json',
        if (authenticated) 'Authorization': 'Bearer $_token',
      };
      final uri = ApiConfig.endpoint(path);
      late final http.Response response;

      if (method == 'GET') {
        response = await _client
            .get(uri, headers: headers)
            .timeout(_requestTimeout);
      } else if (method == 'PUT') {
        response = await _client
            .put(uri, headers: headers, body: jsonEncode(body))
            .timeout(_requestTimeout);
      } else {
        response = await _client
            .post(uri, headers: headers, body: jsonEncode(body))
            .timeout(_requestTimeout);
      }

      final decoded = _decodeResponse(response);

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw AuthException(
          decoded['message']?.toString() ??
              'The request could not be completed.',
        );
      }

      final data = decoded['data'];

      if (data is! Map<String, dynamic>) {
        throw const AuthException('The server returned an invalid response.');
      }

      return data;
    } on TimeoutException {
      throw const AuthException(
        'The server took too long to respond. Please try again.',
      );
    } on http.ClientException {
      throw const AuthException(
        'Could not connect to the server. Check the API URL and internet connection.',
      );
    } on FormatException {
      throw const AuthException('The server returned an invalid response.');
    }
  }

  Map<String, dynamic> _decodeResponse(http.Response response) {
    if (response.bodyBytes.isEmpty) {
      return <String, dynamic>{};
    }

    final value = jsonDecode(utf8.decode(response.bodyBytes));

    if (value is Map<String, dynamic>) {
      return value;
    }

    throw const FormatException('Expected a JSON object.');
  }

  Future<AuthUser> _saveSession(Map<String, dynamic> data) async {
    final token = data['token']?.toString();
    final userJson = data['user'];

    if (token == null || token.isEmpty || userJson is! Map<String, dynamic>) {
      throw const AuthException('The server did not return a valid session.');
    }

    final user = AuthUser.fromJson(userJson);
    final onboardingComplete = data['onboardingCompleted'] == true;

    _token = token;
    _user = user;
    _profile = null;
    _onboardingComplete = onboardingComplete;
    _guestMode = false;

    await _storage.write(key: _tokenKey, value: token);

    await _storage.write(key: _userKey, value: jsonEncode(user.toJson()));

    await _saveOnboardingState();

    notifyListeners();

    return user;
  }
}
