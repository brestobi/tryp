import React, { createContext, useContext, useState, useEffect } from 'react';
import type {
  AdminRole,
  DriverProfile,
  PassengerProfile,
  Ride,
  FareSchema,
  PayoutSettlement,
  AdminAuditLog,
  DriverStatus,
  DocumentStatus
} from '../types/admin';
import {
  INITIAL_DRIVERS,
  INITIAL_PASSENGERS,
  INITIAL_RIDES,
  INITIAL_FARE_SCHEMAS,
  INITIAL_PAYOUTS,
  INITIAL_AUDIT_LOGS
} from '../lib/supabase';

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
  
  // Data state
  drivers: DriverProfile[];
  passengers: PassengerProfile[];
  rides: Ride[];
  fareSchemas: FareSchema[];
  payouts: PayoutSettlement[];
  auditLogs: AdminAuditLog[];
  notifications: AdminNotification[];
  isRealtimeLive: boolean;
  setIsRealtimeLive: (live: boolean) => void;

  // Actions & Mutations
  approveDriver: (driverId: string) => void;
  rejectDriver: (driverId: string, reason: string) => void;
  flagDriverDocument: (driverId: string, docId: string, issueNotes: string) => void;
  approveDriverDocument: (driverId: string, docId: string) => void;
  
  updateFareSchema: (schemaId: string, updates: Partial<FareSchema>) => void;
  assignDriverToRide: (rideId: string, driverId: string) => void;
  cancelRide: (rideId: string, reason: string) => void;
  
  verifyPayout: (payoutId: string) => void;
  adjustUserWallet: (userId: string, amount: number, isDriver: boolean, reason: string) => void;
  toggleUserStatus: (userId: string, isDriver: boolean) => void;
  
  markNotificationsRead: () => void;
  addAuditLog: (action: string, targetId: string, targetType: string, details: string) => void;
  dispatchDriverPushNotification: (driverId: string, title: string, body: string) => void;
}

const AdminContext = createContext<AdminContextType | undefined>(undefined);

