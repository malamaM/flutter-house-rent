import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:house_rent/config/api_config.dart';
import 'package:house_rent/navigation/haven_page_route.dart';
import 'package:house_rent/screens/home/app_shell.dart';
import 'package:house_rent/screens/login/create_account.dart';
import 'package:house_rent/screens/onboarding/social_profile_completion_screen.dart';
import 'package:house_rent/services/app_data_service.dart';
import 'package:house_rent/services/api_error.dart';
import 'package:house_rent/services/auth_method_memory.dart';
import 'package:house_rent/services/session_token_store.dart';
import 'package:house_rent/services/social_auth_service.dart';
import 'package:house_rent/widgets/social_auth_buttons.dart';
import 'package:house_rent/widgets/social_auth_conflict_sheet.dart';
import 'package:http/http.dart' as http;

class SignInScreen extends StatefulWidget {
  const SignInScreen({Key? key}) : super(key: key);

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  final formKey = GlobalKey<FormState>();
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final _passwordFocus = FocusNode();
  bool loading = false;
  bool obscurePassword = true;
  String? socialLoading;
  bool _authNavigationCommitted = false;
  RememberedAuthMethod? _lastAuthMethod;
  SocialAuthAccountConflict? _pendingSocialLink;

  bool get _typedEmailUsedSocially =>
      _lastAuthMethod?.provider != 'password' &&
      (_lastAuthMethod?.matchesEmail(emailController.text) ?? false);

  @override
  void initState() {
    super.initState();
    emailController.addListener(_emailChanged);
    _loadLastAuthMethod();
  }

  void _emailChanged() {
    if (mounted && _lastAuthMethod?.email.isNotEmpty == true) setState(() {});
  }

  Future<void> _loadLastAuthMethod() async {
    final remembered = await AuthMethodMemory.load();
    if (mounted) setState(() => _lastAuthMethod = remembered);
  }

