'use client';

import { useCallback, useEffect, useState } from 'react';
import {
  Camera,
  LifeBuoy,
  MailCheck,
  MessageSquare,
  Send,
  Sparkles,
  Star,
  Store,
  Tag,
} from 'lucide-react';
import { ProviderProfileDetails } from './types';

interface ProfileReviewsChatSupportProps {
  mode: 'profile' | 'support';
  providerId: string;
  businessName: string;
  ownerEmail?: string;
  profile: ProviderProfileDetails | null;
  onRefresh: () => Promise<void> | void;
  onNotify: (msg: string, isError?: boolean) => void;
}

export default function PartnerProfileReviewsChatSupportTab({
  mode,
  providerId,
  businessName,
  ownerEmail,
  profile,
  onRefresh,
  onNotify,
}: ProfileReviewsChatSupportProps) {
  // Kitchen Profile Edit state
  const [displayName, setDisplayName] = useState(profile?.display_name || businessName);
  const [description, setDescription] = useState(profile?.description || '');
  const [address, setAddress] = useState(profile?.address_line1 || '');
  const [locality, setLocality] = useState(profile?.locality || '');
  const [city, setCity] = useState(profile?.city || '');
  const [publicPhone, setPublicPhone] = useState(profile?.public_phone || '');
  const [publicEmail, setPublicEmail] = useState(profile?.public_email || '');
  const [supportsPickup, setSupportsPickup] = useState(profile?.supports_pickup !== false);
  const [supportsDelivery, setSupportsDelivery] = useState(profile?.supports_delivery === true);
  const [coverB64, setCoverB64] = useState<string>('');
  const [logoB64, setLogoB64] = useState<string>('');
  const [otpRequested, setOtpRequested] = useState(false);
  const [otpCode, setOtpCode] = useState('');
  const [sendingOtp, setSendingOtp] = useState(false);
  const [savingProfile, setSavingProfile] = useState(false);

  // Reviews + AI Insights
  const [reviews, setReviews] = useState<any[]>([]);
  const [aiSummary, setAiSummary] = useState<string>('');
  const [aiLoading, setAiLoading] = useState(false);
  const [replyDrafts, setReplyDrafts] = useState<Record<string, string>>({});

  // Customer Chat Inbox
  const [conversations, setConversations] = useState<any[]>([]);
  const [activeCustomerId, setActiveCustomerId] = useState<string>('');
  const [chatMessages, setChatMessages] = useState<any[]>([]);
  const [chatInput, setChatInput] = useState('');
  const [sendingChat, setSendingChat] = useState(false);

  // Partner Support Tickets
  const [tickets, setTickets] = useState<any[]>([]);
  const [ticketCategory, setTicketCategory] = useState('Payouts & Settlements');
  const [ticketSubject, setTicketSubject] = useState('');
  const [ticketMessage, setTicketMessage] = useState('');
  const [submittingTicket, setSubmittingTicket] = useState(false);
  const [ticketFollowUp, setTicketFollowUp] = useState<Record<string, string>>({});

  const loadEngagement = useCallback(async () => {
    if (!providerId) return;
    if (mode === 'profile') {
      const revRes = await fetch(`/api/mess/reviews?provider_id=${providerId}`, { cache: 'no-store' })
        .then((r) => r.json())
        .catch(() => ({}));
      setReviews(revRes?.reviews || []);
    } else {
      const [convRes, tickRes] = await Promise.all([
        fetch(`/api/chat/conversations?provider_id=${providerId}`, { cache: 'no-store' })
          .then((r) => r.json())
          .catch(() => ({})),
        fetch('/api/support/ticket', { cache: 'no-store' })
          .then((r) => r.json())
          .catch(() => ({})),
      ]);
      const convList = convRes?.conversations || [];
      setConversations(convList);
      if (convList.length > 0 && !activeCustomerId) {
        setActiveCustomerId(convList[0].customer_id);
      }
      setTickets(tickRes?.tickets || []);
    }
  }, [providerId, mode, activeCustomerId]);

  useEffect(() => {
    void loadEngagement();
  }, [loadEngagement]);

  useEffect(() => {
    if (mode === 'support' && activeCustomerId) {
      fetch(`/api/chat/messages?provider_id=${providerId}&customer_id=${activeCustomerId}`, { cache: 'no-store' })
        .then((r) => r.json())
        .then((d) => setChatMessages(d?.messages || []))
        .catch(() => {});
    }
  }, [mode, providerId, activeCustomerId]);

  function handleFilePick(file: File, setter: (b64: string) => void) {
    const reader = new FileReader();
    reader.onload = () => {
      if (typeof reader.result === 'string') setter(reader.result);
    };
    reader.readAsDataURL(file);
  }

  async function requestProfileOtp() {
    const targetEmail = (publicEmail || ownerEmail || '').trim().toLowerCase();
    if (!targetEmail.includes('@')) {
      onNotify('Enter a valid email address first to receive the confirmation OTP.', true);
      return;
    }
    setSendingOtp(true);
    try {
      const res = await fetch('/api/auth/otp/send', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ identifier: targetEmail, purpose: 'profile_update' }),
      });
      const data = await res.json().catch(() => ({}));
      if (!res.ok || !data.success) {
        onNotify(data.error || 'Could not send OTP.', true);
      } else {
        setOtpRequested(true);
        onNotify(`Verification OTP sent to ${targetEmail}.`);
      }
    } finally {
      setSendingOtp(false);
    }
  }

  async function handleSaveProfile(e: React.FormEvent) {
    e.preventDefault();
    setSavingProfile(true);
    try {
      const res = await fetch('/api/provider/profile', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          provider_id: providerId,
          display_name: displayName.trim(),
          description: description.trim(),
          address_line1: address.trim(),
          locality: locality.trim(),
          city: city.trim(),
          public_phone: publicPhone.trim(),
          public_email: publicEmail.trim(),
          supports_pickup: supportsPickup,
          supports_delivery: supportsDelivery,
          cover_image_base64: coverB64 || undefined,
          logo_image_base64: logoB64 || undefined,
          otp_code: otpCode.trim() || undefined,
          verification_email: (publicEmail || ownerEmail || '').trim(),
        }),
      });
      const data = await res.json().catch(() => ({}));
      if (!res.ok || !data.success) {
        if (data.requires_otp) {
          setOtpRequested(true);
        }
        onNotify(data.error || 'Could not update kitchen profile.', true);
      } else {
        setCoverB64('');
        setLogoB64('');
        setOtpCode('');
        setOtpRequested(false);
        onNotify('Kitchen profile & photos updated and synced across Thali apps!');
        await onRefresh();
      }
    } finally {
      setSavingProfile(false);
    }
  }

  async function generateReviewSummary() {
    setAiLoading(true);
    try {
      const res = await fetch('/api/ai/review-insights', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ provider_id: providerId, mode: 'summary' }),
      });
      const data = await res.json().catch(() => ({}));
      if (res.ok && data.summary) {
        setAiSummary(data.summary);
      } else {
        onNotify(data.error || 'Could not analyze reviews.', true);
      }
    } finally {
      setAiLoading(false);
    }
  }

  async function draftAiReply(review: any) {
    const res = await fetch('/api/ai/review-insights', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        provider_id: providerId,
        mode: 'draft_reply',
        customer_name: review.customer_name,
        rating: review.rating,
        review_text: review.review_text,
      }),
    });
    const data = await res.json().catch(() => ({}));
    if (res.ok && data.reply) {
      setReplyDrafts((prev) => ({ ...prev, [review.id]: data.reply }));
    }
  }

  async function submitReviewReply(reviewId: string) {
    const reply = (replyDrafts[reviewId] || '').trim();
    if (!reply) return;
    const res = await fetch('/api/mess/reviews', {
      method: 'PATCH',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ provider_id: providerId, review_id: reviewId, partner_reply: reply }),
    });
    if (res.ok) {
      onNotify('Reply published on diner review.');
      await loadEngagement();
    } else {
      onNotify('Could not post reply.', true);
    }
  }

  async function sendChat(e: React.FormEvent) {
    e.preventDefault();
    if (!activeCustomerId || !chatInput.trim()) return;
    setSendingChat(true);
    try {
      const res = await fetch('/api/chat/messages', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          provider_id: providerId,
          customer_id: activeCustomerId,
          message: chatInput.trim(),
          sender_name: businessName,
        }),
      });
      const data = await res.json().catch(() => ({}));
      if (res.ok && data.message) {
        setChatMessages((prev) => [...prev, data.message]);
        setChatInput('');
      }
    } finally {
      setSendingChat(false);
    }
  }

  async function submitPartnerTicket(e: React.FormEvent) {
    e.preventDefault();
    if (ticketMessage.trim().length < 5) {
      onNotify('Please enter a short explanation of your issue.', true);
      return;
    }
    setSubmittingTicket(true);
    try {
      const res = await fetch('/api/support/ticket', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          name: businessName,
          email: publicEmail || ownerEmail,
          phone: publicPhone,
          role: 'provider',
          provider_id: providerId,
          category: ticketCategory,
          subject: ticketSubject.trim() || `${ticketCategory} Support`,
          description: ticketMessage.trim(),
        }),
      });
      const data = await res.json().catch(() => ({}));
      if (!res.ok || !data.success) {
        onNotify(data.error || 'Could not submit partner ticket.', true);
      } else {
        setTicketSubject('');
        setTicketMessage('');
        onNotify('Support ticket submitted to Thali Admin Desk.');
        await loadEngagement();
      }
    } finally {
      setSubmittingTicket(false);
    }
  }

  async function replyTicket(ticketId: string) {
    const msg = (ticketFollowUp[ticketId] || '').trim();
    if (!msg) return;
    const res = await fetch('/api/support/ticket', {
      method: 'PATCH',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ ticket_id: ticketId, message: msg }),
    });
    if (res.ok) {
      setTicketFollowUp((prev) => ({ ...prev, [ticketId]: '' }));
      await loadEngagement();
    }
  }

  if (mode === 'profile') {
    return (
      <div className="grid gap-6 lg:grid-cols-12">
        {/* KITCHEN PROFILE + COVER/DP + OTP CONTACT EDIT */}
        <form onSubmit={handleSaveProfile} className="lg:col-span-6 rounded-2xl border border-slate-200 bg-white p-5 space-y-4">
          <div className="flex items-center gap-2">
            <Store size={18} className="text-orange-600" />
            <h2 className="text-base font-black text-slate-950">Kitchen Profile &amp; Storefront Photos</h2>
          </div>

          <div className="grid gap-3 sm:grid-cols-2">
            <div className="rounded-xl border border-slate-200 p-3 text-xs space-y-2">
              <p className="font-bold text-slate-800">Cover Banner</p>
              {(coverB64 || profile?.cover_path) && (
                <img src={coverB64 || profile?.cover_path || ''} alt="Kitchen cover" className="h-24 w-full rounded-lg object-cover" />
              )}
              <label className="inline-flex cursor-pointer items-center gap-1.5 rounded-lg border border-slate-300 px-3 py-1.5 font-bold text-slate-700 hover:bg-slate-50">
                <Camera size={13} /> Change Cover
                <input
                  type="file"
                  accept="image/*"
                  className="hidden"
                  onChange={(e) => e.target.files?.[0] && handleFilePick(e.target.files[0], setCoverB64)}
                />
              </label>
            </div>
            <div className="rounded-xl border border-slate-200 p-3 text-xs space-y-2">
              <p className="font-bold text-slate-800">Kitchen DP / Logo</p>
              {(logoB64 || profile?.logo_path) && (
                <img src={logoB64 || profile?.logo_path || ''} alt="Kitchen logo" className="h-24 w-24 rounded-full object-cover" />
              )}
              <label className="inline-flex cursor-pointer items-center gap-1.5 rounded-lg border border-slate-300 px-3 py-1.5 font-bold text-slate-700 hover:bg-slate-50">
                <Camera size={13} /> Change DP
                <input
                  type="file"
                  accept="image/*"
                  className="hidden"
                  onChange={(e) => e.target.files?.[0] && handleFilePick(e.target.files[0], setLogoB64)}
                />
              </label>
            </div>
          </div>

          <div className="grid gap-3 text-xs sm:grid-cols-2">
            <div className="sm:col-span-2">
              <label className="block font-bold text-slate-700">Kitchen Display Name</label>
              <input type="text" required value={displayName} onChange={(e) => setDisplayName(e.target.value)} className="mt-1 w-full rounded-xl border border-slate-300 px-3 py-2" />
            </div>
            <div className="sm:col-span-2">
              <label className="block font-bold text-slate-700">About &amp; Specialties</label>
              <textarea rows={2} value={description} onChange={(e) => setDescription(e.target.value)} className="mt-1 w-full rounded-xl border border-slate-300 px-3 py-2" />
            </div>
            <div className="sm:col-span-2">
              <label className="block font-bold text-slate-700">Street Address</label>
              <input type="text" value={address} onChange={(e) => setAddress(e.target.value)} className="mt-1 w-full rounded-xl border border-slate-300 px-3 py-2" />
            </div>
            <div>
              <label className="block font-bold text-slate-700">Locality</label>
              <input type="text" value={locality} onChange={(e) => setLocality(e.target.value)} className="mt-1 w-full rounded-xl border border-slate-300 px-3 py-2" />
            </div>
            <div>
              <label className="block font-bold text-slate-700">City</label>
              <input type="text" value={city} onChange={(e) => setCity(e.target.value)} className="mt-1 w-full rounded-xl border border-slate-300 px-3 py-2" />
            </div>
            <div>
              <label className="block font-bold text-slate-700">Public Contact Phone</label>
              <input type="tel" value={publicPhone} onChange={(e) => setPublicPhone(e.target.value)} className="mt-1 w-full rounded-xl border border-slate-300 px-3 py-2 font-mono" />
            </div>
            <div>
              <label className="block font-bold text-slate-700">Public Email</label>
              <input type="email" value={publicEmail} onChange={(e) => setPublicEmail(e.target.value)} className="mt-1 w-full rounded-xl border border-slate-300 px-3 py-2" />
            </div>
          </div>

          {/* Email OTP Confirmation when changing Phone/Email */}
          <div className="rounded-xl border border-amber-200 bg-amber-50/70 p-3.5 text-xs space-y-2">
            <div className="flex flex-wrap items-center justify-between gap-2">
              <span className="font-bold text-amber-950 flex items-center gap-1.5">
                <MailCheck size={14} /> Changing phone or email requires Email OTP verification
              </span>
              <button
                type="button"
                disabled={sendingOtp}
                onClick={requestProfileOtp}
                className="rounded-lg bg-slate-900 px-3 py-1.5 font-bold text-white hover:bg-slate-800"
              >
                {sendingOtp ? 'Sending...' : 'Send Email OTP'}
              </button>
            </div>
            {otpRequested && (
              <input
                type="text"
                maxLength={6}
                value={otpCode}
                onChange={(e) => setOtpCode(e.target.value)}
                placeholder="Enter 6-digit confirmation OTP from email"
                className="w-full rounded-xl border border-amber-300 bg-white px-3 py-2 font-mono"
              />
            )}
          </div>

          <div className="flex flex-wrap gap-4 text-xs font-semibold text-slate-700">
            <label className="inline-flex cursor-pointer items-center gap-2">
              <input type="checkbox" checked={supportsPickup} onChange={(e) => setSupportsPickup(e.target.checked)} className="h-4 w-4 accent-amber-600" />
              Dine-in &amp; Counter Pickup
            </label>
            <label className="inline-flex cursor-pointer items-center gap-2">
              <input type="checkbox" checked={supportsDelivery} onChange={(e) => setSupportsDelivery(e.target.checked)} className="h-4 w-4 accent-amber-600" />
              Self Tiffin Delivery
            </label>
          </div>

          <button
            type="submit"
            disabled={savingProfile}
            className="w-full rounded-xl bg-orange-600 py-2.5 text-xs font-bold text-white hover:bg-orange-700 disabled:bg-slate-400"
          >
            {savingProfile ? 'Saving Profile...' : 'Save Profile Changes'}
          </button>
        </form>

        {/* REVIEWS & AI INSIGHTS */}
        <div className="lg:col-span-6 rounded-2xl border border-slate-200 bg-white p-5 space-y-4">
          <div className="flex flex-wrap items-center justify-between gap-2">
            <div className="flex items-center gap-2">
              <Star size={18} className="text-orange-600" />
              <h2 className="text-base font-black text-slate-950">Diner Reviews &amp; AI Reputation Coach</h2>
            </div>
            <button
              type="button"
              disabled={aiLoading}
              onClick={generateReviewSummary}
              className="inline-flex items-center gap-1 rounded-xl border border-slate-300 px-3 py-1.5 text-xs font-bold text-slate-800 hover:bg-slate-50"
            >
              <Sparkles size={13} className="text-orange-600" /> {aiLoading ? 'Analyzing...' : 'AI Insights'}
            </button>
          </div>

          {aiSummary && (
            <div className="rounded-xl border border-amber-200 bg-amber-50 p-3.5 text-xs text-slate-800">
              {aiSummary}
            </div>
          )}

          {reviews.length === 0 ? (
            <p className="rounded-xl border border-dashed border-slate-200 p-6 text-center text-xs text-slate-500">
              No subscriber reviews submitted yet.
            </p>
          ) : (
            <div className="space-y-3">
              {reviews.map((rev) => (
                <article key={rev.id} className="rounded-xl border border-slate-200 p-4 text-xs space-y-2">
                  <div className="flex items-center justify-between">
                    <span className="font-bold text-slate-950">{rev.customer_name}</span>
                    <span className="rounded-full bg-amber-50 px-2 py-0.5 font-bold text-amber-800">
                      {rev.rating} / 5
                    </span>
                  </div>
                  {rev.review_text && <p className="text-slate-700">{rev.review_text}</p>}
                  {rev.partner_reply ? (
                    <div className="rounded-lg bg-slate-50 p-2.5 text-slate-700">
                      <span className="font-bold">Your Reply:</span> {rev.partner_reply}
                    </div>
                  ) : (
                    <div className="flex flex-wrap gap-2 pt-1">
                      <input
                        type="text"
                        value={replyDrafts[rev.id] || ''}
                        onChange={(e) => setReplyDrafts((prev) => ({ ...prev, [rev.id]: e.target.value }))}
                        placeholder="Write a polite kitchen reply..."
                        className="flex-1 rounded-lg border border-slate-300 px-2.5 py-1.5"
                      />
                      <button
                        type="button"
                        onClick={() => draftAiReply(rev)}
                        className="rounded-lg border border-slate-300 px-2.5 py-1.5 font-bold text-slate-700 hover:bg-slate-50"
                      >
                        AI Draft
                      </button>
                      <button
                        type="button"
                        onClick={() => submitReviewReply(rev.id)}
                        className="rounded-lg bg-slate-900 px-3 py-1.5 font-bold text-white hover:bg-slate-800"
                      >
                        Post Reply
                      </button>
                    </div>
                  )}
                </article>
              ))}
            </div>
          )}
        </div>
      </div>
    );
  }

  // CUSTOMER CHAT INBOX + THALI SUPPORT DESK
  return (
    <div className="grid gap-6 lg:grid-cols-12">
      {/* DINER CHAT INBOX */}
      <div className="lg:col-span-6 rounded-2xl border border-slate-200 bg-white p-5 space-y-4">
        <div className="flex items-center gap-2">
          <MessageSquare size={18} className="text-orange-600" />
          <h2 className="text-base font-black text-slate-950">Customer Chat Inbox</h2>
        </div>

        {conversations.length === 0 ? (
          <p className="rounded-xl border border-dashed border-slate-200 p-8 text-center text-xs text-slate-500">
            No customer messages yet. Diners can chat with your kitchen directly from the mobile app.
          </p>
        ) : (
          <div className="grid gap-3 sm:grid-cols-12">
            <div className="sm:col-span-4 space-y-1.5 border-r border-slate-100 pr-2">
              {conversations.map((c) => (
                <button
                  key={c.customer_id}
                  type="button"
                  onClick={() => setActiveCustomerId(c.customer_id)}
                  className={`w-full rounded-xl p-2.5 text-left text-xs ${
                    activeCustomerId === c.customer_id
                      ? 'bg-amber-50 font-bold text-amber-950'
                      : 'hover:bg-slate-50 text-slate-700'
                  }`}
                >
                  <p className="truncate font-bold">{c.customer_name}</p>
                  <p className="truncate text-[11px] text-slate-500">{c.last_message}</p>
                </button>
              ))}
            </div>
            <div className="sm:col-span-8 flex flex-col justify-between space-y-3">
              <div className="max-h-72 overflow-y-auto space-y-2 rounded-xl border border-slate-100 bg-slate-50 p-3">
                {chatMessages.map((m) => (
                  <div
                    key={m.id}
                    className={`rounded-xl px-3 py-2 text-xs ${
                      m.sender_role === 'provider'
                        ? 'ml-auto max-w-[85%] bg-orange-600 text-white'
                        : 'mr-auto max-w-[85%] bg-white text-slate-900 border border-slate-200'
                    }`}
                  >
                    <p>{m.message}</p>
                  </div>
                ))}
              </div>
              <form onSubmit={sendChat} className="flex gap-2">
                <input
                  type="text"
                  value={chatInput}
                  onChange={(e) => setChatInput(e.target.value)}
                  placeholder="Type reply to customer..."
                  className="flex-1 rounded-xl border border-slate-300 px-3 py-2 text-xs"
                />
                <button
                  type="submit"
                  disabled={sendingChat || !chatInput.trim()}
                  className="rounded-xl bg-slate-900 px-3.5 py-2 text-xs font-bold text-white hover:bg-slate-800"
                >
                  Send
                </button>
              </form>
            </div>
          </div>
        )}
      </div>

      {/* PARTNER SUPPORT TICKETS TO THALI ADMIN */}
      <div className="lg:col-span-6 rounded-2xl border border-slate-200 bg-white p-5 space-y-4">
        <div className="flex items-center gap-2">
          <LifeBuoy size={18} className="text-orange-600" />
          <h2 className="text-base font-black text-slate-950">Thali Partner Support Desk</h2>
        </div>

        <form onSubmit={submitPartnerTicket} className="space-y-3 rounded-xl border border-slate-200 bg-slate-50/70 p-4 text-xs">
          <div className="grid gap-2 sm:grid-cols-2">
            <select
              value={ticketCategory}
              onChange={(e) => setTicketCategory(e.target.value)}
              className="rounded-xl border border-slate-300 bg-white px-3 py-2 font-semibold"
            >
              <option value="Payouts & Settlements">Payouts &amp; Settlements</option>
              <option value="Approval & KYC">Approval &amp; KYC</option>
              <option value="Technical & QR Issue">Technical &amp; QR Issue</option>
              <option value="Subscriber Dispute">Subscriber Dispute</option>
            </select>
            <input
              type="text"
              value={ticketSubject}
              onChange={(e) => setTicketSubject(e.target.value)}
              placeholder="Ticket Subject"
              className="rounded-xl border border-slate-300 bg-white px-3 py-2"
            />
          </div>
          <textarea
            rows={2}
            required
            value={ticketMessage}
            onChange={(e) => setTicketMessage(e.target.value)}
            placeholder="Describe your payout, KYC, or portal request..."
            className="w-full rounded-xl border border-slate-300 bg-white px-3 py-2"
          />
          <button
            type="submit"
            disabled={submittingTicket}
            className="inline-flex items-center gap-1.5 rounded-xl bg-orange-600 px-4 py-2 font-bold text-white hover:bg-orange-700"
          >
            <Send size={13} /> {submittingTicket ? 'Submitting...' : 'Submit Ticket to Admin'}
          </button>
        </form>

        <div className="space-y-3">
          {tickets.length === 0 ? (
            <p className="text-xs text-slate-500">No partner support tickets raised yet.</p>
          ) : (
            tickets.map((t) => (
              <article key={t.id} className="rounded-xl border border-slate-200 p-4 text-xs space-y-2">
                <div className="flex items-center justify-between">
                  <p className="font-bold text-slate-950">{t.subject}</p>
                  <span className="rounded-full bg-slate-100 px-2.5 py-0.5 text-[10px] font-bold uppercase text-slate-700">
                    {t.status.replace(/_/g, ' ')}
                  </span>
                </div>
                <p className="text-slate-600">{t.description}</p>
                {t.promo_code_granted && (
                  <p className="inline-flex items-center gap-1 rounded-lg bg-amber-50 px-2.5 py-1 font-bold text-amber-900">
                    <Tag size={12} /> Credit Code: {t.promo_code_granted}
                  </p>
                )}
                {(t.messages || []).map((m: any) => (
                  <div key={m.id} className="rounded-lg bg-slate-50 px-3 py-2">
                    <span className="font-bold">{m.sender_role === 'admin' ? 'Thali Admin' : 'You'}:</span> {m.message}
                  </div>
                ))}
                {t.status !== 'resolved' && t.status !== 'closed' && (
                  <div className="flex gap-2">
                    <input
                      type="text"
                      value={ticketFollowUp[t.id] || ''}
                      onChange={(e) => setTicketFollowUp((prev) => ({ ...prev, [t.id]: e.target.value }))}
                      placeholder="Reply..."
                      className="flex-1 rounded-lg border border-slate-300 px-2.5 py-1.5"
                    />
                    <button
                      type="button"
                      onClick={() => replyTicket(t.id)}
                      className="rounded-lg bg-slate-900 px-3 py-1.5 font-bold text-white"
                    >
                      Send
                    </button>
                  </div>
                )}
              </article>
            ))
          )}
        </div>
      </div>
    </div>
  );
}
