import { NextRequest, NextResponse } from 'next/server';

export const dynamic = 'force-dynamic';

const POPULAR_CAMPUS_HUBS = [
  { description: 'Sector 62, Noida, Uttar Pradesh (Near JSS & JIIT)', place_id: 'hub-noida-62' },
  { description: 'BTM Layout 2nd Stage, Bengaluru, Karnataka', place_id: 'hub-blr-btm' },
  { description: 'Marathahalli, Bengaluru, Karnataka (Near ITPL)', place_id: 'hub-blr-marathahalli' },
  { description: 'Kothrud, Pune, Maharashtra (Near MIT)', place_id: 'hub-pune-kothrud' },
  { description: 'Mukherjee Nagar, New Delhi (Student Hub)', place_id: 'hub-delhi-mukherjee' },
  { description: 'Powai, Mumbai, Maharashtra (Near IIT Bombay)', place_id: 'hub-mumbai-powai' },
  { description: 'Koramangala, Bengaluru, Karnataka', place_id: 'hub-blr-koramangala' },
  { description: 'Viman Nagar, Pune, Maharashtra (Near Symbiosis)', place_id: 'hub-pune-viman' },
  { description: 'Sector 15, Chandigarh (Near Panjab University)', place_id: 'hub-chd-15' },
];

export async function GET(req: NextRequest) {
  const { searchParams } = new URL(req.url);
  const input = searchParams.get('input')?.trim() || '';

  const apiKey = process.env.GOOGLE_MAPS_API_KEY || process.env.NEXT_PUBLIC_GOOGLE_MAPS_API_KEY;

  if (apiKey && input.length >= 2) {
    try {
      const gUrl = `https://maps.googleapis.com/maps/api/place/autocomplete/json?input=${encodeURIComponent(
        input
      )}&components=country:in&key=${apiKey}`;

      const res = await fetch(gUrl, { next: { revalidate: 3600 } });
      const data = await res.json();

      if (data?.status === 'OK' && Array.isArray(data.predictions) && data.predictions.length > 0) {
        return NextResponse.json({
          success: true,
          predictions: data.predictions.map((p: any) => ({
            description: p.description,
            place_id: p.place_id,
            main_text: p.structured_formatting?.main_text || p.description,
            secondary_text: p.structured_formatting?.secondary_text || '',
          })),
        });
      }
    } catch {}
  }

  // Graceful fallback filtering
  const filtered = input
    ? POPULAR_CAMPUS_HUBS.filter((h) => h.description.toLowerCase().includes(input.toLowerCase()))
    : POPULAR_CAMPUS_HUBS;

  return NextResponse.json({
    success: true,
    predictions: filtered.map((h) => ({
      description: h.description,
      place_id: h.place_id,
      main_text: h.description.split(',')[0],
      secondary_text: h.description.split(',').slice(1).join(',').trim(),
    })),
  });
}
