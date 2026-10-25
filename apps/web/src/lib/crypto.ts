import crypto from 'crypto';
import { RedemptionTokenPayload } from '@/types';
import { APP_CONFIG } from './config';

/**
 * Signing must fail closed outside an explicitly isolated test process.  A
 * public fallback would let anyone forge production meal passes.
 */
function getQrSecret(): string {
  const secret = process.env.QR_SIGNING_SECRET || process.env.QR_HMAC_SECRET;
  if (secret && secret.length >= 32) return secret;

  if (process.env.NODE_ENV === 'test') {
    return 'test-only-qr-signing-secret-not-for-production-0001';
  }

  throw new Error('QR_SIGNING_SECRET must be configured with at least 32 characters.');
}

export interface SignedQRToken {
  payload: RedemptionTokenPayload;
  signature: string;
  tokenHash: string;
  encodedString: string;
}

/**
 * Generates a tamper-proof, single-use, 5-minute signed QR token.
 */
export function generateSignedQRToken(params: {
  bookingId: string;
  customerId: string;
  providerId: string;
  mealSlotId: string;
  bookingDate: string;
}): SignedQRToken {
  const nonce = crypto.randomBytes(16).toString('hex');
  const expiresAt = Date.now() + APP_CONFIG.qrSecurity.validityWindowMinutes * 60 * 1000;

  const payload: RedemptionTokenPayload = {
    booking_id: params.bookingId,
    customer_id: params.customerId,
    provider_id: params.providerId,
    meal_slot_id: params.mealSlotId,
    booking_date: params.bookingDate,
    nonce,
    expires_at: expiresAt,
  };

  const payloadString = JSON.stringify(payload);
  const signature = crypto
    .createHmac('sha256', getQrSecret())
    .update(payloadString)
    .digest('hex');

  const combined = `${Buffer.from(payloadString).toString('base64url')}.${signature}`;
  const tokenHash = crypto.createHash('sha256').update(combined).digest('hex');

  return {
    payload,
    signature,
    tokenHash,
    encodedString: combined,
  };
}

/**
 * Cryptographically verifies and unpacks a signed QR code string.
 * Returns null if the signature is invalid or payload was tampered with.
 */
export function verifySignedQRToken(encodedString: string): {
  isValid: boolean;
  isExpired: boolean;
  payload?: RedemptionTokenPayload;
  tokenHash: string;
  error?: string;
} {
  const tokenHash = crypto.createHash('sha256').update(encodedString).digest('hex');

  try {
    const parts = encodedString.split('.');
    if (parts.length !== 2) {
      return { isValid: false, isExpired: false, tokenHash, error: 'Malformed token structure' };
    }

    const [b64Payload, signature] = parts;
    const payloadString = Buffer.from(b64Payload, 'base64url').toString('utf-8');

    const expectedSignature = crypto
      .createHmac('sha256', getQrSecret())
      .update(payloadString)
      .digest('hex');

    // Constant-time comparison to prevent timing attacks
    const sigBuf = Buffer.from(signature, 'hex');
    const expBuf = Buffer.from(expectedSignature, 'hex');

    if (sigBuf.length !== expBuf.length || !crypto.timingSafeEqual(sigBuf, expBuf)) {
      return { isValid: false, isExpired: false, tokenHash, error: 'Cryptographic signature mismatch' };
    }

    const payload = JSON.parse(payloadString) as RedemptionTokenPayload;
    const isExpired = Date.now() > payload.expires_at;

    return {
      isValid: true,
      isExpired,
      payload,
      tokenHash,
      error: isExpired ? 'QR code expired. Please refresh on customer app.' : undefined,
    };
  } catch (err: any) {
    return { isValid: false, isExpired: false, tokenHash, error: 'Failed to parse token payload' };
  }
}

/**
 * Validates Razorpay / Indian Payment Gateway Webhook signature
 */
export function verifyWebhookSignature(body: string, signature: string, secret: string): boolean {
  if (!signature || !secret) return false;
  try {
    const expected = crypto.createHmac('sha256', secret).update(body).digest('hex');
    const sigBuf = Buffer.from(signature, 'hex');
    const expBuf = Buffer.from(expected, 'hex');
    return sigBuf.length === expBuf.length && crypto.timingSafeEqual(sigBuf, expBuf);
  } catch {
    return false;
  }
}

/**
 * Returns current date string (YYYY-MM-DD) in Asia/Kolkata timezone
 */
export function getIndiaDateString(date: Date = new Date()): string {
  const formatter = new Intl.DateTimeFormat('en-CA', {
    timeZone: 'Asia/Kolkata',
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
  });
  return formatter.format(date);
}

/**
 * Generates a signed, date-bound Daily Counter QR token for a mess provider.
 * Format: MESS_QR|<providerId>|<YYYY-MM-DD>|<slotOrAll>|<signature>
 */
export function generateCounterQRToken(params: {
  providerId: string;
  date?: string;
  slot?: string;
}): string {
  const dateStr = params.date || getIndiaDateString();
  const slotStr = params.slot || 'ALL';
  const rawData = `${params.providerId}:${dateStr}:${slotStr}`;
  const signature = crypto.createHmac('sha256', getQrSecret()).update(rawData).digest('hex');
  return `MESS_QR|${params.providerId}|${dateStr}|${slotStr}|${signature}`;
}

/**
 * Verifies a signed Counter QR token scanned by a customer.
 */
export function verifyCounterQRToken(token: string): {
  isValid: boolean;
  isExpired: boolean;
  providerId?: string;
  date?: string;
  slot?: string;
  error?: string;
} {
  try {
    const parts = token.trim().split('|');
    if (parts.length < 4) {
      return { isValid: false, isExpired: false, error: 'Invalid QR token structure' };
    }

    const prefix = parts[0];
    const today = getIndiaDateString();

    if (prefix !== 'MESS_QR' || parts.length < 5) {
      return { isValid: false, isExpired: false, error: 'Unrecognized QR token type' };
    }

    const [, providerId, date, slot, signature] = parts;

    // Check date against Asia/Kolkata date
    if (date !== today) {
      return {
        isValid: false,
        isExpired: true,
        providerId,
        date,
        slot,
        error: `This Counter QR is expired. Code date is ${date}, but today in India is ${today}.`,
      };
    }

    const rawData = `${providerId}:${date}:${slot}`;
    const expectedSignature = crypto.createHmac('sha256', getQrSecret()).update(rawData).digest('hex');

    const sigBuf = Buffer.from(signature, 'hex');
    const expBuf = Buffer.from(expectedSignature, 'hex');

    if (sigBuf.length !== expBuf.length || !crypto.timingSafeEqual(sigBuf, expBuf)) {
      return { isValid: false, isExpired: false, error: 'Cryptographic signature mismatch' };
    }

    return {
      isValid: true,
      isExpired: false,
      providerId,
      date,
      slot,
    };
  } catch (err: any) {
    return { isValid: false, isExpired: false, error: 'Failed to parse counter QR' };
  }
}

