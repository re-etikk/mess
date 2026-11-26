import { NextRequest, NextResponse } from 'next/server';
import { requireProviderOwnership } from '@/lib/provider-auth';
import { callGeminiJson, heuristicParseMenu, MenuParseSchema } from '@/lib/ai-service';

export const dynamic = 'force-dynamic';

export async function POST(req: NextRequest) {
  const body = await req.json().catch(() => ({}));
  const providerId = String(body.provider_id || '').trim();
  const slot = String(body.slot || 'LUNCH').toUpperCase().trim();
  const textInput = String(body.text_input || '').trim();
  const imageBase64 = typeof body.image_base64 === 'string' ? body.image_base64 : null;

  if (!providerId) {
    return NextResponse.json({ success: false, error: 'provider_id is required.' }, { status: 400 });
  }
  if (!textInput && !imageBase64) {
    return NextResponse.json({ success: false, error: 'Please type a menu line or choose a menu photo.' }, { status: 400 });
  }

  const access = await requireProviderOwnership(req, providerId);
  if (!access.ok && access.status !== 401) {
    return NextResponse.json({ success: false, error: access.error }, { status: access.status });
  }

  const prompt = `You are a menu digitizer for an Indian tiffin & mess kitchen (${slot} meal).
Extract clean English/Hinglish food item names from the user's input or menu board image into JSON.
Rules:
- Put regular thali/meal items in "included" (e.g. "Rajma", "4 Roti", "Jeera Rice", "Boondi Raita").
- Put paid extras/add-ons/sweets with explicit prices in "extras" with { "name": string, "price": number, "kind": "addon" | "special" }.
- Set "dietary_guess" as "veg", "non_veg", or "jain".
- Estimate realistic total thali calories in "estimated_calories" (integer between 250 and 1800).
Input text: ${textInput || '(Read directly from attached menu photo)'}`;

  const result = await callGeminiJson({
    prompt,
    imageBase64,
    schema: MenuParseSchema,
    fallback: () => heuristicParseMenu(textInput),
  });

  return NextResponse.json({
    success: true,
    source: result.source,
    ...result.data,
  });
}
