import React from 'react';
import { useAdmin } from '../context/AdminContext';
import type { ActiveTab } from '../context/AdminContext';
import type { Permission } from '../lib/rbac';
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
  FileSpreadsheet,
  ShieldCheck,
  CornerDownLeft,
  ShieldAlert,
  CalendarClock,
} from 'lucide-react';

export const Sidebar: React.FC = () => {
  const { activeTab, setActiveTab, drivers, rides, payouts, incidents, scheduledRides, can } = useAdmin();

  const pendingKycCount = drivers.filter(
    (d) => d.driverStatus === 'pending' || d.driverStatus === 'under_review'
  ).length;
  const activeRidesCount = rides.filter(
    (r) => r.status === 'in_trip' || r.status === 'accepted' || r.status === 'arrived'
  ).length;
  const pendingPayoutsCount = payouts.filter((p) => p.status === 'pending').length;
  const openIncidentCount = incidents.filter((i) => i.status === 'open').length;
  const upcomingScheduledCount = scheduledRides.filter(
    (r) => r.status === 'requested' && new Date(r.scheduledFor).getTime() > Date.now(),
  ).length;

  const navItems: {
    id: ActiveTab;
    label: string;
    icon: React.FC<{ className?: string }>;
    badge?: number;
    badgeColor?: string;
    permission: Permission;
  }[] = [
    { id: 'dashboard', label: 'Executive Dashboard', icon: LayoutDashboard, permission: 'dashboard:read' },
    { id: 'kyc',       label: 'Driver KYC Inspector',  icon: UserCheck, badge: pendingKycCount,    badgeColor: 'bg-amber-500/20 text-amber-400 border-amber-500/30', permission: 'kyc:read' },
    { id: 'passenger-verification', label: 'Passenger Verification', icon: UserRoundCheck, permission: 'kyc:read' },
    { id: 'fleet',     label: 'Fleet Command Center',  icon: MapPin,    badge: activeRidesCount,   badgeColor: 'bg-emerald-500/20 text-emerald-400 border-emerald-500/30', permission: 'fleet:read' },
    { id: 'scheduled', label: 'Scheduled Rides',      icon: CalendarClock, badge: upcomingScheduledCount, badgeColor: 'bg-indigo-500/20 text-indigo-300 border-indigo-500/40', permission: 'fleet:read' },
    { id: 'incidents', label: 'Incident Review',      icon: ShieldAlert, badge: openIncidentCount, badgeColor: 'bg-red-500/20 text-red-300 border-red-500/40', permission: 'fleet:read' },
    { id: 'fares',     label: 'Dynamic Fare Engine',   icon: BadgePercent, permission: 'fares:read' },
    { id: 'payouts',   label: 'Payouts & Banking',     icon: CreditCard, badge: pendingPayoutsCount, badgeColor: 'bg-cyan-500/20 text-cyan-400 border-cyan-500/30', permission: 'finance:read' },
    { id: 'wallets',   label: 'Driver Wallets',         icon: Wallet, permission: 'finance:read' },
    { id: 'refunds',   label: 'Refunds & Disputes',    icon: CornerDownLeft, permission: 'finance:read' },
    { id: 'users',     label: 'User Directory',        icon: Users, permission: 'users:read' },
    { id: 'admin-users', label: 'Admin Roster',         icon: ShieldCheck, permission: 'admin:manage' },
    { id: 'audit',     label: 'Admin Audit Logs',      icon: FileText, permission: 'audit:read' },
    { id: 'broadcast', label: 'Broadcast Center',      icon: Megaphone, permission: 'broadcast:write' },
    { id: 'statements', label: 'Driver Statements',    icon: FileSpreadsheet, permission: 'statements:read' },
  ];

  return (
    <aside className="w-64 glass-panel border-r border-slate-800 flex flex-col justify-between p-4 shrink-0 min-h-[calc(100vh-4rem)]">
      <div className="space-y-6">
        <div>
          <div className="text-[11px] font-bold text-slate-500 uppercase tracking-wider px-3 mb-2">
            Operations Portal
          </div>
          <nav className="space-y-1">
            {navItems.filter((item) => can(item.permission)).map((item) => {
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
