import { NextRequest, NextResponse } from 'next/server';
import { platformStore } from '@/lib/platform-service';

export async function POST(req: NextRequest) {
  try {
    const body = await req.json().catch(() => ({}));
    const providerId = body.provider_id || body.providerId;
    const decision = body.decision; // 'approve' | 'reject' | 'suspend'
    const reason = body.reason || 'Admin review completed';

    if (!providerId || !decision) {
      return NextResponse.json(
        { success: false, error: 'provider_id and decision are required.' },
        { status: 400 }
      );
    }

    const provider = platformStore.providers.get(providerId);
    if (!provider) {
      return NextResponse.json(
        { success: false, error: 'Provider not found.' },
        { status: 404 }
      );
    }

    if (decision === 'approve') {
      provider.status = 'active';
    } else if (decision === 'reject') {
      provider.status = 'rejected';
    } else if (decision === 'suspend') {
      provider.status = 'suspended';
    }

    return NextResponse.json({
      success: true,
      provider,
      decision,
      reason,
      message: `Provider ${provider.display_name} has been ${decision}d.`,
    });
  } catch (err: any) {
    return NextResponse.json(
      { success: false, error: err.message },
      { status: 500 }
    );
  }
}
