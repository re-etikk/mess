import { NextRequest, NextResponse } from 'next/server';
import crypto from 'crypto';
import { platformStore } from '@/lib/platform-service';

export async function POST(req: NextRequest) {
  try {
    const body = await req.json().catch(() => ({}));
    const email = body.email?.trim().toLowerCase();
    const password = body.password;
    const role = body.role || 'customer'; // 'customer' | 'provider' | 'admin'
    const name = body.name || body.display_name || body.business_name || email?.split('@')[0] || 'User';
    const phone = body.phone || '';

    if (!email || !password) {
      return NextResponse.json(
        { success: false, error: 'Email and password are required.' },
        { status: 400 }
      );
    }

    const userId = `usr-${Date.now()}-${crypto.randomBytes(3).toString('hex')}`;
    const token = `jwt_mock_${Buffer.from(JSON.stringify({ userId, email, role })).toString('base64url')}`;

    let providerData = null;
    if (role === 'provider') {
      const providerId = `prov-${Date.now()}-${crypto.randomBytes(2).toString('hex')}`;
      const businessName = body.business_name || body.display_name || `${name} Mess`;
      const slug = businessName.toLowerCase().replace(/[^a-z0-9]+/g, '-').replace(/(^-|-$)/g, '');
      providerData = {
        id: providerId,
        owner_user_id: userId,
        display_name: businessName,
        slug,
        description: body.description || 'Authentic daily meals and tiffin service.',
        phone: phone || '+91 98765 43210',
        email,
        address: body.address || 'Main Campus Road',
        locality: body.locality || 'Campus Area',
        city: body.city || 'Noida',
        rating: 5.0,
        total_reviews: 0,
        cuisines: body.cuisines || ['North Indian', 'Homestyle'],
        dietary_types: body.dietary_types || ['veg'],
        status: 'active' as const,
        created_at: new Date().toISOString(),
      };
      platformStore.providers.set(providerId, providerData);
    }

    return NextResponse.json({
      success: true,
      user: {
        id: userId,
        email,
        name,
        role,
        phone,
        provider_id: providerData?.id,
        provider_name: providerData?.display_name,
      },
      provider: providerData,
      token,
      message: `Registration successful as ${role}.`,
    });
  } catch (err: any) {
    return NextResponse.json(
      { success: false, error: err.message || 'Registration failed' },
      { status: 500 }
    );
  }
}