  Future<void> _signInWithGoogle() async {
    if (socialLoading != null || _authNavigationCommitted) return;
    setState(() => socialLoading = 'google');
    try {
      final auth = await SocialAuthService.signInWithGoogle();
      if (mounted) {
        _authNavigationCommitted = true;
        Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
          HavenPageRoute(
            builder: (_) => auth.requiresProfileCompletion
                ? SocialProfileCompletionScreen(auth: auth)
                : const AppShell(),
          ),
          (_) => false,
        );
      }
    } on SocialAuthAccountConflict catch (conflict) {
      await _handleSocialConflict(conflict);
    } on SocialAuthCanceled catch (error) {
      _showMessage(error.message);
    } catch (error) {
      _showMessage(ApiErrorResolver.message(error,
          fallback: 'Google sign-in could not be completed.'));
    } finally {
      if (mounted) setState(() => socialLoading = null);
    }
  }

  Future<void> _handleSocialConflict(SocialAuthAccountConflict conflict) async {
    if (!mounted) return;
    final choice = await showSocialAuthConflictSheet(context, conflict);
    if (!mounted || choice != SocialAuthConflictChoice.enterPassword) return;
    emailController.text = conflict.email;
    setState(() => _pendingSocialLink = conflict);
    _passwordFocus.requestFocus();
  }

  Future<void> _signIn() async {
    if (loading || _authNavigationCommitted) return;
    if (!formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() => loading = true);
    try {
      final response = await http
          .post(
            Uri.parse('${ApiConfig.apiBase}/login'),
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json'
            },
            body: jsonEncode({
              'email': emailController.text.trim(),
              'password': passwordController.text
            }),
          )
          .timeout(const Duration(seconds: 12));
      if (response.statusCode == 200) {
        final token = jsonDecode(response.body)['access_token'];
        await SessionTokenStore.write(token);
        final pendingLink = _pendingSocialLink;
        if (pendingLink != null) {
          try {
            await SocialAuthService.linkGoogleToSignedInAccount(
              accessToken: token,
              identityToken: pendingLink.identityToken,
            );
            _pendingSocialLink = null;
          } catch (_) {
            await SessionTokenStore.delete();
            rethrow;
          }
        }
        await AuthMethodMemory.remember(
          provider: 'password',
          email: emailController.text,
        );
        await SessionService.currentUser(forceRefresh: true);
        if (mounted) {
          _authNavigationCommitted = true;
          Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
            HavenPageRoute(builder: (_) => const AppShell()),
            (_) => false,
          );
        }
        return;
      }
      throw HavenApiException.fromResponse(response, operation: 'sign you in');
    } catch (error) {
      _showMessage(ApiErrorResolver.message(error,
          fallback: 'Haven could not sign you in. Check your details.'));
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  void _notAvailable(String feature) {
    final colors = Theme.of(context).colorScheme;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
        decoration: BoxDecoration(
            color: colors.surface,
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(26))),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                    color: colors.outlineVariant,
                    borderRadius: BorderRadius.circular(4))),
            const SizedBox(height: 24),
            Icon(Icons.construction_rounded,
                color: Theme.of(context).colorScheme.primary, size: 34),
            const SizedBox(height: 14),
            Text('$feature is coming soon',
                style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 8),
            Text(
                'For now, ask the Haven Zambia team to help with your account.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 28, 24, 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Form(
                key: formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                            color: colors.primary,
                            borderRadius: BorderRadius.circular(17)),
                        child: Icon(Icons.roofing_rounded,
                            color: colors.onPrimary, size: 30),
                      ),
                    ),
                    const SizedBox(height: 36),
                    Text('Welcome back.',
                        style: Theme.of(context).textTheme.displayLarge),
                    const SizedBox(height: 10),
                    Text(
                        'Sign in to continue your property search and manage your listings.',
                        style: Theme.of(context)
                            .textTheme
                            .bodyLarge
                            ?.copyWith(color: colors.onSurfaceVariant)),
                    if (_lastAuthMethod != null) ...[
                      const SizedBox(height: 16),
                      _LastSignInReminder(method: _lastAuthMethod!),
                    ],
                    const SizedBox(height: 30),
                    Text('Email address',
                        style: Theme.of(context).textTheme.labelLarge),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: emailController,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      autofillHints: const [AutofillHints.email],
                      decoration: const InputDecoration(
                          hintText: 'you@example.com',
                          prefixIcon: Icon(Icons.mail_outline_rounded)),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Enter your email address';
                        }
                        if (!value.contains('@')) {
                          return 'Enter a valid email address';
                        }
                        return null;
                      },
                    ),
                    if (_typedEmailUsedSocially) ...[
                      const SizedBox(height: 9),
                      _EmailProviderHint(method: _lastAuthMethod!),
                    ],
                    const SizedBox(height: 18),
                    Text('Password',
                        style: Theme.of(context).textTheme.labelLarge),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: passwordController,
                      focusNode: _passwordFocus,
                      obscureText: obscurePassword,
                      textInputAction: TextInputAction.done,
                      onFieldSubmitted: (_) => _signIn(),
                      autofillHints: const [AutofillHints.password],
                      decoration: InputDecoration(
                        hintText: 'Enter your password',
                        prefixIcon: const Icon(Icons.lock_outline_rounded),
                        suffixIcon: IconButton(
                          onPressed: () => setState(
                              () => obscurePassword = !obscurePassword),
                          icon: Icon(obscurePassword
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined),
                        ),
                      ),
                      validator: (value) => value == null || value.isEmpty
                          ? 'Enter your password'
                          : null,
                    ),
                    if (_pendingSocialLink != null) ...[
                      const SizedBox(height: 10),
                      const _PendingLinkHint(),
                    ],
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                          onPressed: () => _notAvailable('Password recovery'),
                          child: const Text('Forgot password?')),
                    ),
                    const SizedBox(height: 14),
                    ElevatedButton(
                      onPressed:
                          loading || socialLoading != null ? null : _signIn,
                      child: loading
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                  color: Colors.white, strokeWidth: 2))
                          : const Text('Sign in'),
                    ),
                    const SizedBox(height: 24),
                    SocialAuthButtons(
                      action: 'Continue',
                      busyProvider: socialLoading,
                      onGoogle: _signInWithGoogle,
                      onApple: () => _notAvailable('Sign in with Apple'),
                      onFacebook: () => _notAvailable('Facebook sign-in'),
                      lastUsedProvider: _lastAuthMethod?.provider,
                    ),
                    const SizedBox(height: 20),
                    Wrap(
                      alignment: WrapAlignment.center,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text('New to Haven Zambia?',
                            style: Theme.of(context).textTheme.bodyMedium),
                        TextButton(
                            onPressed: () async {
                              final conflict = await Navigator.push<
                                  SocialAuthAccountConflict>(
                                context,
                                HavenPageRoute(
                                    builder: (_) =>
                                        const CreateAccountScreen()),
                              );
                              if (conflict != null && mounted) {
                                await _handleSocialConflict(conflict);
                              }
                            },
                            child: const Text('Create account')),
                      ],
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

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }
}

class _LastSignInReminder extends StatelessWidget {
  const _LastSignInReminder({required this.method});

  final RememberedAuthMethod method;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
      decoration: BoxDecoration(
        color: colors.primaryContainer.withValues(alpha: .38),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(children: [
        Icon(Icons.history_rounded, size: 18, color: colors.primary),
        const SizedBox(width: 9),
        Expanded(
          child: Text(
            'Last signed in on this device with ${method.providerLabel}',
            style: TextStyle(
              color: colors.onSurfaceVariant,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ]),
    );
  }
}

class _EmailProviderHint extends StatelessWidget {
  const _EmailProviderHint({required this.method});

  final RememberedAuthMethod method;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.info_outline_rounded, size: 17, color: colors.primary),
        const SizedBox(width: 7),
        Expanded(
          child: Text(
            'This email last used ${method.providerLabel}. Continue with '
            '${method.providerLabel} unless you deliberately added a password later.',
            style: TextStyle(
              color: colors.onSurfaceVariant,
              fontSize: 12.5,
              height: 1.3,
            ),
          ),
        ),
      ],
    );
  }
}

class _PendingLinkHint extends StatelessWidget {
  const _PendingLinkHint();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.link_rounded, size: 18, color: colors.primary),
        const SizedBox(width: 7),
        Expanded(
          child: Text(
            'After your password is verified, Google will be securely connected to this Haven account.',
            style: TextStyle(
              color: colors.onSurfaceVariant,
              fontSize: 12.5,
              height: 1.3,
            ),
          ),
        ),
      ],
    );
  }
}
