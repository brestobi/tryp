import React, { useState } from 'react';
import { useAdmin } from '../context/AdminContext';
import { useAuth } from '../context/AuthContext';
import type { AdminRole } from '../types/admin';
import {
  ShieldCheck,
  Bell,
  CheckCircle2,
  AlertTriangle,
  Info,
  Radio,
  ChevronDown,
  LogOut,
  RefreshCw,
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
    rides,
    loading,
    refresh,
  } = useAdmin();

  const { user, signOut } = useAuth();

  const [showNotifications, setShowNotifications] = useState(false);
  const [showRoleDropdown, setShowRoleDropdown] = useState(false);

  const unreadCount = notifications.filter((n) => !n.read).length;
  const pendingKycCount = drivers.filter(
    (d) => d.driverStatus === 'pending' || d.driverStatus === 'under_review'
  ).length;
  const activeRidesCount = rides.filter(
    (r) => r.status === 'in_trip' || r.status === 'accepted' || r.status === 'arrived'
  ).length;

  const roleLabels: Record<AdminRole, { label: string; classes: string }> = {
    super_admin:     { label: 'Super Admin',      classes: 'bg-purple-500/20 text-purple-400 border-purple-500/30' },
    kyc_officer:     { label: 'KYC Officer',       classes: 'bg-emerald-500/20 text-emerald-400 border-emerald-500/30' },
    fleet_dispatcher:{ label: 'Fleet Dispatcher',  classes: 'bg-amber-500/20 text-amber-400 border-amber-500/30' },
    finance_manager: { label: 'Finance Manager',   classes: 'bg-cyan-500/20 text-cyan-400 border-cyan-500/30' },
  };

  return (
    <header className="h-16 border-b border-slate-800 glass-panel sticky top-0 z-40 px-6 flex items-center justify-between">
      {/* Brand */}
      <div className="flex items-center space-x-4">
        <div className="flex items-center space-x-3">
          <div className="w-9 h-9 rounded-xl bg-gradient-to-tr from-purple-600 via-indigo-600 to-pink-500 flex items-center justify-center shadow-lg shadow-purple-500/20 font-bold text-lg text-white font-heading">
            T
          </div>
          <div>
            <div className="flex items-center space-x-2">
              <span className="font-heading font-extrabold text-lg text-white tracking-tight">TRYP</span>
              <span className="text-xs px-2 py-0.5 rounded-full bg-purple-500/10 text-purple-400 font-mono border border-purple-500/20">
                ADMIN CONSOLE
              </span>
            </div>
            <p className="text-xs text-slate-400">Back-Office Fleet & KYC Operations</p>
          </div>
        </div>

        <div className="hidden lg:flex items-center space-x-3 ml-6 pl-6 border-l border-slate-800">
          {/* Live indicator */}
          <div className="flex items-center space-x-2 px-3 py-1 rounded-full bg-slate-900/80 border border-slate-800 text-xs">
            <span className="relative flex h-2 w-2">
              <span className={`animate-ping absolute inline-flex h-full w-full rounded-full ${isRealtimeLive ? 'bg-emerald-400' : 'bg-slate-600'} opacity-75`} />
              <span className={`relative inline-flex rounded-full h-2 w-2 ${isRealtimeLive ? 'bg-emerald-500' : 'bg-slate-600'}`} />
            </span>
            <span className="text-slate-300 font-medium">
              {isRealtimeLive ? 'Supabase Realtime' : 'Feed Paused'}
            </span>
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

      {/* Controls */}
      <div className="flex items-center space-x-3">
        {/* Refresh */}
        <button
          onClick={refresh}
          disabled={loading}
          title="Reload all data"
          className="p-2 text-slate-400 hover:text-white rounded-lg bg-slate-900 border border-slate-800 hover:border-slate-700 transition-colors disabled:opacity-40"
        >
          <RefreshCw className={`w-4 h-4 ${loading ? 'animate-spin' : ''}`} />
        </button>

        {/* Live toggle */}
        <button
          onClick={() => setIsRealtimeLive(!isRealtimeLive)}
          className={`flex items-center space-x-2 text-xs px-3 py-1.5 rounded-lg border transition-all ${
            isRealtimeLive
              ? 'bg-emerald-500/10 text-emerald-400 border-emerald-500/30 hover:bg-emerald-500/20'
              : 'bg-slate-900 text-slate-400 border-slate-800 hover:bg-slate-800'
          }`}
        >
          <Radio className={`w-3.5 h-3.5 ${isRealtimeLive ? 'animate-pulse' : ''}`} />
          <span className="font-medium hidden sm:inline">
            {isRealtimeLive ? 'Live' : 'Paused'}
          </span>
        </button>

        {/* Role selector */}
        <div className="relative">
          <button
            onClick={() => setShowRoleDropdown(!showRoleDropdown)}
            className={`flex items-center space-x-2 text-xs px-3 py-1.5 rounded-lg border font-medium transition-all ${roleLabels[currentRole].classes}`}
          >
            <ShieldCheck className="w-4 h-4" />
            <span className="hidden sm:inline">{roleLabels[currentRole].label}</span>
            <ChevronDown className="w-3.5 h-3.5 opacity-70" />
          </button>

          {showRoleDropdown && (
            <div className="absolute right-0 mt-2 w-52 glass-panel rounded-xl shadow-2xl border border-slate-800 py-1 z-50 animate-in fade-in zoom-in-95">
              <div className="px-3 py-2 border-b border-slate-800 text-[11px] font-semibold text-slate-400 uppercase tracking-wider">
                Switch View Role
              </div>
              {(Object.keys(roleLabels) as AdminRole[]).map((role) => (
                <button
                  key={role}
                  onClick={() => { setCurrentRole(role); setShowRoleDropdown(false); }}
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

        {/* Notifications */}
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
                {notifications.length === 0 && (
                  <p className="text-center text-xs text-slate-500 py-4">No alerts</p>
                )}
                {notifications.map((n) => (
                  <div key={n.id} className="p-2.5 rounded-lg bg-slate-900/90 border border-slate-800 text-xs space-y-1">
                    <div className="flex items-center justify-between">
                      <div className="flex items-center space-x-1.5 font-semibold text-slate-200">
                        {n.type === 'warning' ? <AlertTriangle className="w-3.5 h-3.5 text-amber-400" />
                          : n.type === 'success' ? <CheckCircle2 className="w-3.5 h-3.5 text-emerald-400" />
                          : n.type === 'error' ? <AlertTriangle className="w-3.5 h-3.5 text-red-400" />
                          : <Info className="w-3.5 h-3.5 text-purple-400" />}
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

        {/* User avatar — populated from auth session */}
        <div className="flex items-center space-x-3 pl-3 border-l border-slate-800">
          <img
            src={user?.avatarUrl ?? `https://ui-avatars.com/api/?name=${encodeURIComponent(user?.fullName ?? 'Admin')}&background=7c3aed&color=fff`}
            alt={user?.fullName ?? 'Admin'}
            className="w-8 h-8 rounded-full object-cover border border-purple-500/40 ring-1 ring-purple-500/20"
          />
          <div className="hidden md:block text-left">
            <div className="text-xs font-semibold text-slate-200 leading-none">{user?.fullName ?? '—'}</div>
            <div className="text-[10px] text-purple-400 font-mono mt-0.5">{user?.email ?? '—'}</div>
          </div>
          <button
            onClick={signOut}
            title="Sign out"
            className="p-1.5 text-slate-500 hover:text-red-400 hover:bg-red-500/10 rounded-lg transition-colors"
          >
            <LogOut className="w-4 h-4" />
          </button>
        </div>
      </div>
    </header>
  );
};
