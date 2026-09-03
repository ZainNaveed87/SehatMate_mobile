import 'package:flutter/material.dart';

import '../core/app_routes.dart';
import '../core/app_theme.dart';
import '../localization/app_language.dart';
import '../localization/language_controller.dart';
import '../localization/language_scope.dart';
import '../services/auth_service.dart';
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

  String _localizedAuthError(AuthException error) {
    final message = error.message.trim();

    switch (message) {
      case 'Incorrect email or password.':
        return context.tr('auth_incorrect_credentials');

      case 'An account with this email already exists.':
        return context.tr('auth_account_exists');

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
      body: SafeArea(
        child: SingleChildScrollView(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1120),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  children: [
                    SizedBox(
                      height: 72,
                      child: Row(
                        children: [
                          InkWell(
                            onTap: () {
                              Navigator.pushReplacementNamed(
                                context,
                                AppRoutes.landing,
                              );
                            },
                            child: const BrandLogo(),
                          ),
                          const Spacer(),
                          TextButton(
                            onPressed: () {
                              Navigator.pushReplacementNamed(
                                context,
                                AppRoutes.landing,
                              );
                            },
                            child: Text(context.tr('back_to_home')),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(top: 24, bottom: 64),
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final narrow = constraints.maxWidth < 760;

                          final form = ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 420),
                            child: AppCard(
                              padding: const EdgeInsets.all(24),
                              child: Column(
                                children: [
                                  Container(
                                    decoration: BoxDecoration(
                                      color: AppColors.secondary,
                                      borderRadius: BorderRadius.circular(
                                        AppRadii.lg,
                                      ),
                                    ),
                                    child: TabBar(
                                      controller: _tabs,
                                      dividerHeight: 0,
                                      indicatorSize: TabBarIndicatorSize.tab,
                                      indicator: BoxDecoration(
                                        color: AppColors.card,
                                        borderRadius: BorderRadius.circular(
                                          AppRadii.md,
                                        ),
                                      ),
                                      tabs: [
                                        Tab(text: context.tr('sign_in')),
                                        Tab(text: context.tr('sign_up')),
                                      ],
                                    ),
                                  ),
                                  SizedBox(
                                    height: 440,
                                    child: TabBarView(
                                      controller: _tabs,
                                      physics: _submitting
                                          ? const NeverScrollableScrollPhysics()
                                          : null,
                                      children: [_signIn(), _signUp()],
                                    ),
                                  ),
                                  TextButton(
                                    onPressed: _submitting
                                        ? null
                                        : _continueAsGuest,
                                    child: SizedBox(
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

                          final explainer = const _AuthExplainer();

                          if (narrow) {
                            return Column(
                              children: [
                                explainer,
                                const SizedBox(height: 40),
                                form,
                              ],
                            );
                          }

                          return Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Expanded(child: Center(child: form)),
                              const SizedBox(width: 56),
                              SizedBox(width: 360, child: explainer),
                            ],
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _signIn() {
    return SingleChildScrollView(
      padding: const EdgeInsets.only(top: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          OutlinedButton(
            onPressed: _submitting ? null : _continueWithGoogle,
            child: _submitting
                ? const _ButtonLoader(color: AppColors.primary)
                : Text(context.tr('continue_with_google')),
          ),

          const SizedBox(height: 16),

          Row(
            children: [
              const Expanded(child: Divider()),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text(
                  context.tr('or'),
                  style: const TextStyle(fontSize: 13, color: AppColors.muted),
                ),
              ),
              const Expanded(child: Divider()),
            ],
          ),

          const SizedBox(height: 16),

          Text(
            context.tr('email'),
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
          ),

          const SizedBox(height: 6),

          TextField(
            controller: _email,
            enabled: !_submitting,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            autofillHints: const [AutofillHints.email],

            // Email example ko
            // translate nahi karna.
            decoration: const InputDecoration(hintText: 'you@example.com'),
          ),

          const SizedBox(height: 14),

          Row(
            children: [
              Text(
                context.tr('password'),
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),

              const Spacer(),

              InkWell(
                onTap: _submitting
                    ? null
                    : () {
                        showDemoMessage(
                          context,
                          context.tr('password_reset_coming'),
                        );
                      },
                child: Text(
                  context.tr('forgot_password'),
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 6),

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
            decoration: InputDecoration(
              hintText: context.tr('your_password'),
              suffixIcon: IconButton(
                onPressed: _submitting
                    ? null
                    : () {
                        setState(() {
                          _hideSignInPassword = !_hideSignInPassword;
                        });
                      },
                icon: Icon(
                  _hideSignInPassword
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                ),
              ),
            ),
          ),

          if (_error != null) ...[
            const SizedBox(height: 12),
            _AuthError(message: _error!),
          ],

          const SizedBox(height: 16),

          FilledButton(
            onPressed: _submitting ? null : _signInUser,
            child: _submitting
                ? const _ButtonLoader()
                : Text(context.tr('sign_in')),
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
          OutlinedButton(
            onPressed: _submitting ? null : _continueWithGoogle,
            child: _submitting
                ? const _ButtonLoader(color: AppColors.primary)
                : Text(context.tr('continue_with_google')),
          ),

          const SizedBox(height: 16),

          Text(
            context.tr('full_name'),
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
          ),

          const SizedBox(height: 6),

          TextField(
            controller: _newName,
            enabled: !_submitting,
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.next,
            autofillHints: const [AutofillHints.name],
            decoration: InputDecoration(hintText: context.tr('your_full_name')),
          ),

          const SizedBox(height: 12),

          Text(
            context.tr('email'),
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
          ),

          const SizedBox(height: 6),

          TextField(
            controller: _newEmail,
            enabled: !_submitting,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            autofillHints: const [AutofillHints.newUsername],

            // Isko same rehne do.
            decoration: const InputDecoration(hintText: 'you@example.com'),
          ),

          const SizedBox(height: 12),

          Text(
            context.tr('password'),
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
          ),

          const SizedBox(height: 6),

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
            decoration: InputDecoration(
              hintText: context.tr('password_min_8_hint'),
              suffixIcon: IconButton(
                onPressed: _submitting
                    ? null
                    : () {
                        setState(() {
                          _hideSignUpPassword = !_hideSignUpPassword;
                        });
                      },
                icon: Icon(
                  _hideSignUpPassword
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                ),
              ),
            ),
          ),

          if (_error != null) ...[
            const SizedBox(height: 12),
            _AuthError(message: _error!),
          ],

          const SizedBox(height: 16),

          FilledButton(
            onPressed: _submitting ? null : _registerUser,
            child: _submitting
                ? const _ButtonLoader()
                : Text(context.tr('create_account')),
          ),
        ],
      ),
    );
  }
}

class _ButtonLoader extends StatelessWidget {
  const _ButtonLoader({this.color = Colors.white});

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
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.criticalSoft,
        borderRadius: BorderRadius.circular(AppRadii.md),
        border: Border.all(color: AppColors.critical.withValues(alpha: .25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline, size: 17, color: AppColors.critical),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.criticalForeground,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AuthExplainer extends StatelessWidget {
  const _AuthExplainer();

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.primaryLight,
              borderRadius: BorderRadius.circular(AppRadii.xl),
            ),
            child: const Icon(
              Icons.verified_user_outlined,
              size: 21,
              color: AppColors.primary,
            ),
          ),

          const SizedBox(height: 16),

          Text(
            context.tr('auth_explainer_title'),
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),

          const SizedBox(height: 16),

          _ExplainerItem(text: context.tr('auth_verified_instructions')),

          const SizedBox(height: 12),

          _ExplainerItem(text: context.tr('auth_7_day_simulation')),

          const SizedBox(height: 12),

          _ExplainerItem(text: context.tr('auth_family_access')),
        ],
      ),
    );
  }
}

class _ExplainerItem extends StatelessWidget {
  const _ExplainerItem({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(top: 2),
          child: Icon(Icons.arrow_forward, size: 16, color: AppColors.primary),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(fontSize: 14, color: AppColors.muted),
          ),
        ),
      ],
    );
  }
}
