import React, { createContext, useContext, useState, useEffect, useCallback } from 'react';
import type {
  AdminRole,
  DriverProfile,
  PassengerProfile,
  Ride,
  FareSchema,
  PayoutSettlement,
  AdminAuditLog,
  DriverStatus,
  DocumentStatus,
} from '../types/admin';
import {
  fetchDrivers,
  fetchPassengers,
  fetchRides,
  fetchFareSchemas,
  fetchPayouts,
  fetchAuditLogs,
  dbUpdateDriverStatus,
  dbUpdateDocumentStatus,
  dbUpdateFareSchema,
  dbAssignDriverToRide,
  dbCancelRide,
  dbVerifyPayout,
  dbAdjustWallet,
  dbToggleUserStatus,
  dbInsertAuditLog,
} from '../lib/queries';
import { supabase } from '../lib/supabase';
import { useAuth } from './AuthContext';

export type ActiveTab = 'dashboard' | 'kyc' | 'fleet' | 'fares' | 'payouts' | 'users' | 'audit';

export interface AdminNotification {
  id: string;
  type: 'info' | 'success' | 'warning' | 'error';
  title: string;
  message: string;
  timestamp: string;
  read: boolean;
}

interface AdminContextType {
  activeTab: ActiveTab;
  setActiveTab: (tab: ActiveTab) => void;
  currentRole: AdminRole;
  setCurrentRole: (role: AdminRole) => void;

  // Loading & error states
  loading: boolean;
  error: string | null;
  refresh: () => void;

  // Data
  drivers: DriverProfile[];
  passengers: PassengerProfile[];
  rides: Ride[];
  fareSchemas: FareSchema[];
  payouts: PayoutSettlement[];
  auditLogs: AdminAuditLog[];
  notifications: AdminNotification[];
  isRealtimeLive: boolean;
  setIsRealtimeLive: (live: boolean) => void;

  // Actions
  approveDriver: (driverId: string) => Promise<void>;
  rejectDriver: (driverId: string, reason: string) => Promise<void>;
  flagDriverDocument: (driverId: string, docId: string, issueNotes: string) => Promise<void>;
  approveDriverDocument: (driverId: string, docId: string) => Promise<void>;
  updateFareSchema: (schemaId: string, updates: Partial<FareSchema>) => Promise<void>;
  assignDriverToRide: (rideId: string, driverId: string) => Promise<void>;
  cancelRide: (rideId: string, reason: string) => Promise<void>;
  verifyPayout: (payoutId: string) => Promise<void>;
  adjustUserWallet: (userId: string, amount: number, isDriver: boolean, reason: string) => Promise<void>;
  toggleUserStatus: (userId: string, isDriver: boolean) => Promise<void>;
  markNotificationsRead: () => void;
  addNotification: (n: Omit<AdminNotification, 'id' | 'read'>) => void;
}

const AdminContext = createContext<AdminContextType | undefined>(undefined);

