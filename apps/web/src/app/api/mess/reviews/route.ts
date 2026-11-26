import { NextRequest, NextResponse } from 'next/server';
import { getAdminClient } from '@/lib/supabase/admin';
import { requireProviderOwnership } from '@/lib/provider-auth';
import { isAllowedMediaUrl, requireCustomerIdentity } from '@/lib/auth-session';
import { checkRateLimit } from '@/lib/rate-limiter';
import { platformStore } from '@/lib/platform-service';

export const dynamic = 'force-dynamic';

export async function GET(req: NextRequest) {
  const providerId = new URL(req.url).searchParams.get('provider_id')?.trim();
  if (!providerId) {
    return NextResponse.json({ success: false, error: 'provider_id is required.' }, { status: 400 });
  }

  const admin = getAdminClient();
  let rows: any[] = [];

  if (admin) {
    try {
      const { data, error } = await admin
        .from('mess_reviews')
        .select('id,provider_id,customer_id,rating,review_text,tags,image_paths,partner_reply,partner_replied_at,created_at,profiles:customer_id(display_name,avatar_path)')
        .eq('provider_id', providerId)
        .order('created_at', { ascending: false })
        .limit(100);

      if (!error && data) {
        rows = data;
      } else {
        // Fallback select if optional columns aren't migrated yet
        const { data: basic } = await admin
          .from('mess_reviews')
          .select('id,provider_id,customer_id,rating,review_text,tags,created_at,profiles:customer_id(display_name,avatar_path)')
          .eq('provider_id', providerId)
          .order('created_at', { ascending: false })
          .limit(100);
        rows = basic ?? [];
      }
    } catch (e: any) {
      console.warn('mess_reviews GET error:', e?.message);
    }
  }

  if (rows.length === 0 && platformStore.reviews.size > 0) {
    for (const r of platformStore.reviews.values()) {
      if (r.provider_id === providerId) rows.push(r);
    }
  }

  const breakdown: Record<number, number> = { 5: 0, 4: 0, 3: 0, 2: 0, 1: 0 };
  const tagCounts = new Map<string, number>();
  const images: string[] = [];
  let sumRating = 0;

  const formatted = rows.map((r) => {
    const rating = Math.min(5, Math.max(1, Number(r.rating || 5)));
    breakdown[rating] = (breakdown[rating] || 0) + 1;
    sumRating += rating;

    const tags = Array.isArray(r.tags) ? r.tags : [];
    for (const t of tags) {
      const clean = String(t).trim();
      if (clean) tagCounts.set(clean, (tagCounts.get(clean) || 0) + 1);
    }

    const imgs = Array.isArray(r.image_paths) ? r.image_paths : [];
    for (const img of imgs) {
      if (img) images.push(String(img));
    }

    const profile = Array.isArray(r.profiles) ? r.profiles[0] : r.profiles;
    return {
      id: r.id,
      provider_id: r.provider_id,
      customer_id: r.customer_id,
      customer_name: profile?.display_name || r.customer_name || 'Verified Customer',
      avatar_path: profile?.avatar_path || null,
      rating,
      review_text: r.review_text || '',
      tags,
      image_paths: imgs,
      partner_reply: r.partner_reply || null,
      partner_replied_at: r.partner_replied_at || null,
      created_at: r.created_at,
    };
  });

  const popularTags = Array.from(tagCounts.entries())
    .sort((a, b) => b[1] - a[1])
    .slice(0, 8)
    .map(([tag, count]) => ({ tag, count }));

  return NextResponse.json(
    {
      success: true,
      provider_id: providerId,
      average_rating: formatted.length > 0 ? Math.round((sumRating / formatted.length) * 10) / 10 : null,
      total_reviews: formatted.length,
      breakdown,
      images,
      popular_tags: popularTags,
      reviews: formatted,
    },
    { headers: { 'Cache-Control': 'private, no-store' } }
  );
}

