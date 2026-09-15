import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../core/localquest_theme.dart';
import '../core/localquest_widgets.dart';
import '../services/review_service.dart';

/// Shows every review the signed-in tourist has posted, across all
/// businesses, most recent first. Read-only — editing/deleting a posted
/// review isn't supported (see ReviewService/firestore.rules: reviews
/// are immutable once created, by design, to keep ratings history
/// honest).
class MyReviewsScreen extends StatelessWidget {
  const MyReviewsScreen({super.key, required this.userId});
  final String userId;

  String _formatDate(DateTime date) => DateFormat('d MMM yyyy').format(date);

  @override
  Widget build(BuildContext context) => LqPage(
    child: Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const LqBackButton(label: 'Profile'),
          const SizedBox(height: 8),
          const Text(
            'My reviews',
            style: TextStyle(
              fontSize: 32,
              height: 1.12,
              fontWeight: FontWeight.w800,
              letterSpacing: -1.2,
              color: LqColors.ink,
            ),
          ),
          const SizedBox(height: 20),
          Expanded(
            child: StreamBuilder<List<Review>>(
              stream: ReviewService.instance.watchReviewsForUser(userId),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting &&
                    !snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  // Most likely cause: the required composite index for
                  // this collection-group query hasn't been created yet.
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Text(
                        'Could not load your reviews: ${snapshot.error}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: LqColors.muted),
                      ),
                    ),
                  );
                }

                final reviews = snapshot.data ?? const <Review>[];

                if (reviews.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.rate_review_outlined,
                            size: 48,
                            color: LqColors.muted,
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'No reviews yet.',
                            style: TextStyle(
                              color: LqColors.muted,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Reviews you post after visiting a business will show up here.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: LqColors.muted, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return ListView.separated(
                  itemCount: reviews.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final review = reviews[index];
                    return LqCard(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  review.businessName.isNotEmpty
                                      ? review.businessName
                                      : 'Business',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    color: LqColors.ink,
                                  ),
                                ),
                              ),
                              Text(
                                _formatDate(review.createdAt),
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: LqColors.muted,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: List.generate(5, (i) {
                              final filled = i < review.rating.round();
                              return Icon(
                                filled ? Icons.star : Icons.star_border,
                                size: 16,
                                color: const Color(0xFFF5A623),
                              );
                            }),
                          ),
                          if (review.text.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Text(
                              review.text,
                              style: const TextStyle(
                                fontSize: 13,
                                color: LqColors.muted,
                                height: 1.4,
                              ),
                            ),
                          ],
                          if (review.photoUrls.isNotEmpty) ...[
                            const SizedBox(height: 10),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(14),
                              child: Image.network(
                                review.photoUrls.first,
                                height: 120,
                                width: double.infinity,
                                fit: BoxFit.cover,
                                errorBuilder: (_, _, _) => const SizedBox.shrink(),
                              ),
                            ),
                          ],
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    ),
  );
}
