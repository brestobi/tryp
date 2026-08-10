/**
 * Typed query functions for the TRYP Admin Console.
 * All data comes from Supabase — no hardcoded records anywhere.
 */

import { supabase } from './supabase';
import type {
  DriverProfile,
  DriverDocument,
  DocumentType,
  DocumentStatus,
  DriverStatus,
  DriverWallet,
  PassengerProfile,
  PassengerVerification,
  Ride,
  RideStatus,
  FareSchema,
  PayoutSettlement,
  AdminAuditLog,
  AdminRole,
} from '../types/admin';

// ─── helpers ────────────────────────────────────────────────────────────────

// eslint-disable-next-line @typescript-eslint/no-explicit-any
function mapDocument(row: any, signedUrl?: string): DriverDocument {
  return {
    id: row.id,
    driverId: row.driver_id,
    docType: row.document_type as DocumentType,
    title: docTypeLabel(row.document_type),
    fileUrl: signedUrl || row.document_url,
    status: (row.status ?? 'pending') as DocumentStatus,
    uploadedAt: row.submitted_at,
    expiresAt: row.expires_at ?? '',
    issueNotes: row.issue_notes ?? undefined,
  };
}

function docTypeLabel(type: string): string {
  const map: Record<string, string> = {
    prdp_license: 'Professional Driving Permit (PrDP)',
    vehicle_registration: 'Vehicle Registration Certificate',
    insurance: 'Comprehensive Passenger Insurance',
    roadworthiness: 'Certificate of Roadworthiness',
    selfie: 'Live Selfie Capture',
  };
  return map[type] ?? type;
}

// eslint-disable-next-line @typescript-eslint/no-explicit-any
function mapDriver(row: any, docs: DriverDocument[]): DriverProfile {
  return {
    id: row.id,
    fullName: row.full_name ?? '',
    email: row.email ?? '',
    phone: row.phone ?? '',
    saIdNumber: row.id_number ?? '',
    licenseNumber: row.license_number ?? '',
    driverStatus: (row.driver_status ?? 'pending') as DriverStatus,
    vehicleMake: row.vehicle_make ?? '',
    vehicleModel: row.vehicle_model ?? '',
    vehicleYear: parseInt(row.vehicle_year ?? '0') || 0,
    vehicleColor: row.vehicle_color ?? '',
    vehiclePlate: row.vehicle_plate ?? '',
    operatingCity: row.operating_city ?? '',
    bankName: row.bank_name ?? '',
    bankAccount: row.bank_account_number ?? '',
    bankBranch: row.bank_branch_code ?? '',
    bankHolder: row.bank_account_holder ?? '',
    walletBalance: parseFloat(row.wallet_balance ?? '0') || 0,
    rating: parseFloat(row.rating ?? '5') || 5,
    isOnline: row.is_online ?? false,
    currentLat: row.current_lat ?? 0,
    currentLng: row.current_lng ?? 0,
    avatarUrl: row.avatar_url ?? `https://ui-avatars.com/api/?name=${encodeURIComponent(row.full_name ?? 'Driver')}&background=111111&color=ffffff`,
    joinedAt: row.created_at,
    totalTrips: 0,
    documents: docs,
  };
}

// eslint-disable-next-line @typescript-eslint/no-explicit-any
function mapPassenger(row: any): PassengerProfile {
  return {
    id: row.id,
    fullName: row.full_name ?? '',
    email: row.email ?? '',
    phone: row.phone ?? '',
    verificationStatus: (row.passenger_verification_status ?? 'unverified') as PassengerProfile['verificationStatus'],
    rating: parseFloat(row.rating ?? '5') || 5,
    walletBalance: parseFloat(row.wallet_balance ?? '0') || 0,
    emergencyContactName: row.emergency_contact_name ?? '',
    emergencyContactPhone: row.emergency_contact_phone ?? '',
    totalRides: 0,
    status: (row.driver_status === 'rejected' ? 'suspended' : 'active') as 'active' | 'suspended',
    joinedAt: row.created_at,
    avatarUrl: row.avatar_url ?? `https://ui-avatars.com/api/?name=${encodeURIComponent(row.full_name ?? 'Passenger')}&background=111111&color=ffffff`,
  };
}