export const AdminProvider: React.FC<{ children: React.ReactNode }> = ({ children }) => {
  const { user } = useAuth();

  const [activeTab, setActiveTab] = useState<ActiveTab>('dashboard');
  const [currentRole, setCurrentRole] = useState<AdminRole>('super_admin');
  const [isRealtimeLive, setIsRealtimeLive] = useState(true);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  const [drivers, setDrivers] = useState<DriverProfile[]>([]);
  const [passengers, setPassengers] = useState<PassengerProfile[]>([]);
  const [rides, setRides] = useState<Ride[]>([]);
  const [fareSchemas, setFareSchemas] = useState<FareSchema[]>([]);
  const [payouts, setPayouts] = useState<PayoutSettlement[]>([]);
  const [auditLogs, setAuditLogs] = useState<AdminAuditLog[]>([]);
  const [notifications, setNotifications] = useState<AdminNotification[]>([]);

  // ── Initial data load ──────────────────────────────────────────────────────
  const loadAll = useCallback(async () => {
    setLoading(true);
    setError(null);
    try {
      const [d, p, r, f, pay, logs] = await Promise.all([
        fetchDrivers(),
        fetchPassengers(),
        fetchRides(),
        fetchFareSchemas(),
        fetchPayouts(),
        fetchAuditLogs(),
      ]);
      setDrivers(d);
      setPassengers(p);
      setRides(r);
      setFareSchemas(f);
      setPayouts(pay);
      setAuditLogs(logs);
    } catch (e: unknown) {
      setError(e instanceof Error ? e.message : 'Failed to load data');
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    loadAll();
  }, [loadAll]);

  // ── Supabase Realtime subscriptions ───────────────────────────────────────
  useEffect(() => {
    if (!isRealtimeLive) return;

    const ridesChannel = supabase
      .channel('admin-rides')
      .on('postgres_changes', { event: '*', schema: 'public', table: 'rides' }, () => {
        fetchRides().then(setRides).catch(console.error);
      })
      .subscribe();

    const profilesChannel = supabase
      .channel('admin-profiles')
      .on('postgres_changes', { event: '*', schema: 'public', table: 'profiles' }, () => {
        fetchDrivers().then(setDrivers).catch(console.error);
        fetchPassengers().then(setPassengers).catch(console.error);
      })
      .subscribe();

    const logsChannel = supabase
      .channel('admin-audit-logs')
      .on('postgres_changes', { event: 'INSERT', schema: 'public', table: 'admin_audit_logs' }, (payload) => {
        const newLog: AdminAuditLog = {
          id: payload.new.id,
          adminRole: payload.new.admin_role as AdminRole,
          adminName: payload.new.admin_email ?? 'Admin',
          action: payload.new.action,
          targetId: payload.new.target_id,
          targetType: payload.new.target_type,
          details: payload.new.details ?? '',
          ipAddress: payload.new.ip_address ?? '',
          timestamp: payload.new.created_at,
        };
        setAuditLogs((prev) => [newLog, ...prev]);
      })
      .subscribe();

    return () => {
      supabase.removeChannel(ridesChannel);
      supabase.removeChannel(profilesChannel);
      supabase.removeChannel(logsChannel);
    };
  }, [isRealtimeLive]);

  // ── Audit log helper ───────────────────────────────────────────────────────
  const writeAuditLog = useCallback(
    async (action: string, targetId: string, targetType: string, details: string) => {
      if (!user) return;
      await dbInsertAuditLog({
        adminId: user.id,
        adminEmail: user.email,
        adminRole: currentRole,
        action,
        targetId,
        targetType,
        details,
        ipAddress: 'client',
      });
    },
    [user, currentRole]
  );

  const addNotification = (n: Omit<AdminNotification, 'id' | 'read'>) => {
    setNotifications((prev) => [
      { ...n, id: `notif-${Date.now()}`, read: false },
      ...prev,
    ]);
  };

  // ── Actions ────────────────────────────────────────────────────────────────
  const approveDriver = async (driverId: string) => {
    await dbUpdateDriverStatus(driverId, 'approved');
    setDrivers((prev) =>
      prev.map((d) => (d.id === driverId ? { ...d, driverStatus: 'approved' as DriverStatus } : d))
    );
    const name = drivers.find((d) => d.id === driverId)?.fullName ?? driverId;
    await writeAuditLog('APPROVE_DRIVER', driverId, 'driver', `Approved KYC application for ${name}.`);
    addNotification({ type: 'success', title: 'Driver Approved', message: `${name} has been verified.`, timestamp: new Date().toISOString() });
  };

  const rejectDriver = async (driverId: string, reason: string) => {
    await dbUpdateDriverStatus(driverId, 'rejected');
    setDrivers((prev) =>
      prev.map((d) => (d.id === driverId ? { ...d, driverStatus: 'rejected' as DriverStatus } : d))
    );
    const name = drivers.find((d) => d.id === driverId)?.fullName ?? driverId;
    await writeAuditLog('REJECT_DRIVER', driverId, 'driver', `Rejected application for ${name}. Reason: ${reason}`);
    addNotification({ type: 'warning', title: 'Driver Rejected', message: `${name}: ${reason}`, timestamp: new Date().toISOString() });
  };

  const flagDriverDocument = async (driverId: string, docId: string, issueNotes: string) => {
    await dbUpdateDocumentStatus(docId, 'flagged', issueNotes);
    setDrivers((prev) =>
      prev.map((d) => {
        if (d.id !== driverId) return d;
        return {
          ...d,
          driverStatus: 'flagged' as DriverStatus,
          documents: d.documents.map((doc) =>
            doc.id === docId ? { ...doc, status: 'flagged' as DocumentStatus, issueNotes } : doc
          ),
        };
      })
    );
    const doc = drivers.find((d) => d.id === driverId)?.documents.find((x) => x.id === docId);
    await writeAuditLog('FLAG_DOCUMENT', docId, 'driver_document', `Flagged "${doc?.title}": ${issueNotes}`);
    addNotification({ type: 'warning', title: 'Document Flagged', message: `${doc?.title ?? docId}: ${issueNotes}`, timestamp: new Date().toISOString() });
  };

  const approveDriverDocument = async (driverId: string, docId: string) => {
    await dbUpdateDocumentStatus(docId, 'approved');
    setDrivers((prev) =>
      prev.map((d) => {
        if (d.id !== driverId) return d;
        return {
          ...d,
          documents: d.documents.map((doc) =>
            doc.id === docId ? { ...doc, status: 'approved' as DocumentStatus } : doc
          ),
        };
      })
    );
    const doc = drivers.find((d) => d.id === driverId)?.documents.find((x) => x.id === docId);
    await writeAuditLog('APPROVE_DOCUMENT', docId, 'driver_document', `Approved document "${doc?.title}"`);
  };

  const updateFareSchema = async (schemaId: string, updates: Partial<FareSchema>) => {
    await dbUpdateFareSchema(schemaId, {
      base_fare: updates.baseFare,
      per_km_rate: updates.perKmRate,
      min_fare: updates.minFare,
      per_minute_rate: updates.perMinuteRate,
      commission_percentage: updates.commissionPercentage,
      surge_multiplier: updates.surgeMultiplier,
    });
    setFareSchemas((prev) =>
      prev.map((s) => (s.id === schemaId ? { ...s, ...updates, updatedAt: new Date().toISOString() } : s))
    );
    const schema = fareSchemas.find((s) => s.id === schemaId);
    await writeAuditLog('UPDATE_FARE_SCHEMA', schemaId, 'fare_schema', `Updated ${schema?.tier} pricing: ${JSON.stringify(updates)}`);
  };

  const assignDriverToRide = async (rideId: string, driverId: string) => {
    await dbAssignDriverToRide(rideId, driverId);
    const drv = drivers.find((d) => d.id === driverId);
    setRides((prev) =>
      prev.map((r) =>
        r.id === rideId
          ? { ...r, driverId: drv?.id, driverName: drv?.fullName, driverPhone: drv?.phone, driverPlate: drv?.vehiclePlate, status: 'accepted' }
          : r
      )
    );
    await writeAuditLog('MANUAL_RIDE_ASSIGNMENT', rideId, 'ride', `Assigned ${drv?.fullName} (${drv?.vehiclePlate}) to trip ${rideId}`);
  };

  const cancelRide = async (rideId: string, reason: string) => {
    await dbCancelRide(rideId);
    setRides((prev) => prev.map((r) => (r.id === rideId ? { ...r, status: 'cancelled' } : r)));
    await writeAuditLog('EMERGENCY_RIDE_CANCEL', rideId, 'ride', `Cancelled trip ${rideId}. Reason: ${reason}`);
    addNotification({ type: 'error', title: 'Ride Cancelled', message: `Trip ${rideId} cancelled: ${reason}`, timestamp: new Date().toISOString() });
  };

  const verifyPayout = async (payoutId: string) => {
    if (!user) return;
    await dbVerifyPayout(payoutId, user.id);
    setPayouts((prev) =>
      prev.map((p) => (p.id === payoutId ? { ...p, status: 'verified', updatedAt: new Date().toISOString() } : p))
    );
    const p = payouts.find((x) => x.id === payoutId);
    await writeAuditLog('VERIFY_PAYOUT', payoutId, 'payout_settlement', `Verified payout of R${p?.netPayout.toFixed(2)} to ${p?.driverName}`);
    addNotification({ type: 'success', title: 'Payout Verified', message: `R${p?.netPayout.toFixed(2)} to ${p?.driverName} marked verified.`, timestamp: new Date().toISOString() });
  };

  const adjustUserWallet = async (userId: string, amount: number, isDriver: boolean, reason: string) => {
    await dbAdjustWallet(userId, amount);
    if (isDriver) {
      setDrivers((prev) => prev.map((d) => (d.id === userId ? { ...d, walletBalance: d.walletBalance + amount } : d)));
    } else {
      setPassengers((prev) => prev.map((p) => (p.id === userId ? { ...p, walletBalance: p.walletBalance + amount } : p)));
    }
    await writeAuditLog('ADJUST_WALLET', userId, isDriver ? 'driver' : 'passenger', `Adjusted wallet by R${amount}. Reason: ${reason}`);
  };

  const toggleUserStatus = async (userId: string, isDriver: boolean) => {
    if (isDriver) {
      const drv = drivers.find((d) => d.id === userId);
      await dbToggleUserStatus(userId, true, drv?.driverStatus ?? 'approved');
      setDrivers((prev) =>
        prev.map((d) => {
          if (d.id !== userId) return d;
          const next: DriverStatus = d.driverStatus === 'approved' ? 'rejected' : 'approved';
          return { ...d, driverStatus: next };
        })
      );
    } else {
      const pas = passengers.find((p) => p.id === userId);
      await dbToggleUserStatus(userId, false, pas?.status ?? 'active');
      setPassengers((prev) =>
        prev.map((p) => {
          if (p.id !== userId) return p;
          const next = p.status === 'active' ? 'suspended' : 'active';
          return { ...p, status: next };
        })
      );
    }
    await writeAuditLog('TOGGLE_USER_STATUS', userId, isDriver ? 'driver' : 'passenger', `Toggled account status`);
  };

  const markNotificationsRead = () => {
    setNotifications((prev) => prev.map((n) => ({ ...n, read: true })));
  };

  return (
    <AdminContext.Provider
      value={{
        activeTab,
        setActiveTab,
        currentRole,
        setCurrentRole,
        loading,
        error,
        refresh: loadAll,
        drivers,
        passengers,
        rides,
        fareSchemas,
        payouts,
        auditLogs,
        notifications,
        isRealtimeLive,
        setIsRealtimeLive,
        approveDriver,
        rejectDriver,
        flagDriverDocument,
        approveDriverDocument,
        updateFareSchema,
        assignDriverToRide,
        cancelRide,
        verifyPayout,
        adjustUserWallet,
        toggleUserStatus,
        markNotificationsRead,
        addNotification,
      }}
    >
      {children}
    </AdminContext.Provider>
  );
};

export const useAdmin = () => {
  const ctx = useContext(AdminContext);
  if (!ctx) throw new Error('useAdmin must be used within an AdminProvider');
  return ctx;
};
