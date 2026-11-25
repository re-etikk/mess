import crypto from 'crypto';

export type CashfreeEnvironment = 'sandbox' | 'production';

export interface CashfreeConfig {
  appId: string;
  secretKey: string;
  env: CashfreeEnvironment;
  apiBase: string;
  apiVersion: string;
  configured: boolean;
}

export function getCashfreeConfig(): CashfreeConfig {
  const appId = (process.env.CASHFREE_APP_ID || process.env.CASHFREE_CLIENT_ID || '').trim();
  const secretKey = (process.env.CASHFREE_SECRET_KEY || process.env.CASHFREE_CLIENT_SECRET || '').trim();
  const rawEnv = (process.env.CASHFREE_ENV || process.env.NEXT_PUBLIC_CASHFREE_ENV || 'sandbox').trim().toLowerCase();
  const env: CashfreeEnvironment = rawEnv === 'production' || rawEnv === 'prod' ? 'production' : 'sandbox';
  const apiBase = env === 'production' ? 'https://api.cashfree.com/pg' : 'https://sandbox.cashfree.com/pg';
  const apiVersion = (process.env.CASHFREE_API_VERSION || '2023-08-01').trim();

  return {
    appId,
    secretKey,
    env,
    apiBase,
    apiVersion,
    configured: Boolean(appId && secretKey),
  };
}

export interface CreateCashfreeOrderInput {
  orderId: string;
  orderAmountInr: number;
  customerId: string;
  customerName?: string;
  customerEmail?: string;
  customerPhone: string;
  returnUrl: string;
  notifyUrl?: string;
  orderNote?: string;
  orderTags?: Record<string, string>;
  idempotencyKey?: string;
}

export interface CashfreeOrderResponse {
  cf_order_id?: string | number;
  order_id: string;
  payment_session_id: string;
  order_status: string;
  order_amount: number;
  order_currency: string;
  order_meta?: {
    return_url?: string;
    notify_url?: string;
  };
  order_tags?: Record<string, string>;
}

function sanitizePhone(raw?: string): string {
  const digits = (raw || '').replace(/\D/g, '');
  if (digits.length >= 10) return digits.slice(-10);
  return '9999999999';
}

function sanitizeEmail(raw?: string): string {
  const trimmed = (raw || '').trim();
  if (trimmed.includes('@') && trimmed.includes('.')) return trimmed;
  return 'customer@thali.store';
}

function sanitizeCustomerId(raw?: string): string {
  const cleaned = (raw || 'cust_thali').replace(/[^a-zA-Z0-9_-]/g, '_');
  return cleaned.slice(0, 48) || 'cust_thali';
}

export async function createCashfreeOrder(input: CreateCashfreeOrderInput): Promise<{
  order: CashfreeOrderResponse;
  env: CashfreeEnvironment;
}> {
  const cfg = getCashfreeConfig();
  if (!cfg.configured) {
    throw new Error('Cashfree credentials (CASHFREE_APP_ID and CASHFREE_SECRET_KEY) are not configured on the server.');
  }

  const amount = Math.max(1, Number(input.orderAmountInr.toFixed(2)));
  const payload: Record<string, unknown> = {
    order_id: input.orderId,
    order_amount: amount,
    order_currency: 'INR',
    customer_details: {
      customer_id: sanitizeCustomerId(input.customerId),
      customer_name: (input.customerName || 'Thali Customer').trim().slice(0, 100),
      customer_email: sanitizeEmail(input.customerEmail),
      customer_phone: sanitizePhone(input.customerPhone),
    },
    order_meta: {
      return_url: input.returnUrl,
      ...(input.notifyUrl ? { notify_url: input.notifyUrl } : {}),
    },
    ...(input.orderNote ? { order_note: input.orderNote.slice(0, 200) } : {}),
    ...(input.orderTags ? { order_tags: input.orderTags } : {}),
  };

  const res = await fetch(`${cfg.apiBase}/orders`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'x-api-version': cfg.apiVersion,
      'x-client-id': cfg.appId,
      'x-client-secret': cfg.secretKey,
      ...(input.idempotencyKey ? { 'x-idempotency-key': input.idempotencyKey } : {}),
    },
    body: JSON.stringify(payload),
    cache: 'no-store',
  });

  const data = await res.json().catch(() => ({}));
  if (!res.ok || !data?.payment_session_id) {
    const errMsg = data?.message || data?.error || `Cashfree order creation failed (${res.status})`;
    throw new Error(errMsg);
  }

  return { order: data as CashfreeOrderResponse, env: cfg.env };
}

