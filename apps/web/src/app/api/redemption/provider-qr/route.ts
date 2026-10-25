import { NextResponse } from 'next/server';

export async function GET() { return NextResponse.json({ error: 'Provider QR issuance requires verified provider staff identity and a configured signing secret.' }, { status: 503 }); }
