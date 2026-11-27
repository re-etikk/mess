import { NextRequest, NextResponse } from 'next/server';
import { z } from 'zod';
import { requireAdmin } from '@/lib/supabase/admin';
import { logAdminAudit } from '@/lib/admin-rbac';
import { addPartnerNotification } from '@/lib/partner-notifications';
import { getPlatformAppConfig } from '@/lib/app-config';

export const dynamic = 'force-dynamic';

const RefundDecisionSchema = z.object({
  action: z.literal('process_refund'),
  refund_id: z.string().uuid(),
  decision: z.enum(['approve', 'reject']),
  gateway_refund_id: z.string().trim().max(120).optional(),
  reason: z.string().trim().min(3).max(500),
});

const CreateSettlementSchema = z.object({
  action: z.literal('create_settlement'),
  provider_id: z.string().uuid(),
  period_start: z.string().regex(/^\d{4}-\d{2}-\d{2}$/),
  period_end: z.string().regex(/^\d{4}-\d{2}-\d{2}$/),
  gross_food_paise: z.number().int().min(0),
  commission_paise: z.number().int().min(0).default(0),
  refund_paise: z.number().int().min(0).default(0),
  adjustment_paise: z.number().int().default(0),
});

const MarkSettlementSchema = z.object({
  action: z.literal('mark_settlement_paid'),
  settlement_id: z.string().uuid(),
  status: z.enum(['processing', 'paid', 'failed', 'cancelled']),
  gateway_payout_reference: z.string().trim().max(120).optional(),
  reason: z.string().trim().max(500).optional(),
});

export async function GET(req: NextRequest) {
  const access = await requireAdmin(req, 'finance.read');
  if (!access.ok) return NextResponse.json({ success: false, error: access.error }, { status: access.status });

  const [txRes, refundsRes, settRes, provRes, appCfg] = await Promise.all([
    access.admin
      .from('payment_transactions')
      .select('id,customer_id,subscription_id,amount_paise,status,gateway_name,verified_at,created_at')
      .eq('status', 'succeeded')
      .order('created_at', { ascending: false })
      .limit(500),
    access.admin.from('refunds').select('*').order('requested_at', { ascending: false }).limit(50),
    access.admin
      .from('provider_settlements')
      .select('*,providers(display_name)')
      .order('created_at', { ascending: false })
      .limit(50),
    access.admin
      .from('providers')
      .select('id,display_name,commission_bps_override,status')
      .eq('status', 'active')
      .limit(200)
      .then((r) => r, () => access.admin.from('providers').select('id,display_name,status').eq('status', 'active').limit(200)),
    getPlatformAppConfig(access.admin),
  ]);

  const txRows = txRes.data ?? [];
  const totalGmvPaise = txRows.reduce((s: number, t: any) => s + Number(t.amount_paise || 0), 0);
  const refundRows = refundsRes.data ?? [];
  const totalRefundedPaise = refundRows
    .filter((r: any) => r.status === 'succeeded')
    .reduce((s: number, r: any) => s + Number(r.amount_paise || 0), 0);
  const settRows = settRes.data ?? [];
  const totalSettledPaise = settRows
    .filter((st: any) => st.status === 'paid')
    .reduce((s: number, st: any) => s + Number(st.net_payable_paise || 0), 0);

  return NextResponse.json(
    {
      success: true,
      summary: {
        verified_gmv_paise: totalGmvPaise,
        total_refunded_paise: totalRefundedPaise,
        total_settled_paise: totalSettledPaise,
        default_commission_bps: appCfg.default_commission_bps,
        succeeded_tx_count: txRows.length,
      },
      refunds: refundRows,
      settlements: settRows.map((row: any) => ({
        ...row,
        provider_name: row.providers?.display_name || 'Kitchen',
      })),
      providers: provRes.data ?? [],
    },
    { headers: { 'Cache-Control': 'private, no-store' } }
  );
}

