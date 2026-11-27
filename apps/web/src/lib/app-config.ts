import type { SupabaseClient } from '@supabase/supabase-js';

export interface PlatformAppConfig {
  hero_title: string;
  hero_subtitle: string;
  hero_badge: string;
  active_cities: string[];
  default_commission_bps: number;
  platform_fee_paise: number;
  default_delivery_fee_paise: number;
  free_delivery_above_paise: number;
  require_provider_approval: boolean;
  customer_maintenance: boolean;
  partner_maintenance: boolean;
  maintenance_message: string;
  min_customer_version: string;
  min_partner_version: string;
  feature_flags: {
    single_meal_orders: boolean;
    cash_at_counter: boolean;
    cashfree_online: boolean;
    ai_features: boolean;
    self_delivery: boolean;
    snacks_slot: boolean;
    banners_enabled: boolean;
  };
  updated_at: string;
}

export const DEFAULT_APP_CONFIG: PlatformAppConfig = {
  hero_title: 'Home-cooked meals from local messes',
  hero_subtitle: 'Subscribe monthly or order a single plate from verified neighborhood kitchens.',
  hero_badge: 'FRESH DAILY TIFFINS',
  active_cities: ['Noida', 'Bengaluru', 'Delhi', 'Gurugram', 'Pune', 'Hyderabad'],
  default_commission_bps: 0,
  platform_fee_paise: 0,
  default_delivery_fee_paise: 0,
  free_delivery_above_paise: 0,
  require_provider_approval: true,
  customer_maintenance: false,
  partner_maintenance: false,
  maintenance_message: 'Thali is undergoing quick scheduled maintenance. We will be back shortly.',
  min_customer_version: '1.0.0',
  min_partner_version: '1.0.0',
  feature_flags: {
    single_meal_orders: true,
    cash_at_counter: true,
    cashfree_online: true,
    ai_features: true,
    self_delivery: true,
    snacks_slot: true,
    banners_enabled: true,
  },
  updated_at: new Date().toISOString(),
};

let inMemoryConfigOverride: Partial<PlatformAppConfig> = {};

export function getInMemoryConfigOverride(): Partial<PlatformAppConfig> {
  return inMemoryConfigOverride;
}

export function setInMemoryConfigOverride(patch: Partial<PlatformAppConfig>): PlatformAppConfig {
  inMemoryConfigOverride = {
    ...inMemoryConfigOverride,
    ...patch,
    feature_flags: {
      ...DEFAULT_APP_CONFIG.feature_flags,
      ...(inMemoryConfigOverride.feature_flags || {}),
      ...(patch.feature_flags || {}),
    },
    updated_at: new Date().toISOString(),
  };
  return mergeConfig(DEFAULT_APP_CONFIG, inMemoryConfigOverride);
}

function mergeConfig(base: PlatformAppConfig, raw: Record<string, any>): PlatformAppConfig {
  const rawFlags = raw.feature_flags && typeof raw.feature_flags === 'object' ? raw.feature_flags : {};
  const cities = Array.isArray(raw.active_cities)
    ? raw.active_cities.map((c) => String(c).trim()).filter(Boolean)
    : base.active_cities;

  return {
    hero_title: typeof raw.hero_title === 'string' && raw.hero_title.trim() ? raw.hero_title.trim() : base.hero_title,
    hero_subtitle:
      typeof raw.hero_subtitle === 'string' && raw.hero_subtitle.trim() ? raw.hero_subtitle.trim() : base.hero_subtitle,
    hero_badge: typeof raw.hero_badge === 'string' && raw.hero_badge.trim() ? raw.hero_badge.trim() : base.hero_badge,
    active_cities: cities,
    default_commission_bps:
      raw.default_commission_bps !== undefined ? Math.max(0, Number(raw.default_commission_bps)) : base.default_commission_bps,
    platform_fee_paise:
      raw.platform_fee_paise !== undefined ? Math.max(0, Number(raw.platform_fee_paise)) : base.platform_fee_paise,
    default_delivery_fee_paise:
      raw.default_delivery_fee_paise !== undefined
        ? Math.max(0, Number(raw.default_delivery_fee_paise))
        : base.default_delivery_fee_paise,
    free_delivery_above_paise:
      raw.free_delivery_above_paise !== undefined
        ? Math.max(0, Number(raw.free_delivery_above_paise))
        : base.free_delivery_above_paise,
    require_provider_approval:
      typeof raw.require_provider_approval === 'boolean' ? raw.require_provider_approval : base.require_provider_approval,
    customer_maintenance:
      typeof raw.customer_maintenance === 'boolean' ? raw.customer_maintenance : base.customer_maintenance,
    partner_maintenance:
      typeof raw.partner_maintenance === 'boolean' ? raw.partner_maintenance : base.partner_maintenance,
    maintenance_message:
      typeof raw.maintenance_message === 'string' && raw.maintenance_message.trim()
        ? raw.maintenance_message.trim()
        : base.maintenance_message,
    min_customer_version:
      typeof raw.min_customer_version === 'string' && raw.min_customer_version.trim()
        ? raw.min_customer_version.trim()
        : base.min_customer_version,
    min_partner_version:
      typeof raw.min_partner_version === 'string' && raw.min_partner_version.trim()
        ? raw.min_partner_version.trim()
        : base.min_partner_version,
    feature_flags: {
      ...base.feature_flags,
      ...(Object.fromEntries(
        Object.entries(rawFlags).filter(([, v]) => typeof v === 'boolean')
      ) as Partial<PlatformAppConfig['feature_flags']>),
    },
    updated_at: String(raw.updated_at || base.updated_at),
  };
}

export async function getPlatformAppConfig(admin?: SupabaseClient<any> | null): Promise<PlatformAppConfig> {
  if (admin) {
    try {
      const { data, error } = await admin
        .from('platform_app_config')
        .select('*')
        .eq('singleton', true)
        .maybeSingle();
      if (!error && data) {
        return mergeConfig(DEFAULT_APP_CONFIG, data);
      }
    } catch {}
  }
  return mergeConfig(DEFAULT_APP_CONFIG, inMemoryConfigOverride);
}