// eslint-disable-next-line @typescript-eslint/no-explicit-any
function mapRide(row: any): Ride {
  return {
    id: row.id,
    rideReference: row.ride_reference ?? '',
    passengerId: row.passenger_id,
    passengerName: row.passenger?.full_name ?? 'Unknown Passenger',
    passengerPhone: row.passenger?.phone ?? '',
    driverId: row.driver_id ?? undefined,
    driverName: row.driver?.full_name ?? undefined,
    driverPhone: row.driver?.phone ?? undefined,
    driverPlate: row.driver?.vehicle_plate ?? undefined,
    pickupAddress: row.origin ?? '',
    destAddress: row.destination ?? '',
    pickupLat: row.pickup_lat ?? 0,
    pickupLng: row.pickup_lng ?? 0,
    destLat: row.dest_lat ?? 0,
    destLng: row.dest_lng ?? 0,
    fare: parseFloat(row.fare ?? '0') || 0,
    tier: (row.ride_type ?? 'TRYP Go') as Ride['tier'],
    status: (row.status ?? 'requested') as RideStatus,
    paymentMethod: (row.payment_method?.toLowerCase() ?? 'cash') as Ride['paymentMethod'],
    paymentStatus: (row.payment_status ?? 'pending') as Ride['paymentStatus'],
    paymentReference: row.payment_reference ?? '',
    requestedAt: row.requested_at,
    surgeMultiplier: parseFloat(row.surge_multiplier ?? '1') || 1,
    distanceKm: parseFloat(row.distance_km ?? '0') || 0,
    durationMins: row.duration_mins ?? 0,
  };
}

// eslint-disable-next-line @typescript-eslint/no-explicit-any
function mapFareSchema(row: any): FareSchema {
  return {
    id: row.id,
    tier: (row.tier ?? 'TRYP Go') as FareSchema['tier'],
    baseFare: parseFloat(row.base_fare ?? '0') || 0,
    perKmRate: parseFloat(row.per_km_rate ?? '0') || 0,
    minFare: parseFloat(row.min_fare ?? '0') || 0,
    perMinuteRate: parseFloat(row.per_minute_rate ?? '0') || 0,
    commissionPercentage: parseFloat(row.commission_percentage ?? '15') || 15,
    surgeMultiplier: parseFloat(row.surge_multiplier ?? '1') || 1,
    updatedAt: row.updated_at,
  };
}

// eslint-disable-next-line @typescript-eslint/no-explicit-any
function mapPayout(row: any): PayoutSettlement {
  return {
    id: row.id,
    driverId: row.driver_id,
    driverName: row.driver?.full_name ?? '',
    bankName: row.driver?.bank_name ?? '',
    accountNumber: row.driver?.bank_account_number ?? '',
    branchCode: row.driver?.bank_branch_code ?? '',
    accountHolder: row.driver?.bank_account_holder ?? '',
    grossEarnings: parseFloat(row.gross_earnings ?? '0') || 0,
    platformFee: parseFloat(row.platform_fee ?? '0') || 0,
    netPayout: parseFloat(row.net_payout ?? '0') || 0,
    status: (row.status ?? 'pending') as PayoutSettlement['status'],
    period: row.period,
    updatedAt: row.updated_at,
  };
}

// eslint-disable-next-line @typescript-eslint/no-explicit-any
function mapAuditLog(row: any): AdminAuditLog {
  return {
    id: row.id,
    adminRole: (row.admin_role ?? 'super_admin') as AdminRole,
    adminName: row.admin_email ?? 'Admin',
    action: row.action,
    targetId: row.target_id,
    targetType: row.target_type,
    details: row.details ?? '',
    ipAddress: row.ip_address ?? '',
    timestamp: row.created_at,
  };
}

// ─── Queries ─────────────────────────────────────────────────────────────────

