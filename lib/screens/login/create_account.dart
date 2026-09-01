import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:house_rent/config/api_config.dart';
import 'package:house_rent/navigation/haven_page_route.dart';
import 'package:house_rent/screens/home/app_shell.dart';
import 'package:house_rent/screens/onboarding/social_profile_completion_screen.dart';
import 'package:house_rent/services/app_data_service.dart';
import 'package:house_rent/services/api_error.dart';
import 'package:house_rent/services/auth_method_memory.dart';
import 'package:house_rent/services/session_token_store.dart';
import 'package:house_rent/services/social_auth_service.dart';
import 'package:house_rent/widgets/social_auth_buttons.dart';
import 'package:house_rent/widgets/social_auth_conflict_sheet.dart';
import 'package:http/http.dart' as http;

enum _WhatsAppChoice { same, different, none }

class CreateAccountScreen extends StatefulWidget {
  const CreateAccountScreen({super.key});

  @override
  State<CreateAccountScreen> createState() => _CreateAccountScreenState();
}

class _CreateAccountScreenState extends State<CreateAccountScreen> {
  final _formKey = GlobalKey<FormState>();
  final _firstName = TextEditingController();
  final _lastName = TextEditingController();
  final _username = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _whatsApp = TextEditingController();
  final _password = TextEditingController();
  final _confirmation = TextEditingController();
  _WhatsAppChoice _whatsAppChoice = _WhatsAppChoice.same;
  bool _loading = false;
  bool _obscurePassword = true;
  String? _socialLoading;
  bool _authNavigationCommitted = false;

