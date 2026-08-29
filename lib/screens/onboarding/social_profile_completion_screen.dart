import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:house_rent/config/api_config.dart';
import 'package:house_rent/navigation/haven_page_route.dart';
import 'package:house_rent/screens/home/app_shell.dart';
import 'package:house_rent/services/api_error.dart';
import 'package:house_rent/services/app_data_service.dart';
import 'package:house_rent/services/social_auth_service.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

enum _WhatsAppChoice { same, different, unavailable }

class SocialProfileCompletionScreen extends StatefulWidget {
  const SocialProfileCompletionScreen({
    super.key,
    required this.auth,
  });

  final SocialAuthResult auth;

  @override
  State<SocialProfileCompletionScreen> createState() =>
      _SocialProfileCompletionScreenState();
}

class _SocialProfileCompletionScreenState
    extends State<SocialProfileCompletionScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _firstName;
  late final TextEditingController _lastName;
  late final TextEditingController _phone;
  final _whatsApp = TextEditingController();
  _WhatsAppChoice _whatsAppChoice = _WhatsAppChoice.same;
  bool _saving = false;

  Map<String, dynamic> get _user => widget.auth.user;

  @override
  void initState() {
    super.initState();
    _firstName =
        TextEditingController(text: _user['first_name']?.toString() ?? '');
    _lastName =
        TextEditingController(text: _user['last_name']?.toString() ?? '');
    _phone = TextEditingController(text: _user['phone_number']?.toString());
  }

  Future<void> _finish() async {
    if (_saving || !_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() => _saving = true);
    final whatsappNumber = switch (_whatsAppChoice) {
      _WhatsAppChoice.same => _phone.text.trim(),
      _WhatsAppChoice.different => _whatsApp.text.trim(),
      _WhatsAppChoice.unavailable => null,
    };
    try {
      final preferences = await SharedPreferences.getInstance();
      final token = preferences.getString('access_token');
      if (token == null) {
        throw const HavenApiException(
          'Your secure sign-in session was not found. Sign in with Google again.',
        );
      }
      final response = await http
          .post(
            Uri.parse('${ApiConfig.apiBase}/update-profile'),
            headers: {
              'Authorization': 'Bearer $token',
              'Accept': 'application/json',
              'Content-Type': 'application/json',
            },
            body: jsonEncode({
              'first_name': _firstName.text.trim(),
              'last_name': _lastName.text.trim(),
              'phone_number': _phone.text.trim(),
              'whatsapp_number': whatsappNumber,
            }),
          )
          .timeout(const Duration(seconds: 15));
      if (response.statusCode != 200) {
        throw HavenApiException.fromResponse(response,
            operation: 'finish setting up your profile');
      }
      await SessionService.currentUser(forceRefresh: true);
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
        HavenPageRoute(builder: (_) => const AppShell()),
        (_) => false,
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(ApiErrorResolver.message(error,
            fallback: 'Haven could not finish setting up your profile.')),
      ));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final provider =
        widget.auth.provider == 'google' ? 'Google' : 'your account';
    final picture = _user['profile_picture']?.toString() ?? '';
    return Scaffold(
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.fromLTRB(22, 28, 22, 36),
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _ProfilePhoto(url: picture),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Finish your Haven',
                            style: Theme.of(context).textTheme.headlineLarge),
                        const SizedBox(height: 6),
                        Text(
                          'We received the secure basics from $provider. Add the contact details Google does not share.',
                          style: Theme.of(context)
                              .textTheme
                              .bodyMedium
                              ?.copyWith(
                                  color: colors.onSurfaceVariant, height: 1.35),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 28),
              _VerifiedEmail(email: _user['email']?.toString() ?? ''),
              const SizedBox(height: 24),
              Text('About you',
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge
                      ?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: _field(_firstName, 'First name')),
                const SizedBox(width: 12),
                Expanded(child: _field(_lastName, 'Last name')),
              ]),
              const SizedBox(height: 14),
              _field(
                _phone,
                'Phone number',
                hint: 'e.g. 097 123 4567',
                keyboardType: TextInputType.phone,
                icon: CupertinoIcons.phone,
              ),
              const SizedBox(height: 28),
              Text('WhatsApp contact',
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge
                      ?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: 5),
              Text('Choose how renters can reach you from your listings.',
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(color: colors.onSurfaceVariant)),
              const SizedBox(height: 12),
              _option(_WhatsAppChoice.same, 'Use my phone number'),
              _option(
                  _WhatsAppChoice.different, 'Use a different WhatsApp number'),
              if (_whatsAppChoice == _WhatsAppChoice.different) ...[
                const SizedBox(height: 8),
                _field(
                  _whatsApp,
                  'WhatsApp number',
                  keyboardType: TextInputType.phone,
                  icon: CupertinoIcons.chat_bubble,
                ),
              ],
              _option(_WhatsAppChoice.unavailable, 'I do not use WhatsApp'),
              const SizedBox(height: 28),
              ElevatedButton(
                onPressed: _saving ? null : _finish,
                child: _saving
                    ? const CupertinoActivityIndicator(color: Colors.white)
                    : const Text('Continue to Haven'),
              ),
              const SizedBox(height: 12),
              Text(
                'Your Google password is never shared with Haven.',
                textAlign: TextAlign.center,
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: colors.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _field(
    TextEditingController controller,
    String label, {
    String? hint,
    TextInputType? keyboardType,
    IconData? icon,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: icon == null ? null : Icon(icon),
      ),
      validator: (value) =>
          value == null || value.trim().isEmpty ? '$label is required' : null,
    );
  }

  Widget _option(_WhatsAppChoice value, String label) {
    final selected = _whatsAppChoice == value;
    final colors = Theme.of(context).colorScheme;
    return CupertinoButton(
      padding: const EdgeInsets.symmetric(vertical: 8),
      onPressed: () => setState(() => _whatsAppChoice = value),
      child: Row(children: [
        Icon(
          selected
              ? CupertinoIcons.check_mark_circled_solid
              : CupertinoIcons.circle,
          color: selected ? colors.primary : colors.onSurfaceVariant,
          size: 22,
        ),
        const SizedBox(width: 11),
        Text(label, style: TextStyle(color: colors.onSurface, fontSize: 16)),
      ]),
    );
  }

  @override
  void dispose() {
    _firstName.dispose();
    _lastName.dispose();
    _phone.dispose();
    _whatsApp.dispose();
    super.dispose();
  }
}

class _ProfilePhoto extends StatelessWidget {
  const _ProfilePhoto({required this.url});

  final String url;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      width: 68,
      height: 68,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: colors.primaryContainer,
      ),
      child: url.isEmpty
          ? Icon(CupertinoIcons.person_fill, color: colors.primary, size: 30)
          : Image.network(
              url,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Icon(CupertinoIcons.person_fill,
                  color: colors.primary, size: 30),
            ),
    );
  }
}

class _VerifiedEmail extends StatelessWidget {
  const _VerifiedEmail({required this.email});

  final String email;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.primaryContainer.withValues(alpha: .4),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(children: [
        Icon(Icons.verified_rounded, color: colors.primary, size: 22),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Google-verified email',
                  style: Theme.of(context)
                      .textTheme
                      .labelLarge
                      ?.copyWith(color: colors.primary)),
              const SizedBox(height: 2),
              Text(email, overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
      ]),
    );
  }
}