export async function fetchDrivers(): Promise<DriverProfile[]> {
  const { data: profiles, error } = await supabase
    .from('profiles')
    .select('*')
    .eq('role', 'driver')
    .order('created_at', { ascending: false });

  if (error) throw error;
  if (!profiles?.length) return [];

  const driverIds = profiles.map((p) => p.id);

  const { data: docRows } = await supabase
    .from('driver_documents')
    .select('*')
    .in('driver_id', driverIds);

  const docsByDriver: Record<string, DriverDocument[]> = {};
  for (const doc of docRows ?? []) {
    let signedUrl: string | undefined;
    if (doc.document_url) {
      const marker = '/driver-documents/';
      if (/^https?:\/\//i.test(doc.document_url) && !doc.document_url.includes(marker)) {
        signedUrl = doc.document_url;
      } else {
        const filePath = doc.document_url.includes(marker)
          ? doc.document_url.split(marker)[1]
          : doc.document_url;
        const { data: signedData } = await supabase.storage
          .from('driver-documents')
          .createSignedUrl(filePath, 3600);
        if (signedData?.signedUrl) {
          signedUrl = signedData.signedUrl;
        }
      }
    }

    const mapped = mapDocument(doc, signedUrl);
    if (!docsByDriver[doc.driver_id]) docsByDriver[doc.driver_id] = [];
    docsByDriver[doc.driver_id].push(mapped);
  }

  return profiles.map((p) => mapDriver(p, docsByDriver[p.id] ?? []));
}

export async function fetchDriverWallets(): Promise<DriverWallet[]> {
  const { data, error } = await supabase
    .from('driver_wallets')
    .select('driver_id, cash_collected, online_held, cash_platform_fee_owed, platform_fees_total, updated_at, driver:driver_id (full_name)')
    .order('updated_at', { ascending: false });

  if (error) throw error;
  return (data ?? []).map((row) => {
    const driver = Array.isArray(row.driver) ? row.driver[0] : row.driver;
    return {
      driverId: row.driver_id,
      driverName: driver?.full_name ?? 'Driver',
      cashCollected: parseFloat(row.cash_collected ?? '0') || 0,
      onlineHeld: parseFloat(row.online_held ?? '0') || 0,
      cashPlatformFeeOwed: parseFloat(row.cash_platform_fee_owed ?? '0') || 0,
      platformFeesTotal: parseFloat(row.platform_fees_total ?? '0') || 0,
      updatedAt: row.updated_at,
    } satisfies DriverWallet;
  });
}

export async function fetchPassengerVerifications(): Promise<PassengerVerification[]> {
  const { data, error } = await supabase
    .from('passenger_verifications')
    .select(`
      id,
      passenger_id,
      id_document_path,
      selfie_path,
      status,
      review_notes,
      submitted_at,
      reviewed_at,
      passenger:passenger_id (full_name, email)
    `)
    .order('submitted_at', { ascending: false });
  if (error) throw error;

  const rows = data ?? [];
  const signed = await Promise.all(rows.map(async (row) => {
    const idUrl = await supabase.storage
      .from('passenger-verification')
      .createSignedUrl(row.id_document_path, 3600);
    const selfieUrl = await supabase.storage
      .from('passenger-verification')
      .createSignedUrl(row.selfie_path, 3600);
    const passenger = Array.isArray(row.passenger) ? row.passenger[0] : row.passenger;
    return {
      id: row.id,
      passengerId: row.passenger_id,
      passengerName: passenger?.full_name ?? 'Unknown Passenger',
      passengerEmail: passenger?.email ?? '',
      idDocumentUrl: idUrl.data?.signedUrl ?? '',
      selfieUrl: selfieUrl.data?.signedUrl ?? '',
      status: row.status as PassengerVerification['status'],
      reviewNotes: row.review_notes ?? undefined,
      submittedAt: row.submitted_at,
      reviewedAt: row.reviewed_at ?? undefined,
    } satisfies PassengerVerification;
  }));
  return signed;
}

export async function verifyPaystackTransaction(reference: string): Promise<{
  reference: string;
  amount: number;
  currency: string | null;
  channel: string;
  status: string;
  paidAt: string | null;
  customerEmail: string;
}> {
  const { data, error } = await supabase.functions.invoke('paystack-admin-verify', {
    body: { reference },
  });
  if (error) throw error;
  return data as {
    reference: string;
    amount: number;
    currency: string | null;
    channel: string;
    status: string;
    paidAt: string | null;
    customerEmail: string;
  };
}

