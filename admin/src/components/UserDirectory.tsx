import React, { useState } from 'react';
import { useAdmin } from '../context/AdminContext';
import {
  Users,
  Search,
  Wallet,
  Star,
  PlusCircle,
  MinusCircle
} from 'lucide-react';

export const UserDirectory: React.FC = () => {
  const { drivers, passengers, adjustUserWallet, toggleUserStatus } = useAdmin();

  const [activeTab, setActiveTab] = useState<'drivers' | 'passengers'>('drivers');
  const [searchTerm, setSearchTerm] = useState<string>('');

  // Wallet adjustment modal state
  const [walletModalUser, setWalletModalUser] = useState<{ id: string; name: string; isDriver: boolean; currentBalance: number } | null>(null);
  const [adjustAmount, setAdjustAmount] = useState<number>(100);
  const [adjustType, setAdjustType] = useState<'add' | 'deduct'>('add');
  const [adjustReason, setAdjustReason] = useState<string>('Administrative customer resolution credit');

  const filteredDrivers = drivers.filter(d => {
    if (!searchTerm) return true;
    const term = searchTerm.toLowerCase();
    return (
      d.fullName.toLowerCase().includes(term) ||
      d.email.toLowerCase().includes(term) ||
      d.phone.includes(term) ||
      d.vehiclePlate.toLowerCase().includes(term)
    );
  });

  const filteredPassengers = passengers.filter(p => {
    if (!searchTerm) return true;
    const term = searchTerm.toLowerCase();
    return (
      p.fullName.toLowerCase().includes(term) ||
      p.email.toLowerCase().includes(term) ||
      p.phone.includes(term)
    );
  });

  const handleWalletSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    if (!walletModalUser) return;
    const finalAmount = adjustType === 'add' ? Math.abs(adjustAmount) : -Math.abs(adjustAmount);
    adjustUserWallet(walletModalUser.id, finalAmount, walletModalUser.isDriver, adjustReason);
    setWalletModalUser(null);
    setAdjustAmount(100);
  };

  return (
    <div className="space-y-6 animate-in fade-in duration-300">
      {/* Header Banner */}
      <div className="glass-panel p-6 rounded-2xl border border-slate-800 flex flex-col md:flex-row md:items-center justify-between gap-4">
        <div>
          <div className="flex items-center space-x-2 text-xs font-bold uppercase tracking-wider text-indigo-400 mb-1 font-mono">
            <Users className="w-4 h-4 text-indigo-400" />
            <span>Module 5 Administration</span>
          </div>
          <h1 className="text-2xl font-bold font-heading text-white">Passenger & Driver User Directory</h1>
          <p className="text-slate-400 text-xs mt-1">
            Central search, account suspension safety controls, rating audits, and wallet balance adjustments.
          </p>
        </div>

        {/* Tab Switcher */}
        <div className="flex items-center space-x-2 bg-slate-900/80 p-1.5 rounded-xl border border-slate-800">
          <button
            onClick={() => setActiveTab('drivers')}
            className={`px-4 py-1.5 rounded-lg text-xs font-semibold transition-all ${
              activeTab === 'drivers'
                ? 'bg-purple-600 text-white shadow-md shadow-purple-500/20'
                : 'text-slate-400 hover:text-white'
            }`}
          >
            Drivers ({drivers.length})
          </button>
          <button
            onClick={() => setActiveTab('passengers')}
            className={`px-4 py-1.5 rounded-lg text-xs font-semibold transition-all ${
              activeTab === 'passengers'
                ? 'bg-purple-600 text-white shadow-md shadow-purple-500/20'
                : 'text-slate-400 hover:text-white'
            }`}
          >
            Passengers ({passengers.length})
          </button>
        </div>
      </div>

      {/* Directory Search Bar */}
      <div className="glass-panel p-4 rounded-2xl border border-slate-800 flex items-center justify-between">
        <div className="relative w-full max-w-md">
          <Search className="w-4 h-4 text-slate-400 absolute left-3 top-3" />
          <input
            type="text"
            placeholder="Search by name, phone, email, plate number..."
            value={searchTerm}
            onChange={e => setSearchTerm(e.target.value)}
            className="w-full pl-9 pr-4 py-2 rounded-xl bg-slate-900 border border-slate-800 text-xs text-slate-200 focus:outline-none focus:border-purple-500"
          />
        </div>
      </div>

      {/* Drivers Table */}
      {activeTab === 'drivers' && (
        <div className="glass-panel rounded-2xl p-5 border border-slate-800 space-y-4">
          <div className="overflow-x-auto">
            <table className="w-full text-left text-xs">
              <thead>
                <tr className="border-b border-slate-800 text-slate-400 font-mono uppercase text-[10px]">
                  <th className="py-3 px-4">Driver Profile</th>
                  <th className="py-3 px-4">City & Vehicle</th>
                  <th className="py-3 px-4">Rating & Trips</th>
                  <th className="py-3 px-4">Wallet Balance</th>
                  <th className="py-3 px-4">Status</th>
                  <th className="py-3 px-4 text-right">Account Actions</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-slate-800/60">
                {filteredDrivers.map(drv => (
                  <tr key={drv.id} className="hover:bg-slate-900/60 transition-colors text-slate-300">
                    <td className="py-3 px-4">
                      <div className="flex items-center space-x-3">
                        <img src={drv.avatarUrl} alt={drv.fullName} className="w-9 h-9 rounded-full object-cover border border-slate-700" />
                        <div>
                          <div className="font-semibold text-slate-100">{drv.fullName}</div>
                          <div className="text-[11px] text-slate-400">{drv.phone}</div>
                        </div>
                      </div>
                    </td>
                    <td className="py-3 px-4">
                      <div className="text-slate-200 font-medium">{drv.operatingCity}</div>
                      <div className="text-[11px] text-purple-400 font-mono">{drv.vehicleMake} {drv.vehicleModel} [{drv.vehiclePlate}]</div>
                    </td>
                    <td className="py-3 px-4 font-mono">
                      <div className="flex items-center space-x-1 text-amber-400">
                        <Star className="w-3.5 h-3.5 fill-amber-400 text-amber-400" />
                        <span className="font-bold">{drv.rating.toFixed(2)}</span>
                      </div>
                      <div className="text-[10px] text-slate-500">{drv.totalTrips} completed trips</div>
                    </td>
                    <td className="py-3 px-4 font-mono font-bold text-emerald-400">
                      R{drv.walletBalance.toFixed(2)}
                    </td>
                    <td className="py-3 px-4">
                      <span className={`px-2.5 py-1 rounded-full text-[10px] font-mono font-bold uppercase border ${
                        drv.driverStatus === 'approved' ? 'bg-emerald-500/20 text-emerald-400 border-emerald-500/30' : 'bg-red-500/20 text-red-400 border-red-500/30'
                      }`}>
                        {drv.driverStatus}
                      </span>
                    </td>
                    <td className="py-3 px-4 text-right space-x-2">
                      <button
                        onClick={() => setWalletModalUser({ id: drv.id, name: drv.fullName, isDriver: true, currentBalance: drv.walletBalance })}
                        className="px-2.5 py-1 rounded-lg bg-emerald-600/20 border border-emerald-500/30 text-emerald-300 hover:bg-emerald-600/40 text-[11px] font-semibold"
                      >
                        Adjust Wallet
                      </button>
                      <button
                        onClick={() => toggleUserStatus(drv.id, true)}
                        className={`px-2.5 py-1 rounded-lg text-[11px] font-semibold transition-colors border ${
                          drv.driverStatus === 'approved'
                            ? 'bg-red-500/10 border-red-500/30 text-red-400 hover:bg-red-500/20'
                            : 'bg-emerald-500/10 border-emerald-500/30 text-emerald-400 hover:bg-emerald-500/20'
                        }`}
                      >
                        {drv.driverStatus === 'approved' ? 'Suspend' : 'Activate'}
                      </button>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </div>
      )}

      {/* Passengers Table */}
      {activeTab === 'passengers' && (
        <div className="glass-panel rounded-2xl p-5 border border-slate-800 space-y-4">
          <div className="overflow-x-auto">
            <table className="w-full text-left text-xs">
              <thead>
                <tr className="border-b border-slate-800 text-slate-400 font-mono uppercase text-[10px]">
                  <th className="py-3 px-4">Passenger Profile</th>
                  <th className="py-3 px-4">Emergency Contact</th>
                  <th className="py-3 px-4">Rating & Rides</th>
                  <th className="py-3 px-4">Wallet Balance</th>
                  <th className="py-3 px-4">Status</th>
                  <th className="py-3 px-4 text-right">Account Actions</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-slate-800/60">
                {filteredPassengers.map(pas => (
                  <tr key={pas.id} className="hover:bg-slate-900/60 transition-colors text-slate-300">
                    <td className="py-3 px-4">
                      <div className="flex items-center space-x-3">
                        <img src={pas.avatarUrl} alt={pas.fullName} className="w-9 h-9 rounded-full object-cover border border-slate-700" />
                        <div>
                          <div className="font-semibold text-slate-100">{pas.fullName}</div>
                          <div className="text-[11px] text-slate-400">{pas.phone} • {pas.email}</div>
                        </div>
                      </div>
                    </td>
                    <td className="py-3 px-4 text-slate-300">
                      <div>{pas.emergencyContactName}</div>
                      <div className="text-[10px] text-slate-400 font-mono">{pas.emergencyContactPhone}</div>
                    </td>
                    <td className="py-3 px-4 font-mono">
                      <div className="flex items-center space-x-1 text-amber-400">
                        <Star className="w-3.5 h-3.5 fill-amber-400 text-amber-400" />
                        <span className="font-bold">{pas.rating.toFixed(2)}</span>
                      </div>
                      <div className="text-[10px] text-slate-500">{pas.totalRides} rides</div>
                    </td>
                    <td className="py-3 px-4 font-mono font-bold text-emerald-400">
                      R{pas.walletBalance.toFixed(2)}
                    </td>
                    <td className="py-3 px-4">
                      <span className={`px-2.5 py-1 rounded-full text-[10px] font-mono font-bold uppercase border ${
                        pas.status === 'active' ? 'bg-emerald-500/20 text-emerald-400 border-emerald-500/30' : 'bg-red-500/20 text-red-400 border-red-500/30'
                      }`}>
                        {pas.status}
                      </span>
                    </td>
                    <td className="py-3 px-4 text-right space-x-2">
                      <button
                        onClick={() => setWalletModalUser({ id: pas.id, name: pas.fullName, isDriver: false, currentBalance: pas.walletBalance })}
                        className="px-2.5 py-1 rounded-lg bg-emerald-600/20 border border-emerald-500/30 text-emerald-300 hover:bg-emerald-600/40 text-[11px] font-semibold"
                      >
                        Adjust Wallet
                      </button>
                      <button
                        onClick={() => toggleUserStatus(pas.id, false)}
                        className={`px-2.5 py-1 rounded-lg text-[11px] font-semibold transition-colors border ${
                          pas.status === 'active'
                            ? 'bg-red-500/10 border-red-500/30 text-red-400 hover:bg-red-500/20'
                            : 'bg-emerald-500/10 border-emerald-500/30 text-emerald-400 hover:bg-emerald-500/20'
                        }`}
                      >
                        {pas.status === 'active' ? 'Suspend' : 'Activate'}
                      </button>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </div>
      )}

      {/* Wallet Adjustment Modal */}
      {walletModalUser && (
        <div className="fixed inset-0 bg-slate-950/80 backdrop-blur-sm z-50 flex items-center justify-center p-4">
          <div className="glass-panel w-full max-w-md rounded-2xl p-6 border border-slate-800 shadow-2xl space-y-4 animate-in zoom-in-95">
            <div className="flex items-center justify-between border-b border-slate-800 pb-3">
              <h3 className="font-heading font-bold text-white flex items-center space-x-2">
                <Wallet className="w-5 h-5 text-emerald-400" />
                <span>Adjust User Wallet Balance</span>
              </h3>
              <button onClick={() => setWalletModalUser(null)} className="text-slate-400 hover:text-white">✕</button>
            </div>

            <form onSubmit={handleWalletSubmit} className="space-y-4 text-xs">
              <div className="p-3 rounded-xl bg-slate-900 border border-slate-800 space-y-1">
                <div className="text-slate-400">Target User: <strong className="text-white">{walletModalUser.name}</strong></div>
                <div className="text-slate-400">Current Balance: <strong className="text-emerald-400 font-mono">R{walletModalUser.currentBalance.toFixed(2)}</strong></div>
              </div>

              <div className="grid grid-cols-2 gap-3">
                <button
                  type="button"
                  onClick={() => setAdjustType('add')}
                  className={`p-2.5 rounded-xl border font-bold flex items-center justify-center space-x-2 ${
                    adjustType === 'add' ? 'bg-emerald-600/30 border-emerald-500 text-emerald-300' : 'bg-slate-900 border-slate-800 text-slate-400'
                  }`}
                >
                  <PlusCircle className="w-4 h-4" />
                  <span>Credit (+)</span>
                </button>
                <button
                  type="button"
                  onClick={() => setAdjustType('deduct')}
                  className={`p-2.5 rounded-xl border font-bold flex items-center justify-center space-x-2 ${
                    adjustType === 'deduct' ? 'bg-red-600/30 border-red-500 text-red-300' : 'bg-slate-900 border-slate-800 text-slate-400'
                  }`}
                >
                  <MinusCircle className="w-4 h-4" />
                  <span>Debit (-)</span>
                </button>
              </div>

              <div>
                <label className="block text-slate-300 font-semibold mb-1">Adjustment Amount (ZAR)</label>
                <input
                  type="number"
                  step="10"
                  value={adjustAmount}
                  onChange={e => setAdjustAmount(parseFloat(e.target.value) || 0)}
                  className="w-full px-3 py-2 rounded-xl bg-slate-900 border border-slate-800 text-slate-200 font-mono font-bold focus:outline-none focus:border-emerald-500"
                />
              </div>

              <div>
                <label className="block text-slate-300 font-semibold mb-1">Audit Reason</label>
                <textarea
                  rows={2}
                  value={adjustReason}
                  onChange={e => setAdjustReason(e.target.value)}
                  className="w-full px-3 py-2 rounded-xl bg-slate-900 border border-slate-800 text-slate-200 focus:outline-none focus:border-emerald-500"
                />
              </div>

              <div className="flex justify-end space-x-3 pt-2">
                <button type="button" onClick={() => setWalletModalUser(null)} className="px-4 py-2 rounded-xl bg-slate-800 text-slate-300">
                  Cancel
                </button>
                <button type="submit" className="px-4 py-2 rounded-xl bg-emerald-600 text-white font-bold hover:bg-emerald-500 shadow-lg shadow-emerald-500/20">
                  Execute Balance Adjustment
                </button>
              </div>
            </form>
          </div>
        </div>
      )}
    </div>
  );
};
