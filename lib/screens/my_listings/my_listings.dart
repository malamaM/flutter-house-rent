import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:house_rent/models/house.dart';
import 'package:house_rent/models/marketplace.dart';
import 'package:house_rent/navigation/haven_page_route.dart';
import 'package:house_rent/screens/details/details.dart';
import 'package:house_rent/screens/my_listings/create_listing_screen.dart';
import 'package:house_rent/screens/my_listings/edit_listing.dart';
import 'package:house_rent/screens/my_listings/paid_reservation_sheet.dart';
import 'package:house_rent/widgets/property_card.dart';
import 'package:house_rent/widgets/screen_state.dart';
import 'package:house_rent/widgets/haven_navigation_bar.dart';
import 'package:house_rent/services/marketplace_service.dart';
import 'package:house_rent/services/api_error.dart';
import 'package:house_rent/services/app_feedback.dart';

class MyListingsScreen extends StatefulWidget {
  const MyListingsScreen({Key? key}) : super(key: key);

  @override
  State<MyListingsScreen> createState() => _MyListingsScreenState();
}

class _MyListingsScreenState extends State<MyListingsScreen> {
  late Future<List<House>> listings;
  final Set<int> _renewing = {};

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload({bool forceRefresh = false}) {
    listings = House.fetchMyHouses(forceRefresh: forceRefresh);
  }

  Future<void> _create() async {
    final created = await Navigator.push(
        context, HavenPageRoute(builder: (_) => const CreateListingScreen()));
    if (created == true && mounted) {
      setState(() {
        _reload(forceRefresh: true);
      });
    }
  }

  Future<void> _edit(House house) async {
    final changed = await Navigator.push(context,
        HavenPageRoute(builder: (_) => EditListingScreen(house: house)));
    if (changed == true && mounted) {
      setState(() {
        _reload(forceRefresh: true);
      });
    }
  }

  Future<void> _manageReservationSlots(House house) async {
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
    if (mounted) setState(() => _reload(forceRefresh: true));
  }

  Future<void> _renew(House house) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Renew this listing?'),
        content: Text(
            '“${house.name}” will remain visible to renters for another 30 days.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Not now')),
          ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Renew listing')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _renewing.add(house.id));
    try {
      await House.renewListing(house.id);
      if (!mounted) return;
      setState(() {
        _reload(forceRefresh: true);
      });
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Listing renewed for 30 days')));
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(ApiErrorResolver.message(error,
              fallback: 'Haven could not renew this listing.')),
        ));
      }
    } finally {
      if (mounted) setState(() => _renewing.remove(house.id));
    }
  }

  Future<void> _availability(House house, String value) async {
    try {
      await MarketplaceService.instance.updateAvailability(house.id, value);
      if (!mounted) return;
      setState(() => _reload(forceRefresh: true));
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(value == 'available'
              ? 'Home marked available.'
              : 'Availability updated.')));
    } on MarketplaceException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.message)));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const HavenNavigationBar(title: 'My listings'),
      body: FutureBuilder<List<House>>(
        future: listings,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const PropertyListSkeleton();
          }
          if (snapshot.hasError) {
            return ScreenState(
              icon: Icons.cloud_off_outlined,
              title: 'Could not load your listings',
              message: AppFeedback.messageFor(snapshot.error!,
                  fallback: 'Haven could not load your listings.'),
              actionLabel: 'Try again',
              onAction: () => setState(() {
                _reload(forceRefresh: true);
              }),
            );
          }
          final items = snapshot.data ?? [];
          if (items.isEmpty) {
            return ScreenState(
              icon: Icons.add_home_work_outlined,
              title: 'List your first property',
              message: 'Reach people looking for a new place across Zambia.',
              actionLabel: 'Create listing',
              onAction: _create,
            );
          }
          return RefreshIndicator(
            onRefresh: () async {
              setState(() => _reload(forceRefresh: true));
              await listings;
            },
            child: ListView.separated(
              key: const PageStorageKey('my-listings'),
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
              itemCount: items.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final house = items[index];
                return Column(
                  children: [
                    PropertyCard(
                      horizontal: true,
                      showSave: false,
                      house: house,
                      secondaryLabel: 'Edit listing',
                      onSecondaryAction: () => _edit(house),
                      onTap: () => Navigator.push(
                          context, Details.route(house, isOwnerView: true)),
                    ),
                    _ListingLifecycleBar(
                      house: house,
                      renewing: _renewing.contains(house.id),
                      onRenew: () => _renew(house),
                      onAvailability: (value) => _availability(house, value),
                      onReservations: () => _manageReservationSlots(house),
                    ),
                  ],
                );
              },
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _create,
        icon: const Icon(Icons.add_rounded),
        label: const Text('New listing'),
      ),
    );
  }
}

