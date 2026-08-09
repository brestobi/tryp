import React, { useState } from 'react';
import { useAdmin } from '../context/AdminContext';
import {
  Megaphone,
  Send,
  Loader2,
  Bell,
  CheckCircle2,
  AlertCircle,
  Users,
  Smartphone,
  ShieldCheck,
  Wrench,
  Tag,
  Car,
  CreditCard,
} from 'lucide-react';
import type { BroadcastType, BroadcastTarget } from '../lib/queries';

const TYPE_META: Record<BroadcastType, { label: string; classes: string; icon: React.ReactNode }> = {
  system: {
    label: 'System',
    classes: 'bg-slate-100 text-slate-950 border-slate-100 shadow-lg shadow-white/10',
    icon: <Wrench className="w-4 h-4" />,
  },
  promo: {
    label: 'Promo',
    classes: 'bg-slate-300 text-slate-950 border-slate-300 shadow-lg shadow-white/10',
    icon: <Tag className="w-4 h-4" />,
  },
  ride: {
    label: 'Ride',
    classes: 'bg-slate-700 text-white border-slate-600 shadow-lg shadow-black/30',
    icon: <Car className="w-4 h-4" />,
  },
  payment: {
    label: 'Payment',
    classes: 'bg-slate-800 text-white border-slate-700 shadow-lg shadow-black/30',
    icon: <CreditCard className="w-4 h-4" />,
  },
};

