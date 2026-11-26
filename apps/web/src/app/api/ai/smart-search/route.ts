import { NextRequest, NextResponse } from 'next/server';
import { callGeminiJson, heuristicSmartSearch, SmartSearchSchema } from '@/lib/ai-service';
import { getClientIp } from '@/lib/auth-session';
import { checkRateLimit } from '@/lib/rate-limiter';

export const dynamic = 'force-dynamic';

export async function POST(req: NextRequest) {
  const rl = checkRateLimit(`smart_search:${getClientIp(req)}`, 40, 60 * 1000);
  if (!rl.isAllowed) {
    return NextResponse.json({ success: false, error: 'Too many search requests. Slow down briefly.' }, { status: 429 });
  }

  const body = await req.json().catch(() => ({}));
  const query = String(body.query || '').trim().slice(0, 240);

  if (!query) {
    return NextResponse.json({ success: false, error: 'Search query is required.' }, { status: 400 });
  }

  const prompt = `Parse a user's Hindi/Hinglish/English tiffin kitchen search query into structured filters JSON.
Query: "${query}"
Fields:
- "keywords": locality, area, or dish words left after extracting filters (empty string if none).
- "max_monthly_inr": integer budget cap if mentioned (e.g. 3500) else null.
- "dietary": "veg" | "non_veg" | "jain" | "all"
- "slot": "breakfast" | "lunch" | "dinner" | ""
- "delivery_only": boolean (true if user mentions home delivery / tiffin delivery)`;

  const res = await callGeminiJson({
    prompt,
    schema: SmartSearchSchema,
    fallback: () => heuristicSmartSearch(query),
  });

  return NextResponse.json({
    success: true,
    source: res.source,
    filters: res.data,
  });
}
