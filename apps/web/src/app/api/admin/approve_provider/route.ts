import { NextRequest, NextResponse } from 'next/server';
import { getAdminClient, requireAdmin } from '@/lib/supabase/admin';
import { platformStore } from '@/lib/platform-service';

export async function POST(req: NextRequest) {
  try {
    // Enforce administrative authentication & authorization
    const auth = await requireAdmin(req);
    if (!auth.ok) {
      return NextResponse.json(
        { success: false, error: auth.error },
        { status: auth.status }
      );
    }

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

    const newStatus = decision === 'approve' ? 'active' : decision === 'reject' ? 'rejected' : 'suspended';

    // 1. Update in Supabase
    try {
      const admin = auth.admin || getAdminClient();
      if (admin) {
        await admin
          .from('providers')
          .update({
            status: newStatus,
            approved_at: decision === 'approve' ? new Date().toISOString() : null,
            resolution_note: reason,
            resolved_at: new Date().toISOString(),
          })
          .eq('id', providerId);
      }
    } catch (err) {
      console.warn('Failed to update Supabase in approve_provider:', err);
    }

    // 2. Update in platformStore
    const provider = platformStore.providers.get(providerId);
    if (provider) {
      provider.status = newStatus as any;
      return NextResponse.json({
        success: true,
        provider,
        decision,
        reason,
        message: `Provider ${provider.display_name} has been ${decision}d.`,
      });
    }

    return NextResponse.json({
      success: true,
      decision,
      message: `Provider ${providerId} status updated to ${newStatus}.`,
    });
  } catch (err: any) {
    return NextResponse.json(
      { success: false, error: err.message },
      { status: 500 }
    );
  }
}
