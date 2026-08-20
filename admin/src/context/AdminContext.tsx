import React, { createContext, useContext, useState, useEffect, useCallback } from 'react';
import type {
  AdminRole,
  AdminUser,
  Refund,
  SafetyIncident,
  ScheduledRide,
  DriverProfile,
  PassengerProfile,
  PassengerVerification,
  Ride,
  FareSchema,
  PayoutSettlement,
  AdminAuditLog,
  DriverStatus,
  DocumentStatus,
  DriverWallet,
} from '../types/admin';
import {
  fetchDrivers,
  fetchDriverWallets,
  fetchPassengers,
  fetchPassengerVerifications,
  dbReviewPassengerVerification,
  fetchRides,
  fetchFareSchemas,
  fetchPayouts,
  fetchAuditLogs,
  fetchAdmins,
  fetchRefunds,
  processRefund,
  flagRefundDispute,
  fetchSafetyIncidents,
  acknowledgeIncident,
  resolveIncident,
  appendIncidentNote,
  fetchScheduledRides,
  rescheduleRide,
  cancelScheduledRide,
  dbUpdateDriverStatus,
  dbUpdateDocumentStatus,
  dbUpdateFareSchema,
  dbAssignDriverToRide,
  dbCancelRide,
  dbVerifyPayout,
  dbAdjustWallet,
  dbToggleUserStatus,
  dbUpdateUserProfile,
  dbDeleteUser,
  dbInsertAuditLog,
  dbAssignAdminRole,
  dbPromoteUserToAdmin,
  dbDemoteAdmin,
  dbBroadcastNotification,
  type BroadcastType,
  type BroadcastTarget,
} from '../lib/queries';
import { supabase } from '../lib/supabase';
import { useAuth } from './AuthContext';
import { hasPermission, type Permission } from '../lib/rbac';

export type ActiveTab = 'dashboard' | 'kyc' | 'passenger-verification' | 'fleet' | 'scheduled' | 'fares' | 'payouts' | 'wallets' | 'refunds' | 'users' | 'admin-users' | 'audit' | 'incidents' | 'broadcast' | 'statements';