export const AdminProvider: React.FC<{ children: React.ReactNode }> = ({ children }) => {
  const [activeTab, setActiveTab] = useState<ActiveTab>('dashboard');
  const [currentRole, setCurrentRole] = useState<AdminRole>('super_admin');
  const [isRealtimeLive, setIsRealtimeLive] = useState<boolean>(true);

  // Persistence in LocalStorage if available
  const [drivers, setDrivers] = useState<DriverProfile[]>(() => {
    const saved = localStorage.getItem('tryp_admin_drivers');
    return saved ? JSON.parse(saved) : INITIAL_DRIVERS;
  });

  const [passengers, setPassengers] = useState<PassengerProfile[]>(() => {
    const saved = localStorage.getItem('tryp_admin_passengers');
    return saved ? JSON.parse(saved) : INITIAL_PASSENGERS;
  });

  const [rides, setRides] = useState<Ride[]>(() => {
    const saved = localStorage.getItem('tryp_admin_rides');
    return saved ? JSON.parse(saved) : INITIAL_RIDES;
  });

  const [fareSchemas, setFareSchemas] = useState<FareSchema[]>(() => {
    const saved = localStorage.getItem('tryp_admin_fare_schemas');
    return saved ? JSON.parse(saved) : INITIAL_FARE_SCHEMAS;
  });

  const [payouts, setPayouts] = useState<PayoutSettlement[]>(() => {
    const saved = localStorage.getItem('tryp_admin_payouts');
    return saved ? JSON.parse(saved) : INITIAL_PAYOUTS;
  });

  const [auditLogs, setAuditLogs] = useState<AdminAuditLog[]>(() => {
    const saved = localStorage.getItem('tryp_admin_audit_logs');
    return saved ? JSON.parse(saved) : INITIAL_AUDIT_LOGS;
  });

  const [notifications, setNotifications] = useState<AdminNotification[]>([
    {
      id: 'notif-1',
      type: 'warning',
      title: 'KYC Document Pending Review',
      message: 'David Khumalo uploaded a revised PrDP License for review.',
      timestamp: new Date(Date.now() - 5 * 60000).toISOString(),
      read: false
    },
    {
      id: 'notif-2',
      type: 'info',
      title: 'Peak Surge Multiplier Active',
      message: 'Sandton region surge automatically scaled to 1.25x.',
      timestamp: new Date(Date.now() - 18 * 60000).toISOString(),
      read: false
    }
  ]);

  // Sync to localStorage
  useEffect(() => {
    localStorage.setItem('tryp_admin_drivers', JSON.stringify(drivers));
  }, [drivers]);

  useEffect(() => {
    localStorage.setItem('tryp_admin_passengers', JSON.stringify(passengers));
  }, [passengers]);

  useEffect(() => {
    localStorage.setItem('tryp_admin_rides', JSON.stringify(rides));
  }, [rides]);

  useEffect(() => {
    localStorage.setItem('tryp_admin_fare_schemas', JSON.stringify(fareSchemas));
  }, [fareSchemas]);

  useEffect(() => {
    localStorage.setItem('tryp_admin_payouts', JSON.stringify(payouts));
  }, [payouts]);

  useEffect(() => {
    localStorage.setItem('tryp_admin_audit_logs', JSON.stringify(auditLogs));
  }, [auditLogs]);

  // --- Realtime WebSocket Simulator ---
  useEffect(() => {
    if (!isRealtimeLive) return;

    const interval = setInterval(() => {
      // Micro update driver locations slightly for realistic movement on map
      setDrivers(prev =>
        prev.map(drv => {
          if (!drv.isOnline) return drv;
          const latOffset = (Math.random() - 0.5) * 0.002;
          const lngOffset = (Math.random() - 0.5) * 0.002;
          return {
            ...drv,
            currentLat: parseFloat((drv.currentLat + latOffset).toFixed(5)),
            currentLng: parseFloat((drv.currentLng + lngOffset).toFixed(5))
          };
        })
      );
    }, 4000);

    return () => clearInterval(interval);
  }, [isRealtimeLive]);

  // Add audit log helper
  const addAuditLog = (action: string, targetId: string, targetType: string, details: string) => {
    const roleNames: Record<AdminRole, string> = {
      super_admin: 'Super Admin',
      kyc_officer: 'KYC Compliance Officer',
      fleet_dispatcher: 'Fleet Dispatcher',
      finance_manager: 'Finance Manager'
    };

    const newLog: AdminAuditLog = {
      id: `log-${Date.now()}`,
      adminRole: currentRole,
      adminName: roleNames[currentRole],
      action,
      targetId,
      targetType,
      details,
      ipAddress: '102.165.12.8',
      timestamp: new Date().toISOString()
    };

    setAuditLogs(prev => [newLog, ...prev]);
  };

  // Push notification simulator
  const dispatchDriverPushNotification = (driverId: string, title: string, body: string) => {
    const driver = drivers.find(d => d.id === driverId);
    const driverName = driver ? driver.fullName : driverId;

    const notif: AdminNotification = {
      id: `notif-${Date.now()}`,
      type: 'info',
      title: `Push Dispatched to ${driverName}`,
      message: `"${title}": ${body}`,
      timestamp: new Date().toISOString(),
      read: false
    };

    setNotifications(prev => [notif, ...prev]);
    addAuditLog('PUSH_NOTIFICATION_DISPATCH', driverId, 'driver', `Dispatched push note: [${title}] ${body}`);
  };

  // Actions
  const approveDriver = (driverId: string) => {
    setDrivers(prev =>
      prev.map(drv => {
        if (drv.id === driverId) {
          const updatedDocs = drv.documents.map(doc => ({ ...doc, status: 'approved' as DocumentStatus }));
          return { ...drv, driverStatus: 'approved' as DriverStatus, documents: updatedDocs };
        }
        return drv;
      })
    );
    const drv = drivers.find(d => d.id === driverId);
    addAuditLog('APPROVE_DRIVER', driverId, 'driver', `Approved driver KYC application for ${drv?.fullName || driverId}. Granted verification badge.`);
    dispatchDriverPushNotification(driverId, 'TRYP Verification Approved!', 'Congratulations, your driver account has been verified. You can now go online.');
  };

  const rejectDriver = (driverId: string, reason: string) => {
    setDrivers(prev =>
      prev.map(drv => (drv.id === driverId ? { ...drv, driverStatus: 'rejected' as DriverStatus } : drv))
    );
    const drv = drivers.find(d => d.id === driverId);
    addAuditLog('REJECT_DRIVER', driverId, 'driver', `Rejected driver application for ${drv?.fullName || driverId}. Reason: ${reason}`);
    dispatchDriverPushNotification(driverId, 'Application Update', `Your driver application requires attention: ${reason}`);
  };

  const flagDriverDocument = (driverId: string, docId: string, issueNotes: string) => {
    setDrivers(prev =>
      prev.map(drv => {
        if (drv.id === driverId) {
          const updatedDocs = drv.documents.map(doc =>
            doc.id === docId ? { ...doc, status: 'flagged' as DocumentStatus, issueNotes } : doc
          );
          return { ...drv, driverStatus: 'flagged' as DriverStatus, documents: updatedDocs };
        }
        return drv;
      })
    );
    const drv = drivers.find(d => d.id === driverId);
    const doc = drv?.documents.find(d => d.id === docId);
    addAuditLog('FLAG_DOCUMENT', docId, 'driver_document', `Flagged document ${doc?.title || docId} for ${drv?.fullName}: ${issueNotes}`);
    dispatchDriverPushNotification(driverId, 'Document Action Required', `Please re-upload your ${doc?.title || 'document'}: ${issueNotes}`);
  };

  const approveDriverDocument = (driverId: string, docId: string) => {
    setDrivers(prev =>
      prev.map(drv => {
        if (drv.id === driverId) {
          const updatedDocs = drv.documents.map(doc =>
            doc.id === docId ? { ...doc, status: 'approved' as DocumentStatus } : doc
          );
          return { ...drv, documents: updatedDocs };
        }
        return drv;
      })
    );
    addAuditLog('APPROVE_DOCUMENT', docId, 'driver_document', `Approved document ${docId} for driver ${driverId}`);
  };

  const updateFareSchema = (schemaId: string, updates: Partial<FareSchema>) => {
    setFareSchemas(prev =>
      prev.map(sch => (sch.id === schemaId ? { ...sch, ...updates, updatedAt: new Date().toISOString() } : sch))
    );
    const schema = fareSchemas.find(s => s.id === schemaId);
    addAuditLog('UPDATE_FARE_SCHEMA', schemaId, 'fare_schema', `Updated ${schema?.tier} pricing schema: ${JSON.stringify(updates)}`);
  };

  const assignDriverToRide = (rideId: string, driverId: string) => {
    const drv = drivers.find(d => d.id === driverId);
    if (!drv) return;

    setRides(prev =>
      prev.map(r => {
        if (r.id === rideId) {
          return {
            ...r,
            driverId: drv.id,
            driverName: drv.fullName,
            driverPhone: drv.phone,
            driverPlate: drv.vehiclePlate,
            status: 'accepted'
          };
        }
        return r;
      })
    );
    addAuditLog('MANUAL_RIDE_ASSIGNMENT', rideId, 'ride', `Manually assigned driver ${drv.fullName} (${drv.vehiclePlate}) to trip ${rideId}`);
  };

  const cancelRide = (rideId: string, reason: string) => {
    setRides(prev =>
      prev.map(r => (r.id === rideId ? { ...r, status: 'cancelled' } : r))
    );
    addAuditLog('EMERGENCY_RIDE_CANCEL', rideId, 'ride', `Dispatcher cancelled trip ${rideId}. Reason: ${reason}`);
  };

  const verifyPayout = (payoutId: string) => {
    setPayouts(prev =>
      prev.map(p => (p.id === payoutId ? { ...p, status: 'verified', updatedAt: new Date().toISOString() } : p))
    );
    const p = payouts.find(pay => pay.id === payoutId);
    addAuditLog('VERIFY_PAYOUT', payoutId, 'payout_settlement', `Verified driver bank settlement for ${p?.driverName}: R${p?.netPayout.toFixed(2)}`);
  };

  const adjustUserWallet = (userId: string, amount: number, isDriver: boolean, reason: string) => {
    if (isDriver) {
      setDrivers(prev =>
        prev.map(drv => (drv.id === userId ? { ...drv, walletBalance: drv.walletBalance + amount } : drv))
      );
    } else {
      setPassengers(prev =>
        prev.map(pas => (pas.id === userId ? { ...pas, walletBalance: pas.walletBalance + amount } : pas))
      );
    }
    addAuditLog('ADJUST_WALLET', userId, isDriver ? 'driver' : 'passenger', `Adjusted wallet balance by R${amount} for user ID ${userId}. Reason: ${reason}`);
  };

  const toggleUserStatus = (userId: string, isDriver: boolean) => {
    if (isDriver) {
      setDrivers(prev =>
        prev.map(drv => {
          if (drv.id === userId) {
            const nextStatus: DriverStatus = drv.driverStatus === 'approved' ? 'rejected' : 'approved';
            return { ...drv, driverStatus: nextStatus };
          }
          return drv;
        })
      );
    } else {
      setPassengers(prev =>
        prev.map(pas => {
          if (pas.id === userId) {
            const nextStatus = pas.status === 'active' ? 'suspended' : 'active';
            return { ...pas, status: nextStatus };
          }
          return pas;
        })
      );
    }
    addAuditLog('TOGGLE_USER_STATUS', userId, isDriver ? 'driver' : 'passenger', `Toggled account status for user ID ${userId}`);
  };

  const markNotificationsRead = () => {
    setNotifications(prev => prev.map(n => ({ ...n, read: true })));
  };

  return (
    <AdminContext.Provider
      value={{
        activeTab,
        setActiveTab,
        currentRole,
        setCurrentRole,
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
        addAuditLog,
        dispatchDriverPushNotification
      }}
    >
      {children}
    </AdminContext.Provider>
  );
};

export const useAdmin = () => {
  const context = useContext(AdminContext);
  if (!context) {
    throw new Error('useAdmin must be used within an AdminProvider');
  }
  return context;
};
