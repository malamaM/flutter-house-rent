import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:house_rent/config/api_config.dart';
import 'package:house_rent/services/api_error.dart';
import 'package:house_rent/services/app_data_service.dart';
import 'package:house_rent/services/session_token_store.dart';
import 'package:house_rent/widgets/haven_navigation_bar.dart';
import 'package:http/http.dart' as http;

class ChangePassword extends StatefulWidget {
  const ChangePassword({super.key});

  @override
  State<ChangePassword> createState() => _ChangePasswordState();
}

class _ChangePasswordState extends State<ChangePassword> {
  final _formKey = GlobalKey<FormState>();
  final _currentPassword = TextEditingController();
  final _newPassword = TextEditingController();
  final _confirmation = TextEditingController();
  bool _saving = false;
  bool _showCurrent = false;
  bool _showNew = false;
  bool? _passwordEnabled;

  @override
  void initState() {
    super.initState();
    _loadAccountSecurity();
  }

  Future<void> _loadAccountSecurity() async {
    final cached = SessionService.cachedUser;
    final user = cached ?? await SessionService.currentUser(forceRefresh: true);
    if (mounted) {
      setState(() => _passwordEnabled = user?['password_enabled'] != false);
    }
  }

  Future<void> _changePassword() async {
    if (!_formKey.currentState!.validate() || _saving) return;
    FocusScope.of(context).unfocus();
    setState(() => _saving = true);
    try {
      final token = await SessionTokenStore.read();
      if (token == null) {
        _notice('Please sign in again.');
        return;
      }
      final response = await http
          .post(
            Uri.parse('${ApiConfig.apiBase}/change-password'),
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: jsonEncode({
              if (_passwordEnabled == true)
                'current_password': _currentPassword.text,
              'new_password': _newPassword.text,
              'new_password_confirmation': _confirmation.text,
            }),
          )
          .timeout(const Duration(seconds: 12));
      if (response.statusCode == 200) {
        _currentPassword.clear();
        _newPassword.clear();
        _confirmation.clear();
        await SessionService.updateCachedUser({
          'password_enabled': true,
          if (SessionService.cachedUser?['auth_provider'] == 'google')
            'auth_provider': 'google_password',
        });
        if (mounted) setState(() => _passwordEnabled = true);
        _notice(_passwordEnabled == true
            ? 'Password sign-in is ready'
            : 'Password updated successfully');
        return;
      }
      throw HavenApiException.fromResponse(response,
          operation: 'update your password');
    } catch (error) {
      _notice(ApiErrorResolver.message(error,
          fallback:
              'Haven could not update your password. Confirm the current password and try again.'));
    } finally {
      if (mounted) setState(() => _saving = false);
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
    final addingPassword = _passwordEnabled == false;
    return Scaffold(
      appBar: const HavenNavigationBar(title: 'Password'),
      body: _passwordEnabled == null
          ? const Center(child: CupertinoActivityIndicator())
          : ListView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 36),
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [
                      colors.primaryContainer.withValues(alpha: .8),
                      colors.surfaceContainerLow,
                    ]),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: colors.outlineVariant),
                  ),
                  child: Row(children: [
                    Container(
                      width: 54,
                      height: 54,
                      decoration: BoxDecoration(
                          color: colors.primary,
                          borderRadius: BorderRadius.circular(17)),
                      child: Icon(Icons.lock_outline_rounded,
                          color: colors.onPrimary, size: 27),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                              addingPassword
                                  ? 'Add password sign-in'
                                  : 'Protect your account',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleLarge
                                  ?.copyWith(
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: -.3)),
                          const SizedBox(height: 5),
                          Text(
                              addingPassword
                                  ? 'Keep Google sign-in and add a password only if you want both methods.'
                                  : 'Choose a strong password you do not use elsewhere.',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.copyWith(color: colors.onSurfaceVariant)),
                        ],
                      ),
                    ),
                  ]),
                ),
                const SizedBox(height: 26),
                Text(addingPassword ? 'Create a password' : 'Update password',
                    style: Theme.of(context)
                        .textTheme
                        .titleLarge
                        ?.copyWith(fontWeight: FontWeight.w800)),
                const SizedBox(height: 5),
                Text(
                    addingPassword
                        ? 'Because you are already securely signed in, no current password is required.'
                        : 'Confirm your current password before setting a new one.',
                    style: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.copyWith(color: colors.onSurfaceVariant)),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: colors.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: colors.outlineVariant),
                  ),
                  child: Form(
                    key: _formKey,
                    child: Column(children: [
                      if (!addingPassword) ...[
                        _passwordField(
                          controller: _currentPassword,
                          label: 'Current password',
                          visible: _showCurrent,
                          onVisibility: () =>
                              setState(() => _showCurrent = !_showCurrent),
                        ),
                        const SizedBox(height: 14),
                      ],
                      _passwordField(
                        controller: _newPassword,
                        label: 'New password',
                        visible: _showNew,
                        onVisibility: () =>
                            setState(() => _showNew = !_showNew),
                        validator: (value) => value == null || value.length < 8
                            ? 'Use at least 8 characters'
                            : null,
                      ),
                      const SizedBox(height: 14),
                      _passwordField(
                        controller: _confirmation,
                        label: 'Confirm new password',
                        visible: _showNew,
                        onVisibility: () =>
                            setState(() => _showNew = !_showNew),
                        validator: (value) => value != _newPassword.text
                            ? 'Passwords do not match'
                            : value == null || value.isEmpty
                                ? 'Confirm your new password'
                                : null,
                      ),
                    ]),
                  ),
                ),
                const SizedBox(height: 28),
                ElevatedButton.icon(
                  onPressed: _saving ? null : _changePassword,
                  icon: _saving
                      ? const SizedBox(
                          width: 19,
                          height: 19,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.shield_outlined),
                  label: Text(_saving
                      ? (addingPassword ? 'Adding…' : 'Updating…')
                      : (addingPassword
                          ? 'Add password sign-in'
                          : 'Update password')),
                ),
              ],
            ),
    );
  }

  Widget _passwordField({
    required TextEditingController controller,
    required String label,
    required bool visible,
    required VoidCallback onVisibility,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: !visible,
      enableSuggestions: false,
      autocorrect: false,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: const Icon(Icons.key_rounded),
        suffixIcon: IconButton(
          onPressed: onVisibility,
          icon: Icon(visible
              ? Icons.visibility_off_outlined
              : Icons.visibility_outlined),
        ),
      ),
      validator: validator ??
          (value) => value == null || value.isEmpty
              ? 'Enter your current password'
              : null,
    );
  }

  @override
  void dispose() {
    _currentPassword.dispose();
    _newPassword.dispose();
    _confirmation.dispose();
    super.dispose();
  }
}
