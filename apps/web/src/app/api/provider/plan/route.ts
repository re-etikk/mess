import { NextRequest } from 'next/server';
import { GET as listPlans, PATCH as updatePlan, POST as createPlan, DELETE as removePlan } from '../plans/route';

export const dynamic = 'force-dynamic';
export const GET = listPlans;
export const DELETE = removePlan;

export async function POST(req: NextRequest) {
  let body: Record<string, unknown>;
  try { body = await req.json() as Record<string, unknown>; }
  catch { return Response.json({ success: false, error: 'Invalid JSON body.' }, { status: 400 }); }
  const planId = body.plan_id || body.id;
  if (typeof planId === 'string' && planId) {
    const headers = new Headers(req.headers);
    headers.set('content-type', 'application/json');
    return updatePlan(new NextRequest(req.url, {
      method: 'PATCH', headers,
      body: JSON.stringify({ ...body, plan_id: planId }),
    }));
  }
  return createPlan(new NextRequest(req.url, {
    method: 'POST', headers: req.headers,
    body: JSON.stringify(body),
  }));
}
