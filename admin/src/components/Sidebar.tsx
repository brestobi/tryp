import React from 'react';
import { useAdmin } from '../context/AdminContext';
import type { ActiveTab } from '../context/AdminContext';
import {
  LayoutDashboard,
  UserCheck,
  UserRoundCheck,
  MapPin,
  BadgePercent,
  CreditCard,
  Wallet,
  Users,
  FileText,
  Zap,
  Server,
  Megaphone,
} from 'lucide-react';

export const Sidebar: React.FC = () => {
  const { activeTab, setActiveTab, drivers, rides, payouts } = useAdmin();

  const pendingKycCount = drivers.filter(
    (d) => d.driverStatus === 'pending' || d.driverStatus === 'under_review'
  ).length;
  const activeRidesCount = rides.filter(
    (r) => r.status === 'in_trip' || r.status === 'accepted' || r.status === 'arrived'
  ).length;
  const pendingPayoutsCount = payouts.filter((p) => p.status === 'pending').length;

  const navItems: {
    id: ActiveTab;
    label: string;
    icon: React.FC<{ className?: string }>;
    badge?: number;
    badgeColor?: string;
  }[] = [
    { id: 'dashboard', label: 'Executive Dashboard', icon: LayoutDashboard },
    { id: 'kyc',       label: 'Driver KYC Inspector',  icon: UserCheck, badge: pendingKycCount,    badgeColor: 'bg-amber-500/20 text-amber-400 border-amber-500/30' },
    { id: 'passenger-verification', label: 'Passenger Verification', icon: UserRoundCheck },
    { id: 'fleet',     label: 'Fleet Command Center',  icon: MapPin,    badge: activeRidesCount,   badgeColor: 'bg-emerald-500/20 text-emerald-400 border-emerald-500/30' },
    { id: 'fares',     label: 'Dynamic Fare Engine',   icon: BadgePercent },
    { id: 'payouts',   label: 'Payouts & Banking',     icon: CreditCard, badge: pendingPayoutsCount, badgeColor: 'bg-cyan-500/20 text-cyan-400 border-cyan-500/30' },
    { id: 'wallets',   label: 'Driver Wallets',         icon: Wallet },
    { id: 'users',     label: 'User Directory',        icon: Users },
    { id: 'audit',     label: 'Admin Audit Logs',      icon: FileText },
    { id: 'broadcast', label: 'Broadcast Center',      icon: Megaphone },
  ];

  return (
    <aside className="w-64 glass-panel border-r border-slate-800 flex flex-col justify-between p-4 shrink-0 min-h-[calc(100vh-4rem)]">
      <div className="space-y-6">
        <div>
          <div className="text-[11px] font-bold text-slate-500 uppercase tracking-wider px-3 mb-2">
            Operations Portal
          </div>
          <nav className="space-y-1">
            {navItems.map((item) => {
              const Icon = item.icon;
              const isActive = activeTab === item.id;
              return (
                <button
                  key={item.id}
                  onClick={() => setActiveTab(item.id)}
                  className={`w-full flex items-center justify-between px-3.5 py-2.5 rounded-xl font-medium text-xs transition-all duration-200 ${
                    isActive
                      ? 'bg-slate-100 text-slate-950 border border-slate-100 shadow-lg shadow-white/10'
                      : 'text-slate-400 hover:text-slate-200 hover:bg-slate-900/60'
                  }`}
                >
                  <div className="flex items-center space-x-3">
                    <Icon className={`w-4 h-4 ${isActive ? 'text-indigo-500' : 'text-slate-400'}`} />
                    <span>{item.label}</span>
                  </div>
                  {item.badge !== undefined && item.badge > 0 && (
                    <span className={`text-[10px] px-2 py-0.5 rounded-full font-mono border ${item.badgeColor}`}>
                      {item.badge}
                    </span>
                  )}
                </button>
              );
            })}
          </nav>
        </div>

        {/* Connection status widget */}
        <div className="p-3.5 rounded-xl glass-card space-y-3">
          <div className="flex items-center justify-between">
            <span className="text-[11px] font-bold text-slate-300 uppercase tracking-wider flex items-center space-x-1.5">
              <Zap className="w-3.5 h-3.5 text-amber-400" />
              <span>System Status</span>
            </span>
            <span className="w-2 h-2 rounded-full bg-emerald-500 animate-pulse" />
          </div>
          <div className="space-y-2 text-xs">
            {[
              { label: 'Supabase DB', status: 'Connected' },
              { label: 'Realtime Feed', status: 'Active' },
              { label: 'Paystack API', status: 'Operational' },
            ].map(({ label, status }) => (
              <div key={label} className="flex justify-between items-center text-slate-400">
                <span>{label}</span>
                <span className="text-emerald-400 font-mono text-[11px]">{status}</span>
              </div>
            ))}
          </div>
        </div>
      </div>

      <div className="pt-4 border-t border-slate-800 text-[11px] text-slate-500 flex items-center justify-between font-mono">
        <div className="flex items-center space-x-1.5">
          <Server className="w-3.5 h-3.5 text-slate-400" />
          <span>v2.5.0-ZA</span>
        </div>
        <span>TRYP Platform</span>
      </div>
    </aside>
  );
};
