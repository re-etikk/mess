import { NextRequest, NextResponse } from 'next/server';
import { executeProviderBillingJob } from '@/lib/platform-service';

export async function POST(req: NextRequest) {
  try {
    const authHeader = req.headers.get('authorization');
    const cronSecret = process.env.CRON_SECRET || 'thali-cron-secret-2026';

    // Verify cron secret if configured
    if (process.env.CRON_SECRET && authHeader !== `Bearer ${cronSecret}`) {
      return NextResponse.json({ error: 'Unauthorized cron trigger' }, { status: 401 });
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
      { success: false, error: err.message || 'Billing job failed' },
      { status: 500 }
    );
  }
}

export async function GET(req: NextRequest) {
  return POST(req);
}
