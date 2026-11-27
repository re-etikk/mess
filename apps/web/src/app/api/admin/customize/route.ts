import { NextRequest, NextResponse } from 'next/server';
import { z } from 'zod';
import { requireAdmin } from '@/lib/supabase/admin';
import { getPlatformAppConfig, setInMemoryConfigOverride } from '@/lib/app-config';
import { hasAdminCapability, logAdminAudit } from '@/lib/admin-rbac';

export const dynamic = 'force-dynamic';

const ConfigUpdateSchema = z.object({
  hero_title: z.string().trim().min(3).max(120).optional(),
  hero_subtitle: z.string().trim().min(3).max(240).optional(),
  hero_badge: z.string().trim().min(2).max(40).optional(),
  active_cities: z.array(z.string().trim().min(2).max(40)).max(50).optional(),
  default_commission_bps: z.number().int().min(0).max(5000).optional(),
  platform_fee_paise: z.number().int().min(0).max(50000).optional(),
  default_delivery_fee_paise: z.number().int().min(0).max(50000).optional(),
  free_delivery_above_paise: z.number().int().min(0).max(500000).optional(),
  require_provider_approval: z.boolean().optional(),
  customer_maintenance: z.boolean().optional(),
  partner_maintenance: z.boolean().optional(),
  maintenance_message: z.string().trim().min(5).max(300).optional(),
  min_customer_version: z.string().trim().min(1).max(20).optional(),
  min_partner_version: z.string().trim().min(1).max(20).optional(),
  feature_flags: z
    .object({
      single_meal_orders: z.boolean().optional(),
      cash_at_counter: z.boolean().optional(),
      cashfree_online: z.boolean().optional(),
      ai_features: z.boolean().optional(),
      self_delivery: z.boolean().optional(),
      snacks_slot: z.boolean().optional(),
      banners_enabled: z.boolean().optional(),
    })
    .optional(),
});

export async function GET(req: NextRequest) {
  const access = await requireAdmin(req, 'overview.read');
  if (!access.ok) return NextResponse.json({ success: false, error: access.error }, { status: access.status });

  const config = await getPlatformAppConfig(access.admin);
  return NextResponse.json({ success: true, config }, { headers: { 'Cache-Control': 'private, no-store' } });
}

export async function PATCH(req: NextRequest) {
  const access = await requireAdmin(req, 'customize.manage');
  if (!access.ok) return NextResponse.json({ success: false, error: access.error }, { status: access.status });

  const body = await req.json().catch(() => ({}));
  const parsed = ConfigUpdateSchema.safeParse(body);
  if (!parsed.success) {
    return NextResponse.json(
      { success: false, error: 'Invalid customization payload.', details: parsed.error.flatten() },
      { status: 400 }
    );
  }

  const d = parsed.data;
  const touchesMoney =
    d.default_commission_bps !== undefined ||
    d.platform_fee_paise !== undefined ||
    d.default_delivery_fee_paise !== undefined ||
    d.free_delivery_above_paise !== undefined;
  if (touchesMoney && !hasAdminCapability(access.adminRole, 'billing.manage')) {
    return NextResponse.json({ success: false, error: 'Only Super Admin or Finance can modify fee rules.' }, { status: 403 });
  }

  const current = await getPlatformAppConfig(access.admin);
  const nextFlags = d.feature_flags ? { ...current.feature_flags, ...d.feature_flags } : current.feature_flags;

  const updateRow: Record<string, any> = {
    singleton: true,
    hero_title: d.hero_title ?? current.hero_title,
    hero_subtitle: d.hero_subtitle ?? current.hero_subtitle,
    hero_badge: d.hero_badge ?? current.hero_badge,
    active_cities: d.active_cities ?? current.active_cities,
    default_commission_bps: d.default_commission_bps ?? current.default_commission_bps,
    platform_fee_paise: d.platform_fee_paise ?? current.platform_fee_paise,
    default_delivery_fee_paise: d.default_delivery_fee_paise ?? current.default_delivery_fee_paise,
    free_delivery_above_paise: d.free_delivery_above_paise ?? current.free_delivery_above_paise,
    require_provider_approval: d.require_provider_approval ?? current.require_provider_approval,
    customer_maintenance: d.customer_maintenance ?? current.customer_maintenance,
    partner_maintenance: d.partner_maintenance ?? current.partner_maintenance,
    maintenance_message: d.maintenance_message ?? current.maintenance_message,
    min_customer_version: d.min_customer_version ?? current.min_customer_version,
    min_partner_version: d.min_partner_version ?? current.min_partner_version,
    feature_flags: nextFlags,
    updated_by: access.userId,
    updated_at: new Date().toISOString(),
  };

  setInMemoryConfigOverride(updateRow);

  const { data, error } = await access.admin
    .from('platform_app_config')
    .upsert(updateRow, { onConflict: 'singleton' })
    .select('*')
    .single();

  if (error) {
    console.warn('platform_app_config upsert fallback:', error.message);
  }

  await logAdminAudit(access.admin, {
    actorUserId: access.userId,
    action: 'app_config.updated',
    subjectType: 'platform_app_config',
    details: parsed.data as Record<string, unknown>,
  });

  const resolved = await getPlatformAppConfig(error ? null : access.admin);
  return NextResponse.json({ success: true, config: data || resolved, message: 'App customization saved.' });
}
