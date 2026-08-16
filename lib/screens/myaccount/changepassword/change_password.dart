import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:house_rent/config/api_config.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

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

  Future<void> _changePassword() async {
    if (!_formKey.currentState!.validate() || _saving) return;
    FocusScope.of(context).unfocus();
    setState(() => _saving = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('access_token');
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
        _notice('Password updated successfully');
        return;
      }
      var message = 'Could not update your password.';
      try {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final errors = data['errors'];
        message = errors is Map && errors.isNotEmpty
            ? (errors.values.first as List).first.toString()
            : data['message']?.toString() ?? message;
      } catch (_) {}
      _notice(message);
    } catch (_) {
      _notice('Could not update your password. Check your connection.');
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
    return Scaffold(
      appBar: AppBar(title: const Text('Password')),
      body: ListView(
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
                    Text('Protect your account',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w800, letterSpacing: -.3)),
                    const SizedBox(height: 5),
                    Text('Choose a strong password you do not use elsewhere.',
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
          Text('Update password',
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 5),
          Text('Confirm your current password before setting a new one.',
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
                _passwordField(
                  controller: _currentPassword,
                  label: 'Current password',
                  visible: _showCurrent,
                  onVisibility: () =>
                      setState(() => _showCurrent = !_showCurrent),
                ),
                const SizedBox(height: 14),
                _passwordField(
                  controller: _newPassword,
                  label: 'New password',
                  visible: _showNew,
                  onVisibility: () => setState(() => _showNew = !_showNew),
                  validator: (value) => value == null || value.length < 8
                      ? 'Use at least 8 characters'
                      : null,
                ),
                const SizedBox(height: 14),
                _passwordField(
                  controller: _confirmation,
                  label: 'Confirm new password',
                  visible: _showNew,
                  onVisibility: () => setState(() => _showNew = !_showNew),
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
            label: Text(_saving ? 'Updating…' : 'Update password'),
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
