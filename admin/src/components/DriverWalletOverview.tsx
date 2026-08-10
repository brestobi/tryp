import React from 'react';
import { Activity, Banknote, RefreshCw, ShieldCheck } from 'lucide-react';
import { useAdmin } from '../context/AdminContext';

export const DriverWalletOverview: React.FC = () => {
  const { driverWallets } = useAdmin();
  const cashTotal = driverWallets.reduce((sum, wallet) => sum + wallet.cashCollected, 0);
  const onlineTotal = driverWallets.reduce((sum, wallet) => sum + wallet.onlineHeld, 0);
  const feesTotal = driverWallets.reduce((sum, wallet) => sum + wallet.cashPlatformFeeOwed, 0);

  return (
    <div className="space-y-5 animate-in fade-in duration-300">
      <div className="glass-panel p-6 rounded-2xl border border-slate-800 flex items-start justify-between gap-4">
        <div>
          <div className="flex items-center gap-2 text-xs font-bold uppercase tracking-wider text-emerald-400 font-mono">
            <Activity className="w-4 h-4" />
            <span>Realtime Wallet Ledger</span>
          </div>
          <h1 className="text-2xl font-bold font-heading text-white mt-1">Driver Balances</h1>
          <p className="text-slate-400 text-xs mt-1">
            Server-settled balances from completed rides. Online funds are held by TRYP until payout.
          </p>
        </div>
        <span className="inline-flex items-center gap-1.5 px-3 py-1.5 rounded-full bg-emerald-500/10 border border-emerald-500/30 text-emerald-300 text-[10px] font-mono font-bold">
          <span className="w-1.5 h-1.5 rounded-full bg-emerald-400 animate-pulse" /> LIVE
        </span>
      </div>

      <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
        <Metric icon={<Banknote className="w-4 h-4" />} label="Cash with drivers" value={cashTotal} tone="text-amber-400" />
        <Metric icon={<ShieldCheck className="w-4 h-4" />} label="Online held by TRYP" value={onlineTotal} tone="text-emerald-400" />
        <Metric icon={<RefreshCw className="w-4 h-4" />} label="Cash fees owed" value={feesTotal} tone="text-cyan-400" />
      </div>

      <div className="glass-panel rounded-2xl p-5 border border-slate-800 overflow-x-auto">
        <table className="w-full text-left text-xs">
          <thead>
            <tr className="border-b border-slate-800 text-slate-400 font-mono uppercase text-[10px]">
              <th className="py-3 px-3">Driver</th>
              <th className="py-3 px-3">Cash collected</th>
              <th className="py-3 px-3">Online held by TRYP</th>
              <th className="py-3 px-3">Cash fees owed</th>
              <th className="py-3 px-3">Updated</th>
            </tr>
          </thead>
          <tbody className="divide-y divide-slate-800/60">
            {driverWallets.map((wallet) => (
              <tr key={wallet.driverId} className="text-slate-300 hover:bg-slate-900/60 transition-colors">
                <td className="py-3 px-3 font-semibold text-slate-100">{wallet.driverName}</td>
                <td className="py-3 px-3 font-mono text-amber-400">R{wallet.cashCollected.toFixed(2)}</td>
                <td className="py-3 px-3 font-mono text-emerald-400">R{wallet.onlineHeld.toFixed(2)}</td>
                <td className="py-3 px-3 font-mono text-cyan-400">R{wallet.cashPlatformFeeOwed.toFixed(2)}</td>
                <td className="py-3 px-3 text-slate-500 font-mono">{new Date(wallet.updatedAt).toLocaleString('en-ZA')}</td>
              </tr>
            ))}
          </tbody>
        </table>
        {driverWallets.length === 0 && (
          <div className="py-12 text-center text-sm text-slate-500">No driver wallet balances yet.</div>
        )}
      </div>
    </div>
  );
};

const Metric: React.FC<{ icon: React.ReactNode; label: string; value: number; tone: string }> = ({ icon, label, value, tone }) => (
  <div className="glass-card p-5 rounded-2xl border border-slate-800 space-y-2">
    <div className="flex items-center gap-2 text-slate-400 text-[11px] uppercase tracking-wider font-bold">{icon}<span>{label}</span></div>
    <div className={`text-2xl font-extrabold font-mono ${tone}`}>R{value.toLocaleString('en-ZA', { minimumFractionDigits: 2 })}</div>
  </div>
);
