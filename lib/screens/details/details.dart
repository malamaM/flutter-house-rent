import 'dart:async';
import 'dart:convert';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:house_rent/config/api_config.dart';
import 'package:house_rent/models/house.dart';
import 'package:house_rent/models/marketplace.dart';
import 'package:house_rent/navigation/haven_page_route.dart';
import 'package:house_rent/services/app_data_service.dart';
import 'package:house_rent/services/api_error.dart';
import 'package:house_rent/services/recommendation_service.dart';
import 'package:house_rent/services/session_recommendation.dart';
import 'package:house_rent/services/marketplace_service.dart';
import 'package:house_rent/services/network_status_service.dart';
import 'package:house_rent/services/offline_sync_service.dart';
import 'package:house_rent/screens/profile/marketplace_hub_screen.dart';
import 'package:house_rent/screens/my_listings/edit_listing.dart';
import 'package:house_rent/screens/my_listings/listing_management_screen.dart';
import 'package:house_rent/screens/my_listings/paid_reservation_sheet.dart';
import 'package:house_rent/theme/app_colors.dart';
import 'package:house_rent/widgets/about.dart';
import 'package:house_rent/widgets/content_intro.dart';
import 'package:house_rent/widgets/details_app_bar.dart';
import 'package:house_rent/widgets/house_gallery.dart';
import 'package:house_rent/widgets/house_info.dart';
import 'package:house_rent/widgets/house_amenities.dart';
import 'package:house_rent/widgets/house_location_map.dart';
import 'package:house_rent/widgets/glass_surface.dart';
import 'package:house_rent/widgets/lister_reviews_section.dart';
import 'package:house_rent/widgets/lister_trust_badges.dart';
import 'package:house_rent/widgets/listing_videos_section.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

/// Cupertino-backed so iOS can attach its interactive edge-swipe pop gesture.
/// The custom transition remains intentionally subtle and is driven by the
/// same route animation, so Android keeps the polished details transition.
class _DetailsPageRoute extends HavenPageRoute<void> {
  _DetailsPageRoute({required House house, required bool isOwnerView})
      : super(
          builder: (_) => Details(house: house, isOwnerView: isOwnerView),
          allowSnapshotting: true,
        );

  @override
  Duration get transitionDuration => const Duration(milliseconds: 320);

  @override
  Duration get reverseTransitionDuration => const Duration(milliseconds: 260);

  @override
  Widget buildTransitions(BuildContext context, Animation<double> animation,
      Animation<double> secondaryAnimation, Widget child) {
    // Let Cupertino own the iOS transition. Its transition widget includes
    // the native interactive left-edge swipe-to-pop controller.
    if (Theme.of(context).platform == TargetPlatform.iOS) {
      return super
          .buildTransitions(context, animation, secondaryAnimation, child);
    }
    final curved = CurvedAnimation(
      parent: animation,
      curve: Curves.easeOutQuart,
      reverseCurve: Curves.easeInQuart,
    );
    return FadeTransition(
      opacity: curved,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(.14, 0),
          end: Offset.zero,
        ).animate(curved),
        child: child,
      ),
    );
  }
}

class _ViewingSchedule {
  final DateTime requestedAt;
  final String? note;

  const _ViewingSchedule(this.requestedAt, this.note);
}

class _ViewingSchedulerSheet extends StatefulWidget {
  const _ViewingSchedulerSheet();

  @override
  State<_ViewingSchedulerSheet> createState() => _ViewingSchedulerSheetState();
}

class _ViewingSchedulerSheetState extends State<_ViewingSchedulerSheet> {
  late DateTime _day;
  late DateTime _time;
  final _note = TextEditingController();
  String? _error;

  @override
  void initState() {
    super.initState();
    final tomorrow = DateTime.now().add(const Duration(days: 1));
    _day = DateTime(tomorrow.year, tomorrow.month, tomorrow.day);
    _time = DateTime(2020, 1, 1, 10);
  }

  DateTime get _selection => DateTime(
        _day.year,
        _day.month,
        _day.day,
        _time.hour,
        _time.minute,
      );

  void _confirm() {
    if (!_selection.isAfter(DateTime.now())) {
      setState(() => _error = 'Choose a time that is still ahead.');
      return;
    }
    final note = _note.text.trim();
    Navigator.pop(
      context,
      _ViewingSchedule(_selection, note.isEmpty ? null : note),
    );
  }

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final now = DateTime.now();
    final firstDay = DateTime(now.year, now.month, now.day);
    return FractionallySizedBox(
      heightFactor: .92,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 4, 14, 10),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Schedule a viewing',
                          style: Theme.of(context).textTheme.headlineMedium),
                      const SizedBox(height: 3),
                      Text('Choose a day and preferred arrival time.',
                          style: Theme.of(context).textTheme.bodyMedium),
                    ],
                  ),
                ),
                CupertinoButton(
                  padding: const EdgeInsets.all(9),
                  onPressed: () => Navigator.pop(context),
                  child: const Icon(CupertinoIcons.xmark_circle_fill),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: colors.outlineVariant),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: colors.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: colors.outlineVariant, width: .7),
                  ),
                  child: CalendarDatePicker(
                    initialDate: _day,
                    firstDate: firstDay,
                    lastDate: firstDay.add(const Duration(days: 60)),
                    onDateChanged: (value) => setState(() {
                      _day = value;
                      _error = null;
                    }),
                  ),
                ),
                const SizedBox(height: 18),
                Text('Preferred time',
                    style: Theme.of(context).textTheme.labelLarge),
                const SizedBox(height: 7),
                Container(
                  height: 132,
                  decoration: BoxDecoration(
                    color: colors.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: colors.outlineVariant, width: .7),
                  ),
                  child: CupertinoDatePicker(
                    mode: CupertinoDatePickerMode.time,
                    initialDateTime: _time,
                    minuteInterval: 15,
                    use24hFormat: MediaQuery.alwaysUse24HourFormatOf(context),
                    onDateTimeChanged: (value) => setState(() {
                      _time = value;
                      _error = null;
                    }),
                  ),
                ),
                const SizedBox(height: 18),
                TextField(
                  controller: _note,
                  maxLength: 500,
                  maxLines: 2,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    labelText: 'Note for the lister (optional)',
                    hintText: 'For example, who will attend with you',
                    prefixIcon: Icon(CupertinoIcons.text_bubble),
                  ),
                ),
              ],
            ),
          ),
          SafeArea(
            top: false,
            child: Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
              decoration: BoxDecoration(
                color: colors.surface,
                border: Border(top: BorderSide(color: colors.outlineVariant)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Icon(CupertinoIcons.calendar,
                          size: 18, color: colors.primary),
                      const SizedBox(width: 9),
                      Expanded(
                        child: Text(_selectionLabel(_selection),
                            style: Theme.of(context).textTheme.titleMedium),
                      ),
                    ],
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 7),
                    Text(_error!,
                        style: TextStyle(
                            color: colors.error,
                            fontSize: 12,
                            fontWeight: FontWeight.w600)),
                  ],
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: _confirm,
                    icon: const Icon(CupertinoIcons.paperplane_fill, size: 18),
                    label: const Text('Send viewing request'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _selectionLabel(DateTime value) {
    const weekdays = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday'
    ];
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December'
    ];
    final hour = value.hour % 12 == 0 ? 12 : value.hour % 12;
    final minute = value.minute.toString().padLeft(2, '0');
    final period = value.hour >= 12 ? 'PM' : 'AM';
    return '${weekdays[value.weekday - 1]}, ${value.day} ${months[value.month - 1]} · $hour:$minute $period';
  }
}

class _ReservationSlotSheet extends StatefulWidget {
  final String propertyName;
  final List<ReservationSlot> slots;
  final ReservationSettings settings;

  const _ReservationSlotSheet({
    required this.propertyName,
    required this.slots,
    required this.settings,
  });

  @override
  State<_ReservationSlotSheet> createState() => _ReservationSlotSheetState();
}

class _ReservationSlotSheetState extends State<_ReservationSlotSheet> {
  int? _selectedId;
  String? _selectedDayKey;
  DateTime? _calendarMonth;

