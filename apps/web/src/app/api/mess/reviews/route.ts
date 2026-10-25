import { NextRequest, NextResponse } from 'next/server';
import { platformStore } from '@/lib/platform-service';
import { MessReview } from '@/types';
import crypto from 'crypto';

export async function GET(req: NextRequest) {
  const { searchParams } = new URL(req.url);
  const providerId = searchParams.get('provider_id') || 'prov-radhe-001';

  const reviews = Array.from(platformStore.reviews.values()).filter(
    (r) => r.provider_id === providerId
  );

  const totalReviews = reviews.length;
  const avgRating = totalReviews > 0
    ? Number((reviews.reduce((acc, r) => acc + r.rating, 0) / totalReviews).toFixed(1))
    : 5.0;

  return NextResponse.json({
    success: true,
    provider_id: providerId,
    average_rating: avgRating,
    total_reviews: totalReviews,
    reviews: reviews.sort((a, b) => b.created_at.localeCompare(a.created_at)),
  });
}

export async function POST(req: NextRequest) {
  try {
    const body = await req.json().catch(() => ({}));
    const providerId = body.provider_id || 'prov-radhe-001';
    const customerId = body.customer_id || 'cust-ritik-001';
    const customerName = body.customer_name || 'Verified Student';
    const rating = Number(body.rating);
    const reviewText = body.review_text || body.comment || '';
    const tags = Array.isArray(body.tags) ? body.tags : ['Delicious', 'Homely'];

    if (!rating || rating < 1 || rating > 5) {
      return NextResponse.json(
        { success: false, error: 'Rating must be an integer between 1 and 5.' },
        { status: 400 }
      );
    }

    const reviewId = `rev-${Date.now()}-${crypto.randomBytes(3).toString('hex')}`;
    const newReview: MessReview = {
      id: reviewId,
      provider_id: providerId,
      customer_id: customerId,
      customer_name: customerName,
      rating,
      review_text: reviewText,
      food_quality_score: Number(body.food_quality_score) || rating,
      hygiene_score: Number(body.hygiene_score) || rating,
      tags,
      created_at: new Date().toISOString(),
    };

    platformStore.reviews.set(reviewId, newReview);

    // Update provider aggregate rating
    const provider = platformStore.providers.get(providerId);
    if (provider) {
      const allReviews = Array.from(platformStore.reviews.values()).filter((r) => r.provider_id === providerId);
      provider.total_reviews = allReviews.length;
      provider.rating = Number((allReviews.reduce((sum, r) => sum + r.rating, 0) / allReviews.length).toFixed(1));
    }

    return NextResponse.json({
      success: true,
      review: newReview,
      message: 'Thank you! Your review has been published.',
    });
  } catch (err: any) {
    return NextResponse.json(
      { success: false, error: err.message || 'Failed to submit review' },
      { status: 500 }
    );
  }
}
