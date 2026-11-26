'use client';

import React, { useEffect, useRef, useState } from 'react';
import { Phone, Navigation, MapPin, CheckCircle2, Truck, RefreshCw, LogOut, LocateFixed } from 'lucide-react';

interface RiderOrder {
  subscription_id: string;
  customer_id: string;
  customer_name: string;
  customer_phone: string;
  address: string;
  lat: number | null;
  lng: number | null;
  slot: string;
  service_date: string;
  status: string;
  instructions: string;
  packaging_preference: string;
}

export default function RiderPortalPage() {
  const [phone, setPhone] = useState('');
  const [pin, setPin] = useState('');
  const [riderToken, setRiderToken] = useState('');
  const [loggedIn, setLoggedIn] = useState(false);
  const [riderName, setRiderName] = useState('');
  const [providerName, setProviderName] = useState('');
  const [slot, setSlot] = useState<'BREAKFAST' | 'LUNCH' | 'DINNER'>('LUNCH');
  const [orders, setOrders] = useState<RiderOrder[]>([]);
  const [loading, setLoading] = useState(false);
  const [busyId, setBusyId] = useState<string | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [gpsActive, setGpsActive] = useState(false);
  const [lastGpsTime, setLastGpsTime] = useState<string>('');
  const [coords, setCoords] = useState<{ lat: number; lng: number } | null>(null);
  const gpsWatchRef = useRef<number | null>(null);

  useEffect(() => {
    const hr = new Date().getHours();
    const initialSlot: 'BREAKFAST' | 'LUNCH' | 'DINNER' =
      hr < 11 ? 'BREAKFAST' : hr < 16 ? 'LUNCH' : 'DINNER';
    setSlot(initialSlot);

    const urlParams = new URLSearchParams(window.location.search);
    const qPhone = urlParams.get('phone');
    if (qPhone) setPhone(qPhone);

    const savedToken = localStorage.getItem('thali_rider_token');
    if (savedToken) {
      setRiderToken(savedToken);
      loadOrders(savedToken, initialSlot);
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  useEffect(() => {
    return () => {
      if (gpsWatchRef.current !== null && navigator.geolocation) {
        navigator.geolocation.clearWatch(gpsWatchRef.current);
      }
    };
  }, []);

  async function loadOrders(token: string, activeSlot: string) {
    setLoading(true);
    setError(null);
    try {
      const res = await fetch(`/api/rider/orders?slot=${encodeURIComponent(activeSlot)}`, {
        headers: { Authorization: `Bearer ${token}` },
        cache: 'no-store',
      });
      const data = await res.json();
      if (!res.ok || !data.success) {
        if (res.status === 401) {
          localStorage.removeItem('thali_rider_token');
          setRiderToken('');
          setLoggedIn(false);
        }
        throw new Error(data.error || 'Unable to load deliveries.');
      }
      setRiderName(data.rider?.name || 'Delivery Staff');
      setProviderName(data.provider?.display_name || 'Mess Kitchen');
      setOrders(Array.isArray(data.orders) ? data.orders : []);
      setLoggedIn(true);
    } catch (e: any) {
      setError(e?.message || 'Unable to load deliveries.');
      if (!loggedIn) setOrders([]);
    } finally {
      setLoading(false);
    }
  }

  async function handleLogin(e: React.FormEvent) {
    e.preventDefault();
    setLoading(true);
    setError(null);
    try {
      const res = await fetch('/api/rider/orders', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ action: 'login', phone: phone.trim(), pin: pin.trim() }),
      });
      const data = await res.json();
      if (!res.ok || !data.success || !data.rider_token) {
        throw new Error(data.error || 'Invalid mobile number or 4-digit staff PIN.');
      }
      localStorage.setItem('thali_rider_token', data.rider_token);
      setRiderToken(data.rider_token);
      setPin('');
      await loadOrders(data.rider_token, slot);
    } catch (e: any) {
      setError(e?.message || 'Unable to sign in.');
      setLoading(false);
    }
  }

  async function updateOrder(order: RiderOrder, nextStatus: 'out_for_delivery' | 'delivered') {
    setBusyId(order.subscription_id);
    setError(null);
    try {
      const res = await fetch('/api/rider/orders', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          Authorization: `Bearer ${riderToken}`,
        },
        body: JSON.stringify({
          action: 'update_status',
          subscription_id: order.subscription_id,
          customer_id: order.customer_id,
          service_date: order.service_date,
          slot: order.slot,
          status: nextStatus,
          lat: coords?.lat ?? null,
          lng: coords?.lng ?? null,
        }),
      });
      const data = await res.json();
      if (!res.ok || !data.success) throw new Error(data.error || 'Status update failed.');
      await loadOrders(riderToken, slot);
    } catch (e: any) {
      setError(e?.message || 'Could not update status.');
    } finally {
      setBusyId(null);
    }
  }

  function toggleGps() {
    if (gpsActive) {
      if (gpsWatchRef.current !== null && navigator.geolocation) {
        navigator.geolocation.clearWatch(gpsWatchRef.current);
        gpsWatchRef.current = null;
      }
      setGpsActive(false);
      return;
    }

    if (!navigator.geolocation) {
      setError('Location tracking is not supported by this browser.');
      return;
    }

    setGpsActive(true);
    gpsWatchRef.current = navigator.geolocation.watchPosition(
      async (pos) => {
        const lat = pos.coords.latitude;
        const lng = pos.coords.longitude;
        setCoords({ lat, lng });
        setLastGpsTime(new Date().toLocaleTimeString('en-IN', { hour: '2-digit', minute: '2-digit' }));
        try {
          await fetch('/api/rider/orders', {
            method: 'POST',
            headers: {
              'Content-Type': 'application/json',
              Authorization: `Bearer ${riderToken}`,
            },
            body: JSON.stringify({ action: 'location_ping', lat, lng }),
          });
        } catch {}
      },
      (err) => {
        setError(`GPS permission needed: ${err.message}`);
        setGpsActive(false);
      },
      { enableHighAccuracy: true, maximumAge: 15000, timeout: 15000 }
    );
  }

  function logout() {
    localStorage.removeItem('thali_rider_token');
    localStorage.removeItem('thali_rider_auth');
    if (gpsWatchRef.current !== null && navigator.geolocation) {
      navigator.geolocation.clearWatch(gpsWatchRef.current);
    }
    setLoggedIn(false);
    setRiderToken('');
    setOrders([]);
    setPin('');
  }

  if (!loggedIn) {
    return (
      <main className="min-h-screen bg-[#f4f4f6] flex items-center justify-center p-4 font-sans">
        <div className="w-full max-w-sm bg-white rounded-2xl border border-[#e4e4e7] p-6 shadow-sm">
          <div className="inline-flex items-center gap-2 px-3 py-1 rounded-full bg-[#fff3ee] text-[#e95f35] text-xs font-bold mb-3">
            <Truck className="w-3.5 h-3.5" /> Thali Kitchen Delivery
          </div>
          <h1 className="text-xl font-extrabold text-[#18181b]">Rider Staff Login</h1>
          <p className="text-sm text-[#71717b] mt-1">
            Enter your mobile number and 4-digit PIN shared by your kitchen owner.
          </p>

          <form onSubmit={handleLogin} className="mt-5 space-y-4">
            <div>
              <label className="block text-xs font-bold text-[#3f3f46] mb-1">Mobile Number</label>
              <input
                type="tel"
                required
                placeholder="10-digit mobile number"
                value={phone}
                onChange={(e) => setPhone(e.target.value)}
                className="w-full px-3.5 py-2.5 rounded-xl border border-[#e4e4e7] text-sm focus:outline-none focus:border-[#e95f35]"
              />
            </div>
            <div>
              <label className="block text-xs font-bold text-[#3f3f46] mb-1">4-Digit PIN</label>
              <input
                type="password"
                inputMode="numeric"
                maxLength={4}
                required
                placeholder="1234"
                value={pin}
                onChange={(e) => setPin(e.target.value)}
                className="w-full px-3.5 py-2.5 rounded-xl border border-[#e4e4e7] text-sm tracking-widest focus:outline-none focus:border-[#e95f35]"
              />
            </div>

            {error && (
              <div className="rounded-xl bg-[#fee2e2] border border-[#fecaca] px-3 py-2 text-xs font-semibold text-[#b91c1c]">
                {error}
              </div>
            )}

            <button
              type="submit"
              disabled={loading}
              className="w-full bg-[#e95f35] hover:bg-[#d14d24] text-white font-bold text-sm py-3 rounded-xl transition disabled:opacity-60"
            >
              {loading ? 'Signing in...' : 'Open Delivery Route'}
            </button>
          </form>
        </div>
      </main>
    );
  }

  const pendingCount = orders.filter((o) => o.status === 'scheduled' || o.status === 'preparing').length;
  const outCount = orders.filter((o) => o.status === 'out_for_delivery').length;
  const doneCount = orders.filter((o) => o.status === 'delivered').length;

  return (
    <main className="min-h-screen bg-[#f4f4f6] pb-16 font-sans">
      <header className="bg-[#e95f35] text-white px-4 pt-5 pb-4 rounded-b-3xl shadow-sm">
        <div className="max-w-md mx-auto flex items-center justify-between">
          <div>
            <div className="text-xs font-semibold opacity-90">{providerName}</div>
            <h1 className="text-lg font-extrabold">{riderName}</h1>
          </div>
          <div className="flex items-center gap-2">
            <button
              onClick={() => loadOrders(riderToken, slot)}
              className="p-2 rounded-full bg-white/15 hover:bg-white/25"
              title="Refresh"
            >
              <RefreshCw className={`w-4 h-4 ${loading ? 'animate-spin' : ''}`} />
            </button>
            <button onClick={logout} className="p-2 rounded-full bg-white/15 hover:bg-white/25" title="Sign out">
              <LogOut className="w-4 h-4" />
            </button>
          </div>
        </div>

        <div className="max-w-md mx-auto mt-3 flex items-center justify-between bg-white/15 rounded-xl px-3 py-2">
          <div className="flex items-center gap-2 text-xs font-semibold">
            <LocateFixed className="w-4 h-4" />
            <span>
              {gpsActive
                ? `Live GPS Sharing On${lastGpsTime ? ` (${lastGpsTime})` : ''}`
                : 'Turn on GPS so customers & kitchen track you'}
            </span>
          </div>
          <button
            onClick={toggleGps}
            className={`px-3 py-1 rounded-lg text-xs font-bold ${
              gpsActive ? 'bg-white text-[#e95f35]' : 'bg-[#18181b] text-white'
            }`}
          >
            {gpsActive ? 'Stop' : 'Share GPS'}
          </button>
        </div>
      </header>

      <div className="max-w-md mx-auto px-4 mt-4 space-y-3">
        <div className="grid grid-cols-3 gap-2">
          {(['BREAKFAST', 'LUNCH', 'DINNER'] as const).map((s) => (
            <button
              key={s}
              onClick={() => {
                setSlot(s);
                loadOrders(riderToken, s);
              }}
              className={`py-2 rounded-xl text-xs font-bold border transition ${
                slot === s
                  ? 'bg-[#e95f35] text-white border-[#e95f35]'
                  : 'bg-white text-[#52525c] border-[#e4e4e7]'
              }`}
            >
              {s[0] + s.slice(1).toLowerCase()}
            </button>
          ))}
        </div>

        <div className="grid grid-cols-3 gap-2 text-center">
          <div className="bg-white border border-[#e4e4e7] rounded-xl py-2">
            <div className="text-base font-extrabold text-[#18181b]">{pendingCount}</div>
            <div className="text-[11px] font-semibold text-[#71717b]">To Dispatch</div>
          </div>
          <div className="bg-white border border-[#e4e4e7] rounded-xl py-2">
            <div className="text-base font-extrabold text-[#e95f35]">{outCount}</div>
            <div className="text-[11px] font-semibold text-[#71717b]">Out Now</div>
          </div>
          <div className="bg-white border border-[#e4e4e7] rounded-xl py-2">
            <div className="text-base font-extrabold text-[#16a34a]">{doneCount}</div>
            <div className="text-[11px] font-semibold text-[#71717b]">Delivered</div>
          </div>
        </div>

        {error && (
          <div className="rounded-xl bg-[#fee2e2] border border-[#fecaca] px-3 py-2 text-xs font-semibold text-[#b91c1c]">
            {error}
          </div>
        )}

        {orders.length === 0 ? (
          <div className="bg-white border border-[#e4e4e7] rounded-2xl p-8 text-center">
            <p className="text-sm font-bold text-[#18181b]">No home deliveries scheduled for {slot.toLowerCase()}.</p>
            <p className="text-xs text-[#71717b] mt-1">Counter pickup subscribers are handled directly at the mess counter.</p>
          </div>
        ) : (
          orders.map((order) => {
            const busy = busyId === order.subscription_id;
            const mapsQuery =
              order.lat != null && order.lng != null
                ? `${order.lat},${order.lng}`
                : encodeURIComponent(order.address);

            return (
              <div key={order.subscription_id} className="bg-white border border-[#e4e4e7] rounded-2xl p-4 space-y-3">
                <div className="flex items-start justify-between gap-2">
                  <div>
                    <h2 className="text-base font-extrabold text-[#18181b]">{order.customer_name}</h2>
                    <p className="text-xs text-[#71717b] flex items-center gap-1 mt-0.5">
                      <MapPin className="w-3.5 h-3.5 text-[#e95f35]" />
                      <span>{order.address}</span>
                    </p>
                    {order.instructions && (
                      <p className="text-xs font-medium text-[#b45309] bg-[#fffbeb] rounded-lg px-2 py-1 mt-1.5">
                        Note: {order.instructions}
                      </p>
                    )}
                  </div>
                  <span
                    className={`px-2.5 py-1 rounded-full text-[11px] font-bold capitalize ${
                      order.status === 'delivered'
                        ? 'bg-[#dcfce7] text-[#15803d]'
                        : order.status === 'out_for_delivery'
                          ? 'bg-[#fff3ee] text-[#e95f35]'
                          : 'bg-[#f4f4f5] text-[#52525c]'
                    }`}
                  >
                    {order.status.replace(/_/g, ' ')}
                  </span>
                </div>

                <div className="flex items-center gap-2 pt-1">
                  {order.customer_phone && (
                    <a
                      href={`tel:${order.customer_phone}`}
                      className="inline-flex items-center justify-center gap-1.5 px-3 py-2 rounded-xl border border-[#e4e4e7] text-xs font-bold text-[#18181b]"
                    >
                      <Phone className="w-3.5 h-3.5 text-[#e95f35]" /> Call
                    </a>
                  )}
                  <a
                    href={`https://www.google.com/maps/search/?api=1&query=${mapsQuery}`}
                    target="_blank"
                    rel="noreferrer"
                    className="inline-flex items-center justify-center gap-1.5 px-3 py-2 rounded-xl border border-[#e4e4e7] text-xs font-bold text-[#18181b]"
                  >
                    <Navigation className="w-3.5 h-3.5 text-[#e95f35]" /> Map
                  </a>

                  {order.status !== 'delivered' && order.status !== 'out_for_delivery' && (
                    <button
                      disabled={busy}
                      onClick={() => updateOrder(order, 'out_for_delivery')}
                      className="flex-1 bg-[#e95f35] hover:bg-[#d14d24] text-white text-xs font-bold py-2 px-3 rounded-xl inline-flex items-center justify-center gap-1.5"
                    >
                      <Truck className="w-3.5 h-3.5" /> Start Delivery
                    </button>
                  )}
                  {order.status === 'out_for_delivery' && (
                    <button
                      disabled={busy}
                      onClick={() => updateOrder(order, 'delivered')}
                      className="flex-1 bg-[#16a34a] hover:bg-[#15803d] text-white text-xs font-bold py-2 px-3 rounded-xl inline-flex items-center justify-center gap-1.5"
                    >
                      <CheckCircle2 className="w-3.5 h-3.5" /> Mark Delivered
                    </button>
                  )}
                </div>
              </div>
            );
          })
        )}
      </div>
    </main>
  );
}
