export type AdminRole = 'super_admin' | 'kyc_officer' | 'fleet_dispatcher' | 'finance_manager';

export type DriverStatus = 'pending' | 'under_review' | 'approved' | 'rejected' | 'flagged';
export type DocumentType = 'prdp_license' | 'vehicle_registration' | 'insurance' | 'roadworthiness' | 'selfie';
export type DocumentStatus = 'pending' | 'approved' | 'rejected' | 'flagged';

export interface DriverDocument {
  id: string;
  driverId: string;
  docType: DocumentType;
  title: string;
  fileUrl: string;
  status: DocumentStatus;
  uploadedAt: string;
  expiresAt: string;
  issueNotes?: string;
}

export interface DriverProfile {
  id: string;
  fullName: string;
  email: string;
  phone: string;
  saIdNumber: string;
  licenseNumber: string;
  driverStatus: DriverStatus;
  accountStatus: 'active' | 'suspended';
  vehicleMake: string;
  vehicleModel: string;
  vehicleYear: number;
  vehicleColor: string;
  vehiclePlate: string;
  operatingCity: string;
  bankName: string;
  bankAccount: string;
  bankBranch: string;
  bankHolder: string;
  walletBalance: number;
  rating: number;
  isOnline: boolean;
  currentLat: number;
  currentLng: number;
  documents: DriverDocument[];
  joinedAt: string;
  totalTrips: number;
  avatarUrl: string;
}

export type PassengerVerificationStatus = 'unverified' | 'pending' | 'under_review' | 'approved' | 'rejected';

export interface DriverWallet {
  driverId: string;
  driverName: string;
  cashCollected: number;
  onlineHeld: number;
  cashPlatformFeeOwed: number;
  platformFeesTotal: number;
  updatedAt: string;
}

export interface PassengerProfile {
  id: string;
  fullName: string;
  email: string;
  phone: string;
  verificationStatus: PassengerVerificationStatus;
  rating: number;
  walletBalance: number;
  emergencyContactName: string;
  emergencyContactPhone: string;
  totalRides: number;
  status: 'active' | 'suspended';
  accountStatus: 'active' | 'suspended';
  joinedAt: string;
  avatarUrl: string;
}

export interface PassengerVerification {
  id: string;
  passengerId: string;
  passengerName: string;
  passengerEmail: string;
  idDocumentUrl: string;
  selfieUrl: string;
  status: PassengerVerificationStatus;
  reviewNotes?: string;
  submittedAt: string;
  reviewedAt?: string;
}

export type RideStatus = 'requested' | 'accepted' | 'arrived' | 'in_trip' | 'completed' | 'cancelled';

export interface Ride {
  id: string;
  rideReference: string;
  passengerId: string;
  passengerName: string;
  passengerPhone: string;
  driverId?: string;
  driverName?: string;
  driverPhone?: string;
  driverPlate?: string;
  pickupAddress: string;
  destAddress: string;
  pickupLat: number;
  pickupLng: number;
  destLat: number;
  destLng: number;
  fare: number;
  tier: 'TRYP Go' | 'TRYP Comfort' | 'TRYP XL' | 'TRYP Exec';
  status: RideStatus;
  paymentMethod: 'card' | 'wallet' | 'cash';
  paymentStatus: 'paid' | 'pending' | 'failed';
  paymentReference: string;
  requestedAt: string;
  surgeMultiplier: number;
  distanceKm: number;
  durationMins: number;
  additionalPassengers: number;
  totalPassengers: number;
}

export interface FareSchema {
  id: string;
  tier: 'TRYP Go' | 'TRYP Comfort' | 'TRYP XL' | 'TRYP Exec';
  baseFare: number;
  perKmRate: number;
  minFare: number;
  perMinuteRate: number;
  extraPersonRate: number;
  commissionPercentage: number;
  surgeMultiplier: number;
  updatedAt: string;
}

export interface PayoutSettlement {
  id: string;
  driverId: string;
  driverName: string;
  bankName: string;
  accountNumber: string;
  branchCode: string;
  accountHolder: string;
  grossEarnings: number;
  platformFee: number;
  netPayout: number;
  status: 'pending' | 'verified' | 'paid' | 'flagged';
  period: string;
  updatedAt: string;
}

export interface AdminAuditLog {
  id: string;
  adminRole: AdminRole;
  adminName: string;
  action: string;
  targetId: string;
  targetType: string;
  details: string;
  ipAddress: string;
  timestamp: string;
}

