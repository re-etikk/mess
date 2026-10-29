'use client';

import { FormEvent, useState } from 'react';
import Link from 'next/link';
import { ArrowRight, CheckCircle2, Store } from 'lucide-react';

const fields = [
  { key: 'display_name', label: 'Mess / business name', required: true, maxLength: 120 },
  { key: 'phone', label: 'Contact phone', required: true, maxLength: 20 },
  { key: 'address_line1', label: 'Street address', required: true, maxLength: 200 },
  { key: 'locality', label: 'Area / locality', required: false, maxLength: 120 },
  { key: 'city', label: 'City', required: true, maxLength: 100 },
  { key: 'state', label: 'State', required: true, maxLength: 100 },
  { key: 'pincode', label: 'PIN code', required: true, maxLength: 6 },
] as const;

export default function ProviderPortal() {
  const [values, setValues] = useState<Record<string, string>>({ description: '' });
  const [message, setMessage] = useState('');
  const [error, setError] = useState('');
  const [saving, setSaving] = useState(false);

  async function submit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    setSaving(true);
    setError('');
    setMessage('');
    try {
      const response = await fetch('/api/providers/applications', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(values),
      });
      const result = await response.json();
      if (!response.ok) throw new Error(result.error || 'Application could not be submitted.');
      setMessage(result.message || 'Your kitchen has been registered successfully! Your mess is now active and ready for student subscriptions.');
      setValues({ description: '' });
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Application could not be submitted.');
    } finally {
      setSaving(false);
    }
  }

  return (
    <main className="min-h-[80vh] bg-[#f7f6f2] px-4 py-12 sm:px-6 sm:py-16">
      <div className="mx-auto grid max-w-6xl gap-8 lg:grid-cols-[0.8fr_1.2fr] lg:items-start">
        <section className="pt-2">
          <div className="inline-flex items-center gap-2 rounded-full border border-amber-200 bg-amber-50 px-3 py-1.5 text-xs font-semibold text-amber-900">
            <Store size={15} aria-hidden="true" /> Mess owner onboarding
          </div>
          <h1 className="mt-5 text-4xl font-bold tracking-tight text-slate-950">Bring your real kitchen onto Thali.</h1>
          <p className="mt-4 text-base leading-7 text-slate-600">
            Register your mess / tiffin business details. Once submitted, your kitchen profile, subscription plans, and daily QR scanner become active.
          </p>
          <ul className="mt-6 space-y-3 text-sm text-slate-700">
            <li className="rounded-xl border border-slate-200 bg-white p-4">
              <strong>Real Listings Only:</strong> Only kitchen details you submit appear on the student exploration app.
            </li>
            <li className="rounded-xl border border-slate-200 bg-white p-4">
              <strong>QR Attendance:</strong> Generate your daily signed QR code in the Kitchen Partner app to redeem meals seamlessly.
            </li>
            <li className="rounded-xl border border-slate-200 bg-white p-4">
              <strong>Flexible Subscriptions:</strong> Students can subscribe to monthly unlimited or flexi meal-tracker packs.
            </li>
          </ul>
          <p className="mt-5 text-sm text-slate-600">
            Already registered? <Link href="/auth/login" className="font-semibold text-amber-800 underline underline-offset-4">Sign in</Link>
          </p>
        </section>

        <section className="rounded-2xl border border-slate-200 bg-white p-5 shadow-sm sm:p-7">
          <h2 className="text-xl font-bold text-slate-950">Business application</h2>
          <p className="mt-1 text-sm text-slate-600">Use accurate contact and location details.</p>
          <form onSubmit={submit} className="mt-6 grid gap-4 sm:grid-cols-2">
            {fields.map((field) => (
              <label key={field.key} className={`text-sm font-semibold text-slate-700 ${field.key === 'address_line1' ? 'sm:col-span-2' : ''}`}>
                {field.label}{field.required && <span aria-hidden="true" className="ml-1 text-red-600">*</span>}
                <input
                  required={field.required}
                  maxLength={field.maxLength}
                  inputMode={field.key === 'phone' || field.key === 'pincode' ? 'tel' : undefined}
                  autoComplete={field.key === 'phone' ? 'tel' : undefined}
                  value={values[field.key] ?? ''}
                  onChange={(event) => setValues((current) => ({ ...current, [field.key]: event.target.value }))}
                  className="mt-2 min-h-11 w-full rounded-lg border border-slate-300 bg-white px-3 font-normal text-slate-950 outline-none transition focus:border-amber-600 focus:ring-2 focus:ring-amber-100"
                />
              </label>
            ))}
            <label className="text-sm font-semibold text-slate-700 sm:col-span-2">
              Short description (optional)
              <textarea
                maxLength={1000}
                rows={3}
                value={values.description ?? ''}
                onChange={(event) => setValues((current) => ({ ...current, description: event.target.value }))}
                className="mt-2 w-full rounded-lg border border-slate-300 px-3 py-2 font-normal outline-none focus:border-amber-600 focus:ring-2 focus:ring-amber-100"
              />
            </label>

            {error && (
              <p role="alert" className="rounded-lg border border-red-200 bg-red-50 p-3 text-sm text-red-800 sm:col-span-2">
                {error}
              </p>
            )}

            {message && (
              <div role="status" className="rounded-xl border border-emerald-200 bg-emerald-50 p-4 text-emerald-950 sm:col-span-2">
                <div className="flex items-center gap-2 font-bold text-emerald-900">
                  <CheckCircle2 size={18} className="text-emerald-700" />
                  {message}
                </div>
                <div className="mt-3 flex flex-wrap gap-3 pt-1">
                  <Link
                    href="/auth/login"
                    className="inline-flex items-center gap-1.5 rounded-lg bg-emerald-800 px-4 py-2 text-xs font-semibold text-white shadow-sm hover:bg-emerald-900 transition"
                  >
                    Partner Login &rarr;
                  </Link>
                  <Link
                    href="/"
                    className="inline-flex items-center gap-1.5 rounded-lg border border-emerald-300 bg-white px-4 py-2 text-xs font-semibold text-emerald-900 hover:bg-emerald-100 transition"
                  >
                    View Directory
                  </Link>
                </div>
              </div>
            )}

            <button
              type="submit"
              disabled={saving}
              className="inline-flex min-h-12 items-center justify-center gap-2 rounded-xl bg-slate-950 px-5 text-sm font-bold text-white transition hover:bg-slate-800 focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-amber-600 disabled:cursor-wait disabled:opacity-60 sm:col-span-2"
            >
              {saving ? 'Submitting…' : 'Submit & Register Kitchen'} <ArrowRight size={17} aria-hidden="true" />
            </button>
          </form>
        </section>
      </div>
    </main>
  );
}
