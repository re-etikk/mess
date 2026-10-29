import { NextRequest, NextResponse } from 'next/server';
import crypto from 'crypto';
import { platformStore } from '@/lib/platform-service';
import { getAdminClient } from '@/lib/supabase/admin';

export async function POST(req: NextRequest) {
  try {
    const body = await req.json().catch(() => ({}));
    const email = body.email?.trim().toLowerCase();
    const password = body.password;
    const requestedRole = (body.role || 'customer').toLowerCase();
    const name = body.name || body.display_name || body.business_name || email?.split('@')[0] || 'User';
    const phone = body.phone || '';

    if (!email || !password) {
      return NextResponse.json(
        { success: false, error: 'Email and password are required.' },
        { status: 400 }
      );
    }

    if (password.length < 6) {
      return NextResponse.json(
        { success: false, error: 'Password must be at least 6 characters long.' },
        { status: 400 }
      );
    }

    // Security check: Prevent public self-registration of administrative privileges
    if (requestedRole === 'admin') {
      return NextResponse.json(
        { success: false, error: 'Forbidden: Administrator accounts cannot be self-registered.' },
        { status: 403 }
      );
    }

    const role = requestedRole === 'provider' ? 'provider' : 'customer';
    const userId = `usr-${Date.now()}-${crypto.randomBytes(3).toString('hex')}`;
    let providerData = null;
    let providerIdVal: string | undefined = undefined;

    if (role === 'provider') {
      const providerId = `prov-${Date.now()}-${crypto.randomBytes(2).toString('hex')}`;
      providerIdVal = providerId;
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
        status: 'pending_review' as const,
        created_at: new Date().toISOString(),
      };
      platformStore.providers.set(providerId, providerData);

      // Persist to Supabase GoTrue Auth and Providers table if admin client available
      try {
        const admin = getAdminClient();
        if (admin) {
          await admin.auth.admin.createUser({
            email,
            password,
            email_confirm: true,
            user_metadata: {
              role: 'provider',
              display_name: businessName,
              phone,
              application: {
                id: providerId,
                display_name: businessName,
                public_phone: phone,
                email,
                status: 'pending_review',
                created_at: new Date().toISOString(),
              },
            },
          });
        }
      } catch (err) {
        console.warn('Supabase provider registration note:', err);
      }
    } else {
      // Customer registration in Supabase
      try {
        const admin = getAdminClient();
        if (admin) {
          await admin.auth.admin.createUser({
            email,
            password,
            email_confirm: true,
            user_metadata: {
              role: 'customer',
              display_name: name,
              phone,
            },
          });
        }
      } catch (err) {
        console.warn('Supabase customer registration note:', err);
      }
    }

    const token = `jwt_session_${Buffer.from(
      JSON.stringify({
        userId,
        email,
        role,
        providerId: providerIdVal,
        provider_id: providerIdVal,
      })
    ).toString('base64url')}`;

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