export const BroadcastComposer: React.FC = () => {
  const { drivers, passengers, broadcastNotification } = useAdmin();

  const [targetRole, setTargetRole] = useState<BroadcastTarget>('all');
  const [type, setType] = useState<BroadcastType>('system');
  const [title, setTitle] = useState('');
  const [body, setBody] = useState('');
  const [routePath, setRoutePath] = useState('');

  const [sending, setSending] = useState(false);
  const [result, setResult] = useState<{ ok: boolean; message: string } | null>(null);

  const audienceCount =
    targetRole === 'passenger' ? passengers.length : targetRole === 'driver' ? drivers.length : drivers.length + passengers.length;

  const audienceLabel =
    targetRole === 'passenger' ? 'Passengers' : targetRole === 'driver' ? 'Drivers' : 'All users';

  const canSend = title.trim().length > 0 && body.trim().length > 0 && !sending;

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!canSend) return;
    setSending(true);
    setResult(null);
    try {
      const count = await broadcastNotification({
        title: title.trim(),
        body: body.trim(),
        type,
        routePath: routePath.trim() || null,
        targetRole,
      });
      setResult({
        ok: true,
        message: `Broadcast delivered to ${count} ${audienceLabel.toLowerCase()}.`,
      });
      setTitle('');
      setBody('');
      setRoutePath('');
    } catch (err) {
      setResult({
        ok: false,
        message: err instanceof Error ? err.message : 'Broadcast failed to send.',
      });
    } finally {
      setSending(false);
    }
  };

  return (
    <div className="space-y-6 animate-in fade-in duration-300">
      {/* Header Banner */}
      <div className="glass-panel p-6 rounded-2xl border border-slate-800 flex flex-col md:flex-row md:items-center justify-between gap-4">
        <div>
          <div className="flex items-center space-x-2 text-xs font-bold uppercase tracking-wider text-pink-400 mb-1 font-mono">
            <Megaphone className="w-4 h-4 text-pink-400" />
            <span>Module 7 Communications</span>
          </div>
          <h1 className="text-2xl font-bold font-heading text-white">Broadcast Notification Center</h1>
          <p className="text-slate-400 text-xs mt-1">
            Compose a single notification and deliver it to every passenger, every driver, or the full TRYP fleet — in-app and push.
          </p>
        </div>

        <div className="flex items-center space-x-2 text-xs px-3 py-1.5 rounded-full bg-slate-900/80 border border-slate-800">
          <Users className="w-3.5 h-3.5 text-pink-400" />
          <span className="text-slate-300 font-medium">
            Fleet Reach: <span className="text-pink-400 font-mono font-bold">{drivers.length + passengers.length}</span> accounts
          </span>
        </div>
      </div>

      <div className="grid grid-cols-1 lg:grid-cols-12 gap-6">
        {/* Composer */}
        <div className="lg:col-span-7 space-y-4">
          <form onSubmit={handleSubmit} className="glass-panel rounded-2xl p-6 border border-slate-800 space-y-5">
            {/* Audience */}
            <div>
              <label className="block text-xs font-semibold text-slate-300 mb-2">Target Audience</label>
              <div className="grid grid-cols-3 gap-2">
                {(
                  [
                    { id: 'all', label: 'All Users', sub: `${drivers.length + passengers.length} accounts` },
                    { id: 'passenger', label: 'Passengers', sub: `${passengers.length} accounts` },
                    { id: 'driver', label: 'Drivers', sub: `${drivers.length} accounts` },
                  ] as { id: BroadcastTarget; label: string; sub: string }[]
                ).map((opt) => (
                  <button
                    key={opt.id}
                    type="button"
                    onClick={() => setTargetRole(opt.id)}
                    className={`p-3 rounded-xl border text-left transition-all ${
                      targetRole === opt.id
                        ? 'bg-pink-600/20 border-pink-500/60 text-white shadow-lg shadow-pink-500/10'
                        : 'bg-slate-900/60 border-slate-800 text-slate-400 hover:border-slate-700'
                    }`}
                  >
                    <div className="text-xs font-bold">{opt.label}</div>
                    <div className="text-[10px] font-mono text-slate-500 mt-0.5">{opt.sub}</div>
                  </button>
                ))}
              </div>
            </div>

            {/* Type */}
            <div>
              <label className="block text-xs font-semibold text-slate-300 mb-2">Notification Type</label>
              <div className="flex flex-wrap gap-2">
                {(Object.keys(TYPE_META) as BroadcastType[]).map((t) => (
                  <button
                    key={t}
                    type="button"
                    onClick={() => setType(t)}
                    className={`px-3 py-1.5 rounded-lg text-xs font-bold border transition-all ${
                      type === t
                        ? TYPE_META[t].classes
                        : 'bg-slate-900/80 text-slate-400 border-slate-800 hover:border-slate-700'
                    }`}
                  >
                    {TYPE_META[t].label}
                  </button>
                ))}
              </div>
            </div>

            {/* Title */}
            <div>
              <div className="flex items-center justify-between mb-2">
                <label className="block text-xs font-semibold text-slate-300">Title</label>
                <span className={`text-[10px] font-mono ${title.length > 80 ? 'text-red-400' : 'text-slate-500'}`}>
                  {title.length}/80
                </span>
              </div>
              <input
                type="text"
                value={title}
                onChange={(e) => setTitle(e.target.value.slice(0, 80))}
                placeholder="e.g. Fare Update: New surge pricing in effect"
                className="w-full px-3 py-2.5 rounded-xl bg-slate-900 border border-slate-800 text-slate-100 text-sm focus:outline-none focus:border-pink-500 transition-colors placeholder-slate-500"
                required
              />
            </div>

            {/* Body */}
            <div>
              <div className="flex items-center justify-between mb-2">
                <label className="block text-xs font-semibold text-slate-300">Message</label>
                <span className={`text-[10px] font-mono ${body.length > 240 ? 'text-red-400' : 'text-slate-500'}`}>
                  {body.length}/240
                </span>
              </div>
              <textarea
                rows={4}
                value={body}
                onChange={(e) => setBody(e.target.value.slice(0, 240))}
                placeholder="Write the message every rider and driver will see..."
                className="w-full px-3 py-2.5 rounded-xl bg-slate-900 border border-slate-800 text-slate-100 text-sm focus:outline-none focus:border-pink-500 transition-colors placeholder-slate-500 resize-none"
                required
              />
            </div>

            {/* Route deep-link */}
            <div>
              <label className="block text-xs font-semibold text-slate-300 mb-2">
                Deep-Link Route <span className="text-slate-500 font-normal">(optional)</span>
              </label>
              <input
                type="text"
                value={routePath}
                onChange={(e) => setRoutePath(e.target.value)}
                placeholder="e.g. /passenger/activity  ·  /passenger/home  ·  /notifications"
                className="w-full px-3 py-2.5 rounded-xl bg-slate-900 border border-slate-800 text-slate-100 text-sm font-mono focus:outline-none focus:border-pink-500 transition-colors placeholder-slate-500"
              />
            </div>

            {result && (
              <div
                className={`p-3 rounded-xl border text-xs flex items-start space-x-2 ${
                  result.ok
                    ? 'bg-emerald-500/10 border-emerald-500/30 text-emerald-300'
                    : 'bg-red-500/10 border-red-500/30 text-red-400'
                }`}
              >
                {result.ok ? (
                  <CheckCircle2 className="w-4 h-4 shrink-0 mt-0.5" />
                ) : (
                  <AlertCircle className="w-4 h-4 shrink-0 mt-0.5" />
                )}
                <span>{result.message}</span>
              </div>
            )}

            <div className="flex items-center justify-between pt-2 border-t border-slate-800">
              <div className="flex items-center space-x-1.5 text-[11px] text-slate-500">
                <ShieldCheck className="w-3.5 h-3.5 text-emerald-400" />
                <span>Action is recorded in the admin audit trail.</span>
              </div>
              <button
                type="submit"
                disabled={!canSend}
                className="px-6 py-2.5 rounded-xl bg-slate-100 text-slate-950 text-xs font-bold shadow-lg shadow-white/10 hover:bg-white transition-all flex items-center space-x-2 disabled:opacity-50 disabled:cursor-not-allowed"
              >
                {sending ? <Loader2 className="w-4 h-4 animate-spin" /> : <Send className="w-4 h-4" />}
                <span>{sending ? 'Broadcasting...' : `Broadcast to ${audienceCount} ${audienceLabel.toLowerCase()}`}</span>
              </button>
            </div>
          </form>
        </div>

        {/* Live Preview */}
        <div className="lg:col-span-5 space-y-4">
          <div className="glass-panel rounded-2xl p-6 border border-slate-800 space-y-5">
            <div className="flex items-center justify-between border-b border-slate-800 pb-3">
              <h3 className="font-heading font-bold text-lg text-white flex items-center space-x-2">
                <Smartphone className="w-5 h-5 text-pink-400" />
                <span>Live Preview</span>
              </h3>
              <span className="text-xs font-mono text-pink-400 font-bold">{TYPE_META[type].label}</span>
            </div>

            {/* Phone-style notification card */}
            <div className="rounded-2xl border border-slate-700/80 bg-gradient-to-br from-slate-900 to-slate-950 p-5">
              <div className="rounded-xl bg-slate-950/90 border border-slate-800 shadow-2xl overflow-hidden">
                <div className="px-4 py-3 flex items-center space-x-3 border-b border-slate-800/60 bg-slate-900/40">
                  <div className="w-7 h-7 rounded-lg bg-slate-100 text-slate-950 flex items-center justify-center">
                    <Bell className="w-4 h-4 text-white" />
                  </div>
                  <div>
                    <div className="text-[10px] text-slate-400 font-medium">TRYP — {audienceLabel}</div>
                    <div className="text-[10px] font-mono text-slate-500">just now</div>
                  </div>
                  <span className="ml-auto text-base">{TYPE_META[type].icon}</span>
                </div>
                <div className="px-4 py-4 space-y-1">
                  <div className="text-sm font-bold text-white leading-snug">
                    {title.trim() || <span className="text-slate-600 italic">Notification title…</span>}
                  </div>
                  <div className="text-xs text-slate-400 leading-relaxed">
                    {body.trim() || <span className="text-slate-600 italic">Your message will appear here.</span>}
                  </div>
                  {routePath.trim() && (
                    <div className="pt-2">
                      <span className="text-[10px] px-2 py-0.5 rounded-full bg-pink-500/10 text-pink-300 border border-pink-500/30 font-mono">
                        → {routePath.trim()}
                      </span>
                    </div>
                  )}
                </div>
              </div>
            </div>

            <div className="p-3 rounded-xl bg-slate-900/80 border border-slate-800 text-[11px] text-slate-400 leading-relaxed">
              Each recipient receives an in-app notification in realtime and a push notification on their device
              (when the push pipeline is configured). Delivery count is returned after broadcast.
            </div>
          </div>
        </div>
      </div>
    </div>
  );
};
