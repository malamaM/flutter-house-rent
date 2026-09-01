import 'package:flutter/material.dart';
import 'package:house_rent/services/api_error.dart';
import 'package:house_rent/services/marketplace_service.dart';
import 'package:house_rent/widgets/haven_navigation_bar.dart';

class MobileMoneySettingsScreen extends StatefulWidget {
  const MobileMoneySettingsScreen({super.key});

  @override
  State<MobileMoneySettingsScreen> createState() =>
      _MobileMoneySettingsScreenState();
}

class _MobileMoneySettingsScreenState extends State<MobileMoneySettingsScreen> {
  final _airtelController = TextEditingController();
  final _mtnController = TextEditingController();
  bool _loading = true;
  bool _saving = false;
  bool _hasChanges = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _airtelController.dispose();
    _mtnController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final numbers =
          await MarketplaceService.instance.mobileMoneyNumbers(refresh: true);
      if (!mounted) return;
      _airtelController.text = numbers['airtel_money'] ?? '';
      _mtnController.text = numbers['mtn_money'] ?? '';
      setState(() {
        _loading = false;
        _hasChanges = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = ApiErrorResolver.message(error,
            fallback: 'Mobile-money settings could not be loaded.');
      });
    }
  }

  Future<void> _save() async {
    final airtel = _airtelController.text.trim();
    final mtn = _mtnController.text.trim();
    final invalid = <String>[];
    if (!_isValidOrEmpty(airtel)) invalid.add('Airtel Money');
    if (!_isValidOrEmpty(mtn)) invalid.add('MTN Money');
    if (invalid.isNotEmpty) {
      setState(() => _error =
          '${invalid.join(' and ')} ${invalid.length == 1 ? 'number is' : 'numbers are'} not valid. Enter 9–15 digits.');
      return;
    }

    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final numbers = await MarketplaceService.instance
          .updateMobileMoneyNumbers(airtelMoney: airtel, mtnMoney: mtn);
      if (!mounted) return;
      _airtelController.text = numbers['airtel_money'] ?? '';
      _mtnController.text = numbers['mtn_money'] ?? '';
      setState(() {
        _saving = false;
        _hasChanges = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Your mobile-money receiving numbers are saved.')));
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = ApiErrorResolver.message(error,
            fallback: 'Mobile-money settings could not be saved.');
      });
    }
  }

  bool _isValidOrEmpty(String value) {
    if (value.isEmpty) return true;
    final digits = value.replaceAll(RegExp(r'[^0-9]'), '');
    return digits.length >= 9 && digits.length <= 15;
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: const HavenNavigationBar(title: 'Mobile-money payments'),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null && !_hasAnyInput
              ? _ErrorState(message: _error!, onRetry: _load)
              : ListView(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 36),
                  children: [
                    _introCard(context),
                    const SizedBox(height: 22),
                    Text('Receiving accounts',
                        style: Theme.of(context)
                            .textTheme
                            .labelMedium
                            ?.copyWith(
                                fontSize: 11,
                                letterSpacing: .7,
                                color: colors.onSurfaceVariant)),
                    const SizedBox(height: 8),
                    _accountsCard(context),
                    const SizedBox(height: 14),
                    if (_error != null) _inlineError(context, _error!),
                    _privacyCard(context),
                    const SizedBox(height: 22),
                    SizedBox(
                      height: 54,
                      child: FilledButton.icon(
                        onPressed: _saving ? null : _save,
                        icon: _saving
                            ? const SizedBox(
                                width: 19,
                                height: 19,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2))
                            : const Icon(Icons.check_rounded),
                        label: Text(_saving
                            ? 'Saving…'
                            : _hasChanges
                                ? 'Save receiving numbers'
                                : 'Save changes'),
                      ),
                    ),
                  ],
                ),
    );
  }

  bool get _hasAnyInput =>
      _airtelController.text.trim().isNotEmpty ||
      _mtnController.text.trim().isNotEmpty;

  Widget _introCard(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            colors.primaryContainer,
            colors.primaryContainer.withValues(alpha: .58),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: colors.primary.withValues(alpha: .14)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 48,
            height: 48,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: colors.primary,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(Icons.account_balance_wallet_outlined,
                color: colors.onPrimary, size: 25),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Get paid for reservations',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: colors.onPrimaryContainer,
                        fontWeight: FontWeight.w900)),
                const SizedBox(height: 5),
                Text(
                  'Save the numbers where you receive Airtel Money and MTN Money. These details apply to every listing on your account.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: colors.onPrimaryContainer, height: 1.35),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _accountsCard(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 13),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: colors.outlineVariant),
        boxShadow: [
          BoxShadow(
              color: colors.shadow.withValues(alpha: .05),
              blurRadius: 16,
              offset: const Offset(0, 5)),
        ],
      ),
      child: Column(
        children: [
          _phoneField(
            context,
            controller: _airtelController,
            label: 'Airtel Money number',
            hint: '097 123 4567',
            accent: const Color(0xFFE64A4A),
          ),
          const SizedBox(height: 12),
          _phoneField(
            context,
            controller: _mtnController,
            label: 'MTN Money number',
            hint: '096 123 4567',
            accent: const Color(0xFFFFB300),
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.info_outline_rounded,
                  size: 17, color: colors.onSurfaceVariant),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  'You can leave either number blank and add it later. Use the number registered for the matching mobile-money service.',
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: colors.onSurfaceVariant, height: 1.35),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _phoneField(
    BuildContext context, {
    required TextEditingController controller,
    required String label,
    required String hint,
    required Color accent,
  }) {
    final colors = Theme.of(context).colorScheme;
    return TextField(
      controller: controller,
      keyboardType: TextInputType.phone,
      textInputAction: TextInputAction.next,
      onChanged: (_) => setState(() {
        _hasChanges = true;
        if (_error != null && _error!.contains('number')) _error = null;
      }),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(Icons.phone_android_rounded, color: accent),
        filled: true,
        fillColor: colors.surfaceContainerLow.withValues(alpha: .72),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: colors.outlineVariant)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: colors.outlineVariant)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: colors.primary, width: 1.5)),
      ),
    );
  }

  Widget _privacyCard(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(top: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.lock_outline_rounded, color: colors.primary, size: 20),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Private to your account',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w800, color: colors.primary)),
                const SizedBox(height: 3),
                Text(
                  'Customers will not see these numbers on your public listings. When live payments are connected, Haven will use the correct profile number for the provider they choose.',
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: colors.onSurfaceVariant, height: 1.35),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _inlineError(BuildContext context, String message) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 2),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
          color: colors.errorContainer,
          borderRadius: BorderRadius.circular(15)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.error_outline_rounded,
              size: 19, color: colors.onErrorContainer),
          const SizedBox(width: 8),
          Expanded(
              child: Text(message,
                  style: TextStyle(color: colors.onErrorContainer))),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.account_balance_wallet_outlined,
                size: 42, color: colors.primary),
            const SizedBox(height: 14),
            Text(message,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge),
            const SizedBox(height: 14),
            OutlinedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Try again')),
          ],
        ),
      ),
    );
  }
}