class _ListingLifecycleBar extends StatelessWidget {
  const _ListingLifecycleBar({
    required this.house,
    required this.renewing,
    required this.onRenew,
    required this.onAvailability,
    required this.onReservations,
  });

  final House house;
  final bool renewing;
  final VoidCallback onRenew;
  final ValueChanged<String> onAvailability;
  final VoidCallback onReservations;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final urgent = house.isArchived || house.daysUntilExpiry <= 3;
    final label = house.isArchived
        ? 'Archived after 30 days'
        : house.daysUntilExpiry == 0
            ? 'Expires today'
            : '${house.daysUntilExpiry} days remaining';
    return Container(
      margin: const EdgeInsets.only(top: 7),
      padding: const EdgeInsets.fromLTRB(13, 8, 9, 8),
      decoration: BoxDecoration(
        color: urgent ? colors.errorContainer : colors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: urgent
                ? colors.error.withValues(alpha: .25)
                : colors.outlineVariant),
      ),
      child: Column(children: [
        Row(children: [
          Icon(house.isArchived ? Icons.inventory_2_outlined : Icons.schedule,
              size: 17,
              color: urgent ? colors.onErrorContainer : colors.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(label,
                style: TextStyle(
                    color: urgent
                        ? colors.onErrorContainer
                        : colors.onSurfaceVariant,
                    fontSize: 12,
                    fontWeight: FontWeight.w700)),
          ),
          if (house.canRenew)
            TextButton.icon(
              onPressed: renewing ? null : onRenew,
              icon: renewing
                  ? const SizedBox(
                      width: 15,
                      height: 15,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Renew'),
            ),
          IconButton(
            onPressed: onReservations,
            tooltip: 'Paid reservation dates',
            icon: const Icon(Icons.event_available_outlined),
            visualDensity: VisualDensity.compact,
          ),
          PopupMenuButton<String>(
            tooltip: 'Update availability',
            onSelected: onAvailability,
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'available', child: Text('Available')),
              PopupMenuItem(
                  value: 'viewing', child: Text('Viewings in progress')),
              PopupMenuItem(value: 'let', child: Text('Now rented')),
              PopupMenuItem(value: 'paused', child: Text('Pause listing')),
            ],
          ),
        ]),
        const SizedBox(height: 7),
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onReservations,
            borderRadius: BorderRadius.circular(11),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                children: [
                  Icon(
                    house.reservationSlotsCount > 0
                        ? Icons.event_available_rounded
                        : Icons.event_note_outlined,
                    size: 17,
                    color: house.reservationSlotsCount > 0
                        ? colors.primary
                        : colors.onSurfaceVariant,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      house.reservationSlotsCount > 0
                          ? '${house.reservationSlotsCount} paid reservation ${house.reservationSlotsCount == 1 ? 'date' : 'dates'} set'
                          : 'No paid reservation dates set',
                      style: TextStyle(
                        color: house.reservationSlotsCount > 0
                            ? colors.primary
                            : colors.onSurfaceVariant,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Text(
                    house.reservationSlotsCount > 0
                        ? 'Manage'
                        : 'Add paid dates',
                    style: TextStyle(
                      color: colors.primary,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Icon(Icons.chevron_right_rounded,
                      size: 18, color: colors.primary),
                ],
              ),
            ),
          ),
        ),
        if (house.qualityScore > 0 && house.qualityScore < 86) ...[
          const SizedBox(height: 6),
          Row(children: [
            Icon(Icons.auto_awesome_outlined, size: 16, color: colors.primary),
            const SizedBox(width: 7),
            Expanded(
                child: Text(
              'Listing quality ${house.qualityScore}% · ${house.qualityWarnings.isEmpty ? 'Add more detail to stand out' : house.qualityWarnings.first}',
              style: TextStyle(fontSize: 11, color: colors.onSurfaceVariant),
            )),
          ]),
        ],
      ]),
    );
  }
}

