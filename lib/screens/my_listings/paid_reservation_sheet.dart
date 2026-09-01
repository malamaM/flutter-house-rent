import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:house_rent/models/marketplace.dart';
import 'package:house_rent/services/api_error.dart';
import 'package:house_rent/services/marketplace_service.dart';

class PaidReservationSheet extends StatefulWidget {
  final int houseId;
  final String houseName;
  final int monthlyRent;

  const PaidReservationSheet({
    super.key,
    required this.houseId,
    required this.houseName,
    required this.monthlyRent,
  });

  @override
  State<PaidReservationSheet> createState() => _PaidReservationSheetState();
}

class _PaidReservationSheetState extends State<PaidReservationSheet> {
  bool _loading = true;
  bool _saving = false;
  bool _hasUnsavedChanges = false;
  String? _error;
  int _percent = 10;
  bool _depositRequired = false;
  int _depositMonths = 1;
  int _rentMonths = 1;
  final Set<String> _paymentMethods = {'airtel_money', 'mtn_money'};
  List<ReservationAvailabilityRule> _rules = [];
  List<ReservationAvailabilityException> _exceptions = [];
  List<ReservationSlot> _oneOffSlots = [];
  String? _slotsWarning;
  late final TextEditingController _airtelNumberController;
  late final TextEditingController _mtnNumberController;

  @override
  void initState() {
    super.initState();
    _airtelNumberController = TextEditingController();
    _mtnNumberController = TextEditingController();
    _load();
  }