  String _dayKey(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';

  String _fullDayTitle(DateTime value) {
    const weekdays = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    return '${weekdays[value.weekday - 1]}, ${value.day} ${months[value.month - 1]}';
  }

  DateTime _monthOnly(DateTime value) => DateTime(value.year, value.month);

  bool _sameMonth(DateTime first, DateTime second) =>
      first.year == second.year && first.month == second.month;

  DateTime _shiftMonth(DateTime value, int amount) =>
      DateTime(value.year, value.month + amount);

  Widget _calendarView(
    BuildContext context, {
    required List<DateTime> sortedDates,
    required Map<String, DateTime> dayDates,
    required Map<String, List<ReservationSlot>> slotsByDay,
    required String selectedDayKey,
  }) {
    final colors = Theme.of(context).colorScheme;
    final firstMonth = _monthOnly(sortedDates.first);
    final lastMonth = _monthOnly(sortedDates.last);
    var month = _monthOnly(
        _calendarMonth ?? dayDates[selectedDayKey] ?? sortedDates.first);
    if (month.isBefore(firstMonth)) month = firstMonth;
    if (month.isAfter(lastMonth)) month = lastMonth;
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    final leadingEmptyDays = DateTime(month.year, month.month, 1).weekday - 1;
    final availableKeys = slotsByDay.keys.toSet();
    const weekdayLabels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    const monthLabels = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];

    return Container(
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Column(
        children: [
          Row(
            children: [
              IconButton(
                tooltip: 'Previous month',
                visualDensity: VisualDensity.compact,
                onPressed: _sameMonth(month, firstMonth)
                    ? null
                    : () => setState(() {
                          _calendarMonth = _shiftMonth(month, -1);
                        }),
                icon: const Icon(Icons.chevron_left_rounded),
              ),
              Expanded(
                child: Text(
                  '${monthLabels[month.month - 1]} ${month.year}',
                  textAlign: TextAlign.center,
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.w900),
                ),
              ),
              IconButton(
                tooltip: 'Next month',
                visualDensity: VisualDensity.compact,
                onPressed: _sameMonth(month, lastMonth)
                    ? null
                    : () => setState(() {
                          _calendarMonth = _shiftMonth(month, 1);
                        }),
                icon: const Icon(Icons.chevron_right_rounded),
              ),
            ],
          ),
          const SizedBox(height: 3),
          Row(
            children: weekdayLabels
                .map((label) => Expanded(
                      child: Center(
                        child: Text(
                          label,
                          style: TextStyle(
                            color: colors.onSurfaceVariant,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ))
                .toList(),
          ),
          const SizedBox(height: 5),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: leadingEmptyDays + daysInMonth,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              mainAxisExtent: 34,
              crossAxisSpacing: 4,
              mainAxisSpacing: 4,
            ),
            itemBuilder: (context, index) {
              if (index < leadingEmptyDays) return const SizedBox.shrink();
              final date = DateTime(
                month.year,
                month.month,
                index - leadingEmptyDays + 1,
              );
              final key = _dayKey(date);
              final availableForDay = availableKeys.contains(key);
              final selected = selectedDayKey == key;
              final count = slotsByDay[key]?.length ?? 0;
              final isToday = DateUtils.isSameDay(date, DateTime.now());
              final foreground = selected
                  ? colors.onPrimary
                  : availableForDay
                      ? colors.primary
                      : colors.onSurfaceVariant.withValues(alpha: .48);
              return Semantics(
                button: availableForDay,
                enabled: availableForDay,
                selected: selected,
                label: availableForDay
                    ? '${_fullDayTitle(date)}, $count time options available'
                    : '${_fullDayTitle(date)}, unavailable',
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: availableForDay
                      ? () => setState(() {
                            _selectedDayKey = key;
                            _selectedId = null;
                            _calendarMonth = _monthOnly(date);
                          })
                      : null,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 160),
                    decoration: BoxDecoration(
                      color: selected
                          ? colors.primary
                          : availableForDay
                              ? colors.primaryContainer.withValues(alpha: .58)
                              : Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                      border: isToday && !selected
                          ? Border.all(color: colors.primary, width: 1.2)
                          : null,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          '${date.day}',
                          style: TextStyle(
                            color: foreground,
                            fontSize: 13,
                            height: 1,
                            fontWeight: selected || availableForDay
                                ? FontWeight.w900
                                : FontWeight.w500,
                          ),
                        ),
                        if (availableForDay) ...[
                          const SizedBox(height: 1),
                          Text(
                            '$count',
                            style: TextStyle(
                              color: foreground.withValues(
                                  alpha: selected ? .88 : .72),
                              fontSize: 9,
                              height: 1,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final available = widget.slots
        .where((slot) => slot.isActive && slot.startsAt.isAfter(DateTime.now()))
        .toList()
      ..sort((a, b) => a.startsAt.compareTo(b.startsAt));
    final slotsByDay = <String, List<ReservationSlot>>{};
    final dayDates = <String, DateTime>{};
    for (final slot in available) {
      final localStart = slot.startsAt.toLocal();
      final key = _dayKey(localStart);
      slotsByDay.putIfAbsent(key, () => <ReservationSlot>[]).add(slot);
      dayDates[key] =
          DateTime(localStart.year, localStart.month, localStart.day);
    }
    final dayKeys = slotsByDay.keys.toList();
    final selectedDayKey = dayKeys.contains(_selectedDayKey)
        ? _selectedDayKey!
        : dayKeys.firstOrNull;
    // The calendar and time list are only built when at least one day exists.
    // Keeping a non-null local here also makes that invariant explicit to the
    // widgets below.
    final activeDayKey = selectedDayKey ?? '';
    final selectedDaySlots = selectedDayKey == null
        ? const <ReservationSlot>[]
        : slotsByDay[selectedDayKey] ?? const <ReservationSlot>[];

    return Material(
      color: colors.surface,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * .96,
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: colors.outlineVariant,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Reserve this home',
                              style: Theme.of(context).textTheme.headlineSmall),
                          const SizedBox(height: 5),
                          Text(
                            'Choose an available date and time for ${widget.propertyName}.',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Close',
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
                const SizedBox(height: 13),
                Expanded(
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.only(bottom: 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _ReservationAmountCard(
                          amount: widget.settings.reservationAmount,
                          downPaymentPercent:
                              widget.settings.downPaymentPercent,
                          currency: widget.settings.currency,
                        ),
                        const SizedBox(height: 12),
                        const _ReservationControlCard(),
                        const SizedBox(height: 16),
                        if (available.isEmpty)
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(18),
                            decoration: BoxDecoration(
                              color: colors.surfaceContainerLow,
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(color: colors.outlineVariant),
                            ),
                            child: const Text(
                                'No reservation dates are available right now.'),
                          )
                        else ...[
                          Row(
                            children: [
                              Text('Available dates',
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleMedium
                                      ?.copyWith(fontWeight: FontWeight.w800)),
                              const SizedBox(width: 8),
                              Flexible(
                                child: Text(
                                    '${dayKeys.length} ${dayKeys.length == 1 ? 'day' : 'days'} · ${available.length} time slots',
                                    textAlign: TextAlign.right,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                        color: colors.onSurfaceVariant,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700)),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          _calendarView(
                            context,
                            sortedDates: dayDates.values.toList()..sort(),
                            dayDates: dayDates,
                            slotsByDay: slotsByDay,
                            selectedDayKey: activeDayKey,
                          ),
                          const SizedBox(height: 10),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 13, vertical: 10),
                            decoration: BoxDecoration(
                              color:
                                  colors.primaryContainer.withValues(alpha: .4),
                              borderRadius: BorderRadius.circular(15),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.event_available_rounded,
                                    size: 20, color: colors.primary),
                                const SizedBox(width: 9),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        _fullDayTitle(dayDates[activeDayKey]!),
                                        style: TextStyle(
                                            color: colors.primary,
                                            fontWeight: FontWeight.w900),
                                      ),
                                      Text(
                                        '${selectedDaySlots.length} ${selectedDaySlots.length == 1 ? 'time option' : 'time options'} on this date',
                                        style: TextStyle(
                                            color: colors.onSurfaceVariant,
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Text('Choose a time window',
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleLarge
                                      ?.copyWith(fontWeight: FontWeight.w800)),
                              const Spacer(),
                              Text('${selectedDaySlots.length} options',
                                  style: TextStyle(
                                      color: colors.onSurfaceVariant,
                                      fontWeight: FontWeight.w700)),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Column(
                            children: selectedDaySlots.map((slot) {
                              final selected = slot.id == _selectedId;
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(17),
                                  onTap: () =>
                                      setState(() => _selectedId = slot.id),
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 160),
                                    constraints:
                                        const BoxConstraints(minHeight: 68),
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 15, vertical: 17),
                                    decoration: BoxDecoration(
                                      color: selected
                                          ? colors.primaryContainer
                                          : colors.surfaceContainerLow,
                                      borderRadius: BorderRadius.circular(17),
                                      border: Border.all(
                                        color: selected
                                            ? colors.primary
                                            : colors.outlineVariant,
                                        width: selected ? 1.4 : .8,
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(
                                          selected
                                              ? Icons
                                                  .radio_button_checked_rounded
                                              : Icons.radio_button_off_rounded,
                                          size: 28,
                                          color: selected
                                              ? colors.primary
                                              : colors.onSurfaceVariant,
                                        ),
                                        const SizedBox(width: 12),
                                        Icon(Icons.schedule_rounded,
                                            size: 23, color: colors.primary),
                                        const SizedBox(width: 9),
                                        Expanded(
                                          child: Text(
                                            _reservationTimeLabel(slot),
                                            style: Theme.of(context)
                                                .textTheme
                                                .titleMedium
                                                ?.copyWith(
                                                    fontWeight:
                                                        FontWeight.w800),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 5),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _selectedId == null
                        ? null
                        : () => Navigator.pop(context, _selectedId),
                    icon: const Icon(Icons.lock_outline_rounded, size: 18),
                    label: const Text('Continue to payment'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ReservationAmountCard extends StatelessWidget {
  final int amount;
  final int? downPaymentPercent;
  final String currency;
  final String? detail;

  const _ReservationAmountCard({
    required this.amount,
    this.downPaymentPercent,
    this.currency = 'ZMW',
    this.detail,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final currencyLabel =
        currency.toUpperCase() == 'ZMW' ? 'K' : currency.toUpperCase();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(15, 13, 13, 13),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            colors.primary.withValues(alpha: .12),
            colors.primaryContainer.withValues(alpha: .62),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(19),
        border: Border.all(color: colors.primary.withValues(alpha: .2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 45,
            height: 45,
            decoration: BoxDecoration(
              color: colors.primary,
              borderRadius: BorderRadius.circular(15),
            ),
            child:
                Icon(Icons.payments_rounded, color: colors.onPrimary, size: 23),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'YOU PAY TO RESERVE',
                  style: TextStyle(
                    color: colors.primary,
                    fontSize: 10,
                    letterSpacing: .8,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 1),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '$currencyLabel${_formatReservationAmount(amount)}',
                    style: TextStyle(
                      color: colors.primary,
                      fontSize: 28,
                      height: 1.08,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  detail ??
                      (downPaymentPercent == null
                          ? 'Refundable down payment'
                          : '$downPaymentPercent% refundable down payment'),
                  style: TextStyle(
                    color: colors.onSurface,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Icon(Icons.verified_rounded, color: colors.primary, size: 22),
        ],
      ),
    );
  }
}

class _ReservationControlCard extends StatefulWidget {
  const _ReservationControlCard();

  @override
  State<_ReservationControlCard> createState() =>
      _ReservationControlCardState();
}

class _ReservationControlCardState extends State<_ReservationControlCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow.withValues(alpha: .82),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colors.primary.withValues(alpha: .18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            button: true,
            expanded: _expanded,
            label: 'How the refundable down payment works',
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(18),
                onTap: () => setState(() => _expanded = !_expanded),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 13, 12, 13),
                  child: Row(
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: colors.primaryContainer,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.shield_outlined,
                            color: colors.primary, size: 18),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'How the down payment works',
                              style: TextStyle(
                                  color: colors.primary,
                                  fontWeight: FontWeight.w900),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _expanded
                                  ? 'Your money stays in your control.'
                                  : 'Refund any time · release when ready',
                              style: TextStyle(
                                color: colors.onSurfaceVariant,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      AnimatedRotation(
                        turns: _expanded ? .5 : 0,
                        duration: const Duration(milliseconds: 180),
                        child: Icon(Icons.keyboard_arrow_down_rounded,
                            color: colors.primary, size: 24),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            child: _expanded
                ? Padding(
                    padding: const EdgeInsets.fromLTRB(14, 0, 14, 13),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Divider(
                            height: 1,
                            color: colors.primary.withValues(alpha: .12)),
                        const SizedBox(height: 11),
                        _controlPoint(context, Icons.undo_rounded,
                            'Cancel the reservation whenever you want and get the down payment back.'),
                        const SizedBox(height: 7),
                        _controlPoint(context, Icons.key_rounded,
                            'Release it only after you have seen the home and received the keys.'),
                        const SizedBox(height: 7),
                        _controlPoint(context, Icons.handshake_outlined,
                            'Pay the remaining rent or deposit directly with the lister; this amount counts toward it.'),
                        const SizedBox(height: 9),
                        Text(
                          'A live refund may exclude the mobile-money provider fee. This demo applies no fee.',
                          style: TextStyle(
                            color: colors.onSurfaceVariant,
                            fontSize: 11,
                            height: 1.3,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  Widget _controlPoint(BuildContext context, IconData icon, String text) {
    final colors = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: colors.primary, size: 17),
        const SizedBox(width: 8),
        Expanded(
          child: Text(text,
              style: TextStyle(
                  color: colors.onSurface, fontSize: 12, height: 1.3)),
        ),
      ],
    );
  }
}

class _MobileMoneyPaymentSheet extends StatefulWidget {
  final int amount;
  final List<String> paymentMethods;

  const _MobileMoneyPaymentSheet({
    required this.amount,
    required this.paymentMethods,
  });

  @override
  State<_MobileMoneyPaymentSheet> createState() =>
      _MobileMoneyPaymentSheetState();
}

class _MobileMoneyPaymentSheetState extends State<_MobileMoneyPaymentSheet> {
  late String _selected;

  @override
  void initState() {
    super.initState();
    _selected = widget.paymentMethods.firstOrNull ?? 'airtel_money';
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final methods = widget.paymentMethods.isEmpty
        ? const ['airtel_money', 'mtn_money']
        : widget.paymentMethods;
    return Material(
      color: colors.surface,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
      child: SafeArea(
        top: false,
        child: ConstrainedBox(
          constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(context).height * .88),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                          color: colors.outlineVariant,
                          borderRadius: BorderRadius.circular(4))),
                ),
                const SizedBox(height: 18),
                Text('Pay the reservation amount',
                    style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: 5),
                Text(
                    'Choose a mobile-money provider to place your refundable down payment.',
                    style: Theme.of(context).textTheme.bodyMedium),
                const SizedBox(height: 14),
                _ReservationAmountCard(
                  amount: widget.amount,
                  detail: 'Refundable reservation amount',
                ),
                const SizedBox(height: 14),
                const _ReservationControlCard(),
                const SizedBox(height: 15),
                ...methods.map((method) {
                  final selected = method == _selected;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 9),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(17),
                      onTap: () => setState(() => _selected = method),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 160),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                            color: selected
                                ? colors.primaryContainer
                                : colors.surfaceContainerLow,
                            borderRadius: BorderRadius.circular(17),
                            border: Border.all(
                                color: selected
                                    ? colors.primary
                                    : colors.outlineVariant,
                                width: selected ? 1.4 : .8)),
                        child: Row(
                          children: [
                            Icon(
                                selected
                                    ? Icons.radio_button_checked_rounded
                                    : Icons.radio_button_off_rounded,
                                color: selected
                                    ? colors.primary
                                    : colors.onSurfaceVariant),
                            const SizedBox(width: 11),
                            Icon(Icons.phone_android_rounded,
                                color: colors.primary, size: 21),
                            const SizedBox(width: 9),
                            Text(_paymentMethodLabel(method),
                                style: const TextStyle(
                                    fontWeight: FontWeight.w700)),
                          ],
                        ),
                      ),
                    ),
                  );
                }),
                const SizedBox(height: 4),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(11),
                  decoration: BoxDecoration(
                      color: colors.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(14)),
                  child: Row(
                    children: [
                      Icon(Icons.science_outlined,
                          size: 18, color: colors.onSurfaceVariant),
                      const SizedBox(width: 8),
                      Expanded(
                          child: Text(
                              'Demo checkout · no real money moves yet.',
                              style: Theme.of(context).textTheme.bodySmall)),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () => Navigator.pop(context, _selected),
                    icon: const Icon(Icons.check_circle_outline_rounded),
                    label:
                        Text('Simulate successful payment · K${widget.amount}'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _paymentMethodLabel(String value) => value == 'mtn_money'
      ? 'MTN Money'
      : value == 'airtel_money'
          ? 'Airtel Money'
          : value;
}

String _reservationSlotLabel(ReservationSlot slot) {
  final start = slot.startsAt.toLocal();
  final hour = start.hour % 12 == 0 ? 12 : start.hour % 12;
  final minute = start.minute.toString().padLeft(2, '0');
  final period = start.hour >= 12 ? 'PM' : 'AM';
  final end = slot.endsAt?.toLocal();
  final endLabel = end == null
      ? ''
      : ' – ${end.hour % 12 == 0 ? 12 : end.hour % 12}:${end.minute.toString().padLeft(2, '0')} ${end.hour >= 12 ? 'PM' : 'AM'}';
  return '${_reservationDayLabel(start)} · $hour:$minute $period$endLabel';
}

String _formatReservationAmount(int amount) {
  final value = amount.toString();
  final firstGroupLength = value.length % 3 == 0 ? 3 : value.length % 3;
  final groups = <String>[value.substring(0, firstGroupLength)];
  for (var index = firstGroupLength; index < value.length; index += 3) {
    groups.add(value.substring(index, index + 3));
  }
  return groups.join(',');
}

String _reservationTimeLabel(ReservationSlot slot) {
  final start = slot.startsAt.toLocal();
  final end = slot.endsAt?.toLocal();
  String format(DateTime value) {
    final hour = value.hour % 12 == 0 ? 12 : value.hour % 12;
    final minute = value.minute.toString().padLeft(2, '0');
    final period = value.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $period';
  }

  return end == null ? format(start) : '${format(start)} – ${format(end)}';
}

String _reservationDayLabel(DateTime value) {
  const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  const months = [
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
    'Dec'
  ];
  return '${weekdays[value.weekday - 1]}, ${value.day} ${months[value.month - 1]}';
}

class Details extends StatefulWidget {
  final House house;
  final bool isOwnerView;
  final bool isPreview;

  const Details({
    Key? key,
    required this.house,
    this.isOwnerView = false,
    this.isPreview = false,
  }) : super(key: key);

  /// A lightweight transition keeps the first details frame smooth on Android
  /// while the gallery, videos, owner data, and map initialize behind it.
  static Route<void> route(House house, {bool isOwnerView = false}) {
    return _DetailsPageRoute(
      house: house,
      isOwnerView: isOwnerView,
    );
  }

  @override
  State<Details> createState() => _DetailsState();
}

class _DetailsState extends State<Details> {
  int _reviewVersion = 0;
  late Future<Map<String, dynamic>> _ownerFuture;
  late Future<List<ViewingSummary>> _ownerViewingsFuture;
  late Future<NotificationInbox> _ownerNotificationsFuture;
  late Future<ReservationState> _reservationFuture;
  bool _reservationBusy = false;
  bool _interestBusy = false;
  bool _ownerLoaded = false;
  bool _canReview = false;
  bool _resolvedOwnerView = false;

  bool get _isOwnerView => widget.isOwnerView || _resolvedOwnerView;

  String get _offlineAge {
    final cachedAt = widget.house.cachedAt;
    if (cachedAt == null) return 'saved previously';
    final age = DateTime.now().difference(cachedAt);
    if (age.inMinutes < 2) return 'saved moments ago';
    if (age.inHours < 1) return 'saved ${age.inMinutes} minutes ago';
    if (age.inDays < 1) return 'saved ${age.inHours} hours ago';
    return 'saved ${age.inDays} days ago';
  }

  @override
  void initState() {
    super.initState();
    _resolvedOwnerView = widget.isOwnerView || _matchesSignedInOwner();
    // Owner details are only needed when the contact sheet opens. Deferring
    // this request keeps the route's first frames free for the transition.
    _ownerFuture = Future.value(widget.house.ownerContact);
    _ownerViewingsFuture = _isOwnerView && !widget.isPreview
        ? MarketplaceService.instance.viewings()
        : Future.value(const <ViewingSummary>[]);
    _ownerNotificationsFuture = _isOwnerView && !widget.isPreview
        ? MarketplaceService.instance.notifications()
        : Future.value(const NotificationInbox(unreadCount: 0, items: []));
    _reservationFuture = widget.isPreview
        ? Future.value(const ReservationState(
            isReserved: false,
            isMine: false,
            isInterested: false,
            reservation: null,
            slots: [],
          ))
        : MarketplaceService.instance.reservationState(widget.house.id);
    unawaited(PropertyDetailsService.cacheOwnerContact(
        widget.house.id, widget.house.ownerContact));
    if (!_isOwnerView && !widget.isPreview) {
      unawaited(_loadReviewEligibility());
      House.recordView(widget.house.id);
      SessionRecommendation.instance.observe(widget.house, 1.1);
      unawaited(RecommendationService.instance
          .track('details', widget.house.id, surface: 'details'));
    }
    if (!widget.isPreview && !_isOwnerView) {
      unawaited(_resolveSignedInOwner());
    }
  }

  bool _matchesSignedInOwner() {
    final ownerId = widget.house.ownerId;
    final userId = _userId(SessionService.cachedUser);
    return ownerId != null && userId != null && ownerId == userId;
  }

  Future<void> _resolveSignedInOwner() async {
    if (widget.house.ownerId == null) return;
    final user = await SessionService.currentUser();
    final userId = _userId(user);
    if (!mounted || userId != widget.house.ownerId || _isOwnerView) return;
    // Assign the futures before the synchronous state update. This keeps the
    // page safe even when account hydration finishes during the first frame.
    final viewings = MarketplaceService.instance.viewings();
    final notifications = MarketplaceService.instance.notifications();
    setState(() {
      _resolvedOwnerView = true;
      _ownerViewingsFuture = viewings;
      _ownerNotificationsFuture = notifications;
    });
  }

  int? _userId(Map<String, dynamic>? user) {
    final value = user?['id'];
    if (value is num) return value.toInt();
    return int.tryParse('$value');
  }

  Future<void> _loadReviewEligibility() async {
    if (widget.house.ownerId == null) return;
    final token =
        (await SharedPreferences.getInstance()).getString('access_token');
    if (token == null) return;
    try {
      final result = await MarketplaceService.instance
          .reviewEligibility(widget.house.ownerId!, widget.house.id);
      if (mounted) setState(() => _canReview = result.eligible);
    } catch (_) {
      // Eligibility is fail-closed: no CTA is shown when it cannot be verified.
    }
  }

  String _whatsAppDigits(String value) {
    var digits = value.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.startsWith('0')) digits = '260${digits.substring(1)}';
    if (digits.length == 9) digits = '260$digits';
    return digits;
  }

  Future<void> _openWhatsApp(String number) async {
    final digits = _whatsAppDigits(number);
    if (digits.length < 10) {
      _notice('This lister’s WhatsApp number is not valid yet.');
      return;
    }
    final text =
        'Hi, I found “${widget.house.name}” on Haven Zambia and would like to know more.';
    final appUri = Uri(
        scheme: 'whatsapp',
        host: 'send',
        queryParameters: {'phone': digits, 'text': text});
    if (await launchUrl(appUri, mode: LaunchMode.externalApplication)) return;
    final webUri = Uri.https('wa.me', '/$digits', {'text': text});
    if (!await launchUrl(webUri, mode: LaunchMode.externalApplication)) {
      _notice('Could not open WhatsApp on this device.');
    }
  }

  void _ensureOwnerLoaded() {
    if (_ownerLoaded) return;
    _ownerLoaded = true;
    _ownerFuture = PropertyDetailsService.owner(widget.house.id)
        .onError((_, __) => widget.house.ownerContact);
  }

  Future<void> _callOwner(String number) async {
    if (!await launchUrl(Uri(scheme: 'tel', path: number))) {
      _notice('Calling is not available on this device.');
    }
  }

  Future<void> _submitReview(int rating, String comment) async {
    if (widget.house.ownerId == null) return;
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access_token');
    if (token == null) {
      _notice('Sign in to review this owner.');
      return;
    }
    try {
      final response = await http
          .post(
            Uri.parse(
                '${ApiConfig.apiBase}/users/${widget.house.ownerId}/review'),
            headers: {
              'Authorization': 'Bearer $token',
              'Content-Type': 'application/json',
              'Accept': 'application/json'
            },
            body: json.encode({
              'house_id': widget.house.id,
              'rating': rating,
              'comment': comment,
            }),
          )
          .timeout(const Duration(seconds: 15));
      if (response.statusCode == 201 || response.statusCode == 202) {
        final data = json.decode(response.body);
        await ListerReviewsService.invalidate(widget.house.ownerId!);
        if (mounted) setState(() => _reviewVersion++);
        if (mounted) setState(() => _canReview = false);
        _notice(data['message'] ?? 'Thanks—your review was received.');
      } else {
        throw HavenApiException.fromResponse(response,
            operation: 'submit your review');
      }
    } catch (error) {
      _notice(ApiErrorResolver.message(error,
          fallback: 'Haven could not submit your review.'));
    }
  }

  void _notice(String value) {
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(value)));
    }
  }

  Future<void> _showReview() async {
    if (widget.house.ownerId == null) return;
    try {
      final eligibility = await MarketplaceService.instance
          .reviewEligibility(widget.house.ownerId!, widget.house.id);
      if (!eligibility.eligible) {
        _notice(eligibility.reason ??
            'Complete a genuine interaction before leaving a review.');
        return;
      }
    } on MarketplaceException catch (error) {
      _notice(error.message);
      return;
    }
    if (!mounted) return;
    var rating = 5;
    final comment = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, update) => Padding(
          padding:
              EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
          child: Container(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 28),
            decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(26))),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Align(
                    child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.outlineVariant,
                            borderRadius: BorderRadius.circular(4)))),
                const SizedBox(height: 22),
                Text('Share your experience',
                    style: Theme.of(context).textTheme.headlineMedium),
                const SizedBox(height: 6),
                Text(
                    'Review the lister based on a genuine property enquiry or experience.',
                    style: Theme.of(context).textTheme.bodyMedium),
                const SizedBox(height: 14),
                Row(
                  children: List.generate(
                      5,
                      (index) => IconButton(
                            onPressed: () => update(() => rating = index + 1),
                            icon: Icon(
                                index < rating
                                    ? Icons.star_rounded
                                    : Icons.star_border_rounded,
                                color: AppColors.warning,
                                size: 31),
                          )),
                ),
                const SizedBox(height: 10),
                TextField(
                    controller: comment,
                    maxLines: 3,
                    decoration: const InputDecoration(
                        hintText:
                            'What went well, or what should others know?')),
                const SizedBox(height: 10),
                Text(
                  'Reviews must be honest, specific, and at least 20 characters. Suspicious activity may be held for moderation.',
                  style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontSize: 11,
                      height: 1.4),
                ),
                const SizedBox(height: 18),
                ElevatedButton(
                  onPressed: () {
                    if (comment.text.trim().length < 20) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                          content: Text(
                              'Please add at least 20 characters about your experience.')));
                      return;
                    }
                    Navigator.pop(context);
                    _submitReview(rating, comment.text.trim());
                  },
                  child: const Text('Submit review'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _messageOwner() async {
    if (!NetworkStatusService.instance.isOnline) {
      await _composeOfflineMessage();
      return;
    }
    try {
      final conversationId =
          await MarketplaceService.instance.startConversation(widget.house.id);
      if (!mounted) return;
      Navigator.of(context).pop();
      Navigator.push(
          context,
          HavenPageRoute(
              builder: (_) => ConversationScreen(
                    conversationId: conversationId,
                    propertyTitle: widget.house.name,
                    participantName: widget.house.ownerName ?? 'Property owner',
                    participantPhone: widget.house.ownerPhone,
                    participantWhatsApp: widget.house.ownerWhatsApp,
                    participantEmail: widget.house.ownerEmail,
                  )));
    } on MarketplaceException catch (error) {
      if (!await NetworkStatusService.instance.checkNow()) {
        await _composeOfflineMessage();
      } else {
        _notice(error.message);
      }
    }
  }

  Future<void> _composeOfflineMessage() async {
    Navigator.of(context).pop();
    await Future<void>.delayed(const Duration(milliseconds: 180));
    if (!mounted) return;
    final controller = TextEditingController();
    final message = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.fromLTRB(
            20, 18, 20, 18 + MediaQuery.viewInsetsOf(sheetContext).bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Write an offline message',
                style: Theme.of(sheetContext).textTheme.headlineSmall),
            const SizedBox(height: 6),
            Text(
              'Haven will send it automatically when the server is reachable.',
              style: Theme.of(sheetContext).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              autofocus: true,
              minLines: 3,
              maxLines: 6,
              maxLength: 2000,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                labelText: 'Message about ${widget.house.name}',
                hintText: 'Hi, is this home still available?',
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  final value = controller.text.trim();
                  if (value.isEmpty) return;
                  Navigator.pop(sheetContext, value);
                },
                icon: const Icon(Icons.cloud_upload_outlined),
                label: const Text('Save and send when online'),
              ),
            ),
          ],
        ),
      ),
    );
    controller.dispose();
    if (message == null || !mounted) return;
    await OfflineSyncService.instance
        .queueContactMessage(widget.house.id, message);
    _notice(
        'Message saved on this device · it will send when Haven reconnects.');
  }

  Future<void> _requestViewing() async {
    final schedule = await showModalBottomSheet<_ViewingSchedule>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => const _ViewingSchedulerSheet(),
    );
    if (schedule == null || !mounted) return;
    try {
      final message = await MarketplaceService.instance.requestViewing(
          widget.house.id, schedule.requestedAt,
          note: schedule.note);
      if (!mounted) return;
      Navigator.of(context).pop();
      _notice(message);
    } on MarketplaceException catch (error) {
      _notice(error.message);
    }
  }

  Widget _reservationAvailabilitySection() {
    final colors = Theme.of(context).colorScheme;
    return FutureBuilder<ReservationState>(
      future: _reservationFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Container(
            margin: const EdgeInsets.symmetric(horizontal: 20),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: colors.surfaceContainerLow,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: colors.outlineVariant),
            ),
            child: Row(
              children: [
                SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                      strokeWidth: 2.2, color: colors.primary),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text('Checking reservation availability…'),
                ),
              ],
            ),
          );
        }
        if (snapshot.hasError) {
          return _reservationUnavailable(ApiErrorResolver.message(
              snapshot.error!,
              fallback:
                  'Paid reservation availability is temporarily unavailable.'));
        }
        final state = snapshot.data;
        if (state == null) return const SizedBox.shrink();

        final available = state.slots
            .where((slot) =>
                slot.isActive && slot.startsAt.isAfter(DateTime.now()))
            .toList();
        final hasDates = state.canAcceptReservations &&
            !state.isReserved &&
            available.isNotEmpty;
        final unavailable = !state.canAcceptReservations && !state.isReserved;
        final isMine = state.isMine && state.isReserved;
        final title = isMine
            ? 'Your paid reservation is active'
            : state.isReserved
                ? 'Currently held by a paid reservation'
                : unavailable
                    ? 'Paid reservation unavailable right now'
                    : hasDates
                        ? 'Reserve with a down payment'
                        : 'Paid reservation dates coming soon';
        final message = isMine
            ? 'You have a paid reservation on this home. Viewings can still be requested.'
            : state.isReserved
                ? 'This home is currently held by a paid reservation, but viewing requests remain open.'
                : unavailable
                    ? 'The lister is not accepting paid reservations for this home right now. Normal viewing requests remain open.'
                    : hasDates
                        ? 'Choose a date and time, then pay the refundable down payment. Normal viewing requests stay open too.'
                        : 'The lister has not opened a paid reservation date yet. We can notify you when one becomes available.';
        final label = isMine || state.isReserved
            ? 'PAID RESERVATION ON HOLD'
            : unavailable
                ? 'PAID RESERVATIONS PAUSED'
                : hasDates
                    ? 'PAID RESERVATION AVAILABLE'
                    : 'STAY IN THE LOOP';

        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 20),
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                colors.primaryContainer.withValues(alpha: .92),
                colors.surfaceContainerLow,
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: colors.primary.withValues(alpha: .18)),
            boxShadow: [
              BoxShadow(
                color: colors.primary.withValues(alpha: .08),
                blurRadius: 22,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: colors.primary,
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: Icon(
                      isMine || state.isReserved
                          ? Icons.verified_rounded
                          : Icons.event_available_rounded,
                      color: colors.onPrimary,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 13),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(label,
                            style: TextStyle(
                                color: colors.primary,
                                fontSize: 11,
                                letterSpacing: .7,
                                fontWeight: FontWeight.w900)),
                        const SizedBox(height: 4),
                        Text(title,
                            style: Theme.of(context)
                                .textTheme
                                .titleLarge
                                ?.copyWith(fontWeight: FontWeight.w800)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 13),
              if (hasDates || isMine) ...[
                _ReservationAmountCard(
                  amount: state.settings.reservationAmount,
                  downPaymentPercent: state.settings.downPaymentPercent,
                  currency: state.settings.currency,
                ),
                const SizedBox(height: 11),
              ],
              Text(message, style: Theme.of(context).textTheme.bodyMedium),
              if (hasDates || isMine) ...[
                const SizedBox(height: 12),
                const _ReservationControlCard(),
              ],
              if (hasDates) ...[
                const SizedBox(height: 14),
                Text('Next available dates',
                    style: TextStyle(
                        color: colors.onSurfaceVariant,
                        fontSize: 12,
                        fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 7,
                  runSpacing: 7,
                  children: available
                      .take(3)
                      .map((slot) => Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 8),
                            decoration: BoxDecoration(
                              color: colors.surface.withValues(alpha: .78),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                  color: colors.primary.withValues(alpha: .18)),
                            ),
                            child: Text(
                              _reservationSlotLabel(slot),
                              style: TextStyle(
                                  color: colors.onSurface,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700),
                            ),
                          ))
                      .toList(),
                ),
              ],
              const SizedBox(height: 15),
              if (hasDates && !state.isReserved)
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _reservationBusy ? null : _reserveHome,
                    icon: _reservationBusy
                        ? const SizedBox(
                            width: 17,
                            height: 17,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.lock_outline_rounded, size: 18),
                    label: const Text('Choose a date & payment'),
                  ),
                )
              else if (isMine)
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => Navigator.push(
                      context,
                      HavenPageRoute(
                          builder: (_) =>
                              const MarketplaceHubScreen(initialTab: 4)),
                    ),
                    icon: const Icon(Icons.event_note_outlined, size: 18),
                    label: const Text('View my paid reservation'),
                  ),
                )
              else
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed:
                        _interestBusy ? null : _toggleReservationInterest,
                    icon: _interestBusy
                        ? const SizedBox(
                            width: 17,
                            height: 17,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : Icon(state.isInterested
                            ? Icons.notifications_active_outlined
                            : Icons.notifications_none_outlined),
                    label: Text(state.isInterested
                        ? 'Availability alerts are on'
                        : state.isReserved
                            ? 'Alert me when available again'
                            : 'Alert me when dates open'),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _reservationAction() {
    return FutureBuilder<ReservationState>(
      future: _reservationFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: null,
              icon: const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2)),
              label: const Text('Checking paid reservation dates'),
            ),
          );
        }
        if (snapshot.hasError) {
          return _reservationUnavailable(ApiErrorResolver.message(
              snapshot.error!,
              fallback:
                  'Paid reservation availability is temporarily unavailable.'));
        }
        final state = snapshot.data;
        if (state == null) return const SizedBox.shrink();
        final hasAvailableSlots = state.slots.any(
            (slot) => slot.isActive && slot.startsAt.isAfter(DateTime.now()));
        if (state.isReserved) {
          final banner = Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.tertiaryContainer,
                borderRadius: BorderRadius.circular(15),
              ),
              child: Row(
                children: [
                  Icon(Icons.verified_outlined,
                      size: 19,
                      color: Theme.of(context).colorScheme.onTertiaryContainer),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Text(
                      state.isMine
                          ? 'You have a paid reservation on this home. Viewings can still be requested.'
                          : 'This home is currently held by a paid reservation. Viewings can still be requested.',
                      style: TextStyle(
                        color:
                            Theme.of(context).colorScheme.onTertiaryContainer,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ));
          if (state.isMine) return banner;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              banner,
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: _interestBusy ? null : _toggleReservationInterest,
                icon: _interestBusy
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : Icon(state.isInterested
                        ? Icons.notifications_active_outlined
                        : Icons.notifications_none_outlined),
                label: Text(state.isInterested
                    ? 'Turn off availability alerts'
                    : 'Alert me when available again'),
              ),
            ],
          );
        }
        if (!state.canAcceptReservations) {
          return Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(15),
              border: Border.all(
                  color: Theme.of(context).colorScheme.outlineVariant),
            ),
            child: Row(
              children: [
                Icon(Icons.pause_circle_outline,
                    size: 19,
                    color: Theme.of(context).colorScheme.onSurfaceVariant),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(
                    'Paid reservations are paused for this listing. Normal viewing requests remain available.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ],
            ),
          );
        }
        if (!hasAvailableSlots) {
          return SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _interestBusy ? null : _toggleReservationInterest,
              icon: _interestBusy
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : Icon(state.isInterested
                      ? Icons.notifications_active_outlined
                      : Icons.notifications_none_outlined),
              label: Text(state.isInterested
                  ? 'Availability alerts are on'
                  : 'Alert me when dates open'),
            ),
          );
        }
        return SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed:
                _reservationBusy ? null : () => _reserveHome(closeAfter: true),
            icon: _reservationBusy
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.lock_outline_rounded),
            label: const Text('Pay down payment & reserve'),
          ),
        );
      },
    );
  }

  Widget _reservationUnavailable(String message) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.errorContainer.withValues(alpha: .55),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.cloud_off_outlined,
              size: 19, color: colors.onErrorContainer),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(message, style: TextStyle(color: colors.onErrorContainer)),
                const SizedBox(height: 5),
                TextButton(
                  onPressed: _reservationBusy ? null : _refreshReservationState,
                  style: TextButton.styleFrom(
                      padding: EdgeInsets.zero, minimumSize: Size.zero),
                  child: const Text('Try again'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _refreshReservationState() {
    if (!mounted) return;
    setState(() {
      _reservationFuture = MarketplaceService.instance
          .reservationState(widget.house.id, refresh: true);
    });
  }

  Future<void> _reserveHome({bool closeAfter = false}) async {
    setState(() => _reservationBusy = true);
    try {
      final state = await MarketplaceService.instance
          .reservationState(widget.house.id, refresh: true);
      if (!mounted) return;
      final slotId = await showModalBottomSheet<int>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        backgroundColor: Colors.transparent,
        builder: (_) => _ReservationSlotSheet(
          propertyName: widget.house.name,
          slots: state.slots,
          settings: state.settings,
        ),
      );
      if (slotId == null || !mounted) return;
      final paymentMethod = await showModalBottomSheet<String>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        backgroundColor: Colors.transparent,
        builder: (_) => _MobileMoneyPaymentSheet(
          amount: state.settings.reservationAmount,
          paymentMethods: state.settings.paymentMethods,
        ),
      );
      if (paymentMethod == null || !mounted) return;
      await Future<void>.delayed(const Duration(milliseconds: 450));
      if (!mounted) return;
      await MarketplaceService.instance
          .reserveHome(widget.house.id, slotId, paymentMethod);
      if (!mounted) return;
      if (closeAfter) Navigator.of(context).pop();
      _notice('Paid reservation confirmed. You can manage it from Your Haven.');
      setState(() {
        _reservationFuture = MarketplaceService.instance
            .reservationState(widget.house.id, refresh: true);
      });
    } on MarketplaceException catch (error) {
      if (mounted) _notice(error.message);
    } finally {
      if (mounted) setState(() => _reservationBusy = false);
    }
  }

  Future<void> _toggleReservationInterest() async {
    setState(() => _interestBusy = true);
    try {
      final current = await _reservationFuture;
      if (!mounted) return;
      if (current.isInterested) {
        await MarketplaceService.instance
            .leaveReservationInterest(widget.house.id);
      } else {
        await MarketplaceService.instance
            .joinReservationInterest(widget.house.id);
      }
      if (mounted) {
        setState(() {
          _reservationFuture = MarketplaceService.instance
              .reservationState(widget.house.id, refresh: true);
        });
        _notice(current.isInterested
            ? 'Availability alerts turned off.'
            : 'We will notify you when this home is available again.');
      }
    } on MarketplaceException catch (error) {
      if (mounted) _notice(error.message);
    } finally {
      if (mounted) setState(() => _interestBusy = false);
    }
  }

  Future<void> _showSafetyOptions() async {
    await showCupertinoModalPopup<void>(
      context: context,
      builder: (context) => CupertinoActionSheet(
        title: const Text('Safety options'),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(context);
              _reportListing();
            },
            child: const Text('Report listing'),
          ),
          CupertinoActionSheetAction(
            isDestructiveAction: true,
            onPressed: () {
              Navigator.pop(context);
              _blockLister();
            },
            child: const Text('Block lister'),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          isDefaultAction: true,
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
      ),
    );
  }

  Future<void> _reportListing() async {
    String reason = 'scam';
    final details = TextEditingController();
    final submitted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, update) => AlertDialog(
          title: const Text('Report this listing'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            DropdownButtonFormField<String>(
              initialValue: reason,
              items: const [
                DropdownMenuItem(value: 'scam', child: Text('Possible scam')),
                DropdownMenuItem(
                    value: 'misleading', child: Text('Misleading information')),
                DropdownMenuItem(
                    value: 'unavailable', child: Text('No longer available')),
                DropdownMenuItem(
                    value: 'spam', child: Text('Spam or duplicate')),
                DropdownMenuItem(value: 'other', child: Text('Something else')),
              ],
              onChanged: (value) => update(() => reason = value ?? reason),
            ),
            const SizedBox(height: 12),
            TextField(
                controller: details,
                maxLines: 3,
                decoration: const InputDecoration(
                    labelText: 'Tell us more (optional)')),
          ]),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Cancel')),
            FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('Send report')),
          ],
        ),
      ),
    );
    if (submitted != true) return;
    try {
      final message = await MarketplaceService.instance
          .reportListing(widget.house.id, reason, details: details.text);
      _notice(message);
    } on MarketplaceException catch (error) {
      _notice(error.message);
    }
  }

  Future<void> _blockLister() async {
    if (widget.house.ownerId == null) return;
    final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
              title: const Text('Block this lister?'),
              content: const Text(
                  'They will no longer be able to message you. You can contact support if you need to reverse this later.'),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(dialogContext, false),
                    child: const Text('Cancel')),
                FilledButton(
                    onPressed: () => Navigator.pop(dialogContext, true),
                    child: const Text('Block'))
              ],
            ));
    if (confirmed != true) return;
    try {
      await MarketplaceService.instance.blockUser(widget.house.ownerId!);
      _notice('Lister blocked.');
    } on MarketplaceException catch (error) {
      _notice(error.message);
    }
  }

  String _responseTime(int minutes) {
    if (minutes < 60) return 'within ${minutes.clamp(1, 59)} min';
    if (minutes < 1440) return 'within ${(minutes / 60).round()} hr';
    return 'within ${(minutes / 1440).round()} day';
  }

  void _showContact() {
    _ensureOwnerLoaded();
    SessionRecommendation.instance.observe(widget.house, 4.5);
    unawaited(RecommendationService.instance
        .track('contact', widget.house.id, surface: 'details'));
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final colors = Theme.of(context).colorScheme;
        final dark = Theme.of(context).brightness == Brightness.dark;
        const radius = BorderRadius.vertical(top: Radius.circular(30));
        return GlassSurface(
          borderRadius: radius,
          blur: 28,
          tint: colors.surface.withValues(alpha: dark ? .82 : .76),
          borderColor: Colors.white.withValues(alpha: dark ? .2 : .68),
          shadows: [
            BoxShadow(
              color: colors.shadow.withValues(alpha: dark ? .34 : .16),
              blurRadius: 34,
              offset: const Offset(0, -8),
            ),
          ],
          child: Container(
            constraints: BoxConstraints(
                maxHeight: MediaQuery.sizeOf(context).height * .82),
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 20),
            child: FutureBuilder<Map<String, dynamic>>(
              future: _ownerFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const SizedBox(
                      height: 180,
                      child: Center(child: CircularProgressIndicator()));
                }
                final user = snapshot.data ?? {};
                final phone = user['phone_number']?.toString() ?? '';
                final whatsapp = user['whatsapp_number']?.toString() ?? '';
                final samePhoneAndWhatsApp = phone.isNotEmpty &&
                    whatsapp.isNotEmpty &&
                    _whatsAppDigits(phone) == _whatsAppDigits(whatsapp);
                return SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Align(
                          child: Container(
                              width: 40,
                              height: 4,
                              decoration: BoxDecoration(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .outlineVariant,
                                  borderRadius: BorderRadius.circular(4)))),
                      const SizedBox(height: 16),
                      Text('Contact the owner',
                          style: Theme.of(context).textTheme.headlineMedium),
                      const SizedBox(height: 6),
                      Text(
                          'Mention “${widget.house.name}” when you get in touch.',
                          style: Theme.of(context).textTheme.bodyMedium),
                      if (!NetworkStatusService.instance.isOnline) ...[
                        const SizedBox(height: 12),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: colors.primaryContainer
                                .withValues(alpha: dark ? .24 : .5),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Row(children: [
                            Icon(Icons.cloud_off_outlined,
                                size: 19, color: colors.primary),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                phone.isEmpty && whatsapp.isEmpty
                                    ? 'Offline · contact numbers were not downloaded on this device yet. You can still save a Haven message.'
                                    : 'Offline · showing saved contact details. Calls work now and Haven messages will send after reconnection.',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ),
                          ]),
                        ),
                      ],
                      const SizedBox(height: 14),
                      _ContactRow(
                          icon: Icons.phone_outlined,
                          label: samePhoneAndWhatsApp
                              ? 'Phone & WhatsApp'
                              : 'Phone',
                          value: phone.isEmpty ? 'Not provided' : phone),
                      if (whatsapp.isNotEmpty && !samePhoneAndWhatsApp)
                        _ContactRow(
                            icon: Icons.chat_outlined,
                            label: 'WhatsApp',
                            value: whatsapp),
                      _ContactRow(
                          icon: Icons.mail_outline_rounded,
                          label: 'Email',
                          value: user['email'] ?? 'Not provided'),
                      if (user['company'] != null)
                        _ContactRow(
                            icon: Icons.business_outlined,
                            label: 'Company',
                            value: user['company']),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _messageOwner,
                          icon: const Icon(Icons.forum_outlined),
                          label: const Text('Message in Haven'),
                        ),
                      ),
                      const SizedBox(height: 8),
                      _reservationAction(),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: _requestViewing,
                          icon: const Icon(Icons.calendar_month_outlined),
                          label: const Text('Request a viewing'),
                        ),
                      ),
                      if (phone.isNotEmpty || whatsapp.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Row(children: [
                          if (phone.isNotEmpty)
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () => _callOwner(phone),
                                icon: const Icon(Icons.phone_outlined),
                                label: const Text('Call'),
                              ),
                            ),
                          if (phone.isNotEmpty && whatsapp.isNotEmpty)
                            const SizedBox(width: 10),
                          if (whatsapp.isNotEmpty)
                            Expanded(
                              child: ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF168C4B),
                                  foregroundColor: Colors.white,
                                ),
                                onPressed: () => _openWhatsApp(whatsapp),
                                icon: const Icon(Icons.chat_rounded),
                                label: const Text('WhatsApp'),
                              ),
                            ),
                        ]),
                      ],
                    ],
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final ownerName = widget.house.ownerName ?? 'Property owner';
    return Scaffold(
      extendBody: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
              child: DetailsAppBar(
                  house: widget.house, isPreview: widget.isPreview)),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.only(top: 24, bottom: 116),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ContentIntro(house: widget.house),
                  if (_isOwnerView && !widget.isPreview) ...[
                    const SizedBox(height: 16),
                    _OwnerListingActions(house: widget.house),
                    const SizedBox(height: 10),
                    _OwnerPropertyUpdates(
                      house: widget.house,
                      future: _ownerNotificationsFuture,
                      onOpen: () => Navigator.push(
                        context,
                        HavenPageRoute(
                          builder: (_) =>
                              ListingManagementScreen(house: widget.house),
                        ),
                      ),
                    ),
                  ],
                  if (!_isOwnerView && !widget.isPreview) ...[
                    const SizedBox(height: 16),
                    _reservationAvailabilitySection(),
                  ],
                  if (widget.house.isFromCache) ...[
                    const SizedBox(height: 12),
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 20),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 9),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surfaceContainer,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(children: [
                        Icon(Icons.offline_pin_outlined,
                            size: 17,
                            color: Theme.of(context).colorScheme.primary),
                        const SizedBox(width: 8),
                        Expanded(
                            child: Text('Available offline · $_offlineAge',
                                style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600))),
                      ]),
                    ),
                  ],
                  if (_isOwnerView && !widget.isPreview) ...[
                    const SizedBox(height: 14),
                    _PendingViewingsBanner(
                        houseId: widget.house.id, future: _ownerViewingsFuture),
                  ],
                  const SizedBox(height: 24),
                  HouseInfo(house: widget.house),
                  if (widget.house.amenities.isNotEmpty ||
                      widget.house.gym == 1 ||
                      widget.house.swimmingPool == 1 ||
                      widget.house.garage == 1 ||
                      widget.house.carGarage > 0) ...[
                    const SizedBox(height: 24),
                    HouseAmenities(house: widget.house),
                  ],
                  const SizedBox(height: 28),
                  HouseGallery(houseId: widget.house.id),
                  const SizedBox(height: 30),
                  ListingVideosSection(houseId: widget.house.id),
                  const SizedBox(height: 30),
                  About(house: widget.house),
                  const SizedBox(height: 30),
                  HouseLocationMap(house: widget.house),
                  const SizedBox(height: 30),
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 20),
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                        color:
                            Theme.of(context).colorScheme.surfaceContainerLow,
                        border: Border.all(
                            color:
                                Theme.of(context).colorScheme.outlineVariant),
                        borderRadius: BorderRadius.circular(18)),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            CircleAvatar(
                              radius: 24,
                              backgroundColor: Theme.of(context)
                                  .colorScheme
                                  .primaryContainer,
                              child: Text(ownerName[0].toUpperCase(),
                                  style: TextStyle(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onPrimaryContainer,
                                      fontWeight: FontWeight.w800)),
                            ),
                            const SizedBox(width: 13),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(ownerName,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 16)),
                                  if (widget.house.isVerified ||
                                      widget.house.isTopRated) ...[
                                    const SizedBox(height: 7),
                                    ListerTrustBadges(
                                        verified: widget.house.isVerified,
                                        topRated: widget.house.isTopRated,
                                        compact: true),
                                  ],
                                  if (widget.house.totalReviews > 0) ...[
                                    const SizedBox(height: 6),
                                    Text(
                                        '${widget.house.averageRating.toStringAsFixed(1)} rating · ${widget.house.totalReviews} reviews',
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodyMedium),
                                  ],
                                  if (widget.house.responseRate > 0) ...[
                                    const SizedBox(height: 5),
                                    Text(
                                      '${widget.house.responseRate.round()}% response rate${widget.house.typicalResponseMinutes == null ? '' : ' · usually replies ${_responseTime(widget.house.typicalResponseMinutes!)}'}',
                                      style:
                                          Theme.of(context).textTheme.bodySmall,
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            if (!_isOwnerView)
                              CupertinoButton(
                                padding: const EdgeInsets.all(8),
                                minimumSize: Size.zero,
                                pressedOpacity: .65,
                                onPressed: _showSafetyOptions,
                                child: const Icon(
                                    CupertinoIcons.ellipsis_circle,
                                    size: 24),
                              ),
                          ],
                        ),
                        if (_canReview) ...[
                          const SizedBox(height: 14),
                          SizedBox(
                              width: double.infinity,
                              child: OutlinedButton(
                                  onPressed: _showReview,
                                  child: const Text('Review this owner'))),
                        ],
                      ],
                    ),
                  ),
                  if (widget.house.ownerId != null) ...[
                    const SizedBox(height: 30),
                    ListerReviewsSection(
                      key: ValueKey('${widget.house.ownerId}:$_reviewVersion'),
                      listerId: widget.house.ownerId!,
                      onAddReview: _canReview ? _showReview : null,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: _isOwnerView
          ? null
          : widget.isPreview
              ? const _PreviewModeBar()
              : SafeArea(
                  minimum: const EdgeInsets.fromLTRB(20, 10, 20, 14),
                  child: GlassSurface(
                    borderRadius: BorderRadius.circular(18),
                    blur: 24,
                    tint: Theme.of(context).colorScheme.surface.withValues(
                        alpha: Theme.of(context).brightness == Brightness.dark
                            ? .76
                            : .68),
                    borderColor: Colors.white.withValues(
                        alpha: Theme.of(context).brightness == Brightness.dark
                            ? .2
                            : .72),
                    shadows: [
                      BoxShadow(
                        color: Theme.of(context)
                            .colorScheme
                            .shadow
                            .withValues(alpha: .18),
                        blurRadius: 28,
                        offset: const Offset(0, 9),
                      ),
                    ],
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: _showContact,
                        borderRadius: BorderRadius.circular(18),
                        child: SizedBox(
                          height: 58,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.chat_bubble_outline_rounded,
                                  color: Theme.of(context).colorScheme.primary),
                              const SizedBox(width: 10),
                              Text('Contact owner',
                                  style: TextStyle(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurface,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700)),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
    );
  }
}

class _PreviewModeBar extends StatelessWidget {
  const _PreviewModeBar();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return SafeArea(
      minimum: const EdgeInsets.fromLTRB(20, 10, 20, 14),
      child: GlassSurface(
        borderRadius: BorderRadius.circular(18),
        tint: colors.primaryContainer.withValues(alpha: .86),
        blur: 18,
        child: SizedBox(
          height: 58,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.visibility_outlined, color: colors.primary),
              const SizedBox(width: 9),
              Text('Customer view preview',
                  style: TextStyle(
                      color: colors.onPrimaryContainer,
                      fontSize: 16,
                      fontWeight: FontWeight.w800)),
            ],
          ),
        ),
      ),
    );
  }
}

