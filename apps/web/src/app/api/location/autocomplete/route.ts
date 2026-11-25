import { NextRequest, NextResponse } from 'next/server';
import { getAdminClient } from '@/lib/supabase/admin';

export const dynamic = 'force-dynamic';

export async function GET(req: NextRequest) {
  const { searchParams } = new URL(req.url);
  const input = searchParams.get('input')?.trim() || '';
  const lat = searchParams.get('lat')?.trim();
  const lng = searchParams.get('lng')?.trim();

  const apiKey = process.env.GOOGLE_MAPS_API_KEY || process.env.NEXT_PUBLIC_GOOGLE_MAPS_API_KEY;

  // 1. Reverse geocoding when lat/lng coordinates are passed
  if (lat && lng) {
    if (apiKey) {
      try {
        const gRes = await fetch(
          `https://maps.googleapis.com/maps/api/geocode/json?latlng=${encodeURIComponent(lat)},${encodeURIComponent(lng)}&key=${apiKey}`,
          { next: { revalidate: 3600 } }
        );
        const gData = await gRes.json();
        const first = gData?.results?.[0];
        if (first) {
          const comp = (t: string) =>
            first.address_components?.find((c: any) => Array.isArray(c.types) && c.types.includes(t))?.long_name || '';
          const locality = comp('sublocality_level_1') || comp('sublocality') || comp('neighborhood') || comp('locality');
          const city = comp('locality') || comp('administrative_area_level_2');
          return NextResponse.json({
            success: true,
            address: {
              formatted: first.formatted_address,
              locality: locality || city || 'Current Location',
              city: city || '',
              state: comp('administrative_area_level_1'),
              pincode: comp('postal_code'),
              latitude: Number(lat),
              longitude: Number(lng),
            },
          });
        }
      } catch {}
    }

    try {
      const osmRes = await fetch(
        `https://nominatim.openstreetmap.org/reverse?format=jsonv2&lat=${encodeURIComponent(lat)}&lon=${encodeURIComponent(lng)}`,
        { headers: { 'User-Agent': 'ThaliApp/1.0 (https://www.thali.store)' } }
      );
      const osm = await osmRes.json();
      if (osm?.address) {
        const a = osm.address;
        const locality = a.suburb || a.neighbourhood || a.road || a.town || a.city_district || '';
        const city = a.city || a.town || a.state_district || '';
        return NextResponse.json({
          success: true,
          address: {
            formatted: osm.display_name || `${locality}, ${city}`,
            locality: locality || city,
            city,
            state: a.state || '',
            pincode: a.postcode || '',
            latitude: Number(lat),
            longitude: Number(lng),
          },
        });
      }
    } catch {}

    return NextResponse.json({ success: false, error: 'Unable to resolve address for coordinates.' }, { status: 503 });
  }

  // 2. Google Places Autocomplete
  if (apiKey && input.length >= 2) {
    try {
      const gUrl = `https://maps.googleapis.com/maps/api/place/autocomplete/json?input=${encodeURIComponent(input)}&components=country:in&key=${apiKey}`;
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

  // 3. OpenStreetMap Nominatim live India search when query provided
  if (input.length >= 2) {
    try {
      const osmRes = await fetch(
        `https://nominatim.openstreetmap.org/search?format=json&addressdetails=1&countrycodes=in&limit=8&q=${encodeURIComponent(input)}`,
        { headers: { 'User-Agent': 'ThaliApp/1.0 (https://www.thali.store)' } }
      );
      const rows = await osmRes.json();
      if (Array.isArray(rows) && rows.length > 0) {
        return NextResponse.json({
          success: true,
          predictions: rows.map((r: any) => ({
            description: r.display_name,
            place_id: `osm-${r.place_id}`,
            main_text: r.name || String(r.display_name).split(',')[0],
            secondary_text: String(r.display_name).split(',').slice(1, 4).join(',').trim(),
            latitude: r.lat ? Number(r.lat) : null,
            longitude: r.lon ? Number(r.lon) : null,
          })),
        });
      }
    } catch {}
  }

  // 4. Real active service localities derived from persisted providers in Supabase
  const admin = getAdminClient();
  if (admin) {
    try {
      let provQ = admin.from('providers').select('locality,city,state,latitude,longitude').eq('status', 'active').limit(50);
      if (input) {
        const esc = input.replace(/[\\%_]/g, '\\$&');
        provQ = provQ.or(`locality.ilike.%${esc}%,city.ilike.%${esc}%`);
      }
      const { data: provLocs } = await provQ;
      const seen = new Set<string>();
      const predictions: any[] = [];
      for (const p of provLocs ?? []) {
        const desc = [p.locality, p.city, p.state].filter(Boolean).join(', ');
        if (desc && !seen.has(desc.toLowerCase())) {
          seen.add(desc.toLowerCase());
          predictions.push({
            description: desc,
            place_id: `prov-area-${predictions.length + 1}`,
            main_text: p.locality || p.city || desc,
            secondary_text: [p.city, p.state, 'India'].filter(Boolean).join(', '),
            latitude: p.latitude ? Number(p.latitude) : null,
            longitude: p.longitude ? Number(p.longitude) : null,
          });
        }
      }
      return NextResponse.json({ success: true, predictions });
    } catch {}
  }

  return NextResponse.json({ success: true, predictions: [] });
}
