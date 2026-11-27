'use client';

import { useState } from 'react';
import Link from 'next/link';
import { Banknote, CheckCircle2, Copy, ExternalLink, Landmark, MessageCircle, Plus, Search, Trash2, Truck } from 'lucide-react';
import { DeliveryRider, SettlementRow, formatInr, formatShortDate } from './types';

interface RidersAndFinanceProps {
  mode: 'riders' | 'finance';
  providerId: string;
  riders: DeliveryRider[];
  settlements: SettlementRow[];
  initialPaymentSettings: {
    upi_id: string;
    upi_name: string;
    upi_qr_url: string;
    account_number: string;
    ifsc_code: string;
    bank_name: string;
    branch_name: string;
    account_holder_name: string;
  };
  onRefresh: () => Promise<void> | void;
  onNotify: (msg: string, isError?: boolean) => void;
}

export default function PartnerRidersAndFinanceTab({
  mode,
  providerId,
  riders,
  settlements,
  initialPaymentSettings,
  onRefresh,
  onNotify,
}: RidersAndFinanceProps) {
  // Rider form state
  const [riderName, setRiderName] = useState('');
  const [riderPhone, setRiderPhone] = useState('');
  const [riderPin, setRiderPin] = useState('');
  const [savingRider, setSavingRider] = useState(false);

  // Payment & Bank Settings state
  const [upiId, setUpiId] = useState(initialPaymentSettings.upi_id || '');
  const [upiName, setUpiName] = useState(initialPaymentSettings.upi_name || '');
  const [upiQrUrl, setUpiQrUrl] = useState(initialPaymentSettings.upi_qr_url || '');
  const [accountNumber, setAccountNumber] = useState(initialPaymentSettings.account_number || '');
  const [ifscCode, setIfscCode] = useState(initialPaymentSettings.ifsc_code || '');
  const [bankName, setBankName] = useState(initialPaymentSettings.bank_name || '');
  const [branchName, setBranchName] = useState(initialPaymentSettings.branch_name || '');
  const [accountHolderName, setAccountHolderName] = useState(initialPaymentSettings.account_holder_name || '');
  const [ifscVerifying, setIfscVerifying] = useState(false);
  const [savingSettings, setSavingSettings] = useState(false);

  async function handleAddRider(e: React.FormEvent) {
    e.preventDefault();
    const digits = riderPhone.replace(/\D/g, '').slice(-10);
    if (!riderName.trim() || digits.length !== 10) {
      onNotify('Enter rider name and valid 10-digit mobile number.', true);
      return;
    }
    setSavingRider(true);
    try {
      const res = await fetch('/api/delivery/riders', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          provider_id: providerId,
          name: riderName.trim(),
          phone: digits,
          pin_code: riderPin.trim() || undefined,
        }),
      });
      const data = await res.json().catch(() => ({}));
      if (!res.ok || !data.success) {
        onNotify(data.error || 'Could not add delivery rider.', true);
      } else {
        setRiderName('');
        setRiderPhone('');
        setRiderPin('');
        onNotify(`Added ${data.rider?.name || 'rider'} (PIN: ${data.rider?.pin_code || 'configured'}).`);
        await onRefresh();
      }
    } finally {
      setSavingRider(false);
    }
  }

  async function removeRider(rider: DeliveryRider) {
    const res = await fetch(`/api/delivery/riders?provider_id=${providerId}&rider_id=${rider.id}`, {
      method: 'DELETE',
    });
    if (res.ok) {
      onNotify(`Removed ${rider.name} from active delivery roster.`);
      await onRefresh();
    } else {
      onNotify('Could not remove rider.', true);
    }
  }

  async function verifyIfsc() {
    const clean = ifscCode.trim().toUpperCase();
    if (clean.length !== 11) {
      onNotify('IFSC must be 11 characters (e.g. SBIN0001234).', true);
      return;
    }
    setIfscVerifying(true);
    try {
      const res = await fetch(`/api/bank/ifsc?code=${clean}`);
      const data = await res.json().catch(() => ({}));
      if (!res.ok || !data.success) {
        onNotify(data.error || 'Could not verify IFSC code.', true);
      } else {
        setIfscCode(clean);
        setBankName(data.bank || bankName);
        setBranchName([data.branch, data.city].filter(Boolean).join(', '));
        onNotify(`Verified: ${data.bank} (${data.branch || 'Main Branch'})`);
      }
    } finally {
      setIfscVerifying(false);
    }
  }

  async function savePaymentSettings(e: React.FormEvent) {
    e.preventDefault();
    setSavingSettings(true);
    try {
      const res = await fetch('/api/provider/payment-settings', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          provider_id: providerId,
          upi_id: upiId.trim(),
          upi_name: upiName.trim(),
          upi_qr_url: upiQrUrl.trim(),
          account_number: accountNumber.trim(),
          ifsc_code: ifscCode.trim().toUpperCase(),
          bank_name: bankName.trim(),
          branch_name: branchName.trim(),
          account_holder_name: accountHolderName.trim(),
        }),
      });
      const data = await res.json().catch(() => ({}));
      if (!res.ok || !data.success) {
        onNotify(data.error || 'Could not save bank & UPI settings.', true);
      } else {
        onNotify('Payout bank account & UPI settings saved!');
        await onRefresh();
      }
    } finally {
      setSavingSettings(false);
    }
  }

  if (mode === 'riders') {
    return (
      <div className="space-y-6">
        <div className="flex flex-wrap items-center justify-between gap-3 rounded-2xl border border-slate-200 bg-white p-5">
          <div className="flex items-center gap-2.5">
            <Truck size={19} className="text-orange-600" />
            <div>
              <h2 className="text-base font-black text-slate-950">Delivery Staff &amp; Rider Portal Links</h2>
              <p className="text-xs text-slate-500">
                Add riders so you can assign tiffins in Live Kitchen Queue and let them update deliveries via /rider/portal.
              </p>
            </div>
          </div>
          <Link
            href="/rider/portal"
            target="_blank"
            className="inline-flex items-center gap-1.5 rounded-xl border border-slate-300 px-3.5 py-2 text-xs font-bold text-slate-700 hover:bg-slate-50"
          >
            Open Rider Portal <ExternalLink size={13} />
          </Link>
        </div>

        <form onSubmit={handleAddRider} className="grid gap-3 rounded-2xl border border-slate-200 bg-white p-5 sm:grid-cols-12">
          <input
            type="text"
            required
            value={riderName}
            onChange={(e) => setRiderName(e.target.value)}
            placeholder="Rider Name (e.g. Suresh)"
            className="sm:col-span-4 rounded-xl border border-slate-300 px-3 py-2 text-xs"
          />
          <input
            type="tel"
            required
            maxLength={10}
            value={riderPhone}
            onChange={(e) => setRiderPhone(e.target.value)}
            placeholder="10-digit Mobile Number"
            className="sm:col-span-4 rounded-xl border border-slate-300 px-3 py-2 font-mono text-xs"
          />
          <input
            type="text"
            maxLength={4}
            value={riderPin}
            onChange={(e) => setRiderPin(e.target.value.replace(/\D/g, '').slice(0, 4))}
            placeholder="4-digit PIN (auto if empty)"
            className="sm:col-span-2 rounded-xl border border-slate-300 px-3 py-2 font-mono text-xs"
          />
          <button
            type="submit"
            disabled={savingRider}
            className="sm:col-span-2 inline-flex items-center justify-center gap-1 rounded-xl bg-orange-600 px-4 py-2 text-xs font-bold text-white hover:bg-orange-700 disabled:bg-slate-400"
          >
            <Plus size={14} /> {savingRider ? 'Adding...' : 'Add Rider'}
          </button>
        </form>

        {riders.length === 0 ? (
          <div className="rounded-2xl border border-dashed border-slate-300 bg-white p-8 text-center text-xs text-slate-500">
            No active delivery staff configured yet. Add your first rider above.
          </div>
        ) : (
          <div className="space-y-3">
            {riders.map((r) => (
              <article key={r.id} className="flex flex-wrap items-center justify-between gap-3 rounded-2xl border border-slate-200 bg-white p-4">
                <div>
                  <p className="text-sm font-bold text-slate-950">{r.name}</p>
                  <p className="mt-0.5 font-mono text-xs text-slate-600">+91 {r.phone}</p>
                </div>
                <div className="flex flex-wrap items-center gap-2">
                  <button
                    type="button"
                    onClick={() => {
                      void navigator.clipboard.writeText(r.rider_url);
                      onNotify(`Copied rider link for ${r.name}.`);
                    }}
                    className="inline-flex items-center gap-1 rounded-xl border border-slate-300 px-3 py-1.5 text-xs font-bold text-slate-700 hover:bg-slate-50"
                  >
                    <Copy size={13} /> Copy Portal Link
                  </button>
                  <a
                    href={r.whatsapp_url}
                    target="_blank"
                    rel="noreferrer"
                    className="inline-flex items-center gap-1 rounded-xl bg-emerald-700 px-3 py-1.5 text-xs font-bold text-white hover:bg-emerald-800"
                  >
                    <MessageCircle size={13} /> Share on WhatsApp
                  </a>
                  <button
                    type="button"
                    onClick={() => removeRider(r)}
                    className="rounded-xl border border-red-200 p-2 text-red-600 hover:bg-red-50"
                    title="Deactivate rider"
                  >
                    <Trash2 size={14} />
                  </button>
                </div>
              </article>
            ))}
          </div>
        )}
      </div>
    );
  }

  // FINANCE: SETTLEMENTS & BANK/UPI SETTINGS
  const totalSettled = settlements
    .filter((s) => s.status === 'paid' || s.status === 'active')
    .reduce((acc, s) => acc + Number(s.amount_inr || 0), 0);

  return (
    <div className="grid gap-6 lg:grid-cols-12">
      {/* BANK & UPI PAYOUT CONFIGURATION */}
      <form onSubmit={savePaymentSettings} className="lg:col-span-5 rounded-2xl border border-slate-200 bg-white p-5 space-y-4">
        <div className="flex items-center gap-2">
          <Landmark size={18} className="text-orange-600" />
          <h2 className="text-base font-black text-slate-950">Bank Account &amp; Direct UPI Settings</h2>
        </div>

        <div className="space-y-3 text-xs">
          <div>
            <label className="block font-bold text-slate-700">Direct Counter UPI ID (VPA)</label>
            <input
              type="text"
              value={upiId}
              onChange={(e) => setUpiId(e.target.value)}
              placeholder="e.g. kitchen@okaxis"
              className="mt-1 w-full rounded-xl border border-slate-300 px-3 py-2 font-mono outline-none focus:border-amber-600"
            />
          </div>
          <div>
            <label className="block font-bold text-slate-700">UPI Display Name</label>
            <input
              type="text"
              value={upiName}
              onChange={(e) => setUpiName(e.target.value)}
              placeholder="Payee Name shown in UPI apps"
              className="mt-1 w-full rounded-xl border border-slate-300 px-3 py-2 outline-none focus:border-amber-600"
            />
          </div>
          <div>
            <label className="block font-bold text-slate-700">UPI QR Image URL (Optional)</label>
            <input
              type="url"
              value={upiQrUrl}
              onChange={(e) => setUpiQrUrl(e.target.value)}
              placeholder="https://..."
              className="mt-1 w-full rounded-xl border border-slate-300 px-3 py-2 outline-none focus:border-amber-600"
            />
          </div>

          <hr className="border-slate-100" />

          <div>
            <label className="block font-bold text-slate-700">Bank Account Holder Name</label>
            <input
              type="text"
              value={accountHolderName}
              onChange={(e) => setAccountHolderName(e.target.value)}
              placeholder="Account holder legal name"
              className="mt-1 w-full rounded-xl border border-slate-300 px-3 py-2 outline-none focus:border-amber-600"
            />
          </div>
          <div>
            <label className="block font-bold text-slate-700">Bank Account Number</label>
            <input
              type="text"
              value={accountNumber}
              onChange={(e) => setAccountNumber(e.target.value)}
              placeholder="Bank account number"
              className="mt-1 w-full rounded-xl border border-slate-300 px-3 py-2 font-mono outline-none focus:border-amber-600"
            />
          </div>
          <div>
            <label className="block font-bold text-slate-700">IFSC Code</label>
            <div className="mt-1 flex gap-2">
              <input
                type="text"
                maxLength={11}
                value={ifscCode}
                onChange={(e) => setIfscCode(e.target.value.toUpperCase())}
                placeholder="e.g. SBIN0001234"
                className="flex-1 rounded-xl border border-slate-300 px-3 py-2 font-mono uppercase outline-none focus:border-amber-600"
              />
              <button
                type="button"
                disabled={ifscVerifying}
                onClick={verifyIfsc}
                className="inline-flex items-center gap-1 rounded-xl border border-slate-300 px-3 py-2 font-bold text-slate-700 hover:bg-slate-50"
              >
                <Search size={13} /> {ifscVerifying ? 'Checking...' : 'Verify IFSC'}
              </button>
            </div>
          </div>
          {(bankName || branchName) && (
            <div className="flex items-start gap-2 rounded-xl border border-emerald-200 bg-emerald-50 p-3 text-emerald-950">
              <CheckCircle2 size={15} className="mt-0.5 shrink-0 text-emerald-700" />
              <div>
                <p className="font-bold">{bankName}</p>
                {branchName && <p className="text-[11px] text-emerald-800">{branchName}</p>}
              </div>
            </div>
          )}
        </div>

        <button
          type="submit"
          disabled={savingSettings}
          className="w-full rounded-xl bg-orange-600 py-2.5 text-xs font-bold text-white hover:bg-orange-700 disabled:bg-slate-400"
        >
          {savingSettings ? 'Saving Payment Settings...' : 'Save Bank & UPI Payout Settings'}
        </button>
      </form>

      {/* SETTLEMENTS LEDGER */}
      <div className="lg:col-span-7 space-y-4">
        <div className="flex flex-wrap items-center justify-between gap-3 rounded-2xl border border-slate-200 bg-white p-5">
          <div className="flex items-center gap-2">
            <Banknote size={18} className="text-orange-600" />
            <h2 className="text-base font-black text-slate-950">Payments &amp; Settlements Ledger</h2>
          </div>
          <div className="text-right">
            <p className="text-[11px] font-bold uppercase text-slate-400">Verified Total</p>
            <p className="text-xl font-black tabular-nums text-emerald-800">{formatInr(totalSettled)}</p>
          </div>
        </div>

        <div className="rounded-2xl border border-slate-200 bg-white overflow-hidden">
          {settlements.length === 0 ? (
            <p className="p-8 text-center text-xs text-slate-500">
              No subscriber payment entries yet. Verified Cashfree &amp; Counter transactions appear here automatically.
            </p>
          ) : (
            <div className="overflow-x-auto">
              <table className="w-full text-left text-xs">
                <thead className="border-b border-slate-200 bg-slate-50 font-bold text-slate-600">
                  <tr>
                    <th className="px-4 py-3">Transaction / Member</th>
                    <th className="px-4 py-3">Plan &amp; Mode</th>
                    <th className="px-4 py-3">Date</th>
                    <th className="px-4 py-3 text-right">Amount</th>
                    <th className="px-4 py-3 text-right">Status</th>
                  </tr>
                </thead>
                <tbody className="divide-y divide-slate-100">
                  {settlements.map((row) => (
                    <tr key={row.id}>
                      <td className="px-4 py-3">
                        <p className="font-bold text-slate-950">{row.customer_name}</p>
                        <p className="font-mono text-[11px] text-slate-500">{row.transaction_id}</p>
                      </td>
                      <td className="px-4 py-3 text-slate-700">
                        <p className="font-semibold">{row.plan_name}</p>
                        <p className="text-[11px] uppercase text-slate-500">{row.payment_mode.replace(/_/g, ' ')}</p>
                      </td>
                      <td className="px-4 py-3 text-slate-500">{formatShortDate(row.paid_at || row.created_at)}</td>
                      <td className="px-4 py-3 text-right font-black tabular-nums text-slate-950">
                        {formatInr(row.amount_inr)}
                      </td>
                      <td className="px-4 py-3 text-right">
                        <span
                          className={`rounded-full px-2 py-0.5 text-[10px] font-bold uppercase ${
                            row.status === 'paid'
                              ? 'bg-emerald-50 text-emerald-800'
                              : row.status === 'pending_payment'
                              ? 'bg-amber-50 text-amber-800'
                              : 'bg-slate-100 text-slate-600'
                          }`}
                        >
                          {row.status}
                        </span>
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          )}
        </div>
      </div>
    </div>
  );
}