class _OwnerPropertyUpdates extends StatelessWidget {
  final House house;
  final Future<NotificationInbox> future;
  final VoidCallback onOpen;

  const _OwnerPropertyUpdates({
    required this.house,
    required this.future,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return FutureBuilder<NotificationInbox>(
      future: future,
      builder: (context, snapshot) {
        final updates = (snapshot.data?.items ?? const <HavenNotification>[])
            .where((item) => item.houseId == house.id)
            .toList();
        final unread = updates.where((item) => !item.isRead).length;
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 20),
          padding: const EdgeInsets.fromLTRB(15, 14, 15, 12),
          decoration: BoxDecoration(
            color: colors.primaryContainer.withValues(alpha: .42),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: colors.primary.withValues(alpha: .18)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: colors.primary,
                      borderRadius: BorderRadius.circular(11),
                    ),
                    child: Icon(Icons.notifications_active_outlined,
                        size: 19, color: colors.onPrimary),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Updates for this listing',
                            style: TextStyle(fontWeight: FontWeight.w900)),
                        const SizedBox(height: 2),
                        Text(
                          unread > 0
                              ? '$unread unread update${unread == 1 ? '' : 's'}'
                              : 'Notifications, viewings and activity stay here',
                          style: TextStyle(
                              color: colors.onSurfaceVariant, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  TextButton(
                    onPressed: onOpen,
                    child: const Text('Open'),
                  ),
                ],
              ),
              if (snapshot.connectionState == ConnectionState.waiting) ...[
                const SizedBox(height: 13),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                      minHeight: 5,
                      backgroundColor: colors.surface.withValues(alpha: .7)),
                ),
              ] else if (snapshot.hasError) ...[
                const SizedBox(height: 10),
                Text(
                  'Activity is temporarily unavailable. Open your listing workspace to try again.',
                  style:
                      TextStyle(color: colors.onSurfaceVariant, fontSize: 12),
                ),
              ] else if (updates.isEmpty) ...[
                const SizedBox(height: 10),
                Text(
                  'No notifications for this home yet. New viewing requests, messages and paid reservations will appear here.',
                  style:
                      TextStyle(color: colors.onSurfaceVariant, fontSize: 12),
                ),
              ] else ...[
                const SizedBox(height: 9),
                ...updates.take(3).map((item) => _OwnerUpdateRow(item: item)),
                if (updates.length > 3)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: onOpen,
                      icon: const Icon(Icons.arrow_forward_rounded, size: 16),
                      label: Text('See all ${updates.length} updates'),
                    ),
                  ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _OwnerUpdateRow extends StatelessWidget {
  final HavenNotification item;

  const _OwnerUpdateRow({required this.item});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 7,
            height: 7,
            margin: const EdgeInsets.only(top: 6, right: 9),
            decoration: BoxDecoration(
              color: item.isRead ? colors.outlineVariant : colors.primary,
              shape: BoxShape.circle,
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w800)),
                if (item.body.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(item.body,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          color: colors.onSurfaceVariant, fontSize: 12)),
                ],
              ],
            ),
          ),
          if (item.createdAt != null) ...[
            const SizedBox(width: 8),
            Text(_ownerUpdateAge(item.createdAt!),
                style: TextStyle(color: colors.onSurfaceVariant, fontSize: 10)),
          ],
        ],
      ),
    );
  }
}

