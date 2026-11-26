/**
 * Shared helpers for computing kitchen open/closed status consistently
 * across Customer discovery, Mess detail, Partner dashboard, and Status APIs.
 */

const WEEKDAYS_SHORT = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'] as const;

export function getIstWeekday(now: Date = new Date()): number {
  const weekdayName = new Intl.DateTimeFormat('en-US', {
    timeZone: 'Asia/Kolkata',
    weekday: 'short',
  }).format(now);
  const idx = WEEKDAYS_SHORT.indexOf(weekdayName as (typeof WEEKDAYS_SHORT)[number]);
  return idx >= 0 ? idx : now.getUTCDay();
}

export function isKitchenOpenFromRecord(params: {
  status?: string | null;
  is_accepting_orders?: boolean | null;
  todayHours?: { closed?: boolean | null } | null;
}): boolean {
  if (params.status && params.status !== 'active') return false;
  if (params.is_accepting_orders === false) return false;
  if (params.todayHours?.closed === true) return false;
  return true;
}

export function isUndefinedColumnError(error: any, columnName: string): boolean {
  if (!error) return false;
  const code = String(error.code || '');
  const msg = String(error.message || '').toLowerCase();
  return code === '42703' || (msg.includes('column') && msg.includes(columnName.toLowerCase()));
}
