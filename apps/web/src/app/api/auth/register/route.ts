import { NextRequest, NextResponse } from 'next/server';
import crypto from 'crypto';

export async function POST(req: NextRequest) {
  try {
    const body = await req.json().catch(() => ({}));
    const email = body.email?.trim().toLowerCase();
    const password = body.password;
    const role = body.role || 'customer'; // 'customer' | 'provider' | 'admin'
    const name = body.name || body.display_name || email?.split('@')[0] || 'User';
    const phone = body.phone || '';

    if (!email || !password) {
      return NextResponse.json(
        { success: false, error: 'Email and password are required.' },
        { status: 400 }
      );
    }

    const userId = `usr-${Date.now()}-${crypto.randomBytes(3).toString('hex')}`;
    const token = `jwt_mock_${Buffer.from(JSON.stringify({ userId, email, role })).toString('base64url')}`;

    return NextResponse.json({
      success: true,
      user: {
        id: userId,
        email,
        name,
        role,
        phone,
      },
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