String _ownerUpdateAge(DateTime value) {
  final elapsed = DateTime.now().difference(value);
  if (elapsed.inMinutes < 1) return 'now';
  if (elapsed.inMinutes < 60) return '${elapsed.inMinutes}m';
  if (elapsed.inHours < 24) return '${elapsed.inHours}h';
  if (elapsed.inDays < 7) return '${elapsed.inDays}d';
  return '${value.day}/${value.month}';
}

class _OwnerListingActions extends StatelessWidget {
  final House house;

  const _OwnerListingActions({required this.house});

  Future<void> _openReservations(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => PaidReservationSheet(
        houseId: house.id,
        houseName: house.name,
        monthlyRent: house.priceRental,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                    color: colors.primaryContainer, shape: BoxShape.circle),
                child: Icon(Icons.home_work_outlined,
                    color: colors.onPrimaryContainer, size: 19),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Your listing controls',
                        style: TextStyle(fontWeight: FontWeight.w800)),
                    SizedBox(height: 3),
                    Text('Edit the home, paid setup and activity'),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 13),
          Row(
            children: [
              Expanded(
                child: _OwnerActionButton(
                  icon: Icons.insights_outlined,
                  label: 'Management',
                  onTap: () => Navigator.push(
                    context,
                    HavenPageRoute(
                        builder: (_) => ListingManagementScreen(house: house)),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _OwnerActionButton(
                  icon: Icons.edit_outlined,
                  label: 'Edit listing',
                  onTap: () => Navigator.push(
                    context,
                    HavenPageRoute(
                        builder: (_) => EditListingScreen(house: house)),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _OwnerActionButton(
                  icon: Icons.event_available_outlined,
                  label: 'Paid setup',
                  onTap: () => _openReservations(context),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _OwnerActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _OwnerActionButton(
      {required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Material(
      color: colors.primaryContainer.withValues(alpha: .55),
      borderRadius: BorderRadius.circular(13),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(13),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 4),
          child: Column(
            children: [
              Icon(icon, color: colors.primary, size: 20),
              const SizedBox(height: 5),
              Text(label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      color: colors.onPrimaryContainer,
                      fontSize: 12,
                      fontWeight: FontWeight.w800)),
            ],
          ),
        ),
      ),
    );
  }
}

class _PendingViewingsBanner extends StatelessWidget {
  final int houseId;
  final Future<List<ViewingSummary>> future;

  const _PendingViewingsBanner({required this.houseId, required this.future});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<ViewingSummary>>(
      future: future,
      builder: (context, snapshot) {
        final pending = (snapshot.data ?? const <ViewingSummary>[])
            .where((item) =>
                item.houseId == houseId &&
                item.role == ViewingRole.lister &&
                item.status == 'pending')
            .length;
        if (pending == 0) return const SizedBox.shrink();
        final label = pending == 1
            ? '1 pending viewing request'
            : '$pending pending viewing requests';
        final colors = Theme.of(context).colorScheme;
        return Material(
          color: colors.primaryContainer.withValues(alpha: .72),
          borderRadius: BorderRadius.circular(18),
          child: InkWell(
            onTap: () => Navigator.push(
              context,
              HavenPageRoute(
                  builder: (_) => const MarketplaceHubScreen(initialTab: 1)),
            ),
            borderRadius: BorderRadius.circular(18),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  Icon(Icons.calendar_month_rounded,
                      color: colors.onPrimaryContainer),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(label,
                            style: TextStyle(
                                color: colors.onPrimaryContainer,
                                fontWeight: FontWeight.w800)),
                        const SizedBox(height: 3),
                        Text(
                            'Review and respond to your request${pending == 1 ? '' : 's'}',
                            style: TextStyle(color: colors.onPrimaryContainer)),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right_rounded,
                      color: colors.onPrimaryContainer),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _ContactRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _ContactRow(
      {required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
          color: Theme.of(context)
              .colorScheme
              .surfaceContainer
              .withValues(alpha: .66),
          border: Border.all(
              color: Colors.white.withValues(
                  alpha: Theme.of(context).brightness == Brightness.dark
                      ? .1
                      : .58)),
          borderRadius: BorderRadius.circular(14)),
      child: Row(
        children: [
          Icon(icon, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 12),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(label,
                    style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        fontSize: 11)),
                const SizedBox(height: 2),
                Text(value,
                    style: const TextStyle(fontWeight: FontWeight.w600)),
              ])),
        ],
      ),
    );
  }
}
