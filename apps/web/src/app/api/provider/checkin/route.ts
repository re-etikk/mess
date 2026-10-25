import { NextRequest, NextResponse } from 'next/server';
import { processStudentCheckin } from '@/lib/platform-service';

export async function POST(req: NextRequest) {
  try {
    const body = await req.json().catch(() => ({}));
    const providerId = body.provider_id || 'prov-radhe-001';
    const studentIdOrQr = body.student_id || body.qr_code || body.token || '';
    const slot = body.slot;

    if (!studentIdOrQr) {
      return NextResponse.json(
        { success: false, error: 'Student ID or QR code is required for check-in.' },
        { status: 400 }
      );
    }

    const result = processStudentCheckin({
      providerId,
      studentIdOrQr,
      slot,
    });

    if (!result.success) {
      return NextResponse.json(result, { status: result.message.includes('already checked in') ? 409 : 400 });
    }

    return NextResponse.json(result, { status: 200 });
  } catch (err: any) {
    return NextResponse.json(
      { success: false, error: err.message || 'Check-in failed' },
      { status: 500 }
    );
  }
}
