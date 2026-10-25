// ==============================================================================
// RATE LIMITING & ABUSE PREVENTION (Anti-Hack Security Layer)
// Protects QR generation, redemption, payment webhooks, and OTP verification
// ==============================================================================

interface RateLimitRecord {
  count: number;
  resetAt: number;
}

const rateLimitStore = new Map<string, RateLimitRecord>();

/**
 * Checks and updates rate limits for a given IP or identifier.
 * Returns true if allowed, false if rate limited.
 */
export function checkRateLimit(
  key: string,
  limit: number = 20,
  windowMs: number = 60 * 1000
): { isAllowed: boolean; remaining: number; resetInMs: number } {
  const now = Date.now();
  const record = rateLimitStore.get(key);

  if (!record || now > record.resetAt) {
    rateLimitStore.set(key, { count: 1, resetAt: now + windowMs });
    return { isAllowed: true, remaining: limit - 1, resetInMs: windowMs };
  }

  if (record.count >= limit) {
    return { isAllowed: false, remaining: 0, resetInMs: record.resetAt - now };
  }

  record.count += 1;
  return { isAllowed: true, remaining: limit - record.count, resetInMs: record.resetAt - now };
}
