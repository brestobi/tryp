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
  AdminUser,
  Refund,
  RefundStatus,
  SafetyIncident,
  IncidentStatus,
  IncidentType,
  IncidentNote,
  ScheduledRide,
  ScheduledRideStatus,
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
    additionalPassengers: Number(row.additional_passengers ?? 0),
    totalPassengers: Number(row.additional_passengers ?? 0) + 1,
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
    extraPersonRate: parseFloat(row.extra_person_rate ?? '0') || 0,
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
        const { data: signedData, error: signedError } = await supabase.functions.invoke('create-r2-download', {
          body: { objectKey: filePath },
        });
        if (signedError) console.error('Driver document URL error:', signedError.message);
        if (signedData?.downloadUrl) signedUrl = signedData.downloadUrl;
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
      storage_provider,
      id_document_object_key,
      selfie_object_key,
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
    const provider = row.storage_provider ?? 'supabase';
    const idObjectKey = row.id_document_object_key ?? row.id_document_path;
    const selfieObjectKey = row.selfie_object_key ?? row.selfie_path;
    const [{ data: idUrl, error: idError }, { data: selfieUrl, error: selfieError }] = await Promise.all([
      provider === 'r2'
        ? supabase.functions.invoke('create-r2-download', { body: { objectKey: idObjectKey } })
        : supabase.storage.from('passenger-verification').createSignedUrl(row.id_document_path, 3600),
      provider === 'r2'
        ? supabase.functions.invoke('create-r2-download', { body: { objectKey: selfieObjectKey } })
        : supabase.storage.from('passenger-verification').createSignedUrl(row.selfie_path, 3600),
    ]);
    if (idError) console.error('Passenger ID URL error:', idError.message);
    if (selfieError) console.error('Passenger selfie URL error:', selfieError.message);
    const passenger = Array.isArray(row.passenger) ? row.passenger[0] : row.passenger;
    return {
      id: row.id,
      passengerId: row.passenger_id,
      passengerName: passenger?.full_name ?? 'Unknown Passenger',
      passengerEmail: passenger?.email ?? '',
      idDocumentUrl: idUrl?.downloadUrl ?? idUrl?.signedUrl ?? '',
      selfieUrl: selfieUrl?.downloadUrl ?? selfieUrl?.signedUrl ?? '',
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

export async function dbNotifyAccountApproval(
  userId: string,
  accountType: 'driver' | 'passenger',
): Promise<void> {
  const { error } = await supabase.rpc('notify_account_approval', {
    p_user_id: userId,
    p_account_type: accountType,
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
  if (status === 'flagged') {
    const { error } = await supabase.rpc('flag_driver_document', {
      p_document_id: docId,
      p_issue_notes: issueNotes ?? null,
    });
    if (error) throw error;
    return;
  }

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
  extra_person_rate?: number;
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

// ─── Driver Statement Queries ────────────────────────────────────────────────

import type { DriverStatementSummary, DriverStatementTrip } from '../types/admin';

export async function fetchDriverStatementData(
  driverId: string,
  startDate: string,
  endDate: string
): Promise<DriverStatementSummary> {
  // Fetch driver profile
  const { data: driverProfile, error: profileError } = await supabase
    .from('profiles')
    .select('*')
    .eq('id', driverId)
    .single();

  if (profileError) throw profileError;

  // Fetch wallet transactions for the period
  // Add time to dates for proper comparison
  const startDateTime = startDate.includes('T') ? startDate : `${startDate}T00:00:00.000Z`;
  const endDateTime = endDate.includes('T') ? endDate : `${endDate}T23:59:59.999Z`;
  
  const { data: transactions, error: txError } = await supabase
    .from('driver_wallet_transactions')
    .select('*')
    .eq('driver_id', driverId)
    .gte('created_at', startDateTime)
    .lte('created_at', endDateTime)
    .order('created_at', { ascending: true });

  if (txError) throw txError;

  // Fetch ride details for each transaction
  const trips: DriverStatementTrip[] = [];
  let totalDistance = 0;
  let totalDuration = 0;
  let longestTrip = 0;
  let shortestTrip = Infinity;

  for (const tx of transactions ?? []) {
    const { data: ride } = await supabase
      .from('rides')
      .select('*')
      .eq('id', tx.ride_id)
      .single();

    if (ride) {
      const distance = parseFloat(ride.distance_km ?? '0') || 0;
      const duration = ride.duration_mins ?? 0;
      totalDistance += distance;
      totalDuration += duration;
      if (distance > longestTrip) longestTrip = distance;
      if (distance > 0 && distance < shortestTrip) shortestTrip = distance;

      trips.push({
        id: ride.id,
        rideReference: ride.ride_reference ?? '',
        passengerName: ride.passenger_name ?? 'Passenger',
        pickupAddress: ride.origin ?? '',
        destAddress: ride.destination ?? '',
        fare: parseFloat(ride.fare ?? '0') || 0,
        paymentMethod: tx.payment_method as 'Cash' | 'Online',
        platformFee: parseFloat(tx.platform_fee ?? '0') || 0,
        driverNetAmount: parseFloat(tx.driver_net_amount ?? '0') || 0,
        completedAt: tx.created_at,
        distanceKm: distance,
        durationMins: duration,
        tier: ride.ride_type ?? 'TRYP Go',
      });
    }
  }

  // Calculate summaries
  const cashTrips = trips.filter(t => t.paymentMethod === 'Cash');
  const onlineTrips = trips.filter(t => t.paymentMethod === 'Online');

  const totalGross = trips.reduce((sum, t) => sum + t.fare, 0);
  const totalPlatformFees = trips.reduce((sum, t) => sum + t.platformFee, 0);
  const totalNetEarnings = trips.reduce((sum, t) => sum + t.driverNetAmount, 0);

  const cashCollected = cashTrips.reduce((sum, t) => sum + t.fare, 0);
  const cashFeesOwed = cashTrips.reduce((sum, t) => sum + t.platformFee, 0);
  const onlineEarnings = onlineTrips.reduce((sum, t) => sum + t.fare, 0);
  const onlineFeesWithheld = onlineTrips.reduce((sum, t) => sum + t.platformFee, 0);

  return {
    driverId,
    driverName: driverProfile.full_name ?? 'Driver',
    driverEmail: driverProfile.email ?? '',
    driverPhone: driverProfile.phone ?? '',
    vehiclePlate: driverProfile.vehicle_plate ?? '',
    bankName: driverProfile.bank_name ?? '',
    bankAccount: driverProfile.bank_account_number ?? '',
    periodStart: startDate,
    periodEnd: endDate,
    totalTrips: trips.length,
    cashTrips: cashTrips.length,
    onlineTrips: onlineTrips.length,
    totalGross,
    totalPlatformFees,
    totalNetEarnings,
    cashCollected,
    cashFeesOwed,
    onlineEarnings,
    onlineFeesWithheld,
    pendingOnlinePayout: onlineEarnings - onlineFeesWithheld,
    averageFare: trips.length > 0 ? totalGross / trips.length : 0,
    longestTrip: longestTrip === Infinity ? 0 : longestTrip,
    shortestTrip: shortestTrip === Infinity ? 0 : shortestTrip,
    totalDistanceKm: totalDistance,
    totalDurationMins: totalDuration,
    rating: parseFloat(driverProfile.rating ?? '5') || 5,
    trips,
  };
}

export async function fetchAllDriverStatements(
  startDate: string,
  endDate: string
): Promise<DriverStatementSummary[]> {
  // Fetch all approved drivers
  const { data: drivers, error: driversError } = await supabase
    .from('profiles')
    .select('id')
    .eq('role', 'driver')
    .eq('driver_status', 'approved');

  if (driversError) throw driversError;

  const statements: DriverStatementSummary[] = [];
  for (const driver of drivers ?? []) {
    const statement = await fetchDriverStatementData(driver.id, startDate, endDate);
    statements.push(statement);
  }

  return statements;
}

export async function sendDriverStatements(
  statements: DriverStatementSummary[]
): Promise<{ success: number; failed: number }> {
  let success = 0;
  let failed = 0;

  for (const statement of statements) {
    try {
      const { error } = await supabase.functions.invoke('send-driver-statement', {
        body: { statement },
      });
      if (error) throw error;
      success++;
    } catch {
      failed++;
    }
  }

  return { success, failed };
}

// ─── Admin Console User Management ───────────────────────────────────────────

// eslint-disable-next-line @typescript-eslint/no-explicit-any
function mapAdminUser(row: any): AdminUser {
  // Legacy `role = 'admin'` accounts default to super_admin in the RBAC table
  // while they have no scoped admin_role assigned. Preserve that behaviour
  // here so the UI surfaces the same permissions the code enforces.
  const baseRole = (row.role === 'super_admin' ? 'super_admin' : 'admin') as AdminUser['baseRole'];
  const adminRole = (row.admin_role ?? 'super_admin') as AdminRole;
  return {
    id: row.id,
    fullName: row.full_name ?? 'Unnamed Admin',
    email: row.email ?? '',
    phone: row.phone ?? '',
    baseRole,
    adminRole,
    isOnline: row.is_online ?? false,
    lastSeenAt: row.last_location_update ?? row.updated_at ?? row.created_at ?? '',
    createdAt: row.created_at ?? '',
    avatarUrl: row.avatar_url ?? `https://ui-avatars.com/api/?name=${encodeURIComponent(row.full_name ?? 'Admin')}&background=111111&color=ffffff`,
  };
}

export async function fetchAdmins(): Promise<AdminUser[]> {
  const { data, error } = await supabase
    .from('profiles')
    .select('id, full_name, email, phone, role, admin_role, is_online, last_location_update, updated_at, created_at, avatar_url')
    .in('role', ['admin', 'super_admin'])
    .order('created_at', { ascending: false });
  if (error) throw error;
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  return (data ?? []).map((row: any) => mapAdminUser(row));
}

/**
 * Assign a scoped admin console role. The pair of triggers
 * (`prevent_admin_role_escalation` and `prevent_role_escalation`) means only
 * super admins can mutate `role` / `admin_role`, so this update will surface a
 * server-side permission error if invoked by the wrong caller.
 */
export async function dbAssignAdminRole(
  userId: string,
  adminRole: AdminRole,
): Promise<void> {
  // Sibling trigger expects `role` to remain in (admin, super_admin) while
  // an admin_role is set, so we re-affirm it explicitly to clear the path for
  // existing super_admin accounts.
  const { error } = await supabase
    .from('profiles')
    .update({
      role: 'admin',
      admin_role: adminRole,
      updated_at: new Date().toISOString(),
    })
    .eq('id', userId);
  if (error) throw error;
}

/**
 * Promote a non-admin (driver/passenger) into the admin console with the
 * requested scoped role.
 */
export async function dbPromoteUserToAdmin(
  userId: string,
  adminRole: AdminRole = 'super_admin',
): Promise<void> {
  const { error } = await supabase
    .from('profiles')
    .update({
      role: 'admin',
      admin_role: adminRole,
      updated_at: new Date().toISOString(),
    })
    .eq('id', userId);
  if (error) throw error;
}

/**
 * Remove a profile's admin access. We default the role back to `passenger`
 * because `prevent_role_escalation` blocks any caller other than super admins
 * from re-writing it. A driver-former-admin can be restored to `driver` by
 * the caller explicitly.
 */
export async function dbDemoteAdmin(
  userId: string,
  fallbackRole: 'passenger' | 'driver' = 'passenger',
): Promise<void> {
  const { error } = await supabase
    .from('profiles')
    .update({
      role: fallbackRole,
      admin_role: null,
      is_online: false,
      updated_at: new Date().toISOString(),
    })
    .eq('id', userId);
  if (error) throw error;
}

// ─── Refunds & Disputes ───────────────────────────────────────────────────────

// eslint-disable-next-line @typescript-eslint/no-explicit-any
function mapRefundRow(row: any): Refund {
  return {
    id: row.id,
    rideId: row.ride_id,
    paymentReference: row.payment_reference ?? '',
    requestedAmount: parseFloat(row.requested_amount ?? '0') || 0,
    processedAmount: parseFloat(row.processed_amount ?? '0') || 0,
    currency: row.currency ?? 'ZAR',
    reason: row.reason ?? '',
    status: (row.status ?? 'pending') as RefundStatus,
    paystackRefundId: row.paystack_refund_id ?? null,
    failureReason: row.failure_reason ?? null,
    requestedBy: row.requested_by,
    passengerId: row.passenger_id ?? null,
    driverId: row.driver_id ?? null,
    notes: (row.notes ?? {}) as Record<string, unknown>,
    createdAt: row.created_at,
    updatedAt: row.updated_at,
    completedAt: row.completed_at ?? null,
    passengerName: row.passenger?.full_name ?? undefined,
    passengerEmail: row.passenger?.email ?? undefined,
    driverName: row.driver?.full_name ?? undefined,
    driverEmail: row.driver?.email ?? undefined,
    rideReference: row.ride?.ride_reference ?? undefined,
    rideFare: row.ride?.fare ? parseFloat(row.ride.fare) : undefined,
    ridePaymentStatus: row.ride?.payment_status ?? undefined,
  };
}

export async function fetchRefunds(): Promise<Refund[]> {
  const { data, error } = await supabase
    .from('refunds')
    .select(`
      id, ride_id, payment_reference, requested_amount, processed_amount, currency,
      reason, status, paystack_refund_id, failure_reason, requested_by, passenger_id,
      driver_id, notes, created_at, updated_at, completed_at,
      passenger:passenger_id ( full_name, email ),
      driver:driver_id ( full_name, email ),
      ride:ride_id ( ride_reference, fare, payment_status )
    `)
    .order('created_at', { ascending: false })
    .limit(200);
  if (error) throw error;
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  return (data ?? []).map((row: any) => mapRefundRow(row));
}

/**
 * Look up a single ride by id (UUID) or payment_reference. Returns null if
 * nothing matches. The query avoids ambiguous return shapes by always
 * fetching both id columns.
 */
export async function fetchRefundableRide(
  identifier: string,
): Promise<{
  id: string;
  rideReference: string;
  fare: number;
  paymentMethod: string;
  paymentStatus: string;
  paymentReference: string;
  passengerId: string | null;
  passengerName: string;
  passengerEmail: string;
  driverName: string;
  status: string;
} | null> {
  const isUuid = /^[0-9a-f-]{36}$/i.test(identifier.trim());
  const baseSelect = `
    id, ride_reference, fare, payment_method, payment_status, payment_reference,
    status, passenger_id, driver_id,
    passenger:passenger_id ( full_name, email ),
    driver:driver_id ( full_name )
  `;
  const base = isUuid
    ? supabase.from('rides').select(baseSelect).eq('id', identifier.trim())
    : supabase
        .from('rides')
        .select(baseSelect)
        .or(`payment_reference.eq.${identifier.trim()},ride_reference.eq.${identifier.trim()}`)
        .limit(1);
  const { data, error } = await base.maybeSingle();
  if (error) throw error;
  if (!data) return null;
  return {
    id: data.id,
    rideReference: data.ride_reference ?? '',
    fare: parseFloat(String((data as { fare?: string | number }).fare ?? '0')) || 0,
    paymentMethod: (data as { payment_method?: string }).payment_method ?? 'Cash',
    paymentStatus: (data as { payment_status?: string }).payment_status ?? 'pending',
    paymentReference: (data as { payment_reference?: string }).payment_reference ?? '',
    passengerId: (data as { passenger_id?: string | null }).passenger_id ?? null,
    passengerName:
      // eslint-disable-next-line @typescript-eslint/no-explicit-any
      ((data as any).passenger?.full_name as string | undefined) ?? '',
    passengerEmail:
      // eslint-disable-next-line @typescript-eslint/no-explicit-any
      ((data as any).passenger?.email as string | undefined) ?? '',
    driverName:
      // eslint-disable-next-line @typescript-eslint/no-explicit-any
      ((data as any).driver?.full_name as string | undefined) ?? '',
    status: (data as { status?: string }).status ?? '',
  };
}

/**
 * Issue a refund. The finance team controls the amount and reason. The
 * Edge Function performs the actual Paystack call and updates the refund row.
 */
export async function processRefund(params: {
  rideId: string;
  amount: number;
  reason: string;
  notes?: Record<string, unknown>;
}): Promise<{
  refundId: string;
  status: 'completed' | 'failed';
  amount: number;
  processedAmount?: number;
  paystackRefundId?: string | null;
  paystackMessage?: string;
}> {
  const { data, error } = await supabase.functions.invoke('paystack-refund', {
    body: {
      rideId: params.rideId,
      amount: params.amount,
      reason: params.reason,
      notes: params.notes ?? {},
    },
  });
  if (error) throw error;
  const payload = (data ?? {}) as {
    refundId?: string;
    status?: 'completed' | 'failed';
    amount?: number;
    processedAmount?: number;
    paystackRefundId?: string | null;
    paystackMessage?: string;
  };
  if (!payload.refundId) {
    throw new Error((data as { error?: string })?.error ?? 'Paystack refund response missing refund ID.');
  }
  return {
    refundId: payload.refundId,
    status: payload.status ?? 'failed',
    amount: payload.amount ?? params.amount,
    processedAmount: payload.processedAmount,
    paystackRefundId: payload.paystackRefundId ?? null,
    paystackMessage: payload.paystackMessage,
  };
}

/**
 * Mark a refund under dispute without contacting Paystack. Used when finance
 * flags a refund as disputed pending Paystack investigation.
 */
export async function flagRefundDispute(refundId: string, reason: string): Promise<void> {
  const { error } = await supabase.rpc('finalize_refund', {
    p_refund_id: refundId,
    p_status: 'disputed',
    p_processed_amount: 0,
    p_paystack_refund_id: null,
    p_paystack_response: null,
    p_failure_reason: reason,
  });
  if (error) throw error;
}

// ─── Safety Incidents ─────────────────────────────────────────────────────────

// eslint-disable-next-line @typescript-eslint/no-explicit-any
function mapIncident(row: any): SafetyIncident {
  return {
    id: row.id,
    rideId: row.ride_id ?? null,
    reporterId: row.reporter_id,
    incidentType: (row.incident_type ?? 'other') as IncidentType,
    message: row.message ?? null,
    latitude: row.latitude ?? null,
    longitude: row.longitude ?? null,
    status: (row.status ?? 'open') as IncidentStatus,
    createdAt: row.created_at,
    acknowledgedBy: row.acknowledged_by ?? null,
    acknowledgedAt: row.acknowledged_at ?? null,
    resolvedBy: row.resolved_by ?? null,
    resolvedAt: row.resolved_at ?? null,
    internalNotes: Array.isArray(row.internal_notes)
      ? // eslint-disable-next-line @typescript-eslint/no-explicit-any
        (row.internal_notes as any[]).map((n) => n as IncidentNote)
      : [],
    reporterName: row.reporter_name ?? 'Unknown reporter',
    reporterEmail: row.reporter_email ?? '',
    reporterPhone: row.reporter_phone ?? '',
    reporterRole: row.reporter_role ?? 'passenger',
    acknowledgedByName: row.acknowledged_by_name ?? null,
    resolvedByName: row.resolved_by_name ?? null,
    rideReference: row.ride_reference ?? null,
    rideStatus: row.ride_status ?? null,
    rideOrigin: row.ride_origin ?? null,
    rideDestination: row.ride_destination ?? null,
  };
}

export async function fetchSafetyIncidents(): Promise<SafetyIncident[]> {
  const { data, error } = await supabase.rpc('fetch_admin_incidents', {
    p_limit: 200,
  });
  if (error) throw error;
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  return ((data ?? []) as any[]).map((row) => mapIncident(row));
}

export async function acknowledgeIncident(incidentId: string): Promise<void> {
  const { error } = await supabase.rpc('update_safety_incident_status', {
    p_incident_id: incidentId,
    p_status: 'acknowledged',
  });
  if (error) throw error;
}

export async function resolveIncident(incidentId: string): Promise<void> {
  const { error } = await supabase.rpc('update_safety_incident_status', {
    p_incident_id: incidentId,
    p_status: 'resolved',
  });
  if (error) throw error;
}

export async function appendIncidentNote(incidentId: string, note: string): Promise<IncidentNote> {
  const { data, error } = await supabase.rpc('append_incident_note', {
    p_incident_id: incidentId,
    p_note: note,
  });
  if (error) throw error;
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  return (data as any) ?? {};
}

// ─── Scheduled Rides ──────────────────────────────────────────────────────────

// eslint-disable-next-line @typescript-eslint/no-explicit-any
function mapScheduledRide(row: any): ScheduledRide {
  return {
    id: row.id,
    rideReference: row.ride_reference ?? '',
    passengerId: row.passenger_id,
    passengerName: row.passenger_name ?? 'Unknown passenger',
    passengerEmail: row.passenger_email ?? '',
    passengerPhone: row.passenger_phone ?? '',
    driverId: row.driver_id ?? null,
    driverName: row.driver_name ?? null,
    driverPhone: row.driver_phone ?? null,
    driverPlate: row.driver_plate ?? null,
    origin: row.origin ?? '',
    destination: row.destination ?? '',
    pickupLat: parseFloat(String(row.pickup_lat ?? 0)) || 0,
    pickupLng: parseFloat(String(row.pickup_lng ?? 0)) || 0,
    destLat: parseFloat(String(row.dest_lat ?? 0)) || 0,
    destLng: parseFloat(String(row.dest_lng ?? 0)) || 0,
    fare: parseFloat(String(row.fare ?? '0')) || 0,
    rideType: row.ride_type ?? 'TRYP Go',
    paymentMethod: row.payment_method ?? 'Cash',
    paymentStatus: row.payment_status ?? 'pending',
    paymentReference: row.payment_reference ?? '',
    status: (row.status ?? 'requested') as ScheduledRideStatus,
    scheduledFor: row.scheduled_for,
    requestedAt: row.requested_at,
    acceptedAt: row.accepted_at ?? null,
    rescheduleCount: Number(row.reschedule_count ?? 0),
    lastRescheduledAt: row.last_rescheduled_at ?? null,
    lastRescheduledBy: row.last_rescheduled_by ?? null,
    lastRescheduledByName: row.last_rescheduled_by_name ?? null,
    lastRescheduleReason: row.last_reschedule_reason ?? null,
  };
}

export async function fetchScheduledRides(): Promise<ScheduledRide[]> {
  const { data, error } = await supabase.rpc('fetch_admin_scheduled_rides', {
    p_window_minutes: 60 * 24 * 30,
  });
  if (error) throw error;
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  return ((data ?? []) as any[]).map((row) => mapScheduledRide(row));
}

export async function rescheduleRide(
  rideId: string,
  scheduledForIso: string,
  reason: string,
): Promise<void> {
  const { error } = await supabase.rpc('reschedule_ride', {
    p_ride_id: rideId,
    p_scheduled_for: scheduledForIso,
    p_reason: reason || null,
  });
  if (error) throw error;
}

export async function cancelScheduledRide(
  rideId: string,
  reason: string,
): Promise<void> {
  const { error } = await supabase.rpc('admin_cancel_scheduled_ride', {
    p_ride_id: rideId,
    p_reason: reason || null,
  });
  if (error) throw error;
}