// Driver Statement Types
export interface DriverStatementTrip {
  id: string;
  rideReference: string;
  passengerName: string;
  pickupAddress: string;
  destAddress: string;
  fare: number;
  paymentMethod: 'Cash' | 'Online';
  platformFee: number;
  driverNetAmount: number;
  completedAt: string;
  distanceKm: number;
  durationMins: number;
  tier: string;
}

export interface DriverStatementSummary {
  driverId: string;
  driverName: string;
  driverEmail: string;
  driverPhone: string;
  vehiclePlate: string;
  bankName: string;
  bankAccount: string;
  periodStart: string;
  periodEnd: string;
  totalTrips: number;
  cashTrips: number;
  onlineTrips: number;
  totalGross: number;
  totalPlatformFees: number;
  totalNetEarnings: number;
  cashCollected: number;
  cashFeesOwed: number;
  onlineEarnings: number;
  onlineFeesWithheld: number;
  pendingOnlinePayout: number;
  averageFare: number;
  longestTrip: number;
  shortestTrip: number;
  totalDistanceKm: number;
  totalDurationMins: number;
  rating: number;
  trips: DriverStatementTrip[];
}

export interface StatementPeriod {
  start: string;
  end: string;
  label: string;
}

export interface AdminUser {
  id: string;
  fullName: string;
  email: string;
  phone: string;
  baseRole: 'admin' | 'super_admin';
  adminRole: AdminRole;
  isOnline: boolean;
  lastSeenAt: string;
  createdAt: string;
  avatarUrl: string;
}

export type RefundStatus = 'pending' | 'processing' | 'completed' | 'failed' | 'disputed';

export interface Refund {
  id: string;
  rideId: string;
  paymentReference: string;
  requestedAmount: number;
  processedAmount: number;
  currency: string;
  reason: string;
  status: RefundStatus;
  paystackRefundId: string | null;
  failureReason: string | null;
  requestedBy: string;
  passengerId: string | null;
  driverId: string | null;
  notes: Record<string, unknown>;
  createdAt: string;
  updatedAt: string;
  completedAt: string | null;

  /** Soft join populated by `fetchRefunds` for direct admin viewing. */
  passengerName?: string;
  passengerEmail?: string;
  driverName?: string;
  driverEmail?: string;
  rideReference?: string;
  rideFare?: number;
  ridePaymentStatus?: string;
}

export type IncidentType = 'emergency' | 'unsafe_driving' | 'medical' | 'harassment' | 'other';
export type IncidentStatus = 'open' | 'acknowledged' | 'resolved';

export interface IncidentNote {
  /** Raw snake_case matching the SQL RPC return shape. */
  note: string;
  operator_id: string;
  operator_email: string;
  operator_role: string;
  appended_at: string;
}

export interface SafetyIncident {
  id: string;
  rideId: string | null;
  reporterId: string;
  incidentType: IncidentType;
  message: string | null;
  latitude: number | null;
  longitude: number | null;
  status: IncidentStatus;
  createdAt: string;
  acknowledgedBy: string | null;
  acknowledgedAt: string | null;
  resolvedBy: string | null;
  resolvedAt: string | null;
  internalNotes: IncidentNote[];

  reporterName: string;
  reporterEmail: string;
  reporterPhone: string;
  reporterRole: string;
  acknowledgedByName: string | null;
  resolvedByName: string | null;
  rideReference: string | null;
  rideStatus: string | null;
  rideOrigin: string | null;
  rideDestination: string | null;
}

export type ScheduledRideStatus = 'requested' | 'accepted' | 'cancelled' | 'pending';

export interface ScheduledRide {
  id: string;
  rideReference: string;
  passengerId: string;
  passengerName: string;
  passengerEmail: string;
  passengerPhone: string;
  driverId: string | null;
  driverName: string | null;
  driverPhone: string | null;
  driverPlate: string | null;
  origin: string;
  destination: string;
  pickupLat: number;
  pickupLng: number;
  destLat: number;
  destLng: number;
  fare: number;
  rideType: string;
  paymentMethod: string;
  paymentStatus: string;
  paymentReference: string;
  status: ScheduledRideStatus;
  scheduledFor: string;
  requestedAt: string;
  acceptedAt: string | null;
  rescheduleCount: number;
  lastRescheduledAt: string | null;
  lastRescheduledBy: string | null;
  lastRescheduledByName: string | null;
  lastRescheduleReason: string | null;
}
