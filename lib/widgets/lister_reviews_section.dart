import 'package:flutter/material.dart';
import 'package:house_rent/services/app_data_service.dart';
import 'package:house_rent/theme/app_colors.dart';

class ListerReviewsSection extends StatefulWidget {
  final int listerId;
  final VoidCallback? onAddReview;

  const ListerReviewsSection(
      {Key? key, required this.listerId, this.onAddReview})
      : super(key: key);

  @override
  State<ListerReviewsSection> createState() => _ListerReviewsSectionState();
}

class _ListerReviewsSectionState extends State<ListerReviewsSection> {
  late Future<ListerReviewsData> reviews;

  @override
  void initState() {
    super.initState();
    reviews = ListerReviewsService.fetch(widget.listerId);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: FutureBuilder<ListerReviewsData>(
        future: reviews,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData) {
            return const SizedBox(
                height: 120, child: Center(child: CircularProgressIndicator()));
          }
          if (!snapshot.hasData) return const SizedBox.shrink();
          final data = snapshot.data!;
          return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Expanded(
                      child: Text('Lister reviews',
                          style: Theme.of(context).textTheme.headlineMedium)),
                  if (widget.onAddReview != null)
                    TextButton(
                        onPressed: widget.onAddReview,
                        child: const Text('Write a review')),
                ]),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surfaceContainerLow,
                      border: Border.all(
                          color: Theme.of(context).colorScheme.outlineVariant),
                      borderRadius: BorderRadius.circular(18)),
                  child: data.total == 0
                      ? Row(children: [
                          Icon(Icons.rate_review_outlined,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant),
                          const SizedBox(width: 12),
                          Expanded(
                              child: Text(
                                  'No published reviews yet. Be the first to share a genuine experience.',
                                  style: TextStyle(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurfaceVariant))),
                        ])
                      : Row(children: [
                          Text(data.average.toStringAsFixed(1),
                              style: TextStyle(
                                  fontSize: 36,
                                  fontWeight: FontWeight.w800,
                                  color:
                                      Theme.of(context).colorScheme.onSurface)),
                          const SizedBox(width: 14),
                          Expanded(
                              child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                _Stars(rating: data.average.round()),
                                const SizedBox(height: 4),
                                Text(
                                    'Based on ${data.total} ${data.total == 1 ? 'review' : 'reviews'}',
                                    style:
                                        Theme.of(context).textTheme.bodyMedium),
                              ])),
                        ]),
                ),
                if (data.reviews.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  ...data.reviews
                      .take(5)
                      .map((review) => _ReviewCard(review: review)),
                ],
              ]);
        },
      ),
    );
  }
}

class _ReviewCard extends StatelessWidget {
  final ListerReviewData review;
  const _ReviewCard({required this.review});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerLow,
          border:
              Border.all(color: Theme.of(context).colorScheme.outlineVariant),
          borderRadius: BorderRadius.circular(16)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          CircleAvatar(
              radius: 17,
              backgroundColor: Theme.of(context).colorScheme.primaryContainer,
              child: Text(
                  review.reviewerName.trim().isEmpty
                      ? 'H'
                      : review.reviewerName.trim()[0].toUpperCase(),
                  style: TextStyle(
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                      fontWeight: FontWeight.w800))),
          const SizedBox(width: 10),
          Expanded(
              child: Text(review.reviewerName,
                  style: const TextStyle(fontWeight: FontWeight.w700))),
          _Stars(rating: review.rating, small: true),
        ]),
        const SizedBox(height: 12),
        Text(review.comment,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurface, height: 1.45)),
        if (review.ownerResponse != null) ...[
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Response from the lister',
                    style: TextStyle(
                        color: Theme.of(context).colorScheme.primary,
                        fontSize: 12,
                        fontWeight: FontWeight.w700)),
                const SizedBox(height: 5),
                Text(review.ownerResponse!,
                    style: Theme.of(context).textTheme.bodyMedium),
              ],
            ),
          ),
        ],
      ]),
    );
  }
}

class _Stars extends StatelessWidget {
  final int rating;
  final bool small;
  const _Stars({required this.rating, this.small = false});

  @override
  Widget build(BuildContext context) => Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(
          5,
          (index) => Icon(
              index < rating ? Icons.star_rounded : Icons.star_border_rounded,
              size: small ? 14 : 19,
              color: AppColors.warning)));
}
