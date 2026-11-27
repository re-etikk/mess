import { z } from 'zod';

const AI_STUDIO_ENDPOINT =
  'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent';
const VERTEX_EXPRESS_ENDPOINT =
  'https://aiplatform.googleapis.com/v1/publishers/google/models/gemini-2.5-flash:generateContent';

export function resolveGeminiConfig(): { url: string; headers: Record<string, string>; mode: 'vertex_express' | 'ai_studio' } | null {
  const apiKey = (process.env.VERTEX_AI_API_KEY || process.env.GEMINI_API_KEY || '').trim();
  if (!apiKey) return null;

  if (apiKey.startsWith('AQ.')) {
    return {
      url: VERTEX_EXPRESS_ENDPOINT,
      headers: {
        'Content-Type': 'application/json',
        'x-goog-api-key': apiKey,
      },
      mode: 'vertex_express',
    };
  }

  return {
    url: `${AI_STUDIO_ENDPOINT}?key=${encodeURIComponent(apiKey)}`,
    headers: { 'Content-Type': 'application/json' },
    mode: 'ai_studio',
  };
}

export async function callGeminiJson<T>({
  prompt,
  imageBase64,
  schema,
  fallback,
}: {
  prompt: string;
  imageBase64?: string | null;
  schema: z.ZodType<T>;
  fallback: () => T;
}): Promise<{ data: T; source: 'gemini' | 'heuristic' }> {
  const cfg = resolveGeminiConfig();
  if (!cfg) {
    return { data: fallback(), source: 'heuristic' };
  }

  try {
    const parts: Array<Record<string, any>> = [{ text: prompt }];
    if (imageBase64 && imageBase64.trim()) {
      const cleaned = imageBase64.trim();
      const match = cleaned.match(/^data:(image\/[a-zA-Z0-9+.-]+);base64,(.+)$/);
      const mimeType = match ? match[1] : 'image/jpeg';
      const b64 = match ? match[2] : cleaned;
      parts.push({ inlineData: { mimeType, data: b64 } });
    }

    const res = await fetch(cfg.url, {
      method: 'POST',
      headers: cfg.headers,
      body: JSON.stringify({
        contents: [{ role: 'user', parts }],
        generationConfig: {
          responseMimeType: 'application/json',
          temperature: 0.2,
        },
      }),
    });

    if (!res.ok) {
      const errSnippet = await res.text().catch(() => '');
      console.warn(`Gemini (${cfg.mode}) HTTP ${res.status}:`, errSnippet.slice(0, 220));
      return { data: fallback(), source: 'heuristic' };
    }

    const json = await res.json();
    const rawText = json?.candidates?.[0]?.content?.parts?.[0]?.text;
    if (typeof rawText !== 'string' || !rawText.trim()) {
      return { data: fallback(), source: 'heuristic' };
    }

    const parsedJson = JSON.parse(rawText);
    const validated = schema.safeParse(parsedJson);
    if (validated.success) {
      return { data: validated.data, source: 'gemini' };
    }
  } catch (err: any) {
    console.warn('Gemini JSON fallback triggered:', err?.message);
  }

  return { data: fallback(), source: 'heuristic' };
}

export type ForecastSlot = 'BREAKFAST' | 'LUNCH' | 'SNACKS' | 'DINNER';

export interface SlotForecast {
  slot: ForecastSlot;
  scheduled_subscribers: number;
  skipped_today: number;
  pickup_count: number;
  delivery_count: number;
  attendance_rate: number;
  recommended_plates: number;
  estimated_waste_saved_inr: number;
}

export interface ChurnAlert {
  subscription_id: string;
  customer_id: string;
  customer_name: string;
  customer_phone: string;
  plan_name: string;
  risk_reason: string;
  days_until_expiry: number;
  days_since_last_scan: number | null;
}

