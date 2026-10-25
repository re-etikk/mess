import { NextRequest, NextResponse } from 'next/server';

export async function POST(req: NextRequest) {
  try {
    const body = await req.json().catch(() => ({}));
    const email = body.email?.trim().toLowerCase();
    const password = body.password;

    if (!email || !password) {
      return NextResponse.json(
        { success: false, error: 'Email and password are required.' },
        { status: 400 }
      );
    }

    let role = 'customer';
    if (email.includes('admin') || email === 'ritik45chaurasia@gmail.com') {
      role = 'admin';
    } else if (email.includes('owner') || email.includes('provider')) {
      role = 'provider';
    }

    const userId = `usr-${role}-${Buffer.from(email).toString('hex').slice(0, 8)}`;
    const token = `jwt_mock_${Buffer.from(JSON.stringify({ userId, email, role })).toString('base64url')}`;

    return NextResponse.json({
      success: true,
      user: {
        id: userId,
        email,
        name: email.split('@')[0],
        role,
      },
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