const TAB_PERMISSIONS: Record<ActiveTab, Permission> = {
  dashboard: 'dashboard:read',
  kyc: 'kyc:read',
  'passenger-verification': 'kyc:read',
  fleet: 'fleet:read',
  scheduled: 'fleet:read',
  fares: 'fares:read',
  payouts: 'finance:read',
  wallets: 'finance:read',
  refunds: 'finance:read',
  users: 'users:read',
  'admin-users': 'admin:manage',
  audit: 'audit:read',
  incidents: 'fleet:read',
  broadcast: 'broadcast:write',
  statements: 'statements:read',
};

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
  user: { id: string; email: string } | null;
  can: (permission: Permission) => boolean;

  // Loading & error states
  loading: boolean;
  error: string | null;
  refresh: () => void;

  // Data
  drivers: DriverProfile[];
  passengers: PassengerProfile[];
  passengerVerifications: PassengerVerification[];
  rides: Ride[];
  fareSchemas: FareSchema[];
  payouts: PayoutSettlement[];
  driverWallets: DriverWallet[];
  admins: AdminUser[];
  refunds: Refund[];
  incidents: SafetyIncident[];
  scheduledRides: ScheduledRide[];
  auditLogs: AdminAuditLog[];
  notifications: AdminNotification[];
  isRealtimeLive: boolean;
  setIsRealtimeLive: (live: boolean) => void;

  // Actions
  approveDriver: (driverId: string) => Promise<void>;
  reviewPassengerVerification: (verificationId: string, status: 'approved' | 'rejected', notes?: string) => Promise<void>;
  rejectDriver: (driverId: string, reason: string) => Promise<void>;
  flagDriverDocument: (driverId: string, docId: string, issueNotes: string) => Promise<void>;
  approveDriverDocument: (driverId: string, docId: string) => Promise<void>;
  updateFareSchema: (schemaId: string, updates: Partial<FareSchema>) => Promise<void>;
  assignDriverToRide: (rideId: string, driverId: string) => Promise<void>;
  cancelRide: (rideId: string, reason: string) => Promise<void>;
  verifyPayout: (payoutId: string) => Promise<void>;
  adjustUserWallet: (userId: string, amount: number, isDriver: boolean, reason: string) => Promise<void>;
  toggleUserStatus: (userId: string, isDriver: boolean) => Promise<void>;
  updateUserProfile: (userId: string, isDriver: boolean, updates: Parameters<typeof dbUpdateUserProfile>[1]) => Promise<void>;
  promoteUserToAdmin: (userId: string) => Promise<void>;
  promoteUserToAdminScoped: (userId: string, adminRole: AdminRole, sourceRole: 'driver' | 'passenger') => Promise<void>;
  assignAdminRole: (adminId: string, adminRole: AdminRole) => Promise<void>;
  demoteAdmin: (adminId: string, fallbackRole: 'driver' | 'passenger') => Promise<void>;
  issueRefund: (params: { rideId: string; amount: number; reason: string; notes?: Record<string, unknown> }) => Promise<string>;
  disputeRefund: (refundId: string, reason: string) => Promise<void>;
  acknowledgeSafetyIncident: (incidentId: string) => Promise<void>;
  resolveSafetyIncident: (incidentId: string) => Promise<void>;
  addIncidentNote: (incidentId: string, note: string) => Promise<void>;
  rescheduleScheduledRide: (rideId: string, scheduledForIso: string, reason: string) => Promise<void>;
  cancelScheduledRideAction: (rideId: string, reason: string) => Promise<void>;
  deleteUser: (userId: string, isDriver: boolean) => Promise<void>;
  markNotificationsRead: () => void;
  addNotification: (n: Omit<AdminNotification, 'id' | 'read'>) => void;
  broadcastNotification: (params: {
    title: string;
    body: string;
    type: BroadcastType;
    routePath?: string | null;
    payload?: Record<string, unknown> | null;
    targetRole?: BroadcastTarget;
  }) => Promise<number>;
}

const AdminContext = createContext<AdminContextType | undefined>(undefined);

