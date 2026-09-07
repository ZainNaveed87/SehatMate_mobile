import 'package:flutter/material.dart';

import '../core/app_routes.dart';
import '../core/app_theme.dart';
import '../localization/app_language.dart';
import '../localization/language_controller.dart';
import '../localization/language_scope.dart';
import '../services/auth_service.dart';
import 'forgot_password_screen.dart';
import '../widgets/brand_logo.dart';
import '../widgets/ui.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;

  final _email = TextEditingController();
  final _password = TextEditingController();
  final _newName = TextEditingController();
  final _newEmail = TextEditingController();
  final _newPassword = TextEditingController();

  bool _submitting = false;
  bool _hideSignInPassword = true;
  bool _hideSignUpPassword = true;

  String? _error;

  @override
  void initState() {
    super.initState();

    _tabs = TabController(length: 2, vsync: this)..addListener(_clearTabError);
  }

  void _clearTabError() {
    if (!_tabs.indexIsChanging || _error == null) {
      return;
    }

    setState(() {
      _error = null;
    });
  }

  @override
  void dispose() {
    _tabs
      ..removeListener(_clearTabError)
      ..dispose();

    _email.dispose();
    _password.dispose();
    _newName.dispose();
    _newEmail.dispose();
    _newPassword.dispose();

    super.dispose();
  }

  bool _validEmail(String value) {
    return RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(value.trim());
  }

  String _googleAccountSignInMessage() {
    return switch (context.appLanguage) {
      AppLanguage.english =>
        'This account uses Google Sign-In. Please continue with Google.',
      AppLanguage.urdu =>
        'یہ اکاؤنٹ گوگل سائن اِن سے بنایا گیا ہے۔ براہِ کرم گوگل کے ذریعے سائن اِن کریں۔',
      AppLanguage.romanUrdu =>
        'Yeh account Google Sign-In se bana hai. Please Google se sign in karein.',
    };
  }

  String _passwordAccountSignInMessage() {
    return switch (context.appLanguage) {
      AppLanguage.english =>
        'This account uses email and password. Please sign in using your password.',
      AppLanguage.urdu =>
        'یہ اکاؤنٹ ای میل اور پاس ورڈ سے بنایا گیا ہے۔ براہِ کرم اپنے پاس ورڈ سے سائن اِن کریں۔',
      AppLanguage.romanUrdu =>
        'Yeh account email aur password se bana hai. Please password se sign in karein.',
    };
  }

  String _localizedAuthError(AuthException error) {
    final message = error.message.trim();

    switch (message) {
      case 'Incorrect email or password.':
        return context.tr('auth_incorrect_credentials');

      case 'An account with this email already exists.':
        return context.tr('auth_account_exists');

      case 'This account uses Google Sign-In. Please continue with Google.':
      case 'An account with this email already exists and uses Google Sign-In. Please continue with Google.':
        return _googleAccountSignInMessage();

      case 'This account uses email and password. Please sign in using your password.':
      case 'An account with this email already exists. Please sign in using your password.':
        return _passwordAccountSignInMessage();

      case 'Google Sign-In failed. Please try again.':
        return context.tr('google_sign_in_failed');

      default:
        if (context.appLanguage == AppLanguage.english) {
          return message;
        }

        return context.tr('auth_request_failed');
    }
  }

  Future<void> _signInUser() async {
    final email = _email.text.trim();

    if (!_validEmail(email)) {
      setState(() {
        _error = context.tr('enter_valid_email');
      });
      return;
    }

    if (_password.text.isEmpty) {
      setState(() {
        _error = context.tr('enter_password');
      });
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      await AuthSession.instance.login(email: email, password: _password.text);

      if (!mounted) {
        return;
      }

      if (!AuthSession.instance.needsOnboarding) {
        await LanguageController.instance.reconcileWithServerProfile();
      }
      if (!mounted) {
        return;
      }

      final destination = AuthSession.instance.needsOnboarding
          ? AppRoutes.onboarding
          : AppRoutes.dashboard;
      Navigator.pushNamedAndRemoveUntil(context, destination, (_) => false);
    } on AuthException catch (error) {
      if (mounted) {
        setState(() {
          _error = _localizedAuthError(error);
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _error = context.tr('sign_in_failed');
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _submitting = false;
        });
      }
    }
  }

  Future<void> _registerUser() async {
    final name = _newName.text.trim();
    final email = _newEmail.text.trim();

    if (name.length < 2) {
      setState(() {
        _error = context.tr('enter_full_name');
      });
      return;
    }

    if (!_validEmail(email)) {
      setState(() {
        _error = context.tr('enter_valid_email');
      });
      return;
    }

    if (_newPassword.text.length < 8) {
      setState(() {
        _error = context.tr('password_min_8_error');
      });
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      await AuthSession.instance.register(
        name: name,
        email: email,
        password: _newPassword.text,
      );

      if (!mounted) {
        return;
      }

      Navigator.pushNamedAndRemoveUntil(
        context,
        AppRoutes.onboarding,
        (_) => false,
      );
    } on AuthException catch (error) {
      if (mounted) {
        setState(() {
          _error = _localizedAuthError(error);
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _error = context.tr('account_creation_failed');
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _submitting = false;
        });
      }
    }
  }

  Future<void> _continueWithGoogle() async {
    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      await AuthSession.instance.loginWithGoogle();

      if (!mounted) {
        return;
      }

      if (!AuthSession.instance.needsOnboarding) {
        await LanguageController.instance.reconcileWithServerProfile();
      }
      if (!mounted) {
        return;
      }

      final destination = AuthSession.instance.needsOnboarding
          ? AppRoutes.onboarding
          : AppRoutes.dashboard;

      Navigator.pushNamedAndRemoveUntil(context, destination, (_) => false);
    } on AuthException catch (error) {
      if (mounted) {
        setState(() {
          _error = _localizedAuthError(error);
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _error = context.tr('google_sign_in_failed');
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _submitting = false;
        });
      }
    }
  }

  Future<void> _continueAsGuest() async {
    await AuthSession.instance.startGuestSession();

    if (!mounted) {
      return;
    }

    Navigator.pushNamedAndRemoveUntil(
      context,
      AppRoutes.dashboard,
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F9F8),
      body: SafeArea(
        child: Stack(
          children: [
            const PositionedDirectional(
              top: -90,
              start: -70,
              child: _AuthGlow(size: 220, color: Color(0x1F14B8A6)),
            ),
            const PositionedDirectional(
              bottom: -120,
              end: -80,
              child: _AuthGlow(size: 280, color: Color(0x182563EB)),
            ),
            SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 36),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1120),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _authTopBar(),
                      const SizedBox(height: 24),
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final narrow = constraints.maxWidth < 780;

                          if (narrow) {
                            return Column(
                              children: [
                                const FadeSlideIn(
                                  child: _AuthExplainer(compact: true),
                                ),
                                const SizedBox(height: 18),
                                FadeSlideIn(
                                  delay: const Duration(milliseconds: 70),
                                  child: _authFormCard(),
                                ),
                              ],
                            );
                          }

                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              const Expanded(
                                flex: 11,
                                child: FadeSlideIn(child: _AuthExplainer()),
                              ),
                              const SizedBox(width: 44),
                              Expanded(
                                flex: 10,
                                child: FadeSlideIn(
                                  delay: const Duration(milliseconds: 80),
                                  child: _authFormCard(),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _authTopBar() {
    return SizedBox(
      height: 72,
      child: Row(
        children: [
          Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(AppRadii.lg),
              onTap: () {
                Navigator.pushReplacementNamed(context, AppRoutes.landing);
              },
              child: const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: BrandLogo(),
              ),
            ),
          ),
          const Spacer(),
          TextButton.icon(
            onPressed: () {
              Navigator.pushReplacementNamed(context, AppRoutes.landing);
            },
            icon: const Icon(Icons.arrow_back_rounded, size: 17),
            label: Text(context.tr('back_to_home')),
          ),
        ],
      ),
    );
  }

  Widget _authFormCard() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadii.xxxl),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1A0F172A),
            blurRadius: 34,
            spreadRadius: -12,
            offset: Offset(0, 18),
          ),
        ],
      ),
      child: AppCard(
        radius: AppRadii.xxxl,
        padding: const EdgeInsets.all(22),
        borderColor: const Color(0xFFDDE7E5),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AnimatedBuilder(
              animation: _tabs,
              builder: (context, _) {
                final signingIn = _tabs.index == 0;
                return AnimatedSwitcher(
                  duration: const Duration(milliseconds: 220),
                  child: Column(
                    key: ValueKey(signingIn),
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF0F766E), Color(0xFF14B8A6)],
                          ),
                          borderRadius: BorderRadius.circular(AppRadii.xl),
                        ),
                        child: Icon(
                          signingIn
                              ? Icons.lock_open_rounded
                              : Icons.person_add_alt_1_rounded,
                          color: Colors.white,
                          size: 22,
                        ),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        context.tr(signingIn ? 'sign_in' : 'sign_up'),
                        style: const TextStyle(
                          fontSize: 25,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -.35,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        context.tr('auth_explainer_title'),
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.muted,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: const Color(0xFFF0F5F4),
                borderRadius: BorderRadius.circular(AppRadii.xl),
              ),
              child: TabBar(
                controller: _tabs,
                dividerHeight: 0,
                indicatorSize: TabBarIndicatorSize.tab,
                labelColor: Colors.white,
                unselectedLabelColor: AppColors.muted,
                labelStyle: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
                unselectedLabelStyle: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
                indicator: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF0F766E), Color(0xFF0D9488)],
                  ),
                  borderRadius: BorderRadius.circular(AppRadii.lg),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x240F766E),
                      blurRadius: 12,
                      spreadRadius: -5,
                      offset: Offset(0, 5),
                    ),
                  ],
                ),
                tabs: [
                  Tab(text: context.tr('sign_in')),
                  Tab(text: context.tr('sign_up')),
                ],
              ),
            ),
            SizedBox(
              height: 500,
              child: TabBarView(
                controller: _tabs,
                physics: _submitting
                    ? const NeverScrollableScrollPhysics()
                    : const BouncingScrollPhysics(),
                children: [_signIn(), _signUp()],
              ),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                const Expanded(child: Divider()),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Icon(
                    Icons.shield_outlined,
                    size: 15,
                    color: AppColors.subtle,
                  ),
                ),
                const Expanded(child: Divider()),
              ],
            ),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: _submitting ? null : _continueAsGuest,
              icon: const Icon(Icons.person_outline_rounded, size: 17),
              label: SizedBox(
                width: double.infinity,
                child: Text(
                  context.tr('continue_as_guest'),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _authDecoration({
    required String hintText,
    required IconData icon,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      hintText: hintText,
      prefixIcon: Icon(icon, size: 19, color: AppColors.muted),
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: const Color(0xFFF8FBFA),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadii.lg),
        borderSide: const BorderSide(color: Color(0xFFDDE7E5)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadii.lg),
        borderSide: const BorderSide(color: AppColors.primary, width: 1.7),
      ),
      disabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadii.lg),
        borderSide: const BorderSide(color: AppColors.border),
      ),
    );
  }

  Widget _fieldTitle(String value) {
    return Text(
      value,
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w700,
        color: AppColors.foreground,
      ),
    );
  }

  Widget _signIn() {
    return SingleChildScrollView(
      padding: const EdgeInsets.only(top: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
              backgroundColor: Colors.white,
              side: const BorderSide(color: Color(0xFFDDE7E5)),
            ),
            onPressed: _submitting ? null : _continueWithGoogle,
            icon: Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(999),
              ),
              alignment: Alignment.center,
              child: const Text(
                'G',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: AppColors.info,
                ),
              ),
            ),
            label: _submitting
                ? const _ButtonLoader(color: AppColors.primary)
                : Text(context.tr('continue_with_google')),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              const Expanded(child: Divider()),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text(
                  context.tr('or'),
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.muted,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const Expanded(child: Divider()),
            ],
          ),
          const SizedBox(height: 18),
          _fieldTitle(context.tr('email')),
          const SizedBox(height: 7),
          TextField(
            controller: _email,
            enabled: !_submitting,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            autofillHints: const [AutofillHints.email],
            decoration: _authDecoration(
              hintText: 'you@example.com',
              icon: Icons.mail_outline_rounded,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _fieldTitle(context.tr('password')),
              const Spacer(),
              InkWell(
                borderRadius: BorderRadius.circular(AppRadii.sm),
                onTap: _submitting
                    ? null
                    : () async {
                        final enteredEmail = _email.text.trim();

                        await Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => ForgotPasswordScreen(
                              initialEmail: _validEmail(enteredEmail)
                                  ? enteredEmail
                                  : null,
                            ),
                          ),
                        );
                      },
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 3,
                  ),
                  child: Text(
                    context.tr('forgot_password'),
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 7),
          TextField(
            controller: _password,
            enabled: !_submitting,
            obscureText: _hideSignInPassword,
            textInputAction: TextInputAction.done,
            autofillHints: const [AutofillHints.password],
            onSubmitted: (_) {
              if (!_submitting) {
                _signInUser();
              }
            },
            decoration: _authDecoration(
              hintText: context.tr('your_password'),
              icon: Icons.lock_outline_rounded,
              suffixIcon: IconButton(
                onPressed: _submitting
                    ? null
                    : () {
                        setState(() {
                          _hideSignInPassword = !_hideSignInPassword;
                        });
                      },
                icon: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 180),
                  child: Icon(
                    _hideSignInPassword
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                    key: ValueKey(_hideSignInPassword),
                    size: 19,
                  ),
                ),
              ),
            ),
          ),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            child: _error == null
                ? const SizedBox.shrink()
                : Padding(
                    key: ValueKey(_error),
                    padding: const EdgeInsets.only(top: 12),
                    child: _AuthError(message: _error!),
                  ),
          ),
          const SizedBox(height: 18),
          FilledButton(
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(50),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadii.lg),
              ),
            ),
            onPressed: _submitting ? null : _signInUser,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 180),
              child: _submitting
                  ? const _ButtonLoader(key: ValueKey('sign-in-loading'))
                  : Row(
                      key: const ValueKey('sign-in-ready'),
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(context.tr('sign_in')),
                        const SizedBox(width: 8),
                        const Icon(Icons.arrow_forward_rounded, size: 18),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _signUp() {
    return SingleChildScrollView(
      padding: const EdgeInsets.only(top: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
              backgroundColor: Colors.white,
              side: const BorderSide(color: Color(0xFFDDE7E5)),
            ),
            onPressed: _submitting ? null : _continueWithGoogle,
            icon: Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(999),
              ),
              alignment: Alignment.center,
              child: const Text(
                'G',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: AppColors.info,
                ),
              ),
            ),
            label: _submitting
                ? const _ButtonLoader(color: AppColors.primary)
                : Text(context.tr('continue_with_google')),
          ),
          const SizedBox(height: 18),
          _fieldTitle(context.tr('full_name')),
          const SizedBox(height: 7),
          TextField(
            controller: _newName,
            enabled: !_submitting,
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.next,
            autofillHints: const [AutofillHints.name],
            decoration: _authDecoration(
              hintText: context.tr('your_full_name'),
              icon: Icons.person_outline_rounded,
            ),
          ),
          const SizedBox(height: 13),
          _fieldTitle(context.tr('email')),
          const SizedBox(height: 7),
          TextField(
            controller: _newEmail,
            enabled: !_submitting,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            autofillHints: const [AutofillHints.newUsername],
            decoration: _authDecoration(
              hintText: 'you@example.com',
              icon: Icons.mail_outline_rounded,
            ),
          ),
          const SizedBox(height: 13),
          _fieldTitle(context.tr('password')),
          const SizedBox(height: 7),
          TextField(
            controller: _newPassword,
            enabled: !_submitting,
            obscureText: _hideSignUpPassword,
            textInputAction: TextInputAction.done,
            autofillHints: const [AutofillHints.newPassword],
            onSubmitted: (_) {
              if (!_submitting) {
                _registerUser();
              }
            },
            decoration: _authDecoration(
              hintText: context.tr('password_min_8_hint'),
              icon: Icons.lock_outline_rounded,
              suffixIcon: IconButton(
                onPressed: _submitting
                    ? null
                    : () {
                        setState(() {
                          _hideSignUpPassword = !_hideSignUpPassword;
                        });
                      },
                icon: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 180),
                  child: Icon(
                    _hideSignUpPassword
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                    key: ValueKey(_hideSignUpPassword),
                    size: 19,
                  ),
                ),
              ),
            ),
          ),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            child: _error == null
                ? const SizedBox.shrink()
                : Padding(
                    key: ValueKey(_error),
                    padding: const EdgeInsets.only(top: 12),
                    child: _AuthError(message: _error!),
                  ),
          ),
          const SizedBox(height: 18),
          FilledButton(
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(50),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadii.lg),
              ),
            ),
            onPressed: _submitting ? null : _registerUser,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 180),
              child: _submitting
                  ? const _ButtonLoader(key: ValueKey('sign-up-loading'))
                  : Row(
                      key: const ValueKey('sign-up-ready'),
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(context.tr('create_account')),
                        const SizedBox(width: 8),
                        const Icon(Icons.arrow_forward_rounded, size: 18),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ButtonLoader extends StatelessWidget {
  const _ButtonLoader({super.key, this.color = Colors.white});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 18,
      height: 18,
      child: CircularProgressIndicator(strokeWidth: 2, color: color),
    );
  }
}