export async function dbReviewPassengerVerification(
  verificationId: string,
  status: 'approved' | 'rejected',
  reviewNotes?: string,
) {
  const { error } = await supabase.rpc('review_passenger_verification', {
    p_verification_id: verificationId,
    p_status: status,
    p_review_notes: reviewNotes ?? null,
  });
  if (error) throw error;
}

export async function fetchPassengers(): Promise<PassengerProfile[]> {
  const { data, error } = await supabase
    .from('profiles')
    .select('*')
    .eq('role', 'passenger')
    .order('created_at', { ascending: false });

  if (error) throw error;
  return (data ?? []).map(mapPassenger);
}

export async function fetchRides(): Promise<Ride[]> {
  const { data, error } = await supabase
    .from('rides')
    .select(`
      *,
      passenger:passenger_id (full_name, phone),
      driver:driver_id (full_name, phone, vehicle_plate)
    `)
    .order('requested_at', { ascending: false })
    .limit(200);

  if (error) throw error;
  return (data ?? []).map(mapRide);
}

export async function fetchFareSchemas(): Promise<FareSchema[]> {
  const { data, error } = await supabase
    .from('fare_schemas')
    .select('*')
    .order('id');

  if (error) throw error;
  return (data ?? []).map(mapFareSchema);
}

export async function fetchPayouts(): Promise<PayoutSettlement[]> {
  const { data, error } = await supabase
    .from('driver_payouts')
    .select(`
      *,
      driver:driver_id (full_name, bank_name, bank_account_number, bank_branch_code, bank_account_holder)
    `)
    .order('created_at', { ascending: false });

  if (error) throw error;
  return (data ?? []).map(mapPayout);
}

export async function fetchAuditLogs(): Promise<AdminAuditLog[]> {
  const { data, error } = await supabase
    .from('admin_audit_logs')
    .select('*')
    .order('created_at', { ascending: false })
    .limit(500);

  if (error) throw error;
  return (data ?? []).map(mapAuditLog);
}

// ─── Mutations ────────────────────────────────────────────────────────────────

export async function dbUpdateDriverStatus(driverId: string, status: DriverStatus) {
  const { error } = await supabase
    .from('profiles')
    .update({ driver_status: status, updated_at: new Date().toISOString() })
    .eq('id', driverId);
  if (error) throw error;
}

export async function dbUpdateDocumentStatus(
  docId: string,
  status: DocumentStatus,
  issueNotes?: string
) {
  const { error } = await supabase
    .from('driver_documents')
    .update({
      status,
      issue_notes: issueNotes ?? null,
      reviewed_at: new Date().toISOString(),
    })
    .eq('id', docId);
  if (error) throw error;
}

export async function dbUpdateFareSchema(schemaId: string, updates: {
  base_fare?: number;
  per_km_rate?: number;
  min_fare?: number;
  per_minute_rate?: number;
  commission_percentage?: number;
  surge_multiplier?: number;
}) {
  const { error } = await supabase
    .from('fare_schemas')
    .update({ ...updates, updated_at: new Date().toISOString() })
    .eq('id', schemaId);
  if (error) throw error;
}

export async function dbAssignDriverToRide(rideId: string, driverId: string) {
  const { error } = await supabase
    .from('rides')
    .update({ driver_id: driverId, status: 'accepted', accepted_at: new Date().toISOString() })
    .eq('id', rideId);
  if (error) throw error;
}

export async function dbCancelRide(rideId: string) {
  const { error } = await supabase
    .from('rides')
    .update({ status: 'cancelled' })
    .eq('id', rideId);
  if (error) throw error;
}

export async function dbVerifyPayout(payoutId: string, adminId: string) {
  const { error } = await supabase
    .from('driver_payouts')
    .update({
      status: 'verified',
      verified_by: adminId,
      verified_at: new Date().toISOString(),
      updated_at: new Date().toISOString(),
    })
    .eq('id', payoutId);
  if (error) throw error;
}

