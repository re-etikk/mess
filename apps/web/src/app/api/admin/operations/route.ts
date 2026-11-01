import { NextRequest, NextResponse } from 'next/server';
import { requireAdmin } from '@/lib/supabase/admin';

export const dynamic = 'force-dynamic';

const sources = {
  bookings: { table: 'meal_bookings', columns: 'id,customer_id,provider_id,meal_slot_id,service_date,booking_type,status,fulfillment_mode,total_due_paise,created_at', sort: 'created_at' },
  redemptions: { table: 'meal_redemptions', columns: 'id,booking_id,customer_id,provider_id,redeemed_by,confirmation_method,fulfillment_mode,redeemed_at', sort: 'redeemed_at' },
  payments: { table: 'payment_transactions', columns: 'id,customer_id,subscription_id,booking_id,purpose,gateway_name,amount_paise,currency,status,verified_at,created_at', sort: 'created_at' },
  refunds: { table: 'refunds', columns: 'id,payment_transaction_id,amount_paise,reason_code,status,requested_by,processed_by,requested_at,completed_at', sort: 'requested_at' },
  settlements: { table: 'provider_settlements', columns: 'id,provider_id,period_start,period_end,gross_food_paise,commission_paise,refund_paise,adjustment_paise,net_payable_paise,status,settled_at,created_at', sort: 'created_at' },
  support: { table: 'support_tickets', columns: 'id,created_by,about_user_id,provider_id,booking_id,payment_transaction_id,category,subject,status,priority,assigned_to,resolved_at,created_at,updated_at', sort: 'created_at' },
  audit: { table: 'audit_logs', columns: 'id,actor_user_id,action,subject_type,subject_id,reason,request_id,created_at', sort: 'created_at' },
} as const;
type SourceKey = keyof typeof sources;

export async function GET(req: NextRequest) {
  const access = await requireAdmin(req);
  if (!access.ok) return NextResponse.json({ success: false, error: access.error }, { status: access.status });
  const params = new URL(req.url).searchParams;
  const source = params.get('source') as SourceKey | null;
  if (!source || !Object.prototype.hasOwnProperty.call(sources, source)) return NextResponse.json({ success: false, error: 'Choose a supported operations record type.' }, { status: 400 });
  const page = Math.min(100000, Math.max(1, Number(params.get('page')) || 1));
  const pageSize = Math.min(50, Math.max(1, Number(params.get('page_size')) || 20));
  const status = params.get('status')?.trim().slice(0, 40) ?? '';
  const { table, columns, sort } = sources[source];
  const db: any = access.admin;
  let query: any = db.from(table).select(columns, { count: 'exact' }).order(sort, { ascending: false });
  if (status && source !== 'redemptions' && source !== 'audit') query = query.eq('status', status);
  const { data, error, count } = await query.range((page - 1) * pageSize, page * pageSize - 1);
  if (error) {
    console.error(`Admin ${source} query failed:`, error.message);
    return NextResponse.json({ success: false, error: 'Operations records could not be loaded.' }, { status: 503 });
  }
  return NextResponse.json({ success: true, source, total: count ?? 0, page, page_size: pageSize, records: data ?? [] }, { headers: { 'Cache-Control': 'private, no-store' } });
}