export function computeKitchenForecast({
  subscriptions,
  eventsToday,
  redemptionsLast28Days,
  targetDateStr,
  supportsDelivery,
  avgMealPriceInr = 70,
}: {
  subscriptions: any[];
  eventsToday: any[];
  redemptionsLast28Days: any[];
  targetDateStr: string;
  supportsDelivery: boolean;
  avgMealPriceInr?: number;
}): {
  date: string;
  slots: SlotForecast[];
  total_recommended_plates: number;
  total_skipped: number;
  total_waste_saved_inr: number;
  churn_alerts: ChurnAlert[];
} {
  const dowJs = new Date(`${targetDateStr}T12:00:00+05:30`).getUTCDay();
  const dow1To7 = dowJs === 0 ? 7 : dowJs;
  const nowMs = new Date(`${targetDateStr}T12:00:00+05:30`).getTime();

  const eligibleSubs = subscriptions.filter((s) => {
    if (s.status !== 'active') return false;
    if (s.starts_at && String(s.starts_at).slice(0, 10) > targetDateStr) return false;
    if (s.expires_at && String(s.expires_at).slice(0, 10) < targetDateStr) return false;
    const rDays =
      Array.isArray(s.repeat_days) && s.repeat_days.length > 0
        ? s.repeat_days.map((d: any) => Number(d))
        : [1, 2, 3, 4, 5, 6, 7];
    return rDays.includes(dow1To7);
  });

  const slotsList: ForecastSlot[] = ['BREAKFAST', 'LUNCH', 'SNACKS', 'DINNER'];

  const slots: SlotForecast[] = slotsList.map((slot) => {
    const slotLower = slot.toLowerCase();
    const slotSubs = eligibleSubs.filter((s) => {
      const cfg = s.selected_slots;
      if (!cfg || typeof cfg !== 'object' || Object.keys(cfg).length === 0) {
        return slot !== 'SNACKS'; // Default plans exclude snacks unless configured
      }
      return Boolean(cfg[slotLower]);
    });

    const slotEvents = eventsToday.filter((e) => String(e.slot || '').toUpperCase() === slot);
    const skippedSet = new Set(slotEvents.filter((e) => e.status === 'skipped').map((e) => e.subscription_id));
    const skippedCount = slotSubs.filter((s) => skippedSet.has(s.id)).length;
    const nonSkipped = slotSubs.filter((s) => !skippedSet.has(s.id));

    let deliveryCount = 0;
    let totalPlatesRequested = 0;
    for (const s of nonSkipped) {
      const cfgQty = Number(s.selected_slots?.[slotLower]?.quantity ?? 1);
      const qty = Number.isFinite(cfgQty) && cfgQty > 0 ? Math.min(10, Math.round(cfgQty)) : 1;
      totalPlatesRequested += qty;
      const ev = slotEvents.find((e) => e.subscription_id === s.id);
      const mode = ev?.fulfillment_mode || s.fulfillment_mode || (supportsDelivery ? 'delivery' : 'pickup');
      if (mode === 'delivery') deliveryCount += qty;
    }
    const pickupCount = Math.max(0, totalPlatesRequested - deliveryCount);

    // Bayesian-smoothed + recency-weighted 28-day attendance estimator
    const slotRedemptions = redemptionsLast28Days.filter((r) => {
      const rSlot = String(r.slot || r.meal_bookings?.meal_slots?.name || '').toUpperCase();
      return rSlot === slot;
    });

    let attendanceRate = 0.92;
    if (slotRedemptions.length >= 3 && totalPlatesRequested > 0) {
      const dayBuckets = new Map<string, number>();
      for (const r of slotRedemptions) {
        const dKey = String(r.redeemed_at || r.date || '').slice(0, 10);
        if (!dKey) continue;
        dayBuckets.set(dKey, (dayBuckets.get(dKey) || 0) + 1);
      }
      if (dayBuckets.size > 0) {
        const sortedDays = Array.from(dayBuckets.entries()).sort((a, b) => a[0].localeCompare(b[0]));
        let weightedSum = 0;
        let weightTotal = 0;
        sortedDays.forEach(([, count], idx) => {
          const recencyWeight = 1 + idx * 0.25; // EMA-style linear recency boost
          weightedSum += count * recencyWeight;
          weightTotal += recencyWeight;
        });
        const expectedDailyCount = weightedSum / Math.max(1, weightTotal);
        const empiricalRatio = expectedDailyCount / Math.max(1, totalPlatesRequested);
        // Bayesian shrinkage towards prior 0.92 so noisy days don't whip-saw
        const shrunk = (empiricalRatio * sortedDays.length + 0.92 * 3) / (sortedDays.length + 3);
        attendanceRate = Math.min(1.0, Math.max(0.65, Number(shrunk.toFixed(2))));
      }
    }

    const recommendedPlates = totalPlatesRequested === 0 ? 0 : Math.max(1, Math.round(totalPlatesRequested * attendanceRate));

    return {
      slot,
      scheduled_subscribers: totalPlatesRequested,
      skipped_today: skippedCount,
      pickup_count: pickupCount,
      delivery_count: deliveryCount,
      attendance_rate: attendanceRate,
      recommended_plates: recommendedPlates,
      estimated_waste_saved_inr: Math.round(skippedCount * avgMealPriceInr),
    };
  });

  // Subscriber Churn & Renewal Radar
  const churnAlerts: ChurnAlert[] = [];
  for (const s of subscriptions) {
    if (s.status !== 'active') continue;
    // Skip single-day meal orders from subscription churn alerts
    if (Number(s.duration_days || 0) === 1 || (s.plan_type === 'meal_credits' && Number(s.initial_meal_credits || 0) === 1)) {
      continue;
    }
    const expMs = s.expires_at ? new Date(s.expires_at).getTime() : nowMs + 30 * 86400000;
    const daysUntilExpiry = Math.max(0, Math.ceil((expMs - nowMs) / 86400000));

    const userRedemptions = redemptionsLast28Days
      .filter((r) => r.user_id === s.customer_id || r.customer_id === s.customer_id || r.subscription_id === s.id)
      .sort((a, b) => new Date(b.redeemed_at || 0).getTime() - new Date(a.redeemed_at || 0).getTime());

    let daysSinceLastScan: number | null = null;
    if (userRedemptions.length > 0 && userRedemptions[0].redeemed_at) {
      daysSinceLastScan = Math.max(0, Math.floor((nowMs - new Date(userRedemptions[0].redeemed_at).getTime()) / 86400000));
    } else if (s.starts_at) {
      const daysSinceStart = Math.floor((nowMs - new Date(s.starts_at).getTime()) / 86400000);
      if (daysSinceStart >= 4) daysSinceLastScan = daysSinceStart;
    }

    const expiringSoon = daysUntilExpiry <= 5;
    const inactive = daysSinceLastScan != null && daysSinceLastScan >= 4;
    if (expiringSoon || inactive) {
      const profile = Array.isArray(s.profiles) ? s.profiles[0] : s.profiles;
      const reason = expiringSoon
        ? daysUntilExpiry === 0
          ? 'Expires today'
          : `Expires in ${daysUntilExpiry} day${daysUntilExpiry === 1 ? '' : 's'}`
        : `No check-in for ${daysSinceLastScan} days`;

      churnAlerts.push({
        subscription_id: s.id,
        customer_id: s.customer_id,
        customer_name: profile?.display_name || s.customer_name || 'Subscriber',
        customer_phone: profile?.phone_e164 || s.customer_phone || '',
        plan_name: s.plan_name_snapshot || s.plan_name || 'Meal Pass',
        risk_reason: reason,
        days_until_expiry: daysUntilExpiry,
        days_since_last_scan: daysSinceLastScan,
      });
    }
  }

  return {
    date: targetDateStr,
    slots,
    total_recommended_plates: slots.reduce((acc, s) => acc + s.recommended_plates, 0),
    total_skipped: slots.reduce((acc, s) => acc + s.skipped_today, 0),
    total_waste_saved_inr: slots.reduce((acc, s) => acc + s.estimated_waste_saved_inr, 0),
    churn_alerts: churnAlerts.slice(0, 10),
  };
}