class _AuthError extends StatelessWidget {
  const _AuthError({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
      decoration: BoxDecoration(
        color: AppColors.criticalSoft,
        borderRadius: BorderRadius.circular(AppRadii.lg),
        border: Border.all(color: AppColors.critical.withValues(alpha: .22)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: .72),
              borderRadius: BorderRadius.circular(AppRadii.sm),
            ),
            child: const Icon(
              Icons.error_outline_rounded,
              size: 17,
              color: AppColors.critical,
            ),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                message,
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.criticalForeground,
                  height: 1.35,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AuthExplainer extends StatelessWidget {
  const _AuthExplainer({this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(compact ? 20 : 30),
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
            blurRadius: 34,
            spreadRadius: -12,
            offset: Offset(0, 18),
          ),
        ],
      ),
      child: Stack(
        children: [
          PositionedDirectional(
            top: -70,
            end: -55,
            child: Container(
              width: compact ? 130 : 190,
              height: compact ? 130 : 190,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Color(0x18FFFFFF),
              ),
            ),
          ),
          PositionedDirectional(
            bottom: -80,
            start: -60,
            child: Container(
              width: 180,
              height: 180,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Color(0x0FFFFFFF),
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: compact ? 44 : 54,
                height: compact ? 44 : 54,
                decoration: BoxDecoration(
                  color: const Color(0x22FFFFFF),
                  borderRadius: BorderRadius.circular(AppRadii.xl),
                  border: Border.all(color: const Color(0x36FFFFFF)),
                ),
                child: const Icon(
                  Icons.verified_user_outlined,
                  color: Colors.white,
                  size: 25,
                ),
              ),
              SizedBox(height: compact ? 15 : 22),
              Text(
                context.tr('auth_explainer_title'),
                style: TextStyle(
                  color: Colors.white,
                  fontSize: compact ? 21 : 30,
                  height: 1.12,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -.45,
                ),
              ),
              SizedBox(height: compact ? 14 : 22),
              if (compact)
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _ExplainerChip(
                      icon: Icons.fact_check_outlined,
                      text: context.tr('auth_verified_instructions'),
                    ),
                    _ExplainerChip(
                      icon: Icons.auto_graph_outlined,
                      text: context.tr('auth_7_day_simulation'),
                    ),
                    _ExplainerChip(
                      icon: Icons.family_restroom_outlined,
                      text: context.tr('auth_family_access'),
                    ),
                  ],
                )
              else ...[
                _ExplainerItem(
                  icon: Icons.fact_check_outlined,
                  text: context.tr('auth_verified_instructions'),
                ),
                const SizedBox(height: 14),
                _ExplainerItem(
                  icon: Icons.auto_graph_outlined,
                  text: context.tr('auth_7_day_simulation'),
                ),
                const SizedBox(height: 14),
                _ExplainerItem(
                  icon: Icons.family_restroom_outlined,
                  text: context.tr('auth_family_access'),
                ),
                const SizedBox(height: 28),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0x17FFFFFF),
                    borderRadius: BorderRadius.circular(AppRadii.xl),
                    border: Border.all(color: const Color(0x24FFFFFF)),
                  ),
                  child: const Row(
                    children: [
                      Icon(
                        Icons.shield_outlined,
                        color: Colors.white,
                        size: 18,
                      ),
                      SizedBox(width: 9),
                      Expanded(
                        child: Text(
                          'Verified care intelligence, with patient control.',
                          style: TextStyle(
                            color: Color(0xE8FFFFFF),
                            fontSize: 12,
                            height: 1.35,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _ExplainerItem extends StatelessWidget {
  const _ExplainerItem({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: const Color(0x1FFFFFFF),
            borderRadius: BorderRadius.circular(AppRadii.lg),
          ),
          child: Icon(icon, size: 17, color: Colors.white),
        ),
        const SizedBox(width: 11),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 7),
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 14,
                color: Color(0xE8FFFFFF),
                height: 1.4,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ExplainerChip extends StatelessWidget {
  const _ExplainerChip({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 260),
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
      decoration: BoxDecoration(
        color: const Color(0x18FFFFFF),
        borderRadius: BorderRadius.circular(AppRadii.lg),
        border: Border.all(color: const Color(0x25FFFFFF)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: Colors.white),
          const SizedBox(width: 7),
          Flexible(
            child: Text(
              text,
              style: const TextStyle(
                color: Color(0xE8FFFFFF),
                fontSize: 12,
                height: 1.25,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AuthGlow extends StatelessWidget {
  const _AuthGlow({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(shape: BoxShape.circle, color: color),
      ),
    );
  }
}
