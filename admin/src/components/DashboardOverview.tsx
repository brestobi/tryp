import React, { useMemo } from 'react';
import { useAdmin } from '../context/AdminContext';
import {
  ResponsiveContainer,
  AreaChart,
  Area,
  BarChart,
  Bar,
  XAxis,
  YAxis,
  Tooltip,
  CartesianGrid,
} from 'recharts';
import {
  TrendingUp,
  Car,
  UserCheck,
  ArrowUpRight,
  ShieldCheck,
  Radio,
  Sparkles,
  Loader2,
} from 'lucide-react';

export const DashboardOverview: React.FC = () => {
  const { drivers, rides, payouts, setActiveTab, loading } = useAdmin();

  const pendingKycCount = drivers.filter(
    (d) => d.driverStatus === 'pending' || d.driverStatus === 'under_review'
  ).length;
  const onlineDrivers = drivers.filter((d) => d.isOnline);
  const activeRides = rides.filter((r) => r.status === 'in_trip' || r.status === 'accepted');

  // Compute revenue by day of week from real rides data
  const revenueByDay = useMemo(() => {
    const dayLabels = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
    const map: Record<string, { revenue: number; trips: number }> = {};
    dayLabels.forEach((d) => { map[d] = { revenue: 0, trips: 0 }; });

    for (const r of rides) {
      if (r.status === 'completed' && r.fare > 0) {
        const day = dayLabels[new Date(r.requestedAt).getDay()];
        map[day].revenue += r.fare;
        map[day].trips += 1;
      }
    }
    return dayLabels.map((day) => ({ day, ...map[day] }));
  }, [rides]);

  // Compute tier distribution from real rides data
  const tierDistribution = useMemo(() => {
    const tiers: Record<string, number> = {};
    for (const r of rides) {
      tiers[r.tier] = (tiers[r.tier] ?? 0) + 1;
    }
    return Object.entries(tiers).map(([tier, count]) => ({ tier, count }));
  }, [rides]);

  // Total revenue from verified payouts
  const totalGross = payouts.reduce((s, p) => s + p.grossEarnings, 0);

  // Average platform driver rating
  const avgRating =
    drivers.length > 0
      ? drivers.reduce((s, d) => s + d.rating, 0) / drivers.length
      : 0;

  if (loading) {
    return (
      <div className="flex items-center justify-center h-64 text-slate-400">
        <Loader2 className="w-6 h-6 animate-spin mr-2" />
        <span className="text-sm">Loading dashboard data...</span>
      </div>
    );
  }

  return (
    <div className="space-y-6 animate-in fade-in duration-300">
      {/* Welcome Banner */}
      <div className="glass-panel p-6 rounded-2xl border border-slate-800 flex flex-col md:flex-row md:items-center justify-between gap-4 relative overflow-hidden">
        <div className="absolute -right-10 -bottom-10 w-64 h-64 bg-purple-600/10 rounded-full blur-3xl pointer-events-none" />
        <div className="space-y-1 z-10">
          <div className="flex items-center space-x-2 text-xs font-bold uppercase tracking-wider text-purple-400 font-mono">
            <Sparkles className="w-4 h-4" />
            <span>Executive Operations Control</span>
          </div>
          <h1 className="text-2xl font-bold font-heading text-white">TRYP Platform Command Center</h1>
          <p className="text-slate-400 text-xs">
            Live overview of driver onboarding, fleet dispatch, and South African ride economics.
          </p>
        </div>

        <div className="flex items-center space-x-3 z-10">
          <button
            onClick={() => setActiveTab('kyc')}
            className="px-4 py-2.5 rounded-xl bg-purple-600/20 border border-purple-500/40 text-purple-300 hover:bg-purple-600/30 text-xs font-bold transition-all flex items-center space-x-2 shadow-lg shadow-purple-500/10"
          >
            <UserCheck className="w-4 h-4" />
            <span>Review KYC ({pendingKycCount})</span>
          </button>
          <button
            onClick={() => setActiveTab('fleet')}
            className="px-4 py-2.5 rounded-xl bg-emerald-600/20 border border-emerald-500/40 text-emerald-300 hover:bg-emerald-600/30 text-xs font-bold transition-all flex items-center space-x-2 shadow-lg shadow-emerald-500/10"
          >
            <Radio className="w-4 h-4 animate-pulse" />
            <span>Fleet Radar</span>
          </button>
        </div>
      </div>

      {/* KPI Cards */}
      <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4">
        <div className="glass-card p-5 rounded-2xl border border-slate-800 space-y-3 glass-card-hover">
          <div className="flex items-center justify-between">
            <span className="text-[11px] font-bold text-slate-400 uppercase tracking-wider">Total Payout Pool</span>
            <div className="w-8 h-8 rounded-xl bg-purple-500/10 border border-purple-500/30 flex items-center justify-center">
              <TrendingUp className="w-4 h-4 text-purple-400" />
            </div>
          </div>
          <div>
            <div className="text-2xl font-extrabold text-white font-mono">
              R{totalGross.toLocaleString('en-ZA', { minimumFractionDigits: 2 })}
            </div>
            <div className="flex items-center space-x-1 text-xs text-emerald-400 font-semibold mt-1">
              <ArrowUpRight className="w-3.5 h-3.5" />
              <span>From verified settlements</span>
            </div>
          </div>
        </div>

        <div className="glass-card p-5 rounded-2xl border border-slate-800 space-y-3 glass-card-hover">
          <div className="flex items-center justify-between">
            <span className="text-[11px] font-bold text-slate-400 uppercase tracking-wider">Active Fleet Online</span>
            <div className="w-8 h-8 rounded-xl bg-emerald-500/10 border border-emerald-500/30 flex items-center justify-center">
              <Car className="w-4 h-4 text-emerald-400" />
            </div>
          </div>
          <div>
            <div className="text-2xl font-extrabold text-white font-mono">{onlineDrivers.length} Drivers</div>
            <div className="text-xs text-slate-400 mt-1">
              <span className="text-emerald-400 font-semibold">{activeRides.length}</span> in active trips
            </div>
          </div>
        </div>

        <div className="glass-card p-5 rounded-2xl border border-slate-800 space-y-3 glass-card-hover">
          <div className="flex items-center justify-between">
            <span className="text-[11px] font-bold text-slate-400 uppercase tracking-wider">KYC Pending Review</span>
            <div className="w-8 h-8 rounded-xl bg-amber-500/10 border border-amber-500/30 flex items-center justify-center">
              <UserCheck className="w-4 h-4 text-amber-400" />
            </div>
          </div>
          <div>
            <div className="text-2xl font-extrabold text-amber-400 font-mono">
              {pendingKycCount} Applications
            </div>
            <div className="text-xs text-slate-400 mt-1">Awaiting document inspection</div>
          </div>
        </div>

        <div className="glass-card p-5 rounded-2xl border border-slate-800 space-y-3 glass-card-hover">
          <div className="flex items-center justify-between">
            <span className="text-[11px] font-bold text-slate-400 uppercase tracking-wider">Avg Driver Rating</span>
            <div className="w-8 h-8 rounded-xl bg-cyan-500/10 border border-cyan-500/30 flex items-center justify-center">
              <ShieldCheck className="w-4 h-4 text-cyan-400" />
            </div>
          </div>
          <div>
            <div className="text-2xl font-extrabold text-white font-mono">
              {avgRating > 0 ? `${avgRating.toFixed(2)} / 5.0` : '—'}
            </div>
            <div className="text-xs text-slate-400 mt-1">
              Across {drivers.length} verified drivers
            </div>
          </div>
        </div>
      </div>

      {/* Charts */}
      <div className="grid grid-cols-1 lg:grid-cols-12 gap-6">
        {/* Revenue by day (computed from rides) */}
        <div className="lg:col-span-8 glass-panel rounded-2xl p-5 border border-slate-800 space-y-4">
          <div className="flex items-center justify-between border-b border-slate-800 pb-3">
            <div>
              <h3 className="font-heading font-bold text-lg text-white">Revenue by Day of Week</h3>
              <p className="text-xs text-slate-400">Completed trip fares (ZAR) — live from database</p>
            </div>
            <span className="text-xs font-mono px-2.5 py-1 rounded bg-slate-900 border border-slate-800 text-purple-400 font-bold">
              {rides.filter((r) => r.status === 'completed').length} completed trips
            </span>
          </div>
          <div className="h-64 w-full pt-2">
            {revenueByDay.some((d) => d.revenue > 0) ? (
              <ResponsiveContainer width="100%" height="100%">
                <AreaChart data={revenueByDay} margin={{ top: 10, right: 10, left: -20, bottom: 0 }}>
                  <defs>
                    <linearGradient id="colorRevenue" x1="0" y1="0" x2="0" y2="1">
                      <stop offset="5%" stopColor="#a855f7" stopOpacity={0.4} />
                      <stop offset="95%" stopColor="#a855f7" stopOpacity={0} />
                    </linearGradient>
                  </defs>
                  <CartesianGrid strokeDasharray="3 3" stroke="#1e293b" />
                  <XAxis dataKey="day" stroke="#64748b" fontSize={11} tickLine={false} />
                  <YAxis stroke="#64748b" fontSize={11} tickLine={false} />
                  <Tooltip
                    contentStyle={{ backgroundColor: '#0f172a', borderColor: '#334155', borderRadius: '0.75rem', fontSize: '12px' }}
                    labelStyle={{ color: '#f8fafc', fontWeight: 'bold' }}
                  />
                  <Area type="monotone" dataKey="revenue" stroke="#a855f7" strokeWidth={3} fillOpacity={1} fill="url(#colorRevenue)" name="Revenue (R)" />
                </AreaChart>
              </ResponsiveContainer>
            ) : (
              <div className="flex items-center justify-center h-full text-slate-500 text-sm">
                No completed rides to chart yet
              </div>
            )}
          </div>
        </div>

        {/* Tier distribution */}
        <div className="lg:col-span-4 glass-panel rounded-2xl p-5 border border-slate-800 space-y-4">
          <div className="border-b border-slate-800 pb-3">
            <h3 className="font-heading font-bold text-lg text-white">Rides by Vehicle Tier</h3>
            <p className="text-xs text-slate-400">All-time trip distribution</p>
          </div>
          <div className="h-64 w-full pt-2">
            {tierDistribution.length > 0 ? (
              <ResponsiveContainer width="100%" height="100%">
                <BarChart data={tierDistribution} margin={{ top: 10, right: 10, left: -20, bottom: 0 }}>
                  <CartesianGrid strokeDasharray="3 3" stroke="#1e293b" />
                  <XAxis dataKey="tier" stroke="#64748b" fontSize={9} tickLine={false} />
                  <YAxis stroke="#64748b" fontSize={11} tickLine={false} />
                  <Tooltip
                    contentStyle={{ backgroundColor: '#0f172a', borderColor: '#334155', borderRadius: '0.75rem', fontSize: '12px' }}
                    labelStyle={{ color: '#f8fafc', fontWeight: 'bold' }}
                  />
                  <Bar dataKey="count" fill="#10b981" radius={[6, 6, 0, 0]} name="Trips" />
                </BarChart>
              </ResponsiveContainer>
            ) : (
              <div className="flex items-center justify-center h-full text-slate-500 text-sm">
                No ride data yet
              </div>
            )}
          </div>
        </div>
      </div>
    </div>
  );
};