export async function fetchCashfreeOrder(orderId: string): Promise<CashfreeOrderResponse> {
  const cfg = getCashfreeConfig();
  if (!cfg.configured) {
    throw new Error('Cashfree credentials are not configured on the server.');
  }

  const res = await fetch(`${cfg.apiBase}/orders/${encodeURIComponent(orderId)}`, {
    method: 'GET',
    headers: {
      'x-api-version': cfg.apiVersion,
      'x-client-id': cfg.appId,
      'x-client-secret': cfg.secretKey,
    },
    cache: 'no-store',
  });

  const data = await res.json().catch(() => ({}));
  if (!res.ok || !data?.order_id) {
    throw new Error(data?.message || `Unable to fetch Cashfree order (${res.status}).`);
  }
  return data as CashfreeOrderResponse;
}

export async function fetchCashfreeOrderPayments(orderId: string): Promise<any[]> {
  const cfg = getCashfreeConfig();
  if (!cfg.configured) return [];

  const res = await fetch(`${cfg.apiBase}/orders/${encodeURIComponent(orderId)}/payments`, {
    method: 'GET',
    headers: {
      'x-api-version': cfg.apiVersion,
      'x-client-id': cfg.appId,
      'x-client-secret': cfg.secretKey,
    },
    cache: 'no-store',
  });

  if (!res.ok) return [];
  const data = await res.json().catch(() => []);
  return Array.isArray(data) ? data : [];
}

/**
 * Verifies Cashfree webhook signature (`x-webhook-signature`) using
 * `HMAC-SHA256(secretKey, timestamp + rawBody)` encoded in Base64.
 */
export function verifyCashfreeWebhookSignature(
  rawBody: string,
  signatureHeader: string | null,
  timestampHeader: string | null,
): boolean {
  const cfg = getCashfreeConfig();
  const webhookSecret = (process.env.CASHFREE_WEBHOOK_SECRET || cfg.secretKey).trim();
  if (!webhookSecret || !signatureHeader || !timestampHeader || !rawBody) {
    return false;
  }

  const signedPayload = `${timestampHeader}${rawBody}`;
  const computed = crypto
    .createHmac('sha256', webhookSecret)
    .update(signedPayload)
    .digest('base64');

  const expectedBuf = Buffer.from(computed, 'utf8');
  const receivedBuf = Buffer.from(signatureHeader.trim(), 'utf8');
  if (expectedBuf.length !== receivedBuf.length) {
    return false;
  }
  return crypto.timingSafeEqual(expectedBuf, receivedBuf);
}

export interface PendingCashfreeOrderMeta {
  order_id: string;
  cf_order_id?: string;
  payment_session_id: string;
  purpose: 'subscription_purchase' | 'single_meal_purchase' | 'plan_upgrade' | 'add_ons';
  subscription_id?: string;
  upgrade_from_subscription_id?: string;
  customer_id: string;
  customer_name: string;
  customer_phone: string;
  customer_email: string;
  provider_id: string;
  provider_name: string;
  plan_id?: string;
  plan_name: string;
  plan_type?: 'fixed_period' | 'meal_credits' | 'daily';
  duration_days?: number;
  meal_credits?: number | null;
  slot?: string;
  amount_paise: number;
  status: 'created' | 'paid' | 'failed';
  created_at: string;
  verified_at?: string;
}

const g = globalThis as unknown as { __cashfreeOrderStore?: Map<string, PendingCashfreeOrderMeta> };
export const cashfreeOrderStore: Map<string, PendingCashfreeOrderMeta> =
  g.__cashfreeOrderStore || (g.__cashfreeOrderStore = new Map<string, PendingCashfreeOrderMeta>());
