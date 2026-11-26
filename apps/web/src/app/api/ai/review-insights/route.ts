import { NextRequest, NextResponse } from 'next/server';
import { z } from 'zod';
import { getAdminClient } from '@/lib/supabase/admin';
import { platformStore } from '@/lib/platform-service';
import { requireProviderOwnership } from '@/lib/provider-auth';
import {
  callGeminiJson,
  heuristicReplyDraft,
  heuristicReviewSummary,
} from '@/lib/ai-service';

export const dynamic = 'force-dynamic';

const SummarySchema = z.object({
  summary: z.string(),
  strengths: z.array(z.string()).default([]),
  focus_area: z.string().default(''),
});

const DraftSchema = z.object({
  reply: z.string(),
});

export async function POST(req: NextRequest) {
  const body = await req.json().catch(() => ({}));
  const providerId = String(body.provider_id || '').trim();
  const mode = String(body.mode || 'summary').trim();

  if (!providerId) {
    return NextResponse.json({ success: false, error: 'provider_id is required.' }, { status: 400 });
  }

  const access = await requireProviderOwnership(req, providerId);
  if (!access.ok) {
    return NextResponse.json({ success: false, error: access.error }, { status: access.status });
  }

  if (mode === 'draft_reply') {
    const customerName = String(body.customer_name || 'Subscriber').trim();
    const rating = Number(body.rating || 5);
    const reviewText = String(body.review_text || '').trim();

    const prompt = `Draft a warm, concise, polite 2-sentence kitchen owner reply to a verified tiffin customer review. No emojis.
Customer Name: ${customerName}
Rating: ${rating}/5
Review: ${reviewText || '(No text comment)'}
Return JSON: { "reply": string }`;

    const res = await callGeminiJson({
      prompt,
      schema: DraftSchema,
      fallback: () => ({ reply: heuristicReplyDraft(customerName, rating, reviewText) }),
    });

    return NextResponse.json({
      success: true,
      source: res.source,
      reply: res.data.reply,
    });
  }

  // Summary mode
  const admin = getAdminClient();
  let reviews: any[] = [];
  if (admin) {
    try {
      const { data } = await admin
        .from('mess_reviews')
        .select('rating,review_text,tags')
        .eq('provider_id', providerId)
        .order('created_at', { ascending: false })
        .limit(40);
      reviews = data ?? [];
    } catch {}
  }

  if (reviews.length === 0) {
    for (const r of platformStore.reviews.values()) {
      if (r.provider_id === providerId) reviews.push(r);
    }
  }

  if (reviews.length < 2) {
    return NextResponse.json({
      success: true,
      source: 'heuristic',
      ...heuristicReviewSummary(reviews),
    });
  }

  const digest = reviews
    .slice(0, 25)
    .map((r) => `[${r.rating}*] ${(r.review_text || '').slice(0, 140)} Tags: ${(r.tags || []).join(', ')}`)
    .join('\n');

  const res = await callGeminiJson({
    prompt: `Summarize these real tiffin customer reviews for the kitchen owner concisely. No emojis.
Reviews:
${digest}
Return JSON: { "summary": string (max 2 sentences), "strengths": string[] (max 3 tags), "focus_area": string (1 actionable focus) }`,
    schema: SummarySchema,
    fallback: () => heuristicReviewSummary(reviews),
  });

  return NextResponse.json({
    success: true,
    source: res.source,
    ...res.data,
  });
}
