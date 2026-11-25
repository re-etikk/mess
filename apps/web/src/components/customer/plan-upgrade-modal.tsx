'use client';

import { useState, useEffect } from 'react';
import { ArrowUpCircle, CheckCircle2, CreditCard, Sparkles, X } from 'lucide-react';
import { launchCashfreeWebCheckout } from '@/lib/cashfree-client';

interface ActiveSub {
  id: string;
  provider_id?: string;
  plan_name_snapshot?: string;
  plan_type_snapshot?: string;
  remaining_meal_credits?: number | null;
  expires_at?: string;
}

export default function CustomerPlanUpgradeModal({
  subscription,
  providerId,
}: {
  subscription: ActiveSub;
  providerId?: string;
}) {
  const [open, setOpen] = useState(false);
  const [plans, setPlans] = useState<any[]>([]);
  const [selectedPlanId, setSelectedPlanId] = useState<string>('');
  const [loading, setLoading] = useState(false);
  const [quote, setQuote] = useState<any>(null);
  const [quoteError, setQuoteError] = useState('');
  const [paymentMode, setPaymentMode] = useState<'cashfree' | 'counter_cash'>('cashfree');
  const [submitting, setSubmitting] = useState(false);
  const [submitted, setSubmitted] = useState(false);

  useEffect(() => {
    if (!open || !providerId) return;
    setLoading(true);
    fetch(`/api/provider/plans?provider_id=${providerId}`)
      .then((r) => r.json())
      .catch(() => ({}))
      .then((pData) => {
        setPlans(pData?.plans || []);
        setLoading(false);
      });
  }, [open, providerId]);

  useEffect(() => {
    if (!selectedPlanId || !subscription.id) return;
    setQuote(null);
    setQuoteError('');
    fetch('/api/subscription/upgrade-quote', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        subscription_id: subscription.id,
        target_plan_id: selectedPlanId,
      }),
    })
      .then(async (res) => {
        const d = await res.json();
        if (!res.ok || !d.success) {
          setQuoteError(d.error || 'Failed to calculate quote');
        } else {
          setQuote(d.quote || d);
        }
      })
      .catch(() => setQuoteError('Network error calculating upgrade difference'));
  }, [selectedPlanId, subscription.id]);

  async function handleUpgradeSubmit(e: React.FormEvent) {
    e.preventDefault();
    if (!selectedPlanId) return;
    setSubmitting(true);
    try {
      if (paymentMode === 'cashfree') {
        const selected = plans.find((p) => p.id === selectedPlanId);
        const orderRes = await fetch('/api/payments/cashfree/create-order', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({
            purpose: 'plan_upgrade',
            provider_id: providerId || subscription.provider_id,
            subscription_id: subscription.id,
            target_plan_id: selectedPlanId,
            plan_name: selected?.name,
            plan_type: selected?.plan_type,
            duration_days: selected?.duration_days || (selected?.duration_months ? selected.duration_months * 30 : 30),
            meal_credits: selected?.meal_credits,
            target_plan_price_paise: selected?.price_paise,
          }),
        });
        const orderData = await orderRes.json().catch(() => ({}));
        if (!orderRes.ok || !orderData.success || !orderData.payment_session_id) {
          throw new Error(orderData.error || 'Unable to start Cashfree online checkout.');
        }
        await launchCashfreeWebCheckout({
          paymentSessionId: orderData.payment_session_id,
          environment: orderData.environment === 'production' ? 'production' : 'sandbox',
        });
        return;
      }

      const res = await fetch('/api/subscription/upgrade', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          subscription_id: subscription.id,
          target_plan_id: selectedPlanId,
          payment_mode: paymentMode,
        }),
      });
      const d = await res.json();
      if (!res.ok || !d.success) throw new Error(d.error || 'Upgrade request failed');
      setSubmitted(true);
    } catch (e: any) {
      alert(e.message || 'Error submitting upgrade');
    } finally {
      setSubmitting(false);
    }
  }

  return (
    <>
      <button
        type="button"
        onClick={() => setOpen(true)}
        className="inline-flex items-center gap-1.5 rounded-xl border border-purple-300 bg-purple-50 px-3.5 py-2 text-xs font-bold text-purple-900 shadow-sm hover:bg-purple-100 transition"
      >
        <ArrowUpCircle size={15} className="text-purple-600" />
        Upgrade / Switch Plan (Pro-Rata Discount)
      </button>

      {open && (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/60 p-4">
          <div className="max-w-lg w-full rounded-3xl bg-white p-6 shadow-2xl space-y-4 max-h-[90vh] overflow-y-auto">
            <div className="flex items-center justify-between border-b pb-3">
              <div>
                <h3 className="text-base font-extrabold text-slate-900 flex items-center gap-1.5">
                  <Sparkles size={18} className="text-purple-600" />
                  OTT-Style Plan Upgrade
                </h3>
                <p className="text-xs text-slate-500">
                  Switch to meal credits or a longer duration plan with instant pro-rata credit for your unused days.
                </p>
              </div>
              <button
                type="button"
                onClick={() => setOpen(false)}
                className="text-slate-400 hover:text-slate-700"
              >
                <X size={20} />
              </button>
            </div>

            {submitted ? (
              <div className="py-8 text-center space-y-3">
                <CheckCircle2 size={48} className="mx-auto text-emerald-600" />
                <h4 className="text-lg font-black text-slate-900">Upgrade Request Submitted!</h4>
                <p className="text-xs text-slate-600 max-w-sm mx-auto">
                  Your upgrade request has been sent to the mess partner. Pay the net difference of ₹
                  {quote?.upgrade_payable_inr ?? 0} in cash at the mess counter. Once verified by the mess, your upgraded pass will activate!
                </p>
                <button
                  type="button"
                  onClick={() => {
                    setOpen(false);
                    window.location.reload();
                  }}
                  className="rounded-xl bg-slate-900 px-6 py-2 text-xs font-bold text-white hover:bg-slate-800"
                >
                  Done
                </button>
              </div>
            ) : (
              <form onSubmit={handleUpgradeSubmit} className="space-y-4 text-xs">
                <div>
                  <label className="block font-bold text-slate-800 mb-1">
                    Select New Upgraded Plan
                  </label>
                  {loading ? (
                    <p className="text-slate-500">Loading available plans...</p>
                  ) : plans.length === 0 ? (
                    <p className="text-slate-500">No alternate plans found for this mess partner.</p>
                  ) : (
                    <div className="space-y-2">
                      {plans.map((p) => {
                        const isSelected = selectedPlanId === p.id;
                        return (
                          <div
                            key={p.id}
                            onClick={() => setSelectedPlanId(p.id)}
                            className={`p-3 rounded-xl border cursor-pointer flex justify-between items-center transition ${
                              isSelected
                                ? 'border-purple-600 bg-purple-50 ring-2 ring-purple-600/20'
                                : 'border-slate-200 hover:bg-slate-50'
                            }`}
                          >
                            <div>
                              <p className="font-bold text-slate-900">{p.name}</p>
                              <p className="text-[11px] text-slate-500">
                                {p.duration_days || (p.duration_months ? p.duration_months * 30 : 30)} Days ·{' '}
                                {p.plan_type === 'meal_credits' ? `${p.meal_credits} Credits` : 'Daily Unlimited'}
                              </p>
                            </div>
                            <span className="font-black text-sm text-slate-900">
                              ₹{(p.price_paise / 100).toFixed(0)}
                            </span>
                          </div>
                        );
                      })}
                    </div>
                  )}
                </div>

                {quoteError && (
                  <div className="rounded-xl border border-red-200 bg-red-50 p-3 text-red-700">
                    {quoteError}
                  </div>
                )}

                {quote && (
                  <div className="rounded-2xl border border-purple-200 bg-purple-50/70 p-4 space-y-2">
                    <p className="font-extrabold text-purple-950 flex items-center gap-1.5">
                      <Sparkles size={14} className="text-purple-600" />
                      Pro-Rata Calculation Breakdown
                    </p>
                    <div className="flex justify-between text-slate-700">
                      <span>Target Plan Price:</span>
                      <span className="font-bold">₹{quote.target_plan_price_inr}</span>
                    </div>
                    <div className="flex justify-between text-emerald-800 font-medium">
                      <span>Unused Days/Credits Deducted:</span>
                      <span>-₹{quote.residual_credit_inr}</span>
                    </div>
                    <div className="border-t border-purple-200/80 pt-2 flex justify-between items-center">
                      <span className="font-black text-slate-900">Net Payable Difference:</span>
                      <span className="text-lg font-black text-purple-800">
                        ₹{quote.upgrade_payable_inr}
                      </span>
                    </div>
                  </div>
                )}

                <div>
                  <label className="block font-bold text-slate-800 mb-1">Payment Method</label>
                  <div className="grid grid-cols-2 gap-2">
                    <button
                      type="button"
                      onClick={() => setPaymentMode('cashfree')}
                      className={`p-2.5 rounded-xl border text-center font-bold transition flex flex-col items-center gap-1 ${
                        paymentMode === 'cashfree'
                          ? 'border-orange-600 bg-orange-50 text-orange-900'
                          : 'border-slate-200 bg-white text-slate-700'
                      }`}
                    >
                      <CreditCard size={15} />
                      <span>Pay Online (Cashfree)</span>
                    </button>
                    <button
                      type="button"
                      onClick={() => setPaymentMode('counter_cash')}
                      className={`p-2.5 rounded-xl border text-center font-bold transition flex flex-col items-center gap-1 ${
                        paymentMode === 'counter_cash'
                          ? 'border-amber-600 bg-amber-50 text-amber-900'
                          : 'border-slate-200 bg-white text-slate-700'
                      }`}
                    >
                      <span>💵</span>
                      <span>Pay Cash at Counter</span>
                    </button>
                  </div>
                </div>

                <div className="pt-2">
                  <button
                    type="submit"
                    disabled={!selectedPlanId || submitting}
                    className="w-full rounded-xl bg-orange-600 py-3 font-extrabold text-white shadow hover:bg-orange-700 disabled:bg-slate-300 transition"
                  >
                    {submitting ? 'Submitting Upgrade Request...' : 'Confirm & Request Upgrade'}
                  </button>
                </div>
              </form>
            )}
          </div>
        </div>
      )}
    </>
  );
}