  @override
  void dispose() {
    _airtelNumberController.dispose();
    _mtnNumberController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final config = await MarketplaceService.instance
          .reservationAvailability(widget.houseId, refresh: true);
      List<ReservationSlot> slots = const [];
      String? slotsWarning;
      try {
        slots = await MarketplaceService.instance
            .reservationSlots(widget.houseId, refresh: true);
      } catch (_) {
        slotsWarning =
            'Schedule settings loaded, but one-off dates could not be refreshed.';
      }
      if (!mounted) return;
      _applyConfig(config);
      setState(() {
        _oneOffSlots =
            slots.where((slot) => slot.source != 'recurring').toList();
        _slotsWarning = slotsWarning;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = ApiErrorResolver.message(error,
            fallback: 'Paid reservation settings could not be loaded.');
      });
    }
  }

  void _applyConfig(ReservationAvailabilityConfig config) {
    final settings = config.settings;
    _percent = settings.downPaymentPercent.clamp(1, 100);
    _depositRequired = settings.depositRequired;
    _depositMonths = settings.depositMonths.clamp(1, 12);
    _rentMonths = settings.rentMonthsAdvance.clamp(1, 12);
    _paymentMethods
      ..clear()
      ..addAll(settings.paymentMethods);
    _airtelNumberController.text =
        settings.receivingNumbers['airtel_money'] ?? '';
    _mtnNumberController.text = settings.receivingNumbers['mtn_money'] ?? '';
    _rules = [...config.rules];
    _exceptions = [...config.exceptions];
    _hasUnsavedChanges = false;
  }

  int get _baseAmount =>
      widget.monthlyRent *
      (_rentMonths + (_depositRequired ? _depositMonths : 0));

  int get _reservationAmount => (_baseAmount * _percent / 100).ceil();

  Future<void> _save() async {
    if (_paymentMethods.isEmpty) {
      _showMessage('Keep at least one mobile-money option enabled.');
      return;
    }
    final receivingNumbers = _receivingNumbers;
    for (final method in _paymentMethods) {
      if (!_isValidNumber(receivingNumbers[method] ?? '')) {
        _showMessage(
            'Add a valid ${_methodLabel(method)} receiving number or turn that payment option off.');
        return;
      }
    }
    setState(() => _saving = true);
    try {
      final config =
          await MarketplaceService.instance.updateReservationAvailability(
        widget.houseId,
        downPaymentPercent: _percent,
        depositRequired: _depositRequired,
        depositMonths: _depositMonths,
        rentMonthsAdvance: _rentMonths,
        paymentMethods: _paymentMethods.toList(),
        receivingNumbers: receivingNumbers,
        rules: _rules,
        exceptions: _exceptions,
      );
      List<ReservationSlot>? slots;
      try {
        slots = await MarketplaceService.instance
            .reservationSlots(widget.houseId, refresh: true);
      } catch (_) {
        // The schedule update has already succeeded. Keep the existing
        // one-off list visible and let the next refresh reconcile it.
      }
      if (!mounted) return;
      _applyConfig(config);
      setState(() {
        if (slots != null) {
          _oneOffSlots =
              slots.where((slot) => slot.source != 'recurring').toList();
          _slotsWarning = null;
        } else {
          _slotsWarning =
              'Settings saved, but available dates could not be refreshed.';
        }
        _saving = false;
      });
      _showMessage(slots == null
          ? 'Settings saved. Dates will refresh when Haven reconnects.'
          : 'Paid reservation settings saved.');
    } catch (error) {
      if (!mounted) return;
      setState(() => _saving = false);
      _showMessage(ApiErrorResolver.message(error,
          fallback: 'Paid reservation settings could not be saved.'));
    }
  }

  Future<void> _editRule({int? index}) async {
    final result = await showModalBottomSheet<ReservationAvailabilityRule>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AvailabilityWindowPicker(
        rule: index == null ? null : _rules[index],
      ),
    );
    if (result == null || !mounted) return;
    setState(() {
      if (index == null) {
        _rules.add(result);
      } else {
        _rules[index] = result;
      }
      _hasUnsavedChanges = true;
    });
    _showMessage(index == null
        ? 'Window added. Save settings to publish it.'
        : 'Window updated. Save settings to publish it.');
  }

  Future<void> _editException({int? index}) async {
    final result = await showModalBottomSheet<ReservationAvailabilityException>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AvailabilityWindowPicker(
        exception: index == null ? null : _exceptions[index],
      ),
    );
    if (result == null || !mounted) return;
    setState(() {
      if (index == null) {
        _exceptions.add(result);
      } else {
        _exceptions[index] = result;
      }
      _hasUnsavedChanges = true;
    });
    _showMessage(index == null
        ? 'Exception added. Save settings to publish it.'
        : 'Exception updated. Save settings to publish it.');
  }

  Future<void> _addOneOffDate() async {
    final tomorrow = DateTime.now().add(const Duration(days: 1));
    final selected = await showModalBottomSheet<DateTime>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _OneOffDateTimePicker(
        minimumDate: DateTime(tomorrow.year, tomorrow.month, tomorrow.day),
        maximumDate: DateTime.now().add(const Duration(days: 180)),
      ),
    );
    if (selected == null || !mounted) return;
    setState(() => _saving = true);
    try {
      final slot = await MarketplaceService.instance.createReservationSlot(
          widget.houseId, selected,
          endsAt: selected.add(const Duration(hours: 1)));
      if (!mounted) return;
      setState(() {
        _oneOffSlots = [..._oneOffSlots, slot]
          ..sort((a, b) => a.startsAt.compareTo(b.startsAt));
        _saving = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _saving = false);
      _showMessage(ApiErrorResolver.message(error,
          fallback: 'One-off date could not be added.'));
    }
  }

  Future<void> _removeOneOff(ReservationSlot slot) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Remove this date?'),
        content: const Text(
            'Customers will no longer be able to choose this one-off date.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Keep it')),
          FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Remove')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _saving = true);
    try {
      await MarketplaceService.instance
          .deleteReservationSlot(widget.houseId, slot.id);
      if (!mounted) return;
      setState(() {
        _oneOffSlots =
            _oneOffSlots.where((item) => item.id != slot.id).toList();
        _saving = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _saving = false);
      _showMessage(ApiErrorResolver.message(error,
          fallback: 'One-off date could not be removed.'));
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Map<String, String> get _receivingNumbers => {
        'airtel_money': _normaliseNumber(_airtelNumberController.text),
        'mtn_money': _normaliseNumber(_mtnNumberController.text),
      };

  bool _isValidNumber(String value) {
    final digits = value.replaceAll(RegExp(r'[^0-9]'), '');
    return digits.length >= 9 && digits.length <= 15;
  }

  String _normaliseNumber(String value) {
    final trimmed = value.trim();
    final digits = trimmed.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) return '';
    if (digits.startsWith('0')) return '+260${digits.substring(1)}';
    if (digits.length == 9) return '+260$digits';
    return trimmed.startsWith('+') ? '+$digits' : digits;
  }

  String _methodLabel(String method) => method == 'mtn_money'
      ? 'MTN Money'
      : method == 'airtel_money'
          ? 'Airtel Money'
          : method;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Material(
      color: colors.surface,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
      child: SafeArea(
        top: false,
        child: ConstrainedBox(
          constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(context).height * .94),
          child: _loading
              ? const SizedBox(
                  height: 300,
                  child: Center(child: CircularProgressIndicator()),
                )
              : _error != null
                  ? _ErrorContent(message: _error!, onRetry: _load)
                  : SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _handle(context),
                          const SizedBox(height: 18),
                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Paid reservations',
                                        style: Theme.of(context)
                                            .textTheme
                                            .headlineSmall),
                                    const SizedBox(height: 4),
                                    Text(widget.houseName,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall),
                                  ],
                                ),
                              ),
                              CircleAvatar(
                                backgroundColor: colors.primaryContainer,
                                child: Icon(Icons.payments_outlined,
                                    color: colors.onPrimaryContainer),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          _intro(context),
                          if (_slotsWarning != null) ...[
                            const SizedBox(height: 10),
                            _warning(context, _slotsWarning!),
                          ],
                          if (_hasUnsavedChanges) ...[
                            const SizedBox(height: 10),
                            _warning(context,
                                'You have schedule changes waiting to be saved. Customers will see them after you tap Save.'),
                          ],
                          const SizedBox(height: 18),
                          _heading(context, 'Down payment',
                              'Set the amount and payment options'),
                          _moneySettings(context),
                          const SizedBox(height: 18),
                          _heading(context, 'Recurring availability',
                              'Customers choose one-hour windows from these ranges'),
                          _rulesView(context),
                          const SizedBox(height: 18),
                          _heading(context, 'Exceptions',
                              'Block lunch breaks, days, holidays or other unavailable windows'),
                          _exceptionsView(context),
                          const SizedBox(height: 18),
                          _heading(context, 'One-off dates',
                              'Add an extra date outside your recurring schedule'),
                          _oneOffView(context),
                          const SizedBox(height: 18),
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton.icon(
                              onPressed: _saving ? null : _save,
                              icon: _saving
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2))
                                  : const Icon(Icons.check_rounded),
                              label: Text(_saving
                                  ? 'Saving settings…'
                                  : 'Save paid reservation settings'),
                            ),
                          ),
                        ],
                      ),
                    ),
        ),
      ),
    );
  }

  Widget _handle(BuildContext context) => Center(
        child: Container(
          width: 40,
          height: 4,
          decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.outlineVariant,
              borderRadius: BorderRadius.circular(4)),
        ),
      );

  Widget _intro(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
          color: colors.primaryContainer.withValues(alpha: .52),
          borderRadius: BorderRadius.circular(17)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline_rounded, color: colors.primary, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Customers pay a refundable down payment to show they are serious. A live refund may exclude the mobile-money provider fee; this demo applies no fee. Haven simulates Airtel Money and MTN Money for now; viewing requests continue as normal.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }

  Widget _warning(BuildContext context, String message) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.tertiaryContainer.withValues(alpha: .65),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.sync_problem_outlined,
              size: 19, color: colors.onTertiaryContainer),
          const SizedBox(width: 9),
          Expanded(
            child: Text(message,
                style: TextStyle(color: colors.onTertiaryContainer)),
          ),
        ],
      ),
    );
  }

  Widget _heading(BuildContext context, String title, String subtitle) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 3),
            Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      );

  Widget _moneySettings(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
          decoration: BoxDecoration(
            color: colors.surfaceContainerLow,
            borderRadius: BorderRadius.circular(17),
            border: Border.all(color: colors.outlineVariant),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  const Expanded(
                      child: Text('Down payment percentage',
                          style: TextStyle(fontWeight: FontWeight.w700))),
                  Text('$_percent%',
                      style: TextStyle(
                          color: colors.primary,
                          fontSize: 18,
                          fontWeight: FontWeight.w900)),
                ],
              ),
              Slider(
                value: _percent.toDouble(),
                min: 1,
                max: 100,
                divisions: 99,
                label: '$_percent%',
                onChanged: (value) => setState(() {
                  _percent = value.round();
                  _hasUnsavedChanges = true;
                }),
              ),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                    'Estimated reservation amount: K$_reservationAmount',
                    style: TextStyle(
                        color: colors.primary, fontWeight: FontWeight.w800)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        _choiceCard(
            context,
            'Rent paid in advance',
            [1, 2, 3, 6],
            _rentMonths,
            (value) => setState(() {
                  _rentMonths = value;
                  _hasUnsavedChanges = true;
                })),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.fromLTRB(14, 5, 8, 5),
          decoration: BoxDecoration(
            color: colors.surfaceContainerLow,
            borderRadius: BorderRadius.circular(17),
            border: Border.all(color: colors.outlineVariant),
          ),
          child: Row(
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Include a security deposit',
                        style: TextStyle(fontWeight: FontWeight.w700)),
                    SizedBox(height: 2),
                    Text('Add deposit months to the calculation.'),
                  ],
                ),
              ),
              Switch.adaptive(
                  value: _depositRequired,
                  onChanged: (value) => setState(() {
                        _depositRequired = value;
                        _hasUnsavedChanges = true;
                      })),
            ],
          ),
        ),
        if (_depositRequired) ...[
          const SizedBox(height: 10),
          _choiceCard(
              context,
              'Security deposit months',
              [1, 2, 3],
              _depositMonths,
              (value) => setState(() {
                    _depositMonths = value;
                    _hasUnsavedChanges = true;
                  })),
        ],
        const SizedBox(height: 10),
        _choiceCard(
          context,
          'Payment options customers can use',
          const [],
          0,
          (_) {},
          custom: [
            FilterChip(
              avatar: const Icon(Icons.phone_android_rounded, size: 17),
              label: const Text('Airtel Money'),
              selected: _paymentMethods.contains('airtel_money'),
              onSelected: (value) => setState(() {
                if (value) {
                  _paymentMethods.add('airtel_money');
                } else {
                  _paymentMethods.remove('airtel_money');
                }
                _hasUnsavedChanges = true;
              }),
            ),
            FilterChip(
              avatar: const Icon(Icons.phone_android_rounded, size: 17),
              label: const Text('MTN Money'),
              selected: _paymentMethods.contains('mtn_money'),
              onSelected: (value) => setState(() {
                if (value) {
                  _paymentMethods.add('mtn_money');
                } else {
                  _paymentMethods.remove('mtn_money');
                }
                _hasUnsavedChanges = true;
              }),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _receivingNumbersCard(context),
      ],
    );
  }

  Widget _receivingNumbersCard(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            colors.primaryContainer.withValues(alpha: .66),
            colors.surfaceContainerLow,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(19),
        border: Border.all(color: colors.primary.withValues(alpha: .18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 36,
                height: 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: colors.primary,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.account_balance_wallet_outlined,
                    size: 20, color: colors.onPrimary),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Where you receive payments',
                        style: TextStyle(fontWeight: FontWeight.w900)),
                    const SizedBox(height: 3),
                    Text(
                      'Add the mobile-money numbers for this listing. Customers choose the provider; Haven will use these details when live payments are connected.',
                      style: TextStyle(
                          color: colors.onSurfaceVariant,
                          fontSize: 12,
                          height: 1.3),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 13),
          _receivingNumberField(
            context,
            controller: _airtelNumberController,
            label: 'Airtel Money receiving number',
            hint: 'e.g. 097 123 4567',
            icon: Icons.phone_android_rounded,
          ),
          const SizedBox(height: 10),
          _receivingNumberField(
            context,
            controller: _mtnNumberController,
            label: 'MTN Money receiving number',
            hint: 'e.g. 096 123 4567',
            icon: Icons.phone_android_rounded,
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.lock_outline_rounded,
                  size: 15, color: colors.onSurfaceVariant),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Private to you. Numbers are not displayed on the customer listing.',
                  style: TextStyle(
                      color: colors.onSurfaceVariant,
                      fontSize: 11,
                      fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _receivingNumberField(
    BuildContext context, {
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
  }) {
    final colors = Theme.of(context).colorScheme;
    return TextField(
      controller: controller,
      keyboardType: TextInputType.phone,
      textInputAction: TextInputAction.next,
      onChanged: (_) => setState(() => _hasUnsavedChanges = true),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, color: colors.primary),
        filled: true,
        fillColor: colors.surface.withValues(alpha: .78),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: colors.outlineVariant),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: colors.outlineVariant),
        ),
      ),
    );
  }

  Widget _choiceCard(BuildContext context, String title, List<int> values,
      int selected, ValueChanged<int> onSelected,
      {List<Widget> custom = const []}) {
    final colors = Theme.of(context).colorScheme;
    final children = custom.isNotEmpty
        ? custom
        : values
            .map((value) => ChoiceChip(
                  label: Text(value.toString() +
                      ' ' +
                      (value == 1 ? 'month' : 'months')),
                  selected: selected == value,
                  onSelected: (_) => onSelected(value),
                ))
            .toList();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
          color: colors.surfaceContainerLow,
          borderRadius: BorderRadius.circular(17),
          border: Border.all(color: colors.outlineVariant)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 9),
          Wrap(spacing: 7, runSpacing: 7, children: children),
        ],
      ),
    );
  }

  Widget _rulesView(BuildContext context) => Column(
        children: [
          if (_rules.isEmpty)
            _empty(
                context, Icons.schedule_outlined, 'No recurring windows yet.')
          else
            ..._rules.asMap().entries.map((entry) => _tile(
                  context,
                  Icons.repeat_rounded,
                  _dayName(entry.value.dayOfWeek) +
                      ' · ' +
                      _timeLabel(entry.value.startsAt) +
                      ' – ' +
                      _timeLabel(entry.value.endsAt),
                  'Weekly availability window',
                  () => _editRule(index: entry.key),
                  () => setState(() {
                    _rules.removeAt(entry.key);
                    _hasUnsavedChanges = true;
                  }),
                )),
          const SizedBox(height: 4),
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              key: const ValueKey('add-recurring-window'),
              onPressed: _saving ? null : () => _editRule(),
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('Add recurring window'),
            ),
          ),
        ],
      );

  Widget _exceptionsView(BuildContext context) => Column(
        children: [
          if (_exceptions.isEmpty)
            _empty(context, Icons.free_breakfast_outlined,
                'No exceptions added. Add lunch breaks or unavailable dates.')
          else
            ..._exceptions.asMap().entries.map((entry) {
              final item = entry.value;
              final when = item.kind == 'weekly'
                  ? _dayName(item.dayOfWeek ?? 1)
                  : _dateLabel(item.exceptionDate);
              return _tile(
                context,
                Icons.block_outlined,
                when +
                    ' · ' +
                    _timeLabel(item.startsAt) +
                    ' – ' +
                    _timeLabel(item.endsAt),
                item.label?.isNotEmpty == true
                    ? item.label!
                    : item.kind == 'weekly'
                        ? 'Repeats every week'
                        : 'Specific date',
                () => _editException(index: entry.key),
                () => setState(() {
                  _exceptions.removeAt(entry.key);
                  _hasUnsavedChanges = true;
                }),
              );
            }),
          const SizedBox(height: 4),
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              key: const ValueKey('add-reservation-exception'),
              onPressed: _saving ? null : () => _editException(),
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('Add exception'),
            ),
          ),
        ],
      );

  Widget _oneOffView(BuildContext context) => Column(
        children: [
          if (_oneOffSlots.isEmpty)
            _empty(context, Icons.event_outlined,
                'No one-off dates. Recurring windows cover the usual schedule.')
          else
            ..._oneOffSlots.map((slot) => _tile(
                  context,
                  Icons.event_available_outlined,
                  _slotLabel(slot),
                  'One-off availability date',
                  null,
                  () => _removeOneOff(slot),
                )),
          const SizedBox(height: 4),
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              onPressed: _saving ? null : _addOneOffDate,
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('Add one-off date'),
            ),
          ),
        ],
      );

  Widget _empty(BuildContext context, IconData icon, String text) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
          color: colors.surfaceContainerLow,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: colors.outlineVariant)),
      child: Row(children: [
        Icon(icon, color: colors.onSurfaceVariant, size: 20),
        const SizedBox(width: 10),
        Expanded(child: Text(text, style: const TextStyle(fontSize: 12))),
      ]),
    );
  }

  Widget _tile(BuildContext context, IconData icon, String title,
      String subtitle, VoidCallback? onTap, VoidCallback onRemove) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
          color: colors.surfaceContainerLow,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: colors.outlineVariant)),
      child: ListTile(
        onTap: onTap,
        leading: Icon(icon, color: colors.primary),
        title: Text(title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text(subtitle),
        trailing: IconButton(
            onPressed: _saving ? null : onRemove,
            icon: const Icon(Icons.remove_circle_outline)),
      ),
    );
  }

  String _slotLabel(ReservationSlot slot) =>
      _dateLabel(_dateKey(slot.startsAt)) +
      ' · ' +
      _timeLabel(_timeKey(slot.startsAt)) +
      ' – ' +
      _timeLabel(
          _timeKey(slot.endsAt ?? slot.startsAt.add(const Duration(hours: 1))));

  String _dayName(int day) => const [
        'Monday',
        'Tuesday',
        'Wednesday',
        'Thursday',
        'Friday',
        'Saturday',
        'Sunday',
      ][day.clamp(1, 7) - 1];

  String _timeLabel(String value) {
    final parts = value.split(':');
    final hour24 = int.tryParse(parts.first) ?? 0;
    final minute = parts.length > 1 ? parts[1].padLeft(2, '0') : '00';
    final hour = hour24 % 12 == 0 ? 12 : hour24 % 12;
    return '$hour:$minute ' + (hour24 >= 12 ? 'PM' : 'AM');
  }

  String _dateLabel(String? value) {
    if (value == null || value.isEmpty) return 'Specific date';
    final date = DateTime.tryParse(value);
    if (date == null) return value;
    return date.day.toString() +
        ' ' +
        const [
          'Jan',
          'Feb',
          'Mar',
          'Apr',
          'May',
          'Jun',
          'Jul',
          'Aug',
          'Sep',
          'Oct',
          'Nov',
          'Dec',
        ][date.month - 1] +
        ' ' +
        date.year.toString();
  }

  String _dateKey(DateTime value) =>
      value.year.toString().padLeft(4, '0') +
      '-' +
      value.month.toString().padLeft(2, '0') +
      '-' +
      value.day.toString().padLeft(2, '0');

  String _timeKey(DateTime value) =>
      value.hour.toString().padLeft(2, '0') +
      ':' +
      value.minute.toString().padLeft(2, '0');
}