export function recommendBestPlan({
  plans,
  weeklyDays = 6,
  weeklySkips = 0,
  mealsPerDay = 2,
}: {
  plans: Array<{
    id: string;
    name: string;
    plan_type: string;
    duration_days: number;
    price_inr: number;
    meal_credits?: number | null;
  }>;
  weeklyDays?: number;
  weeklySkips?: number;
  mealsPerDay?: number;
}) {
  // Filter out 1-day coupons or negligible test plans (< ₹30) when meaningful plans exist
  const realisticPlans = plans.filter((p) => Number(p.price_inr) >= 30 && Number(p.duration_days || 1) > 1);
  const candidatePlans = realisticPlans.length > 0 ? realisticPlans : plans.filter((p) => Number(p.price_inr) > 0);

  if (!candidatePlans.length) {
    return { recommended_plan_id: null, savings_inr: 0, headline: 'Compare multi-day plans to save on regular meals.', breakdown: [] };
  }

  const effectiveMealsPerWeek = Math.max(1, weeklyDays * Math.max(1, mealsPerDay) - weeklySkips);

  const scored = candidatePlans.map((p) => {
    const weeks = Math.max(0.5, Number(p.duration_days || 30) / 7);
    const totalNeededMeals = Math.max(1, Math.round(weeks * effectiveMealsPerWeek));
    const usableMeals =
      p.plan_type === 'meal_credits' && p.meal_credits && p.meal_credits > 0
        ? Math.min(p.meal_credits, totalNeededMeals)
        : totalNeededMeals;
    const rawPerMeal = p.price_inr / Math.max(1, usableMeals);
    const costPerMeal = rawPerMeal >= 1 ? Math.round(rawPerMeal) : Number(rawPerMeal.toFixed(1));
    return {
      plan_id: p.id,
      plan_name: p.name,
      plan_type: p.plan_type,
      price_inr: p.price_inr,
      expected_meals: usableMeals,
      cost_per_meal_inr: costPerMeal,
    };
  });

  const sortedByValue = [...scored].sort((a, b) => a.cost_per_meal_inr - b.cost_per_meal_inr);
  const best = sortedByValue[0];
  const worst = sortedByValue[sortedByValue.length - 1];
  const perMealDiff = Math.max(0, worst.cost_per_meal_inr - best.cost_per_meal_inr);
  const estimatedCycleSavings = Math.round(perMealDiff * best.expected_meals);

  let headline = `${best.plan_name} gives strong value at ~₹${best.cost_per_meal_inr}/meal.`;
  if (estimatedCycleSavings >= 10 && scored.length > 1) {
    headline = `${best.plan_name} (~₹${best.cost_per_meal_inr}/meal) saves ~₹${estimatedCycleSavings} vs ${worst.plan_name} for your schedule.`;
  }

  return {
    recommended_plan_id: best.plan_id,
    recommended_plan_name: best.plan_name,
    best_cost_per_meal_inr: best.cost_per_meal_inr,
    savings_inr: estimatedCycleSavings,
    headline,
    breakdown: scored,
  };
}

