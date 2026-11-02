import { NextRequest, NextResponse } from 'next/server';
import { createClient as createSessionClient } from '@/lib/supabase/server';
import { getAdminClient } from '@/lib/supabase/admin';

export const dynamic = 'force-dynamic';

async function failRequest(admin: NonNullable<ReturnType<typeof getAdminClient>>, requestId: string, userId: string, status: number, message: string) {
  await admin.from('account_deletion_requests').update({ status: 'failed' }).eq('id', requestId).eq('user_id', userId);
  return NextResponse.json({ success: false, error: message, request_id: requestId }, { status });
}

export async function DELETE(req: NextRequest) {
  if (req.headers.get('x-account-deletion-confirmation') !== 'DELETE') {
    return NextResponse.json({ success: false, error: 'Confirm permanent deletion by typing DELETE.' }, { status: 400 });
  }
  const admin = getAdminClient();
  if (!admin) return NextResponse.json({ success: false, error: 'Account deletion is temporarily unavailable.' }, { status: 503 });

  let userId: string | null = null;
  const authorization = req.headers.get('authorization');
  if (authorization?.startsWith('Bearer ')) {
    const token = authorization.slice(7).trim();
    const { data, error } = await admin.auth.getUser(token);
    if (!error && data.user) userId = data.user.id;
  } else {
    try {
      const session = await createSessionClient();
      const { data, error } = await session.auth.getUser();
      if (!error && data.user) userId = data.user.id;
    } catch { /* handled as unauthenticated below */ }
  }
  if (!userId) return NextResponse.json({ success: false, error: 'Sign in to the account you want to delete, then retry.' }, { status: 401 });

  const [{ data: roles, error: rolesError }, { data: memberships, error: membershipError }] = await Promise.all([
    admin.from('user_roles').select('role').eq('user_id', userId).is('revoked_at', null),
    admin.from('provider_memberships').select('provider_id,role').eq('user_id', userId).eq('active', true),
  ]);
  if (rolesError || membershipError) return NextResponse.json({ success: false, error: 'Account type could not be verified. Please retry later.' }, { status: 503 });
  const isProvider = (memberships ?? []).some((membership) => ['owner', 'manager'].includes(membership.role)) || (roles ?? []).some((role) => role.role === 'provider');
  const isCustomer = (roles ?? []).some((role) => role.role === 'customer');
  if ((roles ?? []).some((role) => role.role === 'admin')) return NextResponse.json({ success: false, error: 'Platform administrator accounts must be handled by the platform owner and cannot be deleted through customer or partner settings.' }, { status: 403 });
  if (!isProvider && !isCustomer) return NextResponse.json({ success: false, error: 'This deletion page supports customer and mess partner accounts.' }, { status: 403 });

  const { data: existing } = await admin.from('account_deletion_requests').select('id,status')
    .eq('user_id', userId).in('status', ['pending', 'failed']).order('requested_at', { ascending: false }).limit(1).maybeSingle();
  let requestId = existing?.id as string | undefined;
  if (!requestId) {
    const { data: request, error } = await admin.from('account_deletion_requests').insert({
      user_id: userId, account_type: isProvider ? 'provider' : 'customer', status: 'pending',
    }).select('id').single();
    if (error || !request) return NextResponse.json({ success: false, error: 'Your request could not be recorded. Please retry or contact support.' }, { status: 503 });
    requestId = request.id;
  } else {
    await admin.from('account_deletion_requests').update({ status: 'pending' }).eq('id', requestId);
  }
  if (!requestId) return NextResponse.json({ success: false, error: 'Your request could not be recorded. Please retry.' }, { status: 503 });

  const { error: disableError } = await admin.auth.admin.updateUserById(userId, { ban_duration: '876000h' });
  if (disableError) return failRequest(admin, requestId, userId, 503, 'Your request is recorded, but account access could not be disabled. Contact support with the request ID.');

  try {
    if (isProvider) {
      const { data: owned, error: ownedError } = await admin.from('providers').select('id').eq('owner_user_id', userId);
      if (ownedError) return failRequest(admin, requestId, userId, 503, 'Your deletion request is recorded, but the mess could not be safely deactivated. Contact platform support with the request ID.');
      const providerIds = (owned ?? []).map((provider) => provider.id);
      if (providerIds.length) {
        const { error } = await admin.from('providers').update({ status: 'suspended', public_phone: null, public_email: null }).in('id', providerIds);
        if (error) return failRequest(admin, requestId, userId, 503, 'Your deletion request is recorded, but the mess could not be safely deactivated. Contact platform support with the request ID.');
      }
    }

    if (isCustomer) {
      const { error: subsError } = await admin.from('subscriptions').update({ status: 'cancelled', cancelled_at: new Date().toISOString() })
        .eq('customer_id', userId).in('status', ['active', 'paused', 'pending_payment']);
      if (subsError) return failRequest(admin, requestId, userId, 503, 'Your deletion request is recorded, but active entitlements could not be safely closed. Contact support with the request ID.');
      const { error: bookingError } = await admin.from('meal_bookings').update({ status: 'cancelled', cancelled_at: new Date().toISOString(), address_snapshot: null, customer_note: null })
        .eq('customer_id', userId).in('status', ['draft', 'pending_payment', 'confirmed', 'ready', 'assigned', 'accepted']);
      if (bookingError) return failRequest(admin, requestId, userId, 503, 'Your deletion request is recorded, but open bookings could not be safely closed. Contact support with the request ID.');
      const { error: snapshotError } = await admin.from('meal_bookings').update({ address_snapshot: null, customer_note: null }).eq('customer_id', userId);
      if (snapshotError) return failRequest(admin, requestId, userId, 503, 'Your deletion request is recorded, but personal booking details could not be removed. Contact support with the request ID.');
    }

    const { error: ticketError } = await admin.from('support_tickets').update({
      subject: 'Account deletion completed', description: 'Personal support content removed at the account holder’s request.',
    }).eq('created_by', userId);
    if (ticketError) return failRequest(admin, requestId, userId, 503, 'Your deletion request is recorded, but personal support messages could not be removed. Contact support with the request ID.');

    const { error: deleteError } = await admin.auth.admin.deleteUser(userId);
    if (deleteError) {
      console.error('Account deletion failed:', deleteError.message);
      return failRequest(admin, requestId, userId, 503, 'Your request is recorded but needs support to complete. Contact support with the request ID.');
    }
    const { error: completeError } = await admin.from('account_deletion_requests').update({ status: 'completed', completed_at: new Date().toISOString() }).eq('id', requestId);
    if (completeError) console.error('Account deletion completion status could not be recorded:', completeError.message);
    return NextResponse.json({ success: true, request_id: requestId, message: 'Your account and associated personal data have been deleted. Some anonymized transaction and audit records are retained where required.' });
  } catch (error) {
    console.error('Account deletion processing failed:', error instanceof Error ? error.message : 'unknown error');
    return failRequest(admin, requestId, userId, 503, 'Your request is recorded but needs support to complete. Contact support with the request ID.');
  }
}