export const AdminProvider: React.FC<{ children: React.ReactNode }> = ({ children }) => {
  const { user } = useAuth();

  const [activeTabState, setActiveTabState] = useState<ActiveTab>('dashboard');
  const currentRole = user?.adminRole ?? 'super_admin';
  const can = useCallback(
    (permission: Permission) => hasPermission(currentRole, permission),
    [currentRole],
  );

  const setActiveTab = useCallback((tab: ActiveTab) => {
    if (hasPermission(currentRole, TAB_PERMISSIONS[tab])) {
      setActiveTabState(tab);
    }
  }, [currentRole]);

  const activeTab = hasPermission(currentRole, TAB_PERMISSIONS[activeTabState])
    ? activeTabState
    : 'dashboard';

  const requirePermission = useCallback((permission: Permission) => {
    if (!hasPermission(currentRole, permission)) {
      throw new Error('You do not have permission to perform this action.');
    }
  }, [currentRole]);
  const [isRealtimeLive, setIsRealtimeLive] = useState(true);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  const [drivers, setDrivers] = useState<DriverProfile[]>([]);
  const [passengers, setPassengers] = useState<PassengerProfile[]>([]);
  const [passengerVerifications, setPassengerVerifications] = useState<PassengerVerification[]>([]);
  const [rides, setRides] = useState<Ride[]>([]);
  const [fareSchemas, setFareSchemas] = useState<FareSchema[]>([]);
  const [payouts, setPayouts] = useState<PayoutSettlement[]>([]);
  const [driverWallets, setDriverWallets] = useState<DriverWallet[]>([]);
  const [admins, setAdmins] = useState<AdminUser[]>([]);
  const [refunds, setRefunds] = useState<Refund[]>([]);
  const [incidents, setIncidents] = useState<SafetyIncident[]>([]);
  const [scheduledRides, setScheduledRides] = useState<ScheduledRide[]>([]);
  const [auditLogs, setAuditLogs] = useState<AdminAuditLog[]>([]);
  const [notifications, setNotifications] = useState<AdminNotification[]>([]);

  // ── Initial data load ──────────────────────────────────────────────────────
  const loadAll = useCallback(async () => {
    setLoading(true);
    setError(null);
    try {
      // Do not let a restricted role fail the whole console because it cannot
      // read another department's sensitive tables.
      const [d, wallets, p, pv, r, f, pay, adminsList, refundsList, incidentsList, scheduledList, logs] = await Promise.all([
        can('users:read') || can('kyc:read') || can('fleet:read')
          ? fetchDrivers()
          : Promise.resolve([]),
        can('finance:read') ? fetchDriverWallets() : Promise.resolve([]),
        can('users:read') ? fetchPassengers() : Promise.resolve([]),
        can('kyc:read') ? fetchPassengerVerifications() : Promise.resolve([]),
        can('dashboard:read') || can('fleet:read') ? fetchRides() : Promise.resolve([]),
        can('fares:read') ? fetchFareSchemas() : Promise.resolve([]),
        can('finance:read') ? fetchPayouts() : Promise.resolve([]),
        can('admin:manage') ? fetchAdmins() : Promise.resolve([]),
        can('finance:read') ? fetchRefunds() : Promise.resolve([]),
        can('fleet:read') ? fetchSafetyIncidents() : Promise.resolve([]),
        can('fleet:read') || can('finance:read') ? fetchScheduledRides() : Promise.resolve([]),
        can('audit:read') ? fetchAuditLogs() : Promise.resolve([]),
      ]);
      setDrivers(d);
      setDriverWallets(wallets);
      setPassengers(p);
      setPassengerVerifications(pv);
      setRides(r);
      setFareSchemas(f);
      setPayouts(pay);
      setAdmins(adminsList);
      setRefunds(refundsList);
      setIncidents(incidentsList);
      setScheduledRides(scheduledList);
      setAuditLogs(logs);
    } catch (e: unknown) {
      setError(e instanceof Error ? e.message : 'Failed to load data');
    } finally {
      setLoading(false);
    }
  }, [can]);

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

    const walletsChannel = supabase
      .channel('admin-driver-wallets')
      .on('postgres_changes', { event: '*', schema: 'public', table: 'driver_wallets' }, () => {
        fetchDriverWallets().then(setDriverWallets).catch(console.error);
      })
      .subscribe();

    const refundsChannel = supabase
      .channel('admin-refunds')
      .on('postgres_changes', { event: '*', schema: 'public', table: 'refunds' }, () => {
        if (can('finance:read')) {
          fetchRefunds().then(setRefunds).catch(console.error);
        }
      })
      .subscribe();

    const incidentsChannel = supabase
      .channel('admin-incidents')
      .on('postgres_changes', { event: '*', schema: 'public', table: 'safety_incidents' }, () => {
        if (can('fleet:read')) {
          // Pull the SECURE view, not the base table, so we never request
          // internal_notes without the SECURITY DEFINER gate.
          fetchSafetyIncidents().then(setIncidents).catch(console.error);
        }
      })
      .subscribe();

    const scheduledChannel = supabase
      .channel('admin-scheduled-rides')
      .on('postgres_changes', { event: '*', schema: 'public', table: 'rides' }, () => {
        if (can('fleet:read') || can('finance:read')) {
          fetchScheduledRides().then(setScheduledRides).catch(console.error);
        }
      })
      .subscribe();

    const profilesChannel = supabase
      .channel('admin-profiles')
      .on('postgres_changes', { event: '*', schema: 'public', table: 'profiles' }, () => {
        fetchDrivers().then(setDrivers).catch(console.error);
        fetchPassengers().then(setPassengers).catch(console.error);
        if (can('admin:manage')) {
          fetchAdmins().then(setAdmins).catch(console.error);
        }
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
      supabase.removeChannel(walletsChannel);
      supabase.removeChannel(profilesChannel);
      supabase.removeChannel(refundsChannel);
      supabase.removeChannel(incidentsChannel);
      supabase.removeChannel(scheduledChannel);
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
  const reviewPassengerVerification = async (
    verificationId: string,
    status: 'approved' | 'rejected',
    notes?: string,
  ) => {
    requirePermission('kyc:write');
    await dbReviewPassengerVerification(verificationId, status, notes);
    setPassengerVerifications((prev) =>
      prev.map((v) => (v.id === verificationId ? { ...v, status, reviewNotes: notes } : v)),
    );
    const verification = passengerVerifications.find((v) => v.id === verificationId);
    setPassengers((prev) =>
      prev.map((p) => (p.id === verification?.passengerId ? { ...p, verificationStatus: status } : p)),
    );
    await writeAuditLog(
      status === 'approved' ? 'APPROVE_PASSENGER_VERIFICATION' : 'REJECT_PASSENGER_VERIFICATION',
      verificationId,
      'passenger_verification',
      `${status === 'approved' ? 'Approved' : 'Rejected'} passenger identity submission for ${verification?.passengerName ?? verificationId}.${notes ? ` Notes: ${notes}` : ''}`,
    );
    addNotification({
      type: status === 'approved' ? 'success' : 'warning',
      title: status === 'approved' ? 'Passenger Verified' : 'Passenger Verification Rejected',
      message: verification?.passengerName ?? verificationId,
      timestamp: new Date().toISOString(),
    });
  };

  const approveDriver = async (driverId: string) => {
    requirePermission('kyc:write');
    await dbUpdateDriverStatus(driverId, 'approved');
    setDrivers((prev) =>
      prev.map((d) => (d.id === driverId ? { ...d, driverStatus: 'approved' as DriverStatus } : d))
    );
    const name = drivers.find((d) => d.id === driverId)?.fullName ?? driverId;
    await writeAuditLog('APPROVE_DRIVER', driverId, 'driver', `Approved KYC application for ${name}.`);
    addNotification({ type: 'success', title: 'Driver Approved', message: `${name} has been verified.`, timestamp: new Date().toISOString() });
  };

  const rejectDriver = async (driverId: string, reason: string) => {
    requirePermission('kyc:write');
    await dbUpdateDriverStatus(driverId, 'rejected');
    setDrivers((prev) =>
      prev.map((d) => (d.id === driverId ? { ...d, driverStatus: 'rejected' as DriverStatus } : d))
    );
    const name = drivers.find((d) => d.id === driverId)?.fullName ?? driverId;
    await writeAuditLog('REJECT_DRIVER', driverId, 'driver', `Rejected application for ${name}. Reason: ${reason}`);
    addNotification({ type: 'warning', title: 'Driver Rejected', message: `${name}: ${reason}`, timestamp: new Date().toISOString() });
  };

  const flagDriverDocument = async (driverId: string, docId: string, issueNotes: string) => {
    requirePermission('kyc:write');
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
    requirePermission('kyc:write');
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
    requirePermission('fares:write');
    await dbUpdateFareSchema(schemaId, {
      base_fare: updates.baseFare,
      per_km_rate: updates.perKmRate,
      min_fare: updates.minFare,
      per_minute_rate: updates.perMinuteRate,
      extra_person_rate: updates.extraPersonRate,
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
    requirePermission('fleet:write');
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
    requirePermission('fleet:write');
    await dbCancelRide(rideId);
    setRides((prev) => prev.map((r) => (r.id === rideId ? { ...r, status: 'cancelled' } : r)));
    await writeAuditLog('EMERGENCY_RIDE_CANCEL', rideId, 'ride', `Cancelled trip ${rideId}. Reason: ${reason}`);
    addNotification({ type: 'error', title: 'Ride Cancelled', message: `Trip ${rideId} cancelled: ${reason}`, timestamp: new Date().toISOString() });
  };

  const verifyPayout = async (payoutId: string) => {
    requirePermission('finance:write');
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
    requirePermission('finance:write');
    await dbAdjustWallet(userId, amount);
    if (isDriver) {
      setDrivers((prev) => prev.map((d) => (d.id === userId ? { ...d, walletBalance: d.walletBalance + amount } : d)));
    } else {
      setPassengers((prev) => prev.map((p) => (p.id === userId ? { ...p, walletBalance: p.walletBalance + amount } : p)));
    }
    await writeAuditLog('ADJUST_WALLET', userId, isDriver ? 'driver' : 'passenger', `Adjusted wallet by R${amount}. Reason: ${reason}`);
  };

  const toggleUserStatus = async (userId: string, isDriver: boolean) => {
    requirePermission('users:write');
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

  const updateUserProfile = async (
    userId: string,
    isDriver: boolean,
    updates: Parameters<typeof dbUpdateUserProfile>[1]
  ) => {
    requirePermission(updates.role !== undefined ? 'admin:manage' : 'users:write');
    await dbUpdateUserProfile(userId, updates);
    if (isDriver) {
      setDrivers((prev) =>
        prev.map((d) => (d.id === userId ? { ...d, ...updates } : d))
      );
    } else {
      setPassengers((prev) =>
        prev.map((p) => (p.id === userId ? { ...p, ...updates } : p))
      );
    }
    await writeAuditLog('UPDATE_USER_PROFILE', userId, isDriver ? 'driver' : 'passenger', `Updated profile fields: ${JSON.stringify(updates)}`);
    addNotification({ type: 'success', title: 'Profile Updated', message: `Profile updated successfully.`, timestamp: new Date().toISOString() });
  };

  const deleteUser = async (userId: string, isDriver: boolean) => {
    requirePermission('users:write');
    await dbDeleteUser(userId);
    if (isDriver) {
      setDrivers((prev) => prev.filter((d) => d.id !== userId));
    } else {
      setPassengers((prev) => prev.filter((p) => p.id !== userId));
    }
    await writeAuditLog('DELETE_USER', userId, isDriver ? 'driver' : 'passenger', `Deleted user account from database.`);
    addNotification({ type: 'warning', title: 'User Account Deleted', message: `User record removed from database.`, timestamp: new Date().toISOString() });
  };

  const promoteUserToAdmin = async (userId: string) => {
    // Backwards-compatible wrapper: existing call sites (UserDirectory) hand
    // off the user ID without a scoped role. Default to super_admin so the
    // Migration role-escalation triggers approve the elevation; the super
    // admin can refine the scoped role immediately afterwards.
    await promoteUserToAdminScoped(userId, 'super_admin', 'passenger');
  };

  const promoteUserToAdminScoped = async (
    userId: string,
    adminRole: AdminRole,
    sourceRole: 'driver' | 'passenger',
  ) => {
    requirePermission('admin:manage');
    const expectedFallback = sourceRole === 'driver' ? 'driver' : 'passenger';
    const target = passengers.find((p) => p.id === userId)
      ?? drivers.find((d) => d.id === userId);
    const targetName = target?.fullName ?? userId;
    await dbPromoteUserToAdmin(userId, adminRole);
    setPassengers((prev) => prev.filter((p) => p.id !== userId));
    setDrivers((prev) => prev.filter((d) => d.id !== userId));
    setAdmins((prev) => [
      {
        id: userId,
        fullName: target?.fullName ?? '',
        email: target?.email ?? '',
        phone: target?.phone ?? '',
        baseRole: 'admin',
        adminRole,
        isOnline: false,
        lastSeenAt: '',
        createdAt: target?.joinedAt ?? new Date().toISOString(),
        avatarUrl: target?.avatarUrl ?? '',
      },
      ...prev,
    ]);
    await writeAuditLog(
      'PROMOTE_TO_ADMIN',
      userId,
      expectedFallback,
      `Promoted ${targetName} to admin with scoped role "${adminRole}".`,
    );
    addNotification({
      type: 'success',
      title: 'Admin Role Assigned',
      message: `${targetName} is now a ${adminRole} admin.`,
      timestamp: new Date().toISOString(),
    });
    loadAll();
  };

  const assignAdminRole = async (adminId: string, adminRole: AdminRole) => {
    requirePermission('admin:manage');
    const admin = admins.find((a) => a.id === adminId);
    if (!admin) throw new Error('Admin not found.');
    if (admin.id === user?.id && adminRole !== 'super_admin') {
      throw new Error('You cannot downgrade yourself away from super admin.');
    }
    if (admin.adminRole === 'super_admin' && adminRole !== 'super_admin') {
      const remainingSuper = admins.filter(
        (a) => a.id !== adminId && a.adminRole === 'super_admin',
      ).length;
      if (remainingSuper === 0) {
        throw new Error('At least one super admin must remain in the console.');
      }
    }
    await dbAssignAdminRole(adminId, adminRole);
    setAdmins((prev) =>
      prev.map((a) => (a.id === adminId ? { ...a, adminRole } : a)),
    );
    await writeAuditLog(
      'ASSIGN_ADMIN_ROLE',
      adminId,
      'admin_console_role',
      `Assigned role "${adminRole}" to ${admin.fullName}.`,
    );
    addNotification({
      type: 'success',
      title: 'Admin Role Updated',
      message: `${admin.fullName} is now ${adminRole}.`,
      timestamp: new Date().toISOString(),
    });
  };

  const demoteAdmin = async (adminId: string, fallbackRole: 'driver' | 'passenger') => {
    requirePermission('admin:manage');
    const admin = admins.find((a) => a.id === adminId);
    if (!admin) throw new Error('Admin not found.');
    if (admin.id === user?.id) {
      throw new Error('You cannot demote yourself. Ask another super admin.');
    }
    if (admin.adminRole === 'super_admin') {
      const remainingSuper = admins.filter(
        (a) => a.id !== adminId && a.adminRole === 'super_admin',
      ).length;
      if (remainingSuper === 0) {
        throw new Error('At least one super admin must remain in the console.');
      }
    }
    await dbDemoteAdmin(adminId, fallbackRole);
    setAdmins((prev) => prev.filter((a) => a.id !== adminId));
    await writeAuditLog(
      'DEMOTE_ADMIN',
      adminId,
      'admin',
      `Demoted ${admin.fullName}. Admin access revoked; restored to ${fallbackRole}.`,
    );
    addNotification({
      type: 'warning',
      title: 'Admin Demoted',
      message: `${admin.fullName} has been demoted to ${fallbackRole}.`,
      timestamp: new Date().toISOString(),
    });
    loadAll();
  };

  const issueRefund = async (params: {
    rideId: string;
    amount: number;
    reason: string;
    notes?: Record<string, unknown>;
  }) => {
    requirePermission('finance:write');
    const result = await processRefund(params);
    if (result.status === 'completed') {
      await writeAuditLog(
        'PROCESS_REFUND',
        result.refundId,
        'refund',
        `Issued Paystack refund R ${(result.processedAmount ?? params.amount).toFixed(2)} for ride ${params.rideId}. ${params.reason}`,
      );
      addNotification({
        type: 'success',
        title: 'Refund completed',
        message: `R ${(result.processedAmount ?? params.amount).toFixed(2)} refunded via Paystack.`,
        timestamp: new Date().toISOString(),
      });
    } else {
      await writeAuditLog(
        'REFUND_FAILED',
        result.refundId,
        'refund',
        `Paystack refund attempt failed for ride ${params.rideId}. ${result.paystackMessage ?? ''}`.trim(),
      );
      addNotification({
        type: 'error',
        title: 'Refund failed',
        message: result.paystackMessage ?? 'Paystack did not process the refund.',
        timestamp: new Date().toISOString(),
      });
    }
    // Pull fresh refund data so the table reflects the latest state.
    if (can('finance:read')) {
      fetchRefunds().then(setRefunds).catch(console.error);
      fetchRides().then(setRides).catch(console.error);
    }
    return result.refundId;
  };

  const disputeRefund = async (refundId: string, reason: string) => {
    requirePermission('finance:write');
    await flagRefundDispute(refundId, reason);
    const refund = refunds.find((r) => r.id === refundId);
    await writeAuditLog(
      'DISPUTE_REFUND',
      refundId,
      'refund',
      `Flagged refund ${refund?.paymentReference ?? refundId} as disputed. ${reason}`,
    );
    addNotification({
      type: 'warning',
      title: 'Refund flagged',
      message: 'Refund marked as disputed. Paystack will be notified manually.',
      timestamp: new Date().toISOString(),
    });
    if (can('finance:read')) {
      fetchRefunds().then(setRefunds).catch(console.error);
      fetchRides().then(setRides).catch(console.error);
    }
  };

  const acknowledgeSafetyIncident = async (incidentId: string) => {
    requirePermission('fleet:read');
    await acknowledgeIncident(incidentId);
    const incident = incidents.find((i) => i.id === incidentId);
    await writeAuditLog(
      'ACKNOWLEDGE_INCIDENT',
      incidentId,
      'safety_incident',
      `Acknowledged incident reported by ${incident?.reporterName ?? incidentId} (${incident?.incidentType ?? 'unknown'}).`,
    );
    addNotification({
      type: 'info',
      title: 'Incident acknowledged',
      message: `${incident?.reporterName ?? incidentId} marked as acknowledged.`,
      timestamp: new Date().toISOString(),
    });
    if (can('fleet:read')) {
      fetchSafetyIncidents().then(setIncidents).catch(console.error);
    }
  };

  const resolveSafetyIncident = async (incidentId: string) => {
    requirePermission('fleet:write');
    await resolveIncident(incidentId);
    const incident = incidents.find((i) => i.id === incidentId);
    await writeAuditLog(
      'RESOLVE_INCIDENT',
      incidentId,
      'safety_incident',
      `Resolved incident reported by ${incident?.reporterName ?? incidentId} (${incident?.incidentType ?? 'unknown'}).`,
    );
    addNotification({
      type: 'success',
      title: 'Incident resolved',
      message: `${incident?.reporterName ?? incidentId} marked as resolved.`,
      timestamp: new Date().toISOString(),
    });
    if (can('fleet:read')) {
      fetchSafetyIncidents().then(setIncidents).catch(console.error);
    }
  };

  const addIncidentNote = async (incidentId: string, note: string) => {
    requirePermission('fleet:read');
    await appendIncidentNote(incidentId, note);
    const incident = incidents.find((i) => i.id === incidentId);
    await writeAuditLog(
      'APPEND_INCIDENT_NOTE',
      incidentId,
      'safety_incident',
      `Note appended to incident ${incident?.reporterName ?? incidentId} (${note.length} chars).`,
    );
    addNotification({
      type: 'info',
      title: 'Note saved',
      message: 'Operator note recorded in the audit trail.',
      timestamp: new Date().toISOString(),
    });
    if (can('fleet:read')) {
      fetchSafetyIncidents().then(setIncidents).catch(console.error);
    }
  };

  const rescheduleScheduledRide = async (rideId: string, scheduledForIso: string, reason: string) => {
    requirePermission('fleet:read');
    await rescheduleRide(rideId, scheduledForIso, reason);
    const ride = scheduledRides.find((r) => r.id === rideId);
    await writeAuditLog(
      'RESCHEDULE_RIDE',
      rideId,
      'ride',
      `Rescheduled ride ${ride?.rideReference ?? rideId} to ${new Date(scheduledForIso).toISOString()}.${reason ? ' Reason: ' + reason : ''}`,
    );
    addNotification({
      type: 'success',
      title: 'Ride rescheduled',
      message: `${ride?.rideReference ?? rideId} moved to ${new Date(scheduledForIso).toLocaleString('en-ZA', { dateStyle: 'medium', timeStyle: 'short' })}.`,
      timestamp: new Date().toISOString(),
    });
    if (can('fleet:read') || can('finance:read')) {
      fetchScheduledRides().then(setScheduledRides).catch(console.error);
      fetchRides().then(setRides).catch(console.error);
    }
  };

  const cancelScheduledRideAction = async (rideId: string, reason: string) => {
    requirePermission('fleet:read');
    await cancelScheduledRide(rideId, reason);
    const ride = scheduledRides.find((r) => r.id === rideId);
    await writeAuditLog(
      'CANCEL_SCHEDULED_RIDE',
      rideId,
      'ride',
      `Cancelled scheduled ride ${ride?.rideReference ?? rideId}.${reason ? ' Reason: ' + reason : ''}`,
    );
    addNotification({
      type: 'warning',
      title: 'Scheduled ride cancelled',
      message: `${ride?.passengerName ?? 'Passenger'} (${ride?.rideReference ?? rideId}) notified via audit log.`,
      timestamp: new Date().toISOString(),
    });
    if (can('fleet:read') || can('finance:read')) {
      fetchScheduledRides().then(setScheduledRides).catch(console.error);
      fetchRides().then(setRides).catch(console.error);
    }
  };

  const markNotificationsRead = () => {
    setNotifications((prev) => prev.map((n) => ({ ...n, read: true })));
  };

  const broadcastNotification = async (params: {
    title: string;
    body: string;
    type: BroadcastType;
    routePath?: string | null;
    payload?: Record<string, unknown> | null;
    targetRole?: BroadcastTarget;
  }): Promise<number> => {
    requirePermission('broadcast:write');
    const recipientCount = await dbBroadcastNotification(params);
    const audience =
      params.targetRole === 'passenger'
        ? 'passengers'
        : params.targetRole === 'driver'
          ? 'drivers'
          : 'all users';
    await writeAuditLog(
      'BROADCAST_NOTIFICATION',
      '',
      'notification',
      `Broadcast "${params.title}" (${params.type}) to ${recipientCount} ${audience}.`
    );
    addNotification({
      type: 'success',
      title: 'Broadcast Sent',
      message: `Notification delivered to ${recipientCount} ${audience}.`,
      timestamp: new Date().toISOString(),
    });
    return recipientCount;
  };

  return (
    <AdminContext.Provider
      value={{
        activeTab,
        setActiveTab,
        currentRole,
        user: user ? { id: user.id, email: user.email } : null,
        can,
        loading,
        error,
        refresh: loadAll,
        drivers,
        passengers,
        passengerVerifications,
        rides,
        fareSchemas,
        payouts,
        driverWallets,
        admins,
        refunds,
        incidents,
        scheduledRides,
        auditLogs,
        notifications,
        isRealtimeLive,
        setIsRealtimeLive,
        approveDriver,
        reviewPassengerVerification,
        rejectDriver,
        flagDriverDocument,
        approveDriverDocument,
        updateFareSchema,
        assignDriverToRide,
        cancelRide,
        verifyPayout,
        adjustUserWallet,
        toggleUserStatus,
        updateUserProfile,
        promoteUserToAdmin,
        promoteUserToAdminScoped,
        assignAdminRole,
        demoteAdmin,
        issueRefund,
        disputeRefund,
        acknowledgeSafetyIncident,
        resolveSafetyIncident,
        addIncidentNote,
        rescheduleScheduledRide,
        cancelScheduledRideAction,
        deleteUser,
        markNotificationsRead,
        addNotification,
        broadcastNotification,
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