class _ErrorContent extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorContent({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) => SizedBox(
        height: 300,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text(message, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              TextButton(onPressed: onRetry, child: const Text('Try again')),
            ]),
          ),
        ),
      );
}

class _AvailabilityWindowPicker extends StatefulWidget {
  final ReservationAvailabilityRule? rule;
  final ReservationAvailabilityException? exception;

  const _AvailabilityWindowPicker({this.rule, this.exception});

  @override
  State<_AvailabilityWindowPicker> createState() =>
      _AvailabilityWindowPickerState();
}

class _AvailabilityWindowPickerState extends State<_AvailabilityWindowPicker> {
  late int _day;
  late String _kind;
  late DateTime _date;
  late DateTime _start;
  late DateTime _end;
  final _label = TextEditingController();
  String? _error;

  bool get _isException => widget.exception != null;

  @override
  void initState() {
    super.initState();
    final tomorrow = DateTime.now().add(const Duration(days: 1));
    _day = widget.rule?.dayOfWeek ?? widget.exception?.dayOfWeek ?? 1;
    _kind = widget.exception?.kind ?? 'weekly';
    _date = widget.exception?.exceptionDate == null
        ? DateTime(tomorrow.year, tomorrow.month, tomorrow.day)
        : DateTime.tryParse(widget.exception!.exceptionDate!) ??
            DateTime(tomorrow.year, tomorrow.month, tomorrow.day);
    _start = _timeDate(widget.rule?.startsAt ?? widget.exception?.startsAt,
        const TimeOfDay(hour: 9, minute: 0));
    _end = _timeDate(widget.rule?.endsAt ?? widget.exception?.endsAt,
        const TimeOfDay(hour: 17, minute: 0));
    _label.text = widget.exception?.label ?? '';
  }