  Future<void> _continueWithGoogle() async {
    if (_socialLoading != null || _authNavigationCommitted) return;
    setState(() => _socialLoading = 'google');
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
      if (!mounted) return;
      final choice = await showSocialAuthConflictSheet(context, conflict);
      if (mounted && choice == SocialAuthConflictChoice.enterPassword) {
        Navigator.pop(context, conflict);
      }
    } on SocialAuthCanceled catch (error) {
      _notice(error.message);
    } catch (error) {
      _notice(ApiErrorResolver.message(error,
          fallback: 'Google account creation could not be completed.'));
    } finally {
      if (mounted) setState(() => _socialLoading = null);
    }
  }

  String? _required(String? value) =>
      value == null || value.trim().isEmpty ? 'This field is required' : null;

  Future<void> _createAccount() async {
    if (_loading || _authNavigationCommitted) return;
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() => _loading = true);
    final whatsappNumber = switch (_whatsAppChoice) {
      _WhatsAppChoice.same => _phone.text.trim(),
      _WhatsAppChoice.different => _whatsApp.text.trim(),
      _WhatsAppChoice.none => null,
    };
    try {
      final response = await http
          .post(
            Uri.parse('${ApiConfig.apiBase}/register'),
            headers: const {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: jsonEncode({
              'first_name': _firstName.text.trim(),
              'last_name': _lastName.text.trim(),
              'username': _username.text.trim(),
              'email': _email.text.trim(),
              'phone_number': _phone.text.trim(),
              'whatsapp_number': whatsappNumber,
              'password': _password.text,
              'password_confirmation': _confirmation.text,
            }),
          )
          .timeout(const Duration(seconds: 15));
      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        await SessionTokenStore.write(data['access_token'] as String);
        await AuthMethodMemory.remember(
          provider: 'password',
          email: _email.text,
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
      throw HavenApiException.fromResponse(response,
          operation: 'create your account');
    } catch (error) {
      _notice(ApiErrorResolver.message(error,
          fallback:
              'Haven could not create your account. Review your details and try again.'));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _notice(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Create your account')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 40),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Find your next place.',
                    style: Theme.of(context).textTheme.displayLarge),
                const SizedBox(height: 8),
                Text(
                    'A few details and you’ll be ready to explore Haven Zambia.',
                    style: Theme.of(context)
                        .textTheme
                        .bodyLarge
                        ?.copyWith(color: colors.onSurfaceVariant)),
                const SizedBox(height: 24),
                SocialAuthButtons(
                  action: 'Continue',
                  busyProvider: _socialLoading,
                  onGoogle: _continueWithGoogle,
                  onApple: () => _notice(
                      'Apple account creation will be available once Apple developer access is configured.'),
                  onFacebook: () => _notice(
                      'Facebook account creation is not configured yet.'),
                ),
                const SizedBox(height: 28),
                Row(children: [
                  Expanded(
                      child: _field(_firstName, 'First name',
                          icon: Icons.person_outline_rounded)),
                  const SizedBox(width: 12),
                  Expanded(child: _field(_lastName, 'Last name')),
                ]),
                const SizedBox(height: 14),
                _field(_username, 'Username',
                    icon: Icons.alternate_email_rounded),
                const SizedBox(height: 14),
                _field(_email, 'Email address',
                    icon: Icons.mail_outline_rounded,
                    keyboardType: TextInputType.emailAddress,
                    validator: (value) {
                  final required = _required(value);
                  if (required != null) return required;
                  return value!.contains('@') ? null : 'Enter a valid email';
                }),
                const SizedBox(height: 14),
                _field(_phone, 'Phone number',
                    hint: 'e.g. 097 123 4567',
                    icon: Icons.phone_outlined,
                    keyboardType: TextInputType.phone),
                const SizedBox(height: 22),
                Text('Can renters reach you on WhatsApp?',
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 6),
                Text('This is only shown when you publish a listing.',
                    style: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.copyWith(color: colors.onSurfaceVariant)),
                const SizedBox(height: 12),
                _WhatsAppOption(
                  selected: _whatsAppChoice == _WhatsAppChoice.same,
                  icon: Icons.check_circle_outline_rounded,
                  title: 'Yes, use my phone number',
                  onTap: () =>
                      setState(() => _whatsAppChoice = _WhatsAppChoice.same),
                ),
                _WhatsAppOption(
                  selected: _whatsAppChoice == _WhatsAppChoice.different,
                  icon: Icons.add_call,
                  title: 'Use a different WhatsApp number',
                  onTap: () => setState(
                      () => _whatsAppChoice = _WhatsAppChoice.different),
                ),
                if (_whatsAppChoice == _WhatsAppChoice.different) ...[
                  const SizedBox(height: 8),
                  _field(_whatsApp, 'WhatsApp number',
                      hint: 'Include country code if outside Zambia',
                      icon: Icons.chat_outlined,
                      keyboardType: TextInputType.phone),
                ],
                _WhatsAppOption(
                  selected: _whatsAppChoice == _WhatsAppChoice.none,
                  icon: Icons.chat_bubble_outline_rounded,
                  title: 'No, phone calls only',
                  onTap: () =>
                      setState(() => _whatsAppChoice = _WhatsAppChoice.none),
                ),
                const SizedBox(height: 22),
                _field(_password, 'Password',
                    icon: Icons.lock_outline_rounded,
                    obscureText: _obscurePassword,
                    suffix: IconButton(
                      onPressed: () =>
                          setState(() => _obscurePassword = !_obscurePassword),
                      icon: Icon(_obscurePassword
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined),
                    ), validator: (value) {
                  final required = _required(value);
                  if (required != null) return required;
                  return value!.length >= 8
                      ? null
                      : 'Use at least 8 characters';
                }),
                const SizedBox(height: 14),
                _field(_confirmation, 'Confirm password',
                    icon: Icons.lock_reset_rounded,
                    obscureText: _obscurePassword, validator: (value) {
                  if (value != _password.text) return 'Passwords do not match';
                  return _required(value);
                }),
                const SizedBox(height: 26),
                ElevatedButton(
                  onPressed: _loading || _socialLoading != null
                      ? null
                      : _createAccount,
                  child: _loading
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('Create account'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _field(
    TextEditingController controller,
    String label, {
    String? hint,
    IconData? icon,
    TextInputType? keyboardType,
    bool obscureText = false,
    Widget? suffix,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscureText,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: icon == null ? null : Icon(icon),
        suffixIcon: suffix,
      ),
      validator: validator ?? _required,
    );
  }

  @override
  void dispose() {
    for (final controller in [
      _firstName,
      _lastName,
      _username,
      _email,
      _phone,
      _whatsApp,
      _password,
      _confirmation,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }
}

class _WhatsAppOption extends StatelessWidget {
  const _WhatsAppOption({
    required this.selected,
    required this.icon,
    required this.title,
    required this.onTap,
  });

  final bool selected;
  final IconData icon;
  final String title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: selected
                ? colors.primaryContainer.withValues(alpha: .55)
                : colors.surfaceContainerLow,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
                color: selected ? colors.primary : colors.outlineVariant),
          ),
          child: Row(children: [
            Icon(icon,
                color: selected ? colors.primary : colors.onSurfaceVariant),
            const SizedBox(width: 12),
            Expanded(child: Text(title)),
            Icon(selected ? Icons.radio_button_checked : Icons.radio_button_off,
                color: selected ? colors.primary : colors.onSurfaceVariant),
          ]),
        ),
      ),
    );
  }
}
