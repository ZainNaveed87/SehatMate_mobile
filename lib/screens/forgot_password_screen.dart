import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/app_theme.dart';
import '../localization/app_language.dart';
import '../localization/language_scope.dart';
import '../services/auth_service.dart';
import '../widgets/brand_logo.dart';
import '../widgets/ui.dart';

enum _PasswordResetStep { email, code, newPassword, done }

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key, this.initialEmail});

  final String? initialEmail;

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _email = TextEditingController();
  final _code = TextEditingController();
  final _newPassword = TextEditingController();
  final _confirmPassword = TextEditingController();

  _PasswordResetStep _step = _PasswordResetStep.email;

  bool _submitting = false;
  bool _hideNewPassword = true;
  bool _hideConfirmPassword = true;

  String? _error;
  String? _info;
  String? _resetToken;

  int _cooldownSeconds = 0;
  Timer? _cooldownTimer;

  @override
  void initState() {
    super.initState();

    final initial = widget.initialEmail?.trim() ?? '';

    if (initial.isNotEmpty) {
      _email.text = initial;
    }
  }

  @override
  void dispose() {
    _cooldownTimer?.cancel();

    _email.dispose();
    _code.dispose();
    _newPassword.dispose();
    _confirmPassword.dispose();

    super.dispose();
  }

  String _copy({
    required String english,
    required String urdu,
    required String romanUrdu,
  }) {
    return switch (context.appLanguage) {
      AppLanguage.english => english,
      AppLanguage.urdu => urdu,
      AppLanguage.romanUrdu => romanUrdu,
    };
  }

  bool _validEmail(String value) {
    return RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(value.trim());
  }

  String _localizedError(AuthException error) {
    final message = error.message.trim();

    switch (message) {
      case 'This account uses Google Sign-In. Please continue with Google.':
        return _copy(
          english:
              'This account uses Google Sign-In. Please continue with Google.',
          urdu:
              'ÛŒÛ Ø§Ú©Ø§Ø¤Ù†Ù¹ Ú¯ÙˆÚ¯Ù„ Ø³Ø§Ø¦Ù† Ø§ÙÙ† Ø§Ø³ØªØ¹Ù…Ø§Ù„ Ú©Ø±ØªØ§ ÛÛ’Û” Ø¨Ø±Ø§ÛÙ Ú©Ø±Ù… Ú¯ÙˆÚ¯Ù„ Ú©Û’ Ø°Ø±ÛŒØ¹Û’ Ø³Ø§Ø¦Ù† Ø§ÙÙ† Ú©Ø±ÛŒÚºÛ”',
          romanUrdu:
              'Yeh account Google Sign-In use karta hai. Please Google se sign in karein.',
        );

      case 'Invalid or expired verification code.':
        return _copy(
          english:
              'The verification code is incorrect, expired, or has already been used.',
          urdu:
              'ØªØµØ¯ÛŒÙ‚ÛŒ Ú©ÙˆÚˆ ØºÙ„Ø· ÛÛ’ØŒ Ø®ØªÙ… ÛÙˆ Ú†Ú©Ø§ ÛÛ’ØŒ ÛŒØ§ Ù¾ÛÙ„Û’ Ø§Ø³ØªØ¹Ù…Ø§Ù„ ÛÙˆ Ú†Ú©Ø§ ÛÛ’Û”',
          romanUrdu:
              'Verification code ghalat hai, expire ho chuka hai, ya pehle use ho chuka hai.',
        );

      case 'Password reset session is invalid or expired. Please request a new code.':
        return _copy(
          english:
              'Your password reset session has expired. Please request a new code.',
          urdu:
              'Ø¢Ù¾ Ú©Ø§ Ù¾Ø§Ø³ ÙˆØ±Úˆ Ø±ÛŒ Ø³ÛŒÙ¹ Ø³ÛŒØ´Ù† Ø®ØªÙ… ÛÙˆ Ú¯ÛŒØ§ ÛÛ’Û” Ù†ÛŒØ§ Ú©ÙˆÚˆ Ø­Ø§ØµÙ„ Ú©Ø±ÛŒÚºÛ”',
          romanUrdu:
              'Aap ka password reset session expire ho gaya hai. Please naya code mangwain.',
        );

      case 'The password reset email could not be sent. Please try again later.':
        return _copy(
          english:
              'The verification email could not be sent. Please try again.',
          urdu:
              'ØªØµØ¯ÛŒÙ‚ÛŒ Ø§ÛŒ Ù…ÛŒÙ„ Ù†ÛÛŒÚº Ø¨Ú¾ÛŒØ¬ÛŒ Ø¬Ø§ Ø³Ú©ÛŒÛ” Ø¯ÙˆØ¨Ø§Ø±Û Ú©ÙˆØ´Ø´ Ú©Ø±ÛŒÚºÛ”',
          romanUrdu:
              'Verification email send nahi ho saki. Please dobara try karein.',
        );

      case 'Too many password reset attempts. Please try again later.':
      case 'Too many attempts. Please try again later.':
        return _copy(
          english: 'Too many attempts. Please wait and try again later.',
          urdu:
              'Ø¨ÛØª Ø²ÛŒØ§Ø¯Û Ú©ÙˆØ´Ø´ÛŒÚº ÛÙˆ Ú†Ú©ÛŒ ÛÛŒÚºÛ” Ú©Ú†Ú¾ Ø¯ÛŒØ± Ø¨Ø¹Ø¯ Ø¯ÙˆØ¨Ø§Ø±Û Ú©ÙˆØ´Ø´ Ú©Ø±ÛŒÚºÛ”',
          romanUrdu:
              'Bohat zyada attempts ho gaye hain. Thori dair baad dobara try karein.',
        );

      default:
        if (context.appLanguage == AppLanguage.english) {
          return message;
        }

        return _copy(
          english: 'The request could not be completed.',
          urdu:
              'Ø¯Ø±Ø®ÙˆØ§Ø³Øª Ù…Ú©Ù…Ù„ Ù†ÛÛŒÚº ÛÙˆ Ø³Ú©ÛŒÛ” Ø¯ÙˆØ¨Ø§Ø±Û Ú©ÙˆØ´Ø´ Ú©Ø±ÛŒÚºÛ”',
          romanUrdu: 'Request complete nahi ho saki. Please dobara try karein.',
        );
    }
  }

  void _startCooldown(int seconds) {
    _cooldownTimer?.cancel();

    final safeSeconds = seconds.clamp(0, 300).toInt();

    setState(() {
      _cooldownSeconds = safeSeconds;
    });

    if (safeSeconds <= 0) {
      return;
    }

    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      if (_cooldownSeconds <= 1) {
        timer.cancel();

        setState(() {
          _cooldownSeconds = 0;
        });

        return;
      }

      setState(() {
        _cooldownSeconds -= 1;
      });
    });
  }

  Future<void> _requestCode() async {
    final email = _email.text.trim();

    if (!_validEmail(email)) {
      setState(() {
        _error = _copy(
          english: 'Enter a valid email address.',
          urdu: 'Ø¯Ø±Ø³Øª Ø§ÛŒ Ù…ÛŒÙ„ Ø§ÛŒÚˆØ±ÛŒØ³ Ø¯Ø±Ø¬ Ú©Ø±ÛŒÚºÛ”',
          romanUrdu: 'Valid email address enter karein.',
        );
      });

      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
      _info = null;
    });

    try {
      final result = await AuthSession.instance.requestPasswordReset(
        email: email,
      );

      if (!mounted) return;

      setState(() {
        _step = _PasswordResetStep.code;
        _info = _copy(
          english:
              'If this email belongs to a password account, a 6-digit code has been sent.',
          urdu:
              'Ø§Ú¯Ø± ÛŒÛ Ø§ÛŒ Ù…ÛŒÙ„ Ù¾Ø§Ø³ ÙˆØ±Úˆ Ø§Ú©Ø§Ø¤Ù†Ù¹ Ø³Û’ Ù…Ù†Ø³Ù„Ú© ÛÛ’ ØªÙˆ 6 ÛÙ†Ø¯Ø³ÙˆÚº Ú©Ø§ Ú©ÙˆÚˆ Ø¨Ú¾ÛŒØ¬ Ø¯ÛŒØ§ Ú¯ÛŒØ§ ÛÛ’Û”',
          romanUrdu:
              'Agar yeh email password account se linked hai to 6-digit code send kar diya gaya hai.',
        );
      });

      _startCooldown(result.cooldownSeconds);
    } on AuthException catch (error) {
      if (!mounted) return;

      setState(() {
        _error = _localizedError(error);
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _error = _copy(
          english: 'Could not request a verification code.',
          urdu: 'ØªØµØ¯ÛŒÙ‚ÛŒ Ú©ÙˆÚˆ Ø­Ø§ØµÙ„ Ù†ÛÛŒÚº Ú©ÛŒØ§ Ø¬Ø§ Ø³Ú©Ø§Û”',
          romanUrdu: 'Verification code request nahi ho saka.',
        );
      });
    } finally {
      if (mounted) {
        setState(() {
          _submitting = false;
        });
      }
    }
  }

  Future<void> _verifyCode() async {
    final code = _code.text.trim();

    if (!RegExp(r'^\d{6}$').hasMatch(code)) {
      setState(() {
        _error = _copy(
          english: 'Enter the 6-digit code.',
          urdu: '6 ÛÙ†Ø¯Ø³ÙˆÚº Ú©Ø§ Ú©ÙˆÚˆ Ø¯Ø±Ø¬ Ú©Ø±ÛŒÚºÛ”',
          romanUrdu: '6-digit code enter karein.',
        );
      });

      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
      _info = null;
    });

    try {
      final token = await AuthSession.instance.verifyPasswordResetCode(
        email: _email.text.trim(),
        code: code,
      );

      if (!mounted) return;

      setState(() {
        _resetToken = token;
        _step = _PasswordResetStep.newPassword;
        _info = _copy(
          english: 'Code verified. Now choose a new password.',
          urdu:
              'Ú©ÙˆÚˆ Ú©ÛŒ ØªØµØ¯ÛŒÙ‚ ÛÙˆ Ú¯Ø¦ÛŒÛ” Ø§Ø¨ Ù†ÛŒØ§ Ù¾Ø§Ø³ ÙˆØ±Úˆ Ù…Ù†ØªØ®Ø¨ Ú©Ø±ÛŒÚºÛ”',
          romanUrdu: 'Code verify ho gaya. Ab naya password set karein.',
        );
      });
    } on AuthException catch (error) {
      if (!mounted) return;

      setState(() {
        _error = _localizedError(error);
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _error = _copy(
          english: 'Could not verify the code.',
          urdu: 'Ú©ÙˆÚˆ Ú©ÛŒ ØªØµØ¯ÛŒÙ‚ Ù†ÛÛŒÚº ÛÙˆ Ø³Ú©ÛŒÛ”',
          romanUrdu: 'Code verify nahi ho saka.',
        );
      });
    } finally {
      if (mounted) {
        setState(() {
          _submitting = false;
        });
      }
    }
  }

  Future<void> _resetPassword() async {
    final password = _newPassword.text;

    final confirmation = _confirmPassword.text;

    if (password.length < 8 || password.length > 72) {
      setState(() {
        _error = _copy(
          english: 'Password must contain 8 to 72 characters.',
          urdu:
              'Ù¾Ø§Ø³ ÙˆØ±Úˆ 8 Ø³Û’ 72 Ø­Ø±ÙˆÙ Ù¾Ø± Ù…Ø´ØªÙ…Ù„ ÛÙˆÙ†Ø§ Ú†Ø§ÛÛŒÛ’Û”',
          romanUrdu: 'Password 8 se 72 characters ka hona chahiye.',
        );
      });

      return;
    }

    if (password != confirmation) {
      setState(() {
        _error = _copy(
          english: 'Passwords do not match.',
          urdu: 'Ø¯ÙˆÙ†ÙˆÚº Ù¾Ø§Ø³ ÙˆØ±Úˆ Ø§ÛŒÚ© Ø¬ÛŒØ³Û’ Ù†ÛÛŒÚº ÛÛŒÚºÛ”',
          romanUrdu: 'Dono passwords match nahi karte.',
        );
      });

      return;
    }

    final token = _resetToken;

    if (token == null || token.isEmpty) {
      setState(() {
        _error = _copy(
          english: 'Your reset session has expired. Request a new code.',
          urdu:
              'Ø±ÛŒ Ø³ÛŒÙ¹ Ø³ÛŒØ´Ù† Ø®ØªÙ… ÛÙˆ Ú¯ÛŒØ§ ÛÛ’Û” Ù†ÛŒØ§ Ú©ÙˆÚˆ Ø­Ø§ØµÙ„ Ú©Ø±ÛŒÚºÛ”',
          romanUrdu: 'Reset session expire ho gaya hai. Naya code mangwain.',
        );
      });

      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
      _info = null;
    });

    try {
      await AuthSession.instance.resetPassword(
        email: _email.text.trim(),
        resetToken: token,
        newPassword: password,
      );

      if (!mounted) return;

      _cooldownTimer?.cancel();

      setState(() {
        _resetToken = null;
        _step = _PasswordResetStep.done;
        _info = null;
      });
    } on AuthException catch (error) {
      if (!mounted) return;

      setState(() {
        _error = _localizedError(error);
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _error = _copy(
          english: 'The password could not be changed.',
          urdu: 'Ù¾Ø§Ø³ ÙˆØ±Úˆ ØªØ¨Ø¯ÛŒÙ„ Ù†ÛÛŒÚº Ú©ÛŒØ§ Ø¬Ø§ Ø³Ú©Ø§Û”',
          romanUrdu: 'Password change nahi ho saka.',
        );
      });
    } finally {
      if (mounted) {
        setState(() {
          _submitting = false;
        });
      }
    }
  }

  String get _title {
    return switch (_step) {
      _PasswordResetStep.email => _copy(
        english: 'Forgot password',
        urdu: 'Ù¾Ø§Ø³ ÙˆØ±Úˆ Ø¨Ú¾ÙˆÙ„ Ú¯Ø¦Û’ØŸ',
        romanUrdu: 'Forgot Password',
      ),
      _PasswordResetStep.code => _copy(
        english: 'Enter verification code',
        urdu: 'ØªØµØ¯ÛŒÙ‚ÛŒ Ú©ÙˆÚˆ Ø¯Ø±Ø¬ Ú©Ø±ÛŒÚº',
        romanUrdu: 'Verification Code Enter Karein',
      ),
      _PasswordResetStep.newPassword => _copy(
        english: 'Choose a new password',
        urdu: 'Ù†ÛŒØ§ Ù¾Ø§Ø³ ÙˆØ±Úˆ Ù…Ù†ØªØ®Ø¨ Ú©Ø±ÛŒÚº',
        romanUrdu: 'Naya Password Set Karein',
      ),
      _PasswordResetStep.done => _copy(
        english: 'Password changed',
        urdu: 'Ù¾Ø§Ø³ ÙˆØ±Úˆ ØªØ¨Ø¯ÛŒÙ„ ÛÙˆ Ú¯ÛŒØ§',
        romanUrdu: 'Password Change Ho Gaya',
      ),
    };
  }

  String get _description {
    return switch (_step) {
      _PasswordResetStep.email => _copy(
        english: 'Enter the email you use to sign in.',
        urdu:
            'ÙˆÛ Ø§ÛŒ Ù…ÛŒÙ„ Ø¯Ø±Ø¬ Ú©Ø±ÛŒÚº Ø¬Ø³ Ø³Û’ Ø¢Ù¾ Ø³Ø§Ø¦Ù† Ø§ÙÙ† Ú©Ø±ØªÛ’ ÛÛŒÚºÛ”',
        romanUrdu: 'Woh email enter karein jis se aap sign in karte hain.',
      ),
      _PasswordResetStep.code => _copy(
        english: 'Enter the 6-digit code sent to your email.',
        urdu:
            'Ø§Ù¾Ù†ÛŒ Ø§ÛŒ Ù…ÛŒÙ„ Ù¾Ø± Ø¨Ú¾ÛŒØ¬Ø§ Ú¯ÛŒØ§ 6 ÛÙ†Ø¯Ø³ÙˆÚº Ú©Ø§ Ú©ÙˆÚˆ Ø¯Ø±Ø¬ Ú©Ø±ÛŒÚºÛ”',
        romanUrdu: 'Email par bheja gaya 6-digit code enter karein.',
      ),
      _PasswordResetStep.newPassword => _copy(
        english: 'Your new password must contain at least 8 characters.',
        urdu:
            'Ù†ÛŒØ§ Ù¾Ø§Ø³ ÙˆØ±Úˆ Ú©Ù… Ø§Ø² Ú©Ù… 8 Ø­Ø±ÙˆÙ Ú©Ø§ ÛÙˆÙ†Ø§ Ú†Ø§ÛÛŒÛ’Û”',
        romanUrdu: 'Naya password kam az kam 8 characters ka hona chahiye.',
      ),
      _PasswordResetStep.done => _copy(
        english: 'Your password has been updated successfully.',
        urdu:
            'Ø¢Ù¾ Ú©Ø§ Ù¾Ø§Ø³ ÙˆØ±Úˆ Ú©Ø§Ù…ÛŒØ§Ø¨ÛŒ Ø³Û’ ØªØ¨Ø¯ÛŒÙ„ ÛÙˆ Ú¯ÛŒØ§ ÛÛ’Û”',
        romanUrdu: 'Aap ka password successfully update ho gaya hai.',
      ),
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(
                    height: 64,
                    child: Row(
                      children: [
                        IconButton(
                          tooltip: MaterialLocalizations.of(
                            context,
                          ).backButtonTooltip,
                          onPressed: _submitting
                              ? null
                              : () => Navigator.pop(context),
                          icon: const Icon(Icons.arrow_back),
                        ),
                        const SizedBox(width: 8),
                        const BrandLogo(),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  AppCard(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          _title,
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _description,
                          style: const TextStyle(
                            fontSize: 14,
                            height: 1.5,
                            color: AppColors.muted,
                          ),
                        ),
                        const SizedBox(height: 24),
                        _buildStep(),
                        if (_info != null) ...[
                          const SizedBox(height: 16),
                          _MessageBox(message: _info!, isError: false),
                        ],
                        if (_error != null) ...[
                          const SizedBox(height: 16),
                          _MessageBox(message: _error!, isError: true),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStep() {
    switch (_step) {
      case _PasswordResetStep.email:
        return _emailStep();

      case _PasswordResetStep.code:
        return _codeStep();

      case _PasswordResetStep.newPassword:
        return _newPasswordStep();

      case _PasswordResetStep.done:
        return _doneStep();
    }
  }

  Widget _emailStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          context.tr('email'),
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: _email,
          enabled: !_submitting,
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.done,
          autofillHints: const [AutofillHints.email],
          onSubmitted: (_) {
            if (!_submitting) {
              _requestCode();
            }
          },
          decoration: const InputDecoration(hintText: 'you@example.com'),
        ),
        const SizedBox(height: 20),
        FilledButton(
          onPressed: _submitting ? null : _requestCode,
          child: _submitting
              ? const _ResetLoader()
              : Text(
                  _copy(
                    english: 'Send code',
                    urdu: 'Ú©ÙˆÚˆ Ø¨Ú¾ÛŒØ¬ÛŒÚº',
                    romanUrdu: 'Code Send Karein',
                  ),
                ),
        ),
      ],
    );
  }

  Widget _codeStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          _email.text.trim(),
          style: const TextStyle(fontSize: 14, color: AppColors.muted),
        ),
        const SizedBox(height: 16),
        Text(
          _copy(
            english: '6-digit verification code',
            urdu: '6 ÛÙ†Ø¯Ø³ÙˆÚº Ú©Ø§ ØªØµØ¯ÛŒÙ‚ÛŒ Ú©ÙˆÚˆ',
            romanUrdu: '6-digit Verification Code',
          ),
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: _code,
          enabled: !_submitting,
          keyboardType: TextInputType.number,
          textInputAction: TextInputAction.done,
          maxLength: 6,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(6),
          ],
          onSubmitted: (_) {
            if (!_submitting) {
              _verifyCode();
            }
          },
          decoration: const InputDecoration(
            hintText: '000000',
            counterText: '',
          ),
        ),
        const SizedBox(height: 20),
        FilledButton(
          onPressed: _submitting ? null : _verifyCode,
          child: _submitting
              ? const _ResetLoader()
              : Text(
                  _copy(
                    english: 'Verify code',
                    urdu: 'Ú©ÙˆÚˆ Ú©ÛŒ ØªØµØ¯ÛŒÙ‚ Ú©Ø±ÛŒÚº',
                    romanUrdu: 'Code Verify Karein',
                  ),
                ),
        ),
        const SizedBox(height: 8),
        TextButton(
          onPressed: _submitting || _cooldownSeconds > 0 ? null : _requestCode,
          child: Text(
            _cooldownSeconds > 0
                ? _copy(
                    english: 'Resend in $_cooldownSeconds seconds',
                    urdu:
                        '$_cooldownSeconds Ø³ÛŒÚ©Ù†Úˆ Ø¨Ø¹Ø¯ Ø¯ÙˆØ¨Ø§Ø±Û Ø¨Ú¾ÛŒØ¬ÛŒÚº',
                    romanUrdu: '$_cooldownSeconds seconds baad resend karein',
                  )
                : _copy(
                    english: 'Resend code',
                    urdu: 'Ú©ÙˆÚˆ Ø¯ÙˆØ¨Ø§Ø±Û Ø¨Ú¾ÛŒØ¬ÛŒÚº',
                    romanUrdu: 'Code Dobara Send Karein',
                  ),
          ),
        ),
      ],
    );
  }

  Widget _newPasswordStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          _copy(
            english: 'New password',
            urdu: 'Ù†ÛŒØ§ Ù¾Ø§Ø³ ÙˆØ±Úˆ',
            romanUrdu: 'Naya Password',
          ),
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: _newPassword,
          enabled: !_submitting,
          obscureText: _hideNewPassword,
          autofillHints: const [AutofillHints.newPassword],
          textInputAction: TextInputAction.next,
          decoration: InputDecoration(
            hintText: _copy(
              english: 'At least 8 characters',
              urdu: 'Ú©Ù… Ø§Ø² Ú©Ù… 8 Ø­Ø±ÙˆÙ',
              romanUrdu: 'Kam az kam 8 characters',
            ),
            suffixIcon: IconButton(
              onPressed: _submitting
                  ? null
                  : () {
                      setState(() {
                        _hideNewPassword = !_hideNewPassword;
                      });
                    },
              icon: Icon(
                _hideNewPassword
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined,
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          _copy(
            english: 'Confirm new password',
            urdu: 'Ù†Ø¦Û’ Ù¾Ø§Ø³ ÙˆØ±Úˆ Ú©ÛŒ ØªØµØ¯ÛŒÙ‚ Ú©Ø±ÛŒÚº',
            romanUrdu: 'Naya Password Confirm Karein',
          ),
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: _confirmPassword,
          enabled: !_submitting,
          obscureText: _hideConfirmPassword,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) {
            if (!_submitting) {
              _resetPassword();
            }
          },
          decoration: InputDecoration(
            hintText: _copy(
              english: 'Enter it again',
              urdu: 'Ø¯ÙˆØ¨Ø§Ø±Û Ø¯Ø±Ø¬ Ú©Ø±ÛŒÚº',
              romanUrdu: 'Dobara enter karein',
            ),
            suffixIcon: IconButton(
              onPressed: _submitting
                  ? null
                  : () {
                      setState(() {
                        _hideConfirmPassword = !_hideConfirmPassword;
                      });
                    },
              icon: Icon(
                _hideConfirmPassword
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined,
              ),
            ),
          ),
        ),
        const SizedBox(height: 20),
        FilledButton(
          onPressed: _submitting ? null : _resetPassword,
          child: _submitting
              ? const _ResetLoader()
              : Text(
                  _copy(
                    english: 'Reset password',
                    urdu: 'Ù¾Ø§Ø³ ÙˆØ±Úˆ Ø±ÛŒ Ø³ÛŒÙ¹ Ú©Ø±ÛŒÚº',
                    romanUrdu: 'Password Reset Karein',
                  ),
                ),
        ),
      ],
    );
  }

  Widget _doneStep() {
    return Column(
      children: [
        Container(
          width: 64,
          height: 64,
          decoration: const BoxDecoration(
            color: AppColors.primaryLight,
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: const Icon(
            Icons.check_rounded,
            size: 34,
            color: AppColors.primary,
          ),
        ),
        const SizedBox(height: 20),
        Text(
          _copy(
            english: 'You can now sign in using your new password.',
            urdu:
                'Ø§Ø¨ Ø¢Ù¾ Ø§Ù¾Ù†Û’ Ù†Ø¦Û’ Ù¾Ø§Ø³ ÙˆØ±Úˆ Ø³Û’ Ø³Ø§Ø¦Ù† Ø§ÙÙ† Ú©Ø± Ø³Ú©ØªÛ’ ÛÛŒÚºÛ”',
            romanUrdu: 'Ab aap apne naye password se sign in kar sakhte hain.',
          ),
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 15, height: 1.5),
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              _copy(
                english: 'Back to sign in',
                urdu: 'Ø³Ø§Ø¦Ù† Ø§ÙÙ† Ù¾Ø± ÙˆØ§Ù¾Ø³ Ø¬Ø§Ø¦ÛŒÚº',
                romanUrdu: 'Sign In Par Wapas Jain',
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ResetLoader extends StatelessWidget {
  const _ResetLoader();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      width: 18,
      height: 18,
      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
    );
  }
}

class _MessageBox extends StatelessWidget {
  const _MessageBox({required this.message, required this.isError});

  final String message;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: isError ? AppColors.criticalSoft : AppColors.primaryLight,
        borderRadius: BorderRadius.circular(AppRadii.md),
        border: Border.all(
          color: isError
              ? AppColors.critical.withValues(alpha: .25)
              : AppColors.primary.withValues(alpha: .18),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            isError ? Icons.error_outline : Icons.info_outline,
            size: 18,
            color: isError ? AppColors.critical : AppColors.primary,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                fontSize: 13,
                height: 1.4,
                color: isError
                    ? AppColors.criticalForeground
                    : AppColors.foreground,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