  DateTime _timeDate(String? value, TimeOfDay fallback) {
    final parts = value?.split(':') ?? const <String>[];
    return DateTime(
      2020,
      1,
      1,
      int.tryParse(parts.firstOrNull ?? '') ?? fallback.hour,
      int.tryParse(parts.length > 1 ? parts[1] : '') ?? fallback.minute,
    );
  }

  String _timeKey(DateTime value) =>
      value.hour.toString().padLeft(2, '0') +
      ':' +
      value.minute.toString().padLeft(2, '0');

  String _dateKey(DateTime value) =>
      value.year.toString().padLeft(4, '0') +
      '-' +
      value.month.toString().padLeft(2, '0') +
      '-' +
      value.day.toString().padLeft(2, '0');

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final tomorrow = DateTime.now().add(const Duration(days: 1));
    return Material(
      color: colors.surface,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                        color: colors.outlineVariant,
                        borderRadius: BorderRadius.circular(4)),
                  ),
                ),
                const SizedBox(height: 17),
                Text(_isException ? 'Add an exception' : 'Add recurring window',
                    style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: 4),
                Text(
                    _isException
                        ? 'Block a break or date from your available windows.'
                        : 'Choose a weekly day and the time range customers can select.',
                    style: Theme.of(context).textTheme.bodyMedium),
                if (_isException) ...[
                  const SizedBox(height: 15),
                  Wrap(spacing: 8, children: [
                    ChoiceChip(
                        label: const Text('Every week'),
                        selected: _kind == 'weekly',
                        onSelected: (_) => setState(() => _kind = 'weekly')),
                    ChoiceChip(
                        label: const Text('Specific date'),
                        selected: _kind == 'date',
                        onSelected: (_) => setState(() => _kind = 'date')),
                  ]),
                ],
                const SizedBox(height: 15),
                if (_isException && _kind == 'date')
                  _datePicker(context, tomorrow)
                else
                  _dayPicker(context),
                const SizedBox(height: 13),
                Row(children: [
                  Expanded(
                      child: _timePicker(context, 'From', _start,
                          (value) => setState(() => _start = value))),
                  const SizedBox(width: 10),
                  Expanded(
                      child: _timePicker(context, 'Until', _end,
                          (value) => setState(() => _end = value))),
                ]),
                if (_isException) ...[
                  const SizedBox(height: 13),
                  TextField(
                      controller: _label,
                      decoration: const InputDecoration(
                          labelText: 'Label (optional)',
                          hintText: 'Lunch break or public holiday')),
                ],
                if (_error != null) ...[
                  const SizedBox(height: 10),
                  Text(_error!,
                      style: TextStyle(color: colors.error, fontSize: 12)),
                ],
                const SizedBox(height: 15),
                Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                  CupertinoButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel')),
                  CupertinoButton.filled(
                      onPressed: _submit,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 17, vertical: 9),
                      child:
                          Text(_isException ? 'Add exception' : 'Add window')),
                ]),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _dayPicker(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Day of the week',
              style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: List.generate(7, (index) {
              final day = index + 1;
              return ChoiceChip(
                  label: Text(const [
                    'Mon',
                    'Tue',
                    'Wed',
                    'Thu',
                    'Fri',
                    'Sat',
                    'Sun'
                  ][index]),
                  selected: _day == day,
                  onSelected: (_) => setState(() => _day = day));
            }),
          ),
        ],
      );

  Widget _datePicker(BuildContext context, DateTime tomorrow) {
    final colors = Theme.of(context).colorScheme;
    final minimumDate = widget.exception != null && _date.isBefore(tomorrow)
        ? DateTime(_date.year, _date.month, _date.day)
        : DateTime(tomorrow.year, tomorrow.month, tomorrow.day);
    final maximumDate = DateTime.now().add(const Duration(days: 180));
    final pickerMaximum = widget.exception != null && _date.isAfter(maximumDate)
        ? DateTime(_date.year, _date.month, _date.day)
        : DateTime(maximumDate.year, maximumDate.month, maximumDate.day);
    return _pickerBox(
      context,
      CupertinoDatePicker(
          mode: CupertinoDatePickerMode.date,
          minimumDate: minimumDate,
          maximumDate: pickerMaximum,
          initialDateTime: _date,
          onDateTimeChanged: (value) => setState(() => _date = value)),
      colors,
    );
  }

  Widget _timePicker(BuildContext context, String label, DateTime value,
      ValueChanged<DateTime> onChanged) {
    final colors = Theme.of(context).colorScheme;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
      const SizedBox(height: 7),
      _pickerBox(
        context,
        CupertinoDatePicker(
            mode: CupertinoDatePickerMode.time,
            use24hFormat: false,
            minuteInterval: 15,
            initialDateTime: value,
            onDateTimeChanged: onChanged),
        colors,
        height: 130,
      ),
    ]);
  }

  Widget _pickerBox(BuildContext context, Widget picker, ColorScheme colors,
      {double height = 130}) {
    return Container(
      decoration: BoxDecoration(
          color: colors.surfaceContainerLow,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: colors.outlineVariant)),
      child: CupertinoTheme(
        data: CupertinoThemeData(
          brightness: Theme.of(context).brightness,
          primaryColor: colors.primary,
          textTheme: CupertinoTextThemeData(
              dateTimePickerTextStyle:
                  TextStyle(color: colors.onSurface, fontSize: 20)),
        ),
        child: SizedBox(height: height, child: picker),
      ),
    );
  }

  void _submit() {
    if (!_end.isAfter(_start)) {
      setState(() => _error = 'The end time must be after the start time.');
      return;
    }
    final label = _label.text.trim().isEmpty ? null : _label.text.trim();
    if (_isException) {
      Navigator.pop(
        context,
        ReservationAvailabilityException(
          id: widget.exception?.id ?? 0,
          kind: _kind,
          dayOfWeek: _kind == 'weekly' ? _day : null,
          exceptionDate: _kind == 'date' ? _dateKey(_date) : null,
          startsAt: _timeKey(_start),
          endsAt: _timeKey(_end),
          label: label,
        ),
      );
    } else {
      Navigator.pop(
        context,
        ReservationAvailabilityRule(
          id: widget.rule?.id ?? 0,
          dayOfWeek: _day,
          startsAt: _timeKey(_start),
          endsAt: _timeKey(_end),
        ),
      );
    }
  }
}

