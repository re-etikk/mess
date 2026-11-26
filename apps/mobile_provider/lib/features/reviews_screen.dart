import 'package:flutter/material.dart';

import '../core/theme/thali_partner_theme.dart';
import '../core/widgets/partner_widgets.dart';
import '../models/models.dart';
import '../services/provider_api_service.dart';

class PartnerReviewsScreen extends StatefulWidget {
  const PartnerReviewsScreen({super.key, required this.session});
  final ProviderSession session;

  @override
  State<PartnerReviewsScreen> createState() => _PartnerReviewsScreenState();
}

class _PartnerReviewsScreenState extends State<PartnerReviewsScreen> {
  bool _loading = true;
  String? _error;
  double? _avgRating;
  int _totalReviews = 0;
  Map<String, dynamic> _breakdown = const {};
  List<Map<String, dynamic>> _reviews = const [];
  Map<String, dynamic>? _insights;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await ProviderApiService.fetchReviews(widget.session.providerId);
      final reviewsList = ((data['reviews'] as List?) ?? const [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
      Map<String, dynamic>? insights;
      if (reviewsList.length >= 2) {
        try {
          insights = await ProviderApiService.fetchReviewInsights(widget.session.providerId);
        } catch (_) {}
      }
      if (!mounted) return;
      setState(() {
        _avgRating = (data['average_rating'] as num?)?.toDouble();
        _totalReviews = (data['total_reviews'] as num?)?.toInt() ?? 0;
        _breakdown = (data['breakdown'] as Map<String, dynamic>?) ?? const {};
        _reviews = reviewsList;
        _insights = insights;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _replySheet(Map<String, dynamic> review) async {
    final ctrl = TextEditingController(text: review['partner_reply']?.toString() ?? '');
    bool submitting = false;
    bool drafting = false;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: ThaliColors.card,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 14,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(color: ThaliColors.stroke, borderRadius: BorderRadius.circular(99)),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Reply to ${review['customer_name'] ?? 'Customer'}',
                      style: const TextStyle(fontSize: 17.5, fontWeight: FontWeight.w800, color: ThaliColors.ink),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: drafting
                        ? null
                        : () async {
                            setSheetState(() => drafting = true);
                            try {
                              final draft = await ProviderApiService.draftReviewReply(
                                providerId: widget.session.providerId,
                                customerName: review['customer_name']?.toString() ?? 'Customer',
                                rating: (review['rating'] as num?)?.toInt() ?? 5,
                                reviewText: review['review_text']?.toString() ?? '',
                              );
                              if (draft.isNotEmpty) {
                                ctrl.text = draft;
                              }
                            } catch (e) {
                              if (mounted) showPartnerNotice(context, '$e', isError: true);
                            } finally {
                              setSheetState(() => drafting = false);
                            }
                          },
                    icon: const Icon(Icons.edit_note_outlined, size: 15, color: ThaliColors.ink),
                    label: Text(
                      drafting ? 'Drafting...' : 'Suggest reply',
                      style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: ThaliColors.ink),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: ctrl,
                maxLines: 3,
                decoration: const InputDecoration(hintText: 'Thank you for your feedback...'),
              ),
              const SizedBox(height: 14),
              PartnerActionButton(
                label: 'Publish Reply',
                loading: submitting,
                onPressed: () async {
                  final text = ctrl.text.trim();
                  if (text.isEmpty) return;
                  setSheetState(() => submitting = true);
                  try {
                    await ProviderApiService.replyToReview(
                      providerId: widget.session.providerId,
                      reviewId: review['id'].toString(),
                      reply: text,
                    );
                    if (ctx.mounted) Navigator.pop(ctx);
                    if (mounted) {
                      showPartnerNotice(context, 'Reply published.');
                      _load();
                    }
                  } catch (e) {
                    setSheetState(() => submitting = false);
                    if (mounted) {
                      showPartnerNotice(context, e.toString().replaceFirst('Exception: ', ''), isError: true);
                    }
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ThaliColors.scaffold,
      appBar: AppBar(
        title: const Text('Ratings & Reviews'),
      ),
      body: RefreshIndicator(
        color: ThaliColors.primary,
        onRefresh: _load,
        child: _loading
            ? const PartnerSkeletonList(itemCount: 3, cardHeight: 112)
            : _error != null
                ? ListView(
                    physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                    padding: const EdgeInsets.all(24),
                    children: [
                      const SizedBox(height: 24),
                      CardSurface(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          children: [
                            const Icon(Icons.cloud_off_rounded, size: 36, color: ThaliColors.muted),
                            const SizedBox(height: 10),
                            Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: ThaliColors.red, fontSize: 13.5)),
                            const SizedBox(height: 14),
                            PartnerActionButton(label: 'Retry', height: 42, onPressed: _load),
                          ],
                        ),
                      ),
                    ],
                  )
                : ListView(
                    physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              children: [
                CardSurface(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          RatingBadge(rating: _avgRating),
                          const SizedBox(height: 6),
                          Text(
                            _totalReviews > 0 ? '$_totalReviews verified reviews' : 'No reviews yet',
                            style: const TextStyle(fontSize: 12.5, color: ThaliColors.muted, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                      const SizedBox(width: 18),
                      Expanded(
                        child: Column(
                          children: [5, 4, 3, 2, 1].map((star) {
                            final count = (_breakdown['$star'] as num?)?.toInt() ?? 0;
                            final pct = _totalReviews > 0 ? count / _totalReviews : 0.0;
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 2),
                              child: Row(
                                children: [
                                  SizedBox(
                                    width: 14,
                                    child: Text('$star', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                                  ),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(99),
                                      child: LinearProgressIndicator(
                                        value: pct,
                                        minHeight: 6,
                                        backgroundColor: ThaliColors.subtle,
                                        valueColor: const AlwaysStoppedAnimation<Color>(ThaliColors.green),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ],
                  ),
                ),
                if (_insights != null) ...[
                  const SizedBox(height: 12),
                  CardSurface(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.analytics_outlined, size: 16, color: ThaliColors.ink),
                            SizedBox(width: 6),
                            Text('Customer Summary', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: ThaliColors.ink)),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _insights!['summary']?.toString() ?? '',
                          style: const TextStyle(fontSize: 12.5, color: ThaliColors.body, height: 1.35),
                        ),
                        if ((_insights!['focus_area']?.toString() ?? '').isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Text(
                            'Focus: ${_insights!['focus_area']}',
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: ThaliColors.primary),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                if (_reviews.isEmpty)
                  const CardSurface(
                    padding: EdgeInsets.all(24),
                    child: Center(
                      child: Text(
                        'Customer ratings will appear here once subscribers submit reviews.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: ThaliColors.muted, fontSize: 13),
                      ),
                    ),
                  )
                else
                  ..._reviews.map((r) {
                    final reply = r['partner_reply']?.toString() ?? '';
                    final tags = ((r['tags'] as List?) ?? const []).map((t) => t.toString()).toList();
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: CardSurface(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    r['customer_name']?.toString() ?? 'Subscriber',
                                    style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800, color: ThaliColors.ink),
                                  ),
                                ),
                                RatingBadge(rating: (r['rating'] as num?)?.toDouble()),
                              ],
                            ),
                            if ((r['review_text']?.toString() ?? '').isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Text(
                                r['review_text'].toString(),
                                style: const TextStyle(fontSize: 13, color: ThaliColors.body, height: 1.4),
                              ),
                            ],
                            if (tags.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 6,
                                runSpacing: 6,
                                children: tags
                                    .map((t) => Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                          decoration: BoxDecoration(
                                            color: ThaliColors.subtle,
                                            borderRadius: BorderRadius.circular(99),
                                          ),
                                          child: Text(t, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                                        ))
                                    .toList(),
                              ),
                            ],
                            if (reply.isNotEmpty) ...[
                              const SizedBox(height: 10),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: ThaliColors.primarySoft,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  'Kitchen reply: $reply',
                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: ThaliColors.primaryDark),
                                ),
                              ),
                            ],
                            const SizedBox(height: 8),
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton.icon(
                                onPressed: () => _replySheet(r),
                                icon: const Icon(Icons.reply_rounded, size: 16, color: ThaliColors.primary),
                                label: Text(
                                  reply.isEmpty ? 'Reply to Customer' : 'Edit Reply',
                                  style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: ThaliColors.primary),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
              ],
            ),
      ),
    );
  }
}