export async function PATCH(req: NextRequest) {
  const access = await requireAdmin(req, 'finance.manage');
  if (!access.ok) return NextResponse.json({ success: false, error: access.error }, { status: access.status });
  if (process.env.VERCEL_ENV === 'preview') {
    return NextResponse.json({ success: false, error: 'Financial payouts/refunds are disabled in preview mode.' }, { status: 403 });
  }

  const body = await req.json().catch(() => ({}));

  const refParsed = RefundDecisionSchema.safeParse(body);
  if (refParsed.success) {
    const { refund_id, decision, gateway_refund_id, reason } = refParsed.data;
    const status = decision === 'approve' ? 'succeeded' : 'rejected';
    const { data, error } = await access.admin
      .from('refunds')
      .update({
        status,
        gateway_refund_id: gateway_refund_id || null,
        processed_by: access.userId,
        reason_note: reason,
        completed_at: new Date().toISOString(),
      })
      .eq('id', refund_id)
      .select('*')
      .maybeSingle();

    if (error || !data) {
      return NextResponse.json({ success: false, error: 'Refund record could not be updated.' }, { status: 503 });
    }

    await logAdminAudit(access.admin, {
      actorUserId: access.userId,
      action: `finance.refund_${decision}`,
      subjectType: 'refund',
      subjectId: refund_id,
      reason,
      details: { gateway_refund_id },
    });

    return NextResponse.json({ success: true, refund: data, message: `Refund marked ${status}.` });
  }

  const settCreate = CreateSettlementSchema.safeParse(body);
  if (settCreate.success) {
    const s = settCreate.data;
    const net = Math.max(0, s.gross_food_paise - s.commission_paise - s.refund_paise + s.adjustment_paise);
    const { data, error } = await access.admin
      .from('provider_settlements')
      .insert({
        provider_id: s.provider_id,
        period_start: s.period_start,
        period_end: s.period_end,
        gross_food_paise: s.gross_food_paise,
        commission_paise: s.commission_paise,
        refund_paise: s.refund_paise,
        adjustment_paise: s.adjustment_paise,
        net_payable_paise: net,
        status: 'pending',
      })
      .select('*')
      .single();

    if (error) {
      return NextResponse.json({ success: false, error: error.message || 'Settlement batch creation failed.' }, { status: 400 });
    }

    await logAdminAudit(access.admin, {
      actorUserId: access.userId,
      action: 'finance.settlement_created',
      subjectType: 'provider_settlement',
      subjectId: data.id,
      details: { provider_id: s.provider_id, net_payable_paise: net },
    });

    return NextResponse.json({ success: true, settlement: data, message: 'Settlement batch created.' });
  }

  const settMark = MarkSettlementSchema.safeParse(body);
  if (settMark.success) {
    const { settlement_id, status, gateway_payout_reference, reason } = settMark.data;
    const { data, error } = await access.admin
      .from('provider_settlements')
      .update({
        status,
        gateway_payout_reference: gateway_payout_reference || null,
        settled_at: status === 'paid' ? new Date().toISOString() : null,
      })
      .eq('id', settlement_id)
      .select('*')
      .maybeSingle();

    if (error || !data) {
      return NextResponse.json({ success: false, error: 'Settlement status update failed.' }, { status: 503 });
    }

    await logAdminAudit(access.admin, {
      actorUserId: access.userId,
      action: `finance.settlement_${status}`,
      subjectType: 'provider_settlement',
      subjectId: settlement_id,
      reason: reason || null,
      details: { gateway_payout_reference },
    });

    if (status === 'paid' && data.provider_id) {
      addPartnerNotification({
        provider_id: String(data.provider_id),
        type: 'settlement',
        title: 'Settlement Payout Completed',
        message: `₹${Math.round(Number(data.net_payable_paise || 0) / 100)} payout marked paid${gateway_payout_reference ? ` (Ref: ${gateway_payout_reference})` : ''}.`,
        action_tab: 'settlements',
      });
    }

    return NextResponse.json({ success: true, settlement: data, message: `Settlement marked ${status}.` });
  }

  return NextResponse.json({ success: false, error: 'Invalid finance operation payload.' }, { status: 400 });
}