class _OneOffDateTimePicker extends StatefulWidget {
  final DateTime minimumDate;
  final DateTime maximumDate;

  const _OneOffDateTimePicker(
      {required this.minimumDate, required this.maximumDate});

  @override
  State<_OneOffDateTimePicker> createState() => _OneOffDateTimePickerState();
}

class _OneOffDateTimePickerState extends State<_OneOffDateTimePicker> {
  late DateTime _selected;

  @override
  void initState() {
    super.initState();
    _selected = DateTime(widget.minimumDate.year, widget.minimumDate.month,
        widget.minimumDate.day, 10);
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Material(
      color: colors.surface,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                    color: colors.outlineVariant,
                    borderRadius: BorderRadius.circular(4))),
            const SizedBox(height: 18),
            Align(
                alignment: Alignment.centerLeft,
                child: Text('Add one-off date',
                    style: Theme.of(context).textTheme.headlineSmall)),
            const SizedBox(height: 12),
            _pickerBox(
              context,
              CupertinoDatePicker(
                  mode: CupertinoDatePickerMode.dateAndTime,
                  use24hFormat: false,
                  minuteInterval: 15,
                  minimumDate: widget.minimumDate,
                  maximumDate: widget.maximumDate,
                  initialDateTime: _selected,
                  onDateTimeChanged: (value) =>
                      setState(() => _selected = value)),
              colors,
              height: 190,
            ),
            const SizedBox(height: 12),
            Row(mainAxisAlignment: MainAxisAlignment.end, children: [
              CupertinoButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel')),
              CupertinoButton.filled(
                  onPressed: () => Navigator.pop(context, _selected),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 17, vertical: 9),
                  child: const Text('Add date')),
            ]),
          ]),
        ),
      ),
    );
  }

  Widget _pickerBox(BuildContext context, Widget picker, ColorScheme colors,
      {required double height}) {
    return Container(
      decoration: BoxDecoration(
          color: colors.surfaceContainerLow,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: colors.outlineVariant)),
      child: CupertinoTheme(
        data: CupertinoThemeData(
          brightness: Theme.of(context).brightness,
          primaryColor: colors.primary,
          textTheme: CupertinoTextThemeData(
              dateTimePickerTextStyle:
                  TextStyle(color: colors.onSurface, fontSize: 22)),
        ),
        child: SizedBox(height: height, child: picker),
      ),
    );
  }
}
