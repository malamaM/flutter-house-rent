import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:house_rent/config/api_config.dart';
import 'package:house_rent/models/house.dart';
import 'package:house_rent/services/app_data_service.dart';
import 'package:house_rent/theme/app_colors.dart';
import 'package:house_rent/widgets/about.dart';
import 'package:house_rent/widgets/content_intro.dart';
import 'package:house_rent/widgets/details_app_bar.dart';
import 'package:house_rent/widgets/house_gallery.dart';
import 'package:house_rent/widgets/house_info.dart';
import 'package:house_rent/widgets/house_location_map.dart';
import 'package:house_rent/widgets/lister_reviews_section.dart';
import 'package:house_rent/widgets/lister_trust_badges.dart';
import 'package:house_rent/widgets/listing_videos_section.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class Details extends StatefulWidget {
  final House house;
  final bool isOwnerView;

  const Details({Key? key, required this.house, this.isOwnerView = false})
      : super(key: key);

  @override
  State<Details> createState() => _DetailsState();
}

class _DetailsState extends State<Details> {
  int _reviewVersion = 0;
  @override
  void initState() {
    super.initState();
    if (!widget.isOwnerView) House.recordView(widget.house.id);
  }

  Future<Map<String, dynamic>> _fetchOwner() async {
    return PropertyDetailsService.owner(widget.house.id);
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
            decoration: const BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.vertical(top: Radius.circular(26))),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Align(
                    child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                            color: AppColors.divider,
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
                const Text(
                  'Reviews must be honest, specific, and at least 20 characters. Suspicious activity may be held for moderation.',
                  style: TextStyle(
                      color: AppColors.textSecondary,
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
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 30),
        decoration: const BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(26))),
        child: FutureBuilder<Map<String, dynamic>>(
          future: _fetchOwner(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const SizedBox(
                  height: 180,
                  child: Center(child: CircularProgressIndicator()));
            }
            final user = snapshot.data ?? {};
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Align(
                    child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                            color: AppColors.divider,
                            borderRadius: BorderRadius.circular(4)))),
                const SizedBox(height: 22),
                Text('Contact the owner',
                    style: Theme.of(context).textTheme.headlineMedium),
                const SizedBox(height: 6),
                Text('Mention “${widget.house.name}” when you get in touch.',
                    style: Theme.of(context).textTheme.bodyMedium),
                const SizedBox(height: 18),
                _ContactRow(
                    icon: Icons.phone_outlined,
                    label: 'Phone',
                    value: user['phone_number'] ?? 'Not provided'),
                _ContactRow(
                    icon: Icons.mail_outline_rounded,
                    label: 'Email',
                    value: user['email'] ?? 'Not provided'),
                if (user['company'] != null)
                  _ContactRow(
                      icon: Icons.business_outlined,
                      label: 'Company',
                      value: user['company']),
              ],
            );
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ownerName = widget.house.ownerName ?? 'Property owner';
    return Scaffold(
      backgroundColor: AppColors.background,
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
                        color: AppColors.surface,
                        border: Border.all(color: AppColors.divider),
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
              child: ElevatedButton.icon(
                onPressed: _showContact,
                icon: const Icon(Icons.chat_bubble_outline_rounded),
                label: const Text('Contact owner'),
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
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
          color: AppColors.surfaceContainer,
          borderRadius: BorderRadius.circular(14)),
      child: Row(
        children: [
          Icon(icon, color: AppColors.primary),
          const SizedBox(width: 12),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(label,
                    style: const TextStyle(
                        color: AppColors.textSecondary, fontSize: 11)),
                const SizedBox(height: 2),
                Text(value,
                    style: const TextStyle(fontWeight: FontWeight.w600)),
              ])),
        ],
      ),
    );
  }
}
