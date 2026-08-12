import React, { useEffect, useState } from 'react';
import { useAdmin } from '../context/AdminContext';
import type { FareSchema } from '../types/admin';
import {
  BadgePercent,
  Save,
  Calculator,
  Sliders,
  Zap,
  Loader2,
} from 'lucide-react';

export const FarePricingEngine: React.FC = () => {
  const { fareSchemas, updateFareSchema, addNotification, can } = useAdmin();
  const canWriteFares = can('fares:write');

  const [selectedSchemaId, setSelectedSchemaId] = useState<string>(fareSchemas[0]?.id || 'schema-go');
  const activeSchema = fareSchemas.find(s => s.id === selectedSchemaId) || fareSchemas[0];

  // Editable state
  const [baseFare, setBaseFare] = useState<number>(activeSchema?.baseFare || 18.0);
  const [perKmRate, setPerKmRate] = useState<number>(activeSchema?.perKmRate || 6.5);
  const [minFare, setMinFare] = useState<number>(activeSchema?.minFare || 25.0);
  const [perMinuteRate, setPerMinuteRate] = useState<number>(activeSchema?.perMinuteRate || 1.2);
  const [extraPersonRate, setExtraPersonRate] = useState<number>(activeSchema?.extraPersonRate || 0);
  const [commissionPercentage, setCommissionPercentage] = useState<number>(activeSchema?.commissionPercentage || 15.0);
  const [surgeMultiplier, setSurgeMultiplier] = useState<number>(activeSchema?.surgeMultiplier || 1.0);

  useEffect(() => {
    if (!activeSchema) return;
    setBaseFare(activeSchema.baseFare);
    setPerKmRate(activeSchema.perKmRate);
    setMinFare(activeSchema.minFare);
    setPerMinuteRate(activeSchema.perMinuteRate);
    setExtraPersonRate(activeSchema.extraPersonRate);
    setCommissionPercentage(activeSchema.commissionPercentage);
    setSurgeMultiplier(activeSchema.surgeMultiplier);
  }, [activeSchema]);

  // Sync state when selected tier changes
  const handleSelectTier = (schema: FareSchema) => {
    setSelectedSchemaId(schema.id);
    setBaseFare(schema.baseFare);
    setPerKmRate(schema.perKmRate);
    setMinFare(schema.minFare);
    setPerMinuteRate(schema.perMinuteRate);
    setExtraPersonRate(schema.extraPersonRate);
    setCommissionPercentage(schema.commissionPercentage);
    setSurgeMultiplier(schema.surgeMultiplier);
  };

  // Sandbox simulation state
  const [simDistance, setSimDistance] = useState<number>(12.5);
  const [simDuration, setSimDuration] = useState<number>(18);
  const [simCompanions, setSimCompanions] = useState<number>(0);

  const calculatedFare = Math.max(
    minFare,
    (baseFare + simDistance * perKmRate + simDuration * perMinuteRate) * surgeMultiplier
  ) + simCompanions * extraPersonRate;
  const platformFee = calculatedFare * (commissionPercentage / 100);
  const driverEarnings = calculatedFare - platformFee;

  const [saving, setSaving] = useState<boolean>(false);

  const handleSave = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!activeSchema || saving) return;
    setSaving(true);
    try {
      await updateFareSchema(activeSchema.id, {
        baseFare,
        perKmRate,
        minFare,
        perMinuteRate,
        extraPersonRate,
        commissionPercentage,
        surgeMultiplier
      });
    } catch (err) {
      addNotification({
        type: 'error',
        title: 'Fare Schema Save Failed',
        message: err instanceof Error ? err.message : 'Failed to save fare schema.',
        timestamp: new Date().toISOString(),
      });
    } finally {
      setSaving(false);
    }
  };

  return (
    <div className="space-y-6 animate-in fade-in duration-300">
      {/* Header Banner */}
      <div className="glass-panel p-6 rounded-2xl border border-slate-800 flex flex-col md:flex-row md:items-center justify-between gap-4">
        <div>
          <div className="flex items-center space-x-2 text-xs font-bold uppercase tracking-wider text-amber-400 mb-1 font-mono">
            <BadgePercent className="w-4 h-4 text-amber-400" />
            <span>Module 3 Operational Control</span>
          </div>
          <h1 className="text-2xl font-bold font-heading text-white">Dynamic Fare & Surge Pricing Engine</h1>
          <p className="text-slate-400 text-xs mt-1">
            Configure base rates, per-kilometer pricing, minimum fares, and real-time peak surge multipliers across vehicle tiers.
          </p>
        </div>
      </div>

      {/* Tier Selector Pills */}
      <div className="grid grid-cols-2 md:grid-cols-4 gap-4">
        {fareSchemas.map(schema => {
          const isSelected = schema.id === selectedSchemaId;
          return (
            <div
              key={schema.id}
              onClick={() => handleSelectTier(schema)}
              className={`p-4 rounded-2xl border cursor-pointer transition-all ${
                isSelected
                  ? 'glass-card border-purple-500/80 shadow-xl shadow-purple-500/10'
                  : 'bg-slate-900/60 border-slate-800/80 hover:border-slate-700'
              }`}
            >
              <div className="flex items-center justify-between">
                <span className="font-heading font-bold text-slate-100 text-base">{schema.tier}</span>
                {schema.surgeMultiplier > 1.0 && (
                  <span className="text-[10px] px-2 py-0.5 rounded-full bg-amber-500/20 text-amber-400 border border-amber-500/30 font-mono font-bold">
                    {schema.surgeMultiplier}x Peak Surge
                  </span>
                )}
              </div>
              <div className="mt-3 text-xs space-y-1 text-slate-400 font-mono">
                <div>Base: R{schema.baseFare.toFixed(2)}</div>
                <div>Per KM: R{schema.perKmRate.toFixed(2)}/km</div>
                <div>Min Fare: R{schema.minFare.toFixed(2)}</div>
                <div>Extra Person: R{schema.extraPersonRate.toFixed(2)}</div>
              </div>
            </div>
          );
        })}
      </div>

      {/* Editor & Sandbox Grid */}
      <div className="grid grid-cols-1 lg:grid-cols-12 gap-6">
        {/* Schema Rates Editor Form (7 cols) */}
        <div className="lg:col-span-7 space-y-4">
          <form onSubmit={handleSave} className="glass-panel rounded-2xl p-6 border border-slate-800 space-y-5">
            <div className="flex items-center justify-between border-b border-slate-800 pb-3">
              <h3 className="font-heading font-bold text-lg text-white flex items-center space-x-2">
                <Sliders className="w-5 h-5 text-purple-400" />
                <span>Edit Rate Schema: {activeSchema.tier}</span>
              </h3>
              <span className="text-xs font-mono text-purple-400">
                Last updated: {new Date(activeSchema.updatedAt).toLocaleDateString()}
              </span>
            </div>

            <div className="grid grid-cols-1 sm:grid-cols-2 gap-4 text-xs">
              {/* Base Fare */}
              <div className="p-3 rounded-xl bg-slate-900/80 border border-slate-800 space-y-1.5">
                <label className="block text-slate-300 font-semibold">Base Pickup Fare (R)</label>
                <input
                  type="number"
                  step="0.50"
                  value={baseFare}
                  onChange={e => setBaseFare(parseFloat(e.target.value) || 0)}
                  className="w-full px-3 py-2 rounded-lg bg-slate-950 border border-slate-800 text-slate-100 font-mono font-bold text-sm focus:border-purple-500 focus:outline-none"
                />
              </div>

              {/* Per KM Rate */}
              <div className="p-3 rounded-xl bg-slate-900/80 border border-slate-800 space-y-1.5">
                <label className="block text-slate-300 font-semibold">Per-Kilometer Distance Rate (R/km)</label>
                <input
                  type="number"
                  step="0.10"
                  value={perKmRate}
                  onChange={e => setPerKmRate(parseFloat(e.target.value) || 0)}
                  className="w-full px-3 py-2 rounded-lg bg-slate-950 border border-slate-800 text-slate-100 font-mono font-bold text-sm focus:border-purple-500 focus:outline-none"
                />
              </div>

              {/* Min Fare */}
              <div className="p-3 rounded-xl bg-slate-900/80 border border-slate-800 space-y-1.5">
                <label className="block text-slate-300 font-semibold">Minimum Trip Threshold (R)</label>
                <input
                  type="number"
                  step="1.00"
                  value={minFare}
                  onChange={e => setMinFare(parseFloat(e.target.value) || 0)}
                  className="w-full px-3 py-2 rounded-lg bg-slate-950 border border-slate-800 text-slate-100 font-mono font-bold text-sm focus:border-purple-500 focus:outline-none"
                />
              </div>

              {/* Per Minute Rate */}
              <div className="p-3 rounded-xl bg-slate-900/80 border border-slate-800 space-y-1.5">
                <label className="block text-slate-300 font-semibold">Per-Minute Time Rate (R/min)</label>
                <input
                  type="number"
                  step="0.10"
                  value={perMinuteRate}
                  onChange={e => setPerMinuteRate(parseFloat(e.target.value) || 0)}
                  className="w-full px-3 py-2 rounded-lg bg-slate-950 border border-slate-800 text-slate-100 font-mono font-bold text-sm focus:border-purple-500 focus:outline-none"
                />
              </div>

              {/* Extra Person Rate */}
              <div className="p-3 rounded-xl bg-slate-900/80 border border-slate-800 space-y-1.5">
                <label className="block text-slate-300 font-semibold">Per Extra Companion (R/person)</label>
                <input
                  type="number"
                  min="0"
                  step="0.50"
                  value={extraPersonRate}
                  onChange={e => setExtraPersonRate(parseFloat(e.target.value) || 0)}
                  className="w-full px-3 py-2 rounded-lg bg-slate-950 border border-slate-800 text-slate-100 font-mono font-bold text-sm focus:border-purple-500 focus:outline-none"
                />
                <p className="text-[10px] text-slate-500">Added once per companion; it does not change the base, start, or kilometre rates.</p>
              </div>

              {/* Commission Percentage */}
              <div className="p-3 rounded-xl bg-slate-900/80 border border-slate-800 space-y-1.5">
                <label className="block text-slate-300 font-semibold">TRYP Platform Fee (%)</label>
                <input
                  type="number"
                  step="0.5"
                  value={commissionPercentage}
                  onChange={e => setCommissionPercentage(parseFloat(e.target.value) || 0)}
                  className="w-full px-3 py-2 rounded-lg bg-slate-950 border border-slate-800 text-slate-100 font-mono font-bold text-sm focus:border-purple-500 focus:outline-none"
                />
              </div>

              {/* Surge Multiplier Slider */}
              <div className="p-3 rounded-xl bg-slate-900/80 border border-slate-800 space-y-1 sm:col-span-2">
                <div className="flex items-center justify-between text-xs">
                  <label className="text-slate-300 font-semibold flex items-center space-x-1">
                    <Zap className="w-3.5 h-3.5 text-amber-400" />
                    <span>Realtime Surge Multiplier Controller</span>
                  </label>
                  <span className="font-mono font-bold text-amber-400 text-sm">{surgeMultiplier.toFixed(2)}x</span>
                </div>
                <input
                  type="range"
                  min="1.0"
                  max="3.0"
                  step="0.05"
                  value={surgeMultiplier}
                  onChange={e => setSurgeMultiplier(parseFloat(e.target.value))}
                  className="w-full accent-amber-500 cursor-pointer"
                />
                <div className="flex justify-between text-[10px] text-slate-500 font-mono">
                  <span>1.0x (Standard)</span>
                  <span>1.5x (Moderate Peak)</span>
                  <span>2.0x (High Surge)</span>
                  <span>3.0x (Max Peak)</span>
                </div>
              </div>
            </div>

            <div className="flex justify-end pt-2">
              <button
                type="submit"
                disabled={!canWriteFares || saving}
                className="px-6 py-2.5 rounded-xl bg-indigo-600 text-white font-bold text-xs shadow-lg shadow-indigo-500/20 hover:bg-indigo-500 transition-all flex items-center space-x-2 disabled:opacity-50 disabled:cursor-not-allowed"
              >
                {saving ? <Loader2 className="w-4 h-4 animate-spin" /> : <Save className="w-4 h-4" />}
                <span>{saving ? 'Saving...' : 'Save Schema Rates to Database'}</span>
              </button>
            </div>
          </form>
        </div>

        {/* Dynamic Sandbox Fare Calculator (5 cols) */}
        <div className="lg:col-span-5 space-y-4">
          <div className="glass-panel rounded-2xl p-6 border border-slate-800 space-y-5">
            <div className="flex items-center justify-between border-b border-slate-800 pb-3">
              <h3 className="font-heading font-bold text-lg text-white flex items-center space-x-2">
                <Calculator className="w-5 h-5 text-emerald-400" />
                <span>Sandbox Price Estimator</span>
              </h3>
              <span className="text-xs font-mono text-emerald-400 font-bold">Simulate Passenger Cost</span>
            </div>

            <div className="space-y-4 text-xs">
              <div>
                <label className="block text-slate-300 font-semibold mb-1">Estimated Distance (Kilometers)</label>
                <input
                  type="number"
                  step="0.5"
                  value={simDistance}
                  onChange={e => setSimDistance(parseFloat(e.target.value) || 0)}
                  className="w-full px-3 py-2 rounded-xl bg-slate-900 border border-slate-800 text-slate-200 font-mono font-bold focus:outline-none focus:border-emerald-500"
                />
              </div>

              <div>
                <label className="block text-slate-300 font-semibold mb-1">Estimated Duration (Minutes)</label>
                <input
                  type="number"
                  step="1"
                  value={simDuration}
                  onChange={e => setSimDuration(parseInt(e.target.value) || 0)}
                  className="w-full px-3 py-2 rounded-xl bg-slate-900 border border-slate-800 text-slate-200 font-mono font-bold focus:outline-none focus:border-emerald-500"
                />
              </div>

              <div>
                <label className="block text-slate-300 font-semibold mb-1">Additional Companions</label>
                <input
                  type="number"
                  min="0"
                  step="1"
                  value={simCompanions}
                  onChange={e => setSimCompanions(Math.max(0, parseInt(e.target.value) || 0))}
                  className="w-full px-3 py-2 rounded-xl bg-slate-900 border border-slate-800 text-slate-200 font-mono font-bold focus:outline-none focus:border-emerald-500"
                />
              </div>

              {/* Calculated Outputs */}
              <div className="p-4 rounded-xl glass-card space-y-3 border border-emerald-500/30">
                <div className="flex justify-between items-center text-xs">
                  <span className="text-slate-400 font-medium">Estimated Passenger Fare</span>
                  <span className="text-xl font-extrabold text-white font-mono">
                    R{calculatedFare.toFixed(2)}
                  </span>
                </div>

                <div className="border-t border-slate-800 pt-2 space-y-1.5 text-[11px]">
                  <div className="flex justify-between text-slate-400">
                    <span>Platform Commission ({commissionPercentage}%):</span>
                    <span className="font-mono text-amber-400">-R{platformFee.toFixed(2)}</span>
                  </div>
                  <div className="flex justify-between text-slate-300 font-bold">
                    <span>Net Driver Earnings:</span>
                    <span className="font-mono text-emerald-400">R{driverEarnings.toFixed(2)}</span>
                  </div>
                </div>
              </div>

              <div className="p-3 rounded-xl bg-slate-900/80 border border-slate-800 text-[11px] text-slate-400 leading-relaxed">
                Changes saved to dynamic fare schemas are published to Supabase instantly. Mobile passenger apps query this schema on route calculation.
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
};
