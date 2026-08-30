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

  const _ReservationSlotSheet({
    required this.propertyName,
    required this.slots,
  });

  @override
  State<_ReservationSlotSheet> createState() => _ReservationSlotSheetState();
}

class _ReservationSlotSheetState extends State<_ReservationSlotSheet> {
  int? _selectedId;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final available = widget.slots
        .where((slot) => slot.isActive && slot.startsAt.isAfter(DateTime.now()))
        .toList();
    return Material(
      color: colors.surface,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
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
              Text('Reserve this home',
                  style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 5),
              Text(
                'Choose one date offered by the lister for ${widget.propertyName}. You can manage the reservation from Your Haven.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 16),
              if (available.isEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: colors.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: colors.outlineVariant),
                  ),
                  child: const Text(
                      'No reservation dates are available right now.'),
                )
              else
                ...available.map((slot) {
                  final selected = slot.id == _selectedId;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 9),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(18),
                      onTap: () => setState(() => _selectedId = slot.id),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: selected
                              ? colors.primaryContainer
                              : colors.surfaceContainerLow,
                          borderRadius: BorderRadius.circular(18),
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
                                  ? Icons.radio_button_checked_rounded
                                  : Icons.radio_button_off_rounded,
                              color: selected
                                  ? colors.primary
                                  : colors.onSurfaceVariant,
                            ),
                            const SizedBox(width: 11),
                            Icon(Icons.calendar_month_outlined,
                                size: 19, color: colors.primary),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _reservationSlotLabel(slot),
                                style: Theme.of(context)
                                    .textTheme
                                    .titleSmall
                                    ?.copyWith(fontWeight: FontWeight.w700),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }),
              const SizedBox(height: 5),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _selectedId == null
                      ? null
                      : () => Navigator.pop(context, _selectedId),
                  icon: const Icon(Icons.lock_outline_rounded, size: 18),
                  label: const Text('Continue with this date'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _reservationSlotLabel(ReservationSlot slot) {
  final start = slot.startsAt;
  final hour = start.hour % 12 == 0 ? 12 : start.hour % 12;
  final minute = start.minute.toString().padLeft(2, '0');
  final period = start.hour >= 12 ? 'PM' : 'AM';
  final end = slot.endsAt;
  final endLabel = end == null
      ? ''
      : ' – ${end.hour % 12 == 0 ? 12 : end.hour % 12}:${end.minute.toString().padLeft(2, '0')} ${end.hour >= 12 ? 'PM' : 'AM'}';
  return '${_reservationDayLabel(start)} · $hour:$minute $period$endLabel';
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

  const Details({Key? key, required this.house, this.isOwnerView = false})
      : super(key: key);

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
  late Future<ReservationState> _reservationFuture;
  bool _reservationBusy = false;
  bool _interestBusy = false;
  bool _ownerLoaded = false;
  bool _canReview = false;

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
    // Owner details are only needed when the contact sheet opens. Deferring
    // this request keeps the route's first frames free for the transition.
    _ownerFuture = Future.value(widget.house.ownerContact);
    _ownerViewingsFuture = widget.isOwnerView
        ? MarketplaceService.instance.viewings()
        : Future.value(const <ViewingSummary>[]);
    _reservationFuture =
        MarketplaceService.instance.reservationState(widget.house.id);
    unawaited(PropertyDetailsService.cacheOwnerContact(
        widget.house.id, widget.house.ownerContact));
    if (!widget.isOwnerView) {
      unawaited(_loadReviewEligibility());
      House.recordView(widget.house.id);
      SessionRecommendation.instance.observe(widget.house, 1.1);
      unawaited(RecommendationService.instance
          .track('details', widget.house.id, surface: 'details'));
    }
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
                const Text('Checking reservation availability…'),
              ],
            ),
          );
        }
        final state = snapshot.data;
        if (state == null) return const SizedBox.shrink();

        final available = state.slots
            .where((slot) =>
                slot.isActive && slot.startsAt.isAfter(DateTime.now()))
            .toList();
        final hasDates = !state.isReserved && available.isNotEmpty;
        final isMine = state.isMine && state.isReserved;
        final title = isMine
            ? 'Your reservation is active'
            : state.isReserved
                ? 'Currently reserved'
                : hasDates
                    ? 'Reserve this home'
                    : 'Reservation dates coming soon';
        final message = isMine
            ? 'You have reserved this home. Viewings can still be requested.'
            : state.isReserved
                ? 'This home is currently reserved, but viewing requests remain open.'
                : hasDates
                    ? 'Choose a date offered by the lister. Normal viewing requests stay open too.'
                    : 'The lister has not opened a reservation date yet. We can notify you when one becomes available.';
        final label = isMine || state.isReserved
            ? 'RESERVATION ON HOLD'
            : hasDates
                ? 'RESERVATIONS AVAILABLE'
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
              Text(message, style: Theme.of(context).textTheme.bodyMedium),
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
                    label: const Text('Choose a reservation date'),
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
                              const MarketplaceHubScreen(initialTab: 1)),
                    ),
                    icon: const Icon(Icons.event_note_outlined, size: 18),
                    label: const Text('View my reservation'),
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
              label: const Text('Checking reservation dates'),
            ),
          );
        }
        final state = snapshot.data;
        if (state == null) return const SizedBox.shrink();
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
                          ? 'You have reserved this home. Viewings can still be requested.'
                          : 'This home is currently reserved. Viewings can still be requested.',
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
        if (state.slots.isEmpty) {
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
            label: const Text('Reserve this home'),
          ),
        );
      },
    );
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
        ),
      );
      if (slotId == null || !mounted) return;
      await MarketplaceService.instance.reserveHome(widget.house.id, slotId);
      if (!mounted) return;
      if (closeAfter) Navigator.of(context).pop();
      _notice('Home reserved. You can manage it from Your Haven.');
      setState(() => _reservationFuture = MarketplaceService.instance
          .reservationState(widget.house.id, refresh: true));
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
        setState(() => _reservationFuture = MarketplaceService.instance
            .reservationState(widget.house.id, refresh: true));
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
          SliverToBoxAdapter(child: DetailsAppBar(house: widget.house)),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.only(top: 24, bottom: 116),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ContentIntro(house: widget.house),
                  if (!widget.isOwnerView) ...[
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
                  if (widget.isOwnerView) ...[
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
                            if (!widget.isOwnerView)
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
      bottomNavigationBar: widget.isOwnerView
          ? null
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
                                  color:
                                      Theme.of(context).colorScheme.onSurface,
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