export async function dbAdjustWallet(userId: string, amount: number) {
  const { error } = await supabase.rpc('increment_wallet', {
    user_id: userId,
    delta: amount,
  });
  if (error) {
    const { data: profile, error: readError } = await supabase
      .from('profiles')
      .select('wallet_balance')
      .eq('id', userId)
      .single();
    if (readError) throw readError;
    const current = parseFloat(profile?.wallet_balance ?? '0') || 0;
    const { error: updateError } = await supabase
      .from('profiles')
      .update({ wallet_balance: current + amount, updated_at: new Date().toISOString() })
      .eq('id', userId);
    if (updateError) throw updateError;
  }
}

export async function dbToggleUserStatus(userId: string, isDriver: boolean, currentStatus: string) {
  if (isDriver) {
    const next = currentStatus === 'approved' ? 'rejected' : 'approved';
    const { error } = await supabase
      .from('profiles')
      .update({ driver_status: next, updated_at: new Date().toISOString() })
      .eq('id', userId);
    if (error) throw error;
  } else {
    const next = currentStatus === 'active' ? 'rejected' : 'pending';
    const { error } = await supabase
      .from('profiles')
      .update({ driver_status: next, updated_at: new Date().toISOString() })
      .eq('id', userId);
    if (error) throw error;
  }
}

export async function dbUpdateUserProfile(userId: string, updates: {
  fullName?: string;
  phone?: string;
  vehicleMake?: string;
  vehicleModel?: string;
  vehicleYear?: number;
  vehiclePlate?: string;
  vehicleColor?: string;
  operatingCity?: string;
  rating?: number;
  role?: string;
}) {
  const dbFields: Record<string, unknown> = {
    updated_at: new Date().toISOString(),
  };
  if (updates.fullName !== undefined) dbFields.full_name = updates.fullName;
  if (updates.phone !== undefined) dbFields.phone = updates.phone;
  if (updates.vehicleMake !== undefined) dbFields.vehicle_make = updates.vehicleMake;
  if (updates.vehicleModel !== undefined) dbFields.vehicle_model = updates.vehicleModel;
  if (updates.vehicleYear !== undefined) dbFields.vehicle_year = updates.vehicleYear.toString();
  if (updates.vehiclePlate !== undefined) dbFields.vehicle_plate = updates.vehiclePlate;
  if (updates.vehicleColor !== undefined) dbFields.vehicle_color = updates.vehicleColor;
  if (updates.operatingCity !== undefined) dbFields.operating_city = updates.operatingCity;
  if (updates.rating !== undefined) dbFields.rating = updates.rating;
  if (updates.role !== undefined) dbFields.role = updates.role;

  const { error } = await supabase
    .from('profiles')
    .update(dbFields)
    .eq('id', userId);
  if (error) throw error;
}

export async function dbDeleteUser(userId: string) {
  const { error } = await supabase
    .from('profiles')
    .delete()
    .eq('id', userId);
  if (error) throw error;
}

export async function dbInsertAuditLog(log: {
  adminId: string;
  adminEmail: string;
  adminRole: string;
  action: string;
  targetId: string;
  targetType: string;
  details: string;
  ipAddress: string;
}) {
  const { error } = await supabase.from('admin_audit_logs').insert({
    admin_id: log.adminId,
    admin_email: log.adminEmail,
    admin_role: log.adminRole,
    action: log.action,
    target_id: log.targetId,
    target_type: log.targetType,
    details: log.details,
    ip_address: log.ipAddress,
  });
  if (error) console.error('Audit log insert error:', error.message);
}

export type BroadcastType = 'ride' | 'promo' | 'system' | 'payment';
export type BroadcastTarget = 'all' | 'passenger' | 'driver';

export async function dbBroadcastNotification(params: {
  title: string;
  body: string;
  type: BroadcastType;
  routePath?: string | null;
  payload?: Record<string, unknown> | null;
  targetRole?: BroadcastTarget;
}): Promise<number> {
  const { data, error } = await supabase.rpc('broadcast_notification', {
    p_title: params.title,
    p_body: params.body,
    p_type: params.type,
    p_route_path: params.routePath ?? null,
    p_payload: params.payload ?? null,
    p_target_role: params.targetRole ?? 'all',
  });
  if (error) throw error;
  return (data ?? 0) as number;
}
