import { NextRequest, NextResponse } from 'next/server';
import { platformStore } from '@/lib/platform-service';

export async function POST(req: NextRequest) {
  try {
    const body = await req.json().catch(() => ({}));
    const email = body.email?.trim().toLowerCase();
    const password = body.password;
    const requestedRole = body.role?.trim().toLowerCase();

    if (!email || !password) {
      return NextResponse.json(
        { success: false, error: 'Email and password are required.' },
        { status: 400 }
      );
    }

    let role = requestedRole || 'customer';
    if (email.includes('admin') || email === 'ritik45chaurasia@gmail.com') {
      role = 'admin';
    } else if (email.includes('owner') || email.includes('provider')) {
      role = 'provider';
    }

    const userId = `usr-${role}-${Buffer.from(email).toString('hex').slice(0, 8)}`;
    const token = `jwt_mock_${Buffer.from(JSON.stringify({ userId, email, role })).toString('base64url')}`;

    let providerData = null;
    if (role === 'provider') {
      // Find matching provider in platform store or pick the first active provider
      const found = Array.from(platformStore.providers.values()).find(
        (p) => p.email.toLowerCase() === email || p.owner_user_id === userId
      );
      if (found) {
        providerData = found;
      } else {
        // Fallback to first existing provider or initialize one for this user
        const existing = Array.from(platformStore.providers.values())[0];
        if (existing) {
          providerData = existing;
        } else {
          const newId = `prov-${Buffer.from(email).toString('hex').slice(0, 6)}`;
          providerData = {
            id: newId,
            owner_user_id: userId,
            display_name: `${email.split('@')[0]} Mess`,
            slug: email.split('@')[0].toLowerCase().replace(/[^a-z0-9]+/g, '-'),
            description: 'Homely nutritious daily meals for students.',
            phone: '+91 98765 43210',
            email,
            address: 'Main Market, Student Campus Area',
            locality: 'Campus Area',
            city: 'Noida',
            rating: 4.8,
            total_reviews: 0,
            cuisines: ['North Indian', 'Homestyle'],
            dietary_types: ['veg'] as ('veg' | 'non_veg' | 'jain')[],
            status: 'active' as const,
            created_at: new Date().toISOString(),
          };
          platformStore.providers.set(newId, providerData);
        }
      }
    }

    return NextResponse.json({
      success: true,
      user: {
        id: userId,
        email,
        name: email.split('@')[0],
        role,
        provider_id: providerData?.id,
        provider_name: providerData?.display_name,
      },
      provider: providerData,
      token,
      message: 'Login successful.',
    });
  } catch (err: any) {
    return NextResponse.json(
      { success: false, error: err.message || 'Login failed' },
      { status: 500 }
    );
  }
}