export const MenuParseSchema = z.object({
  included: z.array(z.string()).default([]),
  extras: z
    .array(
      z.object({
        name: z.string(),
        price: z.number().nonnegative(),
        kind: z.enum(['addon', 'special']).default('addon'),
      })
    )
    .default([]),
  dietary_guess: z.enum(['veg', 'non_veg', 'jain']).default('veg'),
  estimated_calories: z.number().int().min(100).max(2500).default(650),
});

export function heuristicParseMenu(textInput: string): z.infer<typeof MenuParseSchema> {
  const raw = (textInput || '').trim();
  const included: string[] = [];
  const extras: Array<{ name: string; price: number; kind: 'addon' | 'special' }> = [];

  if (!raw) {
    return { included: [], extras: [], dietary_guess: 'veg', estimated_calories: 650 };
  }

  const lower = raw.toLowerCase();
  const dietary_guess: 'veg' | 'non_veg' | 'jain' =
    /\b(chicken|mutton|egg|fish|keema|biryani non)\b/.test(lower)
      ? 'non_veg'
      : /\b(jain|no onion|no garlic)\b/.test(lower)
        ? 'jain'
        : 'veg';

  const parts = raw
    .split(/[\n,+&]+|\baur\b|\bwith\b/i)
    .map((p) => p.trim())
    .filter((p) => p.length >= 2);

  for (const part of parts) {
    const priceMatch = part.match(/(?:₹|rs\.?\s*)?(\d{1,4})(?:\s*(?:rs|inr|\/-))?$/i);
    if (priceMatch && (/extra|special|sweet|addon|gulab|lassi|chaas|egg|paneer|₹|rs/i.test(part))) {
      const price = Number(priceMatch[1]);
      const cleanName = part
        .replace(priceMatch[0], '')
        .replace(/^(extra|add-on|addon|special)\s*/i, '')
        .replace(/[-:]+$/, '')
        .trim();
      if (cleanName) {
        extras.push({
          name: cleanName.charAt(0).toUpperCase() + cleanName.slice(1),
          price: isFinite(price) && price > 0 ? price : 25,
          kind: /special/i.test(part) ? 'special' : 'addon',
        });
        continue;
      }
    }

    const cleaned = part.replace(/^(aaj|today|lunch|dinner|breakfast|me|hai)\s+/gi, '').trim();
    if (cleaned) {
      included.push(cleaned.charAt(0).toUpperCase() + cleaned.slice(1));
    }
  }

  return {
    included: included.slice(0, 12),
    extras: extras.slice(0, 6),
    dietary_guess,
    estimated_calories: Math.min(1400, 420 + included.length * 75),
  };
}

