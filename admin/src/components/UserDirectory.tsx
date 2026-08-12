import React, { useState } from 'react';
import { useAdmin } from '../context/AdminContext';
import {
  Users,
  Search,
  Wallet,
  Star,
  PlusCircle,
  MinusCircle,
  Edit,
  Trash2,
  AlertTriangle,
  Loader2,
} from 'lucide-react';
import type { DriverProfile, PassengerProfile } from '../types/admin';

export const UserDirectory: React.FC = () => {
  const {
    drivers,
    passengers,
    adjustUserWallet,
    toggleUserStatus,
    updateUserProfile,
    deleteUser,
    promoteUserToAdmin,
    addNotification,
    can,
  } = useAdmin();

  const canWriteUsers = can('users:write');
  const canManageAdmins = can('admin:manage');
  const canAdjustFinance = can('finance:write');

  const [activeTab, setActiveTab] = useState<'drivers' | 'passengers'>('drivers');
  const [searchTerm, setSearchTerm] = useState<string>('');

  // Inline row action pending state (Promote / Suspend / Activate)
  const [pendingIds, setPendingIds] = useState<Set<string>>(new Set());

  // Modal submitting state (Edit / Delete / Wallet)
  const [submitting, setSubmitting] = useState<boolean>(false);
  const [modalError, setModalError] = useState<string | null>(null);

  // Wallet adjustment modal state
  const [walletModalUser, setWalletModalUser] = useState<{
    id: string;
    name: string;
    isDriver: boolean;
    currentBalance: number;
  } | null>(null);
  const [adjustAmount, setAdjustAmount] = useState<number>(100);
  const [adjustType, setAdjustType] = useState<'add' | 'deduct'>('add');
  const [adjustReason, setAdjustReason] = useState<string>(
    'Administrative customer resolution credit'
  );

  // Edit user modal state
  const [editModalUser, setEditModalUser] = useState<{
    id: string;
    fullName: string;
    phone: string;
    email: string;
    isDriver: boolean;
    vehicleMake?: string;
    vehicleModel?: string;
    vehicleYear?: number;
    vehiclePlate?: string;
    vehicleColor?: string;
    operatingCity?: string;
    rating: number;
  } | null>(null);

  // Delete user modal state
  const [deleteModalUser, setDeleteModalUser] = useState<{
    id: string;
    name: string;
    isDriver: boolean;
  } | null>(null);

  const filteredDrivers = drivers.filter((d) => {
    if (!searchTerm) return true;
    const term = searchTerm.toLowerCase();
    return (
      d.fullName.toLowerCase().includes(term) ||
      d.email.toLowerCase().includes(term) ||
      d.phone.includes(term) ||
      d.vehiclePlate.toLowerCase().includes(term)
    );
  });

  const filteredPassengers = passengers.filter((p) => {
    if (!searchTerm) return true;
    const term = searchTerm.toLowerCase();
    return (
      p.fullName.toLowerCase().includes(term) ||
      p.email.toLowerCase().includes(term) ||
      p.phone.includes(term)
    );
  });

  const handleWalletSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!walletModalUser || submitting) return;
    const finalAmount =
      adjustType === 'add' ? Math.abs(adjustAmount) : -Math.abs(adjustAmount);
    setSubmitting(true);
    setModalError(null);
    try {
      await adjustUserWallet(
        walletModalUser.id,
        finalAmount,
        walletModalUser.isDriver,
        adjustReason
      );
      setWalletModalUser(null);
      setAdjustAmount(100);
    } catch (err) {
      setModalError(err instanceof Error ? err.message : 'Wallet adjustment failed');
    } finally {
      setSubmitting(false);
    }
  };

  const handleEditSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!editModalUser || submitting) return;
    setSubmitting(true);
    setModalError(null);
    try {
      await updateUserProfile(editModalUser.id, editModalUser.isDriver, {
        fullName: editModalUser.fullName,
        phone: editModalUser.phone,
        vehicleMake: editModalUser.vehicleMake,
        vehicleModel: editModalUser.vehicleModel,
        vehicleYear: editModalUser.vehicleYear,
        vehiclePlate: editModalUser.vehiclePlate,
        vehicleColor: editModalUser.vehicleColor,
        operatingCity: editModalUser.operatingCity,
        rating: editModalUser.rating,
      });
      setEditModalUser(null);
    } catch (err) {
      setModalError(err instanceof Error ? err.message : 'Failed to save profile changes');
    } finally {
      setSubmitting(false);
    }
  };

  const handleDeleteSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!deleteModalUser || submitting) return;
    setSubmitting(true);
    setModalError(null);
    try {
      await deleteUser(deleteModalUser.id, deleteModalUser.isDriver);
      setDeleteModalUser(null);
    } catch (err) {
      setModalError(err instanceof Error ? err.message : 'Failed to delete user');
    } finally {
      setSubmitting(false);
    }
  };

  const handlePromote = async (userId: string) => {
    if (pendingIds.has(userId)) return;
    setPendingIds((prev) => new Set(prev).add(userId));
    try {
      await promoteUserToAdmin(userId);
    } catch (err) {
      addNotification({
        type: 'error',
        title: 'Promotion Failed',
        message: err instanceof Error ? err.message : 'Failed to promote user to admin.',
        timestamp: new Date().toISOString(),
      });
    } finally {
      setPendingIds((prev) => {
        const next = new Set(prev);
        next.delete(userId);
        return next;
      });
    }
  };

  const handleToggleStatus = async (userId: string, isDriver: boolean) => {
    if (pendingIds.has(userId)) return;
    setPendingIds((prev) => new Set(prev).add(userId));
    try {
      await toggleUserStatus(userId, isDriver);
    } catch (err) {
      addNotification({
        type: 'error',
        title: 'Status Update Failed',
        message: err instanceof Error ? err.message : 'Failed to update account status.',
        timestamp: new Date().toISOString(),
      });
    } finally {
      setPendingIds((prev) => {
        const next = new Set(prev);
        next.delete(userId);
        return next;
      });
    }
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
          <h1 className="text-2xl font-bold font-heading text-white">
            User Directory & Account Control
          </h1>
          <p className="text-slate-400 text-xs mt-1">
            Manage profile fields and legacy account credits. Authoritative driver ride balances are in Driver Wallets.
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
            onChange={(e) => setSearchTerm(e.target.value)}
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
                  <th className="py-3 px-4">Legacy Account Credit</th>
                  <th className="py-3 px-4">Status</th>
                  <th className="py-3 px-4 text-right">Account Actions</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-slate-800/60">
                {filteredDrivers.map((drv: DriverProfile) => (
                  <tr
                    key={drv.id}
                    className="hover:bg-slate-900/60 transition-colors text-slate-300"
                  >
                    <td className="py-3 px-4">
                      <div className="flex items-center space-x-3">
                        <img
                          src={drv.avatarUrl}
                          alt={drv.fullName}
                          className="w-9 h-9 rounded-full object-cover border border-slate-700"
                        />
                        <div>
                          <div className="font-semibold text-slate-100">{drv.fullName}</div>
                          <div className="text-[11px] text-slate-400">{drv.phone}</div>
                          <div className="text-[10px] text-slate-500">{drv.email}</div>
                        </div>
                      </div>
                    </td>
                    <td className="py-3 px-4">
                      <div className="text-slate-200 font-medium">{drv.operatingCity || 'Not specified'}</div>
                      <div className="text-[11px] text-purple-400 font-mono">
                        {drv.vehicleMake} {drv.vehicleModel} [{drv.vehiclePlate}]
                      </div>
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
                      <span
                        className={`px-2.5 py-1 rounded-full text-[10px] font-mono font-bold uppercase border ${
                          drv.driverStatus === 'approved'
                            ? 'bg-emerald-500/20 text-emerald-400 border-emerald-500/30'
                            : 'bg-red-500/20 text-red-400 border-red-500/30'
                        }`}
                      >
                        {drv.driverStatus}
                      </span>
                    </td>
                    <td className="py-3 px-4 text-right space-x-1.5">
                    <button
                      onClick={() => handlePromote(drv.id)}
                      disabled={!canManageAdmins || pendingIds.has(drv.id)}
                      title="Promote to Admin"
                      className="px-2 py-1 rounded-lg bg-amber-600/20 border border-amber-500/30 text-amber-300 hover:bg-amber-600/40 text-[11px] font-semibold disabled:opacity-50 disabled:cursor-not-allowed flex items-center space-x-1"
                    >
                      {pendingIds.has(drv.id) ? (
                        <Loader2 className="w-3 h-3 animate-spin" />
                      ) : null}
                      <span>Promote</span>
                    </button>
                    <button
                      onClick={() => {
                        setModalError(null);
                        setEditModalUser({
                          id: drv.id,

                            fullName: drv.fullName,
                            phone: drv.phone,
                            email: drv.email,
                            isDriver: true,
                            vehicleMake: drv.vehicleMake,
                            vehicleModel: drv.vehicleModel,
                            vehicleYear: drv.vehicleYear,
                            vehiclePlate: drv.vehiclePlate,
                            vehicleColor: drv.vehicleColor,
                            operatingCity: drv.operatingCity,
                            rating: drv.rating,
                          });
                        }}
                        title="Edit Driver Profile"
                        disabled={!canWriteUsers}
                        className="px-2 py-1 rounded-lg bg-purple-600/20 border border-purple-500/30 text-purple-300 hover:bg-purple-600/40 text-[11px] font-semibold disabled:opacity-50 disabled:cursor-not-allowed"
                      >
                        <Edit className="w-3.5 h-3.5 inline mr-1" />
                        Edit
                      </button>
                      <button
                        onClick={() => {
                          setModalError(null);
                          setWalletModalUser({
                            id: drv.id,
                            name: drv.fullName,
                            isDriver: true,
                            currentBalance: drv.walletBalance,
                          });
                        }}
                        disabled={!canAdjustFinance}
                        className="px-2 py-1 rounded-lg bg-emerald-600/20 border border-emerald-500/30 text-emerald-300 hover:bg-emerald-600/40 text-[11px] font-semibold disabled:opacity-50 disabled:cursor-not-allowed"
                      >
                        Legacy Credit
                      </button>
                      <button
                        onClick={() => handleToggleStatus(drv.id, true)}
                        disabled={!canWriteUsers || pendingIds.has(drv.id)}
                        className={`px-2 py-1 rounded-lg text-[11px] font-semibold transition-colors border flex items-center space-x-1 disabled:opacity-50 disabled:cursor-not-allowed ${
                          drv.driverStatus === 'approved'
                            ? 'bg-red-500/10 border-red-500/30 text-red-400 hover:bg-red-500/20'
                            : 'bg-emerald-500/10 border-emerald-500/30 text-emerald-400 hover:bg-emerald-500/20'
                        }`}
                      >
                        {pendingIds.has(drv.id) ? (
                          <Loader2 className="w-3 h-3 animate-spin" />
                        ) : null}
                        <span>{drv.driverStatus === 'approved' ? 'Suspend' : 'Activate'}</span>
                      </button>
                      <button
                        onClick={() => {
                          setModalError(null);
                          setDeleteModalUser({
                            id: drv.id,
                            name: drv.fullName,
                            isDriver: true,
                          });
                        }}
                        title="Delete User Account"
                        disabled={!canWriteUsers}
                        className="p-1 rounded-lg bg-red-500/10 border border-red-500/30 text-red-400 hover:bg-red-500/20 transition-colors"
                      >
                        <Trash2 className="w-3.5 h-3.5" />
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
                  <th className="py-3 px-4">Legacy Account Credit</th>
                  <th className="py-3 px-4">Status</th>
                  <th className="py-3 px-4 text-right">Account Actions</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-slate-800/60">
                {filteredPassengers.map((pas: PassengerProfile) => (
                  <tr
                    key={pas.id}
                    className="hover:bg-slate-900/60 transition-colors text-slate-300"
                  >
                    <td className="py-3 px-4">
                      <div className="flex items-center space-x-3">
                        <img
                          src={pas.avatarUrl}
                          alt={pas.fullName}
                          className="w-9 h-9 rounded-full object-cover border border-slate-700"
                        />
                        <div>
                          <div className="font-semibold text-slate-100">{pas.fullName}</div>
                          <div className="text-[11px] text-slate-400">{pas.phone}</div>
                          <div className="text-[10px] text-slate-500">{pas.email}</div>
                        </div>
                      </div>
                    </td>
                    <td className="py-3 px-4 text-slate-300">
                      <div>{pas.emergencyContactName || 'None'}</div>
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
                      <span
                        className={`px-2.5 py-1 rounded-full text-[10px] font-mono font-bold uppercase border ${
                          pas.status === 'active'
                            ? 'bg-emerald-500/20 text-emerald-400 border-emerald-500/30'
                            : 'bg-red-500/20 text-red-400 border-red-500/30'
                        }`}
                      >
                        {pas.status}
                      </span>
                    </td>
                    <td className="py-3 px-4 text-right space-x-1.5">
                      <button
                        onClick={() => handlePromote(pas.id)}
                        disabled={!canManageAdmins || pendingIds.has(pas.id)}
                        title="Promote to Admin"
                        className="px-2 py-1 rounded-lg bg-amber-600/20 border border-amber-500/30 text-amber-300 hover:bg-amber-600/40 text-[11px] font-semibold disabled:opacity-50 disabled:cursor-not-allowed flex items-center space-x-1"
                      >
                        {pendingIds.has(pas.id) ? (
                          <Loader2 className="w-3 h-3 animate-spin" />
                        ) : null}
                        <span>Promote</span>
                      </button>
                      <button
                        onClick={() => {
                          setModalError(null);
                          setEditModalUser({
                            id: pas.id,
                            fullName: pas.fullName,
                            phone: pas.phone,
                            email: pas.email,
                            isDriver: false,
                            rating: pas.rating,
                          });
                        }}
                        title="Edit Passenger Profile"
                        disabled={!canWriteUsers}
                        className="px-2 py-1 rounded-lg bg-purple-600/20 border border-purple-500/30 text-purple-300 hover:bg-purple-600/40 text-[11px] font-semibold disabled:opacity-50 disabled:cursor-not-allowed"
                      >
                        <Edit className="w-3.5 h-3.5 inline mr-1" />
                        Edit
                      </button>
                      <button
                        onClick={() => {
                          setModalError(null);
                          setWalletModalUser({
                            id: pas.id,
                            name: pas.fullName,
                            isDriver: false,
                            currentBalance: pas.walletBalance,
                          });
                        }}
                        disabled={!canAdjustFinance}
                        className="px-2 py-1 rounded-lg bg-emerald-600/20 border border-emerald-500/30 text-emerald-300 hover:bg-emerald-600/40 text-[11px] font-semibold disabled:opacity-50 disabled:cursor-not-allowed"
                      >
                        Legacy Credit
                      </button>
                      <button
                        onClick={() => handleToggleStatus(pas.id, false)}
                        disabled={!canWriteUsers || pendingIds.has(pas.id)}
                        className={`px-2 py-1 rounded-lg text-[11px] font-semibold transition-colors border flex items-center space-x-1 disabled:opacity-50 disabled:cursor-not-allowed ${
                          pas.status === 'active'
                            ? 'bg-red-500/10 border-red-500/30 text-red-400 hover:bg-red-500/20'
                            : 'bg-emerald-500/10 border-emerald-500/30 text-emerald-400 hover:bg-emerald-500/20'
                        }`}
                      >
                        {pendingIds.has(pas.id) ? (
                          <Loader2 className="w-3 h-3 animate-spin" />
                        ) : null}
                        <span>{pas.status === 'active' ? 'Suspend' : 'Activate'}</span>
                      </button>
                      <button
                        onClick={() => {
                          setModalError(null);
                          setDeleteModalUser({
                            id: pas.id,
                            name: pas.fullName,
                            isDriver: false,
                          });
                        }}
                        title="Delete User Account"
                        disabled={!canWriteUsers}
                        className="p-1 rounded-lg bg-red-500/10 border border-red-500/30 text-red-400 hover:bg-red-500/20 transition-colors"
                      >
                        <Trash2 className="w-3.5 h-3.5" />
                      </button>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </div>
      )}

      {/* Edit Profile Modal */}
      {editModalUser && (
        <div className="fixed inset-0 bg-slate-950/80 backdrop-blur-sm z-50 flex items-center justify-center p-4">
          <div className="glass-panel w-full max-w-lg rounded-2xl p-6 border border-slate-800 shadow-2xl space-y-4 animate-in zoom-in-95">
            <div className="flex items-center justify-between border-b border-slate-800 pb-3">
              <h3 className="font-heading font-bold text-white flex items-center space-x-2">
                <Edit className="w-5 h-5 text-purple-400" />
                <span>Edit {editModalUser.isDriver ? 'Driver' : 'Passenger'} Profile</span>
              </h3>
              <button
                onClick={() => setEditModalUser(null)}
                disabled={submitting}
                className="text-slate-400 hover:text-white disabled:opacity-40"
              >
                ✕
              </button>
            </div>

            <form onSubmit={handleEditSubmit} className="space-y-3 text-xs">
              <div className="grid grid-cols-2 gap-3">
                <div>
                  <label className="block text-slate-300 font-semibold mb-1">Full Name</label>
                  <input
                    type="text"
                    value={editModalUser.fullName}
                    onChange={(e) =>
                      setEditModalUser({ ...editModalUser, fullName: e.target.value })
                    }
                    className="w-full px-3 py-2 rounded-xl bg-slate-900 border border-slate-800 text-slate-200 focus:outline-none focus:border-purple-500"
                    required
                  />
                </div>
                <div>
                  <label className="block text-slate-300 font-semibold mb-1">Phone Number</label>
                  <input
                    type="text"
                    value={editModalUser.phone}
                    onChange={(e) =>
                      setEditModalUser({ ...editModalUser, phone: e.target.value })
                    }
                    className="w-full px-3 py-2 rounded-xl bg-slate-900 border border-slate-800 text-slate-200 focus:outline-none focus:border-purple-500"
                    required
                  />
                </div>
              </div>

              {editModalUser.isDriver && (
                <>
                  <div className="grid grid-cols-2 gap-3">
                    <div>
                      <label className="block text-slate-300 font-semibold mb-1">Vehicle Make</label>
                      <input
                        type="text"
                        value={editModalUser.vehicleMake || ''}
                        onChange={(e) =>
                          setEditModalUser({ ...editModalUser, vehicleMake: e.target.value })
                        }
                        className="w-full px-3 py-2 rounded-xl bg-slate-900 border border-slate-800 text-slate-200 focus:outline-none focus:border-purple-500"
                      />
                    </div>
                    <div>
                      <label className="block text-slate-300 font-semibold mb-1">Vehicle Model</label>
                      <input
                        type="text"
                        value={editModalUser.vehicleModel || ''}
                        onChange={(e) =>
                          setEditModalUser({ ...editModalUser, vehicleModel: e.target.value })
                        }
                        className="w-full px-3 py-2 rounded-xl bg-slate-900 border border-slate-800 text-slate-200 focus:outline-none focus:border-purple-500"
                      />
                    </div>
                  </div>

                  <div className="grid grid-cols-2 gap-3">
                    <div>
                      <label className="block text-slate-300 font-semibold mb-1">Number Plate</label>
                      <input
                        type="text"
                        value={editModalUser.vehiclePlate || ''}
                        onChange={(e) =>
                          setEditModalUser({ ...editModalUser, vehiclePlate: e.target.value })
                        }
                        className="w-full px-3 py-2 rounded-xl bg-slate-900 border border-slate-800 text-slate-200 font-mono focus:outline-none focus:border-purple-500"
                      />
                    </div>
                    <div>
                      <label className="block text-slate-300 font-semibold mb-1">Operating City</label>
                      <input
                        type="text"
                        value={editModalUser.operatingCity || ''}
                        onChange={(e) =>
                          setEditModalUser({ ...editModalUser, operatingCity: e.target.value })
                        }
                        className="w-full px-3 py-2 rounded-xl bg-slate-900 border border-slate-800 text-slate-200 focus:outline-none focus:border-purple-500"
                      />
                    </div>
                  </div>
                </>
              )}

              <div>
                <label className="block text-slate-300 font-semibold mb-1">
                  Rating (1.00 – 5.00)
                </label>
                <input
                  type="number"
                  step="0.1"
                  min="1"
                  max="5"
                  value={editModalUser.rating}
                  onChange={(e) =>
                    setEditModalUser({
                      ...editModalUser,
                      rating: parseFloat(e.target.value) || 5.0,
                    })
                  }
                  className="w-full px-3 py-2 rounded-xl bg-slate-900 border border-slate-800 text-slate-200 font-mono focus:outline-none focus:border-purple-500"
                />
              </div>

              {modalError && (
                <div className="p-3 rounded-xl bg-red-500/10 border border-red-500/30 text-red-400 text-[11px]">
                  {modalError}
                </div>
              )}

              <div className="flex justify-end space-x-3 pt-3 border-t border-slate-800">
                <button
                  type="button"
                  onClick={() => setEditModalUser(null)}
                  disabled={submitting}
                  className="px-4 py-2 rounded-xl bg-slate-800 text-slate-300 hover:bg-slate-700 disabled:opacity-50"
                >
                  Cancel
                </button>
                <button
                  type="submit"
                  disabled={submitting}
                  className="px-4 py-2 rounded-xl bg-purple-600 text-white font-bold hover:bg-purple-500 shadow-lg shadow-purple-500/20 disabled:opacity-50 disabled:cursor-not-allowed flex items-center space-x-2"
                >
                  {submitting && <Loader2 className="w-4 h-4 animate-spin" />}
                  <span>{submitting ? 'Saving...' : 'Save Profile Changes'}</span>
                </button>
              </div>
            </form>
          </div>
        </div>
      )}

      {/* Delete User Modal */}
      {deleteModalUser && (
        <div className="fixed inset-0 bg-slate-950/80 backdrop-blur-sm z-50 flex items-center justify-center p-4">
          <div className="glass-panel w-full max-w-md rounded-2xl p-6 border border-red-500/30 shadow-2xl space-y-4 animate-in zoom-in-95">
            <div className="flex items-center space-x-3 text-red-400">
              <AlertTriangle className="w-6 h-6 shrink-0" />
              <h3 className="font-heading font-bold text-white text-lg">
                Delete Account Permanently?
              </h3>
            </div>

            <p className="text-xs text-slate-300 leading-relaxed">
              Are you sure you want to delete <strong className="text-white">{deleteModalUser.name}</strong> from the database? This action will remove their profile record and cannot be undone.
            </p>

            {modalError && (
              <div className="p-3 rounded-xl bg-red-500/10 border border-red-500/30 text-red-400 text-[11px]">
                {modalError}
              </div>
            )}

            <form onSubmit={handleDeleteSubmit} className="flex justify-end space-x-3 pt-2">
              <button
                type="button"
                onClick={() => setDeleteModalUser(null)}
                disabled={submitting}
                className="px-4 py-2 rounded-xl bg-slate-800 text-slate-300 hover:bg-slate-700 text-xs disabled:opacity-50"
              >
                Cancel
              </button>
              <button
                type="submit"
                disabled={submitting}
                className="px-4 py-2 rounded-xl bg-red-600 hover:bg-red-500 text-white font-bold text-xs shadow-lg shadow-red-500/20 disabled:opacity-50 disabled:cursor-not-allowed flex items-center space-x-2"
              >
                {submitting && <Loader2 className="w-3.5 h-3.5 animate-spin" />}
                <span>{submitting ? 'Deleting...' : 'Confirm Delete'}</span>
              </button>
            </form>
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
                <span>Adjust Legacy Account Credit</span>
              </h3>
              <button
                onClick={() => setWalletModalUser(null)}
                disabled={submitting}
                className="text-slate-400 hover:text-white disabled:opacity-40"
              >
                ✕
              </button>
            </div>

            <form onSubmit={handleWalletSubmit} className="space-y-4 text-xs">
              <div className="p-3 rounded-xl bg-slate-900 border border-slate-800 space-y-1">
                <div className="text-slate-400">
                  Target User: <strong className="text-white">{walletModalUser.name}</strong>
                </div>
                <div className="text-slate-400">
                  Current Balance:{' '}
                  <strong className="text-emerald-400 font-mono">
                    R{walletModalUser.currentBalance.toFixed(2)}
                  </strong>
                </div>
              </div>

              <div className="grid grid-cols-2 gap-3">
                <button
                  type="button"
                  onClick={() => setAdjustType('add')}
                  className={`p-2.5 rounded-xl border font-bold flex items-center justify-center space-x-2 ${
                    adjustType === 'add'
                      ? 'bg-emerald-600/30 border-emerald-500 text-emerald-300'
                      : 'bg-slate-900 border-slate-800 text-slate-400'
                  }`}
                >
                  <PlusCircle className="w-4 h-4" />
                  <span>Credit (+)</span>
                </button>
                <button
                  type="button"
                  onClick={() => setAdjustType('deduct')}
                  className={`p-2.5 rounded-xl border font-bold flex items-center justify-center space-x-2 ${
                    adjustType === 'deduct'
                      ? 'bg-red-600/30 border-red-500 text-red-300'
                      : 'bg-slate-900 border-slate-800 text-slate-400'
                  }`}
                >
                  <MinusCircle className="w-4 h-4" />
                  <span>Debit (-)</span>
                </button>
              </div>

              <div>
                <label className="block text-slate-300 font-semibold mb-1">
                  Adjustment Amount (ZAR)
                </label>
                <input
                  type="number"
                  step="10"
                  value={adjustAmount}
                  onChange={(e) => setAdjustAmount(parseFloat(e.target.value) || 0)}
                  className="w-full px-3 py-2 rounded-xl bg-slate-900 border border-slate-800 text-slate-200 font-mono font-bold focus:outline-none focus:border-emerald-500"
                />
              </div>

              <div>
                <label className="block text-slate-300 font-semibold mb-1">Audit Reason</label>
                <textarea
                  rows={2}
                  value={adjustReason}
                  onChange={(e) => setAdjustReason(e.target.value)}
                  className="w-full px-3 py-2 rounded-xl bg-slate-900 border border-slate-800 text-slate-200 focus:outline-none focus:border-emerald-500"
                />
              </div>

              {modalError && (
                <div className="p-3 rounded-xl bg-red-500/10 border border-red-500/30 text-red-400 text-[11px]">
                  {modalError}
                </div>
              )}

              <div className="flex justify-end space-x-3 pt-2">
                <button
                  type="button"
                  onClick={() => setWalletModalUser(null)}
                  disabled={submitting}
                  className="px-4 py-2 rounded-xl bg-slate-800 text-slate-300 disabled:opacity-50"
                >
                  Cancel
                </button>
                <button
                  type="submit"
                  disabled={submitting}
                  className="px-4 py-2 rounded-xl bg-emerald-600 text-white font-bold hover:bg-emerald-500 shadow-lg shadow-emerald-500/20 disabled:opacity-50 disabled:cursor-not-allowed flex items-center space-x-2"
                >
                  {submitting && <Loader2 className="w-4 h-4 animate-spin" />}
                  <span>{submitting ? 'Adjusting...' : 'Execute Balance Adjustment'}</span>
                </button>
              </div>
            </form>
          </div>
        </div>
      )}
    </div>
  );
};
