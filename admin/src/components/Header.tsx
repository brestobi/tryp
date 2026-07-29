import React, { useState } from 'react';
import { useAdmin } from '../context/AdminContext';
import type { AdminRole } from '../types/admin';
import {
  ShieldCheck,
  Bell,
  CheckCircle2,
  AlertTriangle,
  Info,
  Radio,
  ChevronDown
} from 'lucide-react';

export const Header: React.FC = () => {
  const {
    currentRole,
    setCurrentRole,
    notifications,
    markNotificationsRead,
    isRealtimeLive,
    setIsRealtimeLive,
    drivers,
    rides
  } = useAdmin();

  const [showNotifications, setShowNotifications] = useState(false);
  const [showRoleDropdown, setShowRoleDropdown] = useState(false);

  const unreadCount = notifications.filter(n => !n.read).length;
  const pendingKycCount = drivers.filter(d => d.driverStatus === 'pending' || d.driverStatus === 'under_review').length;
  const activeRidesCount = rides.filter(r => r.status === 'in_trip' || r.status === 'accepted' || r.status === 'arrived').length;

  const roleLabels: Record<AdminRole, { label: string; bg: string; text: string }> = {
    super_admin: { label: 'Super Admin', bg: 'bg-purple-500/20', text: 'text-purple-400 border-purple-500/30' },
    kyc_officer: { label: 'KYC Officer', bg: 'bg-emerald-500/20', text: 'text-emerald-400 border-emerald-500/30' },
    fleet_dispatcher: { label: 'Fleet Dispatcher', bg: 'bg-amber-500/20', text: 'text-amber-400 border-amber-500/30' },
    finance_manager: { label: 'Finance Manager', bg: 'bg-cyan-500/20', text: 'text-cyan-400 border-cyan-500/30' }
  };

  return (
    <header className="h-16 border-b border-slate-800 glass-panel sticky top-0 z-40 px-6 flex items-center justify-between">
      {/* Brand & System Status */}
      <div className="flex items-center space-x-4">
        <div className="flex items-center space-x-3">
          <div className="w-9 h-9 rounded-xl bg-gradient-to-tr from-purple-600 via-indigo-600 to-pink-500 flex items-center justify-center shadow-lg shadow-purple-500/20 font-bold text-lg text-white font-heading">
            T
          </div>
          <div>
            <div className="flex items-center space-x-2">
              <span className="font-heading font-extrabold text-lg text-white tracking-tight">TRYP</span>
              <span className="text-xs px-2 py-0.5 rounded-full bg-purple-500/10 text-purple-400 font-mono border border-purple-500/20">
                PROD-CONSOLE
              </span>
            </div>
            <p className="text-xs text-slate-400">Back-Office Fleet & KYC Operations</p>
          </div>
        </div>

        <div className="hidden lg:flex items-center space-x-3 ml-6 pl-6 border-l border-slate-800">
          <div className="flex items-center space-x-2 px-3 py-1 rounded-full bg-slate-900/80 border border-slate-800 text-xs">
            <span className="relative flex h-2 w-2">
              <span className="animate-ping absolute inline-flex h-full w-full rounded-full bg-emerald-400 opacity-75"></span>
              <span className="relative inline-flex rounded-full h-2 w-2 bg-emerald-500"></span>
            </span>
            <span className="text-slate-300 font-medium">Supabase Realtime</span>
          </div>

          <div className="flex items-center space-x-2 text-xs text-slate-400">
            <span className="px-2 py-0.5 rounded bg-slate-900 border border-slate-800">
              <span className="text-emerald-400 font-semibold">{activeRidesCount}</span> Active Rides
            </span>
            <span className="px-2 py-0.5 rounded bg-slate-900 border border-slate-800">
              <span className="text-amber-400 font-semibold">{pendingKycCount}</span> KYC Pending
            </span>
          </div>
        </div>
      </div>

      {/* Control Actions */}
      <div className="flex items-center space-x-4">
        {/* Live Simulation Toggle */}
        <button
          onClick={() => setIsRealtimeLive(!isRealtimeLive)}
          className={`flex items-center space-x-2 text-xs px-3 py-1.5 rounded-lg border transition-all ${
            isRealtimeLive
              ? 'bg-emerald-500/10 text-emerald-400 border-emerald-500/30 hover:bg-emerald-500/20'
              : 'bg-slate-900 text-slate-400 border-slate-800 hover:bg-slate-800'
          }`}
          title="Toggle live telemetry feed"
        >
          <Radio className={`w-3.5 h-3.5 ${isRealtimeLive ? 'animate-pulse text-emerald-400' : ''}`} />
          <span className="font-medium">{isRealtimeLive ? 'Live Feed: Active' : 'Live Feed: Paused'}</span>
        </button>

        {/* Role Selector */}
        <div className="relative">
          <button
            onClick={() => setShowRoleDropdown(!showRoleDropdown)}
            className={`flex items-center space-x-2 text-xs px-3 py-1.5 rounded-lg border font-medium transition-all ${roleLabels[currentRole].bg} ${roleLabels[currentRole].text}`}
          >
            <ShieldCheck className="w-4 h-4" />
            <span>{roleLabels[currentRole].label}</span>
            <ChevronDown className="w-3.5 h-3.5 opacity-70" />
          </button>

          {showRoleDropdown && (
            <div className="absolute right-0 mt-2 w-56 glass-panel rounded-xl shadow-2xl border border-slate-800 py-1 z-50 animate-in fade-in zoom-in-95">
              <div className="px-3 py-2 border-b border-slate-800 text-[11px] font-semibold text-slate-400 uppercase tracking-wider">
                Switch Admin View Role
              </div>
              {(Object.keys(roleLabels) as AdminRole[]).map(role => (
                <button
                  key={role}
                  onClick={() => {
                    setCurrentRole(role);
                    setShowRoleDropdown(false);
                  }}
                  className={`w-full text-left px-3 py-2 text-xs flex items-center justify-between hover:bg-slate-800/60 ${
                    currentRole === role ? 'text-purple-400 font-semibold bg-purple-500/10' : 'text-slate-300'
                  }`}
                >
                  <span>{roleLabels[role].label}</span>
                  {currentRole === role && <CheckCircle2 className="w-3.5 h-3.5 text-purple-400" />}
                </button>
              ))}
            </div>
          )}
        </div>

        {/* Notifications Dropdown */}
        <div className="relative">
          <button
            onClick={() => {
              setShowNotifications(!showNotifications);
              if (unreadCount > 0) markNotificationsRead();
            }}
            className="relative p-2 text-slate-400 hover:text-white rounded-lg bg-slate-900 border border-slate-800 hover:border-slate-700 transition-colors"
          >
            <Bell className="w-4 h-4" />
            {unreadCount > 0 && (
              <span className="absolute -top-1 -right-1 w-4 h-4 bg-purple-500 text-white text-[10px] font-bold rounded-full flex items-center justify-center animate-bounce">
                {unreadCount}
              </span>
            )}
          </button>

          {showNotifications && (
            <div className="absolute right-0 mt-2 w-80 glass-panel rounded-xl shadow-2xl border border-slate-800 p-3 z-50 animate-in fade-in zoom-in-95">
              <div className="flex items-center justify-between border-b border-slate-800 pb-2 mb-2">
                <span className="text-xs font-bold text-white uppercase tracking-wider">System Alerts</span>
                <span className="text-[10px] text-purple-400 font-mono">{notifications.length} events</span>
              </div>
              <div className="space-y-2 max-h-64 overflow-y-auto">
                {notifications.map(n => (
                  <div
                    key={n.id}
                    className="p-2.5 rounded-lg bg-slate-900/90 border border-slate-800 text-xs space-y-1 hover:border-slate-700 transition-all"
                  >
                    <div className="flex items-center justify-between">
                      <div className="flex items-center space-x-1.5 font-semibold text-slate-200">
                        {n.type === 'warning' ? (
                          <AlertTriangle className="w-3.5 h-3.5 text-amber-400" />
                        ) : n.type === 'success' ? (
                          <CheckCircle2 className="w-3.5 h-3.5 text-emerald-400" />
                        ) : (
                          <Info className="w-3.5 h-3.5 text-purple-400" />
                        )}
                        <span>{n.title}</span>
                      </div>
                      <span className="text-[10px] text-slate-500 font-mono">
                        {new Date(n.timestamp).toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' })}
                      </span>
                    </div>
                    <p className="text-slate-400 text-[11px] leading-relaxed">{n.message}</p>
                  </div>
                ))}
              </div>
            </div>
          )}
        </div>

        {/* User Admin Avatar */}
        <div className="flex items-center space-x-3 pl-3 border-l border-slate-800">
          <div className="w-8 h-8 rounded-full bg-gradient-to-tr from-indigo-500 to-purple-500 p-0.5">
            <img
              src="https://images.unsplash.com/photo-1534528741775-53994a69daeb?auto=format&fit=crop&q=80&w=200"
              alt="Admin Profile"
              className="w-full h-full rounded-full object-cover"
            />
          </div>
          <div className="hidden md:block text-left">
            <div className="text-xs font-semibold text-slate-200">Dimpho Bresley</div>
            <div className="text-[10px] text-purple-400 font-mono">bresleydimpho@gmail.com</div>
          </div>
        </div>
      </div>
    </header>
  );
};