class _ReservationSlotsSheet extends StatefulWidget {
  final int houseId;
  final String houseName;

  const _ReservationSlotsSheet({
    required this.houseId,
    required this.houseName,
  });

  @override
  State<_ReservationSlotsSheet> createState() => _ReservationSlotsSheetState();
}

class _ReservationSlotsSheetState extends State<_ReservationSlotsSheet> {
  late Future<List<ReservationSlot>> _future;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    _future = MarketplaceService.instance
        .reservationSlots(widget.houseId, refresh: true);
  }

  Future<void> _addDate() async {
    final tomorrow = DateTime.now().add(const Duration(days: 1));
    final minimumDate = DateTime(tomorrow.year, tomorrow.month, tomorrow.day);
    final startsAt = await showModalBottomSheet<DateTime>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ReservationDateTimePicker(
        minimumDate: minimumDate,
        maximumDate: DateTime.now().add(const Duration(days: 180)),
        initialDateTime: DateTime(
          tomorrow.year,
          tomorrow.month,
          tomorrow.day,
          10,
        ),
      ),
    );
    if (startsAt == null || !mounted) return;
    if (!startsAt.isAfter(DateTime.now())) {
      _showMessage('Choose a time that is still ahead.');
      return;
    }
    setState(() => _saving = true);
    try {
      await MarketplaceService.instance
          .createReservationSlot(widget.houseId, startsAt);
      if (mounted) setState(_load);
    } on MarketplaceException catch (error) {
      if (mounted) _showMessage(error.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _remove(ReservationSlot slot) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Remove this date?'),
        content: const Text(
            'Customers will no longer be able to choose this reservation date.'),
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
      if (mounted) setState(_load);
    } on MarketplaceException catch (error) {
      if (mounted) _showMessage(error.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
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
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 14),
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
                      borderRadius: BorderRadius.circular(4)),
                ),
              ),
              const SizedBox(height: 17),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Reservation dates',
                            style: Theme.of(context).textTheme.headlineSmall),
                        const SizedBox(height: 4),
                        Text(widget.houseName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodySmall),
                      ],
                    ),
                  ),
                  IconButton.filledTonal(
                    onPressed: _saving ? null : _addDate,
                    tooltip: 'Add a date',
                    icon: _saving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.add_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: colors.primaryContainer.withValues(alpha: .42),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline_rounded,
                        size: 18, color: colors.primary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'These dates control reservations only. Normal viewing requests continue as usual.',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              FutureBuilder<List<ReservationSlot>>(
                future: _future,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Padding(
                      padding: EdgeInsets.all(26),
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }
                  if (snapshot.hasError) {
                    return _ReservationEmptyState(
                      icon: Icons.cloud_off_outlined,
                      text: 'Reservation dates could not be loaded.',
                      action: TextButton(
                          onPressed: () => setState(_load),
                          child: const Text('Try again')),
                    );
                  }
                  final slots = snapshot.data ?? const <ReservationSlot>[];
                  if (slots.isEmpty) {
                    return const _ReservationEmptyState(
                      icon: Icons.event_available_outlined,
                      text: 'Add dates when customers can reserve this home.',
                    );
                  }
                  return ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 330),
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: slots.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (_, index) {
                        final slot = slots[index];
                        return Container(
                          padding: const EdgeInsets.fromLTRB(13, 11, 5, 11),
                          decoration: BoxDecoration(
                            color: colors.surfaceContainerLow,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: colors.outlineVariant),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.calendar_month_outlined,
                                  color: colors.primary, size: 20),
                              const SizedBox(width: 10),
                              Expanded(
                                  child: Text(_slotLabel(slot),
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w700))),
                              IconButton(
                                onPressed: _saving ? null : () => _remove(slot),
                                tooltip: 'Remove date',
                                icon: const Icon(Icons.remove_circle_outline),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReservationDateTimePicker extends StatefulWidget {
  final DateTime minimumDate;
  final DateTime maximumDate;
  final DateTime initialDateTime;

  const _ReservationDateTimePicker({
    required this.minimumDate,
    required this.maximumDate,
    required this.initialDateTime,
  });

  @override
  State<_ReservationDateTimePicker> createState() =>
      _ReservationDateTimePickerState();
}

class _ReservationDateTimePickerState
    extends State<_ReservationDateTimePicker> {
  late DateTime _selected;

  @override
  void initState() {
    super.initState();
    _selected = widget.initialDateTime;
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final pickerTextStyle = TextStyle(
      color: colors.onSurface,
      fontSize: 22,
      fontWeight: FontWeight.w600,
    );
    return Material(
      color: colors.surface,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 14),
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
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Add a reservation date',
                            style: Theme.of(context).textTheme.headlineSmall),
                        const SizedBox(height: 4),
                        Text('Choose when customers can arrive',
                            style: Theme.of(context).textTheme.bodyMedium),
                      ],
                    ),
                  ),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: colors.primaryContainer,
                      shape: BoxShape.circle,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(11),
                      child: Icon(Icons.event_available_rounded,
                          color: colors.onPrimaryContainer, size: 22),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: colors.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: colors.outlineVariant),
                ),
                child: CupertinoTheme(
                  data: CupertinoThemeData(
                    brightness: Theme.of(context).brightness,
                    primaryColor: colors.primary,
                    textTheme: CupertinoTextThemeData(
                      dateTimePickerTextStyle: pickerTextStyle,
                    ),
                  ),
                  child: SizedBox(
                    height: 190,
                    child: CupertinoDatePicker(
                      mode: CupertinoDatePickerMode.dateAndTime,
                      use24hFormat: false,
                      minuteInterval: 15,
                      minimumDate: widget.minimumDate,
                      maximumDate: widget.maximumDate,
                      initialDateTime: widget.initialDateTime,
                      onDateTimeChanged: (value) => setState(() {
                        _selected = value;
                      }),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      _slotLabelFromDateTime(_selected),
                      style: TextStyle(
                        color: colors.primary,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  CupertinoButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 2),
                  CupertinoButton.filled(
                    onPressed: () => Navigator.pop(context, _selected),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 17, vertical: 9),
                    child: const Text('Add date'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _slotLabelFromDateTime(DateTime value) {
  final hour = value.hour % 12 == 0 ? 12 : value.hour % 12;
  final minute = value.minute.toString().padLeft(2, '0');
  final period = value.hour >= 12 ? 'PM' : 'AM';
  return '${_shortDay(value)} · $hour:$minute $period';
}

class _ReservationEmptyState extends StatelessWidget {
  final IconData icon;
  final String text;
  final Widget? action;

  const _ReservationEmptyState({
    required this.icon,
    required this.text,
    this.action,
  });

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(12, 18, 12, 24),
        child: Column(
          children: [
            Icon(icon,
                size: 30,
                color: Theme.of(context).colorScheme.onSurfaceVariant),
            const SizedBox(height: 9),
            Text(text, textAlign: TextAlign.center),
            if (action != null) action!,
          ],
        ),
      );
}

String _slotLabel(ReservationSlot slot) {
  final value = slot.startsAt;
  final hour = value.hour % 12 == 0 ? 12 : value.hour % 12;
  final minute = value.minute.toString().padLeft(2, '0');
  final period = value.hour >= 12 ? 'PM' : 'AM';
  return '${_shortDay(value)} · $hour:$minute $period';
}

String _shortDay(DateTime value) {
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