export async function POST(req: NextRequest) {
  const body = await req.json().catch(() => ({}));
  const providerId = String(body.provider_id || '').trim();
  const claimedCustomerId = String(body.customer_id || '').trim();
  const identity = await requireCustomerIdentity(req, claimedCustomerId || undefined);
  if (!identity.ok) {
    return NextResponse.json({ success: false, error: identity.error }, { status: identity.status });
  }
  const customerId = identity.isAdmin && claimedCustomerId ? claimedCustomerId : identity.userId;

  const rl = checkRateLimit(`mess-review:${customerId}`, 10, 10 * 60 * 1000);
  if (!rl.isAllowed) {
    return NextResponse.json({ success: false, error: 'Too many review submissions. Please try again later.' }, { status: 429 });
  }

  const rating = Number(body.rating);
  const reviewText = String(body.review_text || '').trim().slice(0, 1000);
  const tags = Array.isArray(body.tags) ? body.tags.map((t: any) => String(t).trim()).filter(Boolean).slice(0, 6) : [];
  const rawImages = Array.isArray(body.image_paths) ? body.image_paths.map((i: any) => String(i).trim()).filter(Boolean).slice(0, 4) : [];
  if (rawImages.some((url: string) => !isAllowedMediaUrl(url))) {
    return NextResponse.json({ success: false, error: 'One or more image URLs are invalid or unsupported.' }, { status: 400 });
  }
  const imagePaths = rawImages;

  if (!providerId || !customerId || isNaN(rating) || rating < 1 || rating > 5) {
    return NextResponse.json({ success: false, error: 'provider_id, customer_id, and rating (1-5) are required.' }, { status: 400 });
  }

  // Only verified subscribers (active/paused/expired/cancelled, never unpaid pending_payment) can submit a review
  const adminCheck = getAdminClient();
  let hasVerifiedSub = false;
  if (adminCheck) {
    try {
      const { data: subRow } = await adminCheck
        .from('subscriptions')
        .select('id,status')
        .eq('provider_id', providerId)
        .eq('customer_id', customerId)
        .in('status', ['active', 'paused', 'expired', 'cancelled'])
        .limit(1)
        .maybeSingle();
      if (subRow) hasVerifiedSub = true;
    } catch {}
  }
  if (!hasVerifiedSub) {
    hasVerifiedSub = Array.from(platformStore.subscriptions.values()).some(
      (s) => s.provider_id === providerId && s.customer_id === customerId && s.status !== 'pending_payment'
    );
  }
  if (!hasVerifiedSub && !identity.isAdmin) {
    return NextResponse.json(
      { success: false, error: 'Only verified kitchen subscribers can submit a review.' },
      { status: 403 }
    );
  }

  const admin = getAdminClient();
  if (admin) {
    try {
      const { data, error } = await admin
        .from('mess_reviews')
        .insert({
          provider_id: providerId,
          customer_id: customerId,
          rating: Math.round(rating),
          review_text: reviewText,
          tags,
          image_paths: imagePaths,
        })
        .select('*')
        .single();

      if (!error && data) {
        return NextResponse.json({ success: true, review: data }, { status: 201 });
      }
      // Retry without optional image_paths if column not migrated yet
      const { data: fallbackRow, error: err2 } = await admin
        .from('mess_reviews')
        .insert({
          provider_id: providerId,
          customer_id: customerId,
          rating: Math.round(rating),
          review_text: reviewText,
          tags,
        })
        .select('*')
        .single();
      if (!err2 && fallbackRow) {
        return NextResponse.json({ success: true, review: fallbackRow }, { status: 201 });
      }
    } catch (e: any) {
      return NextResponse.json({ success: false, error: e?.message || 'Failed to save review.' }, { status: 500 });
    }
  }

  const memReview: any = {
    id: `rev-${Date.now()}`,
    provider_id: providerId,
    customer_id: customerId,
    customer_name: body.customer_name || 'Customer',
    rating: Math.round(rating),
    review_text: reviewText,
    tags,
    image_paths: imagePaths,
    created_at: new Date().toISOString(),
  };
  platformStore.reviews.set(memReview.id, memReview);
  return NextResponse.json({ success: true, review: memReview }, { status: 201 });
}

export async function PATCH(req: NextRequest) {
  const body = await req.json().catch(() => ({}));
  const reviewId = String(body.review_id || '').trim();
  const providerId = String(body.provider_id || '').trim();
  const reply = String(body.partner_reply || body.reply || '').trim();

  if (!reviewId || !providerId || !reply) {
    return NextResponse.json({ success: false, error: 'review_id, provider_id, and partner_reply are required.' }, { status: 400 });
  }

  const access = await requireProviderOwnership(req, providerId);
  if (!access.ok) {
    return NextResponse.json({ success: false, error: access.error }, { status: access.status });
  }

  const admin = getAdminClient();
  if (admin) {
    const { data, error } = await admin
      .from('mess_reviews')
      .update({ partner_reply: reply, partner_replied_at: new Date().toISOString() })
      .eq('id', reviewId)
      .eq('provider_id', providerId)
      .select('*')
      .single();
    if (!error && data) {
      return NextResponse.json({ success: true, review: data });
    }
  }
  return NextResponse.json({ success: false, error: 'Unable to save reply.' }, { status: 503 });
}