export const SmartSearchSchema = z.object({
  keywords: z.string().default(''),
  max_monthly_inr: z.number().nullable().default(null),
  dietary: z.enum(['all', 'veg', 'non_veg', 'jain']).default('all'),
  slot: z.enum(['', 'breakfast', 'lunch', 'snacks', 'dinner']).default(''),
  delivery_only: z.boolean().default(false),
});

export function heuristicSmartSearch(query: string): z.infer<typeof SmartSearchSchema> {
  const q = (query || '').trim();
  const lower = q.toLowerCase();

  let maxMonthlyInr: number | null = null;
  const priceMatch = lower.match(/(?:under|below|within|upto|budget|ke andar|<)\s*₹?\s*(\d{3,5})/);
  if (priceMatch) {
    maxMonthlyInr = Number(priceMatch[1]);
  } else {
    const standalonePrice = lower.match(/\b([1-9]\d{2,4})\b/);
    if (standalonePrice && /budget|rupee|rs|inr|mahina|month|price/i.test(lower)) {
      maxMonthlyInr = Number(standalonePrice[1]);
    }
  }

  let dietary: 'all' | 'veg' | 'non_veg' | 'jain' = 'all';
  if (/\bjain\b/.test(lower)) dietary = 'jain';
  else if (/\b(non[-\s]?veg|chicken|mutton|egg)\b/.test(lower)) dietary = 'non_veg';
  else if (/\b(veg|pure veg|vegetarian|shudh)\b/.test(lower)) dietary = 'veg';

  let slot: '' | 'breakfast' | 'lunch' | 'snacks' | 'dinner' = '';
  if (/\b(breakfast|nashta|morning|subah)\b/.test(lower)) slot = 'breakfast';
  else if (/\b(snacks?|chai|evening|sham)\b/.test(lower)) slot = 'snacks';
  else if (/\b(lunch|dopahar|afternoon)\b/.test(lower)) slot = 'lunch';
  else if (/\b(dinner|raat|night)\b/.test(lower)) slot = 'dinner';

  const delivery_only = /\b(delivery|home delivery|deliver|ghar)\b/.test(lower);

  const stopWords =
    /\b(under|below|within|upto|budget|ke|andar|me|mein|wala|chahiye|pure|veg|non|vegetarian|jain|breakfast|lunch|snacks?|dinner|delivery|home|mess|tiffin|rs|inr)\b/gi;
  const cleanedKeywords = q
    .replace(stopWords, ' ')
    .replace(/\d{3,5}/g, ' ')
    .replace(/\s+/g, ' ')
    .trim();

  return {
    keywords: cleanedKeywords,
    max_monthly_inr: maxMonthlyInr,
    dietary,
    slot,
    delivery_only,
  };
}

export function heuristicReviewSummary(reviews: any[]) {
  if (reviews.length < 2) {
    return {
      summary: 'Collect at least 2 verified customer reviews to unlock trend highlights.',
      strengths: [] as string[],
      focus_area: '',
    };
  }

  const avg = reviews.reduce((s, r) => s + Number(r.rating || 5), 0) / reviews.length;
  const tagCounts: Record<string, number> = {};
  for (const r of reviews) {
    if (Array.isArray(r.tags)) {
      for (const t of r.tags) {
        tagCounts[t] = (tagCounts[t] || 0) + 1;
      }
    }
  }
  const topTags = Object.entries(tagCounts)
    .sort((a, b) => b[1] - a[1])
    .slice(0, 2)
    .map(([k]) => k);

  const lowCount = reviews.filter((r) => Number(r.rating || 5) <= 3).length;
  return {
    summary: `Average ${avg.toFixed(1)} stars across ${reviews.length} verified reviews.${topTags.length ? ` Customers frequently praise ${topTags.join(' & ')}.` : ''}`,
    strengths: topTags,
    focus_area: lowCount > 0 ? `${lowCount} recent rating(s) at 3 stars or below need follow-up.` : 'Consistency looks strong across recent feedback.',
  };
}

export function heuristicReplyDraft(customerName: string, rating: number, reviewText: string) {
  const name = (customerName || 'there').split(' ')[0];
  if (rating >= 4) {
    return `Thank you ${name}! Glad you enjoyed the home-style food with us${reviewText ? ' — feedback like yours motivates our kitchen team daily' : ''}. Look forward to serving your next meal.`;
  }
  return `Thank you for honest feedback, ${name}. We are sorry the experience did not meet expectations and have shared your note with our kitchen lead to improve right away.`;
}
