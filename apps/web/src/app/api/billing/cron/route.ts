import { NextRequest, NextResponse } from 'next/server';
import { executeProviderBillingJob } from '@/lib/platform-service';
import { timingSafeStringEqual } from '@/lib/auth-session';

export const dynamic = 'force-dynamic';

export async function POST(req: NextRequest) {
  try {
    const cronSecret = process.env.CRON_SECRET?.trim();
    if (!cronSecret) {
      return NextResponse.json(
        { success: false, error: 'CRON_SECRET is not configured on the server.' },
        { status: 503 }
      );
    }

    const authHeader = req.headers.get('authorization')?.trim() || '';
    if (!timingSafeStringEqual(authHeader, `Bearer ${cronSecret}`)) {
      return NextResponse.json({ success: false, error: 'Unauthorized cron trigger' }, { status: 401 });
    }

    const result = executeProviderBillingJob();

    return NextResponse.json({
      success: true,
      timestamp: new Date().toISOString(),
      rule: '₹25 per 90 successful scans (AutoPay / recurring mandate)',
      ...result,
    });
  } catch (err: any) {
    return NextResponse.json(
      { success: false, error: err?.message || 'Billing job failed' },
      { status: 500 }
    );
  }
}
