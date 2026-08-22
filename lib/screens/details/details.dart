import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:house_rent/config/api_config.dart';
import 'package:house_rent/models/house.dart';
import 'package:house_rent/services/app_data_service.dart';
import 'package:house_rent/services/recommendation_service.dart';
import 'package:house_rent/services/session_recommendation.dart';
import 'package:house_rent/theme/app_colors.dart';
import 'package:house_rent/widgets/about.dart';
import 'package:house_rent/widgets/content_intro.dart';
import 'package:house_rent/widgets/details_app_bar.dart';
import 'package:house_rent/widgets/house_gallery.dart';
import 'package:house_rent/widgets/house_info.dart';
import 'package:house_rent/widgets/house_location_map.dart';
import 'package:house_rent/widgets/glass_surface.dart';
import 'package:house_rent/widgets/lister_reviews_section.dart';
import 'package:house_rent/widgets/lister_trust_badges.dart';
import 'package:house_rent/widgets/listing_videos_section.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

class _DetailsPageRoute extends MaterialPageRoute<void> {
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
  bool _ownerLoaded = false;

  @override
  void initState() {
    super.initState();
    // Owner details are only needed when the contact sheet opens. Deferring
    // this request keeps the route's first frames free for the transition.
    _ownerFuture = Future.value(const <String, dynamic>{});
    if (!widget.isOwnerView) {
      House.recordView(widget.house.id);
      SessionRecommendation.instance.observe(widget.house, 1.1);
      unawaited(RecommendationService.instance
          .track('details', widget.house.id, surface: 'details'));
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
    final uri = Uri.https('wa.me', '/$digits', {
      'text':
          'Hi, I found “${widget.house.name}” on Haven Zambia and would like to know more.',
    });
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      _notice('Could not open WhatsApp on this device.');
    }
  }

  void _ensureOwnerLoaded() {
    if (_ownerLoaded) return;
    _ownerLoaded = true;
    _ownerFuture = PropertyDetailsService.owner(widget.house.id);
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
      final response = await http.post(
        Uri.parse('${ApiConfig.apiBase}/users/${widget.house.ownerId}/review'),
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
      );
      final data = json.decode(response.body);
      if (response.statusCode == 201 || response.statusCode == 202) {
        await ListerReviewsService.invalidate(widget.house.ownerId!);
        if (mounted) setState(() => _reviewVersion++);
        _notice(data['message'] ?? 'Thanks—your review was received.');
      } else {
        _notice(data['error'] ?? 'Could not submit your review.');
      }
    } catch (_) {
      _notice('Could not submit your review. Try again later.');
    }
  }

  void _notice(String value) {
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(value)));
    }
  }

  void _showReview() {
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
                  const SizedBox(height: 24),
                  HouseInfo(house: widget.house),
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
                              backgroundColor: AppColors.primaryLight,
                              child: Text(ownerName[0].toUpperCase(),
                                  style: const TextStyle(
                                      color: AppColors.primary,
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
                                ],
                              ),
                            ),
                          ],
                        ),
                        if (!widget.isOwnerView) ...[
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
                      onAddReview: widget.isOwnerView ? null : _showReview,
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
