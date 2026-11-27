'use client';

import { useState } from 'react';
import { Clock, Edit3, Plus, Sparkles, Trash2, UploadCloud, UtensilsCrossed } from 'lucide-react';
import { MealSlotConfig, MenuDish } from './types';

interface MenuAndTimingsProps {
  providerId: string;
  dishes: MenuDish[];
  mealSlots: MealSlotConfig[];
  operatingHours: Array<{ weekday: number; opens_at?: string | null; closes_at?: string | null; closed: boolean }>;
  onRefresh: () => Promise<void> | void;
  onNotify: (msg: string, isError?: boolean) => void;
}

const DAYS = ['Daily', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
const SLOTS = ['BREAKFAST', 'LUNCH', 'SNACKS', 'DINNER'];
const WEEKDAYS = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];

export default function PartnerMenuAndTimingsTab({
  providerId,
  dishes,
  mealSlots,
  operatingHours,
  onRefresh,
  onNotify,
}: MenuAndTimingsProps) {
  const [selectedDay, setSelectedDay] = useState('Daily');
  const [selectedSlot, setSelectedSlot] = useState('LUNCH');

  // Add / Edit Dish State
  const [dishName, setDishName] = useState('');
  const [dishKind, setDishKind] = useState<'included' | 'addon' | 'special'>('included');
  const [dishPrice, setDishPrice] = useState('30');
  const [dishDietary, setDishDietary] = useState('vegetarian');
  const [savingDish, setSavingDish] = useState(false);

  const [editingId, setEditingId] = useState<string | null>(null);
  const [editName, setEditName] = useState('');
  const [editPrice, setEditPrice] = useState('');

  // Single-Meal Rate for selected slot
  const activeSlotObj = mealSlots.find((s) => s.name.toUpperCase() === selectedSlot);
  const [slotPriceInput, setSlotPriceInput] = useState(
    activeSlotObj?.single_meal_price_inr ? String(activeSlotObj.single_meal_price_inr) : ''
  );
  const [savingRate, setSavingRate] = useState(false);

  // AI Menu Scanner
  const [aiText, setAiText] = useState('');
  const [aiParsing, setAiParsing] = useState(false);
  const [aiResult, setAiResult] = useState<{
    included: string[];
    extras: Array<{ name: string; price: number; kind: 'addon' | 'special' }>;
    dietary_guess?: string;
    estimated_calories?: number;
  } | null>(null);

  // Serving Timings State
  const [slotDrafts, setSlotDrafts] = useState<
    Record<string, { enabled: boolean; start: string; end: string; price: string }>
  >(() => {
    const base: Record<string, { enabled: boolean; start: string; end: string; price: string }> = {
      breakfast: { enabled: true, start: '07:30', end: '10:00', price: '' },
      lunch: { enabled: true, start: '12:00', end: '15:30', price: '' },
      snacks: { enabled: false, start: '16:30', end: '18:30', price: '' },
      dinner: { enabled: true, start: '19:30', end: '22:30', price: '' },
    };
    for (const s of mealSlots) {
      const k = s.name.toLowerCase();
      base[k] = {
        enabled: s.active,
        start: String(s.starts_at_local).slice(0, 5),
        end: String(s.ends_at_local).slice(0, 5),
        price: s.single_meal_price_inr ? String(s.single_meal_price_inr) : '',
      };
    }
    return base;
  });
  const [newCustomSlotName, setNewCustomSlotName] = useState('');
  const [closedWeekdays, setClosedWeekdays] = useState<Record<number, boolean>>(() => {
    const map: Record<number, boolean> = {};
    for (const h of operatingHours) map[h.weekday] = h.closed === true;
    return map;
  });
  const [savingTimings, setSavingTimings] = useState(false);

  const visibleDishes = dishes.filter((d) => {
    const matchSlot = d.slot.toUpperCase() === selectedSlot;
    const matchDay = selectedDay === 'Daily' ? !d.day_of_week || d.day_of_week === 'Daily' : d.day_of_week === selectedDay;
    return matchSlot && matchDay;
  });

  function handleSelectSlot(nextSlot: string) {
    setSelectedSlot(nextSlot);
    const found = mealSlots.find((s) => s.name.toUpperCase() === nextSlot);
    setSlotPriceInput(found?.single_meal_price_inr ? String(found.single_meal_price_inr) : '');
  }

  async function saveSingleMealRate() {
    setSavingRate(true);
    try {
      const numeric = slotPriceInput.trim() === '' ? null : Math.max(0, Number(slotPriceInput));
      const res = await fetch('/api/provider/menu', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          provider_id: providerId,
          action: 'set_slot_price',
          slot: selectedSlot,
          single_meal_price_inr: numeric,
        }),
      });
      const data = await res.json().catch(() => ({}));
      if (!res.ok || !data.success) {
        onNotify(data.error || 'Could not save single-meal rate.', true);
      } else {
        onNotify(`${selectedSlot} single-meal walk-in rate updated.`);
        await onRefresh();
      }
    } catch {
      onNotify('Network error saving single-meal rate.', true);
    } finally {
      setSavingRate(false);
    }
  }

  async function handleAddDish(e: React.FormEvent) {
    e.preventDefault();
    if (!dishName.trim()) return;
    setSavingDish(true);
    try {
      const res = await fetch('/api/provider/menu', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          provider_id: providerId,
          action: 'add_item',
          slot: selectedSlot,
          day_of_week: selectedDay,
          name: dishName.trim(),
          is_extra: dishKind !== 'included',
          item_kind: dishKind,
          price: dishKind === 'included' ? 0 : Math.max(0, Number(dishPrice) || 0),
          dietary_type: dishDietary,
        }),
      });
      const data = await res.json().catch(() => ({}));
      if (!res.ok || !data.success) {
        onNotify(data.error || 'Could not add dish.', true);
      } else {
        setDishName('');
        onNotify(`Added dish to ${selectedSlot} (${selectedDay}).`);
        await onRefresh();
      }
    } catch {
      onNotify('Network error adding dish.', true);
    } finally {
      setSavingDish(false);
    }
  }

  async function toggleDishAvailability(dish: MenuDish) {
    const res = await fetch('/api/provider/menu', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        provider_id: providerId,
        action: 'toggle_availability',
        item_id: dish.id,
        item_name: dish.name,
        slot: dish.slot,
        day_of_week: dish.day_of_week || 'Daily',
        is_available: !dish.active,
      }),
    });
    if (res.ok) {
      await onRefresh();
    } else {
      onNotify('Could not toggle dish availability.', true);
    }
  }

  async function saveDishEdit(dish: MenuDish) {
    if (!editName.trim()) return;
    const res = await fetch('/api/provider/menu', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        provider_id: providerId,
        action: 'update_item',
        item_id: dish.id,
        item_name: editName.trim(),
        price: Math.max(0, Number(editPrice) || 0),
      }),
    });
    const data = await res.json().catch(() => ({}));
    if (res.ok && data.success) {
      setEditingId(null);
      onNotify('Dish updated.');
      await onRefresh();
    } else {
      onNotify(data.error || 'Could not update dish.', true);
    }
  }

  async function removeDish(dish: MenuDish) {
    const res = await fetch('/api/provider/menu', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        provider_id: providerId,
        action: 'remove_item',
        item_id: dish.id,
        item_name: dish.name,
        slot: dish.slot,
        day_of_week: dish.day_of_week || 'Daily',
      }),
    });
    if (res.ok) {
      onNotify(`Removed ${dish.name}.`);
      await onRefresh();
    } else {
      onNotify('Could not remove dish.', true);
    }
  }

  async function runAiScan(imageBase64?: string) {
    if (!aiText.trim() && !imageBase64) {
      onNotify('Paste menu text or choose a menu board photo first.', true);
      return;
    }
    setAiParsing(true);
    try {
      const res = await fetch('/api/ai/parse-menu', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          provider_id: providerId,
          slot: selectedSlot,
          text_input: aiText.trim() || undefined,
          image_base64: imageBase64 || undefined,
        }),
      });
      const data = await res.json().catch(() => ({}));
      if (!res.ok || !data.success) {
        onNotify(data.error || 'Could not parse menu.', true);
      } else {
        setAiResult({
          included: data.included || [],
          extras: data.extras || [],
          dietary_guess: data.dietary_guess,
          estimated_calories: data.estimated_calories,
        });
        onNotify('Menu digitized by Thali AI. Review and click Import.');
      }
    } catch {
      onNotify('Network error scanning menu.', true);
    } finally {
      setAiParsing(false);
    }
  }

  async function importAiMenu() {
    if (!aiResult) return;
    setAiParsing(true);
    try {
      const dietary = aiResult.dietary_guess === 'non_veg' ? 'non_vegetarian' : aiResult.dietary_guess === 'jain' ? 'jain' : 'vegetarian';
      for (const name of aiResult.included) {
        await fetch('/api/provider/menu', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({
            provider_id: providerId,
            action: 'add_item',
            slot: selectedSlot,
            day_of_week: selectedDay,
            name,
            is_extra: false,
            item_kind: 'included',
            dietary_type: dietary,
          }),
        });
      }
      for (const extra of aiResult.extras) {
        await fetch('/api/provider/menu', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({
            provider_id: providerId,
            action: 'add_item',
            slot: selectedSlot,
            day_of_week: selectedDay,
            name: extra.name,
            is_extra: true,
            item_kind: extra.kind === 'special' ? 'special' : 'addon',
            price: Number(extra.price || 30),
            dietary_type: dietary,
          }),
        });
      }
      setAiResult(null);
      setAiText('');
      onNotify(`Imported scanned dishes into ${selectedSlot} (${selectedDay}).`);
      await onRefresh();
    } finally {
      setAiParsing(false);
    }
  }

  async function saveAllTimings() {
    setSavingTimings(true);
    try {
      const slotsPayload = Object.entries(slotDrafts).flatMap(([name, cfg]) => {
        if (cfg.end <= cfg.start && cfg.enabled) {
          throw new Error(`End time must be after start time for ${name}.`);
        }
        return [
          {
            name,
            starts_at_local: `${cfg.start}:00`,
            ends_at_local: `${cfg.end}:00`,
            active: cfg.enabled,
            single_meal_price_inr: cfg.price.trim() ? Number(cfg.price) : null,
          },
        ];
      });
      const opHoursPayload = WEEKDAYS.map((_, idx) => ({
        weekday: idx,
        opens_at: '07:00:00',
        closes_at: '22:30:00',
        closed: closedWeekdays[idx] === true,
      }));
      const res = await fetch('/api/provider/timings', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          provider_id: providerId,
          slots: slotsPayload,
          operating_hours: opHoursPayload,
          replace_slots: false,
        }),
      });
      const data = await res.json().catch(() => ({}));
      if (!res.ok || !data.success) {
        onNotify(data.error || 'Could not save meal timings.', true);
      } else {
        onNotify('Meal timings, single rates, and weekly open days saved.');
        await onRefresh();
      }
    } catch (err: any) {
      onNotify(err?.message || 'Error saving meal timings.', true);
    } finally {
      setSavingTimings(false);
    }
  }

  return (
    <div className="space-y-6">
      {/* 7-DAY + SLOT MENU BUILDER */}
      <section className="rounded-2xl border border-slate-200 bg-white p-5 space-y-5">
        <div className="flex flex-wrap items-center justify-between gap-3">
          <div className="flex items-center gap-2">
            <UtensilsCrossed size={18} className="text-orange-600" />
            <h2 className="text-base font-black text-slate-950">7-Day Menu &amp; Single-Meal Rate</h2>
          </div>

          <div className="flex items-center gap-2">
            <label className="text-xs font-bold text-slate-600">{selectedSlot} Single Rate:</label>
            <input
              type="number"
              min={0}
              value={slotPriceInput}
              onChange={(e) => setSlotPriceInput(e.target.value)}
              placeholder="₹/meal"
              className="w-24 rounded-xl border border-slate-300 px-3 py-1.5 text-xs font-bold tabular-nums"
            />
            <button
              type="button"
              disabled={savingRate}
              onClick={saveSingleMealRate}
              className="rounded-xl bg-slate-900 px-3 py-1.5 text-xs font-bold text-white hover:bg-slate-800 disabled:bg-slate-400"
            >
              {savingRate ? 'Saving...' : 'Save Rate'}
            </button>
          </div>
        </div>

        {/* Day Pills */}
        <div className="flex gap-1.5 overflow-x-auto pb-1">
          {DAYS.map((day) => (
            <button
              key={day}
              type="button"
              onClick={() => setSelectedDay(day)}
              className={`shrink-0 rounded-xl px-3 py-1.5 text-xs font-bold transition ${
                selectedDay === day
                  ? 'bg-orange-600 text-white'
                  : 'border border-slate-200 text-slate-600 hover:bg-slate-50'
              }`}
            >
              {day}
            </button>
          ))}
        </div>

        {/* Slot Tabs incl. SNACKS */}
        <div className="grid grid-cols-4 gap-2">
          {SLOTS.map((slot) => (
            <button
              key={slot}
              type="button"
              onClick={() => handleSelectSlot(slot)}
              className={`rounded-xl py-2 text-xs font-bold transition ${
                selectedSlot === slot
                  ? 'border border-amber-600 bg-amber-50 text-amber-950'
                  : 'border border-slate-200 text-slate-600 hover:bg-slate-50'
              }`}
            >
              {slot.slice(0, 1) + slot.slice(1).toLowerCase()}
            </button>
          ))}
        </div>

        {/* Add Dish Form */}
        <form onSubmit={handleAddDish} className="grid gap-2.5 rounded-xl border border-slate-200 bg-slate-50/70 p-3.5 sm:grid-cols-12">
          <input
            type="text"
            required
            value={dishName}
            onChange={(e) => setDishName(e.target.value)}
            placeholder={`Add dish to ${selectedSlot} (${selectedDay})...`}
            className="sm:col-span-5 rounded-xl border border-slate-300 bg-white px-3 py-2 text-xs outline-none focus:border-amber-600"
          />
          <select
            value={dishKind}
            onChange={(e) => setDishKind(e.target.value as 'included' | 'addon' | 'special')}
            className="sm:col-span-2 rounded-xl border border-slate-300 bg-white px-2.5 py-2 text-xs font-semibold"
          >
            <option value="included">Thali Included</option>
            <option value="addon">Paid Add-on</option>
            <option value="special">Chef Special</option>
          </select>
          <input
            type="number"
            min={0}
            disabled={dishKind === 'included'}
            value={dishKind === 'included' ? '0' : dishPrice}
            onChange={(e) => setDishPrice(e.target.value)}
            placeholder="₹ Price"
            className="sm:col-span-2 rounded-xl border border-slate-300 bg-white px-3 py-2 text-xs disabled:bg-slate-100"
          />
          <select
            value={dishDietary}
            onChange={(e) => setDishDietary(e.target.value)}
            className="sm:col-span-2 rounded-xl border border-slate-300 bg-white px-2.5 py-2 text-xs font-semibold"
          >
            <option value="vegetarian">Veg</option>
            <option value="non_vegetarian">Non-Veg</option>
            <option value="jain">Jain</option>
          </select>
          <button
            type="submit"
            disabled={savingDish}
            className="sm:col-span-1 inline-flex items-center justify-center gap-1 rounded-xl bg-orange-600 px-3 py-2 text-xs font-bold text-white hover:bg-orange-700"
          >
            <Plus size={14} /> Add
          </button>
        </form>

        {/* Dish List */}
        {visibleDishes.length === 0 ? (
          <p className="rounded-xl border border-dashed border-slate-200 p-6 text-center text-xs text-slate-500">
            No dishes listed yet for {selectedDay} · {selectedSlot}. Add a dish above or scan your printed menu below.
          </p>
        ) : (
          <ul className="divide-y divide-slate-100 rounded-xl border border-slate-200">
            {visibleDishes.map((d) => {
              const isEditing = editingId === (d.id || d.name);
              return (
                <li key={d.id || d.name} className="flex flex-wrap items-center justify-between gap-3 px-4 py-3 text-xs">
                  {isEditing ? (
                    <div className="flex flex-1 flex-wrap items-center gap-2">
                      <input
                        type="text"
                        value={editName}
                        onChange={(e) => setEditName(e.target.value)}
                        className="flex-1 rounded-lg border border-slate-300 px-2.5 py-1.5 text-xs"
                      />
                      <input
                        type="number"
                        min={0}
                        value={editPrice}
                        onChange={(e) => setEditPrice(e.target.value)}
                        className="w-20 rounded-lg border border-slate-300 px-2.5 py-1.5 text-xs"
                      />
                      <button
                        type="button"
                        onClick={() => saveDishEdit(d)}
                        className="rounded-lg bg-slate-900 px-3 py-1.5 text-xs font-bold text-white"
                      >
                        Save
                      </button>
                      <button
                        type="button"
                        onClick={() => setEditingId(null)}
                        className="rounded-lg border border-slate-300 px-2.5 py-1.5 text-xs font-bold text-slate-600"
                      >
                        Cancel
                      </button>
                    </div>
                  ) : (
                    <>
                      <div>
                        <p className="font-bold text-slate-950">
                          {d.name}
                          {d.is_add_on && d.price_inr > 0 ? (
                            <span className="ml-2 text-orange-700">+₹{d.price_inr}</span>
                          ) : (
                            <span className="ml-2 text-emerald-700">Included</span>
                          )}
                        </p>
                        <p className="mt-0.5 text-[11px] text-slate-500 capitalize">
                          {d.item_kind || (d.is_add_on ? 'addon' : 'included')} · {d.dietary_type || 'veg'}
                        </p>
                      </div>
                      <div className="flex items-center gap-2">
                        <button
                          type="button"
                          onClick={() => toggleDishAvailability(d)}
                          className={`rounded-lg px-2.5 py-1 font-bold ${
                            d.active ? 'bg-emerald-50 text-emerald-800' : 'bg-slate-100 text-slate-500'
                          }`}
                        >
                          {d.active ? 'In Stock' : 'Paused'}
                        </button>
                        <button
                          type="button"
                          onClick={() => {
                            setEditingId(d.id || d.name);
                            setEditName(d.name);
                            setEditPrice(String(d.price_inr || 0));
                          }}
                          className="rounded-lg border border-slate-200 p-1.5 text-slate-600 hover:bg-slate-50"
                          title="Edit dish"
                        >
                          <Edit3 size={13} />
                        </button>
                        <button
                          type="button"
                          onClick={() => removeDish(d)}
                          className="rounded-lg border border-red-200 p-1.5 text-red-600 hover:bg-red-50"
                          title="Delete dish"
                        >
                          <Trash2 size={13} />
                        </button>
                      </div>
                    </>
                  )}
                </li>
              );
            })}
          </ul>
        )}
      </section>

      {/* AI MENU SCANNER */}
      <section className="rounded-2xl border border-slate-200 bg-white p-5 space-y-3">
        <div className="flex flex-wrap items-center justify-between gap-2">
          <div className="flex items-center gap-2">
            <Sparkles size={18} className="text-orange-600" />
            <h2 className="text-base font-black text-slate-950">AI Menu Board Digitizer</h2>
          </div>
          <label className="inline-flex cursor-pointer items-center gap-1.5 rounded-xl border border-slate-300 px-3 py-1.5 text-xs font-bold text-slate-700 hover:bg-slate-50">
            <UploadCloud size={14} /> Upload Menu Photo
            <input
              type="file"
              accept="image/*"
              className="hidden"
              onChange={(e) => {
                const file = e.target.files?.[0];
                if (!file) return;
                const reader = new FileReader();
                reader.onload = () => {
                  if (typeof reader.result === 'string') void runAiScan(reader.result);
                };
                reader.readAsDataURL(file);
              }}
            />
          </label>
        </div>
        <div className="flex flex-col gap-2 sm:flex-row">
          <input
            type="text"
            value={aiText}
            onChange={(e) => setAiText(e.target.value)}
            placeholder="Paste Hinglish/English menu line: Dal Makhani, 4 Butter Roti, Jeera Rice, Extra Paneer ₹45..."
            className="flex-1 rounded-xl border border-slate-300 px-3 py-2 text-xs outline-none focus:border-amber-600"
          />
          <button
            type="button"
            disabled={aiParsing}
            onClick={() => runAiScan()}
            className="rounded-xl bg-slate-900 px-4 py-2 text-xs font-bold text-white hover:bg-slate-800 disabled:bg-slate-400"
          >
            {aiParsing ? 'Digitizing...' : 'Scan Text'}
          </button>
        </div>

        {aiResult && (
          <div className="rounded-xl border border-amber-200 bg-amber-50/70 p-4 space-y-2 text-xs">
            <p className="font-bold text-slate-900">
              Parsed for {selectedSlot} ({aiResult.dietary_guess || 'veg'}
              {aiResult.estimated_calories ? ` · ~${aiResult.estimated_calories} kcal` : ''})
            </p>
            <p className="text-slate-700">
              <strong>Included:</strong> {aiResult.included.join(', ') || 'None'}
            </p>
            {aiResult.extras.length > 0 && (
              <p className="text-slate-700">
                <strong>Add-ons:</strong> {aiResult.extras.map((x) => `${x.name} (₹${x.price})`).join(', ')}
              </p>
            )}
            <button
              type="button"
              disabled={aiParsing}
              onClick={importAiMenu}
              className="mt-2 rounded-xl bg-orange-600 px-4 py-2 text-xs font-bold text-white hover:bg-orange-700"
            >
              Import All Into {selectedSlot} ({selectedDay})
            </button>
          </div>
        )}
      </section>

      {/* MEAL TIMINGS & WEEKLY OPERATING HOURS */}
      <section className="rounded-2xl border border-slate-200 bg-white p-5 space-y-4">
        <div className="flex flex-wrap items-center justify-between gap-3">
          <div className="flex items-center gap-2">
            <Clock size={18} className="text-orange-600" />
            <h2 className="text-base font-black text-slate-950">Serving Windows &amp; Weekly Off Days</h2>
          </div>
          <button
            type="button"
            disabled={savingTimings}
            onClick={saveAllTimings}
            className="rounded-xl bg-orange-600 px-4 py-2 text-xs font-bold text-white hover:bg-orange-700 disabled:bg-slate-400"
          >
            {savingTimings ? 'Saving Timings...' : 'Save Timings & Days'}
          </button>
        </div>

        <div className="space-y-2.5">
          {Object.entries(slotDrafts).map(([name, cfg]) => (
            <div key={name} className="grid items-center gap-3 rounded-xl border border-slate-200 p-3 sm:grid-cols-12">
              <label className="flex items-center gap-2 text-xs font-bold capitalize text-slate-900 sm:col-span-3 cursor-pointer">
                <input
                  type="checkbox"
                  checked={cfg.enabled}
                  onChange={(e) =>
                    setSlotDrafts((prev) => ({ ...prev, [name]: { ...prev[name], enabled: e.target.checked } }))
                  }
                  className="h-4 w-4 accent-amber-600"
                />
                {name}
              </label>
              <div className="flex items-center gap-2 sm:col-span-5">
                <input
                  type="time"
                  value={cfg.start}
                  onChange={(e) =>
                    setSlotDrafts((prev) => ({ ...prev, [name]: { ...prev[name], start: e.target.value } }))
                  }
                  className="w-full rounded-lg border border-slate-300 px-2.5 py-1.5 text-xs"
                />
                <span className="text-xs text-slate-400">to</span>
                <input
                  type="time"
                  value={cfg.end}
                  onChange={(e) =>
                    setSlotDrafts((prev) => ({ ...prev, [name]: { ...prev[name], end: e.target.value } }))
                  }
                  className="w-full rounded-lg border border-slate-300 px-2.5 py-1.5 text-xs"
                />
              </div>
              <div className="sm:col-span-4">
                <input
                  type="number"
                  min={0}
                  value={cfg.price}
                  onChange={(e) =>
                    setSlotDrafts((prev) => ({ ...prev, [name]: { ...prev[name], price: e.target.value } }))
                  }
                  placeholder="Single meal ₹ (optional)"
                  className="w-full rounded-lg border border-slate-300 px-2.5 py-1.5 text-xs"
                />
              </div>
            </div>
          ))}
        </div>

        <div className="flex flex-wrap items-center gap-2 pt-1">
          <input
            type="text"
            value={newCustomSlotName}
            onChange={(e) => setNewCustomSlotName(e.target.value)}
            placeholder="Custom slot name (e.g. brunch, midnight)"
            className="rounded-xl border border-slate-300 px-3 py-1.5 text-xs"
          />
          <button
            type="button"
            onClick={() => {
              const key = newCustomSlotName.trim().toLowerCase();
              if (!key) return;
              setSlotDrafts((prev) => ({
                ...prev,
                [key]: prev[key] || { enabled: true, start: '11:00', end: '12:00', price: '' },
              }));
              setNewCustomSlotName('');
            }}
            className="rounded-xl border border-slate-300 px-3 py-1.5 text-xs font-bold text-slate-700 hover:bg-slate-50"
          >
            + Add Custom Slot
          </button>
        </div>

        <div className="border-t border-slate-100 pt-3">
          <p className="text-xs font-bold text-slate-700">Weekly Closed Days (Check days kitchen stays closed)</p>
          <div className="mt-2 flex flex-wrap gap-2">
            {WEEKDAYS.map((dayLabel, idx) => (
              <label
                key={dayLabel}
                className={`inline-flex cursor-pointer items-center gap-1.5 rounded-lg border px-2.5 py-1 text-xs font-semibold ${
                  closedWeekdays[idx] ? 'border-red-200 bg-red-50 text-red-700' : 'border-slate-200 text-slate-700'
                }`}
              >
                <input
                  type="checkbox"
                  checked={closedWeekdays[idx] === true}
                  onChange={(e) => setClosedWeekdays((prev) => ({ ...prev, [idx]: e.target.checked }))}
                  className="h-3.5 w-3.5 accent-red-600"
                />
                {dayLabel} Off
              </label>
            ))}
          </div>
        </div>
      </section>
    </div>
  );
}
