import React from 'react';
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
  CartesianGrid
} from 'recharts';
import {
  TrendingUp,
  Car,
  UserCheck,
  ArrowUpRight,
  ShieldCheck,
  Radio,
  Sparkles
} from 'lucide-react';

const REVENUE_DATA = [
  { day: 'Mon', revenue: 14200, trips: 184 },
  { day: 'Tue', revenue: 18900, trips: 240 },
  { day: 'Wed', revenue: 16500, trips: 210 },
  { day: 'Thu', revenue: 22400, trips: 290 },
  { day: 'Fri', revenue: 31000, trips: 410 },
  { day: 'Sat', revenue: 38500, trips: 520 },
  { day: 'Sun', revenue: 27800, trips: 360 }
];

const TIER_DISTRIBUTION = [
  { tier: 'TRYP Go', count: 1240, revenue: 84500 },
  { tier: 'TRYP Comfort', count: 680, revenue: 98000 },
  { tier: 'TRYP XL', count: 210, revenue: 42000 },
  { tier: 'TRYP Exec', count: 95, revenue: 38000 }
];

export const DashboardOverview: React.FC = () => {
  const { drivers, rides, setActiveTab } = useAdmin();

  const pendingKycCount = drivers.filter(d => d.driverStatus === 'pending' || d.driverStatus === 'under_review').length;
  const onlineDrivers = drivers.filter(d => d.isOnline);
  const activeRides = rides.filter(r => r.status === 'in_trip' || r.status === 'accepted');

  return (
    <div className="space-y-6 animate-in fade-in duration-300">
      {/* Welcome Banner */}
      <div className="glass-panel p-6 rounded-2xl border border-slate-800 flex flex-col md:flex-row md:items-center justify-between gap-4 relative overflow-hidden">
        <div className="absolute -right-10 -bottom-10 w-64 h-64 bg-purple-600/10 rounded-full blur-3xl pointer-events-none"></div>
        <div className="space-y-1 z-10">
          <div className="flex items-center space-x-2 text-xs font-bold uppercase tracking-wider text-purple-400 font-mono">
            <Sparkles className="w-4 h-4 text-purple-400" />
            <span>Executive Operations Control</span>
          </div>
          <h1 className="text-2xl font-bold font-heading text-white">TRYP Platform Command Center</h1>
          <p className="text-slate-400 text-xs">
            Live overview of driver onboarding compliance, fleet real-time dispatch, and daily South African ride economics.
          </p>
        </div>

        {/* Quick Operational Action Shortcuts */}
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
            <Radio className="w-4 h-4 text-emerald-400 animate-pulse" />
            <span>Open Fleet Radar</span>
          </button>
        </div>
      </div>

      {/* KPI Cards Grid */}
      <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4">
        {/* Card 1: Daily Revenue */}
        <div className="glass-card p-5 rounded-2xl border border-slate-800 space-y-3 glass-card-hover">
          <div className="flex items-center justify-between">
            <span className="text-[11px] font-bold text-slate-400 uppercase tracking-wider">Weekly Platform Gross</span>
            <div className="w-8 h-8 rounded-xl bg-purple-500/10 border border-purple-500/30 flex items-center justify-center text-purple-400">
              <TrendingUp className="w-4 h-4" />
            </div>
          </div>
          <div>
            <div className="text-2xl font-extrabold text-white font-mono">R169,300.00</div>
            <div className="flex items-center space-x-1 text-xs text-emerald-400 font-semibold mt-1">
              <ArrowUpRight className="w-3.5 h-3.5" />
              <span>+18.4% vs last week</span>
            </div>
          </div>
        </div>

        {/* Card 2: Active Fleet */}
        <div className="glass-card p-5 rounded-2xl border border-slate-800 space-y-3 glass-card-hover">
          <div className="flex items-center justify-between">
            <span className="text-[11px] font-bold text-slate-400 uppercase tracking-wider">Active Fleet Online</span>
            <div className="w-8 h-8 rounded-xl bg-emerald-500/10 border border-emerald-500/30 flex items-center justify-center text-emerald-400">
              <Car className="w-4 h-4" />
            </div>
          </div>
          <div>
            <div className="text-2xl font-extrabold text-white font-mono">{onlineDrivers.length} Drivers</div>
            <div className="text-xs text-slate-400 mt-1">
              <span className="text-emerald-400 font-semibold">{activeRides.length}</span> currently in active trips
            </div>
          </div>
        </div>

        {/* Card 3: Pending KYC */}
        <div className="glass-card p-5 rounded-2xl border border-slate-800 space-y-3 glass-card-hover">
          <div className="flex items-center justify-between">
            <span className="text-[11px] font-bold text-slate-400 uppercase tracking-wider">Pending KYC Queue</span>
            <div className="w-8 h-8 rounded-xl bg-amber-500/10 border border-amber-500/30 flex items-center justify-center text-amber-400">
              <UserCheck className="w-4 h-4" />
            </div>
          </div>
          <div>
            <div className="text-2xl font-extrabold text-amber-400 font-mono">{pendingKycCount} Verification Req</div>
            <div className="text-xs text-slate-400 mt-1">Split-screen inspection pending</div>
          </div>
        </div>

        {/* Card 4: Avg Rating */}
        <div className="glass-card p-5 rounded-2xl border border-slate-800 space-y-3 glass-card-hover">
          <div className="flex items-center justify-between">
            <span className="text-[11px] font-bold text-slate-400 uppercase tracking-wider">Platform Safety Rating</span>
            <div className="w-8 h-8 rounded-xl bg-cyan-500/10 border border-cyan-500/30 flex items-center justify-center text-cyan-400">
              <ShieldCheck className="w-4 h-4" />
            </div>
          </div>
          <div>
            <div className="text-2xl font-extrabold text-white font-mono">4.92 / 5.0</div>
            <div className="text-xs text-slate-400 mt-1">Verified passenger ride feedback</div>
          </div>
        </div>
      </div>

      {/* Analytics Charts Grid */}
      <div className="grid grid-cols-1 lg:grid-cols-12 gap-6">
        {/* Weekly Revenue & Trip Volume Chart (8 cols) */}
        <div className="lg:col-span-8 glass-panel rounded-2xl p-5 border border-slate-800 space-y-4">
          <div className="flex items-center justify-between border-b border-slate-800 pb-3">
            <div>
              <h3 className="font-heading font-bold text-lg text-white">Daily Platform Revenue & Trip Volume</h3>
              <p className="text-xs text-slate-400">South African fleet performance metrics (ZAR)</p>
            </div>
            <span className="text-xs font-mono px-2.5 py-1 rounded bg-slate-900 border border-slate-800 text-purple-400 font-bold">
              Realtime Aggregated
            </span>
          </div>

          <div className="h-72 w-full pt-2">
            <ResponsiveContainer width="100%" height="100%">
              <AreaChart data={REVENUE_DATA} margin={{ top: 10, right: 10, left: -20, bottom: 0 }}>
                <defs>
                  <linearGradient id="colorRevenue" x1="0" y1="0" x2="0" y2="1">
                    <stop offset="5%" stopColor="#a855f7" stopOpacity={0.4} />
                    <stop offset="95%" stopColor="#a855f7" stopOpacity={0.0} />
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
          </div>
        </div>

        {/* Tier Distribution Bar Chart (4 cols) */}
        <div className="lg:col-span-4 glass-panel rounded-2xl p-5 border border-slate-800 space-y-4">
          <div className="border-b border-slate-800 pb-3">
            <h3 className="font-heading font-bold text-lg text-white">Vehicle Tier Volume</h3>
            <p className="text-xs text-slate-400">Rides completed per tier</p>
          </div>

          <div className="h-72 w-full pt-2">
            <ResponsiveContainer width="100%" height="100%">
              <BarChart data={TIER_DISTRIBUTION} margin={{ top: 10, right: 10, left: -20, bottom: 0 }}>
                <CartesianGrid strokeDasharray="3 3" stroke="#1e293b" />
                <XAxis dataKey="tier" stroke="#64748b" fontSize={10} tickLine={false} />
                <YAxis stroke="#64748b" fontSize={11} tickLine={false} />
                <Tooltip
                  contentStyle={{ backgroundColor: '#0f172a', borderColor: '#334155', borderRadius: '0.75rem', fontSize: '12px' }}
                  labelStyle={{ color: '#f8fafc', fontWeight: 'bold' }}
                />
                <Bar dataKey="count" fill="#10b981" radius={[6, 6, 0, 0]} name="Ride Count" />
              </BarChart>
            </ResponsiveContainer>
          </div>
        </div>
      </div>
    </div>
  );
};
