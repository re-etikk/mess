'use client';

import { useCallback, useEffect, useState } from 'react';
import { LifeBuoy, MessageSquareReply, Plus, Send, Tag } from 'lucide-react';

interface TicketMessage {
  id: string;
  sender_role: string;
  sender_name: string;
  message: string;
  created_at: string;
}

interface SupportTicket {
  id: string;
  category: string;
  subject: string;
  description: string;
  status: string;
  priority: string;
  resolution_note?: string | null;
  promo_code_granted?: string | null;
  created_at: string;
  messages?: TicketMessage[];
}

export default function CustomerSupportTicketsPanel({
  customerName,
  customerEmail,
}: {
  customerName: string;
  customerEmail?: string;
}) {
  const [tickets, setTickets] = useState<SupportTicket[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');
  const [showNewForm, setShowNewForm] = useState(false);

  const [category, setCategory] = useState('Subscription & Pass');
  const [subject, setSubject] = useState('');
  const [message, setMessage] = useState('');
  const [submitting, setSubmitting] = useState(false);
  const [notice, setNotice] = useState('');

  const [replyDrafts, setReplyDrafts] = useState<Record<string, string>>({});
  const [replyBusyId, setReplyBusyId] = useState<string | null>(null);

  const loadTickets = useCallback(async () => {
    setLoading(true);
    setError('');
    try {
      const res = await fetch('/api/support/ticket', { cache: 'no-store' });
      const data = await res.json().catch(() => ({}));
      if (!res.ok || !data.success) {
        setError(data.error || 'Could not load support tickets.');
      } else {
        setTickets(data.tickets || []);
      }
    } catch {
      setError('Unable to load support tickets right now.');
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    void loadTickets();
  }, [loadTickets]);

  async function handleCreateTicket(e: React.FormEvent) {
    e.preventDefault();
    if (message.trim().length < 5) {
      setError('Please describe your issue in a few words.');
      return;
    }
    setSubmitting(true);
    setError('');
    setNotice('');
    try {
      const res = await fetch('/api/support/ticket', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          name: customerName,
          email: customerEmail,
          role: 'customer',
          category,
          subject: subject.trim() || `${category} Help Request`,
          description: message.trim(),
        }),
      });
      const data = await res.json().catch(() => ({}));
      if (!res.ok || !data.success) {
        setError(data.error || 'Could not submit your help ticket.');
      } else {
        setNotice(`Ticket submitted${data.ticket_id ? ` (#${String(data.ticket_id).slice(0, 8).toUpperCase()})` : ''}.`);
        setSubject('');
        setMessage('');
        setShowNewForm(false);
        await loadTickets();
      }
    } catch {
      setError('Network error submitting ticket.');
    } finally {
      setSubmitting(false);
    }
  }

  async function handleFollowUp(ticketId: string) {
    const draft = (replyDrafts[ticketId] || '').trim();
    if (!draft) return;
    setReplyBusyId(ticketId);
    setError('');
    try {
      const res = await fetch('/api/support/ticket', {
        method: 'PATCH',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ ticket_id: ticketId, message: draft }),
      });
      const data = await res.json().catch(() => ({}));
      if (!res.ok || !data.success) {
        setError(data.error || 'Could not send reply.');
      } else {
        setReplyDrafts((prev) => ({ ...prev, [ticketId]: '' }));
        await loadTickets();
      }
    } catch {
      setError('Network error sending reply.');
    } finally {
      setReplyBusyId(null);
    }
  }

  return (
    <section aria-labelledby="support-tickets-heading" className="mt-8">
      <div className="flex flex-wrap items-center justify-between gap-3">
        <h2 id="support-tickets-heading" className="flex items-center gap-2 text-lg font-extrabold text-slate-950">
          <LifeBuoy size={19} aria-hidden="true" />
          My Support Tickets
        </h2>
        <button
          type="button"
          onClick={() => setShowNewForm((prev) => !prev)}
          className="inline-flex min-h-10 items-center gap-1.5 rounded-xl bg-orange-600 px-3.5 text-xs font-bold text-white hover:bg-orange-700"
        >
          <Plus size={15} />
          {showNewForm ? 'Close Form' : 'New Help Ticket'}
        </button>
      </div>

      {notice && (
        <div className="mt-3 rounded-xl border border-emerald-200 bg-emerald-50 px-4 py-2.5 text-xs font-semibold text-emerald-900">
          {notice}
        </div>
      )}
      {error && (
        <div role="alert" className="mt-3 rounded-xl border border-red-200 bg-red-50 px-4 py-2.5 text-xs font-semibold text-red-700">
          {error}
        </div>
      )}

      {showNewForm && (
        <form onSubmit={handleCreateTicket} className="mt-3 rounded-2xl border border-amber-950/10 bg-white p-5 space-y-3">
          <div className="grid gap-3 sm:grid-cols-2">
            <div>
              <label htmlFor="cust-ticket-cat" className="block text-xs font-bold text-slate-700">
                Issue Category
              </label>
              <select
                id="cust-ticket-cat"
                value={category}
                onChange={(e) => setCategory(e.target.value)}
                className="mt-1 w-full rounded-xl border border-slate-300 bg-white px-3 py-2 text-xs text-slate-900 outline-none focus:border-amber-600"
              >
                <option value="Subscription & Pass">Subscription &amp; Pass</option>
                <option value="Payment & Refund">Payment &amp; Refund</option>
                <option value="Meal Quality & Hygiene">Meal Quality &amp; Hygiene</option>
                <option value="Delivery & Timing">Delivery &amp; Timing</option>
                <option value="Account & General">Account &amp; General</option>
              </select>
            </div>
            <div>
              <label htmlFor="cust-ticket-subj" className="block text-xs font-bold text-slate-700">
                Subject
              </label>
              <input
                id="cust-ticket-subj"
                type="text"
                value={subject}
                onChange={(e) => setSubject(e.target.value)}
                placeholder="Short summary of your issue"
                className="mt-1 w-full rounded-xl border border-slate-300 px-3 py-2 text-xs text-slate-900 outline-none focus:border-amber-600"
              />
            </div>
          </div>
          <div>
            <label htmlFor="cust-ticket-msg" className="block text-xs font-bold text-slate-700">
              Describe what happened
            </label>
            <textarea
              id="cust-ticket-msg"
              rows={3}
              required
              value={message}
              onChange={(e) => setMessage(e.target.value)}
              placeholder="Include kitchen name, date, or transaction ID if relevant..."
              className="mt-1 w-full rounded-xl border border-slate-300 px-3 py-2 text-xs text-slate-900 outline-none focus:border-amber-600"
            />
          </div>
          <button
            type="submit"
            disabled={submitting}
            className="inline-flex min-h-10 items-center gap-1.5 rounded-xl bg-slate-900 px-4 text-xs font-bold text-white hover:bg-slate-800 disabled:bg-slate-400"
          >
            <Send size={14} />
            {submitting ? 'Submitting...' : 'Submit Ticket'}
          </button>
        </form>
      )}

      {loading ? (
        <div className="mt-3 rounded-2xl border border-slate-200 bg-white p-5 text-xs text-slate-500">
          Loading support tickets...
        </div>
      ) : tickets.length === 0 ? (
        <div className="mt-3 rounded-2xl border border-slate-200 bg-white p-5 text-xs text-slate-600">
          No support tickets submitted yet. Need help with an order, refund, or kitchen pass? Open a ticket anytime.
        </div>
      ) : (
        <div className="mt-3 space-y-3">
          {tickets.map((t) => {
            const isClosed = t.status === 'resolved' || t.status === 'closed';
            return (
              <article key={t.id} className="rounded-2xl border border-slate-200 bg-white p-5">
                <div className="flex flex-wrap items-start justify-between gap-2">
                  <div>
                    <p className="text-sm font-bold text-slate-950">{t.subject}</p>
                    <p className="mt-0.5 text-xs text-slate-500">
                      {t.category} · {new Date(t.created_at).toLocaleDateString('en-IN')}
                    </p>
                  </div>
                  <span
                    className={`rounded-full px-2.5 py-0.5 text-[11px] font-bold uppercase ${
                      isClosed
                        ? 'bg-emerald-50 text-emerald-800'
                        : t.status === 'in_progress'
                        ? 'bg-amber-50 text-amber-800'
                        : 'bg-slate-100 text-slate-700'
                    }`}
                  >
                    {t.status.replace(/_/g, ' ')}
                  </span>
                </div>
                <p className="mt-2.5 text-xs text-slate-700 whitespace-pre-wrap">{t.description}</p>

                {t.promo_code_granted && (
                  <div className="mt-3 inline-flex items-center gap-1.5 rounded-lg border border-amber-200 bg-amber-50 px-3 py-1.5 text-xs font-bold text-amber-900">
                    <Tag size={13} />
                    Apology Coupon Granted: <span className="font-mono">{t.promo_code_granted}</span>
                  </div>
                )}

                {t.resolution_note && (
                  <div className="mt-3 rounded-xl border border-emerald-200 bg-emerald-50/70 px-3.5 py-2.5 text-xs text-emerald-950">
                    <span className="font-bold">Resolution Note:</span> {t.resolution_note}
                  </div>
                )}

                {(t.messages || []).length > 0 && (
                  <div className="mt-3 space-y-2 border-t border-slate-100 pt-3">
                    {t.messages!.map((m) => (
                      <div
                        key={m.id}
                        className={`rounded-xl px-3 py-2 text-xs ${
                          m.sender_role === 'admin'
                            ? 'border border-amber-200 bg-amber-50/60 text-slate-900'
                            : 'bg-slate-50 text-slate-700'
                        }`}
                      >
                        <div className="flex items-center justify-between gap-2 font-bold text-[11px] text-slate-500">
                          <span className="flex items-center gap-1">
                            <MessageSquareReply size={12} />
                            {m.sender_role === 'admin' ? `${m.sender_name || 'Thali Support'} (Team)` : 'You'}
                          </span>
                          <time>{new Date(m.created_at).toLocaleString('en-IN')}</time>
                        </div>
                        <p className="mt-1 whitespace-pre-wrap">{m.message}</p>
                      </div>
                    ))}
                  </div>
                )}

                {!isClosed && (
                  <div className="mt-3 flex gap-2 border-t border-slate-100 pt-3">
                    <input
                      type="text"
                      value={replyDrafts[t.id] || ''}
                      onChange={(e) => setReplyDrafts((prev) => ({ ...prev, [t.id]: e.target.value }))}
                      placeholder="Reply to support team..."
                      className="flex-1 rounded-xl border border-slate-300 px-3 py-1.5 text-xs text-slate-900 outline-none focus:border-amber-600"
                    />
                    <button
                      type="button"
                      disabled={replyBusyId === t.id || !(replyDrafts[t.id] || '').trim()}
                      onClick={() => handleFollowUp(t.id)}
                      className="rounded-xl bg-slate-900 px-3.5 py-1.5 text-xs font-bold text-white hover:bg-slate-800 disabled:bg-slate-300"
                    >
                      {replyBusyId === t.id ? 'Sending...' : 'Reply'}
                    </button>
                  </div>
                )}
              </article>
            );
          })}
        </div>
      )}
    </section>
  );
}
