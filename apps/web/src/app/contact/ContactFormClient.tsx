'use client';

import { FormEvent, useState } from 'react';
import { CheckCircle2, Send } from 'lucide-react';

export default function ContactFormClient() {
  const [name, setName] = useState('');
  const [email, setEmail] = useState('');
  const [phone, setPhone] = useState('');
  const [role, setRole] = useState<'customer' | 'provider'>('customer');
  const [category, setCategory] = useState('General Inquiry');
  const [subject, setSubject] = useState('');
  const [message, setMessage] = useState('');
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState('');
  const [ticketId, setTicketId] = useState('');

  async function submit(e: FormEvent) {
    e.preventDefault();
    setError('');
    setTicketId('');
    setBusy(true);
    try {
      const res = await fetch('/api/support/ticket', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          name: name.trim(),
          email: email.trim(),
          phone: phone.trim(),
          role,
          category,
          subject: subject.trim(),
          description: message.trim(),
          message: message.trim(),
        }),
      });
      const json = await res.json();
      if (!res.ok || !json.success) throw new Error(json.error || 'Could not submit ticket.');
      setTicketId(json.ticket_id ? String(json.ticket_id).slice(0, 8) : 'LOGGED');
      setSubject('');
      setMessage('');
    } catch (e) {
      setError(e instanceof Error ? e.message : 'Unable to send support ticket right now.');
    } finally {
      setBusy(false);
    }
  }

  return (
    <form onSubmit={submit} className="mt-8 grid gap-4 rounded-2xl border border-slate-200 bg-white p-6 shadow-sm">
      {ticketId && (
        <div className="flex items-start gap-2 rounded-xl border border-emerald-200 bg-emerald-50 p-4 text-sm text-emerald-900">
          <CheckCircle2 className="mt-0.5 shrink-0" size={18} />
          <div>
            <strong>Ticket Submitted ({ticketId})</strong>
            <p className="text-xs text-emerald-800">Our support team has received your request and will reply shortly.</p>
          </div>
        </div>
      )}
      {error && (
        <div className="rounded-xl border border-red-200 bg-red-50 p-3 text-sm text-red-800">{error}</div>
      )}

      <div className="grid gap-4 sm:grid-cols-2">
        <label className="text-xs font-bold text-slate-700">
          Your Name
          <input required className="mt-1 block w-full rounded-lg border border-slate-300 px-3 py-2 text-sm" value={name} onChange={(e) => setName(e.target.value)} />
        </label>
        <label className="text-xs font-bold text-slate-700">
          Email Address
          <input type="email" required className="mt-1 block w-full rounded-lg border border-slate-300 px-3 py-2 text-sm" value={email} onChange={(e) => setEmail(e.target.value)} />
        </label>
        <label className="text-xs font-bold text-slate-700">
          10-Digit Phone
          <input type="tel" required className="mt-1 block w-full rounded-lg border border-slate-300 px-3 py-2 text-sm" value={phone} onChange={(e) => setPhone(e.target.value)} />
        </label>
        <label className="text-xs font-bold text-slate-700">
          Account Type & Topic
          <div className="mt-1 grid grid-cols-2 gap-2">
            <select className="rounded-lg border border-slate-300 px-2.5 py-2 text-sm" value={role} onChange={(e) => setRole(e.target.value as any)}>
              <option value="customer">Customer</option>
              <option value="provider">Kitchen Partner</option>
            </select>
            <select className="rounded-lg border border-slate-300 px-2.5 py-2 text-sm" value={category} onChange={(e) => setCategory(e.target.value)}>
              <option value="General Inquiry">General</option>
              <option value="Order / Meal Issue">Order / Meal</option>
              <option value="Payment / Refund">Payment / Refund</option>
              <option value="Partner Onboarding">Kitchen Onboarding</option>
            </select>
          </div>
        </label>
      </div>

      <label className="text-xs font-bold text-slate-700">
        Subject
        <input required className="mt-1 block w-full rounded-lg border border-slate-300 px-3 py-2 text-sm" value={subject} onChange={(e) => setSubject(e.target.value)} placeholder="Brief summary of your issue" />
      </label>

      <label className="text-xs font-bold text-slate-700">
        Details
        <textarea required rows={4} className="mt-1 block w-full rounded-lg border border-slate-300 px-3 py-2 text-sm" value={message} onChange={(e) => setMessage(e.target.value)} placeholder="Share order/subscription ID or kitchen details so our team can resolve quickly..." />
      </label>

      <div>
        <button type="submit" disabled={busy} className="inline-flex items-center gap-2 rounded-xl bg-slate-950 px-5 py-2.5 text-sm font-bold text-white hover:bg-slate-800 disabled:opacity-60">
          <Send size={15} /> {busy ? 'Submitting…' : 'Send Support Request'}
        </button>
      </div>
    </form>
  );
}
